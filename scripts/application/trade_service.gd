class_name TradeService
extends RefCounted

const NFL_TRADE_DEADLINE_WEEK := 9
const FUTURE_PICK_YEARS := 3
const PICK_VALUES := {
	1: 1200,
	2: 560,
	3: 270,
	4: 130,
	5: 65,
	6: 32,
	7: 16,
}
const POSITION_VALUES := {
	"QB": 1.25,
	"EDGE": 1.13,
	"LT": 1.12,
	"CB": 1.10,
	"WR": 1.08,
	"DT": 1.04,
	"LB": 1.02,
	"S": 1.02,
	"RT": 1.02,
	"K": 0.78,
	"P": 0.72,
	"LS": 0.58,
}


static func ensure_future_draft_picks(league: LeagueState) -> int:
	var additions := 0
	for draft_year in range(league.season_year + 1, league.season_year + FUTURE_PICK_YEARS + 1):
		for round_number in range(1, DraftService.ROUNDS + 1):
			for team in league.teams:
				if future_pick_for(league, draft_year, round_number, team.id) != null:
					continue
				league.future_draft_picks.append(DraftPickData.new(
					_future_pick_id(draft_year, round_number, team.id),
					draft_year,
					round_number,
					0,
					0,
					team.id,
					team.id
				))
				additions += 1
	_sort_future_picks(league.future_draft_picks)
	return additions


static func prune_past_draft_picks(league: LeagueState) -> void:
	for pick: DraftPickData in league.future_draft_picks.duplicate():
		if pick.draft_year <= league.season_year:
			league.future_draft_picks.erase(pick)


static func future_pick_by_id(league: LeagueState, pick_id: String) -> DraftPickData:
	for pick in league.future_draft_picks:
		if pick.id == pick_id:
			return pick
	return null


static func future_pick_for(league: LeagueState, draft_year: int, round_number: int, original_team_id: String) -> DraftPickData:
	for pick in league.future_draft_picks:
		if pick.draft_year == draft_year and pick.round_number == round_number and pick.original_team_id == original_team_id:
			return pick
	return null


static func picks_owned_by(league: LeagueState, team_id: String) -> Array[DraftPickData]:
	var picks: Array[DraftPickData] = []
	for pick in league.future_draft_picks:
		if league.current_draft != null and pick.draft_year == league.current_draft.draft_year:
			continue
		if pick.owner_team_id == team_id and not pick.is_used():
			picks.append(pick)
	_sort_future_picks(picks)
	return picks


static func trade_deadline_week(league: LeagueState) -> int:
	return mini(NFL_TRADE_DEADLINE_WEEK, maxi(1, ceili(float(league.league_format.regular_season_weeks) / 2.0)))


static func trades_open(league: LeagueState) -> bool:
	if league.phase == LeagueState.PHASE_REGULAR_SEASON:
		return league.current_week <= trade_deadline_week(league)
	return league.phase in [
		LeagueState.PHASE_SEASON_REVIEW,
		LeagueState.PHASE_RE_SIGNING,
		LeagueState.PHASE_PLAYER_DEVELOPMENT,
		LeagueState.PHASE_RETIREMENTS,
		"Complete",
	]


static func trade_window_label(league: LeagueState) -> String:
	if league.phase == LeagueState.PHASE_REGULAR_SEASON:
		if trades_open(league):
			return "OPEN THROUGH WEEK %d" % trade_deadline_week(league)
		return "CLOSED AFTER WEEK %d" % trade_deadline_week(league)
	if trades_open(league):
		return "OFFSEASON WINDOW OPEN"
	return "TRADING CLOSED DURING %s" % league.phase.to_upper()


static func preview_proposal(
	league: LeagueState,
	proposing_team_id: String,
	responding_team_id: String,
	proposer_player_ids: Array,
	responder_player_ids: Array,
	proposer_pick_ids: Array,
	responder_pick_ids: Array
) -> Dictionary:
	var proposer_players := _unique_ids(proposer_player_ids)
	var responder_players := _unique_ids(responder_player_ids)
	var proposer_picks := _unique_ids(proposer_pick_ids)
	var responder_picks := _unique_ids(responder_pick_ids)
	var errors := _validation_errors(
		league,
		proposing_team_id,
		responding_team_id,
		proposer_players,
		responder_players,
		proposer_picks,
		responder_picks
	)
	var proposer := league.team_by_id(proposing_team_id)
	var responder := league.team_by_id(responding_team_id)
	var incoming_value := 0
	var outgoing_value := 0
	if proposer != null and responder != null:
		incoming_value = package_value(league, proposer, responder, proposer_players, proposer_picks)
		outgoing_value = package_value(league, responder, proposer, responder_players, responder_picks)
	var threshold := _acceptance_threshold(league, responding_team_id)
	var ratio := float(incoming_value) / float(maxi(outgoing_value, 1))
	var interest := TradeProposalData.STATUS_REJECTED
	if ratio + 0.001 >= threshold:
		interest = TradeProposalData.STATUS_ACCEPTED
	elif ratio + 0.001 >= threshold * 0.78:
		interest = TradeProposalData.STATUS_COUNTERED
	var proposer_cap := _projected_payroll(league, proposer, proposer_players, responder_players, responder) if proposer != null else 0
	var responder_cap := _projected_payroll(league, responder, responder_players, proposer_players, proposer) if responder != null else 0
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"proposer_value": incoming_value,
		"responder_value": outgoing_value,
		"ratio": ratio,
		"threshold": threshold,
		"interest": interest,
		"proposer_projected_payroll": proposer_cap,
		"responder_projected_payroll": responder_cap,
		"proposer_player_ids": proposer_players,
		"responder_player_ids": responder_players,
		"proposer_pick_ids": proposer_picks,
		"responder_pick_ids": responder_picks,
	}


static func submit_proposal(
	league: LeagueState,
	proposing_team_id: String,
	responding_team_id: String,
	proposer_player_ids: Array,
	responder_player_ids: Array,
	proposer_pick_ids: Array,
	responder_pick_ids: Array
) -> Dictionary:
	var preview := preview_proposal(
		league,
		proposing_team_id,
		responding_team_id,
		proposer_player_ids,
		responder_player_ids,
		proposer_pick_ids,
		responder_pick_ids
	)
	if not bool(preview.get("ok", false)):
		return _failure(_first_error(preview), "Invalid")
	match str(preview.get("interest", TradeProposalData.STATUS_REJECTED)):
		TradeProposalData.STATUS_ACCEPTED:
			return execute_trade(
				league,
				proposing_team_id,
				responding_team_id,
				preview.get("proposer_player_ids", []),
				preview.get("responder_player_ids", []),
				preview.get("proposer_pick_ids", []),
				preview.get("responder_pick_ids", [])
			)
		TradeProposalData.STATUS_COUNTERED:
			var counter := _build_counter_offer(league, proposing_team_id, responding_team_id, preview)
			if not counter.is_empty():
				return {
					"ok": true,
					"executed": false,
					"status": TradeProposalData.STATUS_COUNTERED,
					"message": "%s will complete the deal with the revised package." % league.team_by_id(responding_team_id).display_name(),
					"counter": counter,
				}
	return _failure("The offer does not provide enough value for %s." % league.team_by_id(responding_team_id).display_name(), TradeProposalData.STATUS_REJECTED)


static func accept_counter(league: LeagueState, counter: Dictionary) -> Dictionary:
	var preview := preview_proposal(
		league,
		str(counter.get("proposing_team_id", "")),
		str(counter.get("responding_team_id", "")),
		counter.get("proposer_player_ids", []),
		counter.get("responder_player_ids", []),
		counter.get("proposer_pick_ids", []),
		counter.get("responder_pick_ids", [])
	)
	if not bool(preview.get("ok", false)):
		return _failure(_first_error(preview), "Invalid")
	if str(preview.get("interest", "")) != TradeProposalData.STATUS_ACCEPTED:
		return _failure("The counteroffer is no longer acceptable after the latest roster changes.", TradeProposalData.STATUS_REJECTED)
	return execute_trade(
		league,
		str(counter.get("proposing_team_id", "")),
		str(counter.get("responding_team_id", "")),
		preview.get("proposer_player_ids", []),
		preview.get("responder_player_ids", []),
		preview.get("proposer_pick_ids", []),
		preview.get("responder_pick_ids", [])
	)


static func execute_trade(
	league: LeagueState,
	proposing_team_id: String,
	responding_team_id: String,
	proposer_player_ids: Array,
	responder_player_ids: Array,
	proposer_pick_ids: Array,
	responder_pick_ids: Array
) -> Dictionary:
	var preview := preview_proposal(
		league,
		proposing_team_id,
		responding_team_id,
		proposer_player_ids,
		responder_player_ids,
		proposer_pick_ids,
		responder_pick_ids
	)
	if not bool(preview.get("ok", false)):
		return _failure(_first_error(preview), "Invalid")
	var proposer := league.team_by_id(proposing_team_id)
	var responder := league.team_by_id(responding_team_id)
	var normalized_proposer_players: Array[String] = preview.get("proposer_player_ids", [])
	var normalized_responder_players: Array[String] = preview.get("responder_player_ids", [])
	var normalized_proposer_picks: Array[String] = preview.get("proposer_pick_ids", [])
	var normalized_responder_picks: Array[String] = preview.get("responder_pick_ids", [])
	var proposer_labels := _asset_labels(league, proposer, normalized_proposer_players, normalized_proposer_picks)
	var responder_labels := _asset_labels(league, responder, normalized_responder_players, normalized_responder_picks)
	var proposer_old_payroll := proposer.payroll()
	var responder_old_payroll := responder.payroll()
	var moving_to_responder: Array[PlayerData] = []
	var moving_to_proposer: Array[PlayerData] = []
	for player_id in normalized_proposer_players:
		moving_to_responder.append(proposer.player_by_id(player_id))
	for player_id in normalized_responder_players:
		moving_to_proposer.append(responder.player_by_id(player_id))
	for player in moving_to_responder:
		proposer.remove_player(player.id)
		_apply_trade_contract_charge(proposer, player)
	for player in moving_to_proposer:
		responder.remove_player(player.id)
		_apply_trade_contract_charge(responder, player)
	var allowed_limit := TeamData.OFFSEASON_ROSTER_LIMIT if league.is_offseason() else proposer.roster_limit
	for player in moving_to_proposer:
		player.record_team(proposer.id)
		proposer.add_player(player, allowed_limit)
	allowed_limit = TeamData.OFFSEASON_ROSTER_LIMIT if league.is_offseason() else responder.roster_limit
	for player in moving_to_responder:
		player.record_team(responder.id)
		responder.add_player(player, allowed_limit)
	for pick_id in normalized_proposer_picks:
		future_pick_by_id(league, pick_id).owner_team_id = responder.id
	for pick_id in normalized_responder_picks:
		future_pick_by_id(league, pick_id).owner_team_id = proposer.id
	proposer.initialize_depth_chart()
	responder.initialize_depth_chart()
	proposer.configure_game_day_roster()
	responder.configure_game_day_roster()
	var record := TradeProposalData.new(
		"trade_%d_%d" % [league.season_year, league.trade_history.size() + 1],
		league.season_year,
		league.current_week,
		proposer.id,
		responder.id
	)
	record.proposer_player_ids = normalized_proposer_players.duplicate()
	record.responder_player_ids = normalized_responder_players.duplicate()
	record.proposer_pick_ids = normalized_proposer_picks.duplicate()
	record.responder_pick_ids = normalized_responder_picks.duplicate()
	record.proposer_asset_labels = proposer_labels
	record.responder_asset_labels = responder_labels
	record.proposer_value = int(preview.get("proposer_value", 0))
	record.responder_value = int(preview.get("responder_value", 0))
	record.status = TradeProposalData.STATUS_ACCEPTED
	record.summary = "%s send %s to %s for %s." % [
		proposer.display_name(),
		_package_label(proposer_labels),
		responder.display_name(),
		_package_label(responder_labels),
	]
	league.trade_history.push_front(record)
	while league.trade_history.size() > 100:
		league.trade_history.pop_back()
	_record_trade_transaction(league, proposer, responder, record, proposer.payroll() - proposer_old_payroll, true)
	_record_trade_transaction(league, responder, proposer, record, responder.payroll() - responder_old_payroll, false)
	league.reconcile_trade_market()
	return {
		"ok": true,
		"executed": true,
		"status": TradeProposalData.STATUS_ACCEPTED,
		"message": "Trade accepted. " + record.summary,
		"record": record,
	}


static func package_value(
	league: LeagueState,
	source_team: TeamData,
	receiving_team: TeamData,
	player_ids: Array,
	pick_ids: Array
) -> int:
	var total := 0
	for player_id in player_ids:
		var player := source_team.player_by_id(str(player_id)) if source_team != null else null
		if player != null:
			total += player_trade_value(player, receiving_team)
	for pick_id in pick_ids:
		var pick := future_pick_by_id(league, str(pick_id))
		if pick != null:
			total += draft_pick_value(league, pick)
	return total


static func player_trade_value(player: PlayerData, receiving_team: TeamData = null) -> int:
	var rating_band := maxi(player.overall - 50, 1)
	var value := float(rating_band * rating_band) * 1.2
	value += float(maxi(player.potential - player.overall, 0)) * 34.0
	var age_multiplier := 1.26 if player.age <= 23 else (1.16 if player.age <= 26 else (1.0 if player.age <= 29 else (0.80 if player.age <= 32 else 0.58)))
	value *= age_multiplier
	value *= float(POSITION_VALUES.get(player.position, 1.0))
	if receiving_team != null:
		var starter := receiving_team.player_at(player.position)
		if starter == null:
			value *= 1.18
		elif player.overall >= starter.overall + 3:
			value *= 1.10
		elif receiving_team.players_at(player.position).size() <= 2:
			value *= 1.05
	if player.contract != null:
		var salary_weight := float(player.contract.annual_salary) / 1_000_000.0
		value *= clampf(1.08 - salary_weight * 0.008, 0.70, 1.08)
		if player.contract.years_remaining >= 3 and player.age <= 27:
			value *= 1.07
	if player.injury_weeks > 0:
		value *= clampf(0.94 - float(player.injury_weeks) * 0.035, 0.68, 0.92)
	return maxi(1, roundi(value))


static func draft_pick_value(league: LeagueState, pick: DraftPickData) -> int:
	var base := int(PICK_VALUES.get(pick.round_number, 10))
	var years_out := maxi(pick.draft_year - (league.season_year + 1), 0)
	return maxi(1, roundi(float(base) * pow(0.82, years_out)))


static func pick_description(league: LeagueState, pick: DraftPickData) -> String:
	var original := league.team_by_id(pick.original_team_id)
	var original_label := original.abbreviation if original != null else pick.original_team_id.to_upper()
	return "%d ROUND %d · %s ORIGINAL" % [pick.draft_year, pick.round_number, original_label]


static func _validation_errors(
	league: LeagueState,
	proposing_team_id: String,
	responding_team_id: String,
	proposer_player_ids: Array[String],
	responder_player_ids: Array[String],
	proposer_pick_ids: Array[String],
	responder_pick_ids: Array[String]
) -> Array[String]:
	var errors: Array[String] = []
	if not trades_open(league):
		errors.append("The trade window is closed. %s." % trade_window_label(league).capitalize())
	var proposer := league.team_by_id(proposing_team_id)
	var responder := league.team_by_id(responding_team_id)
	if proposer == null or responder == null or proposer.id == responder.id:
		errors.append("Select two different valid clubs.")
		return errors
	if proposer_player_ids.is_empty() and proposer_pick_ids.is_empty():
		errors.append("%s must send at least one asset." % proposer.display_name())
	if responder_player_ids.is_empty() and responder_pick_ids.is_empty():
		errors.append("%s must send at least one asset." % responder.display_name())
	for player_id in proposer_player_ids:
		var player := proposer.player_by_id(player_id)
		if player == null:
			errors.append("An offered player is no longer on %s's roster." % proposer.display_name())
		elif player.contract == null:
			errors.append("%s cannot be traded without an active contract." % player.full_name)
	for player_id in responder_player_ids:
		var player := responder.player_by_id(player_id)
		if player == null:
			errors.append("A requested player is no longer on %s's roster." % responder.display_name())
		elif player.contract == null:
			errors.append("%s cannot be traded without an active contract." % player.full_name)
	for pick_id in proposer_pick_ids:
		var pick := future_pick_by_id(league, pick_id)
		if pick == null or pick.owner_team_id != proposer.id or pick.is_used():
			errors.append("An offered draft pick is no longer owned by %s." % proposer.display_name())
	for pick_id in responder_pick_ids:
		var pick := future_pick_by_id(league, pick_id)
		if pick == null or pick.owner_team_id != responder.id or pick.is_used():
			errors.append("A requested draft pick is no longer owned by %s." % responder.display_name())
	_validate_projected_team(league, proposer, proposer_player_ids, responder, responder_player_ids, errors)
	_validate_projected_team(league, responder, responder_player_ids, proposer, proposer_player_ids, errors)
	return errors


static func _validate_projected_team(
	league: LeagueState,
	team: TeamData,
	outgoing_ids: Array[String],
	incoming_team: TeamData,
	incoming_ids: Array[String],
	errors: Array[String]
) -> void:
	var projected_count := team.players.size() - outgoing_ids.size() + incoming_ids.size()
	var allowed_limit := TeamData.OFFSEASON_ROSTER_LIMIT if league.is_offseason() else team.roster_limit
	if projected_count > allowed_limit:
		errors.append("%s would exceed its %d-player roster limit." % [team.display_name(), allowed_limit])
	if projected_count < TeamData.MIN_ROSTER_SIZE:
		errors.append("%s would fall below the %d-player minimum." % [team.display_name(), TeamData.MIN_ROSTER_SIZE])
	var position_counts: Dictionary = {}
	for player in team.players:
		if player.id not in outgoing_ids:
			position_counts[player.position] = int(position_counts.get(player.position, 0)) + 1
	for player_id in incoming_ids:
		var player := incoming_team.player_by_id(player_id)
		if player != null:
			position_counts[player.position] = int(position_counts.get(player.position, 0)) + 1
	for position_name in TeamData.ROSTER_POSITIONS:
		if position_name == "LS" and team.roster_limit < TeamData.DEFAULT_ROSTER_LIMIT:
			continue
		if int(position_counts.get(position_name, 0)) <= 0:
			errors.append("%s would have no %s after the trade." % [team.display_name(), position_name])
	var projected_payroll := _projected_payroll(league, team, outgoing_ids, incoming_ids, incoming_team)
	if projected_payroll > team.salary_cap:
		errors.append("%s would exceed the salary cap by %s." % [team.display_name(), PlayerContract.money_label(projected_payroll - team.salary_cap)])


static func _projected_payroll(
	league: LeagueState,
	team: TeamData,
	outgoing_ids: Array,
	incoming_ids: Array,
	incoming_team: TeamData = null
) -> int:
	if team == null:
		return 0
	var projected := team.payroll()
	for player_id in outgoing_ids:
		var player := team.player_by_id(str(player_id))
		if player == null or player.contract == null:
			continue
		projected -= player.contract.annual_salary
		projected += player.contract.trade_penalty()
	if incoming_team != null:
		for player_id in incoming_ids:
			var player := incoming_team.player_by_id(str(player_id))
			if player != null and player.contract != null:
				projected += player.contract.annual_salary
	return projected


static func _build_counter_offer(
	league: LeagueState,
	proposing_team_id: String,
	responding_team_id: String,
	preview: Dictionary
) -> Dictionary:
	var proposer := league.team_by_id(proposing_team_id)
	var responder := league.team_by_id(responding_team_id)
	var proposer_players: Array[String] = preview.get("proposer_player_ids", []).duplicate()
	var responder_players: Array[String] = preview.get("responder_player_ids", []).duplicate()
	var proposer_picks: Array[String] = preview.get("proposer_pick_ids", []).duplicate()
	var responder_picks: Array[String] = preview.get("responder_pick_ids", []).duplicate()
	var candidates: Array[Dictionary] = []
	for player in proposer.players:
		if player.id not in proposer_players:
			candidates.append({"type": "player", "id": player.id, "value": player_trade_value(player, responder)})
	for pick in picks_owned_by(league, proposer.id):
		if pick.id not in proposer_picks:
			candidates.append({"type": "pick", "id": pick.id, "value": draft_pick_value(league, pick)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("value", 0)) < int(b.get("value", 0)))
	for candidate in candidates:
		var counter_players := proposer_players.duplicate()
		var counter_picks := proposer_picks.duplicate()
		if str(candidate.get("type", "")) == "player":
			counter_players.append(str(candidate.get("id", "")))
		else:
			counter_picks.append(str(candidate.get("id", "")))
		var counter_preview := preview_proposal(league, proposer.id, responder.id, counter_players, responder_players, counter_picks, responder_picks)
		if bool(counter_preview.get("ok", false)) and str(counter_preview.get("interest", "")) == TradeProposalData.STATUS_ACCEPTED:
			return _counter_dictionary(proposer.id, responder.id, counter_preview)
	var removable: Array[Dictionary] = []
	for player_id in responder_players:
		var player := responder.player_by_id(player_id)
		removable.append({"type": "player", "id": player_id, "value": player_trade_value(player, proposer)})
	for pick_id in responder_picks:
		var pick := future_pick_by_id(league, pick_id)
		removable.append({"type": "pick", "id": pick_id, "value": draft_pick_value(league, pick)})
	removable.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("value", 0)) > int(b.get("value", 0)))
	for candidate in removable:
		if responder_players.size() + responder_picks.size() <= 1:
			break
		var reduced_players := responder_players.duplicate()
		var reduced_picks := responder_picks.duplicate()
		if str(candidate.get("type", "")) == "player":
			reduced_players.erase(str(candidate.get("id", "")))
		else:
			reduced_picks.erase(str(candidate.get("id", "")))
		var reduced_preview := preview_proposal(league, proposer.id, responder.id, proposer_players, reduced_players, proposer_picks, reduced_picks)
		if bool(reduced_preview.get("ok", false)) and str(reduced_preview.get("interest", "")) == TradeProposalData.STATUS_ACCEPTED:
			return _counter_dictionary(proposer.id, responder.id, reduced_preview)
	return {}


static func _counter_dictionary(proposing_team_id: String, responding_team_id: String, preview: Dictionary) -> Dictionary:
	return {
		"proposing_team_id": proposing_team_id,
		"responding_team_id": responding_team_id,
		"proposer_player_ids": Array(preview.get("proposer_player_ids", [])).duplicate(),
		"responder_player_ids": Array(preview.get("responder_player_ids", [])).duplicate(),
		"proposer_pick_ids": Array(preview.get("proposer_pick_ids", [])).duplicate(),
		"responder_pick_ids": Array(preview.get("responder_pick_ids", [])).duplicate(),
		"proposer_value": int(preview.get("proposer_value", 0)),
		"responder_value": int(preview.get("responder_value", 0)),
	}


static func _asset_labels(league: LeagueState, team: TeamData, player_ids: Array, pick_ids: Array) -> Array[String]:
	var labels: Array[String] = []
	for player_id in player_ids:
		var player := team.player_by_id(str(player_id))
		if player != null:
			labels.append("%s (%s, %d OVR)" % [player.full_name, player.position, player.overall])
	for pick_id in pick_ids:
		var pick := future_pick_by_id(league, str(pick_id))
		if pick != null:
			labels.append(pick_description(league, pick).capitalize())
	return labels


static func _package_label(labels: Array[String]) -> String:
	if labels.is_empty():
		return "no assets"
	if labels.size() == 1:
		return labels.front()
	return ", ".join(labels)


static func _apply_trade_contract_charge(team: TeamData, player: PlayerData) -> void:
	if player.contract == null:
		return
	var penalty := player.contract.trade_penalty()
	team.dead_cap += penalty
	player.contract.guaranteed_money = maxi(player.contract.guaranteed_money - penalty, 0)


static func _record_trade_transaction(
	league: LeagueState,
	team: TeamData,
	partner: TeamData,
	record: TradeProposalData,
	cap_change: int,
	add_news: bool
) -> void:
	var transaction := TransactionData.new(
		"%s_%s" % [record.id, team.id],
		league.season_year,
		league.current_week,
		"Trade",
		team.id,
		"",
		"Trade with %s" % partner.display_name(),
		record.summary,
		cap_change
	)
	if add_news:
		league.record_transaction(transaction, "%s and %s complete a trade." % [team.display_name(), partner.display_name()])
	else:
		league.transactions.push_front(transaction)
		while league.transactions.size() > 100:
			league.transactions.pop_back()


static func _acceptance_threshold(league: LeagueState, responding_team_id: String) -> float:
	var personality_seed := absi(responding_team_id.hash() + league.season_seed + league.season_year * 97)
	return 0.92 + float(personality_seed % 6) * 0.01


static func _unique_ids(values: Array) -> Array[String]:
	var unique: Array[String] = []
	for value in values:
		var id := str(value)
		if not id.is_empty() and id not in unique:
			unique.append(id)
	return unique


static func _future_pick_id(draft_year: int, round_number: int, team_id: String) -> String:
	return "future_%d_r%d_%s" % [draft_year, round_number, team_id]


static func _sort_future_picks(picks: Array[DraftPickData]) -> void:
	picks.sort_custom(func(a: DraftPickData, b: DraftPickData):
		if a.draft_year != b.draft_year:
			return a.draft_year < b.draft_year
		if a.round_number != b.round_number:
			return a.round_number < b.round_number
		return a.original_team_id < b.original_team_id
	)


static func _first_error(preview: Dictionary) -> String:
	var errors: Array = preview.get("errors", [])
	return str(errors.front()) if not errors.is_empty() else "The trade could not be completed."


static func _failure(message: String, status: String) -> Dictionary:
	return {"ok": false, "executed": false, "status": status, "message": message}
