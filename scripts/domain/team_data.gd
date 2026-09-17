class_name TeamData
extends RefCounted

const OFFENSIVE_POSITIONS: Array[String] = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT"]
const DEFENSIVE_POSITIONS: Array[String] = ["EDGE", "DT", "LB", "CB", "S"]
const ROSTER_POSITIONS: Array[String] = ["QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT", "EDGE", "DT", "LB", "CB", "S", "K", "P", "LS"]
const DEFAULT_SALARY_CAP := 301_200_000
const MIN_ROSTER_SIZE := 35
const DEFAULT_ROSTER_LIMIT := 53
const OFFSEASON_ROSTER_LIMIT := 90

var id: String
var city: String
var nickname: String
var abbreviation: String
var conference: String
var division := ""
var primary_color: Color
var secondary_color: Color
var logo_url := ""
var offense_rating: int
var defense_rating: int
var special_teams_rating: int
var run_tendency := 0.46
var aggression := 0.50
var tempo := 0.50
var passing_depth := 0.50
var blitz_rate := 0.42
var coverage_preference := "Balanced"
var players: Array[PlayerData] = []
var injured_reserve: Array[PlayerData] = []
var practice_squad: Array[PlayerData] = []
var depth_chart: Dictionary = {}
var salary_cap := DEFAULT_SALARY_CAP
var base_salary_cap := DEFAULT_SALARY_CAP
var salary_cap_adjustment := 0
var salary_cap_year := 2026
var roster_limit := DEFAULT_ROSTER_LIMIT
var game_day_active_limit := 48
var practice_squad_limit := 16
var practice_squad_veteran_limit := 6
var injured_reserve_minimum_weeks := 4
var dead_cap := 0


func _init(
	team_id: String = "",
	team_city: String = "",
	team_nickname: String = "",
	team_abbreviation: String = "",
	team_conference: String = "",
	team_primary_color: Color = Color.WHITE,
	team_secondary_color: Color = Color.BLACK,
	offense: int = 50,
	defense: int = 50,
	special_teams: int = 50,
	team_players: Array[PlayerData] = []
) -> void:
	id = team_id
	city = team_city
	nickname = team_nickname
	abbreviation = team_abbreviation
	conference = team_conference
	primary_color = team_primary_color
	secondary_color = team_secondary_color
	offense_rating = offense
	defense_rating = defense
	special_teams_rating = special_teams
	players = team_players
	initialize_depth_chart()


func display_name() -> String:
	return "%s %s" % [city, nickname]


func overall_rating() -> int:
	return roundi(
		float(effective_offense_rating()) * 0.45
		+ float(effective_defense_rating()) * 0.45
		+ float(effective_special_teams_rating()) * 0.10
	)


func initialize_depth_chart() -> void:
	depth_chart.clear()
	for roster_position in ROSTER_POSITIONS:
		var position_players := players_at(roster_position)
		position_players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		var ids: Array[String] = []
		for player in position_players:
			ids.append(player.id)
		depth_chart[roster_position] = ids


func players_at(position_name: String, available_only: bool = false) -> Array[PlayerData]:
	var matches: Array[PlayerData] = []
	for player in players:
		if player.position == position_name and (not available_only or player.is_available()):
			matches.append(player)
	return matches


func depth_players(position_name: String) -> Array[PlayerData]:
	var ordered: Array[PlayerData] = []
	var seen: Dictionary = {}
	var ids: Array = depth_chart.get(position_name, [])
	for player_id in ids:
		var player := player_by_id(str(player_id))
		if player != null:
			ordered.append(player)
			seen[player.id] = true
	for player in players_at(position_name):
		if not seen.has(player.id):
			ordered.append(player)
	return ordered


func player_at(position_name: String) -> PlayerData:
	if position_name == "OL":
		return _best_available_from(["LT", "LG", "C", "RG", "RT"])
	for player in depth_players(position_name):
		if player.is_available():
			return player
	if position_name in OFFENSIVE_POSITIONS:
		return _best_available_from(OFFENSIVE_POSITIONS)
	if position_name in DEFENSIVE_POSITIONS:
		return _best_available_from(DEFENSIVE_POSITIONS)
	return _best_available_from(ROSTER_POSITIONS)


func player_by_id(player_id: String) -> PlayerData:
	for player in players:
		if player.id == player_id:
			return player
	return null


func injured_reserve_player_by_id(player_id: String) -> PlayerData:
	for player in injured_reserve:
		if player.id == player_id:
			return player
	return null


func practice_squad_player_by_id(player_id: String) -> PlayerData:
	for player in practice_squad:
		if player.id == player_id:
			return player
	return null


func owned_player_by_id(player_id: String) -> PlayerData:
	var player := player_by_id(player_id)
	if player != null:
		return player
	player = injured_reserve_player_by_id(player_id)
	return player if player != null else practice_squad_player_by_id(player_id)


func all_contract_players() -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	result.append_array(players)
	result.append_array(injured_reserve)
	result.append_array(practice_squad)
	return result


func add_player(player: PlayerData, allowed_limit: int = -1) -> bool:
	var limit := roster_limit if allowed_limit < 0 else allowed_limit
	if player == null or owned_player_by_id(player.id) != null or players.size() >= limit:
		return false
	players.append(player)
	var ids: Array = depth_chart.get(player.position, [])
	var insert_index := ids.size()
	for index in range(ids.size()):
		var depth_player := player_by_id(str(ids[index]))
		if depth_player != null and player.overall > depth_player.overall:
			insert_index = index
			break
	ids.insert(insert_index, player.id)
	depth_chart[player.position] = ids
	return true


func remove_player(player_id: String) -> PlayerData:
	var player := player_by_id(player_id)
	if player == null:
		return null
	players.erase(player)
	var ids: Array = depth_chart.get(player.position, [])
	ids.erase(player.id)
	depth_chart[player.position] = ids
	return player


func remove_owned_player(player_id: String) -> PlayerData:
	var player := remove_player(player_id)
	if player != null:
		return player
	player = injured_reserve_player_by_id(player_id)
	if player != null:
		injured_reserve.erase(player)
		return player
	player = practice_squad_player_by_id(player_id)
	if player != null:
		practice_squad.erase(player)
	return player


func add_injured_reserve_player(player: PlayerData) -> bool:
	if player == null or owned_player_by_id(player.id) != null:
		return false
	injured_reserve.append(player)
	return true


func add_practice_squad_player(player: PlayerData) -> bool:
	if player == null or owned_player_by_id(player.id) != null or practice_squad.size() >= practice_squad_limit:
		return false
	practice_squad.append(player)
	return true


func payroll() -> int:
	return payroll_for_year(salary_cap_year)


func payroll_for_year(season_year: int) -> int:
	var total := dead_cap
	for player in all_contract_players():
		if player.contract != null:
			total += player.contract.cap_hit_for_year(season_year)
	return total


func cap_space() -> int:
	return salary_cap - payroll()


func cap_space_for_year(season_year: int) -> int:
	return salary_cap - payroll_for_year(season_year)


func has_roster_space() -> bool:
	return players.size() < roster_limit


func configure_roster_rules(format: LeagueFormatData) -> void:
	roster_limit = format.roster_size
	game_day_active_limit = format.game_day_active_limit
	practice_squad_limit = format.practice_squad_limit
	practice_squad_veteran_limit = format.practice_squad_veteran_limit
	injured_reserve_minimum_weeks = format.injured_reserve_minimum_weeks


func configure_game_day_roster() -> void:
	for player in players:
		player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, player.status_changed_week)
	var activated: Dictionary = {}
	for position_name in ROSTER_POSITIONS:
		var candidates := depth_players(position_name)
		for candidate in candidates:
			if candidate.injury_weeks <= 0:
				candidate.set_roster_status(PlayerData.STATUS_ACTIVE_ROSTER, candidate.status_changed_week)
				activated[candidate.id] = true
				break
	var available := players.duplicate()
	available.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	for player: PlayerData in available:
		if active_roster_count() >= game_day_active_limit:
			break
		if player.injury_weeks <= 0 and not activated.has(player.id):
			player.set_roster_status(PlayerData.STATUS_ACTIVE_ROSTER, player.status_changed_week)
			activated[player.id] = true


func move_on_depth_chart(position_name: String, player_id: String, direction: int) -> bool:
	var ids: Array = depth_chart.get(position_name, [])
	var current_index := ids.find(player_id)
	if current_index < 0:
		return false
	var target_index := clampi(current_index + direction, 0, ids.size() - 1)
	if target_index == current_index:
		return false
	var displaced = ids[target_index]
	ids[target_index] = ids[current_index]
	ids[current_index] = displaced
	depth_chart[position_name] = ids
	return true


func set_strategy(values: Dictionary) -> void:
	run_tendency = float(values.get("run_tendency", run_tendency))
	aggression = float(values.get("aggression", aggression))
	tempo = float(values.get("tempo", tempo))
	passing_depth = float(values.get("passing_depth", passing_depth))
	blitz_rate = float(values.get("blitz_rate", blitz_rate))
	coverage_preference = str(values.get("coverage_preference", coverage_preference))


func strategy_dict() -> Dictionary:
	return {
		"run_tendency": run_tendency,
		"aggression": aggression,
		"tempo": tempo,
		"passing_depth": passing_depth,
		"blitz_rate": blitz_rate,
		"coverage_preference": coverage_preference,
	}


func clone_with_strategy(strategy: Dictionary) -> TeamData:
	var cloned_players: Array[PlayerData] = []
	for player in players:
		cloned_players.append(PlayerData.from_dict(player.to_dict()))
	var clone := TeamData.new(
		id, city, nickname, abbreviation, conference, primary_color, secondary_color,
		offense_rating, defense_rating, special_teams_rating, cloned_players
	)
	clone.division = division
	clone.depth_chart = depth_chart.duplicate(true)
	clone.salary_cap = salary_cap
	clone.base_salary_cap = base_salary_cap
	clone.salary_cap_adjustment = salary_cap_adjustment
	clone.salary_cap_year = salary_cap_year
	clone.roster_limit = roster_limit
	clone.game_day_active_limit = game_day_active_limit
	clone.practice_squad_limit = practice_squad_limit
	clone.practice_squad_veteran_limit = practice_squad_veteran_limit
	clone.injured_reserve_minimum_weeks = injured_reserve_minimum_weeks
	clone.dead_cap = dead_cap
	clone.logo_url = logo_url
	for player in injured_reserve:
		clone.injured_reserve.append(PlayerData.from_dict(player.to_dict()))
	for player in practice_squad:
		clone.practice_squad.append(PlayerData.from_dict(player.to_dict()))
	clone.set_strategy(strategy_dict())
	clone.set_strategy(strategy)
	return clone


func effective_offense_rating() -> int:
	var lineup := _unit_average(OFFENSIVE_POSITIONS)
	return roundi(float(offense_rating) * 0.38 + float(lineup) * 0.62)


func effective_defense_rating() -> int:
	var lineup := _unit_average(DEFENSIVE_POSITIONS)
	return roundi(float(defense_rating) * 0.38 + float(lineup) * 0.62)


func effective_special_teams_rating() -> int:
	var lineup := _unit_average(["K", "P"])
	return roundi(float(special_teams_rating) * 0.55 + float(lineup) * 0.45)


func recalculate_ratings_from_roster() -> void:
	offense_rating = _unit_average(OFFENSIVE_POSITIONS)
	defense_rating = _unit_average(DEFENSIVE_POSITIONS)
	special_teams_rating = _unit_average(["K", "P"])


func active_roster_count() -> int:
	var count := 0
	for player in players:
		if player.is_active:
			count += 1
	return count


func injured_players() -> Array[PlayerData]:
	var injured: Array[PlayerData] = []
	for player in players:
		if player.injury_weeks > 0:
			injured.append(player)
	injured.append_array(injured_reserve)
	return injured


func to_dict() -> Dictionary:
	var serialized_players: Array[Dictionary] = []
	for player in players:
		serialized_players.append(player.to_dict())
	var serialized_injured_reserve: Array[Dictionary] = []
	for player in injured_reserve:
		serialized_injured_reserve.append(player.to_dict())
	var serialized_practice_squad: Array[Dictionary] = []
	for player in practice_squad:
		serialized_practice_squad.append(player.to_dict())
	return {
		"id": id,
		"city": city,
		"nickname": nickname,
		"abbreviation": abbreviation,
		"conference": conference,
		"division": division,
		"primary_color": primary_color.to_html(false),
		"secondary_color": secondary_color.to_html(false),
		"logo_url": logo_url,
		"offense_rating": offense_rating,
		"defense_rating": defense_rating,
		"special_teams_rating": special_teams_rating,
		"strategy": strategy_dict(),
		"players": serialized_players,
		"injured_reserve": serialized_injured_reserve,
		"practice_squad": serialized_practice_squad,
		"depth_chart": depth_chart.duplicate(true),
		"salary_cap": salary_cap,
		"base_salary_cap": base_salary_cap,
		"salary_cap_adjustment": salary_cap_adjustment,
		"salary_cap_year": salary_cap_year,
		"roster_limit": roster_limit,
		"game_day_active_limit": game_day_active_limit,
		"practice_squad_limit": practice_squad_limit,
		"practice_squad_veteran_limit": practice_squad_veteran_limit,
		"injured_reserve_minimum_weeks": injured_reserve_minimum_weeks,
		"dead_cap": dead_cap,
	}


static func from_dict(data: Dictionary) -> TeamData:
	var loaded_players: Array[PlayerData] = []
	for player_data in data.get("players", []):
		loaded_players.append(PlayerData.from_dict(player_data))
	var team := TeamData.new(
		str(data.get("id", "")),
		str(data.get("city", "")),
		str(data.get("nickname", "")),
		str(data.get("abbreviation", "")),
		str(data.get("conference", "")),
		Color(str(data.get("primary_color", "ffffff"))),
		Color(str(data.get("secondary_color", "000000"))),
		int(data.get("offense_rating", 50)),
		int(data.get("defense_rating", 50)),
		int(data.get("special_teams_rating", 50)),
		loaded_players
	)
	team.set_strategy(data.get("strategy", {}))
	team.division = str(data.get("division", ""))
	team.depth_chart = data.get("depth_chart", team.depth_chart).duplicate(true)
	team.salary_cap = int(data.get("salary_cap", DEFAULT_SALARY_CAP))
	team.base_salary_cap = int(data.get("base_salary_cap", mini(team.salary_cap, DEFAULT_SALARY_CAP)))
	team.salary_cap_adjustment = int(data.get("salary_cap_adjustment", team.salary_cap - team.base_salary_cap))
	team.salary_cap_year = int(data.get("salary_cap_year", 2026))
	team.roster_limit = int(data.get("roster_limit", DEFAULT_ROSTER_LIMIT))
	team.game_day_active_limit = int(data.get("game_day_active_limit", team.roster_limit))
	team.practice_squad_limit = int(data.get("practice_squad_limit", 16 if team.roster_limit >= DEFAULT_ROSTER_LIMIT else 8))
	team.practice_squad_veteran_limit = int(data.get("practice_squad_veteran_limit", 6 if team.roster_limit >= DEFAULT_ROSTER_LIMIT else 4))
	team.injured_reserve_minimum_weeks = int(data.get("injured_reserve_minimum_weeks", 4))
	team.dead_cap = int(data.get("dead_cap", 0))
	team.logo_url = str(data.get("logo_url", ""))
	for player_data in data.get("injured_reserve", []):
		team.injured_reserve.append(PlayerData.from_dict(player_data))
	for player_data in data.get("practice_squad", []):
		team.practice_squad.append(PlayerData.from_dict(player_data))
	return team


func _unit_average(positions: Array[String]) -> int:
	var total := 0
	var count := 0
	for position_name in positions:
		var starter := player_at(position_name)
		if starter != null:
			total += starter.effective_overall()
			count += 1
	return roundi(float(total) / float(count)) if count > 0 else 50


func _best_available_from(positions: Array[String]) -> PlayerData:
	var best: PlayerData
	for player in players:
		if player.position in positions and player.is_available():
			if best == null or player.effective_overall() > best.effective_overall():
				best = player
	if best != null:
		return best
	return players.front() if not players.is_empty() else null
