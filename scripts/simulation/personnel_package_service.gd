class_name PersonnelPackageService
extends RefCounted

const OFFENSIVE_PACKAGES := {
	"10": {"QB": 1, "RB": 1, "WR": 4, "TE": 0, "LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1},
	"11": {"QB": 1, "RB": 1, "WR": 3, "TE": 1, "LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1},
	"12": {"QB": 1, "RB": 1, "WR": 2, "TE": 2, "LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1},
	"21": {"QB": 1, "RB": 2, "WR": 2, "TE": 1, "LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1},
	"22": {"QB": 1, "RB": 2, "WR": 1, "TE": 2, "LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1},
}

const DEFENSIVE_PACKAGES := {
	"Base": {"EDGE": 2, "DT": 2, "LB": 3, "CB": 2, "S": 2},
	"Nickel": {"EDGE": 2, "DT": 2, "LB": 2, "CB": 3, "S": 2},
	"Dime": {"EDGE": 2, "DT": 2, "LB": 1, "CB": 4, "S": 2},
	"Goal Line": {"EDGE": 2, "DT": 3, "LB": 4, "CB": 1, "S": 1},
}


static func offensive_counts(personnel: String) -> Dictionary:
	return Dictionary(OFFENSIVE_PACKAGES.get(personnel, OFFENSIVE_PACKAGES["11"])).duplicate()


static func defensive_counts(personnel: String) -> Dictionary:
	return Dictionary(DEFENSIVE_PACKAGES.get(personnel, DEFENSIVE_PACKAGES["Base"])).duplicate()


static func offensive_lineup(team: TeamData, personnel: String) -> Array[PlayerData]:
	return lineup(team, offensive_counts(personnel))


static func defensive_lineup(team: TeamData, personnel: String) -> Array[PlayerData]:
	return lineup(team, defensive_counts(personnel))


static func lineup(team: TeamData, position_counts: Dictionary) -> Array[PlayerData]:
	var selected: Array[PlayerData] = []
	var used: Dictionary = {}
	if team == null:
		return selected
	for position_name in position_counts:
		var needed := int(position_counts[position_name])
		if needed <= 0:
			continue
		for player in team.depth_players(str(position_name)):
			if not player.is_available() or used.has(player.id):
				continue
			selected.append(player)
			used[player.id] = true
			needed -= 1
			if needed <= 0:
				break
	# A depleted custom roster still fields a legal unit with the best available
	# substitutes. Standard 53-player rosters never need this fallback.
	if selected.size() < 11:
		var substitutes: Array[PlayerData] = []
		for player in team.players:
			if player.is_available() and not used.has(player.id):
				substitutes.append(player)
		substitutes.sort_custom(func(a: PlayerData, b: PlayerData):
			return a.effective_overall() > b.effective_overall()
		)
		for player in substitutes:
			selected.append(player)
			used[player.id] = true
			if selected.size() >= 11:
				break
	return selected


static func players_at(lineup_players: Array[PlayerData], positions: Array[String]) -> Array[PlayerData]:
	var matches: Array[PlayerData] = []
	for player in lineup_players:
		if player != null and player.position in positions:
			matches.append(player)
	return matches


static func blockers(lineup_players: Array[PlayerData], ball_carrier: PlayerData = null) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player in lineup_players:
		if player == null or player == ball_carrier:
			continue
		if player.position in ["LT", "LG", "C", "RG", "RT", "TE", "RB"]:
			result.append(player)
	return result


static func pass_protectors(lineup_players: Array[PlayerData], quarterback: PlayerData) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	for player in lineup_players:
		if player == null or player == quarterback:
			continue
		if player.position in ["LT", "LG", "C", "RG", "RT"]:
			result.append(player)
	return result


static func rushers(lineup_players: Array[PlayerData]) -> Array[PlayerData]:
	return players_at(lineup_players, ["EDGE", "DT", "LB"])


static func ids(lineup_players: Array[PlayerData]) -> Array[String]:
	var result: Array[String] = []
	for player in lineup_players:
		if player != null and not result.has(player.id):
			result.append(player.id)
	return result
