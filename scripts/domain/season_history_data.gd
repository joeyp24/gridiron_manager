class_name SeasonHistoryData
extends RefCounted

var season_year: int
var user_team_id: String
var champion_team_id: String
var runner_up_team_id: String
var user_record: String
var championship_score: String
var standings: Array[Dictionary] = []


func _init(
	year: int = 2026,
	managed_team_id: String = "",
	champion_id: String = "",
	runner_up_id: String = "",
	managed_record: String = "0-0",
	title_game_score: String = ""
) -> void:
	season_year = year
	user_team_id = managed_team_id
	champion_team_id = champion_id
	runner_up_team_id = runner_up_id
	user_record = managed_record
	championship_score = title_game_score


func to_dict() -> Dictionary:
	return {
		"season_year": season_year,
		"user_team_id": user_team_id,
		"champion_team_id": champion_team_id,
		"runner_up_team_id": runner_up_team_id,
		"user_record": user_record,
		"championship_score": championship_score,
		"standings": standings.duplicate(true),
	}


static func from_dict(data: Dictionary) -> SeasonHistoryData:
	var record := SeasonHistoryData.new(
		int(data.get("season_year", 2026)),
		str(data.get("user_team_id", "")),
		str(data.get("champion_team_id", "")),
		str(data.get("runner_up_team_id", "")),
		str(data.get("user_record", "0-0")),
		str(data.get("championship_score", ""))
	)
	for standing_data in data.get("standings", []):
		if standing_data is Dictionary:
			record.standings.append(standing_data.duplicate(true))
	return record
