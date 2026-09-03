class_name PlayDefinitionData
extends RefCounted

var id: String
var display_name: String
var category: String
var play_type: String
var formation: String
var personnel: String
var concept: String
var description: String
var risk: String
var tags: Array[String] = []
var runner_position := "RB"
var target_positions: Array[String] = []
var yardage_modifier := 0.0
var variance_multiplier := 1.0
var completion_modifier := 0.0
var sack_modifier := 0.0
var interception_modifier := 0.0
var fumble_modifier := 0.0
var clock_multiplier := 1.0


func _init(play_id: String = "", play_name: String = "", base_type: String = "run") -> void:
	id = play_id
	display_name = play_name
	play_type = base_type
	category = "Run" if base_type == "run" else "Pass"


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"play_type": play_type,
		"formation": formation,
		"personnel": personnel,
		"concept": concept,
		"description": description,
		"risk": risk,
		"tags": tags.duplicate(),
		"runner_position": runner_position,
		"target_positions": target_positions.duplicate(),
		"yardage_modifier": yardage_modifier,
		"variance_multiplier": variance_multiplier,
		"completion_modifier": completion_modifier,
		"sack_modifier": sack_modifier,
		"interception_modifier": interception_modifier,
		"fumble_modifier": fumble_modifier,
		"clock_multiplier": clock_multiplier,
	}


static func from_dict(data: Dictionary) -> PlayDefinitionData:
	var play := PlayDefinitionData.new(
		str(data.get("id", "")),
		str(data.get("display_name", "Unnamed Play")),
		str(data.get("play_type", "run"))
	)
	play.category = str(data.get("category", play.category))
	play.formation = str(data.get("formation", "Multiple"))
	play.personnel = str(data.get("personnel", "11"))
	play.concept = str(data.get("concept", play.display_name))
	play.description = str(data.get("description", ""))
	play.risk = str(data.get("risk", "Medium"))
	for tag in Array(data.get("tags", [])):
		play.tags.append(str(tag))
	play.runner_position = str(data.get("runner_position", "RB"))
	for position_name in Array(data.get("target_positions", [])):
		play.target_positions.append(str(position_name))
	play.yardage_modifier = float(data.get("yardage_modifier", 0.0))
	play.variance_multiplier = float(data.get("variance_multiplier", 1.0))
	play.completion_modifier = float(data.get("completion_modifier", 0.0))
	play.sack_modifier = float(data.get("sack_modifier", 0.0))
	play.interception_modifier = float(data.get("interception_modifier", 0.0))
	play.fumble_modifier = float(data.get("fumble_modifier", 0.0))
	play.clock_multiplier = float(data.get("clock_multiplier", 1.0))
	return play
