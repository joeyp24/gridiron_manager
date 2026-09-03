class_name FootballSimulator
extends RefCounted

var state: GameStateData
var seed: int
var require_winner: bool
var playbook: PlaybookData

var _rng := RandomNumberGenerator.new()
var _offensive_starters: Dictionary = {}
var _defensive_starters: Dictionary = {}


func _init(
	home: TeamData,
	away: TeamData,
	game_seed: int,
	game_requires_winner: bool = false,
	selected_playbook: PlaybookData = null
) -> void:
	seed = game_seed
	require_winner = game_requires_winner
	playbook = selected_playbook if selected_playbook != null else PlaybookCatalog.pro_style_offense()
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


func available_play_calls() -> Array[PlayDefinitionData]:
	return PlayCallerService.available_plays(state, playbook)


func recommended_play_calls(limit: int = 3) -> Array[PlayDefinitionData]:
	return PlayCallerService.recommendations(state, playbook, limit)


func play_by_id(play_id: String) -> PlayDefinitionData:
	return playbook.play_by_id(play_id)


func call_validation_error(play_id: String) -> String:
	return PlayCallerService.validation_error(state, playbook.play_by_id(play_id))


func simulate_called_play(play_id: String, tempo: String = PlayCallData.TEMPO_NORMAL) -> PlayResult:
	return simulate_next_play(PlayCallData.new(play_id, tempo, true))


func simulate_next_play(submitted_call: PlayCallData = null) -> PlayResult:
	if state.is_final:
		return null
	var call := submitted_call
	if call == null:
		call = PlayCallerService.automatic_call(state, playbook, _rng)
	var play := playbook.play_by_id(call.play_id)
	if not PlayCallerService.validation_error(state, play).is_empty():
		return null
	var defensive_call := PlayCallerService.automatic_defensive_call(state, _rng)
	var result := _new_result()
	_populate_call_context(result, call, play, defensive_call)
	var modifiers := PlayCallerService.matchup_modifiers(play, defensive_call, state.play_history)
	match play.play_type:
		"run":
			_resolve_run(result, call, play, modifiers)
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


func _resolve_run(result: PlayResult, call: PlayCallData, play: PlayDefinitionData, modifiers: Dictionary) -> void:
	var offense := state.offense()
	var defense := state.defense()
	var runner := _select_depth_player(offense, play.runner_position)
	var tackler := _select_defender(defense, ["LB", "S", "DT", "EDGE"])
	var recovery_player := _select_defender(defense, ["LB", "S", "CB", "EDGE"])
	_populate_scrimmage_participants(result, offense, defense, [runner], [tackler, recovery_player])
	result.ball_carrier_id = runner.id
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	var blocking_edge := float(offense.effective_offense_rating() - defense.effective_defense_rating()) * 0.07
	var skill_edge := float(runner.power + runner.speed - 160) * 0.025
	var expected_yards := 4.2 + blocking_edge + skill_edge + float(modifiers.get("yardage", 0.0))
	var variance := 4.3 * float(modifiers.get("variance", 1.0))
	var yards := clampi(roundi(_rng.randfn(expected_yards, variance)), -8, 40)
	var fumble_chance := clampf(0.010 + float(defense.effective_defense_rating() - runner.awareness) * 0.0005 + float(modifiers.get("fumble", 0.0)), 0.002, 0.045)

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
		result.description = "%s loses the football after a %d-yard run. %s recovers." % [runner.full_name, yards, defense.display_name()]
		result.drive_ended = true
		result.possession_changed = true
		_consume_clock(_called_clock(_rng.randi_range(22, 38), offense, call, play), offense.id)
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
	var quarterback := offense.player_at("QB")
	var receiver := _select_target(offense, play.target_positions)
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
	match defensive_call.coverage:
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
	var sack_chance := clampf(0.055 + pressure_edge * 0.0022 + float(edge.technique - 82) * 0.001 + float(modifiers.get("sack", 0.0)), 0.012, 0.20)

	result.play_type = "pass"
	result.title = play.display_name

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
		_consume_clock(_called_clock(_rng.randi_range(20, 34), offense, call, play), offense.id)
		return

	var interception_chance := clampf(
		0.017
		+ float(defense.effective_defense_rating() - quarterback.awareness) * 0.0012
		+ offense.aggression * 0.010
		+ coverage_interception_adjustment
		+ float(modifiers.get("interception", 0.0)),
		0.008,
		0.085
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
		_consume_clock(_called_clock(_rng.randi_range(8, 18), offense, call, play), offense.id)
		state.switch_possession()
		return

	var completion_chance := clampf(
		0.60
		+ float(quarterback.technique - defense.effective_defense_rating()) * 0.004
		+ float(receiver.technique - corner.technique) * 0.0025
		- offense.aggression * 0.035
		- (offense.passing_depth - 0.50) * 0.10
		+ coverage_completion_adjustment
		+ float(modifiers.get("completion", 0.0)),
		0.24,
		0.88
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
		_consume_clock(_called_clock(_rng.randi_range(5, 9), offense, call, play), offense.id)
		return

	var yards := clampi(
		roundi(_rng.randfn(8.5 + float(offense.effective_offense_rating() - defense.effective_defense_rating()) * 0.08 + offense.aggression * 3.0 + (offense.passing_depth - 0.50) * 12.0 + coverage_yards_adjustment + float(modifiers.get("yardage", 0.0)), 7.0 * float(modifiers.get("variance", 1.0)))),
		-2,
		58 if play.has_tag("deep") else 42
	)
	result.yards = yards
	result.completed_pass = true
	if tackler != null:
		result.tackler_ids.append(tackler.id)
	result.description = "%s connects with %s %s." % [quarterback.full_name, receiver.full_name, _for_yards(yards)]
	_record_yards(offense.id, "pass", yards)
	_apply_standard_gain(result, yards)
	_consume_clock(_called_clock(_rng.randi_range(17, 34), offense, call, play), offense.id)


func _resolve_punt(result: PlayResult, call: PlayCallData, play: PlayDefinitionData) -> void:
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
	_consume_clock(_called_clock(_rng.randi_range(9, 14), offense, call, play), offense.id)
	if landing_position >= 100:
		result.punt_touchback = true
		result.net_yards = maxi(0, 75 - result.starting_field_position)
		result.description = "%s punts into the end zone. %s starts at its 25." % [offense.display_name(), defense.abbreviation]
		state.switch_possession(true)
	else:
		state.field_position = landing_position
		state.switch_possession()
		result.description = "%s flips the field with a %d-yard punt." % [offense.display_name(), punt_distance]


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
	_consume_clock(_called_clock(_rng.randi_range(5, 9), offense, call, play), offense.id)
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


func _select_target(team: TeamData, preferred_positions: Array[String]) -> PlayerData:
	var candidates: Array[PlayerData] = []
	var weights: Array[float] = []
	var position_weight := {"WR": 1.0, "TE": 0.66, "RB": 0.38}
	for position_name in preferred_positions:
		var depth_index := 0
		for player in team.depth_players(position_name):
			if not player.is_available():
				continue
			candidates.append(player)
			weights.append(
				maxf(float(player.technique + player.speed), 1.0)
				* float(position_weight.get(position_name, 0.5))
				* pow(0.58, depth_index)
			)
			depth_index += 1
			if depth_index >= 4:
				break
	return _weighted_player(candidates, weights, team.player_at(preferred_positions.front()))


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
