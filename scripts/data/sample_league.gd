class_name SampleLeague
extends RefCounted


static func create_teams() -> Array[TeamData]:
	return [
		_create_boston(),
		_create_austin(),
		_create_seattle(),
		_create_miami(),
	]


static func _create_boston() -> TeamData:
	return TeamData.new(
		"boston_sentinels",
		"Boston",
		"Sentinels",
		"BOS",
		"Atlantic",
		Color("35e0a1"),
		Color("0b2028"),
		84,
		81,
		78,
		[
			_p("bos_qb", "Marcus Vale", "QB", 87, 76, 62, 91, 89, 29),
			_p("bos_rb", "Devin Cross", "RB", 84, 89, 78, 83, 80, 25),
			_p("bos_wr", "Eli Mercer", "WR", 86, 92, 62, 88, 84, 26),
			_p("bos_te", "Grant Rowe", "TE", 79, 74, 84, 81, 79, 27),
			_p("bos_ol", "Noah Baines", "OL", 82, 58, 90, 85, 86, 30),
			_p("bos_edge", "Khalil Ward", "EDGE", 85, 86, 88, 84, 82, 27),
			_p("bos_lb", "Owen Price", "LB", 80, 81, 84, 80, 86, 28),
			_p("bos_cb", "Jalen Frost", "CB", 83, 91, 65, 86, 83, 24),
			_p("bos_s", "Theo Grant", "S", 78, 84, 73, 79, 84, 26),
			_p("bos_k", "Mason Pike", "K", 78, 55, 68, 86, 82, 31),
		]
	)


static func _create_austin() -> TeamData:
	var team := TeamData.new(
		"austin_outlaws",
		"Austin",
		"Outlaws",
		"AUS",
		"Frontier",
		Color("ff9e57"),
		Color("3b1f17"),
		82,
		79,
		86,
		[
			_p("aus_qb", "Cole Maddox", "QB", 82, 81, 69, 84, 82, 27),
			_p("aus_rb", "Trey Hollis", "RB", 88, 91, 86, 85, 82, 24),
			_p("aus_wr", "Jordan Lake", "WR", 81, 88, 64, 84, 80, 26),
			_p("aus_te", "Beau Tanner", "TE", 81, 76, 87, 82, 79, 28),
			_p("aus_ol", "Rhett Coleman", "OL", 84, 57, 92, 86, 85, 29),
			_p("aus_edge", "Andre Boone", "EDGE", 80, 82, 84, 82, 81, 26),
			_p("aus_lb", "Miles Clay", "LB", 84, 84, 86, 83, 88, 28),
			_p("aus_cb", "Cameron Reed", "CB", 76, 87, 63, 79, 78, 25),
			_p("aus_s", "Isaiah Knox", "S", 82, 83, 80, 83, 86, 29),
			_p("aus_k", "Nico Ames", "K", 86, 58, 66, 91, 89, 30),
		]
	)
	team.run_tendency = 0.57
	return team


static func _create_seattle() -> TeamData:
	var team := TeamData.new(
		"seattle_orcas",
		"Seattle",
		"Orcas",
		"SEA",
		"Pacific",
		Color("43b9ff"),
		Color("10243c"),
		79,
		86,
		80,
		[
			_p("sea_qb", "Micah Stone", "QB", 79, 78, 64, 82, 84, 26),
			_p("sea_rb", "Aaron Bell", "RB", 78, 85, 78, 79, 77, 25),
			_p("sea_wr", "Keon Bishop", "WR", 83, 93, 59, 84, 76, 23),
			_p("sea_te", "Luke Ibarra", "TE", 76, 72, 82, 79, 80, 28),
			_p("sea_ol", "Samir Holt", "OL", 79, 60, 86, 81, 84, 27),
			_p("sea_edge", "Darius North", "EDGE", 88, 87, 91, 87, 84, 28),
			_p("sea_lb", "Finn Walker", "LB", 86, 84, 87, 86, 90, 29),
			_p("sea_cb", "Rico Dunn", "CB", 85, 92, 62, 88, 84, 25),
			_p("sea_s", "Malik Rivers", "S", 82, 86, 76, 83, 88, 27),
			_p("sea_k", "Evan Cole", "K", 80, 56, 65, 87, 84, 32),
		]
	)
	team.run_tendency = 0.49
	return team


static func _create_miami() -> TeamData:
	var team := TeamData.new(
		"miami_nightjars",
		"Miami",
		"Nightjars",
		"MIA",
		"Atlantic",
		Color("a98cff"),
		Color("241b3d"),
		88,
		76,
		77,
		[
			_p("mia_qb", "Adrian Vega", "QB", 90, 84, 65, 93, 91, 28),
			_p("mia_rb", "Dante Moss", "RB", 79, 90, 73, 78, 75, 23),
			_p("mia_wr", "Xavier King", "WR", 89, 95, 61, 91, 85, 25),
			_p("mia_te", "Roman Silva", "TE", 82, 78, 84, 85, 83, 26),
			_p("mia_ol", "Caleb Monroe", "OL", 80, 56, 88, 82, 82, 30),
			_p("mia_edge", "Zion Pace", "EDGE", 78, 88, 79, 80, 75, 24),
			_p("mia_lb", "Bryce Quinn", "LB", 77, 79, 82, 78, 80, 27),
			_p("mia_cb", "Tyrell Moon", "CB", 82, 90, 62, 85, 82, 26),
			_p("mia_s", "Landon Shaw", "S", 75, 82, 70, 78, 81, 25),
			_p("mia_k", "Gabriel Soto", "K", 77, 57, 64, 84, 80, 29),
		]
	)
	team.run_tendency = 0.36
	team.aggression = 0.61
	return team


static func _p(
	id: String,
	name: String,
	position: String,
	overall: int,
	speed: int,
	power: int,
	technique: int,
	awareness: int,
	age: int
) -> PlayerData:
	return PlayerData.new(id, name, position, overall, speed, power, technique, awareness, age)
