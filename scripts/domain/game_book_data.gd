class_name GameBookData
extends RefCounted

var matchup_id: String
var season_year: int
var week: int
var phase: String
var away_team_id: String
var home_team_id: String
var away_score: int
var home_score: int
var team_stats: Dictionary = {}
var player_stats: Dictionary = {}
var play_calls: Array[Dictionary] = []


static func from_game(matchup: MatchupData, game: GameStateData, year: int) -> GameBookData:
	var book := GameBookData.new()
	book.matchup_id = matchup.id
	book.season_year = year
	book.week = matchup.week
	book.phase = matchup.phase
	book.away_team_id = matchup.away_team_id
	book.home_team_id = matchup.home_team_id
	book.away_score = game.away_score
	book.home_score = game.home_score
	for team_id in [book.away_team_id, book.home_team_id]:
		var line := StatLineData.new(Dictionary(game.stats.get(team_id, {})))
		line.set_value("games_played", 1)
		line.set_value("points", book.away_score if team_id == book.away_team_id else book.home_score)
		line.set_value("points_allowed", book.home_score if team_id == book.away_team_id else book.away_score)
		book.team_stats[team_id] = line
	for player_id in game.player_stats:
		var player_line = game.player_stats[player_id]
		if player_line is PlayerGameStatsData and player_line.stats.value("games_played") > 0:
			book.player_stats[player_id] = PlayerGameStatsData.from_dict(player_line.to_dict())
	for result in game.play_history:
		book.play_calls.append({
			"sequence": result.sequence,
			"quarter": result.quarter,
			"clock_seconds": result.clock_seconds,
			"offense_id": result.offense_id,
			"defense_id": result.defense_id,
			"offensive_call_id": result.call_id,
			"offensive_call_name": result.call_name,
			"offensive_call_formation": result.call_formation,
			"offensive_call_personnel": result.call_personnel,
			"offensive_call_concept": result.call_concept,
			"offensive_call_tempo": result.call_tempo,
			"offensive_call_tags": result.call_tags.duplicate(),
			"offensive_call_was_user_selected": result.call_was_user_selected,
			"play_type": result.play_type,
			"defensive_call_id": result.defensive_call_id,
			"defensive_call_name": result.defensive_call_name,
			"defensive_call_personnel": result.defensive_call_personnel,
			"defensive_call_coverage": result.defensive_call_coverage,
			"defensive_call_front": result.defensive_call_front,
			"defensive_call_shell": result.defensive_call_shell,
			"defensive_call_rusher_count": result.defensive_call_rusher_count,
			"defensive_call_tags": result.defensive_call_tags.duplicate(),
			"defensive_call_was_user_selected": result.defensive_call_was_user_selected,
			"result": result.title,
			"yards": result.yards,
			"points": result.points,
		})
	return book


func team_line(team_id: String) -> StatLineData:
	return team_stats.get(team_id)


func player_line(player_id: String) -> PlayerGameStatsData:
	return player_stats.get(player_id)


func to_dict() -> Dictionary:
	var serialized_teams: Dictionary = {}
	for team_id in team_stats:
		serialized_teams[team_id] = team_line(str(team_id)).to_dict()
	var serialized_players: Dictionary = {}
	for player_id in player_stats:
		serialized_players[player_id] = player_line(str(player_id)).to_dict()
	return {
		"matchup_id": matchup_id,
		"season_year": season_year,
		"week": week,
		"phase": phase,
		"away_team_id": away_team_id,
		"home_team_id": home_team_id,
		"away_score": away_score,
		"home_score": home_score,
		"team_stats": serialized_teams,
		"player_stats": serialized_players,
		"play_calls": play_calls.duplicate(true),
	}


static func from_dict(data: Dictionary) -> GameBookData:
	var book := GameBookData.new()
	book.matchup_id = str(data.get("matchup_id", ""))
	book.season_year = int(data.get("season_year", 2026))
	book.week = int(data.get("week", 1))
	book.phase = str(data.get("phase", "Regular Season"))
	book.away_team_id = str(data.get("away_team_id", ""))
	book.home_team_id = str(data.get("home_team_id", ""))
	book.away_score = int(data.get("away_score", 0))
	book.home_score = int(data.get("home_score", 0))
	for team_id in Dictionary(data.get("team_stats", {})):
		book.team_stats[team_id] = StatLineData.from_dict(Dictionary(data["team_stats"][team_id]))
	for player_id in Dictionary(data.get("player_stats", {})):
		book.player_stats[player_id] = PlayerGameStatsData.from_dict(Dictionary(data["player_stats"][player_id]))
	for call_data in Array(data.get("play_calls", [])):
		book.play_calls.append(Dictionary(call_data).duplicate(true))
	return book
