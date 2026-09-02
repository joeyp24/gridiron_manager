class_name LeagueStatisticsData
extends RefCounted

var seasons: Dictionary = {}
var career_player_totals: Dictionary = {}


func season(year: int, create_if_missing: bool = false) -> SeasonStatisticsData:
	var key := str(year)
	var record: SeasonStatisticsData = seasons.get(key)
	if record == null and create_if_missing:
		record = SeasonStatisticsData.new(year)
		seasons[key] = record
	return record


func record_game(book: GameBookData) -> bool:
	if book == null:
		return false
	var season_record := season(book.season_year, true)
	if not season_record.record_game(book):
		return false
	for player_id in book.player_stats:
		var game_line: PlayerGameStatsData = book.player_stats[player_id]
		var career_line: PlayerSeasonStatsData = career_player_totals.get(player_id)
		if career_line == null:
			career_line = PlayerSeasonStatsData.new(0, game_line.player_id, game_line.full_name, game_line.position)
			career_player_totals[player_id] = career_line
		career_line.record_game(game_line, book.phase)
	return true


func player_season(player_id: String, year: int) -> PlayerSeasonStatsData:
	var season_record := season(year)
	return season_record.player_stats_for(player_id) if season_record != null else null


func player_career(player_id: String) -> PlayerSeasonStatsData:
	return career_player_totals.get(player_id)


func to_dict() -> Dictionary:
	var serialized_seasons: Dictionary = {}
	for year in seasons:
		serialized_seasons[year] = (seasons[year] as SeasonStatisticsData).to_dict()
	var serialized_careers: Dictionary = {}
	for player_id in career_player_totals:
		serialized_careers[player_id] = (career_player_totals[player_id] as PlayerSeasonStatsData).to_dict()
	return {
		"seasons": serialized_seasons,
		"career_player_totals": serialized_careers,
	}


static func from_dict(data: Dictionary) -> LeagueStatisticsData:
	var statistics := LeagueStatisticsData.new()
	for year in Dictionary(data.get("seasons", {})):
		statistics.seasons[year] = SeasonStatisticsData.from_dict(Dictionary(data["seasons"][year]))
	for player_id in Dictionary(data.get("career_player_totals", {})):
		statistics.career_player_totals[player_id] = PlayerSeasonStatsData.from_dict(Dictionary(data["career_player_totals"][player_id]))
	return statistics
