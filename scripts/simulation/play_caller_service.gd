class_name PlayCallerService
extends RefCounted

static var _defensive_call_cache: Array[DefensiveCallData] = []


static func available_plays(state: GameStateData, playbook: PlaybookData) -> Array[PlayDefinitionData]:
	var available: Array[PlayDefinitionData] = []
	if state == null or playbook == null or state.is_final:
		return available
	for play in playbook.plays:
		if validation_error(state, play).is_empty():
			available.append(play)
	return available


static func validation_error(state: GameStateData, play: PlayDefinitionData) -> String:
	if state == null or state.is_final:
		return "The game is complete."
	if play == null:
		return "That play is not in the active playbook."
	var offense := state.offense()
	if offense == null:
		return "No offense is available."
	if play.play_type in ["pass", "spike"] and offense.players_at("QB", true).is_empty():
		return "No quarterback is available for this call."
	if play.play_type == "run" and offense.players_at(play.runner_position, true).is_empty():
		return "No available %s can carry the ball." % play.runner_position
	if play.play_type == "pass" and not play.target_positions.is_empty():
		var has_target := false
		for position_name in play.target_positions:
			if not offense.players_at(position_name, true).is_empty():
				has_target = true
				break
		if not has_target:
			return "No eligible target is available for this concept."
	if play.play_type == "field_goal":
		var distance := 117 - state.field_position
		if distance > 64:
			return "A %d-yard field goal is outside the call sheet's range." % distance
		if offense.players_at("K", true).is_empty():
			return "No kicker is available."
	if play.play_type == "punt" and offense.players_at("P", true).is_empty():
		return "No punter is available."
	return ""


static func recommendations(state: GameStateData, playbook: PlaybookData, limit: int = 3) -> Array[PlayDefinitionData]:
	var ranked := available_plays(state, playbook)
	ranked.sort_custom(func(a: PlayDefinitionData, b: PlayDefinitionData):
		var first := _recommendation_score(state, a)
		var second := _recommendation_score(state, b)
		if not is_equal_approx(first, second):
			return first > second
		return a.id < b.id
	)
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked


static func automatic_call(state: GameStateData, playbook: PlaybookData, rng: RandomNumberGenerator) -> PlayCallData:
	if state == null or playbook == null or state.is_final:
		return PlayCallData.new()
	if state.down == 4 and not _should_go_for_it(state, rng):
		var kick := playbook.play_by_id("field_goal")
		if kick != null and validation_error(state, kick).is_empty() and _should_attempt_field_goal(state):
			return PlayCallData.new(kick.id, _automatic_tempo(state), false)
		var punt := playbook.play_by_id("punt")
		if punt != null and validation_error(state, punt).is_empty():
			return PlayCallData.new(punt.id, _automatic_tempo(state), false)

	var pass_chance := 1.0 - state.offense().run_tendency
	if state.down == 3 and state.yards_to_first >= 7:
		pass_chance += 0.24
	if state.clock_seconds < 150 and state.quarter >= 4 and _offense_is_trailing(state):
		pass_chance += 0.18
	var desired_type := "pass" if rng.randf() < clampf(pass_chance, 0.20, 0.86) else "run"
	var candidates := playbook.plays_in_category("Pass" if desired_type == "pass" else "Run")
	if candidates.is_empty():
		candidates = available_plays(state, playbook)
		if candidates.is_empty():
			return PlayCallData.new()
	var chosen: PlayDefinitionData = candidates.front()
	var chosen_score: float = -INF
	for play in candidates:
		var score := _recommendation_score(state, play) + rng.randf_range(-10.0, 10.0)
		if score > chosen_score:
			chosen = play
			chosen_score = score
	# Standard 53-player rosters can rank their category directly. Validate the
	# winner once, then use the complete availability scan only for depleted or
	# custom rosters where that call cannot be executed.
	if not validation_error(state, chosen).is_empty():
		var available := available_plays(state, playbook)
		if available.is_empty():
			return PlayCallData.new()
		chosen = available.front()
		chosen_score = -INF
		for play in available:
			var score := _recommendation_score(state, play) + rng.randf_range(-10.0, 10.0)
			if score > chosen_score:
				chosen = play
				chosen_score = score
	return PlayCallData.new(chosen.id, _automatic_tempo(state), false)


static func automatic_defensive_call(state: GameStateData, rng: RandomNumberGenerator) -> DefensiveCallData:
	var calls: Array[DefensiveCallData] = _defensive_calls()
	var chosen: DefensiveCallData = calls.front()
	var chosen_score: float = -INF
	for call in calls:
		var score := 50.0 + rng.randf_range(-12.0, 12.0)
		if state.yards_to_first <= 2:
			score += 24.0 if call.id in ["run_commit", "goal_line"] else 0.0
		if state.yards_to_first >= 7:
			score += 20.0 if call.id in ["nickel_cover_2", "zone_blitz", "dime_prevent"] else 0.0
		if state.field_position >= 90:
			score += 28.0 if call.id == "goal_line" else 0.0
		if state.quarter >= 4 and state.clock_seconds <= 120 and state.score_for(state.defense().id) > state.score_for(state.offense().id):
			score += 45.0 if call.id == "dime_prevent" else 0.0
		if state.defense().coverage_preference == "Zone" and call.coverage == "Zone":
			score += 9.0
		elif state.defense().coverage_preference == "Man" and call.coverage == "Man":
			score += 9.0
		if state.defense().blitz_rate >= 0.55 and call.id in ["man_pressure", "zone_blitz"]:
			score += 12.0
		if score > chosen_score:
			chosen = call
			chosen_score = score
	return chosen


static func matchup_modifiers(
	play: PlayDefinitionData,
	defense: DefensiveCallData,
	history: Array[PlayResult]
) -> Dictionary:
	var modifiers := {
		"yardage": play.yardage_modifier,
		"variance": play.variance_multiplier,
		"completion": play.completion_modifier,
		"sack": play.sack_modifier,
		"interception": play.interception_modifier,
		"fumble": play.fumble_modifier,
	}
	if play.play_type == "run":
		modifiers["yardage"] = float(modifiers["yardage"]) + defense.run_yards_modifier
		if play.has_tag("power") and defense.personnel in ["Nickel", "Dime"]:
			modifiers["yardage"] = float(modifiers["yardage"]) + 0.8
		if play.has_tag("outside") and defense.id == "run_commit":
			modifiers["yardage"] = float(modifiers["yardage"]) - 0.4
	elif play.play_type == "pass":
		modifiers["yardage"] = float(modifiers["yardage"]) + defense.pass_yards_modifier
		modifiers["completion"] = float(modifiers["completion"]) + defense.completion_modifier
		modifiers["sack"] = float(modifiers["sack"]) + defense.sack_modifier
		modifiers["interception"] = float(modifiers["interception"]) + defense.interception_modifier
		if play.has_tag("blitz_beater") and defense.id in ["man_pressure", "zone_blitz"]:
			modifiers["yardage"] = float(modifiers["yardage"]) + 2.5
			modifiers["completion"] = float(modifiers["completion"]) + 0.07
			modifiers["sack"] = float(modifiers["sack"]) - 0.02
		if play.has_tag("quick") and defense.id in ["man_pressure", "zone_blitz"]:
			modifiers["completion"] = float(modifiers["completion"]) + 0.04
			modifiers["sack"] = float(modifiers["sack"]) - 0.015
		if play.has_tag("play_action") and defense.id == "run_commit":
			modifiers["yardage"] = float(modifiers["yardage"]) + 2.0
			modifiers["completion"] = float(modifiers["completion"]) + 0.06
		if play.has_tag("play_action") and defense.id in ["man_pressure", "zone_blitz"]:
			modifiers["sack"] = float(modifiers["sack"]) + 0.015
		if play.has_tag("deep") and defense.id == "dime_prevent":
			modifiers["yardage"] = float(modifiers["yardage"]) - 4.0
			modifiers["completion"] = float(modifiers["completion"]) - 0.06
		if play.has_tag("zone_beater") and defense.coverage == "Zone":
			modifiers["completion"] = float(modifiers["completion"]) + 0.025
		if play.has_tag("man_beater") and defense.coverage == "Man":
			modifiers["completion"] = float(modifiers["completion"]) + 0.025
		if play.has_tag("max_protect") and defense.id in ["man_pressure", "zone_blitz"]:
			modifiers["sack"] = float(modifiers["sack"]) - 0.018

	var repeats := 0
	var first_index := maxi(history.size() - 6, 0)
	for index in range(first_index, history.size()):
		if history[index].call_id == play.id:
			repeats += 1
	if repeats > 0:
		modifiers["yardage"] = float(modifiers["yardage"]) - float(repeats) * 0.45
		modifiers["completion"] = float(modifiers["completion"]) - float(repeats) * 0.015
	return modifiers


static func _recommendation_score(state: GameStateData, play: PlayDefinitionData) -> float:
	var score := 50.0
	var distance := state.yards_to_first
	if play.play_type == "run":
		score += state.offense().run_tendency * 18.0
		if distance <= 3 and play.has_tag("power"):
			score += 26.0
		if distance >= 8:
			score -= 13.0
	elif play.play_type == "pass":
		score += (1.0 - state.offense().run_tendency) * 18.0
		if distance <= 4 and play.has_tag("quick"):
			score += 20.0
		if distance >= 7 and play.has_tag("intermediate"):
			score += 18.0
		if distance >= 10 and play.has_tag("deep"):
			score += 16.0
		if state.down == 3 and play.has_tag("screen"):
			score += 8.0
	elif play.play_type == "field_goal":
		score = 150.0 if state.down == 4 and _should_attempt_field_goal(state) else -80.0
	elif play.play_type == "punt":
		score = 135.0 if state.down == 4 and not _should_attempt_field_goal(state) else -90.0
	elif play.play_type == "kneel":
		score = 210.0 if state.quarter >= 4 and state.clock_seconds <= 120 and not _offense_is_trailing(state) else -120.0
	elif play.play_type == "spike":
		score = 190.0 if state.quarter >= 2 and state.clock_seconds <= 45 and _offense_is_trailing(state) and state.down < 4 else -110.0
	if state.quarter >= 4 and state.clock_seconds <= 150 and _offense_is_trailing(state):
		if play.has_tag("sideline") or play.has_tag("deep"):
			score += 18.0
		if play.play_type == "run":
			score -= 18.0
	var repeats := 0
	var first_index := maxi(state.play_history.size() - 6, 0)
	for index in range(first_index, state.play_history.size()):
		if state.play_history[index].call_id == play.id:
			repeats += 1
	return score - float(repeats) * 12.0


static func _defensive_calls() -> Array[DefensiveCallData]:
	if _defensive_call_cache.is_empty():
		_defensive_call_cache.append(_defense("base_cover_3", "Base Cover 3", "Base", "Zone", -0.1, 0.01, -0.5, 0.0, 0.002))
		_defensive_call_cache.append(_defense("nickel_cover_2", "Nickel Cover 2", "Nickel", "Zone", 0.7, -0.02, -1.0, -0.004, 0.004))
		_defensive_call_cache.append(_defense("man_pressure", "Man Pressure", "Nickel", "Man", 0.3, -0.025, 0.8, 0.022, 0.003))
		_defensive_call_cache.append(_defense("zone_blitz", "Zone Blitz", "Base", "Zone", -0.5, 0.005, 0.5, 0.026, 0.005))
		_defensive_call_cache.append(_defense("run_commit", "Run Commit", "Base", "Man", -1.7, 0.08, 3.0, -0.01, -0.005))
		_defensive_call_cache.append(_defense("dime_prevent", "Dime Prevent", "Dime", "Zone", 1.8, 0.08, -3.0, -0.02, -0.002))
		_defensive_call_cache.append(_defense("goal_line", "Goal-Line Front", "Goal Line", "Man", -2.3, -0.03, -1.0, 0.01, 0.002))
	return _defensive_call_cache


static func _defense(
	call_id: String,
	call_name: String,
	personnel: String,
	coverage: String,
	run_modifier: float,
	completion_modifier: float,
	pass_modifier: float,
	sack_modifier: float,
	interception_modifier: float
) -> DefensiveCallData:
	var call := DefensiveCallData.new(call_id, call_name)
	call.personnel = personnel
	call.coverage = coverage
	call.run_yards_modifier = run_modifier
	call.completion_modifier = completion_modifier
	call.pass_yards_modifier = pass_modifier
	call.sack_modifier = sack_modifier
	call.interception_modifier = interception_modifier
	return call


static func _should_go_for_it(state: GameStateData, rng: RandomNumberGenerator) -> bool:
	var situational_boost := 0.0
	if state.field_position >= 50:
		situational_boost += 0.15
	if state.yards_to_first <= 2:
		situational_boost += 0.22
	if state.quarter >= 4 and _offense_is_trailing(state):
		situational_boost += 0.38
	return rng.randf() < clampf(state.offense().aggression * 0.30 + situational_boost, 0.03, 0.82)


static func _should_attempt_field_goal(state: GameStateData) -> bool:
	var kick_distance := 117 - state.field_position
	return kick_distance <= 59 and state.field_position >= 45


static func _automatic_tempo(state: GameStateData) -> String:
	if state.quarter >= 4 and state.clock_seconds <= 150:
		return PlayCallData.TEMPO_HURRY if _offense_is_trailing(state) else PlayCallData.TEMPO_CHEW
	return PlayCallData.TEMPO_NORMAL


static func _offense_is_trailing(state: GameStateData) -> bool:
	return state.score_for(state.offense().id) < state.score_for(state.defense().id)
