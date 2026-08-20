class_name LeagueState
extends RefCounted

const REGULAR_SEASON_WEEKS := 7
const CHAMPIONSHIP_WEEK := 8
const PHASE_REGULAR_SEASON := "Regular Season"
const PHASE_CHAMPIONSHIP := "Championship"
const PHASE_SEASON_REVIEW := "Season Review"
const PHASE_RE_SIGNING := "Re-signing"
const PHASE_PLAYER_DEVELOPMENT := "Player Development"
const PHASE_RETIREMENTS := "Retirements"
const PHASE_DRAFT_PREPARATION := "Draft Preparation"
const PHASE_DRAFT := "Draft"
const PHASE_ROSTER_DECISIONS := "Roster Decisions"

var season_year := 2026
var current_week := 1
var phase := PHASE_REGULAR_SEASON
var user_team_id: String
var champion_team_id := ""
var season_seed := 0
var prepared_week := 0
var teams: Array[TeamData] = []
var schedule: Array[MatchupData] = []
var standings: Dictionary = {}
var news: Array[String] = []
var free_agents: Array[PlayerData] = []
var transactions: Array[TransactionData] = []
var season_history: Array[SeasonHistoryData] = []
var development_reports: Array[DevelopmentReportData] = []
var retired_players: Array[RetiredPlayerData] = []
var last_retirement_year := 0
var current_draft: DraftStateData
var draft_history: Array[DraftStateData] = []


func _init(league_teams: Array[TeamData] = [], selected_team_id: String = "", seed: int = 0) -> void:
	teams = league_teams
	user_team_id = selected_team_id
	season_seed = seed
	for team in teams:
		standings[team.id] = StandingData.new(team.id)


func team_by_id(team_id: String) -> TeamData:
	for team in teams:
		if team.id == team_id:
			return team
	return null


func user_team() -> TeamData:
	return team_by_id(user_team_id)


func is_offseason() -> bool:
	return phase in [
		PHASE_SEASON_REVIEW,
		PHASE_RE_SIGNING,
		PHASE_PLAYER_DEVELOPMENT,
		PHASE_RETIREMENTS,
		PHASE_DRAFT_PREPARATION,
		PHASE_DRAFT,
		PHASE_ROSTER_DECISIONS,
		"Complete",
	]


func contract_start_year() -> int:
	return season_year + 1 if is_offseason() else season_year


func free_agent_by_id(player_id: String) -> PlayerData:
	for player in free_agents:
		if player.id == player_id:
			return player
	return null


func record_transaction(transaction: TransactionData, headline: String) -> void:
	transactions.push_front(transaction)
	news.push_front(headline)
	while transactions.size() > 100:
		transactions.pop_back()
	while news.size() > 12:
		news.pop_back()


func recent_transactions(limit: int = 12) -> Array[TransactionData]:
	return transactions.slice(0, mini(limit, transactions.size()))


func matchups_for_week(week_number: int) -> Array[MatchupData]:
	var matches: Array[MatchupData] = []
	for matchup in schedule:
		if matchup.week == week_number:
			matches.append(matchup)
	return matches


func current_user_matchup() -> MatchupData:
	if is_offseason():
		return null
	for matchup in matchups_for_week(current_week):
		if matchup.includes(user_team_id):
			return matchup
	return null


func standing_for(team_id: String) -> StandingData:
	return standings.get(team_id)


func sorted_standings(conference: String = "") -> Array[StandingData]:
	var ordered: Array[StandingData] = []
	for team in teams:
		if conference.is_empty() or team.conference == conference:
			ordered.append(standing_for(team.id))
	ordered.sort_custom(func(a: StandingData, b: StandingData):
		if not is_equal_approx(a.win_percentage(), b.win_percentage()):
			return a.win_percentage() > b.win_percentage()
		if a.point_differential() != b.point_differential():
			return a.point_differential() > b.point_differential()
		return a.points_for > b.points_for
	)
	return ordered


func record_game(matchup: MatchupData, game: GameStateData) -> void:
	if matchup.played:
		return
	matchup.played = true
	matchup.away_score = game.away_score
	matchup.home_score = game.home_score
	matchup.away_stats = game.stats.get(matchup.away_team_id, {}).duplicate(true)
	matchup.home_stats = game.stats.get(matchup.home_team_id, {}).duplicate(true)
	if matchup.phase != "Regular Season":
		return
	var away_standing := standing_for(matchup.away_team_id)
	var home_standing := standing_for(matchup.home_team_id)
	away_standing.points_for += matchup.away_score
	away_standing.points_against += matchup.home_score
	home_standing.points_for += matchup.home_score
	home_standing.points_against += matchup.away_score
	var conference_game := team_by_id(matchup.away_team_id).conference == team_by_id(matchup.home_team_id).conference
	if matchup.away_score > matchup.home_score:
		away_standing.wins += 1
		home_standing.losses += 1
		if conference_game:
			away_standing.conference_wins += 1
			home_standing.conference_losses += 1
	elif matchup.home_score > matchup.away_score:
		home_standing.wins += 1
		away_standing.losses += 1
		if conference_game:
			home_standing.conference_wins += 1
			away_standing.conference_losses += 1
	else:
		away_standing.ties += 1
		home_standing.ties += 1


func week_complete() -> bool:
	var matchups := matchups_for_week(current_week)
	if matchups.is_empty():
		return false
	for matchup in matchups:
		if not matchup.played:
			return false
	return true


func ensure_championship_matchup() -> void:
	if not matchups_for_week(CHAMPIONSHIP_WEEK).is_empty():
		return
	var atlantic := sorted_standings("Atlantic")
	var frontier := sorted_standings("Frontier")
	if atlantic.is_empty() or frontier.is_empty():
		return
	var atlantic_champion: String = atlantic.front().team_id
	var frontier_champion: String = frontier.front().team_id
	schedule.append(MatchupData.new(
		"championship_%d" % season_year,
		CHAMPIONSHIP_WEEK,
		frontier_champion,
		atlantic_champion,
		"Championship"
	))


func advance_after_completed_week() -> void:
	if not week_complete():
		return
	if current_week < REGULAR_SEASON_WEEKS:
		current_week += 1
		return
	if current_week == REGULAR_SEASON_WEEKS:
		ensure_championship_matchup()
		current_week = CHAMPIONSHIP_WEEK
		phase = PHASE_CHAMPIONSHIP
		return
	var championship := matchups_for_week(CHAMPIONSHIP_WEEK)
	if not championship.is_empty():
		champion_team_id = championship.front().winner_id()
	_archive_current_season()
	phase = PHASE_SEASON_REVIEW


func latest_season_record() -> SeasonHistoryData:
	return season_history.back() if not season_history.is_empty() else null


func development_reports_for(team_id: String, year: int = 0) -> Array[DevelopmentReportData]:
	var reports: Array[DevelopmentReportData] = []
	for report in development_reports:
		if report.team_id == team_id and (year <= 0 or report.season_year == year):
			reports.append(report)
	reports.sort_custom(func(a: DevelopmentReportData, b: DevelopmentReportData):
		if a.overall_change() != b.overall_change():
			return a.overall_change() > b.overall_change()
		return a.new_overall > b.new_overall
	)
	return reports


func retired_players_for_year(year: int, team_id: String = "") -> Array[RetiredPlayerData]:
	var records: Array[RetiredPlayerData] = []
	for record in retired_players:
		if record.retirement_year != year:
			continue
		if not team_id.is_empty() and record.final_team_id != team_id:
			continue
		records.append(record)
	records.sort_custom(func(a: RetiredPlayerData, b: RetiredPlayerData):
		if a.peak_overall != b.peak_overall:
			return a.peak_overall > b.peak_overall
		return a.age > b.age
	)
	return records


func recent_results(limit: int = 6) -> Array[MatchupData]:
	var results: Array[MatchupData] = []
	for matchup in schedule:
		if matchup.played:
			results.append(matchup)
	results.sort_custom(func(a: MatchupData, b: MatchupData): return a.week > b.week)
	return results.slice(0, mini(limit, results.size()))


func team_leaders() -> Dictionary:
	var scoring: StandingData
	var defense: StandingData
	var differential: StandingData
	for standing: StandingData in standings.values():
		if scoring == null or standing.points_for > scoring.points_for:
			scoring = standing
		if defense == null or standing.points_against < defense.points_against:
			defense = standing
		if differential == null or standing.point_differential() > differential.point_differential():
			differential = standing
	return {"scoring": scoring, "defense": defense, "differential": differential}


func to_dict() -> Dictionary:
	var team_data: Array[Dictionary] = []
	for team in teams:
		team_data.append(team.to_dict())
	var matchup_data: Array[Dictionary] = []
	for matchup in schedule:
		matchup_data.append(matchup.to_dict())
	var standing_data: Dictionary = {}
	for team_id: String in standings:
		standing_data[team_id] = standing_for(team_id).to_dict()
	var free_agent_data: Array[Dictionary] = []
	for player in free_agents:
		free_agent_data.append(player.to_dict())
	var transaction_data: Array[Dictionary] = []
	for transaction in transactions:
		transaction_data.append(transaction.to_dict())
	var history_data: Array[Dictionary] = []
	for record in season_history:
		history_data.append(record.to_dict())
	var development_data: Array[Dictionary] = []
	for report in development_reports:
		development_data.append(report.to_dict())
	var draft_history_data: Array[Dictionary] = []
	for draft in draft_history:
		draft_history_data.append(draft.to_dict())
	var retired_player_data: Array[Dictionary] = []
	for retired_player in retired_players:
		retired_player_data.append(retired_player.to_dict())
	return {
		"season_year": season_year,
		"current_week": current_week,
		"phase": phase,
		"user_team_id": user_team_id,
		"champion_team_id": champion_team_id,
		"season_seed": season_seed,
		"prepared_week": prepared_week,
		"teams": team_data,
		"schedule": matchup_data,
		"standings": standing_data,
		"news": news.duplicate(),
		"free_agents": free_agent_data,
		"transactions": transaction_data,
		"season_history": history_data,
		"development_reports": development_data,
		"retired_players": retired_player_data,
		"last_retirement_year": last_retirement_year,
		"current_draft": current_draft.to_dict() if current_draft != null else null,
		"draft_history": draft_history_data,
	}


static func from_dict(data: Dictionary) -> LeagueState:
	var loaded_teams: Array[TeamData] = []
	for team_data in data.get("teams", []):
		loaded_teams.append(TeamData.from_dict(team_data))
	var league := LeagueState.new(
		loaded_teams,
		str(data.get("user_team_id", "")),
		int(data.get("season_seed", 0))
	)
	league.season_year = int(data.get("season_year", 2026))
	league.current_week = int(data.get("current_week", 1))
	league.phase = str(data.get("phase", "Regular Season"))
	league.champion_team_id = str(data.get("champion_team_id", ""))
	league.prepared_week = int(data.get("prepared_week", 0))
	league.schedule.clear()
	for matchup_data in data.get("schedule", []):
		league.schedule.append(MatchupData.from_dict(matchup_data))
	league.standings.clear()
	var saved_standings: Dictionary = data.get("standings", {})
	for team in loaded_teams:
		league.standings[team.id] = StandingData.from_dict(saved_standings.get(team.id, {"team_id": team.id}))
	for item in data.get("news", []):
		league.news.append(str(item))
	for free_agent_data in data.get("free_agents", []):
		league.free_agents.append(PlayerData.from_dict(free_agent_data))
	for transaction_data in data.get("transactions", []):
		league.transactions.append(TransactionData.from_dict(transaction_data))
	for history_data in data.get("season_history", []):
		league.season_history.append(SeasonHistoryData.from_dict(history_data))
	for report_data in data.get("development_reports", []):
		league.development_reports.append(DevelopmentReportData.from_dict(report_data))
	for retired_data in data.get("retired_players", []):
		league.retired_players.append(RetiredPlayerData.from_dict(retired_data))
	league.last_retirement_year = int(data.get("last_retirement_year", 0))
	var current_draft_data = data.get("current_draft")
	if current_draft_data is Dictionary:
		league.current_draft = DraftStateData.from_dict(current_draft_data)
	for draft_data in data.get("draft_history", []):
		league.draft_history.append(DraftStateData.from_dict(draft_data))
	if league.phase == "Complete":
		league._archive_current_season()
		league.phase = PHASE_SEASON_REVIEW
	return league


func _archive_current_season() -> void:
	for existing in season_history:
		if existing.season_year == season_year:
			return
	var championship_games := matchups_for_week(CHAMPIONSHIP_WEEK)
	if championship_games.is_empty() or not championship_games.front().played:
		return
	var title_game: MatchupData = championship_games.front()
	var runner_up_id := title_game.home_team_id if champion_team_id == title_game.away_team_id else title_game.away_team_id
	var user_standing := standing_for(user_team_id)
	var record := SeasonHistoryData.new(
		season_year,
		user_team_id,
		champion_team_id,
		runner_up_id,
		user_standing.record_label() if user_standing != null else "0-0",
		"%s %d - %d %s" % [
			team_by_id(title_game.away_team_id).abbreviation,
			title_game.away_score,
			title_game.home_score,
			team_by_id(title_game.home_team_id).abbreviation,
		]
	)
	for standing in sorted_standings():
		var team := team_by_id(standing.team_id)
		record.standings.append({
			"team_id": team.id,
			"team_name": team.display_name(),
			"abbreviation": team.abbreviation,
			"conference": team.conference,
			"record": standing.record_label(),
			"wins": standing.wins,
			"losses": standing.losses,
			"ties": standing.ties,
			"point_differential": standing.point_differential(),
		})
	season_history.append(record)
