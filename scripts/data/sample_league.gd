class_name SampleLeague
extends RefCounted

const FIRST_NAMES: Array[String] = [
	"Marcus", "Devin", "Eli", "Grant", "Noah", "Khalil", "Owen", "Jalen",
	"Theo", "Mason", "Cole", "Trey", "Jordan", "Beau", "Rhett", "Andre",
	"Miles", "Cameron", "Isaiah", "Nico", "Micah", "Aaron", "Keon", "Luke",
	"Samir", "Darius", "Finn", "Rico", "Malik", "Evan", "Adrian", "Dante",
	"Xavier", "Roman", "Caleb", "Zion", "Bryce", "Tyrell", "Landon", "Gabriel",
	"Julian", "Amari", "Jonah", "Tobias", "Cedric", "Emmett", "Desmond", "Kai",
]
const LAST_NAMES: Array[String] = [
	"Vale", "Cross", "Mercer", "Rowe", "Baines", "Ward", "Price", "Frost",
	"Grant", "Pike", "Maddox", "Hollis", "Lake", "Tanner", "Coleman", "Boone",
	"Clay", "Reed", "Knox", "Ames", "Stone", "Bell", "Bishop", "Ibarra",
	"Holt", "North", "Walker", "Dunn", "Rivers", "Cole", "Vega", "Moss",
	"King", "Silva", "Monroe", "Pace", "Quinn", "Moon", "Shaw", "Soto",
	"Banks", "Fox", "Hale", "James", "Lowell", "Nash", "Pierce", "Young",
]


static func create_teams() -> Array[TeamData]:
	var profiles: Array[Dictionary] = [
		_profile("boston_sentinels", "Boston", "Sentinels", "BOS", "Atlantic", "35e0a1", "0b2028", 84, 81, 78, 1101, 0.46, 0.50),
		_profile("miami_nightjars", "Miami", "Nightjars", "MIA", "Atlantic", "a98cff", "241b3d", 88, 76, 77, 1102, 0.35, 0.64),
		_profile("new_york_admirals", "New York", "Admirals", "NYA", "Atlantic", "f4cf55", "172638", 80, 84, 79, 1103, 0.50, 0.44),
		_profile("chicago_foundry", "Chicago", "Foundry", "CHI", "Atlantic", "f07167", "321b1c", 78, 87, 82, 1104, 0.58, 0.52),
		_profile("austin_outlaws", "Austin", "Outlaws", "AUS", "Frontier", "ff9e57", "3b1f17", 82, 79, 86, 2101, 0.59, 0.55),
		_profile("seattle_orcas", "Seattle", "Orcas", "SEA", "Frontier", "43b9ff", "10243c", 79, 86, 80, 2102, 0.48, 0.48),
		_profile("denver_summit", "Denver", "Summit", "DEN", "Frontier", "84e25d", "153023", 83, 82, 75, 2103, 0.54, 0.46),
		_profile("phoenix_scorpions", "Phoenix", "Scorpions", "PHX", "Frontier", "ff6b72", "35172b", 86, 77, 83, 2104, 0.39, 0.67),
	]
	var teams: Array[TeamData] = []
	for profile in profiles:
		teams.append(_create_team(profile))
	return teams


static func create_free_agents() -> Array[PlayerData]:
	var free_agents: Array[PlayerData] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 781_337
	var name_cursor := 19
	for position_name in TeamData.ROSTER_POSITIONS:
		for market_index in range(2):
			var overall := clampi(83 - market_index * 7 + rng.randi_range(-3, 3), 66, 86)
			var attributes := _attributes_for_position(position_name, overall, rng)
			var first := FIRST_NAMES[name_cursor % FIRST_NAMES.size()]
			var last := LAST_NAMES[(name_cursor * 11 + 17) % LAST_NAMES.size()]
			name_cursor += 1
			free_agents.append(PlayerData.new(
				"free_agent_%s_%d" % [position_name.to_lower(), market_index],
				"%s %s" % [first, last],
				position_name,
				overall,
				attributes["speed"],
				attributes["power"],
				attributes["technique"],
				attributes["awareness"],
				rng.randi_range(22, 33),
				attributes["durability"]
			))
	free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return free_agents


static func create_replacement_player(position_name: String, season_year: int, market_index: int) -> PlayerData:
	var rng := RandomNumberGenerator.new()
	rng.seed = season_year * 10007 + position_name.hash() * 31 + market_index * 97
	var overall := rng.randi_range(55, 63)
	var attributes := _attributes_for_position(position_name, overall, rng)
	var name_cursor := absi(season_year * 19 + position_name.hash() + market_index * 7)
	var first := FIRST_NAMES[name_cursor % FIRST_NAMES.size()]
	var last := LAST_NAMES[(name_cursor * 11 + season_year) % LAST_NAMES.size()]
	return PlayerData.new(
		"replacement_%d_%s_%d" % [season_year, position_name.to_lower(), market_index],
		"%s %s" % [first, last],
		position_name,
		overall,
		attributes["speed"],
		attributes["power"],
		attributes["technique"],
		attributes["awareness"],
		rng.randi_range(23, 29),
		attributes["durability"]
	)


static func _profile(
	id: String,
	city: String,
	nickname: String,
	abbreviation: String,
	conference: String,
	primary: String,
	secondary: String,
	offense: int,
	defense: int,
	special_teams: int,
	seed: int,
	run_tendency: float,
	aggression: float
) -> Dictionary:
	return {
		"id": id,
		"city": city,
		"nickname": nickname,
		"abbreviation": abbreviation,
		"conference": conference,
		"primary": primary,
		"secondary": secondary,
		"offense": offense,
		"defense": defense,
		"special_teams": special_teams,
		"seed": seed,
		"run_tendency": run_tendency,
		"aggression": aggression,
	}


static func _create_team(profile: Dictionary) -> TeamData:
	var players := _generate_roster(
		str(profile["id"]),
		int(profile["offense"]),
		int(profile["defense"]),
		int(profile["special_teams"]),
		int(profile["seed"])
	)
	var team := TeamData.new(
		str(profile["id"]),
		str(profile["city"]),
		str(profile["nickname"]),
		str(profile["abbreviation"]),
		str(profile["conference"]),
		Color(str(profile["primary"])),
		Color(str(profile["secondary"])),
		int(profile["offense"]),
		int(profile["defense"]),
		int(profile["special_teams"]),
		players
	)
	team.run_tendency = float(profile["run_tendency"])
	team.aggression = float(profile["aggression"])
	team.tempo = 0.58 if team.aggression >= 0.60 else 0.48
	team.passing_depth = 0.62 if team.run_tendency < 0.42 else 0.48
	team.blitz_rate = 0.55 if team.defense_rating >= 84 else 0.40
	return team


static func _generate_roster(
	team_id: String,
	offense_rating: int,
	defense_rating: int,
	special_rating: int,
	seed: int
) -> Array[PlayerData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var counts := {
		"QB": 2, "RB": 3, "WR": 5, "TE": 2,
		"LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
		"EDGE": 3, "DT": 3, "LB": 4, "CB": 4, "S": 3,
		"K": 1, "P": 1,
	}
	var roster: Array[PlayerData] = []
	var name_cursor := seed % FIRST_NAMES.size()
	for position_name: String in counts:
		var position_count: int = counts[position_name]
		for depth_index in range(position_count):
			var base_rating := _position_base(position_name, offense_rating, defense_rating, special_rating)
			var depth_drop := depth_index * rng.randi_range(3, 6)
			var overall := clampi(base_rating + rng.randi_range(-3, 3) - depth_drop, 58, 94)
			var first := FIRST_NAMES[name_cursor % FIRST_NAMES.size()]
			var last := LAST_NAMES[(name_cursor * 7 + seed) % LAST_NAMES.size()]
			name_cursor += 1
			var attributes := _attributes_for_position(position_name, overall, rng)
			var player := PlayerData.new(
				"%s_%s_%d" % [team_id, position_name.to_lower(), depth_index],
				"%s %s" % [first, last],
				position_name,
				overall,
				attributes["speed"],
				attributes["power"],
				attributes["technique"],
				attributes["awareness"],
				rng.randi_range(21, 32),
				attributes["durability"]
			)
			player.contract = PlayerContract.initial_contract(player, 2026, depth_index)
			roster.append(player)
	return roster


static func _position_base(position_name: String, offense: int, defense: int, special: int) -> int:
	if position_name in ["K", "P"]:
		return special
	if position_name in TeamData.OFFENSIVE_POSITIONS:
		var adjustment := 2 if position_name in ["QB", "WR"] else (-2 if position_name in ["LT", "LG", "C", "RG", "RT"] else 0)
		return offense + adjustment
	var defense_adjustment := 2 if position_name in ["EDGE", "CB"] else 0
	return defense + defense_adjustment


static func _attributes_for_position(position_name: String, overall: int, rng: RandomNumberGenerator) -> Dictionary:
	var speed := overall + rng.randi_range(-6, 6)
	var power := overall + rng.randi_range(-6, 6)
	var technique := overall + rng.randi_range(-4, 5)
	var awareness := overall + rng.randi_range(-5, 5)
	if position_name in ["WR", "CB", "S", "RB"]:
		speed += 6
	if position_name in ["LT", "LG", "C", "RG", "RT", "DT", "EDGE", "TE"]:
		power += 7
	if position_name == "QB":
		technique += 6
		awareness += 5
	if position_name in ["K", "P"]:
		technique += 8
		speed -= 14
	return {
		"speed": clampi(speed, 45, 97),
		"power": clampi(power, 45, 97),
		"technique": clampi(technique, 45, 97),
		"awareness": clampi(awareness, 45, 97),
		"durability": clampi(overall + rng.randi_range(-12, 10), 55, 96),
	}
