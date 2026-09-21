class_name CareerSession
extends RefCounted

var league: LeagueState
var active_simulator: FootballSimulator
var active_matchup: MatchupData
var active_week_simulation: WeekSimulationTask


func _init(state: LeagueState = null) -> void:
	league = state


static func new_career(
	team_id: String,
	seed: int,
	source_id: String = LeagueCatalog.SOURCE_NFLVERSE_FULL,
	career_mode: String = LeagueState.CAREER_MODE_STANDARD
) -> CareerSession:
	var state := LeagueSimulator.create_season(team_id, seed, source_id)
	if state != null:
		RosterTransactionService.initialize_league(state)
	if state != null and career_mode == LeagueState.CAREER_MODE_FANTASY_DRAFT:
		FantasyDraftService.initialize(state)
	if state != null:
		TradeMarketService.initialize_market(state)
		CoachProgressionService.initialize(state)
	return CareerSession.new(state)


static func from_dict(data: Dictionary) -> CareerSession:
	var state := LeagueState.from_dict(data.get("league", {}))
	TradeMarketService.initialize_market(state)
	CoachProgressionService.initialize(state)
	return CareerSession.new(state)


func to_dict() -> Dictionary:
	return {"league": league.to_dict()}


func user_team() -> TeamData:
	return league.user_team()


func coach_change_error() -> String:
	if active_simulator != null or active_week_simulation != null:
		return "Complete the active game or week before changing coaching skills."
	if league.is_fantasy_draft_active():
		return "Complete the fantasy draft before developing your coach."
	return ""


func learn_coach_skill(skill_id: String) -> Dictionary:
	var error := coach_change_error()
	if not error.is_empty():
		return {"ok": false, "message": error}
	return CoachProgressionService.unlock(user_team().coach, skill_id)


func choose_coach_background(background: String) -> Dictionary:
	var error := coach_change_error()
	if not error.is_empty():
		return {"ok": false, "message": error}
	return CoachProgressionService.choose_background(user_team().coach, background)


func retrain_coach() -> Dictionary:
	var error := coach_change_error()
	if not error.is_empty():
		return {"ok": false, "message": error}
	return CoachProgressionService.respec(league, user_team().coach)


func current_matchup() -> MatchupData:
	return league.current_user_matchup()


func next_opponent() -> TeamData:
	var matchup := current_matchup()
	return league.team_by_id(matchup.opponent_id(league.user_team_id)) if matchup != null else null


func current_game_plan() -> WeeklyGamePlanData:
	return GamePlanningService.current_user_plan(league)


func current_opponent_report() -> OpponentScoutingReportData:
	var opponent := next_opponent()
	return GamePlanningService.build_report(league, opponent.id, league.user_team_id) if opponent != null else null


func save_game_plan(
	offensive_focus: String,
	defensive_focus: String,
	offensive_points: int,
	defensive_points: int
) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the weekly plan."}
	return GamePlanningService.save_user_plan(
		league,
		offensive_focus,
		defensive_focus,
		offensive_points,
		defensive_points
	)


func sign_free_agent(player_id: String, years: int, offer_multiplier: float) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return TransactionService.sign_free_agent(league, league.user_team_id, player_id, years, offer_multiplier)


func release_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return TransactionService.release_player(league, league.user_team_id, player_id)


func place_player_on_injured_reserve(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.place_on_injured_reserve(league, league.user_team_id, player_id)


func activate_player_from_injured_reserve(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.activate_from_injured_reserve(league, league.user_team_id, player_id)


func set_player_game_day_active(player_id: String, active: bool) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the game-day list."}
	return RosterTransactionService.set_game_day_active(league, league.user_team_id, player_id, active)


func sign_practice_squad_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.sign_to_practice_squad(league, league.user_team_id, player_id)


func assign_roster_player_to_practice_squad(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.move_to_practice_squad(league, league.user_team_id, player_id)


func promote_practice_squad_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.promote_from_practice_squad(league, league.user_team_id, player_id)


func release_practice_squad_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.release_from_practice_squad(league, league.user_team_id, player_id)


func poach_practice_squad_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return RosterTransactionService.poach_practice_squad_player(league, league.user_team_id, player_id)


func submit_waiver_claim(entry_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before submitting a waiver claim."}
	return RosterTransactionService.submit_waiver_claim(league, league.user_team_id, entry_id)


func withdraw_waiver_claim(entry_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing a waiver claim."}
	return RosterTransactionService.withdraw_waiver_claim(league, league.user_team_id, entry_id)


func game_day_errors() -> Array[String]:
	return RosterValidator.validate_game_day_roster(user_team())


func preview_trade(
	partner_team_id: String,
	user_player_ids: Array,
	partner_player_ids: Array,
	user_pick_ids: Array,
	partner_pick_ids: Array
) -> Dictionary:
	return TradeService.preview_proposal(
		league,
		league.user_team_id,
		partner_team_id,
		user_player_ids,
		partner_player_ids,
		user_pick_ids,
		partner_pick_ids
	)


func submit_trade(
	partner_team_id: String,
	user_player_ids: Array,
	partner_player_ids: Array,
	user_pick_ids: Array,
	partner_pick_ids: Array
) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "executed": false, "status": "Invalid", "message": "Complete the active game before proposing a trade."}
	var result := TradeService.submit_proposal(
		league,
		league.user_team_id,
		partner_team_id,
		user_player_ids,
		partner_player_ids,
		user_pick_ids,
		partner_pick_ids
	)
	if bool(result.get("executed", false)):
		league.reconcile_trade_market()
	return result


func accept_trade_counter(counter: Dictionary, source_offer_id: String = "") -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "executed": false, "status": "Invalid", "message": "Complete the active game before accepting a trade."}
	if str(counter.get("proposing_team_id", "")) != league.user_team_id:
		return {"ok": false, "executed": false, "status": "Invalid", "message": "The counteroffer does not belong to this club."}
	var result := TradeService.accept_counter(league, counter)
	if bool(result.get("executed", false)):
		league.reconcile_trade_market()
		if not source_offer_id.is_empty():
			TradeMarketService.mark_counter_offer_completed(league, source_offer_id)
	return result


func toggle_trade_block(player_id: String, listed: bool) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the trade block."}
	return TradeMarketService.toggle_user_trade_block(league, player_id, listed)


func accept_incoming_trade_offer(offer_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before accepting a trade offer."}
	return TradeMarketService.accept_incoming_offer(league, offer_id)


func decline_incoming_trade_offer(offer_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before declining a trade offer."}
	return TradeMarketService.decline_incoming_offer(league, offer_id)


func counter_incoming_trade_offer(
	offer_id: String,
	user_player_ids: Array,
	partner_player_ids: Array,
	user_pick_ids: Array,
	partner_pick_ids: Array
) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before countering a trade offer."}
	return TradeMarketService.submit_incoming_counter(
		league,
		offer_id,
		user_player_ids,
		partner_player_ids,
		user_pick_ids,
		partner_pick_ids
	)


func extend_player(player_id: String, years: int, offer_multiplier: float) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before negotiating a contract."}
	if league.phase != LeagueState.PHASE_RE_SIGNING:
		return {"ok": false, "message": "Extensions are available during the re-signing stage."}
	return TransactionService.extend_player(league, league.user_team_id, player_id, years, offer_multiplier)


func advance_offseason() -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before advancing the offseason."}
	return OffseasonService.advance_stage(league)


func scout_prospect(prospect_id: String) -> Dictionary:
	return DraftService.scout_prospect(league, prospect_id)


func toggle_draft_favorite(prospect_id: String) -> Dictionary:
	return DraftService.toggle_favorite(league, prospect_id)


func select_draft_prospect(prospect_id: String) -> Dictionary:
	var result := DraftService.select_user_prospect(league, prospect_id)
	if bool(result.get("ok", false)) and league.phase == LeagueState.PHASE_ROSTER_DECISIONS:
		OffseasonService.prepare_post_draft_ai_rosters(league)
	return result


func auto_pick_draft_selection() -> Dictionary:
	var result := DraftService.auto_pick_user(league)
	if bool(result.get("ok", false)) and league.phase == LeagueState.PHASE_ROSTER_DECISIONS:
		OffseasonService.prepare_post_draft_ai_rosters(league)
	return result


func start_fantasy_draft() -> Dictionary:
	return FantasyDraftService.start(league)


func select_fantasy_player(player_id: String) -> Dictionary:
	return FantasyDraftService.select_user_player(league, player_id)


func auto_pick_fantasy_selection() -> Dictionary:
	return FantasyDraftService.auto_pick_user(league)


func simulate_fantasy_to_user_pick() -> Dictionary:
	return FantasyDraftService.simulate_to_user_pick(league)


func simulate_fantasy_draft() -> Dictionary:
	return FantasyDraftService.simulate_remainder(league)


func expiring_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	for player in user_team().all_contract_players():
		if player.contract != null and player.contract.is_expiring_after(league.season_year):
			players.append(player)
	players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return players


func begin_user_game() -> FootballSimulator:
	if active_simulator != null:
		return active_simulator
	if league.is_offseason():
		return null
	if not game_day_errors().is_empty():
		return null
	active_matchup = current_matchup()
	if active_matchup == null or active_matchup.played:
		return null
	LeagueSimulator.prepare_current_week(league)
	var home := league.team_by_id(active_matchup.home_team_id)
	var away := league.team_by_id(active_matchup.away_team_id)
	var game_seed := league.season_seed + league.current_week * 1009 + active_matchup.id.hash()
	var plans: Dictionary = {}
	for team_id in [active_matchup.away_team_id, active_matchup.home_team_id]:
		var plan := GamePlanningService.plan_for_matchup(league, active_matchup, team_id, true)
		if plan != null:
			plans[team_id] = plan
	active_simulator = FootballSimulator.new(home, away, game_seed, active_matchup.phase != "Regular Season", null, null, plans)
	return active_simulator


func complete_user_game() -> void:
	var task := start_postgame_simulation()
	while task != null and not task.is_complete():
		advance_week_simulation(task)


func simulate_current_week() -> void:
	var task := start_week_simulation()
	while task != null and not task.is_complete():
		advance_week_simulation(task)


func start_week_simulation() -> WeekSimulationTask:
	if active_week_simulation != null and not active_week_simulation.is_complete():
		return active_week_simulation
	if league.is_offseason() or active_simulator != null:
		return null
	if current_matchup() != null and not game_day_errors().is_empty():
		return null
	active_week_simulation = WeekSimulationTask.new(
		WeekSimulationTask.MODE_FULL_WEEK,
		league.current_week,
		_unplayed_current_week_matchups()
	)
	return active_week_simulation


func start_postgame_simulation() -> WeekSimulationTask:
	if active_week_simulation != null and not active_week_simulation.is_complete():
		return active_week_simulation
	if active_simulator == null or active_matchup == null or not active_simulator.state.is_final:
		return null
	var remaining := _unplayed_current_week_matchups()
	remaining.erase(active_matchup)
	active_week_simulation = WeekSimulationTask.new(
		WeekSimulationTask.MODE_POSTGAME,
		league.current_week,
		remaining
	)
	return active_week_simulation


func advance_week_simulation(task: WeekSimulationTask) -> bool:
	if task == null or task != active_week_simulation or task.is_complete():
		return false
	match task.stage:
		WeekSimulationTask.STAGE_PREPARE:
			LeagueSimulator.prepare_current_week(league)
			if task.mode == WeekSimulationTask.MODE_POSTGAME:
				LeagueSimulator.process_played_matchup(league, active_matchup, active_simulator.state)
			task.completed_units += 1
			if task.pending_matchups.is_empty():
				_set_league_operations_stage(task)
			else:
				task.stage = WeekSimulationTask.STAGE_GAMES
				_set_matchup_progress(task)
		WeekSimulationTask.STAGE_GAMES:
			var matchup := task.pending_matchups[task.next_matchup_index]
			LeagueSimulator.simulate_matchup(league, matchup)
			task.next_matchup_index += 1
			task.completed_units += 1
			if task.next_matchup_index >= task.pending_matchups.size():
				_set_league_operations_stage(task)
			else:
				_set_matchup_progress(task)
		WeekSimulationTask.STAGE_LEAGUE_OPERATIONS:
			_add_week_news(task.completed_week)
			_run_ai_front_offices()
			task.completed_units += 1
			task.stage = WeekSimulationTask.STAGE_FINALIZE
			task.status_text = "UPDATING LEAGUE TABLES"
			task.detail_text = "Finalizing standings, playoff position, records, and the league calendar."
		WeekSimulationTask.STAGE_FINALIZE:
			league.advance_after_completed_week()
			if task.mode == WeekSimulationTask.MODE_POSTGAME:
				active_simulator = null
				active_matchup = null
			task.completed_units = task.total_units
			task.stage = WeekSimulationTask.STAGE_COMPLETE
			task.status_text = "WEEK COMPLETE"
			task.detail_text = "Every result and roster update has been finalized."
			active_week_simulation = null
	return true


func _unplayed_current_week_matchups() -> Array[MatchupData]:
	var matchups: Array[MatchupData] = []
	for matchup in league.matchups_for_week(league.current_week):
		if not matchup.played:
			matchups.append(matchup)
	return matchups


func _set_matchup_progress(task: WeekSimulationTask) -> void:
	var matchup := task.pending_matchups[task.next_matchup_index]
	var away := league.team_by_id(matchup.away_team_id)
	var home := league.team_by_id(matchup.home_team_id)
	task.status_text = "SIMULATING %s @ %s" % [away.abbreviation, home.abbreviation]
	task.detail_text = "League game %d of %d · processing plays, statistics, fatigue, and injuries." % [task.next_matchup_index + 1, task.pending_matchups.size()]


func _set_league_operations_stage(task: WeekSimulationTask) -> void:
	task.stage = WeekSimulationTask.STAGE_LEAGUE_OPERATIONS
	task.status_text = "PROCESSING LEAGUE OPERATIONS"
	task.detail_text = "Resolving injuries, AI roster decisions, practice squads, waivers, and weekly news."


func current_week_label() -> String:
	if league.is_offseason():
		return league.phase.to_upper()
	if league.phase == LeagueState.PHASE_CHAMPIONSHIP:
		return "CHAMPIONSHIP WEEK"
	if league.phase == LeagueState.PHASE_PLAYOFFS:
		var playoff_round := league.current_week - league.league_format.regular_season_weeks
		return ["WILD CARD", "DIVISIONAL", "CONFERENCE CHAMPIONSHIP"][clampi(playoff_round - 1, 0, 2)]
	return "WEEK %d OF %d" % [league.current_week, league.league_format.regular_season_weeks]


func _add_week_news(completed_week: int) -> void:
	var user_result: MatchupData
	for matchup in league.matchups_for_week(completed_week):
		if matchup.includes(league.user_team_id):
			user_result = matchup
			break
	if user_result != null:
		var opponent := league.team_by_id(user_result.opponent_id(league.user_team_id))
		var user_is_away := user_result.away_team_id == league.user_team_id
		var user_score := user_result.away_score if user_is_away else user_result.home_score
		var opponent_score := user_result.home_score if user_is_away else user_result.away_score
		var outcome := "defeats" if user_score > opponent_score else ("falls to" if user_score < opponent_score else "draws with")
		league.news.push_front("%s %s %s, %d–%d." % [league.user_team().display_name(), outcome, opponent.display_name(), user_score, opponent_score])
	for player in league.user_team().injured_players():
		league.news.push_front("Medical update: %s is managing a %s." % [player.full_name, player.injury_type.to_lower()])
	while league.news.size() > 12:
		league.news.pop_back()


func _run_ai_front_offices() -> void:
	if not league.is_offseason():
		RosterTransactionService.run_ai_roster_management(league)
	if league.current_week <= league.league_format.regular_season_weeks:
		TransactionService.run_ai_roster_moves(league)
	TradeMarketService.process_week(league)
