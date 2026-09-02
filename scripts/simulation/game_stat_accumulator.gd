class_name GameStatAccumulator
extends RefCounted


static func record_play(state: GameStateData, result: PlayResult) -> void:
	if state == null or result == null:
		return
	var offense := state.team_by_id(result.offense_id)
	var defense := state.team_by_id(result.defense_id)
	if offense == null or defense == null:
		return
	_record_participants(state, result, offense, defense)
	_record_situational_team_stats(state, result)
	match result.play_type:
		"run":
			_record_run(state, result, offense, defense)
		"pass":
			_record_pass(state, result, offense, defense)
		"sack":
			_record_sack(state, result, offense, defense)
		"punt":
			_record_punt(state, result, offense, defense)
		"field_goal":
			_record_field_goal(state, result, offense, defense)
	_record_tackles(state, result, defense, offense)
	if result.touchdown:
		_record_touchdown(state, result, offense, defense)


static func _record_participants(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	var offensive_starters := _id_set(result.offensive_starter_ids)
	var defensive_starters := _id_set(result.defensive_starter_ids)
	for player_id in result.offensive_participant_ids:
		var line := _line_for(state, offense, defense, player_id)
		if line != null:
			line.mark_appearance(offensive_starters.has(player_id))
			line.stats.add("offensive_snaps")
	for player_id in result.defensive_participant_ids:
		var line := _line_for(state, defense, offense, player_id)
		if line != null:
			line.mark_appearance(defensive_starters.has(player_id))
			line.stats.add("defensive_snaps")
	for player_id in result.special_teams_participant_ids:
		var team := offense if offense.player_by_id(player_id) != null else defense
		var opponent := defense if team == offense else offense
		var line := _line_for(state, team, opponent, player_id)
		if line != null:
			line.mark_appearance(false)
			line.stats.add("special_teams_snaps")


static func _record_situational_team_stats(state: GameStateData, result: PlayResult) -> void:
	var offense_stats: Dictionary = state.stats[result.offense_id]
	var defense_stats: Dictionary = state.stats[result.defense_id]
	if result.down == 3:
		offense_stats["third_down_attempts"] += 1
		if result.first_down or result.touchdown:
			offense_stats["third_down_conversions"] += 1
	elif result.down == 4 and result.play_type in ["run", "pass", "sack"]:
		offense_stats["fourth_down_attempts"] += 1
		if result.first_down or result.touchdown:
			offense_stats["fourth_down_conversions"] += 1
	if result.points > 0:
		offense_stats["points"] += result.points
		defense_stats["points_allowed"] += result.points


static func _record_run(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	state.stats[offense.id]["rushing_attempts"] += 1
	var runner := _line_for(state, offense, defense, result.ball_carrier_id)
	if runner == null:
		return
	runner.stats.add("rushing_attempts")
	runner.stats.add("rushing_yards", result.yards)
	runner.stats.maximize("longest_rush", result.yards)
	if result.fumble:
		state.stats[offense.id]["fumbles"] += 1
		runner.stats.add("fumbles")
		if result.fumble_lost:
			state.stats[offense.id]["fumbles_lost"] += 1
			runner.stats.add("fumbles_lost")
		_record_fumble_defense(state, result, defense, offense)


static func _record_pass(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	state.stats[offense.id]["passing_attempts"] += 1
	var passer := _line_for(state, offense, defense, result.passer_id)
	var target := _line_for(state, offense, defense, result.target_id)
	if passer != null:
		passer.stats.add("passing_attempts")
		if result.completed_pass:
			state.stats[offense.id]["passing_completions"] += 1
			passer.stats.add("passing_completions")
			passer.stats.add("passing_yards", result.yards)
			passer.stats.maximize("longest_completion", result.yards)
		if result.interception:
			state.stats[offense.id]["passing_interceptions"] += 1
			passer.stats.add("passing_interceptions")
	if target != null:
		state.stats[offense.id]["receiving_targets"] += 1
		target.stats.add("receiving_targets")
		if result.completed_pass:
			state.stats[offense.id]["receptions"] += 1
			state.stats[offense.id]["receiving_yards"] += result.yards
			target.stats.add("receptions")
			target.stats.add("receiving_yards", result.yards)
			target.stats.maximize("longest_reception", result.yards)
		elif result.dropped_pass:
			state.stats[offense.id]["receiving_drops"] += 1
			target.stats.add("receiving_drops")
	var offense_stats: Dictionary = state.stats[offense.id]
	if result.completed_pass:
		offense_stats["gross_pass_yards"] += result.yards
	if result.interception:
		var interceptor := _line_for(state, defense, offense, result.interceptor_id)
		if interceptor != null:
			interceptor.stats.add("defensive_interceptions")
		state.stats[defense.id]["defensive_interceptions_team"] += 1
	if result.pass_defended:
		var defender := _line_for(state, defense, offense, result.pass_defender_id)
		if defender != null:
			defender.stats.add("passes_defended")
			state.stats[defense.id]["passes_defended"] += 1


static func _record_sack(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	var passer := _line_for(state, offense, defense, result.passer_id)
	if passer != null:
		passer.stats.add("sacks_taken")
		passer.stats.add("sack_yards_lost", absi(result.yards))
	var defender := _line_for(state, defense, offense, result.sack_player_id)
	if defender != null:
		defender.stats.add("sacks")
		defender.stats.add("quarterback_hits")
		defender.stats.add("tackles_for_loss")
		state.stats[defense.id]["sacks"] += 1
		state.stats[defense.id]["quarterback_hits"] += 1
		state.stats[defense.id]["tackles_for_loss"] += 1
	state.stats[offense.id]["sacks_allowed"] += 1
	state.stats[offense.id]["sack_yards_allowed"] += absi(result.yards)
	state.stats[defense.id]["defensive_sacks"] += 1


static func _record_punt(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	state.stats[offense.id]["punts"] += 1
	state.stats[offense.id]["punt_yards"] += result.yards
	state.stats[offense.id]["net_punt_yards"] += result.net_yards
	state.stats[offense.id]["longest_punt"] = maxi(int(state.stats[offense.id]["longest_punt"]), result.yards)
	var punter := _line_for(state, offense, defense, result.punter_id)
	if punter == null:
		return
	punter.stats.add("punts")
	punter.stats.add("punt_yards", result.yards)
	punter.stats.add("net_punt_yards", result.net_yards)
	punter.stats.maximize("longest_punt", result.yards)
	if result.punt_touchback:
		state.stats[offense.id]["punt_touchbacks"] += 1
		punter.stats.add("punt_touchbacks")
	elif result.starting_field_position + result.yards >= 80:
		state.stats[offense.id]["punts_inside_20"] += 1
		punter.stats.add("punts_inside_20")


static func _record_field_goal(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	state.stats[offense.id]["field_goal_attempts"] += 1
	var kicker := _line_for(state, offense, defense, result.kicker_id)
	if kicker == null:
		return
	kicker.stats.add("field_goal_attempts")
	if result.field_goal_made:
		state.stats[offense.id]["field_goals_made"] += 1
		state.stats[offense.id]["field_goal_yards"] += result.kick_distance
		state.stats[offense.id]["longest_field_goal"] = maxi(int(state.stats[offense.id]["longest_field_goal"]), result.kick_distance)
		kicker.stats.add("field_goals_made")
		kicker.stats.add("field_goal_yards", result.kick_distance)
		kicker.stats.maximize("longest_field_goal", result.kick_distance)


static func _record_tackles(state: GameStateData, result: PlayResult, defense: TeamData, offense: TeamData) -> void:
	for index in range(result.tackler_ids.size()):
		var tackler := _line_for(state, defense, offense, result.tackler_ids[index])
		if tackler == null:
			continue
		if index == 0:
			tackler.stats.add("tackles")
			state.stats[defense.id]["tackles"] += 1
		else:
			tackler.stats.add("assisted_tackles")
			state.stats[defense.id]["assisted_tackles"] += 1
		if result.yards < 0 and not result.sack:
			tackler.stats.add("tackles_for_loss")
			state.stats[defense.id]["tackles_for_loss"] += 1


static func _record_fumble_defense(state: GameStateData, result: PlayResult, defense: TeamData, offense: TeamData) -> void:
	var forcer := _line_for(state, defense, offense, result.forced_fumble_player_id)
	if forcer != null:
		forcer.stats.add("forced_fumbles")
		state.stats[defense.id]["forced_fumbles_team"] += 1
	var recovery := _line_for(state, defense, offense, result.recovery_player_id)
	if recovery != null:
		recovery.stats.add("fumble_recoveries")
		state.stats[defense.id]["fumble_recoveries_team"] += 1


static func _record_touchdown(state: GameStateData, result: PlayResult, offense: TeamData, defense: TeamData) -> void:
	if result.play_type == "run":
		state.stats[offense.id]["rushing_touchdowns"] += 1
		var runner := _line_for(state, offense, defense, result.ball_carrier_id)
		if runner != null:
			runner.stats.add("rushing_touchdowns")
	elif result.play_type == "pass":
		state.stats[offense.id]["passing_touchdowns"] += 1
		var passer := _line_for(state, offense, defense, result.passer_id)
		var receiver := _line_for(state, offense, defense, result.target_id)
		if passer != null:
			passer.stats.add("passing_touchdowns")
		if receiver != null:
			receiver.stats.add("receiving_touchdowns")
	var kicker := _line_for(state, offense, defense, result.kicker_id)
	if kicker != null:
		state.stats[offense.id]["extra_point_attempts"] += 1
		state.stats[offense.id]["extra_points_made"] += 1
		kicker.mark_appearance(false)
		kicker.stats.add("special_teams_snaps")
		kicker.stats.add("extra_point_attempts")
		kicker.stats.add("extra_points_made")


static func _line_for(
	state: GameStateData,
	team: TeamData,
	opponent: TeamData,
	player_id: String
) -> PlayerGameStatsData:
	if player_id.is_empty() or team == null:
		return null
	var existing: PlayerGameStatsData = state.player_stats.get(player_id)
	if existing != null:
		return existing
	var player := team.player_by_id(player_id)
	if player == null:
		return null
	var line := PlayerGameStatsData.new(player.id, player.full_name, player.position, team.id, opponent.id if opponent != null else "")
	state.player_stats[player.id] = line
	return line


static func _id_set(ids: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for player_id in ids:
		result[player_id] = true
	return result
