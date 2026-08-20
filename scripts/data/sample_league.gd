class_name SampleLeague
extends RefCounted

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
	for position_name in TeamData.ROSTER_POSITIONS:
		for market_index in range(2):
			free_agents.append(PlayerGenerator.generate_free_agent(position_name, 2026, market_index))
	free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return free_agents


static func create_replacement_player(position_name: String, season_year: int, market_index: int) -> PlayerData:
	return PlayerGenerator.generate_replacement(position_name, season_year, market_index)


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
	for position_name: String in counts:
		var position_count: int = counts[position_name]
		for depth_index in range(position_count):
			var base_rating := _position_base(position_name, offense_rating, defense_rating, special_rating)
			var depth_drop := depth_index * rng.randi_range(3, 6)
			var overall := clampi(base_rating + rng.randi_range(-3, 3) - depth_drop, 58, 94)
			var age := rng.randi_range(21, 32)
			var player := PlayerGenerator.generate_roster_player(
				"%s_%s_%d" % [team_id, position_name.to_lower(), depth_index],
				team_id,
				position_name,
				overall,
				age,
				2026,
				depth_index,
				seed * 1009 + position_name.hash() * 31 + depth_index * 97
			)
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
