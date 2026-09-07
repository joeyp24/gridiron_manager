class_name FantasyDraftPickData
extends RefCounted

var round_number := 1
var pick_in_round := 1
var overall_pick := 1
var team_id := ""
var selected_player_id := ""
var selected_player_name := ""
var selected_position := ""
var selected_overall := 0


func _init(round_value: int = 1, slot_value: int = 1, overall_value: int = 1, owner_team_id: String = "") -> void:
	round_number = round_value
	pick_in_round = slot_value
	overall_pick = overall_value
	team_id = owner_team_id


func is_used() -> bool:
	return not selected_player_id.is_empty()


func pick_label() -> String:
	return "ROUND %d · PICK %d · #%d OVERALL" % [round_number, pick_in_round, overall_pick]


func to_dict() -> Dictionary:
	return {
		"round_number": round_number,
		"pick_in_round": pick_in_round,
		"overall_pick": overall_pick,
		"team_id": team_id,
		"selected_player_id": selected_player_id,
		"selected_player_name": selected_player_name,
		"selected_position": selected_position,
		"selected_overall": selected_overall,
	}


static func from_dict(data: Dictionary) -> FantasyDraftPickData:
	var pick := FantasyDraftPickData.new(
		int(data.get("round_number", 1)),
		int(data.get("pick_in_round", 1)),
		int(data.get("overall_pick", 1)),
		str(data.get("team_id", ""))
	)
	pick.selected_player_id = str(data.get("selected_player_id", ""))
	pick.selected_player_name = str(data.get("selected_player_name", ""))
	pick.selected_position = str(data.get("selected_position", ""))
	pick.selected_overall = int(data.get("selected_overall", 0))
	return pick
