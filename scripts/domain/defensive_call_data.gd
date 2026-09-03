class_name DefensiveCallData
extends RefCounted

var id: String
var display_name: String
var personnel: String
var coverage: String
var run_yards_modifier := 0.0
var completion_modifier := 0.0
var pass_yards_modifier := 0.0
var sack_modifier := 0.0
var interception_modifier := 0.0


func _init(call_id: String = "", call_name: String = "") -> void:
	id = call_id
	display_name = call_name


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"personnel": personnel,
		"coverage": coverage,
		"run_yards_modifier": run_yards_modifier,
		"completion_modifier": completion_modifier,
		"pass_yards_modifier": pass_yards_modifier,
		"sack_modifier": sack_modifier,
		"interception_modifier": interception_modifier,
	}


static func from_dict(data: Dictionary) -> DefensiveCallData:
	var call := DefensiveCallData.new(str(data.get("id", "")), str(data.get("display_name", "")))
	call.personnel = str(data.get("personnel", "Base"))
	call.coverage = str(data.get("coverage", "Zone"))
	call.run_yards_modifier = float(data.get("run_yards_modifier", 0.0))
	call.completion_modifier = float(data.get("completion_modifier", 0.0))
	call.pass_yards_modifier = float(data.get("pass_yards_modifier", 0.0))
	call.sack_modifier = float(data.get("sack_modifier", 0.0))
	call.interception_modifier = float(data.get("interception_modifier", 0.0))
	return call
