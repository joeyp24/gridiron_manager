class_name DraftService
extends RefCounted

const ROUNDS := 7
const DESIRED_DEPTH := {
	"QB": 2, "RB": 3, "WR": 5, "TE": 2, "LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
	"EDGE": 3, "DT": 3, "LB": 4, "CB": 4, "S": 3, "K": 1, "P": 1,
	"LS": 1,
}


static func create_draft(league: LeagueState) -> DraftStateData:
	TradeService.ensure_future_draft_picks(league)
	var draft := DraftStateData.new(league.season_year + 1)
	var class_size := league.teams.size() * ROUNDS + league.teams.size()
	draft.prospects = DraftClassGenerator.generate(draft.draft_year, league.season_seed, class_size, league.teams.size())
	var order := _draft_order(league)
	var overall_pick := 1
	for round_number in range(1, ROUNDS + 1):
		for pick_index in range(order.size()):
			var original_team_id: String = order[pick_index]
			var reserved_pick := TradeService.future_pick_for(league, draft.draft_year, round_number, original_team_id)
			var owner_team_id := reserved_pick.owner_team_id if reserved_pick != null else original_team_id
			draft.picks.append(DraftPickData.new(
				"draft_%d_r%d_p%d" % [draft.draft_year, round_number, pick_index + 1],
				draft.draft_year,
				round_number,
				pick_index + 1,
				overall_pick,
				original_team_id,
				owner_team_id
			))
			overall_pick += 1
	for prospect in draft.prospects:
		var report := ScoutingReportData.new(league.user_team_id, prospect.id)
		report.initialize(prospect, league.season_seed + draft.draft_year * 193)
		draft.scouting_reports.append(report)
	return draft


static func scout_prospect(league: LeagueState, prospect_id: String) -> Dictionary:
	var draft := league.current_draft
	if league.phase != LeagueState.PHASE_DRAFT_PREPARATION or draft == null:
		return _failure("Targeted scouting is only available during draft preparation.")
	if draft.scouting_points_remaining <= 0:
		return _failure("No scouting assignments remain.")
	var prospect := draft.prospect_by_id(prospect_id)
	var report := draft.report_for(league.user_team_id, prospect_id)
	if prospect == null or report == null:
		return _failure("The selected prospect is unavailable.")
	if report.level >= 3:
		return _failure("The scouting staff has completed this evaluation.")
	if not report.advance(prospect, league.season_seed + draft.draft_year * 193):
		return _failure("The scouting report could not be advanced.")
	draft.scouting_points_remaining -= 1
	return {"ok": true, "message": "Scouting on %s advanced to %d%% confidence." % [prospect.full_name, report.confidence]}


static func toggle_favorite(league: LeagueState, prospect_id: String) -> Dictionary:
	var draft := league.current_draft
	if draft == null or draft.prospect_by_id(prospect_id) == null:
		return _failure("The selected prospect is unavailable.")
	var is_favorite := draft.toggle_favorite(prospect_id)
	return {"ok": true, "is_favorite": is_favorite, "message": "Added to favorites." if is_favorite else "Removed from favorites."}


static func start_draft(league: LeagueState) -> Dictionary:
	var draft := league.current_draft
	if league.phase != LeagueState.PHASE_DRAFT_PREPARATION or draft == null:
		return _failure("Draft preparation is not active.")
	draft.status = DraftStateData.STATUS_IN_PROGRESS
	draft.current_pick_index = 0
	league.phase = LeagueState.PHASE_DRAFT
	_simulate_ai_until_user_pick(league)
	return {"ok": true, "message": "The %d draft is underway." % draft.draft_year}


static func select_user_prospect(league: LeagueState, prospect_id: String) -> Dictionary:
	var draft := league.current_draft
	var pick := draft.current_pick() if draft != null else null
	if league.phase != LeagueState.PHASE_DRAFT or draft == null or pick == null:
		return _failure("The draft is not awaiting a selection.")
	if pick.owner_team_id != league.user_team_id:
		return _failure("Your club is not currently on the clock.")
	var prospect := draft.prospect_by_id(prospect_id)
	if prospect == null or not prospect in draft.available_prospects():
		return _failure("The selected prospect is no longer available.")
	var result := _make_selection(league, pick, prospect)
	if not bool(result.get("ok", false)):
		return result
	_simulate_ai_until_user_pick(league)
	return result


static func auto_pick_user(league: LeagueState) -> Dictionary:
	var draft := league.current_draft
	var pick := draft.current_pick() if draft != null else null
	if pick == null or pick.owner_team_id != league.user_team_id:
		return _failure("Your club is not currently on the clock.")
	var prospect := _best_user_board_prospect(league)
	return select_user_prospect(league, prospect.id) if prospect != null else _failure("No prospects remain.")


static func ranked_board(league: LeagueState, position_filter: String = "", favorites_only: bool = false) -> Array[ProspectData]:
	var draft := league.current_draft
	var board: Array[ProspectData] = []
	if draft == null:
		return board
	for prospect in draft.available_prospects():
		if not position_filter.is_empty() and prospect.position != position_filter:
			continue
		if favorites_only and not draft.is_favorite(prospect.id):
			continue
		board.append(prospect)
	board.sort_custom(func(a: ProspectData, b: ProspectData): return _user_board_score(league, a) > _user_board_score(league, b))
	return board


static func team_needs(team: TeamData, limit: int = 4) -> Array[String]:
	var positions := TeamData.ROSTER_POSITIONS.duplicate()
	positions.sort_custom(func(a: String, b: String): return _need_score(team, a) > _need_score(team, b))
	var needs: Array[String] = []
	for index in range(mini(limit, positions.size())):
		needs.append(positions[index])
	return needs


static func team_draft_grade(draft: DraftStateData, team_id: String) -> String:
	var selections := draft.selections_for_team(team_id)
	if selections.is_empty():
		return "N/A"
	var points := 0.0
	for pick in selections:
		match pick.selection_grade:
			"A": points += 4.0
			"B": points += 3.0
			"C": points += 2.0
			_: points += 1.0
	var average := points / float(selections.size())
	if average >= 3.55:
		return "A"
	if average >= 2.75:
		return "B"
	if average >= 1.75:
		return "C"
	return "D"


static func recent_selections(draft: DraftStateData, limit: int = 8) -> Array[DraftPickData]:
	var selections: Array[DraftPickData] = []
	for pick in draft.picks:
		if pick.is_used():
			selections.push_front(pick)
	return selections.slice(0, mini(limit, selections.size()))


static func _simulate_ai_until_user_pick(league: LeagueState) -> void:
	var draft := league.current_draft
	while draft != null and draft.current_pick() != null and draft.current_pick().owner_team_id != league.user_team_id:
		var pick := draft.current_pick()
		var team := league.team_by_id(pick.owner_team_id)
		var prospect := _best_ai_prospect(league, team, pick)
		if prospect == null:
			break
		_make_selection(league, pick, prospect)
	if draft != null and draft.current_pick() == null:
		_complete_draft(league)


static func _make_selection(league: LeagueState, pick: DraftPickData, prospect: ProspectData) -> Dictionary:
	var draft := league.current_draft
	var team := league.team_by_id(pick.owner_team_id)
	if draft == null or team == null or prospect == null:
		return _failure("The selection could not be completed.")
	var player := prospect.to_player(draft.draft_year)
	player.draft_round = pick.round_number
	player.draft_pick = pick.pick_in_round
	player.record_team(team.id)
	player.contract = PlayerContract.rookie_contract(draft.draft_year, pick.round_number, pick.pick_in_round)
	if not team.add_player(player, TeamData.OFFSEASON_ROSTER_LIMIT):
		return _failure("The offseason roster cannot accept another drafted player.")
	pick.selected_prospect_id = prospect.id
	pick.selected_player_id = player.id
	var value_difference := pick.overall_pick - prospect.consensus_rank
	pick.value_label = "VALUE" if value_difference >= 8 else ("REACH" if value_difference <= -10 else "ON BOARD")
	pick.selection_grade = "A" if value_difference >= 8 else ("B" if value_difference >= -5 else ("C" if value_difference >= -14 else "D"))
	draft.current_pick_index += 1
	_record_selection(league, team, player, pick)
	return {"ok": true, "message": "%s selected %s at #%d." % [team.display_name(), player.full_name, pick.overall_pick], "player": player, "pick": pick}


static func _complete_draft(league: LeagueState) -> void:
	var draft := league.current_draft
	if draft == null or draft.is_complete():
		return
	draft.status = DraftStateData.STATUS_COMPLETE
	if not draft.undrafted_converted:
		for prospect in draft.available_prospects():
			var player := prospect.to_player(draft.draft_year)
			player.contract = null
			player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
			league.free_agents.append(player)
		draft.undrafted_converted = true
		league.free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	league.phase = LeagueState.PHASE_ROSTER_DECISIONS
	league.news.push_front("The %d draft is complete. Clubs now must finalize their active rosters." % draft.draft_year)


static func _best_ai_prospect(league: LeagueState, team: TeamData, pick: DraftPickData) -> ProspectData:
	var best: ProspectData
	var best_score := -9999.0
	for prospect in league.current_draft.available_prospects():
		var score := float(prospect.true_overall) * 0.58 + float(prospect.true_potential) * 0.28
		score += _need_score(team, prospect.position) * 1.8
		score += _position_value(prospect.position)
		score += float(prospect.production_grade) * 0.04
		var noise_seed := league.season_seed + pick.overall_pick * 1009 + prospect.id.hash() + team.id.hash()
		var noise := float((absi(noise_seed) % 901) - 450) / 100.0
		score += noise
		if score > best_score:
			best = prospect
			best_score = score
	return best


static func _best_user_board_prospect(league: LeagueState) -> ProspectData:
	var board := ranked_board(league)
	return board.front() if not board.is_empty() else null


static func _user_board_score(league: LeagueState, prospect: ProspectData) -> float:
	var report := league.current_draft.report_for(league.user_team_id, prospect.id)
	if report == null:
		return 0.0
	return report.estimated_overall() * 0.62 + report.estimated_potential() * 0.28 + float(prospect.production_grade) * 0.04 + _need_score(league.user_team(), prospect.position) * 1.5 + _position_value(prospect.position)


static func _need_score(team: TeamData, position_name: String) -> float:
	var players := team.players_at(position_name)
	var desired := int(DESIRED_DEPTH.get(position_name, 2))
	var shortage := maxi(desired - players.size(), 0)
	var starter := team.player_at(position_name)
	var quality_need := clampf(float(78 - starter.overall) / 8.0, 0.0, 3.0) if starter != null else 4.0
	return float(shortage) * 2.0 + quality_need


static func _position_value(position_name: String) -> float:
	match position_name:
		"QB": return 5.0
		"EDGE", "LT", "CB", "WR": return 3.0
		"DT", "LB", "S", "RT": return 1.8
		"K", "P", "LS": return -2.0
	return 1.0


static func _draft_order(league: LeagueState) -> Array[String]:
	var record := league.latest_season_record()
	var entries: Array[Dictionary] = []
	if record != null:
		entries = record.standings.duplicate(true)
	entries.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_id := str(a.get("team_id", ""))
		var b_id := str(b.get("team_id", ""))
		if a_id == record.champion_team_id:
			return false
		if b_id == record.champion_team_id:
			return true
		if int(a.get("wins", 0)) != int(b.get("wins", 0)):
			return int(a.get("wins", 0)) < int(b.get("wins", 0))
		if int(a.get("ties", 0)) != int(b.get("ties", 0)):
			return int(a.get("ties", 0)) < int(b.get("ties", 0))
		return int(a.get("point_differential", 0)) < int(b.get("point_differential", 0))
	)
	var order: Array[String] = []
	for entry in entries:
		order.append(str(entry.get("team_id", "")))
	if order.is_empty():
		for team in league.teams:
			order.push_front(team.id)
	return order


static func _record_selection(league: LeagueState, team: TeamData, player: PlayerData, pick: DraftPickData) -> void:
	var details := "Selected %s with pick #%d in round %d; rookie cap hit %s." % [player.full_name, pick.overall_pick, pick.round_number, PlayerContract.money_label(player.contract.current_cap_hit())]
	var transaction := TransactionData.new(
		"draft_transaction_%d_%d" % [pick.draft_year, pick.overall_pick],
		league.season_year,
		league.current_week,
		"Draft Selection",
		team.id,
		player.id,
		player.full_name,
		details,
		player.contract.current_cap_hit()
	)
	league.record_transaction(transaction, "%s select %s at #%d." % [team.display_name(), player.full_name, pick.overall_pick])


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
