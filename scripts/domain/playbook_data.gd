class_name PlaybookData
extends RefCounted

var id: String
var display_name: String
var plays: Array[PlayDefinitionData] = []


func _init(playbook_id: String = "", playbook_name: String = "") -> void:
	id = playbook_id
	display_name = playbook_name


func play_by_id(play_id: String) -> PlayDefinitionData:
	for play in plays:
		if play.id == play_id:
			return play
	return null


func plays_in_category(category_name: String) -> Array[PlayDefinitionData]:
	var matches: Array[PlayDefinitionData] = []
	for play in plays:
		if play.category == category_name:
			matches.append(play)
	return matches


func to_dict() -> Dictionary:
	var play_data: Array[Dictionary] = []
	for play in plays:
		play_data.append(play.to_dict())
	return {
		"id": id,
		"display_name": display_name,
		"plays": play_data,
	}


static func from_dict(data: Dictionary) -> PlaybookData:
	var playbook := PlaybookData.new(
		str(data.get("id", "default_offense")),
		str(data.get("display_name", "Pro Style Offense"))
	)
	for play_data in Array(data.get("plays", [])):
		playbook.plays.append(PlayDefinitionData.from_dict(Dictionary(play_data)))
	return playbook
