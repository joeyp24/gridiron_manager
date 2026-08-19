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
var durability: int
var age: int
var energy := 100
var is_active := true
var injury_type := ""
var injury_weeks := 0
var contract: PlayerContract


func _init(
	player_id: String = "",
	player_name: String = "",
	player_position: String = "",
	player_overall: int = 50,
	player_speed: int = 50,
	player_power: int = 50,
	player_technique: int = 50,
	player_awareness: int = 50,
	player_age: int = 24,
	player_durability: int = 78
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
	durability = player_durability


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
		"durability":
			return durability
		_:
			return overall


func is_available() -> bool:
	return is_active and injury_weeks <= 0


func effective_overall() -> int:
	if not is_available():
		return 0
	var fatigue_penalty := roundi(float(maxi(100 - energy, 0)) * 0.16)
	return maxi(1, overall - fatigue_penalty)


func apply_game_fatigue(starter: bool) -> void:
	var cost := 32 if starter else 14
	energy = clampi(energy - cost, 20, 100)


func injure(label: String, weeks: int) -> void:
	injury_type = label
	injury_weeks = maxi(weeks, 1)


func recover_for_new_week() -> void:
	energy = mini(100, energy + 22)


func advance_injury_week() -> void:
	if injury_weeks > 0:
		injury_weeks -= 1
		if injury_weeks == 0:
			injury_type = ""


func availability_label() -> String:
	if injury_weeks > 0:
		return "%s · %d wk" % [injury_type, injury_weeks]
	if not is_active:
		return "Inactive"
	if energy < 65:
		return "Tired · %d%%" % energy
	return "Available · %d%%" % energy


func is_free_agent() -> bool:
	return contract == null


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
		"durability": durability,
		"age": age,
		"energy": energy,
		"is_active": is_active,
		"injury_type": injury_type,
		"injury_weeks": injury_weeks,
		"contract": contract.to_dict() if contract != null else null,
	}


static func from_dict(data: Dictionary) -> PlayerData:
	var player := PlayerData.new(
		str(data.get("id", "")),
		str(data.get("full_name", "Unknown Player")),
		str(data.get("position", "")),
		int(data.get("overall", 50)),
		int(data.get("speed", 50)),
		int(data.get("power", 50)),
		int(data.get("technique", 50)),
		int(data.get("awareness", 50)),
		int(data.get("age", 24)),
		int(data.get("durability", 78))
	)
	player.energy = int(data.get("energy", 100))
	player.is_active = bool(data.get("is_active", true))
	player.injury_type = str(data.get("injury_type", ""))
	player.injury_weeks = int(data.get("injury_weeks", 0))
	var contract_data = data.get("contract")
	if contract_data is Dictionary:
		player.contract = PlayerContract.from_dict(contract_data)
	return player
