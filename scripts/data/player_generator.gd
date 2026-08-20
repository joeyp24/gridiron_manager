class_name PlayerGenerator
extends RefCounted

const FIRST_NAMES: Array[String] = [
	"Marcus", "Devin", "Eli", "Grant", "Noah", "Khalil", "Owen", "Jalen",
	"Theo", "Mason", "Cole", "Trey", "Jordan", "Beau", "Rhett", "Andre",
	"Miles", "Cameron", "Isaiah", "Nico", "Micah", "Aaron", "Keon", "Luke",
	"Samir", "Darius", "Finn", "Rico", "Malik", "Evan", "Adrian", "Dante",
	"Xavier", "Roman", "Caleb", "Zion", "Bryce", "Tyrell", "Landon", "Gabriel",
	"Julian", "Amari", "Jonah", "Tobias", "Cedric", "Emmett", "Desmond", "Kai",
	"Terrance", "Damian", "Quincy", "Leon", "Wesley", "Avery", "Dominic", "Kendrick",
	"Jayden", "Tristan", "Donovan", "Corey", "Marlon", "Simeon", "Derrick", "Ashton",
]
const LAST_NAMES: Array[String] = [
	"Vale", "Cross", "Mercer", "Rowe", "Baines", "Ward", "Price", "Frost",
	"Grant", "Pike", "Maddox", "Hollis", "Lake", "Tanner", "Coleman", "Boone",
	"Clay", "Reed", "Knox", "Ames", "Stone", "Bell", "Bishop", "Ibarra",
	"Holt", "North", "Walker", "Dunn", "Rivers", "Cole", "Vega", "Moss",
	"King", "Silva", "Monroe", "Pace", "Quinn", "Moon", "Shaw", "Soto",
	"Banks", "Fox", "Hale", "James", "Lowell", "Nash", "Pierce", "Young",
	"Morrow", "Hampton", "Delgado", "Baxter", "Hines", "Pollard", "Rojas", "Conley",
	"Sutton", "Merritt", "Crawford", "Booker", "Sampson", "Mills", "Vaughn", "Boyd",
]
const COLLEGES: Array[String] = [
	"Great Lakes State", "Coastal Tech", "Red River", "North Metro", "Pacific Union",
	"Appalachian A&M", "Central Plains", "Gulf State", "Mountain Tech", "Capital University",
	"Lone Star State", "Lakeview", "Atlantic Commonwealth", "Western Prairie", "Cascadia",
]
const PERSONALITIES: Array[String] = ["Driven", "Professional", "Team Leader", "Reserved", "Independent", "Competitive"]


static func generate_roster_player(
	player_id: String,
	team_id: String,
	position_name: String,
	overall: int,
	age: int,
	league_year: int,
	depth_index: int,
	seed: int
) -> PlayerData:
	var player := _build_player(player_id, position_name, overall, age, league_year, seed, "Initial Roster")
	player.experience_years = maxi(age - 21, 0)
	player.entry_year = league_year - player.experience_years
	player.draft_round = clampi(depth_index + 1 + absi(seed) % 3, 1, 7) if depth_index < 4 else 0
	player.draft_pick = absi(seed * 17 + depth_index * 11) % 8 + 1 if player.draft_round > 0 else 0
	player.record_team(team_id)
	player.contract = PlayerContract.initial_contract(player, league_year, depth_index)
	return player


static func generate_free_agent(position_name: String, league_year: int, market_index: int, seed: int = 781_337) -> PlayerData:
	var profile_seed := seed + position_name.hash() * 43 + market_index * 1009
	var rng := _rng(profile_seed)
	var overall := clampi(83 - market_index * 7 + rng.randi_range(-3, 3), 66, 86)
	var age := rng.randi_range(22, 33)
	var player := _build_player(
		"free_agent_%d_%s_%d" % [league_year, position_name.to_lower(), market_index],
		position_name,
		overall,
		age,
		league_year,
		profile_seed,
		"Veteran Market"
	)
	player.experience_years = maxi(age - 21, 0)
	player.entry_year = league_year - player.experience_years
	return player


static func generate_replacement(position_name: String, league_year: int, market_index: int, seed: int = 0) -> PlayerData:
	var profile_seed := seed + league_year * 10007 + position_name.hash() * 31 + market_index * 97
	var rng := _rng(profile_seed)
	var overall := rng.randi_range(55, 63)
	var age := rng.randi_range(23, 29)
	var player := _build_player(
		"replacement_%d_%s_%d" % [league_year, position_name.to_lower(), market_index],
		position_name,
		overall,
		age,
		league_year,
		profile_seed,
		"Replacement Pool"
	)
	player.experience_years = maxi(age - 22, 0)
	player.entry_year = league_year - player.experience_years
	return player


static func generate_prospect(position_name: String, draft_year: int, class_index: int, seed: int) -> ProspectData:
	var profile_seed := seed + draft_year * 65537 + class_index * 2053 + position_name.hash() * 17
	var rng := _rng(profile_seed)
	var overall := clampi(roundi(rng.randfn(68.5, 6.7)), 54, 86)
	if position_name in ["K", "P"]:
		overall = clampi(overall - 3, 54, 80)
	var age := rng.randi_range(21, 23)
	var upside := rng.randi_range(2, 13) + (2 if age == 21 else 0)
	var potential := clampi(overall + upside, overall, 97)
	var attributes := _attributes(position_name, overall, rng)
	var measurements := _measurements(position_name, rng)
	var identity := _identity(profile_seed, class_index)
	var production := clampi(roundi(float(overall) * 0.82 + rng.randi_range(2, 23)), 48, 96)
	return ProspectData.new(
		"prospect_%d_%03d" % [draft_year, class_index + 1],
		str(identity["name"]),
		position_name,
		_archetype(position_name, attributes),
		age,
		int(measurements["height"]),
		int(measurements["weight"]),
		COLLEGES[rng.randi_range(0, COLLEGES.size() - 1)],
		production,
		PERSONALITIES[rng.randi_range(0, PERSONALITIES.size() - 1)],
		overall,
		potential,
		int(attributes["speed"]),
		int(attributes["power"]),
		int(attributes["technique"]),
		int(attributes["awareness"]),
		int(attributes["durability"]),
		_combine_forty(int(attributes["speed"]), position_name, rng),
		_combine_bench(int(attributes["power"]), position_name, rng),
		_combine_shuttle(int(attributes["speed"]), int(attributes["technique"]), rng)
	)


static func _build_player(
	player_id: String,
	position_name: String,
	overall: int,
	age: int,
	league_year: int,
	seed: int,
	source: String
) -> PlayerData:
	var rng := _rng(seed)
	var attributes := _attributes(position_name, overall, rng)
	var measurements := _measurements(position_name, rng)
	var identity := _identity(seed, absi(player_id.hash()))
	var player := PlayerData.new(
		player_id,
		str(identity["name"]),
		position_name,
		overall,
		int(attributes["speed"]),
		int(attributes["power"]),
		int(attributes["technique"]),
		int(attributes["awareness"]),
		age,
		int(attributes["durability"])
	)
	player.archetype = _archetype(position_name, attributes)
	player.personality = PERSONALITIES[rng.randi_range(0, PERSONALITIES.size() - 1)]
	player.height_inches = int(measurements["height"])
	player.weight_lbs = int(measurements["weight"])
	player.college = COLLEGES[rng.randi_range(0, COLLEGES.size() - 1)]
	player.entry_year = league_year
	player.generation_source = source
	return player


static func _identity(seed: int, index: int) -> Dictionary:
	var first_index := absi(seed * 31 + index * 17) % FIRST_NAMES.size()
	var last_index := absi(seed * 13 + index * 47 + 19) % LAST_NAMES.size()
	return {"name": "%s %s" % [FIRST_NAMES[first_index], LAST_NAMES[last_index]]}


static func _attributes(position_name: String, overall: int, rng: RandomNumberGenerator) -> Dictionary:
	var values := {
		"speed": overall + rng.randi_range(-7, 7),
		"power": overall + rng.randi_range(-7, 7),
		"technique": overall + rng.randi_range(-6, 7),
		"awareness": overall + rng.randi_range(-8, 5),
		"durability": overall + rng.randi_range(-10, 10),
	}
	if position_name in ["RB", "WR", "CB", "S"]:
		values["speed"] += 7
	if position_name in ["LT", "LG", "C", "RG", "RT", "DT", "EDGE", "TE"]:
		values["power"] += 8
	if position_name == "QB":
		values["technique"] += 7
		values["awareness"] += 4
	if position_name in ["K", "P"]:
		values["technique"] += 10
		values["speed"] -= 12
	for key in values:
		values[key] = clampi(int(values[key]), 42, 98)
	return values


static func _measurements(position_name: String, rng: RandomNumberGenerator) -> Dictionary:
	match position_name:
		"QB":
			return {"height": rng.randi_range(72, 78), "weight": rng.randi_range(205, 242)}
		"RB":
			return {"height": rng.randi_range(68, 73), "weight": rng.randi_range(190, 228)}
		"WR", "CB", "S":
			return {"height": rng.randi_range(69, 77), "weight": rng.randi_range(175, 220)}
		"TE":
			return {"height": rng.randi_range(74, 79), "weight": rng.randi_range(235, 270)}
		"LT", "LG", "C", "RG", "RT":
			return {"height": rng.randi_range(74, 80), "weight": rng.randi_range(285, 338)}
		"DT", "EDGE":
			return {"height": rng.randi_range(72, 79), "weight": rng.randi_range(245, 325)}
		"LB":
			return {"height": rng.randi_range(71, 77), "weight": rng.randi_range(220, 260)}
		_:
			return {"height": rng.randi_range(70, 76), "weight": rng.randi_range(185, 230)}


static func _archetype(position_name: String, attributes: Dictionary) -> String:
	if position_name == "QB":
		return "Field General" if int(attributes["awareness"]) >= int(attributes["speed"]) else "Dual Threat"
	if position_name == "RB":
		return "Power Back" if int(attributes["power"]) > int(attributes["speed"]) else "Home-Run Threat"
	if position_name == "WR":
		return "Route Technician" if int(attributes["technique"]) >= int(attributes["speed"]) else "Vertical Threat"
	if position_name in ["CB", "S"]:
		return "Ball Hawk" if int(attributes["awareness"]) >= int(attributes["power"]) else "Press Enforcer"
	if position_name in ["LT", "LG", "C", "RG", "RT", "DT", "EDGE"]:
		return "Power" if int(attributes["power"]) >= int(attributes["technique"]) else "Technical"
	if position_name in ["K", "P"]:
		return "Precision"
	return "Versatile"


static func _combine_forty(speed: int, position_name: String, rng: RandomNumberGenerator) -> float:
	var base := 5.25 - float(speed - 50) * 0.017
	if position_name in ["LT", "LG", "C", "RG", "RT", "DT"]:
		base += 0.35
	return snappedf(clampf(base + rng.randf_range(-0.08, 0.08), 4.25, 5.65), 0.01)


static func _combine_bench(power: int, position_name: String, rng: RandomNumberGenerator) -> int:
	var base := 8 + roundi(float(power - 45) * 0.48)
	if position_name in ["LT", "LG", "C", "RG", "RT", "DT", "EDGE"]:
		base += 4
	return clampi(base + rng.randi_range(-3, 3), 5, 42)


static func _combine_shuttle(speed: int, technique: int, rng: RandomNumberGenerator) -> float:
	var base := 4.85 - float(speed + technique - 100) * 0.006
	return snappedf(clampf(base + rng.randf_range(-0.08, 0.08), 3.85, 5.15), 0.01)


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
