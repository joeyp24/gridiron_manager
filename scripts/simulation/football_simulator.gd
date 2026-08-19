class_name FootballSimulator
extends RefCounted

var state: GameStateData
var seed: int

var _rng := RandomNumberGenerator.new()


func _init(home: TeamData, away: TeamData, game_seed: int) -> void:
	seed = game_seed
	_rng.seed = game_seed
	state = GameStateData.new(home, away)
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
	var runner := offense.player_at("RB")
	var blocking_edge := float(offense.offense_rating - defense.defense_rating) * 0.07
	var skill_edge := float(runner.power + runner.speed - 160) * 0.025
	var yards := clampi(roundi(_rng.randfn(4.2 + blocking_edge + skill_edge, 4.3)), -6, 32)
	var fumble_chance := clampf(0.010 + float(defense.defense_rating - runner.awareness) * 0.0005, 0.004, 0.030)

	result.play_type = "run"
	result.title = "Run"
	if _rng.randf() < fumble_chance:
		_apply_scrimmage_yards(yards)
		_record_yards(offense.id, "run", yards)
		state.stats[offense.id]["turnovers"] += 1
		result.yards = yards
		result.title = "Fumble"
		result.description = "%s loses the football after a %d-yard run. %s recovers." % [runner.full_name, yards, defense.display_name()]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_rng.randi_range(22, 38), offense.id)
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
	_consume_clock(_rng.randi_range(27, 43), offense.id)


func _resolve_pass(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var quarterback := offense.player_at("QB")
	var receiver := offense.player_at("WR")
	var edge := defense.player_at("EDGE")
	var corner := defense.player_at("CB")
	var pressure_edge := float(defense.defense_rating - offense.offense_rating)
	var sack_chance := clampf(0.055 + pressure_edge * 0.0022 + float(edge.technique - 82) * 0.001, 0.025, 0.15)

	result.play_type = "pass"
	result.title = "Pass"

	if _rng.randf() < sack_chance:
		var sack_yards := -_rng.randi_range(3, 10)
		result.play_type = "sack"
		result.title = "Sack"
		result.yards = sack_yards
		result.description = "%s breaks through and drops %s for a loss of %d." % [edge.full_name, quarterback.full_name, absi(sack_yards)]
		_record_yards(offense.id, "pass", sack_yards)
		_apply_standard_gain(result, sack_yards)
		_consume_clock(_rng.randi_range(20, 34), offense.id)
		return

	var interception_chance := clampf(
		0.017
		+ float(defense.defense_rating - quarterback.awareness) * 0.0012
		+ offense.aggression * 0.010,
		0.008,
		0.060
	)
	if _rng.randf() < interception_chance:
		var target_depth := clampi(roundi(_rng.randfn(9.0, 7.0)), 0, 28)
		state.field_position = clampi(state.field_position + target_depth, 1, 99)
		state.stats[offense.id]["plays"] += 1
		state.stats[offense.id]["turnovers"] += 1
		result.yards = 0
		result.title = "Intercepted"
		result.description = "%s reads the throw and intercepts %s." % [corner.full_name, quarterback.full_name]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_rng.randi_range(8, 18), offense.id)
		state.switch_possession()
		return

	var completion_chance := clampf(
		0.60
		+ float(quarterback.technique - defense.defense_rating) * 0.004
		+ float(receiver.technique - corner.technique) * 0.0025
		- offense.aggression * 0.035,
		0.34,
		0.79
	)
	if _rng.randf() >= completion_chance:
		state.stats[offense.id]["plays"] += 1
		result.yards = 0
		result.title = "Incomplete"
		result.description = "%s looks for %s, but the pass falls incomplete." % [quarterback.full_name, receiver.full_name]
		_advance_down_after_no_gain(result)
		_consume_clock(_rng.randi_range(5, 9), offense.id)
		return

	var yards := clampi(
		roundi(_rng.randfn(8.5 + float(offense.offense_rating - defense.defense_rating) * 0.08 + offense.aggression * 3.0, 7.0)),
		-2,
		42
	)
	result.yards = yards
	result.description = "%s connects with %s %s." % [quarterback.full_name, receiver.full_name, _for_yards(yards)]
	_record_yards(offense.id, "pass", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_rng.randi_range(17, 34), offense.id)


func _resolve_punt(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var punt_distance := _rng.randi_range(38, 53)
	var landing_position := state.field_position + punt_distance
	result.play_type = "punt"
	result.title = "Punt"
	result.yards = punt_distance
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_rng.randi_range(9, 14), offense.id)
	if landing_position >= 100:
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
	var kick_chance := clampf(
		0.94
		+ float(offense.special_teams_rating - 80) * 0.007
		- float(maxi(kick_distance - 35, 0)) * 0.018,
		0.18,
		0.97
	)
	result.play_type = "field_goal"
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_rng.randi_range(5, 9), offense.id)
	if _rng.randf() < kick_chance:
		state.add_score(offense.id, 3)
		result.title = "Field goal"
		result.description = "%s converts from %d yards." % [offense.display_name(), kick_distance]
		result.points = 3
		result.scoring_play = true
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
		result.drive_ended = true
		result.possession_changed = true
		state.switch_possession(true)
		return

	if yards >= state.yards_to_first:
		state.down = 1
		state.yards_to_first = mini(10, 100 - state.field_position)
		state.stats[offense_id]["first_downs"] += 1
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
	return result


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
