class_name DefensivePlaybookData
extends RefCounted

var id: String
var display_name: String
var calls: Array[DefensiveCallData] = []


func _init(playbook_id: String = "", playbook_name: String = "") -> void:
	id = playbook_id
	display_name = playbook_name


func call_by_id(call_id: String) -> DefensiveCallData:
	for call in calls:
		if call.id == call_id:
			return call
	return null


func calls_in_category(category_name: String) -> Array[DefensiveCallData]:
	var matches: Array[DefensiveCallData] = []
	for call in calls:
		if call.category == category_name:
			matches.append(call)
	return matches


func to_dict() -> Dictionary:
	var call_data: Array[Dictionary] = []
	for call in calls:
		call_data.append(call.to_dict())
	return {
		"id": id,
		"display_name": display_name,
		"calls": call_data,
	}


static func from_dict(data: Dictionary) -> DefensivePlaybookData:
	var playbook := DefensivePlaybookData.new(
		str(data.get("id", "default_defense")),
		str(data.get("display_name", "Multiple Defense"))
	)
	for call_data in Array(data.get("calls", [])):
		playbook.calls.append(DefensiveCallData.from_dict(Dictionary(call_data)))
	return playbook
