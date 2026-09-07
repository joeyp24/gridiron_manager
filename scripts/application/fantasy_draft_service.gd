class_name FantasyDraftService
extends RefCounted

# Fantasy clubs hold a realistic depth-contract reserve so star selections cannot
# consume the last dollars needed to finish all 53 rounds.
const MINIMUM_SALARY := 1_000_000
const TARGET_DEPTH := {
	"QB": 2, "RB": 4, "WR": 6, "TE": 3,
	"LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
	"EDGE": 5, "DT": 4, "LB": 6, "CB": 6, "S": 4,
	"K": 1, "P": 1, "LS": 1,
}
const MAXIMUM_DEPTH := {
	"QB": 4, "RB": 6, "WR": 9, "TE": 5,
	"LT": 4, "LG": 4, "C": 4, "RG": 4, "RT": 4,
	"EDGE": 7, "DT": 7, "LB": 9, "CB": 9, "S": 7,
	"K": 2, "P": 2, "LS": 2,
}


static func initialize(league: LeagueState) -> FantasyDraftStateData:
	var draft := FantasyDraftStateData.new(league.season_seed ^ 0x5F3759DF)
	var player_pool: Array[PlayerData] = []
	var player_ids: Dictionary = {}
	for team in league.teams:
		for player in team.players:
			if not player_ids.has(player.id):
				player_pool.append(player)
				player_ids[player.id] = true
		team.players.clear()
		team.dead_cap = 0
		team.initialize_depth_chart()
	for player in league.free_agents:
		if not player_ids.has(player.id):
			player_pool.append(player)
			player_ids[player.id] = true
	draft.original_pool_size = player_pool.size()
	draft.total_rounds = league.league_format.roster_size
	draft.draft_order = _randomized_order(league, draft.draft_seed)
	draft.picks = _build_snake_picks(draft.draft_order, draft.total_rounds)
	player_pool.sort_custom(func(a: PlayerData, b: PlayerData):
		if a.overall != b.overall:
			return a.overall > b.overall
		return a.id < b.id
	)
	league.free_agents = player_pool
	league.career_mode = LeagueState.CAREER_MODE_FANTASY_DRAFT
	league.phase = LeagueState.PHASE_FANTASY_DRAFT
	league.fantasy_draft = draft
	league.news.push_front("The league-wide fantasy draft pool is open. All %d players are available." % player_pool.size())
	return draft


static func start(league: LeagueState) -> Dictionary:
	var draft := league.fantasy_draft
	if draft == null or draft.status != FantasyDraftStateData.STATUS_READY:
		return _failure("The fantasy draft is not ready to begin.")
	draft.status = FantasyDraftStateData.STATUS_IN_PROGRESS
	draft.current_pick_index = 0
	var result := _simulate_ai_until_user_pick(league)
	if not bool(result.get("ok", false)):
		return result
	return {"ok": true, "message": "The fantasy draft is underway. Your club owns slot #%d." % draft.user_draft_slot(league.user_team_id)}


static func select_user_player(league: LeagueState, player_id: String) -> Dictionary:
	var draft := league.fantasy_draft
	var pick := draft.current_pick() if draft != null else null
	if draft == null or draft.status != FantasyDraftStateData.STATUS_IN_PROGRESS or pick == null:
		return _failure("The fantasy draft is not awaiting a selection.")
	if pick.team_id != league.user_team_id:
		return _failure("Your club is not currently on the clock.")
	var player := league.free_agent_by_id(player_id)
	var result := _make_selection(league, pick, player)
	if not bool(result.get("ok", false)):
		return result
	var ai_result := _simulate_ai_until_user_pick(league)
	if not bool(ai_result.get("ok", false)):
		return ai_result
	return result


static func auto_pick_user(league: LeagueState) -> Dictionary:
	var draft := league.fantasy_draft
	var pick := draft.current_pick() if draft != null else null
	if pick == null or pick.team_id != league.user_team_id:
		return _failure("Your club is not currently on the clock.")
	var player := _best_ai_player(league, league.user_team(), pick)
	return select_user_player(league, player.id) if player != null else _failure("No legal player remains for this roster.")


static func simulate_to_user_pick(league: LeagueState) -> Dictionary:
	if league.fantasy_draft == null or league.fantasy_draft.status != FantasyDraftStateData.STATUS_IN_PROGRESS:
		return _failure("The fantasy draft is not in progress.")
	return _simulate_ai_until_user_pick(league)


static func simulate_remainder(league: LeagueState) -> Dictionary:
	var draft := league.fantasy_draft
	if draft == null or draft.status == FantasyDraftStateData.STATUS_COMPLETE:
		return _failure("The fantasy draft is already complete.")
	if draft.status == FantasyDraftStateData.STATUS_READY:
		draft.status = FantasyDraftStateData.STATUS_IN_PROGRESS
	while draft.current_pick() != null:
		var pick := draft.current_pick()
		var team := league.team_by_id(pick.team_id)
		var player := _best_ai_player(league, team, pick)
		if player == null:
			return _failure(_no_legal_selection_message(league, team, pick))
		var result := _make_selection(league, pick, player)
		if not bool(result.get("ok", false)):
			return result
	_finalize(league)
	return {"ok": true, "message": "The fantasy draft is complete. All 32 rosters are ready for the season."}


static func ranked_pool(league: LeagueState, position_filter: String = "", search_text: String = "") -> Array[PlayerData]:
	var team := league.user_team()
	var result: Array[PlayerData] = []
	var query := search_text.strip_edges().to_lower()
	for player in league.free_agents:
		if not position_filter.is_empty() and player.position != position_filter:
			continue
		if not query.is_empty() and not query in player.full_name.to_lower():
			continue
		result.append(player)
	result.sort_custom(func(a: PlayerData, b: PlayerData):
		var a_score := board_score(team, a)
		var b_score := board_score(team, b)
		if not is_equal_approx(a_score, b_score):
			return a_score > b_score
		return a.id < b.id
	)
	return result


static func board_score(team: TeamData, player: PlayerData) -> float:
	var counts := roster_counts(team)
	return _player_score(team, player, counts, team.players.size(), 0)


static func roster_counts(team: TeamData) -> Dictionary:
	var counts: Dictionary = {}
	for position_name in TeamData.ROSTER_POSITIONS:
		counts[position_name] = 0
	for player in team.players:
		counts[player.position] = int(counts.get(player.position, 0)) + 1
	return counts


static func team_needs(team: TeamData, limit: int = 5) -> Array[String]:
	var counts := roster_counts(team)
	var positions := TeamData.ROSTER_POSITIONS.duplicate()
	positions.sort_custom(func(a: String, b: String):
		var a_shortage := int(TARGET_DEPTH.get(a, 1)) - int(counts.get(a, 0))
		var b_shortage := int(TARGET_DEPTH.get(b, 1)) - int(counts.get(b, 0))
		if a_shortage != b_shortage:
			return a_shortage > b_shortage
		return _position_value(a) > _position_value(b)
	)
	var result: Array[String] = []
	for index in range(mini(limit, positions.size())):
		result.append(positions[index])
	return result


static func selection_error(league: LeagueState, team: TeamData, player: PlayerData) -> String:
	return _selection_error_with_context(league, team, player, _selection_context(league, team))


static func _simulate_ai_until_user_pick(league: LeagueState) -> Dictionary:
	var draft := league.fantasy_draft
	while draft != null and draft.current_pick() != null and draft.current_pick().team_id != league.user_team_id:
		var pick := draft.current_pick()
		var team := league.team_by_id(pick.team_id)
		var player := _best_ai_player(league, team, pick)
		if player == null:
			return _failure(_no_legal_selection_message(league, team, pick))
		var result := _make_selection(league, pick, player)
		if not bool(result.get("ok", false)):
			return result
	if draft != null and draft.current_pick() == null:
		_finalize(league)
	return {"ok": true, "message": "Simulation advanced to the next user selection."}


static func _make_selection(league: LeagueState, pick: FantasyDraftPickData, player: PlayerData) -> Dictionary:
	var team := league.team_by_id(pick.team_id)
	if team == null or player == null:
		return _failure("The selected player is no longer available.")
	var validation_error := selection_error(league, team, player)
	if not validation_error.is_empty():
		return _failure(validation_error)
	league.free_agents.erase(player)
	if player.contract == null:
		player.contract = PlayerContract.initial_contract(player, league.season_year, team.players_at(player.position).size())
	player.is_active = true
	player.record_team(team.id)
	if not team.add_player(player):
		league.free_agents.append(player)
		return _failure("The roster could not accept this selection.")
	pick.selected_player_id = player.id
	pick.selected_player_name = player.full_name
	pick.selected_position = player.position
	pick.selected_overall = player.overall
	league.fantasy_draft.current_pick_index += 1
	return {
		"ok": true,
		"message": "%s drafted %s (%s, OVR %d) at #%d." % [team.display_name(), player.full_name, player.position, player.overall, pick.overall_pick],
		"player": player,
		"pick": pick,
	}


static func _best_ai_player(league: LeagueState, team: TeamData, pick: FantasyDraftPickData) -> PlayerData:
	var context := _selection_context(league, team, true)
	var counts: Dictionary = context["roster_counts"]
	var best: PlayerData
	var best_score := -INF
	for player in league.free_agents:
		if not _selection_error_with_context(league, team, player, context).is_empty():
			continue
		var noise_seed := league.fantasy_draft.draft_seed + pick.overall_pick * 1009 + player.id.hash() + team.id.hash()
		var score := _player_score(team, player, counts, team.players.size(), noise_seed)
		if score > best_score:
			best = player
			best_score = score
	return best


static func _player_score(team: TeamData, player: PlayerData, counts: Dictionary, roster_size: int, noise_seed: int) -> float:
	var desired := int(TARGET_DEPTH.get(player.position, 2))
	var position_count := int(counts.get(player.position, 0))
	var shortage := maxi(desired - position_count, 0)
	var score := float(player.overall) + float(player.potential - player.overall) * 0.18
	score += float(shortage) * 1.6 + _position_value(player.position)
	if position_count == 0 and roster_size >= 28:
		score += 7.0
	if player.age <= 25:
		score += 2.0
	elif player.age >= 32:
		score -= float(player.age - 31) * 0.65
	if player.position in ["RB", "TE", "LT", "LG", "C", "RG", "RT"]:
		score += (team.run_tendency - 0.5) * 4.0
	elif player.position in ["QB", "WR"]:
		score += (0.5 - team.run_tendency) * 4.0
	elif player.position in ["CB", "S", "LB"] and player.madden_ratings != null:
		var coverage_name := "zoneCoverage" if team.coverage_preference == "Zone" else "manCoverage"
		score += float(player.madden_ratings.rating(coverage_name, player.technique) - 75) * 0.05
	if player.contract != null:
		score -= float(player.contract.annual_salary) / 20_000_000.0
	if noise_seed != 0:
		score += float((absi(noise_seed) % 401) - 200) / 100.0
	return score


static func _selection_context(league: LeagueState, team: TeamData, assume_pool_member: bool = false) -> Dictionary:
	var pool_counts: Dictionary = {}
	for position_name in TeamData.ROSTER_POSITIONS:
		pool_counts[position_name] = 0
	for player in league.free_agents:
		pool_counts[player.position] = int(pool_counts.get(player.position, 0)) + 1
	var teams_missing: Dictionary = {}
	for position_name in TeamData.ROSTER_POSITIONS:
		teams_missing[position_name] = 0
	for league_team in league.teams:
		var seen: Dictionary = {}
		for roster_player in league_team.players:
			seen[roster_player.position] = true
		for position_name in TeamData.ROSTER_POSITIONS:
			if not seen.has(position_name):
				teams_missing[position_name] = int(teams_missing[position_name]) + 1
	return {
		"roster_counts": roster_counts(team),
		"pool_counts": pool_counts,
		"teams_missing": teams_missing,
		"payroll": team.payroll(),
		"remaining_slots": team.roster_limit - team.players.size(),
		"assume_pool_member": assume_pool_member,
	}


static func _selection_error_with_context(league: LeagueState, team: TeamData, player: PlayerData, context: Dictionary) -> String:
	if player == null or (not bool(context.get("assume_pool_member", false)) and not league.free_agents.has(player)):
		return "The selected player is no longer in the draft pool."
	if team.players.size() >= team.roster_limit:
		return "%s already has a complete roster." % team.display_name()
	var counts: Dictionary = context["roster_counts"]
	if int(counts.get(player.position, 0)) >= int(MAXIMUM_DEPTH.get(player.position, 4)):
		return "The roster has reached its fantasy draft limit at %s." % player.position
	var missing_positions: Array[String] = []
	for position_name in TeamData.ROSTER_POSITIONS:
		if int(counts.get(position_name, 0)) == 0:
			missing_positions.append(position_name)
	var remaining_slots := int(context["remaining_slots"])
	if remaining_slots <= missing_positions.size() and not player.position in missing_positions:
		return "The remaining selections must fill missing positions: %s." % ", ".join(missing_positions)
	var pool_counts: Dictionary = context["pool_counts"]
	var teams_missing: Dictionary = context["teams_missing"]
	if int(counts.get(player.position, 0)) > 0 and int(pool_counts.get(player.position, 0)) <= int(teams_missing.get(player.position, 0)):
		return "That selection would leave another club without a %s." % player.position
	var salary := _selection_salary(player, league.season_year, int(counts.get(player.position, 0)))
	var reserve := maxi(remaining_slots - 1, 0) * MINIMUM_SALARY
	if int(context["payroll"]) + salary + reserve > team.salary_cap:
		return "The selection would leave insufficient cap room to complete the roster."
	return ""


static func _selection_salary(player: PlayerData, season_year: int, depth_index: int) -> int:
	if player.contract != null:
		return player.contract.annual_salary
	return PlayerContract.initial_contract(player, season_year, depth_index).annual_salary


static func _finalize(league: LeagueState) -> void:
	var draft := league.fantasy_draft
	if draft == null or draft.status == FantasyDraftStateData.STATUS_COMPLETE:
		return
	for player in league.free_agents:
		player.contract = null
		player.is_active = true
	for team in league.teams:
		team.initialize_depth_chart()
		team.recalculate_ratings_from_roster()
	draft.status = FantasyDraftStateData.STATUS_COMPLETE
	league.phase = LeagueState.PHASE_REGULAR_SEASON
	league.news.push_front("The fantasy draft is complete. All clubs carry new 53-player rosters into Week 1.")
	league.news.push_front("%s selected from slot #%d in the fantasy draft." % [league.user_team().display_name(), draft.user_draft_slot(league.user_team_id)])


static func _randomized_order(league: LeagueState, draft_seed: int) -> Array[String]:
	var order: Array[String] = []
	for team in league.teams:
		order.append(team.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = draft_seed
	for index in range(order.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var displaced := order[index]
		order[index] = order[swap_index]
		order[swap_index] = displaced
	return order


static func _build_snake_picks(order: Array[String], rounds: int) -> Array[FantasyDraftPickData]:
	var picks: Array[FantasyDraftPickData] = []
	var overall_pick := 1
	for round_number in range(1, rounds + 1):
		var round_order := order.duplicate()
		if round_number % 2 == 0:
			round_order.reverse()
		for pick_index in range(round_order.size()):
			picks.append(FantasyDraftPickData.new(round_number, pick_index + 1, overall_pick, round_order[pick_index]))
			overall_pick += 1
	return picks


static func _position_value(position_name: String) -> float:
	match position_name:
		"QB": return 7.0
		"EDGE", "LT", "CB", "WR": return 4.0
		"DT", "LB", "S", "RT": return 2.5
		"K", "P": return -8.0
		"LS": return -10.0
	return 1.5


static func _no_legal_selection_message(league: LeagueState, team: TeamData, pick: FantasyDraftPickData) -> String:
	var context := _selection_context(league, team, true)
	var reasons: Dictionary = {}
	for player in league.free_agents:
		var reason := _selection_error_with_context(league, team, player, context)
		reasons[reason] = int(reasons.get(reason, 0)) + 1
	var reason_labels: Array[String] = []
	for reason in reasons:
		if not str(reason).is_empty():
			reason_labels.append("%s (%d)" % [reason, int(reasons[reason])])
	return "%s could not make a legal selection at #%d with %d roster spots and %s cap space remaining. %s" % [team.display_name(), pick.overall_pick, int(context["remaining_slots"]), PlayerContract.money_label(team.cap_space()), " | ".join(reason_labels)]


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
