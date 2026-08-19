class_name PlayerData
extends RefCounted

var id: String
var full_name: String
var position: String
var overall: int
var speed: int
var power: int
var technique: int
var awareness: int
var age: int


func _init(
	player_id: String = "",
	player_name: String = "",
	player_position: String = "",
	player_overall: int = 50,
	player_speed: int = 50,
	player_power: int = 50,
	player_technique: int = 50,
	player_awareness: int = 50,
	player_age: int = 24
) -> void:
	id = player_id
	full_name = player_name
	position = player_position
	overall = player_overall
	speed = player_speed
	power = player_power
	technique = player_technique
	awareness = player_awareness
	age = player_age


func rating_for(category: String) -> int:
	match category:
		"speed":
			return speed
		"power":
			return power
		"technique":
			return technique
		"awareness":
			return awareness
		_:
			return overall


func to_dict() -> Dictionary:
	return {
		"id": id,
		"full_name": full_name,
		"position": position,
		"overall": overall,
		"speed": speed,
		"power": power,
		"technique": technique,
		"awareness": awareness,
		"age": age,
	}
