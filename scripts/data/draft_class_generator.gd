class_name DraftClassGenerator
extends RefCounted

const COLLEGES: Array[String] = [
	"Great Lakes State", "Coastal Tech", "Red River", "North Metro", "Pacific Union",
	"Appalachian A&M", "Central Plains", "Gulf State", "Mountain Tech", "Capital University",
	"Lone Star State", "Lakeview", "Atlantic Commonwealth", "Western Prairie", "Cascadia",
]
const PERSONALITIES: Array[String] = ["Driven", "Professional", "Team Leader", "Reserved", "Independent", "Competitive"]
const POSITION_POOL: Array[String] = [
	"QB", "QB", "QB", "QB", "QB", "QB",
	"RB", "RB", "RB", "RB", "RB", "RB",
	"WR", "WR", "WR", "WR", "WR", "WR", "WR", "WR", "WR",
	"TE", "TE", "TE", "TE", "TE",
	"LT", "LT", "LT", "LT", "LT", "LG", "LG", "LG", "LG",
	"C", "C", "C", "C", "RG", "RG", "RG", "RG", "RT", "RT", "RT", "RT", "RT",
	"EDGE", "EDGE", "EDGE", "EDGE", "EDGE", "EDGE", "EDGE",
	"DT", "DT", "DT", "DT", "DT", "DT",
	"LB", "LB", "LB", "LB", "LB", "LB", "LB",
	"CB", "CB", "CB", "CB", "CB", "CB", "CB", "CB",
	"S", "S", "S", "S", "S", "S", "K", "K", "P", "P",
]


static func generate(draft_year: int, seed: int) -> Array[ProspectData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + draft_year * 65537
	var prospects: Array[ProspectData] = []
	var shuffled_positions := POSITION_POOL.duplicate()
	for index in range(shuffled_positions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current: String = shuffled_positions[index]
		shuffled_positions[index] = shuffled_positions[swap_index]
		shuffled_positions[swap_index] = current
	for index in range(shuffled_positions.size()):
		var position_name: String = shuffled_positions[index]
		var overall := clampi(roundi(rng.randfn(68.5, 6.7)), 54, 86)
		if position_name in ["K", "P"]:
			overall = clampi(overall - 3, 54, 80)
		var age := rng.randi_range(21, 23)
		var upside := rng.randi_range(2, 13) + (2 if age == 21 else 0)
		var potential := clampi(overall + upside, overall, 97)
		var attributes := _attributes(position_name, overall, rng)
		var measurements := _measurements(position_name, rng)
		var first := SampleLeague.FIRST_NAMES[(index * 5 + draft_year + rng.randi_range(0, 9)) % SampleLeague.FIRST_NAMES.size()]
		var last := SampleLeague.LAST_NAMES[(index * 13 + draft_year + rng.randi_range(0, 11)) % SampleLeague.LAST_NAMES.size()]
		var production := clampi(roundi(float(overall) * 0.82 + rng.randi_range(2, 23)), 48, 96)
		prospects.append(ProspectData.new(
			"prospect_%d_%03d" % [draft_year, index + 1],
			"%s %s" % [first, last],
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
		))
	prospects.sort_custom(func(a: ProspectData, b: ProspectData):
		var a_grade := float(a.true_overall) * 0.62 + float(a.true_potential) * 0.28 + float(a.production_grade) * 0.10
		var b_grade := float(b.true_overall) * 0.62 + float(b.true_potential) * 0.28 + float(b.production_grade) * 0.10
		return a_grade > b_grade
	)
	for index in range(prospects.size()):
		prospects[index].consensus_rank = index + 1
		prospects[index].projected_round = mini(8, floori(float(index) / 8.0) + 1)
	return prospects


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
	if position_name in ["RB", "WR", "CB", "S"]:
		return "Explosive" if int(attributes["speed"]) >= int(attributes["technique"]) else "Technician"
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
