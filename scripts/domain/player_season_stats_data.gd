class_name PlayerSeasonStatsData
extends RefCounted

var season_year: int
var player_id: String
var full_name: String
var position: String
var stats := StatLineData.new()
var team_splits: Dictionary = {}
var phase_splits: Dictionary = {}


func _init(
	year: int = 0,
	athlete_id: String = "",
	athlete_name: String = "Unknown Player",
	position_name: String = ""
) -> void:
	season_year = year
	player_id = athlete_id
	full_name = athlete_name
	position = position_name


func record_game(line: PlayerGameStatsData, phase: String) -> void:
	if line == null:
		return
	full_name = line.full_name
	position = line.position
	stats.merge(line.stats)
	var team_line: StatLineData = team_splits.get(line.team_id)
	if team_line == null:
		team_line = StatLineData.new()
		team_splits[line.team_id] = team_line
	team_line.merge(line.stats)
	var phase_line: StatLineData = phase_splits.get(phase)
	if phase_line == null:
		phase_line = StatLineData.new()
		phase_splits[phase] = phase_line
	phase_line.merge(line.stats)


func to_dict() -> Dictionary:
	var serialized_team_splits: Dictionary = {}
	for team_id in team_splits:
		serialized_team_splits[team_id] = (team_splits[team_id] as StatLineData).to_dict()
	var serialized_phase_splits: Dictionary = {}
	for phase_name in phase_splits:
		serialized_phase_splits[phase_name] = (phase_splits[phase_name] as StatLineData).to_dict()
	return {
		"season_year": season_year,
		"player_id": player_id,
		"full_name": full_name,
		"position": position,
		"stats": stats.to_dict(),
		"team_splits": serialized_team_splits,
		"phase_splits": serialized_phase_splits,
	}


static func from_dict(data: Dictionary) -> PlayerSeasonStatsData:
	var record := PlayerSeasonStatsData.new(
		int(data.get("season_year", 0)),
		str(data.get("player_id", "")),
		str(data.get("full_name", "Unknown Player")),
		str(data.get("position", ""))
	)
	record.stats = StatLineData.from_dict(Dictionary(data.get("stats", {})))
	for team_id in Dictionary(data.get("team_splits", {})):
		record.team_splits[team_id] = StatLineData.from_dict(Dictionary(data["team_splits"][team_id]))
	for phase_name in Dictionary(data.get("phase_splits", {})):
		record.phase_splits[phase_name] = StatLineData.from_dict(Dictionary(data["phase_splits"][phase_name]))
	return record
