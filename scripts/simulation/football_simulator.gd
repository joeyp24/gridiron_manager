class_name FootballSimulator
extends RefCounted

var state: GameStateData
var seed: int
var require_winner: bool
var playbook: PlaybookData
var defensive_playbook: DefensivePlaybookData

var _rng := RandomNumberGenerator.new()
var _offensive_starters: Dictionary = {}
var _defensive_starters: Dictionary = {}
var _offensive_lineups: Dictionary = {}
var _defensive_lineups: Dictionary = {}


func _init(
	home: TeamData,
	away: TeamData,
	game_seed: int,
	game_requires_winner: bool = false,
	selected_playbook: PlaybookData = null,
	selected_defensive_playbook: DefensivePlaybookData = null
) -> void:
	seed = game_seed
	require_winner = game_requires_winner
	playbook = selected_playbook if selected_playbook != null else PlaybookCatalog.pro_style_offense()
	defensive_playbook = selected_defensive_playbook if selected_defensive_playbook != null else PlaybookCatalog.multiple_defense()
	_rng.seed = game_seed
	state = GameStateData.new(home, away)
	for team in [home, away]:
		for personnel in PersonnelPackageService.OFFENSIVE_PACKAGES:
			_offensive_lineups[_lineup_cache_key(team.id, str(personnel))] = PersonnelPackageService.offensive_lineup(team, str(personnel))
		for personnel in PersonnelPackageService.DEFENSIVE_PACKAGES:
			_defensive_lineups[_lineup_cache_key(team.id, str(personnel))] = PersonnelPackageService.defensive_lineup(team, str(personnel))
		_offensive_starters[team.id] = PersonnelPackageService.ids(_cached_offensive_lineup(team, "11"))
		_defensive_starters[team.id] = PersonnelPackageService.ids(_cached_defensive_lineup(team, "Base"))
	if _rng.randf() >= 0.5:
		state.possession_team_id = home.id
		state.opening_possession_team_id = home.id


func available_play_calls() -> Array[PlayDefinitionData]:
	return PlayCallerService.available_plays(state, playbook)


func recommended_play_calls(limit: int = 3) -> Array[PlayDefinitionData]:
	return PlayCallerService.recommendations(state, playbook, limit)


func play_by_id(play_id: String) -> PlayDefinitionData:
	return playbook.play_by_id(play_id)


func call_validation_error(play_id: String) -> String:
	return PlayCallerService.validation_error(state, playbook.play_by_id(play_id))


func available_defensive_calls() -> Array[DefensiveCallData]:
	return PlayCallerService.available_defensive_calls(state, defensive_playbook)


func recommended_defensive_calls(limit: int = 3) -> Array[DefensiveCallData]:
	return PlayCallerService.defensive_recommendations(state, defensive_playbook, limit)


func defensive_call_by_id(call_id: String) -> DefensiveCallData:
	return defensive_playbook.call_by_id(call_id)


func defensive_call_validation_error(call_id: String) -> String:
	return PlayCallerService.defensive_validation_error(state, defensive_playbook.call_by_id(call_id))


func simulate_called_play(play_id: String, tempo: String = PlayCallData.TEMPO_NORMAL) -> PlayResult:
	return simulate_next_play(PlayCallData.new(play_id, tempo, true))


func simulate_called_defense(call_id: String) -> PlayResult:
	var selected := defensive_playbook.call_by_id(call_id)
	if selected == null:
		return null
	var submitted := DefensiveCallData.from_dict(selected.to_dict())
	submitted.user_selected = true
	return simulate_next_play(null, submitted)


func simulate_next_play(
	submitted_call: PlayCallData = null,
	submitted_defensive_call: DefensiveCallData = null
) -> PlayResult:
	if state.is_final:
		return null
	var call := submitted_call
	if call == null:
		call = PlayCallerService.automatic_call(state, playbook, _rng)
	var play := playbook.play_by_id(call.play_id)
	if not PlayCallerService.validation_error(state, play).is_empty():
		return null
	var defensive_call := submitted_defensive_call
	if defensive_call == null:
		defensive_call = PlayCallerService.automatic_defensive_call(state, _rng, defensive_playbook)
	elif not PlayCallerService.defensive_validation_error(state, defensive_call).is_empty():
		return null
	var result := _new_result()
	_populate_call_context(result, call, play, defensive_call)
	var modifiers := PlayCallerService.matchup_modifiers(play, defensive_call, state.play_history)
	match play.play_type:
		"run":
			_resolve_run(result, call, play, defensive_call, modifiers)
		"pass":
			_resolve_pass(result, call, play, defensive_call, modifiers)
		"punt":
			_resolve_punt(result, call, play)
		"field_goal":
			_resolve_field_goal(result, call, play)
		"kneel":
			_resolve_kneel(result, call, play)
		"spike":
			_resolve_spike(result)
		_:
			return null

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


func _resolve_run(
	result: PlayResult,
	call: PlayCallData,
	play: PlayDefinitionData,
	defensive_call: DefensiveCallData,
	modifiers: Dictionary
) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var offense_lineup := _cached_offensive_lineup(offense, play.personnel)
	var defense_lineup := _cached_defensive_lineup(defense, defensive_call.personnel)
	var runner := _select_lineup_player(offense_lineup, [play.runner_position], offense.player_at(play.runner_position))
	var tackler := _select_lineup_player(defense_lineup, ["LB", "S", "DT", "EDGE", "CB"], defense.player_at("LB"))
	var recovery_player := _select_lineup_player(defense_lineup, ["LB", "S", "CB", "EDGE"], tackler)
	var blockers := PersonnelPackageService.blockers(offense_lineup, runner)
	var front := PersonnelPackageService.rushers(defense_lineup)
	var matchup := AttributeMatchupService.run_matchup(play, blockers, front, runner, tackler)
	_populate_scrimmage_participants(result, offense, defense, [runner], [tackler, recovery_player], offense_lineup, defense_lineup)
	result.ball_carrier_id = runner.id
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	var expected_yards := (
		SimulationTuning.value("run", "base_yards", 4.15)
		+ float(matchup["blocking_edge"]) * SimulationTuning.value("run", "blocking_edge_yards", 0.065)
		+ float(matchup["carrier_edge"]) * SimulationTuning.value("run", "carrier_edge_yards", 0.045)
		+ float(offense.offense_rating - defense.defense_rating) * SimulationTuning.value("run", "team_edge_yards", 0.015)
		+ float(modifiers.get("yardage", 0.0))
	)
	var variance := SimulationTuning.value("run", "variance", 4.0) * float(modifiers.get("variance", 1.0))
	var yards := clampi(roundi(_rng.randfn(expected_yards, variance)), -8, 40)
	var fumble_chance := clampf(
		SimulationTuning.value("run", "base_fumble_chance", 0.012)
		+ (float(matchup["hit_force"]) - float(matchup["ball_security"])) * SimulationTuning.value("run", "fumble_rating_coefficient", 0.00035)
		+ float(modifiers.get("fumble", 0.0)),
		SimulationTuning.value("run", "minimum_fumble_chance", 0.002),
		SimulationTuning.value("run", "maximum_fumble_chance", 0.05)
	)
	result.matchup_context = matchup.duplicate(true)
	result.matchup_context.merge({
		"model": "attribute_simulation_v2",
		"offensive_personnel": play.personnel,
		"defensive_personnel": defensive_call.personnel,
		"defensive_front": defensive_call.front,
		"coverage_shell": defensive_call.shell,
		"defensive_tags": defensive_call.tags.duplicate(),
		"expected_yards": expected_yards,
		"fumble_chance": fumble_chance,
		"runner_id": runner.id,
		"primary_tackler_id": tackler.id if tackler != null else "",
	}, true)

	result.play_type = "run"
	result.title = play.display_name
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
		result.description = "%s attacks a %s, but %s jars the ball loose after %s. %s recovers." % [
			runner.full_name,
			str(matchup["lane_label"]),
			tackler.full_name if tackler != null else defense.display_name(),
			_yard_phrase(yards),
			defense.display_name(),
		]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_called_clock(_rng.randi_range(22, 38), offense, call, play), offense.id)
		state.switch_possession()
		return

	result.yards = yards
	result.description = "%s hits the %s and meets %s, gaining %s." % [
		runner.full_name,
		str(matchup["lane_label"]),
		tackler.full_name if tackler != null else str(matchup["finish_label"]),
		_yard_phrase(yards),
	]
	_record_yards(offense.id, "run", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_called_clock(_rng.randi_range(27, 43), offense, call, play), offense.id)


func _resolve_pass(
	result: PlayResult,
	call: PlayCallData,
	play: PlayDefinitionData,
	defensive_call: DefensiveCallData,
	modifiers: Dictionary
) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var offense_lineup := _cached_offensive_lineup(offense, play.personnel)
	var defense_lineup := _cached_defensive_lineup(defense, defensive_call.personnel)
	var quarterback := _select_lineup_player(offense_lineup, ["QB"], offense.player_at("QB"))
	var receiver := _select_target_from_lineup(offense_lineup, play.target_positions, offense)
	var rushers := PersonnelPackageService.pass_rushers(defense_lineup, defensive_call.rusher_count)
	var edge := _select_rusher(rushers, defense.player_at("EDGE"))
	var corner := _select_lineup_player(defense_lineup, ["CB", "S", "LB"], defense.player_at("CB"))
	var tackler := _select_lineup_player(defense_lineup, ["CB", "S", "LB"], corner)
	var protectors := PersonnelPackageService.pass_protectors(offense_lineup, quarterback)
	if play.has_tag("max_protect"):
		for player in offense_lineup:
			if player != receiver and player.position in ["TE", "RB"]:
				protectors.append(player)
	var matchup := AttributeMatchupService.pass_matchup(play, defensive_call, protectors, rushers, quarterback, receiver, corner)
	var spy_player_id := ""
	if defensive_call.has_tag("spy"):
		for player in defense_lineup:
			if player.position in ["LB", "S"] and not rushers.has(player):
				spy_player_id = player.id
				break
	_populate_scrimmage_participants(result, offense, defense, [quarterback, receiver], [edge, corner, tackler], offense_lineup, defense_lineup)
	result.passer_id = quarterback.id
	result.target_id = receiver.id
	var pressure_edge := (
		float(matchup["pressure_edge"])
		+ float(defensive_call.rusher_count - 4) * 2.4
		+ (defense.blitz_rate - 0.42) * 4.0
	)
	var sack_chance := clampf(
		SimulationTuning.value("pass", "base_sack_chance", 0.052)
		+ pressure_edge * SimulationTuning.value("pass", "pressure_sack_coefficient", 0.0028)
		- (float(matchup["pocket_escape"]) - SimulationTuning.ratings_center()) * SimulationTuning.value("pass", "escape_sack_coefficient", 0.001)
		+ float(modifiers.get("sack", 0.0)),
		SimulationTuning.value("pass", "minimum_sack_chance", 0.012),
		SimulationTuning.value("pass", "maximum_sack_chance", 0.20)
	)
	result.matchup_context = matchup.duplicate(true)
	result.matchup_context.merge({
		"model": "attribute_simulation_v2",
		"offensive_personnel": play.personnel,
		"defensive_personnel": defensive_call.personnel,
		"sack_chance": sack_chance,
		"passer_id": quarterback.id,
		"receiver_id": receiver.id,
		"coverage_defender_id": corner.id if corner != null else "",
		"primary_rusher_id": edge.id if edge != null else "",
		"rush_participant_ids": PersonnelPackageService.ids(rushers),
		"spy_player_id": spy_player_id,
		"defensive_front": defensive_call.front,
		"coverage_shell": defensive_call.shell,
		"defensive_tags": defensive_call.tags.duplicate(),
	}, true)

	result.play_type = "pass"
	result.title = play.display_name

	if _rng.randf() < sack_chance:
		var sack_yards := -_rng.randi_range(3, 10)
		result.play_type = "sack"
		result.title = "Sack"
		result.yards = sack_yards
		result.sack = true
		result.sack_player_id = edge.id if edge != null else ""
		if edge != null:
			result.tackler_ids.append(edge.id)
		result.description = "%s creates %s and drops %s for a loss of %d." % [
			edge.full_name if edge != null else defense.display_name(),
			str(matchup["pressure_label"]),
			quarterback.full_name,
			absi(sack_yards),
		]
		_record_yards(offense.id, "pass", sack_yards)
		_apply_standard_gain(result, sack_yards)
		_consume_clock(_called_clock(_rng.randi_range(20, 34), offense, call, play), offense.id)
		return

	var depth_interception_adjustment := 0.012 if play.has_tag("deep") else (0.004 if play.has_tag("intermediate") else 0.0)
	var interception_chance := clampf(
		SimulationTuning.value("pass", "base_interception_chance", 0.019)
		+ (float(matchup["coverage"]) - float(matchup["decision"])) * SimulationTuning.value("pass", "coverage_interception_coefficient", 0.00115)
		+ offense.aggression * 0.010
		+ depth_interception_adjustment
		+ float(modifiers.get("interception", 0.0)),
		SimulationTuning.value("pass", "minimum_interception_chance", 0.006),
		SimulationTuning.value("pass", "maximum_interception_chance", 0.085)
	)
	result.matchup_context["interception_chance"] = interception_chance
	if _rng.randf() < interception_chance:
		var target_depth := clampi(roundi(_rng.randfn(_air_yards_for(play), 5.0)), 0, 35)
		state.field_position = clampi(state.field_position + target_depth, 1, 99)
		state.stats[offense.id]["plays"] += 1
		state.stats[offense.id]["turnovers"] += 1
		result.yards = 0
		result.interception = true
		result.interceptor_id = corner.id if corner != null else ""
		result.title = "Intercepted"
		result.description = "%s wins a %s and intercepts %s." % [
			corner.full_name if corner != null else defense.display_name(),
			str(matchup["coverage_label"]),
			quarterback.full_name,
		]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_called_clock(_rng.randi_range(8, 18), offense, call, play), offense.id)
		state.switch_possession()
		return

	var catchable_chance := clampf(
		SimulationTuning.value("pass", "base_catchable_chance", 0.625)
		+ (float(matchup["accuracy"]) - SimulationTuning.ratings_center()) * SimulationTuning.value("pass", "accuracy_completion_coefficient", 0.0038)
		+ float(matchup["separation_edge"]) * SimulationTuning.value("pass", "separation_completion_coefficient", 0.0026)
		- maxf(pressure_edge, 0.0) * SimulationTuning.value("pass", "pressure_completion_coefficient", 0.0012)
		- offense.aggression * 0.035
		- (offense.passing_depth - 0.50) * 0.10
		+ float(modifiers.get("completion", 0.0)),
		SimulationTuning.value("pass", "minimum_catchable_chance", 0.22),
		SimulationTuning.value("pass", "maximum_catchable_chance", 0.91)
	)
	var catch_chance := clampf(
		SimulationTuning.value("pass", "base_catch_chance", 0.93)
		+ (float(matchup["catch"]) - SimulationTuning.ratings_center()) * SimulationTuning.value("pass", "catch_rating_coefficient", 0.002)
		- maxf(float(matchup["coverage"]) - float(matchup["route"]), 0.0) * SimulationTuning.value("pass", "coverage_catch_coefficient", 0.0008),
		SimulationTuning.value("pass", "minimum_catch_chance", 0.72),
		SimulationTuning.value("pass", "maximum_catch_chance", 0.985)
	)
	result.matchup_context["catchable_chance"] = catchable_chance
	result.matchup_context["catch_chance"] = catch_chance
	var catchable := _rng.randf() < catchable_chance
	var caught := catchable and _rng.randf() < catch_chance
	if not caught:
		state.stats[offense.id]["plays"] += 1
		result.yards = 0
		if catchable and _rng.randf() < 0.72:
			result.dropped_pass = true
		else:
			result.pass_defended = corner != null and (_rng.randf() < 0.58 or float(matchup["coverage"]) > float(matchup["route"]))
			result.pass_defender_id = corner.id if result.pass_defended and corner != null else ""
		result.title = "Incomplete"
		if result.dropped_pass:
			result.description = "%s delivers through a %s, but %s cannot finish the catch." % [quarterback.full_name, str(matchup["coverage_label"]), receiver.full_name]
		elif result.pass_defended:
			result.description = "%s closes a %s and breaks up %s's throw to %s." % [corner.full_name, str(matchup["coverage_label"]), quarterback.full_name, receiver.full_name]
		else:
			result.description = "%s faces %s and misses %s in a %s." % [quarterback.full_name, str(matchup["pressure_label"]), receiver.full_name, str(matchup["coverage_label"])]
		_advance_down_after_no_gain(result)
		_consume_clock(_called_clock(_rng.randi_range(5, 9), offense, call, play), offense.id)
		return

	var air_yards := roundi(_rng.randfn(
		_air_yards_for(play) + float(modifiers.get("yardage", 0.0)) + (float(matchup["accuracy"]) - SimulationTuning.ratings_center()) * 0.025,
		SimulationTuning.value("pass", "air_yard_variance", 4.6) * float(modifiers.get("variance", 1.0))
	))
	var expected_yac := (
		SimulationTuning.value("pass", "base_yac", 3.2)
		+ (float(matchup["yac"]) - float(matchup["tackle"])) * SimulationTuning.value("pass", "yac_rating_coefficient", 0.055)
	)
	var yards_after_catch := roundi(_rng.randfn(expected_yac, SimulationTuning.value("pass", "yac_variance", 3.8)))
	var explosive_chance := clampf(
		0.055
		+ (0.08 if play.has_tag("deep") else 0.0)
		+ float(modifiers.get("explosive", 0.0))
		+ float(matchup["separation_edge"]) * 0.0015,
		0.005,
		0.28
	)
	var explosive_triggered := _rng.randf() < explosive_chance
	if explosive_triggered:
		yards_after_catch += _rng.randi_range(8, 18)
	var yards := clampi(air_yards + yards_after_catch, -2, 58 if play.has_tag("deep") else 42)
	result.matchup_context["air_yards"] = air_yards
	result.matchup_context["yards_after_catch"] = yards_after_catch
	result.matchup_context["explosive_chance"] = explosive_chance
	result.matchup_context["explosive_play"] = explosive_triggered or yards >= 20
	result.yards = yards
	result.completed_pass = true
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	result.description = "%s works from a %s and finds %s with %s %s." % [
		quarterback.full_name,
		str(matchup["pressure_label"]),
		receiver.full_name,
		str(matchup["coverage_label"]),
		_for_yards(yards),
	]
	_record_yards(offense.id, "pass", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_called_clock(_rng.randi_range(17, 34), offense, call, play), offense.id)


func _resolve_punt(result: PlayResult, call: PlayCallData, play: PlayDefinitionData) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var punter := offense.player_at("P")
	var long_snapper := offense.player_at("LS")
	var profile := AttributeMatchupService.punt_profile(punter)
	var punt_distance := clampi(
		roundi(_rng.randfn(float(profile["expected_distance"]), SimulationTuning.value("special_teams", "punt_distance_variance", 4.2))),
		roundi(SimulationTuning.value("special_teams", "punt_minimum_distance", 28.0)),
		roundi(SimulationTuning.value("special_teams", "punt_maximum_distance", 70.0))
	)
	var raw_landing_position := state.field_position + punt_distance
	var placement_chance := clampf(0.28 + (float(profile["accuracy"]) - SimulationTuning.ratings_center()) * 0.012, 0.08, 0.70)
	if raw_landing_position >= 100 and state.field_position <= 75 and _rng.randf() < placement_chance:
		var target_landing := _rng.randi_range(96, 99)
		punt_distance = maxi(target_landing - state.field_position, 1)
	result.punter_id = punter.id
	_append_player_id(result.special_teams_participant_ids, punter)
	_append_player_id(result.special_teams_participant_ids, long_snapper)
	var landing_position := state.field_position + punt_distance
	result.matchup_context = profile.duplicate(true)
	result.matchup_context.merge({
		"model": "attribute_simulation_v2",
		"placement_chance": placement_chance,
		"landing_position": landing_position,
	}, true)
	result.play_type = "punt"
	result.title = "Punt"
	result.yards = punt_distance
	result.net_yards = punt_distance
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_called_clock(_rng.randi_range(9, 14), offense, call, play), offense.id)
	if landing_position >= 100:
		result.punt_touchback = true
		result.net_yards = maxi(0, 75 - result.starting_field_position)
		result.description = "%s drives the punt into the end zone. %s starts at its 25." % [punter.full_name, defense.abbreviation]
		state.switch_possession(true)
	else:
		state.field_position = landing_position
		state.switch_possession()
		result.description = "%s flips the field with a %d-yard punt%s." % [
			punter.full_name,
			punt_distance,
			", placed inside the 5" if landing_position >= 95 else "",
		]


func _resolve_field_goal(result: PlayResult, call: PlayCallData, play: PlayDefinitionData) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var kick_distance := 117 - state.field_position
	var kicker := offense.player_at("K")
	var long_snapper := offense.player_at("LS")
	result.kicker_id = kicker.id
	result.kick_distance = kick_distance
	_append_player_id(result.special_teams_participant_ids, kicker)
	_append_player_id(result.special_teams_participant_ids, long_snapper)
	var profile := AttributeMatchupService.field_goal_profile(kicker, kick_distance)
	var kick_chance := float(profile["chance"])
	result.matchup_context = profile.duplicate(true)
	result.matchup_context.merge({"model": "attribute_simulation_v2", "distance": kick_distance}, true)
	result.play_type = "field_goal"
	result.drive_ended = true
	result.possession_changed = true
	_consume_clock(_called_clock(_rng.randi_range(5, 9), offense, call, play), offense.id)
	if _rng.randf() < kick_chance:
		state.add_score(offense.id, 3)
		result.title = "Field goal"
		result.description = "%s converts from %d yards with power to spare." % [kicker.full_name, kick_distance]
		result.points = 3
		result.scoring_play = true
		result.field_goal_made = true
		state.switch_possession(true)
	else:
		result.title = "No good"
		result.description = "%s misses the %d-yard attempt." % [kicker.full_name, kick_distance]
		state.switch_possession()


func _resolve_kneel(result: PlayResult, call: PlayCallData, play: PlayDefinitionData) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var quarterback := offense.player_at("QB")
	_populate_scrimmage_participants(result, offense, defense, [quarterback], [])
	result.play_type = "run"
	result.title = "Quarterback kneel"
	result.ball_carrier_id = quarterback.id
	result.yards = -1
	result.description = "%s takes a knee behind the %s formation." % [quarterback.full_name, play.formation]
	_record_yards(offense.id, "run", result.yards)
	_apply_standard_gain(result, result.yards)
	_consume_clock(_called_clock(_rng.randi_range(38, 42), offense, call, play), offense.id)


func _resolve_spike(result: PlayResult) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var quarterback := offense.player_at("QB")
	_populate_scrimmage_participants(result, offense, defense, [quarterback], [])
	result.play_type = "pass"
	result.title = "Spike"
	result.passer_id = quarterback.id
	result.description = "%s spikes the ball to stop the clock." % quarterback.full_name
	state.stats[offense.id]["plays"] += 1
	_advance_down_after_no_gain(result)
	_consume_clock(1, offense.id)


func _apply_standard_gain(result: PlayResult, yards: int) -> void:
	var offense_id := state.possession_team_id
	state.field_position = clampi(state.field_position + yards, 1, 100)
	if state.field_position >= 100:
		state.add_score(offense_id, 6)
		result.title = "Touchdown"
		result.description = "%s Touchdown — %s" % [state.offense().abbreviation, result.description]
		result.points = 6
		result.scoring_play = true
		result.touchdown = true
		var kicker := state.team_by_id(offense_id).player_at("K")
		if kicker != null:
			result.kicker_id = kicker.id
			result.extra_point_attempted = true
			var extra_point_chance := AttributeMatchupService.extra_point_chance(kicker)
			result.matchup_context["extra_point_chance"] = extra_point_chance
			if _rng.randf() < extra_point_chance:
				state.add_score(offense_id, 1)
				result.points += 1
				result.extra_point_made = true
				result.description += " %s adds the extra point." % kicker.full_name
			else:
				result.description += " %s misses the extra point." % kicker.full_name
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


func _called_clock(seconds: int, offense: TeamData, call: PlayCallData, play: PlayDefinitionData) -> int:
	var tempo_multiplier := 1.0
	if call.tempo == PlayCallData.TEMPO_HURRY:
		tempo_multiplier = 0.64
	elif call.tempo == PlayCallData.TEMPO_CHEW:
		tempo_multiplier = 1.22
	return clampi(roundi(float(_tempo_clock(seconds, offense)) * tempo_multiplier * play.clock_multiplier), 1, 45)


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


func _populate_call_context(
	result: PlayResult,
	call: PlayCallData,
	play: PlayDefinitionData,
	defensive_call: DefensiveCallData
) -> void:
	result.call_id = play.id
	result.call_name = play.display_name
	result.call_formation = play.formation
	result.call_personnel = play.personnel
	result.call_concept = play.concept
	result.call_tempo = call.tempo
	result.call_was_user_selected = call.user_selected
	result.defensive_call_id = defensive_call.id
	result.defensive_call_name = defensive_call.display_name
	result.defensive_call_category = defensive_call.category
	result.defensive_call_personnel = defensive_call.personnel
	result.defensive_call_coverage = defensive_call.coverage
	result.defensive_call_front = defensive_call.front
	result.defensive_call_shell = defensive_call.shell
	result.defensive_call_was_user_selected = defensive_call.user_selected


func _populate_scrimmage_participants(
	result: PlayResult,
	offense: TeamData,
	defense: TeamData,
	extra_offense: Array,
	extra_defense: Array,
	offense_lineup: Array[PlayerData] = [],
	defense_lineup: Array[PlayerData] = []
) -> void:
	var offense_starters: Array[String] = _offensive_starters[offense.id]
	var defense_starters: Array[String] = _defensive_starters[defense.id]
	result.offensive_starter_ids = offense_starters.duplicate()
	result.defensive_starter_ids = defense_starters.duplicate()
	result.offensive_participant_ids = PersonnelPackageService.ids(offense_lineup) if not offense_lineup.is_empty() else result.offensive_starter_ids.duplicate()
	result.defensive_participant_ids = PersonnelPackageService.ids(defense_lineup) if not defense_lineup.is_empty() else result.defensive_starter_ids.duplicate()
	for player in extra_offense:
		_replace_position_participant(result.offensive_participant_ids, offense, player)
	for player in extra_defense:
		_replace_position_participant(result.defensive_participant_ids, defense, player)


func _cached_offensive_lineup(team: TeamData, personnel: String) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	var cached = _offensive_lineups.get(_lineup_cache_key(team.id, personnel), [])
	for player in cached:
		result.append(player)
	if result.is_empty():
		return PersonnelPackageService.offensive_lineup(team, personnel)
	return result


func _cached_defensive_lineup(team: TeamData, personnel: String) -> Array[PlayerData]:
	var result: Array[PlayerData] = []
	var cached = _defensive_lineups.get(_lineup_cache_key(team.id, personnel), [])
	for player in cached:
		result.append(player)
	if result.is_empty():
		return PersonnelPackageService.defensive_lineup(team, personnel)
	return result


func _lineup_cache_key(team_id: String, personnel: String) -> String:
	return "%s|%s" % [team_id, personnel]


func _select_lineup_player(lineup_players: Array[PlayerData], positions: Array[String], fallback: PlayerData) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	for player in lineup_players:
		if player != null and player.position in positions:
			candidates.append(player)
			weights.append(maxf(float(player.effective_overall()), 1.0))
	return _weighted_player(candidates, weights, fallback)


func _select_target_from_lineup(lineup_players: Array[PlayerData], preferred_positions: Array[String], team: TeamData) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	var position_weight := {"WR": 1.0, "TE": 0.70, "RB": 0.42}
	for player in lineup_players:
		if player == null or not player.position in preferred_positions:
			continue
		candidates.append(player)
		var receiving_skill := AttributeMatchupService.weighted_rating(player, {
			"catching": 0.35, "shortRouteRunning": 0.18, "mediumRouteRunning": 0.18,
			"deepRouteRunning": 0.12, "release": 0.09, "speed": 0.08,
		})
		weights.append(maxf(receiving_skill, 1.0) * float(position_weight.get(player.position, 0.5)))
	var fallback_position: String = preferred_positions.front() if not preferred_positions.is_empty() else "WR"
	return _weighted_player(candidates, weights, team.player_at(fallback_position))


func _select_rusher(rushers: Array[PlayerData], fallback: PlayerData) -> PlayerData:
	var weights: Array[float] = []
	for player in rushers:
		weights.append(maxf(AttributeMatchupService.weighted_rating(player, {
			"finesseMoves": 0.28, "powerMoves": 0.28, "blockShedding": 0.18,
			"acceleration": 0.14, "strength": 0.12,
		}), 1.0))
	return _weighted_player(rushers, weights, fallback)


func _air_yards_for(play: PlayDefinitionData) -> float:
	if play.has_tag("screen"):
		return SimulationTuning.value("pass", "screen_air_yards", 0.5)
	if play.has_tag("quick"):
		return SimulationTuning.value("pass", "quick_air_yards", 4.5)
	if play.has_tag("deep"):
		return SimulationTuning.value("pass", "deep_air_yards", 18.5)
	if play.has_tag("intermediate") or play.has_tag("seam") or play.has_tag("crossing"):
		return SimulationTuning.value("pass", "intermediate_air_yards", 10.5)
	return SimulationTuning.value("pass", "default_air_yards", 7.5)


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
