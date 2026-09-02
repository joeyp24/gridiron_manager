class_name SeasonStatisticsData
extends RefCounted

var season_year: int
var game_books: Dictionary = {}
var player_totals: Dictionary = {}
var team_totals: Dictionary = {}
var team_phase_totals: Dictionary = {}


func _init(year: int = 2026) -> void:
	season_year = year


func record_game(book: GameBookData) -> bool:
	if book == null or book.matchup_id.is_empty() or game_books.has(book.matchup_id):
		return false
	game_books[book.matchup_id] = book
	for player_id in book.player_stats:
		var game_line: PlayerGameStatsData = book.player_stats[player_id]
		var season_line: PlayerSeasonStatsData = player_totals.get(player_id)
		if season_line == null:
			season_line = PlayerSeasonStatsData.new(season_year, game_line.player_id, game_line.full_name, game_line.position)
			player_totals[player_id] = season_line
		season_line.record_game(game_line, book.phase)
	for team_id in book.team_stats:
		var game_team_line: StatLineData = book.team_stats[team_id]
		var season_team_line: StatLineData = team_totals.get(team_id)
		if season_team_line == null:
			season_team_line = StatLineData.new()
			team_totals[team_id] = season_team_line
		season_team_line.merge(game_team_line)
		if not team_phase_totals.has(book.phase):
			team_phase_totals[book.phase] = {}
		var phase_teams: Dictionary = team_phase_totals[book.phase]
		var phase_team_line: StatLineData = phase_teams.get(team_id)
		if phase_team_line == null:
			phase_team_line = StatLineData.new()
			phase_teams[team_id] = phase_team_line
		phase_team_line.merge(game_team_line)
	return true


func player_stats_for(player_id: String) -> PlayerSeasonStatsData:
	return player_totals.get(player_id)


func team_stats_for(team_id: String, phase: String = "") -> StatLineData:
	if phase.is_empty():
		return team_totals.get(team_id)
	return Dictionary(team_phase_totals.get(phase, {})).get(team_id)


func to_dict() -> Dictionary:
	var books: Dictionary = {}
	for matchup_id in game_books:
		books[matchup_id] = (game_books[matchup_id] as GameBookData).to_dict()
	var players: Dictionary = {}
	for player_id in player_totals:
		players[player_id] = (player_totals[player_id] as PlayerSeasonStatsData).to_dict()
	var teams: Dictionary = {}
	for team_id in team_totals:
		teams[team_id] = (team_totals[team_id] as StatLineData).to_dict()
	var phases: Dictionary = {}
	for phase_name in team_phase_totals:
		var serialized_phase: Dictionary = {}
		for team_id in Dictionary(team_phase_totals[phase_name]):
			serialized_phase[team_id] = (team_phase_totals[phase_name][team_id] as StatLineData).to_dict()
		phases[phase_name] = serialized_phase
	return {
		"season_year": season_year,
		"game_books": books,
		"player_totals": players,
		"team_totals": teams,
		"team_phase_totals": phases,
	}


static func from_dict(data: Dictionary) -> SeasonStatisticsData:
	var season := SeasonStatisticsData.new(int(data.get("season_year", 2026)))
	for matchup_id in Dictionary(data.get("game_books", {})):
		season.game_books[matchup_id] = GameBookData.from_dict(Dictionary(data["game_books"][matchup_id]))
	for player_id in Dictionary(data.get("player_totals", {})):
		season.player_totals[player_id] = PlayerSeasonStatsData.from_dict(Dictionary(data["player_totals"][player_id]))
	for team_id in Dictionary(data.get("team_totals", {})):
		season.team_totals[team_id] = StatLineData.from_dict(Dictionary(data["team_totals"][team_id]))
	for phase_name in Dictionary(data.get("team_phase_totals", {})):
		var phase_teams: Dictionary = {}
		for team_id in Dictionary(data["team_phase_totals"][phase_name]):
			phase_teams[team_id] = StatLineData.from_dict(Dictionary(data["team_phase_totals"][phase_name][team_id]))
		season.team_phase_totals[phase_name] = phase_teams
	return season
