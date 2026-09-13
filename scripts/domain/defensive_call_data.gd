class_name DefensiveCallData
extends RefCounted

var id: String
var display_name: String
var category := "Base"
var personnel := "Base"
var coverage := "Zone"
var front := "Even"
var shell := "Cover 3"
var description := ""
var risk := "Medium"
var tags: Array[String] = []
var rusher_count := 4
var run_yards_modifier := 0.0
var completion_modifier := 0.0
var pass_yards_modifier := 0.0
var sack_modifier := 0.0
var interception_modifier := 0.0
var explosive_modifier := 0.0
var fumble_modifier := 0.0
var user_selected := false


func _init(call_id: String = "", call_name: String = "") -> void:
	id = call_id
	display_name = call_name


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"category": category,
		"personnel": personnel,
		"coverage": coverage,
		"front": front,
		"shell": shell,
		"description": description,
		"risk": risk,
		"tags": tags.duplicate(),
		"rusher_count": rusher_count,
		"run_yards_modifier": run_yards_modifier,
		"completion_modifier": completion_modifier,
		"pass_yards_modifier": pass_yards_modifier,
		"sack_modifier": sack_modifier,
		"interception_modifier": interception_modifier,
		"explosive_modifier": explosive_modifier,
		"fumble_modifier": fumble_modifier,
		"user_selected": user_selected,
	}


static func from_dict(data: Dictionary) -> DefensiveCallData:
	var call := DefensiveCallData.new(str(data.get("id", "")), str(data.get("display_name", "")))
	call.category = str(data.get("category", "Base"))
	call.personnel = str(data.get("personnel", "Base"))
	call.coverage = str(data.get("coverage", "Zone"))
	call.front = str(data.get("front", "Even"))
	call.shell = str(data.get("shell", "Cover 3"))
	call.description = str(data.get("description", ""))
	call.risk = str(data.get("risk", "Medium"))
	for tag in Array(data.get("tags", [])):
		call.tags.append(str(tag))
	call.rusher_count = int(data.get("rusher_count", 4))
	call.run_yards_modifier = float(data.get("run_yards_modifier", 0.0))
	call.completion_modifier = float(data.get("completion_modifier", 0.0))
	call.pass_yards_modifier = float(data.get("pass_yards_modifier", 0.0))
	call.sack_modifier = float(data.get("sack_modifier", 0.0))
	call.interception_modifier = float(data.get("interception_modifier", 0.0))
	call.explosive_modifier = float(data.get("explosive_modifier", 0.0))
	call.fumble_modifier = float(data.get("fumble_modifier", 0.0))
	call.user_selected = bool(data.get("user_selected", false))
	return call
