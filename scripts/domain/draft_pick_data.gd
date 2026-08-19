class_name DraftPickData
extends RefCounted

var id: String
var draft_year: int
var round_number: int
var pick_in_round: int
var overall_pick: int
var original_team_id: String
var owner_team_id: String
var selected_prospect_id := ""
var selected_player_id := ""
var selection_grade := ""
var value_label := ""


func _init(
	pick_id: String = "",
	year: int = 2027,
	round_value: int = 1,
	round_pick: int = 1,
	overall_value: int = 1,
	original_owner: String = "",
	current_owner: String = ""
) -> void:
	id = pick_id
	draft_year = year
	round_number = round_value
	pick_in_round = round_pick
	overall_pick = overall_value
	original_team_id = original_owner
	owner_team_id = current_owner if not current_owner.is_empty() else original_owner


func is_used() -> bool:
	return not selected_prospect_id.is_empty()


func pick_label() -> String:
	return "R%d P%d (#%d)" % [round_number, pick_in_round, overall_pick]


func to_dict() -> Dictionary:
	return {
		"id": id,
		"draft_year": draft_year,
		"round_number": round_number,
		"pick_in_round": pick_in_round,
		"overall_pick": overall_pick,
		"original_team_id": original_team_id,
		"owner_team_id": owner_team_id,
		"selected_prospect_id": selected_prospect_id,
		"selected_player_id": selected_player_id,
		"selection_grade": selection_grade,
		"value_label": value_label,
	}


static func from_dict(data: Dictionary) -> DraftPickData:
	var pick := DraftPickData.new(
		str(data.get("id", "")),
		int(data.get("draft_year", 2027)),
		int(data.get("round_number", 1)),
		int(data.get("pick_in_round", 1)),
		int(data.get("overall_pick", 1)),
		str(data.get("original_team_id", "")),
		str(data.get("owner_team_id", ""))
	)
	pick.selected_prospect_id = str(data.get("selected_prospect_id", ""))
	pick.selected_player_id = str(data.get("selected_player_id", ""))
	pick.selection_grade = str(data.get("selection_grade", ""))
	pick.value_label = str(data.get("value_label", ""))
	return pick
