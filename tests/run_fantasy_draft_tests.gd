extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("FANTASY_DRAFT_TEST: creating 32-team fantasy career")
	var career := CareerSession.new_career("nfl_buf", 860921, LeagueCatalog.SOURCE_NFLVERSE_FULL, LeagueState.CAREER_MODE_FANTASY_DRAFT)
	var draft := career.league.fantasy_draft
	_check(draft != null, "Fantasy career creation must initialize draft state")
	_check(career.league.phase == LeagueState.PHASE_FANTASY_DRAFT, "Fantasy careers must begin in the fantasy draft phase")
	_check(career.league.career_mode == LeagueState.CAREER_MODE_FANTASY_DRAFT, "Fantasy careers must retain their career mode")
	_check(career.league.teams.size() == 32, "The fantasy draft requires all 32 clubs")
	_check(career.league.free_agents.size() == 2035, "Every rostered player and free agent must enter the shared pool")
	_check(draft.draft_order.size() == 32 and _unique_count(draft.draft_order) == 32, "The first-round order must contain every club exactly once")
	_check(draft.picks.size() == 32 * 53, "The snake draft must schedule 53 selections for every club")
	for team in career.league.teams:
		_check(team.players.is_empty(), "%s must start with an empty fantasy roster" % team.abbreviation)
	for index in range(32):
		_check(draft.picks[index].team_id == draft.draft_order[index], "Round one must follow the randomized order")
		_check(draft.picks[32 + index].team_id == draft.draft_order[31 - index], "Round two must reverse the randomized order")

	var same_seed := CareerSession.new_career("nfl_buf", 860921, LeagueCatalog.SOURCE_NFLVERSE_FULL, LeagueState.CAREER_MODE_FANTASY_DRAFT)
	_check(same_seed.league.fantasy_draft.draft_order == draft.draft_order, "Identical seeds must generate identical draft positions")
	var other_seed := CareerSession.new_career("nfl_buf", 860922, LeagueCatalog.SOURCE_NFLVERSE_FULL, LeagueState.CAREER_MODE_FANTASY_DRAFT)
	_check(other_seed.league.fantasy_draft.draft_order != draft.draft_order, "Different seeds should generate a different draft order")

	print("FANTASY_DRAFT_TEST: beginning draft and testing user selection")
	var begin := career.start_fantasy_draft()
	_check(bool(begin.get("ok", false)), "The live fantasy draft must start successfully")
	_check(draft.current_pick() != null and draft.current_pick().team_id == career.league.user_team_id, "AI clubs must simulate to the user's first selection")
	var legal_player: PlayerData
	for candidate in FantasyDraftService.ranked_pool(career.league):
		if FantasyDraftService.selection_error(career.league, career.user_team(), candidate).is_empty():
			legal_player = candidate
			break
	_check(legal_player != null, "The user must have a legal player available on the clock")
	var user_pick := career.select_fantasy_player(legal_player.id) if legal_player != null else {"ok": false}
	_check(bool(user_pick.get("ok", false)), "The user's manual selection must be accepted")
	_check(career.user_team().player_by_id(legal_player.id) != null, "A selected player must join the user's roster")
	_check(career.league.free_agent_by_id(legal_player.id) == null, "A selected player must leave the draft pool")
	_check(draft.current_pick() != null and draft.current_pick().team_id == career.league.user_team_id, "The draft must advance through AI picks to the user's next selection")

	print("FANTASY_DRAFT_TEST: validating mid-draft persistence")
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	var loaded_draft := loaded.league.fantasy_draft
	_check(loaded_draft != null and loaded_draft.status == FantasyDraftStateData.STATUS_IN_PROGRESS, "An in-progress fantasy draft must survive a save round trip")
	_check(loaded_draft.current_pick_index == draft.current_pick_index, "Save data must preserve the exact current selection")
	_check(loaded_draft.draft_order == draft.draft_order, "Save data must preserve draft order")
	_check(loaded.league.free_agents.size() == career.league.free_agents.size(), "Save data must preserve the available player pool")
	_check(loaded.user_team().players.size() == career.user_team().players.size(), "Save data must preserve drafted rosters")

	print("FANTASY_DRAFT_TEST: simulating remaining selections")
	var completed := loaded.simulate_fantasy_draft()
	_check(bool(completed.get("ok", false)), str(completed.get("message", "The remaining fantasy draft must simulate")))
	_check(loaded_draft.is_complete(), "The fantasy draft must reach complete status")
	_check(loaded.league.phase == LeagueState.PHASE_REGULAR_SEASON, "A completed fantasy draft must open Week 1")
	_check(loaded.league.current_week == 1, "The regular season schedule must remain at Week 1")
	_check(loaded.league.schedule.size() == 272, "The full regular-season schedule must remain intact")
	var all_player_ids: Dictionary = {}
	var rostered_count := 0
	for team in loaded.league.teams:
		rostered_count += team.players.size()
		_check(team.players.size() == 53, "%s must finish with a 53-player roster" % team.abbreviation)
		var roster_errors := RosterValidator.validate_team(team, true)
		_check(roster_errors.is_empty(), "%s must finish with a legal roster: %s" % [team.abbreviation, "; ".join(roster_errors)])
		_check(team.depth_chart.size() == TeamData.ROSTER_POSITIONS.size(), "%s must rebuild its complete depth chart" % team.abbreviation)
		_check(team.offense_rating > 0 and team.defense_rating > 0 and team.special_teams_rating > 0, "%s must recalculate ratings from its drafted roster" % team.abbreviation)
		for player in team.players:
			_check(not all_player_ids.has(player.id), "%s may only belong to one drafted roster" % player.full_name)
			all_player_ids[player.id] = true
	_check(rostered_count == 1696, "All 32 clubs must draft exactly 53 players")
	_check(loaded.league.free_agents.size() == 339, "Undrafted players must form the expanded free-agent pool")
	for player in loaded.league.free_agents:
		_check(player.contract == null, "%s must enter free agency without a contract" % player.full_name)
		_check(not all_player_ids.has(player.id), "%s cannot be rostered and a free agent" % player.full_name)
		all_player_ids[player.id] = true
	_check(all_player_ids.size() == 2035, "The draft must preserve every player without duplication or loss")

	var standard := CareerSession.new_career("nfl_buf", 860921, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	_check(standard.league.career_mode == LeagueState.CAREER_MODE_STANDARD, "Standard career creation must remain the default")
	_check(standard.league.fantasy_draft == null and standard.user_team().players.size() == 53, "Standard careers must keep their original rosters")

	if _failures.is_empty():
		print("PASS: %d assertions across fantasy draft setup, AI, persistence, roster construction, and standard-mode compatibility." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _unique_count(values: Array[String]) -> int:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	return unique.size()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
