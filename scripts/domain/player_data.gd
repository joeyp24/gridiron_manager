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
var potential: int
var archetype := "Balanced"
var personality := "Professional"
var height_inches := 72
var weight_lbs := 220
var college := "Independent"
var experience_years := 0
var entry_year := 2026
var draft_round := 0
var draft_pick := 0
var original_team_id := ""
var team_history: Array[String] = []
var career_peak_overall := 50
var seasons_as_free_agent := 0
var generation_source := "Legacy"
var jersey_number := 0
var madden_ratings: PlayerRatingsData
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
	player_durability: int = 78,
	player_potential: int = -1
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
	potential = player_potential if player_potential >= 0 else initial_potential(player_id, player_overall, player_age)
	career_peak_overall = player_overall
	madden_ratings = PlayerRatingsData.from_summary(
		player_id, player_position, player_overall, player_speed, player_power,
		player_technique, player_awareness, player_durability
	)


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


func height_label() -> String:
	return "%d'%d\"" % [height_inches / 12, height_inches % 12]


func record_team(team_id: String) -> void:
	if team_id.is_empty():
		return
	if original_team_id.is_empty():
		original_team_id = team_id
	if team_history.is_empty() or team_history.back() != team_id:
		team_history.append(team_id)
	seasons_as_free_agent = 0


func advance_to_league_year(league_year: int, free_agent: bool) -> void:
	experience_years = maxi(league_year - entry_year, 0)
	seasons_as_free_agent = seasons_as_free_agent + 1 if free_agent else 0
	career_peak_overall = maxi(career_peak_overall, overall)


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
		"potential": potential,
		"archetype": archetype,
		"personality": personality,
		"height_inches": height_inches,
		"weight_lbs": weight_lbs,
		"college": college,
		"experience_years": experience_years,
		"entry_year": entry_year,
		"draft_round": draft_round,
		"draft_pick": draft_pick,
		"original_team_id": original_team_id,
		"team_history": team_history.duplicate(),
		"career_peak_overall": career_peak_overall,
		"seasons_as_free_agent": seasons_as_free_agent,
		"generation_source": generation_source,
		"jersey_number": jersey_number,
		"madden_ratings": madden_ratings.to_dict() if madden_ratings != null else null,
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
		int(data.get("durability", 78)),
		int(data.get("potential", -1))
	)
	player.energy = int(data.get("energy", 100))
	player.is_active = bool(data.get("is_active", true))
	player.injury_type = str(data.get("injury_type", ""))
	player.injury_weeks = int(data.get("injury_weeks", 0))
	player.archetype = str(data.get("archetype", "Balanced"))
	player.personality = str(data.get("personality", "Professional"))
	player.height_inches = int(data.get("height_inches", 72))
	player.weight_lbs = int(data.get("weight_lbs", 220))
	player.college = str(data.get("college", "Independent"))
	player.experience_years = int(data.get("experience_years", maxi(player.age - 21, 0)))
	player.entry_year = int(data.get("entry_year", 2026 - player.experience_years))
	player.draft_round = int(data.get("draft_round", 0))
	player.draft_pick = int(data.get("draft_pick", 0))
	player.original_team_id = str(data.get("original_team_id", ""))
	for team_id in data.get("team_history", []):
		player.team_history.append(str(team_id))
	player.career_peak_overall = int(data.get("career_peak_overall", player.overall))
	player.seasons_as_free_agent = int(data.get("seasons_as_free_agent", 0))
	player.generation_source = str(data.get("generation_source", "Legacy"))
	player.jersey_number = int(data.get("jersey_number", 0))
	var ratings_data = data.get("madden_ratings")
	if ratings_data is Dictionary:
		player.madden_ratings = PlayerRatingsData.from_dict(ratings_data)
	else:
		player.madden_ratings = PlayerRatingsData.from_summary(
			player.id, player.position, player.overall, player.speed, player.power,
			player.technique, player.awareness, player.durability, player.archetype
		)
	var contract_data = data.get("contract")
	if contract_data is Dictionary:
		player.contract = PlayerContract.from_dict(contract_data)
	return player


static func initial_potential(player_id: String, player_overall: int, player_age: int) -> int:
	var youth_ceiling := 11 if player_age <= 22 else (8 if player_age <= 24 else (5 if player_age <= 27 else 2))
	var deterministic_bonus := absi(player_id.hash()) % (youth_ceiling + 1)
	return clampi(player_overall + deterministic_bonus, player_overall, 97)
