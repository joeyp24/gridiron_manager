class_name LeagueState
extends RefCounted

const REGULAR_SEASON_WEEKS := 7
const CHAMPIONSHIP_WEEK := 8

var season_year := 2026
var current_week := 1
var phase := "Regular Season"
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
		phase = "Championship"
		return
	var championship := matchups_for_week(CHAMPIONSHIP_WEEK)
	if not championship.is_empty():
		champion_team_id = championship.front().winner_id()
	phase = "Complete"


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
	return league
