class_name DevelopmentReportData
extends RefCounted

var season_year: int
var player_id: String
var player_name: String
var team_id: String
var position: String
var previous_age: int
var new_age: int
var previous_overall: int
var new_overall: int
var potential: int
var attribute_changes: Dictionary = {}


func _init(
	year: int = 2027,
	report_player_id: String = "",
	report_player_name: String = "",
	report_team_id: String = "",
	report_position: String = "",
	old_age: int = 24,
	updated_age: int = 25,
	old_overall: int = 50,
	updated_overall: int = 50,
	player_potential: int = 50,
	changes: Dictionary = {}
) -> void:
	season_year = year
	player_id = report_player_id
	player_name = report_player_name
	team_id = report_team_id
	position = report_position
	previous_age = old_age
	new_age = updated_age
	previous_overall = old_overall
	new_overall = updated_overall
	potential = player_potential
	attribute_changes = changes.duplicate(true)


func overall_change() -> int:
	return new_overall - previous_overall


func trend_label() -> String:
	var change := overall_change()
	if change > 0:
		return "+%d OVR" % change
	if change < 0:
		return "%d OVR" % change
	return "NO CHANGE"


func to_dict() -> Dictionary:
	return {
		"season_year": season_year,
		"player_id": player_id,
		"player_name": player_name,
		"team_id": team_id,
		"position": position,
		"previous_age": previous_age,
		"new_age": new_age,
		"previous_overall": previous_overall,
		"new_overall": new_overall,
		"potential": potential,
		"attribute_changes": attribute_changes.duplicate(true),
	}


static func from_dict(data: Dictionary) -> DevelopmentReportData:
	return DevelopmentReportData.new(
		int(data.get("season_year", 2027)),
		str(data.get("player_id", "")),
		str(data.get("player_name", "Unknown Player")),
		str(data.get("team_id", "")),
		str(data.get("position", "")),
		int(data.get("previous_age", 24)),
		int(data.get("new_age", 25)),
		int(data.get("previous_overall", 50)),
		int(data.get("new_overall", 50)),
		int(data.get("potential", 50)),
		data.get("attribute_changes", {})
	)
