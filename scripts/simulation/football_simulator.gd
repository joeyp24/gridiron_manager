class_name FootballSimulator
extends RefCounted

var state: GameStateData
var seed: int
var require_winner: bool

var _rng := RandomNumberGenerator.new()
var _offensive_starters: Dictionary = {}
var _defensive_starters: Dictionary = {}


func _init(home: TeamData, away: TeamData, game_seed: int, game_requires_winner: bool = false) -> void:
	seed = game_seed
	require_winner = game_requires_winner
	_rng.seed = game_seed
	state = GameStateData.new(home, away)
	for team in [home, away]:
		_offensive_starters[team.id] = _lineup_ids(team, {
			"QB": 1, "RB": 1, "WR": 3, "TE": 1,
			"LT": 1, "LG": 1, "C": 1, "RG": 1, "RT": 1,
		})
		_defensive_starters[team.id] = _lineup_ids(team, {
			"EDGE": 2, "DT": 2, "LB": 3, "CB": 2, "S": 2,
		})
	if _rng.randf() >= 0.5:
		state.possession_team_id = home.id
		state.opening_possession_team_id = home.id


func simulate_next_play() -> PlayResult:
	if state.is_final:
		return null

	var result := _new_result()
	if state.down == 4 and not _should_go_for_it():
		if _should_attempt_field_goal():
			_resolve_field_goal(result)
		else:
			_resolve_punt(result)
	else:
		var pass_chance := 1.0 - state.offense().run_tendency
		if state.down == 3 and state.yards_to_first >= 7:
			pass_chance += 0.24
		if state.clock_seconds < 150 and state.quarter >= 4 and _offense_is_trailing():
			pass_chance += 0.18
		if _rng.randf() < clampf(pass_chance, 0.20, 0.86):
			_resolve_pass(result)
		else:
			_resolve_run(result)

	GameStatAccumulator.record_play(state, result)
	state.play_count += 1
	result.sequence = state.play_count
	state.play_history.append(result)
	_advance_period_if_needed()
	return result


func simulate_drive() -> Array[PlayResult]:
	var results: Array[PlayResult] = []
	var starting_drive := state.drive_number
	while not state.is_final and state.drive_number == starting_drive and results.size() < 24:
		results.append(simulate_next_play())
	return results


func simulate_to_end(max_plays: int = 500) -> Array[PlayResult]:
	var results: Array[PlayResult] = []
	while not state.is_final and results.size() < max_plays:
		results.append(simulate_next_play())
	if not state.is_final:
		state.is_final = true
	return results


func _resolve_run(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var runner := _select_depth_player(offense, "RB")
	var tackler := _select_defender(defense, ["LB", "S", "DT", "EDGE"])
	var recovery_player := _select_defender(defense, ["LB", "S", "CB", "EDGE"])
	_populate_scrimmage_participants(result, offense, defense, [runner], [tackler, recovery_player])
	result.ball_carrier_id = runner.id
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	var blocking_edge := float(offense.effective_offense_rating() - defense.effective_defense_rating()) * 0.07
	var skill_edge := float(runner.power + runner.speed - 160) * 0.025
	var yards := clampi(roundi(_rng.randfn(4.2 + blocking_edge + skill_edge, 4.3)), -6, 32)
	var fumble_chance := clampf(0.010 + float(defense.effective_defense_rating() - runner.awareness) * 0.0005, 0.004, 0.030)

	result.play_type = "run"
	result.title = "Run"
	if _rng.randf() < fumble_chance:
		_apply_scrimmage_yards(yards)
		_record_yards(offense.id, "run", yards)
		state.stats[offense.id]["turnovers"] += 1
		result.yards = yards
		result.fumble = true
		result.fumble_lost = true
		result.fumbler_id = runner.id
		result.forced_fumble_player_id = tackler.id if tackler != null else ""
		result.recovery_player_id = recovery_player.id if recovery_player != null else result.forced_fumble_player_id
		result.title = "Fumble"
		result.description = "%s loses the football after a %d-yard run. %s recovers." % [runner.full_name, yards, defense.display_name()]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_tempo_clock(_rng.randi_range(22, 38), offense), offense.id)
		state.switch_possession()
		return

	result.yards = yards
	result.description = "%s finds %s for %s." % [
		runner.full_name,
		"a crease" if yards >= 5 else "limited room",
		_yard_phrase(yards),
	]
	_record_yards(offense.id, "run", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_tempo_clock(_rng.randi_range(27, 43), offense), offense.id)


func _resolve_pass(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var quarterback := offense.player_at("QB")
	var receiver := _select_target(offense)
	var edge := _select_depth_player(defense, "EDGE")
	var corner := _select_defender(defense, ["CB", "S"])
	var safety := _select_depth_player(defense, "S")
	var tackler := _select_defender(defense, ["CB", "S", "LB"])
	_populate_scrimmage_participants(result, offense, defense, [quarterback, receiver], [edge, corner, safety, tackler])
	result.passer_id = quarterback.id
	result.target_id = receiver.id
	var coverage_completion_adjustment := 0.0
	var coverage_interception_adjustment := 0.0
	var coverage_yards_adjustment := 0.0
	match defense.coverage_preference:
		"Zone":
			coverage_completion_adjustment = float(quarterback.awareness - safety.awareness) * 0.0012
			coverage_interception_adjustment = 0.004 + float(safety.awareness - quarterback.awareness) * 0.0004
			coverage_yards_adjustment = -1.0
		"Man":
			coverage_completion_adjustment = float(receiver.speed - corner.speed) * 0.0014
			coverage_interception_adjustment = float(corner.technique - receiver.technique) * 0.0003
			coverage_yards_adjustment = 1.0
	var pressure_edge := float(defense.effective_defense_rating() - offense.effective_offense_rating())
	pressure_edge += (defense.blitz_rate - 0.42) * 15.0
	var sack_chance := clampf(0.055 + pressure_edge * 0.0022 + float(edge.technique - 82) * 0.001, 0.025, 0.15)

	result.play_type = "pass"
	result.title = "Pass"

	if _rng.randf() < sack_chance:
		var sack_yards := -_rng.randi_range(3, 10)
		result.play_type = "sack"
		result.title = "Sack"
		result.yards = sack_yards
		result.sack = true
		result.sack_player_id = edge.id
		result.tackler_ids.append(edge.id)
		result.description = "%s breaks through and drops %s for a loss of %d." % [edge.full_name, quarterback.full_name, absi(sack_yards)]
		_record_yards(offense.id, "pass", sack_yards)
		_apply_standard_gain(result, sack_yards)
		_consume_clock(_tempo_clock(_rng.randi_range(20, 34), offense), offense.id)
		return

	var interception_chance := clampf(
		0.017
		+ float(defense.effective_defense_rating() - quarterback.awareness) * 0.0012
		+ offense.aggression * 0.010
		+ coverage_interception_adjustment,
		0.008,
		0.060
	)
	if _rng.randf() < interception_chance:
		var target_depth := clampi(roundi(_rng.randfn(9.0, 7.0)), 0, 28)
		state.field_position = clampi(state.field_position + target_depth, 1, 99)
		state.stats[offense.id]["plays"] += 1
		state.stats[offense.id]["turnovers"] += 1
		result.yards = 0
		result.interception = true
		result.interceptor_id = corner.id
		result.title = "Intercepted"
		result.description = "%s reads the throw and intercepts %s." % [corner.full_name, quarterback.full_name]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_tempo_clock(_rng.randi_range(8, 18), offense), offense.id)
		state.switch_possession()
		return

	var completion_chance := clampf(
		0.60
		+ float(quarterback.technique - defense.effective_defense_rating()) * 0.004
		+ float(receiver.technique - corner.technique) * 0.0025
		- offense.aggression * 0.035
		- (offense.passing_depth - 0.50) * 0.10
		+ coverage_completion_adjustment,
		0.34,
		0.79
	)
	if _rng.randf() >= completion_chance:
		state.stats[offense.id]["plays"] += 1
		result.yards = 0
		if _rng.randf() < 0.14:
			result.dropped_pass = true
		else:
			result.pass_defended = _rng.randf() < 0.55
			result.pass_defender_id = corner.id if result.pass_defended else ""
		result.title = "Incomplete"
		result.description = "%s looks for %s, but the pass falls incomplete." % [quarterback.full_name, receiver.full_name]
		_advance_down_after_no_gain(result)
		_consume_clock(_tempo_clock(_rng.randi_range(5, 9), offense), offense.id)
		return

	var yards := clampi(
		roundi(_rng.randfn(8.5 + float(offense.effective_offense_rating() - defense.effective_defense_rating()) * 0.08 + offense.aggression * 3.0 + (offense.passing_depth - 0.50) * 12.0 + coverage_yards_adjustment, 7.0)),
		-2,
		42
	)
	result.yards = yards
	result.completed_pass = true
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	result.description = "%s connects with %s %s." % [quarterback.full_name, receiver.full_name, _for_yards(yards)]
	_record_yards(offense.id, "pass", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_tempo_clock(_rng.randi_range(17, 34), offense), offense.id)


func _resolve_punt(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var punt_distance := _rng.randi_range(38, 53)
	var punter := offense.player_at("P")
	var long_snapper := offense.player_at("LS")
	result.punter_id = punter.id
	_append_player_id(result.special_teams_participant_ids, punter)
	_append_player_id(result.special_teams_participant_ids, long_snapper)
	var landing_position := state.field_position + punt_distance
	result.play_type = "punt"
	result.title = "Punt"
	result.yards = punt_distance
	result.net_yards = punt_distance
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_tempo_clock(_rng.randi_range(9, 14), offense), offense.id)
	if landing_position >= 100:
		result.punt_touchback = true
		result.net_yards = maxi(0, 75 - result.starting_field_position)
		result.description = "%s punts into the end zone. %s starts at its 25." % [offense.display_name(), defense.abbreviation]
		state.switch_possession(true)
	else:
		state.field_position = landing_position
		state.switch_possession()
		result.description = "%s flips the field with a %d-yard punt." % [offense.display_name(), punt_distance]


func _resolve_field_goal(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var kick_distance := 117 - state.field_position
	var kicker := offense.player_at("K")
	var long_snapper := offense.player_at("LS")
	result.kicker_id = kicker.id
	result.kick_distance = kick_distance
	_append_player_id(result.special_teams_participant_ids, kicker)
	_append_player_id(result.special_teams_participant_ids, long_snapper)
	var kick_chance := clampf(
		0.94
		+ float(offense.effective_special_teams_rating() - 80) * 0.007
		- float(maxi(kick_distance - 35, 0)) * 0.018,
		0.18,
		0.97
	)
	result.play_type = "field_goal"
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_tempo_clock(_rng.randi_range(5, 9), offense), offense.id)
	if _rng.randf() < kick_chance:
		state.add_score(offense.id, 3)
		result.title = "Field goal"
		result.description = "%s converts from %d yards." % [offense.display_name(), kick_distance]
		result.points = 3
		result.scoring_play = true
		result.field_goal_made = true
		state.switch_possession(true)
	else:
		result.title = "No good"
		result.description = "%s misses the %d-yard attempt." % [offense.display_name(), kick_distance]
		state.switch_possession()


func _apply_standard_gain(result: PlayResult, yards: int) -> void:
	var offense_id := state.possession_team_id
	state.field_position = clampi(state.field_position + yards, 1, 100)
	if state.field_position >= 100:
		state.add_score(offense_id, 7)
		result.title = "Touchdown"
		result.description = "%s Touchdown — %s" % [state.offense().abbreviation, result.description]
		result.points = 7
		result.scoring_play = true
		result.touchdown = true
		var kicker := state.team_by_id(offense_id).player_at("K")
		if kicker != null:
			result.kicker_id = kicker.id
		result.drive_ended = true
		result.possession_changed = true
		state.switch_possession(true)
		return

	if yards >= state.yards_to_first:
		state.down = 1
		state.yards_to_first = mini(10, 100 - state.field_position)
		state.stats[offense_id]["first_downs"] += 1
		result.first_down = true
		result.title = "First down"
	else:
		state.down += 1
		state.yards_to_first = maxi(1, state.yards_to_first - yards)
		if state.down > 4:
			result.title = "Turnover on downs"
			result.description += " The defense holds on fourth down."
			result.drive_ended = true
			result.possession_changed = true
			state.switch_possession()


func _advance_down_after_no_gain(result: PlayResult) -> void:
	state.down += 1
	if state.down > 4:
		result.title = "Turnover on downs"
		result.description += " Possession changes hands."
		result.drive_ended = true
		result.possession_changed = true
		state.switch_possession()


func _apply_scrimmage_yards(yards: int) -> void:
	state.field_position = clampi(state.field_position + yards, 1, 99)


func _record_yards(team_id: String, play_type: String, yards: int) -> void:
	state.stats[team_id]["plays"] += 1
	state.stats[team_id]["total_yards"] += yards
	if play_type == "run":
		state.stats[team_id]["rush_yards"] += yards
	else:
		state.stats[team_id]["pass_yards"] += yards


func _consume_clock(seconds: int, offense_id: String) -> void:
	var consumed := mini(seconds, state.clock_seconds)
	state.clock_seconds -= consumed
	state.stats[offense_id]["possession_seconds"] += consumed


func _tempo_clock(seconds: int, offense: TeamData) -> int:
	var multiplier := lerpf(1.18, 0.76, clampf(offense.tempo, 0.0, 1.0))
	return maxi(3, roundi(float(seconds) * multiplier))


func _advance_period_if_needed() -> void:
	if state.clock_seconds > 0:
		return
	if state.quarter < 4:
		var completed_quarter := state.quarter
		state.quarter += 1
		state.clock_seconds = 900
		if completed_quarter == 2:
			state.possession_team_id = (
				state.away_team.id
				if state.opening_possession_team_id == state.home_team.id
				else state.home_team.id
			)
			state.field_position = 25
			state.down = 1
			state.yards_to_first = 10
			state.drive_number += 1
		return
	if state.quarter == 4 and state.home_score == state.away_score:
		state.quarter = 5
		state.clock_seconds = 600
		state.switch_possession(true)
		return
	if state.quarter > 4 and require_winner and state.home_score == state.away_score:
		state.quarter += 1
		state.clock_seconds = 600
		state.switch_possession(true)
		return
	state.is_final = true


func _should_go_for_it() -> bool:
	var situational_boost := 0.0
	if state.field_position >= 50:
		situational_boost += 0.15
	if state.yards_to_first <= 2:
		situational_boost += 0.22
	if state.quarter >= 4 and _offense_is_trailing():
		situational_boost += 0.38
	return _rng.randf() < clampf(state.offense().aggression * 0.30 + situational_boost, 0.03, 0.82)


func _should_attempt_field_goal() -> bool:
	var kick_distance := 117 - state.field_position
	return kick_distance <= 59 and state.field_position >= 45


func _offense_is_trailing() -> bool:
	return state.score_for(state.offense().id) < state.score_for(state.defense().id)


func _new_result() -> PlayResult:
	var result := PlayResult.new()
	result.quarter = state.quarter
	result.clock_seconds = state.clock_seconds
	result.offense_id = state.possession_team_id
	result.defense_id = state.defense().id
	result.down = state.down
	result.yards_to_first = state.yards_to_first
	result.starting_field_position = state.field_position
	return result


func _populate_scrimmage_participants(
	result: PlayResult,
	offense: TeamData,
	defense: TeamData,
	extra_offense: Array,
	extra_defense: Array
) -> void:
	var offense_starters: Array[String] = _offensive_starters[offense.id]
	var defense_starters: Array[String] = _defensive_starters[defense.id]
	result.offensive_starter_ids = offense_starters.duplicate()
	result.defensive_starter_ids = defense_starters.duplicate()
	result.offensive_participant_ids = result.offensive_starter_ids.duplicate()
	result.defensive_participant_ids = result.defensive_starter_ids.duplicate()
	for player in extra_offense:
		_replace_position_participant(result.offensive_participant_ids, offense, player)
	for player in extra_defense:
		_replace_position_participant(result.defensive_participant_ids, defense, player)


func _lineup_ids(team: TeamData, position_counts: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for position_name in position_counts:
		var needed := int(position_counts[position_name])
		for player in team.depth_players(str(position_name)):
			if not player.is_available():
				continue
			_append_player_id(ids, player)
			needed -= 1
			if needed <= 0:
				break
	return ids


func _select_depth_player(team: TeamData, position_name: String) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	var depth_index := 0
	for player in team.depth_players(position_name):
		if not player.is_available():
			continue
		candidates.append(player)
		weights.append(maxf(float(player.effective_overall()), 1.0) * pow(0.38, depth_index))
		depth_index += 1
		if candidates.size() >= 4:
			break
	return _weighted_player(candidates, weights, team.player_at(position_name))


func _select_target(team: TeamData) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	var position_weight := {"WR": 1.0, "TE": 0.66, "RB": 0.38}
	for position_name in ["WR", "TE", "RB"]:
		var depth_index := 0
		for player in team.depth_players(position_name):
			if not player.is_available():
				continue
			candidates.append(player)
			weights.append(
				maxf(float(player.technique + player.speed), 1.0)
				* float(position_weight[position_name])
				* pow(0.58, depth_index)
			)
			depth_index += 1
			if depth_index >= 4:
				break
	return _weighted_player(candidates, weights, team.player_at("WR"))


func _select_defender(team: TeamData, positions: Array[String]) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	for position_name in positions:
		var depth_index := 0
		for player in team.depth_players(position_name):
			if not player.is_available():
				continue
			candidates.append(player)
			weights.append(maxf(float(player.awareness + player.technique), 1.0) * pow(0.52, depth_index))
			depth_index += 1
			if depth_index >= 3:
				break
	return _weighted_player(candidates, weights, team.player_at(positions.front()))


func _weighted_player(candidates: Array[PlayerData], weights: Array[float], fallback: PlayerData) -> PlayerData:
	if candidates.is_empty():
		return fallback
	var total := 0.0
	for weight in weights:
		total += weight
	var roll := _rng.randf() * total
	for index in range(candidates.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func _append_player_id(ids: Array[String], player: PlayerData) -> void:
	if player != null and not ids.has(player.id):
		ids.append(player.id)


func _replace_position_participant(ids: Array[String], team: TeamData, player: PlayerData) -> void:
	if player == null or ids.has(player.id):
		return
	for index in range(ids.size() - 1, -1, -1):
		var current := team.player_by_id(ids[index])
		if current != null and current.position == player.position:
			ids[index] = player.id
			return
	ids.append(player.id)


func _yard_phrase(yards: int) -> String:
	if yards < 0:
		return "a loss of %d" % absi(yards)
	if yards == 0:
		return "no gain"
	return "%d yards" % yards


func _for_yards(yards: int) -> String:
	if yards < 0:
		return "for a loss of %d" % absi(yards)
	if yards == 0:
		return "at the line of scrimmage"
	return "for %d yards" % yards
