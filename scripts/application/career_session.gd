class_name CareerSession
extends RefCounted

var league: LeagueState
var active_simulator: FootballSimulator
var active_matchup: MatchupData


func _init(state: LeagueState = null) -> void:
	league = state


static func new_career(team_id: String, seed: int, source_id: String = LeagueCatalog.SOURCE_NFLVERSE_FULL) -> CareerSession:
	return CareerSession.new(LeagueSimulator.create_season(team_id, seed, source_id))


static func from_dict(data: Dictionary) -> CareerSession:
	return CareerSession.new(LeagueState.from_dict(data.get("league", {})))


func to_dict() -> Dictionary:
	return {"league": league.to_dict()}


func user_team() -> TeamData:
	return league.user_team()


func current_matchup() -> MatchupData:
	return league.current_user_matchup()


func next_opponent() -> TeamData:
	var matchup := current_matchup()
	return league.team_by_id(matchup.opponent_id(league.user_team_id)) if matchup != null else null


func sign_free_agent(player_id: String, years: int, offer_multiplier: float) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return TransactionService.sign_free_agent(league, league.user_team_id, player_id, years, offer_multiplier)


func release_player(player_id: String) -> Dictionary:
	if active_simulator != null:
		return {"ok": false, "message": "Complete the active game before changing the roster."}
	return TransactionService.release_player(league, league.user_team_id, player_id)


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


func expiring_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	for player in user_team().players:
		if player.contract != null and player.contract.is_expiring_after(league.season_year):
			players.append(player)
	players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return players


func begin_user_game() -> FootballSimulator:
	if active_simulator != null:
		return active_simulator
	if league.is_offseason():
		return null
	active_matchup = current_matchup()
	if active_matchup == null or active_matchup.played:
		return null
	LeagueSimulator.prepare_current_week(league)
	var home := league.team_by_id(active_matchup.home_team_id)
	var away := league.team_by_id(active_matchup.away_team_id)
	var game_seed := league.season_seed + league.current_week * 1009 + active_matchup.id.hash()
	active_simulator = FootballSimulator.new(home, away, game_seed, active_matchup.phase != "Regular Season")
	return active_simulator


func complete_user_game() -> void:
	if active_simulator == null or active_matchup == null or not active_simulator.state.is_final:
		return
	var completed_week := league.current_week
	LeagueSimulator.process_played_matchup(league, active_matchup, active_simulator.state)
	LeagueSimulator.simulate_remaining_week(league)
	_add_week_news(completed_week)
	_run_ai_front_offices()
	league.advance_after_completed_week()
	active_simulator = null
	active_matchup = null


func simulate_current_week() -> void:
	if league.is_offseason() or active_simulator != null:
		return
	var completed_week := league.current_week
	LeagueSimulator.prepare_current_week(league)
	LeagueSimulator.simulate_remaining_week(league)
	_add_week_news(completed_week)
	_run_ai_front_offices()
	league.advance_after_completed_week()


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
	if league.current_week <= league.league_format.regular_season_weeks:
		TransactionService.run_ai_roster_moves(league)
