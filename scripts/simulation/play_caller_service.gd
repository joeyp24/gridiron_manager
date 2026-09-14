class_name PlayCallerService
extends RefCounted

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


static func available_defensive_calls(
	state: GameStateData,
	playbook: DefensivePlaybookData
) -> Array[DefensiveCallData]:
	var available: Array[DefensiveCallData] = []
	if state == null or playbook == null or state.is_final:
		return available
	for call in playbook.calls:
		if defensive_validation_error(state, call).is_empty():
			available.append(call)
	return available


static func defensive_validation_error(state: GameStateData, call: DefensiveCallData) -> String:
	if state == null or state.is_final:
		return "The game is complete."
	if call == null:
		return "That call is not in the active defensive playbook."
	var defense := state.defense()
	if defense == null:
		return "No defense is available."
	if PersonnelPackageService.defensive_lineup(defense, call.personnel).size() < 11:
		return "The defense cannot field eleven available players for %s personnel." % call.personnel
	return ""


static func defensive_recommendations(
	state: GameStateData,
	playbook: DefensivePlaybookData,
	limit: int = 3
) -> Array[DefensiveCallData]:
	var ranked := available_defensive_calls(state, playbook)
	ranked.sort_custom(func(a: DefensiveCallData, b: DefensiveCallData):
		var first := _defensive_recommendation_score(state, a)
		var second := _defensive_recommendation_score(state, b)
		if not is_equal_approx(first, second):
			return first > second
		return a.id < b.id
	)
	if ranked.size() > limit:
		ranked.resize(limit)
	return ranked


static func defensive_recommendation_reason(state: GameStateData, call: DefensiveCallData) -> String:
	if state == null or call == null:
		return "Coordinator selection"
	if state.field_position >= 90 and call.has_tag("goal_line"):
		return "Protect the goal line"
	if state.yards_to_first <= 2 and call.has_tag("run_commit"):
		return "Attack short yardage"
	if _defense_is_protecting_late_lead(state) and call.has_tag("prevent"):
		return "Keep the offense in bounds"
	if state.yards_to_first >= 8 and call.has_tag("pass_commit"):
		return "Defend the sticks"
	if call.has_tag("spy"):
		return "Contain quarterback movement"
	if call.has_tag("blitz") or call.has_tag("simulated_pressure"):
		return "Create immediate pressure"
	if call.has_tag("robber"):
		return "Challenge inside routes"
	return "Balanced down-and-distance call"


static func automatic_defensive_call(
	state: GameStateData,
	rng: RandomNumberGenerator,
	playbook: DefensivePlaybookData = null
) -> DefensiveCallData:
	var selected_playbook := playbook if playbook != null else PlaybookCatalog.multiple_defense()
	if state == null or selected_playbook == null or state.is_final:
		return DefensiveCallData.new("emergency_base", "Emergency Base")
	var calls := selected_playbook.calls
	if calls.is_empty():
		return DefensiveCallData.new("emergency_base", "Emergency Base")
	var chosen: DefensiveCallData = calls.front()
	var chosen_score: float = -INF
	for call in calls:
		var score := _defensive_recommendation_score(state, call) + rng.randf_range(-12.0, 12.0)
		if score > chosen_score:
			chosen = call
			chosen_score = score
	if not defensive_validation_error(state, chosen).is_empty():
		var available := available_defensive_calls(state, selected_playbook)
		if available.is_empty():
			return DefensiveCallData.new("emergency_base", "Emergency Base")
		chosen = available.front()
		chosen_score = -INF
		for call in available:
			var score := _defensive_recommendation_score(state, call) + rng.randf_range(-12.0, 12.0)
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
		"explosive": defense.explosive_modifier,
	}
	if play.play_type == "run":
		modifiers["yardage"] = float(modifiers["yardage"]) + defense.run_yards_modifier
		modifiers["fumble"] = float(modifiers["fumble"]) + defense.fumble_modifier
		if play.has_tag("power") and defense.personnel in ["Nickel", "Dime"]:
			modifiers["yardage"] = float(modifiers["yardage"]) + 0.8
		if play.has_tag("outside") and defense.has_tag("run_commit"):
			modifiers["yardage"] = float(modifiers["yardage"]) - 0.4
		if play.runner_position == "QB" and defense.has_tag("spy"):
			modifiers["yardage"] = float(modifiers["yardage"]) - 1.4
			modifiers["fumble"] = float(modifiers["fumble"]) + 0.002
	elif play.play_type == "pass":
		modifiers["yardage"] = float(modifiers["yardage"]) + defense.pass_yards_modifier
		modifiers["completion"] = float(modifiers["completion"]) + defense.completion_modifier
		modifiers["sack"] = float(modifiers["sack"]) + defense.sack_modifier
		modifiers["interception"] = float(modifiers["interception"]) + defense.interception_modifier
		if play.has_tag("blitz_beater") and defense.has_tag("blitz"):
			modifiers["yardage"] = float(modifiers["yardage"]) + 2.5
			modifiers["completion"] = float(modifiers["completion"]) + 0.07
			modifiers["sack"] = float(modifiers["sack"]) - 0.02
		if play.has_tag("quick") and defense.has_tag("blitz"):
			modifiers["completion"] = float(modifiers["completion"]) + 0.04
			modifiers["sack"] = float(modifiers["sack"]) - 0.015
		if play.has_tag("play_action") and defense.has_tag("run_commit"):
			modifiers["yardage"] = float(modifiers["yardage"]) + 2.0
			modifiers["completion"] = float(modifiers["completion"]) + 0.06
		if play.has_tag("play_action") and defense.has_tag("blitz"):
			modifiers["sack"] = float(modifiers["sack"]) + 0.015
		if play.has_tag("deep") and defense.has_tag("prevent"):
			modifiers["yardage"] = float(modifiers["yardage"]) - 3.0
			modifiers["completion"] = float(modifiers["completion"]) - 0.05
		if play.has_tag("zone_beater") and defense.coverage == "Zone":
			modifiers["completion"] = float(modifiers["completion"]) + 0.025
		if play.has_tag("man_beater") and defense.coverage == "Man":
			modifiers["completion"] = float(modifiers["completion"]) + 0.025
		if play.has_tag("max_protect") and defense.has_tag("blitz"):
			modifiers["sack"] = float(modifiers["sack"]) - 0.018

	var repeats := 0
	var first_index := maxi(history.size() - 6, 0)
	for index in range(first_index, history.size()):
		if history[index].call_id == play.id:
			repeats += 1
	if repeats > 0:
		modifiers["yardage"] = float(modifiers["yardage"]) - float(repeats) * 0.45
		modifiers["completion"] = float(modifiers["completion"]) - float(repeats) * 0.015
	var defensive_repeats := 0
	for index in range(first_index, history.size()):
		if history[index].defensive_call_id == defense.id:
			defensive_repeats += 1
	if defensive_repeats > 0:
		modifiers["yardage"] = float(modifiers["yardage"]) + float(defensive_repeats) * 0.30
		if play.play_type == "pass":
			modifiers["completion"] = float(modifiers["completion"]) + float(defensive_repeats) * 0.008
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


static func _defensive_recommendation_score(state: GameStateData, call: DefensiveCallData) -> float:
	var score := 50.0
	var distance := state.yards_to_first
	var likely_run := clampf(state.offense().run_tendency, 0.20, 0.80)
	if state.down == 3 and distance >= 7:
		likely_run -= 0.22
	elif distance <= 2:
		likely_run += 0.18
	var recent_runs := 0
	var recent_passes := 0
	var first_index := maxi(state.play_history.size() - 6, 0)
	for index in range(first_index, state.play_history.size()):
		var previous := state.play_history[index]
		if previous.offense_id != state.offense().id:
			continue
		if previous.play_type == "run":
			recent_runs += 1
		elif previous.play_type in ["pass", "sack"]:
			recent_passes += 1
	if recent_runs + recent_passes > 0:
		likely_run = clampf(lerpf(likely_run, float(recent_runs) / float(recent_runs + recent_passes), 0.38), 0.12, 0.88)
	if call.has_tag("run_commit"):
		score += (likely_run - 0.45) * 54.0
		if distance <= 2:
			score += 24.0
	if call.has_tag("pass_commit"):
		score += (0.55 - likely_run) * 38.0
		if distance >= 7:
			score += 18.0
	if call.category == "Nickel" and distance >= 4:
		score += 7.0
	if call.category == "Dime" and distance >= 8:
		score += 12.0
	if call.has_tag("goal_line"):
		score += 40.0 if state.field_position >= 90 else -34.0
	if call.has_tag("prevent"):
		score += 52.0 if _defense_is_protecting_late_lead(state) else -38.0
	if state.defense().coverage_preference == call.coverage:
		score += 9.0
	if call.has_tag("blitz"):
		score += (state.defense().blitz_rate - 0.42) * 30.0
		if distance >= 10:
			score += 6.0
	if call.has_tag("simulated_pressure"):
		score += 6.0
	if call.has_tag("spy") and state.offense().player_at("QB") != null:
		var quarterback := state.offense().player_at("QB")
		var mobility := AttributeMatchupService.weighted_rating(quarterback, {
			"speed": 0.35, "acceleration": 0.25, "agility": 0.20, "breakSack": 0.20,
		})
		score += (mobility - SimulationTuning.ratings_center()) * 0.55
	var repeats := 0
	for index in range(first_index, state.play_history.size()):
		if state.play_history[index].defensive_call_id == call.id:
			repeats += 1
	return score - float(repeats) * 11.0


static func _defense_is_protecting_late_lead(state: GameStateData) -> bool:
	return (
		state.quarter >= 4
		and state.clock_seconds <= 150
		and state.score_for(state.defense().id) > state.score_for(state.offense().id)
	)


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
