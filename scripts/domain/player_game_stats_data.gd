class_name PlayerGameStatsData
extends RefCounted

var player_id: String
var full_name: String
var position: String
var team_id: String
var opponent_team_id: String
var stats := StatLineData.new()


func _init(
	athlete_id: String = "",
	athlete_name: String = "Unknown Player",
	position_name: String = "",
	club_id: String = "",
	opponent_id: String = ""
) -> void:
	player_id = athlete_id
	full_name = athlete_name
	position = position_name
	team_id = club_id
	opponent_team_id = opponent_id


func mark_appearance(starter: bool = false) -> void:
	stats.set_value("games_played", 1)
	if starter:
		stats.set_value("games_started", 1)


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"full_name": full_name,
		"position": position,
		"team_id": team_id,
		"opponent_team_id": opponent_team_id,
		"stats": stats.to_dict(),
	}


static func from_dict(data: Dictionary) -> PlayerGameStatsData:
	var record := PlayerGameStatsData.new(
		str(data.get("player_id", "")),
		str(data.get("full_name", "Unknown Player")),
		str(data.get("position", "")),
		str(data.get("team_id", "")),
		str(data.get("opponent_team_id", ""))
	)
	record.stats = StatLineData.from_dict(Dictionary(data.get("stats", {})))
	return record
