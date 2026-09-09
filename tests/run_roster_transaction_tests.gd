extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("ROSTER_TRANSACTION_TEST: creating full league")
	var career := CareerSession.new_career("nfl_buf", 928441, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var league := career.league
	var team := career.user_team()
	_check(team.players.size() == 53, "A new career must retain its 53-man roster")
	_check(team.active_roster_count() == 48, "A new career must prepare a 48-player game-day list")
	_check(RosterValidator.validate_game_day_roster(team).is_empty(), "The automatic game-day list must be legal")
	var receiver_room := team.depth_players("WR")
	team.move_on_depth_chart("WR", receiver_room[1].id, -1)
	team.configure_game_day_roster()
	_check(team.depth_players("WR").front().id == receiver_room[1].id, "Automatic game-day configuration must preserve user depth-chart priority")
	var preferred_receiver: PlayerData = team.depth_players("WR")[1]
	team.move_on_depth_chart("WR", preferred_receiver.id, -1)
	team.configure_game_day_roster()
	_check(team.depth_players("WR").front().id == preferred_receiver.id, "Automatic game-day setup must preserve the user's depth-chart priority")

	print("ROSTER_TRANSACTION_TEST: validating game-day controls")
	var active_receiver: PlayerData
	for receiver in team.players_at("WR", true):
		active_receiver = receiver
		break
	_check(active_receiver != null, "The game-day roster must activate a wide receiver")
	var deactivated := career.set_player_game_day_active(active_receiver.id, false)
	_check(bool(deactivated.get("ok", false)), "A position group with remaining coverage should allow a player to be deactivated")
	_check(team.active_roster_count() == 47 and active_receiver.roster_status == PlayerData.STATUS_GAME_DAY_INACTIVE, "Deactivation must update both the count and explicit status")
	_check(career.begin_user_game() == null, "A club with an incomplete game-day list must be blocked from starting its matchup")
	var inactive_player: PlayerData
	for player in team.players:
		if not player.is_active and player.injury_weeks <= 0:
			inactive_player = player
			break
	var activated := career.set_player_game_day_active(inactive_player.id, true)
	_check(bool(activated.get("ok", false)) and team.active_roster_count() == 48, "A healthy inactive player should fill the open game-day place")
	var overflow := career.set_player_game_day_active(active_receiver.id, true)
	_check(not bool(overflow.get("ok", false)), "The game-day list must reject a 49th active player")

	print("ROSTER_TRANSACTION_TEST: validating injured reserve")
	var injured_player: PlayerData = team.players_at("WR").back()
	injured_player.injure("Knee sprain", 6)
	var payroll_before_ir := team.payroll()
	var ir_result := career.place_player_on_injured_reserve(injured_player.id)
	_check(bool(ir_result.get("ok", false)), "An injured player should move to injured reserve")
	_check(team.players.size() == 52 and team.injured_reserve_player_by_id(injured_player.id) != null, "IR must open a 53-man roster place without losing ownership")
	_check(injured_player.roster_status == PlayerData.STATUS_INJURED_RESERVE and injured_player.eligible_return_week == 5, "IR must assign an explicit status and four-week minimum stay")
	_check(team.payroll() == payroll_before_ir, "IR must preserve the player's contract and cap charge")
	injured_player.injury_weeks = 0
	var early_return := career.activate_player_from_injured_reserve(injured_player.id)
	_check(not bool(early_return.get("ok", false)), "An IR player cannot return before the minimum stay ends")
	league.current_week = injured_player.eligible_return_week
	var ir_return := career.activate_player_from_injured_reserve(injured_player.id)
	_check(bool(ir_return.get("ok", false)) and team.players.size() == 53 and team.injured_reserve.is_empty(), "An eligible IR player should return to the 53-man roster")

	print("ROSTER_TRANSACTION_TEST: validating practice-squad movement")
	var free_agent: PlayerData = _eligible_free_agent(league, team)
	var free_agent_count := league.free_agents.size()
	var practice_result := career.sign_practice_squad_player(free_agent.id)
	_check(bool(practice_result.get("ok", false)), "An eligible free agent should sign to the practice squad")
	_check(team.practice_squad_player_by_id(free_agent.id) != null and league.free_agents.size() == free_agent_count - 1, "Practice-squad signing must transfer ownership from free agency")
	_check(free_agent.contract != null and free_agent.contract.role == "Practice Squad" and free_agent.roster_status == PlayerData.STATUS_PRACTICE_SQUAD, "Practice-squad players need their own contract and roster status")
	var blocked_promotion := career.promote_practice_squad_player(free_agent.id)
	_check(not bool(blocked_promotion.get("ok", false)), "Promotion must require an open place on the 53-man roster")
	var roster_cut: PlayerData = _releasable_player(team)
	var cut_result := career.release_player(roster_cut.id)
	_check(bool(cut_result.get("ok", false)) and league.waiver_entry_for_player(roster_cut.id) != null, "An in-season release must place the player on waivers")
	var promotion := career.promote_practice_squad_player(free_agent.id)
	_check(bool(promotion.get("ok", false)) and team.player_by_id(free_agent.id) != null, "A practice-squad player should promote into an open roster place")

	print("ROSTER_TRANSACTION_TEST: validating claims and persistence")
	var source := league.teams[1]
	var waiver_player := _releasable_player(source)
	var waiver_result := RosterTransactionService.waive_player(league, source.id, waiver_player.id)
	var entry: WaiverEntryData = waiver_result.get("entry")
	var user_cut := _releasable_player(team)
	var second_cut := career.release_player(user_cut.id)
	_check(bool(second_cut.get("ok", false)), "The managed club should be able to create room for a claim")
	var claim := career.submit_waiver_claim(entry.id)
	_check(bool(claim.get("ok", false)) and entry.has_claim(team.id), "A valid waiver claim must be recorded")
	var restored := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	var restored_entry := restored.league.waiver_entry_by_id(entry.id)
	_check(restored_entry != null and restored_entry.has_claim(team.id), "A pending claim and its player must survive a save round trip")
	restored.league.current_week = restored_entry.resolve_week
	var resolution := RosterTransactionService.resolve_waivers(restored.league)
	_check(int(resolution.get("awarded", 0)) >= 1, "Eligible claims must resolve after the waiver deadline")
	_check(restored.user_team().player_by_id(waiver_player.id) != null, "The highest-priority valid claimant must inherit the player and contract")

	print("ROSTER_TRANSACTION_TEST: validating AI roster management")
	var ai_team := restored.league.teams[2]
	var ai_injured: PlayerData = ai_team.players_at("WR").back()
	ai_injured.injure("Hamstring strain", 4)
	RosterTransactionService.run_ai_roster_management(restored.league)
	_check(ai_team.injured_reserve_player_by_id(ai_injured.id) != null, "AI clubs must protect multi-week injuries on IR")
	_check(ai_team.practice_squad.size() > 0 and ai_team.practice_squad.size() <= ai_team.practice_squad_limit, "AI clubs must build a legal development squad")
	for club in restored.league.teams:
		_check(club.players.size() <= club.roster_limit, "%s must remain within its 53-man limit" % club.abbreviation)
		_check(club.practice_squad.size() <= club.practice_squad_limit, "%s must remain within its practice-squad limit" % club.abbreviation)
		_check(club.payroll() <= club.salary_cap, "%s must remain under the cap" % club.abbreviation)

	var round_trip := CareerSession.from_dict(JSON.parse_string(JSON.stringify(restored.to_dict())))
	_check(round_trip.league.teams[2].injured_reserve_player_by_id(ai_injured.id) != null, "IR state must persist across another save round trip")
	_check(round_trip.league.teams[2].practice_squad.size() == ai_team.practice_squad.size(), "Practice-squad state must persist across another save round trip")
	_check(_all_player_ids_unique(round_trip.league), "No roster transaction may duplicate a player across ownership pools")

	if _failures.is_empty():
		print("PASS: %d assertions across game-day activation, IR, practice squads, waivers, AI, and persistence." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _eligible_free_agent(league: LeagueState, team: TeamData) -> PlayerData:
	for player in league.free_agents:
		if RosterValidator.practice_squad_error(team, player).is_empty():
			var contract := PlayerContract.practice_squad_contract(player, league.contract_start_year())
			if contract.annual_salary <= team.cap_space():
				return player
	return null


func _releasable_player(team: TeamData) -> PlayerData:
	var ordered := team.players.duplicate()
	ordered.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall < b.overall)
	for player: PlayerData in ordered:
		if RosterValidator.release_error(team, player).is_empty():
			return player
	return null


func _all_player_ids_unique(league: LeagueState) -> bool:
	var seen: Dictionary = {}
	for player in league.all_players():
		if seen.has(player.id):
			return false
		seen[player.id] = true
	return true


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
