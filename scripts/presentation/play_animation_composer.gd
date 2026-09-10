class_name PlayAnimationComposer
extends RefCounted

const SNAP_PROGRESS := 0.12
const OFFENSE_SKILL_POSITIONS: Array[String] = ["QB", "RB", "WR", "TE"]
const OFFENSIVE_LINE_POSITIONS: Array[String] = ["LT", "LG", "C", "RG", "RT"]
const DEFENSIVE_FRONT_POSITIONS: Array[String] = ["EDGE", "DT"]


static func compose(result: PlayResult, state: GameStateData) -> PlayAnimationData:
	if result == null or state == null:
		return null
	var offense := state.team_by_id(result.offense_id)
	var defense := state.team_by_id(result.defense_id)
	if offense == null or defense == null:
		return null

	var animation := PlayAnimationData.new()
	animation.sequence = result.sequence
	animation.title = result.title
	animation.description = result.description
	animation.play_type = result.play_type
	animation.call_name = result.call_name
	animation.offense_team_id = offense.id
	animation.defense_team_id = defense.id
	animation.offense_abbreviation = offense.abbreviation
	animation.defense_abbreviation = defense.abbreviation
	animation.offense_color = offense.primary_color
	animation.defense_color = defense.primary_color
	animation.direction = 1.0 if offense.id == state.away_team.id else -1.0
	animation.line_of_scrimmage = _absolute_yard(result.starting_field_position, animation.direction)
	animation.line_to_gain = clampf(animation.line_of_scrimmage + animation.direction * float(result.yards_to_first), 0.0, 100.0)
	animation.duration_seconds = _duration_for(result)
	animation.outcome_label = _outcome_label(result)
	animation.outcome_color = _outcome_color(result)

	var outcome_yards := _outcome_yards(result)
	var outcome_x := clampf(animation.line_of_scrimmage + animation.direction * outcome_yards, 0.0, 100.0)
	var outcome_y := _outcome_lane(result)
	animation.outcome_position = Vector2(outcome_x, outcome_y)

	var offense_players := _participants(offense, result.offensive_participant_ids, result.special_teams_participant_ids, result.call_personnel, true)
	var defense_players := _participants(defense, result.defensive_participant_ids, [], "Base", false)
	var offense_starts := _formation_positions(offense_players, animation.line_of_scrimmage, animation.direction, result.call_formation, true)
	var defense_starts := _formation_positions(defense_players, animation.line_of_scrimmage, animation.direction, result.defensive_call_name, false)

	for index in range(offense_players.size()):
		var player := offense_players[index]
		var track := _new_track(player, offense, true, offense_starts[player.id], _is_featured(player.id, result))
		_compose_offense_track(track, player, index, result, animation)
		animation.actor_tracks.append(track)
	for index in range(defense_players.size()):
		var player := defense_players[index]
		var track := _new_track(player, defense, false, defense_starts[player.id], _is_featured(player.id, result))
		_compose_defense_track(track, player, index, result, animation)
		animation.actor_tracks.append(track)

	_compose_ball_track(animation, result)
	return animation


static func _participants(
	team: TeamData,
	primary_ids: Array[String],
	special_ids: Array[String],
	personnel: String,
	is_offense: bool
) -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	var used: Dictionary = {}
	for player_id in special_ids + primary_ids:
		var player := team.player_by_id(player_id)
		if player != null and not used.has(player.id):
			players.append(player)
			used[player.id] = true
	var fallback := PersonnelPackageService.offensive_lineup(team, personnel) if is_offense and PersonnelPackageService.OFFENSIVE_PACKAGES.has(personnel) else PersonnelPackageService.defensive_lineup(team, personnel)
	if is_offense and not PersonnelPackageService.OFFENSIVE_PACKAGES.has(personnel):
		fallback = PersonnelPackageService.offensive_lineup(team, "11")
	for player in fallback:
		if not used.has(player.id):
			players.append(player)
			used[player.id] = true
		if players.size() >= 11:
			break
	if players.size() < 11:
		for player in team.players:
			if player.is_available() and not used.has(player.id):
				players.append(player)
				used[player.id] = true
			if players.size() >= 11:
				break
	if players.size() > 11:
		players.resize(11)
	return players


static func _formation_positions(
	players: Array[PlayerData],
	line_of_scrimmage: float,
	direction: float,
	formation: String,
	is_offense: bool
) -> Dictionary:
	var positions: Dictionary = {}
	var counts: Dictionary = {}
	for player in players:
		var ordinal := int(counts.get(player.position, 0))
		counts[player.position] = ordinal + 1
		var offset := _offensive_offset(player.position, ordinal, formation) if is_offense else _defensive_offset(player.position, ordinal, formation)
		positions[player.id] = Vector2(clampf(line_of_scrimmage + direction * offset.x, 0.0, 100.0), offset.y)
	return positions


static func _offensive_offset(position_name: String, ordinal: int, formation: String) -> Vector2:
	match position_name:
		"LT": return Vector2(-0.2, 0.34)
		"LG": return Vector2(-0.2, 0.42)
		"C", "LS": return Vector2(0.0, 0.50)
		"RG": return Vector2(-0.2, 0.58)
		"RT": return Vector2(-0.2, 0.66)
		"QB": return Vector2(-4.2 if formation in ["Shotgun", "Pistol"] else -2.0, 0.50)
		"RB":
			var rb_lanes: Array[float] = [0.56, 0.44, 0.66]
			return Vector2(-6.5 if formation != "I Formation" else -5.0 - ordinal * 2.0, rb_lanes[ordinal % rb_lanes.size()])
		"WR":
			var receiver_lanes: Array[float] = [0.10, 0.90, 0.23, 0.77]
			return Vector2(0.0, receiver_lanes[ordinal % receiver_lanes.size()])
		"TE":
			var tight_end_lanes: Array[float] = [0.28, 0.72, 0.20]
			return Vector2(-0.1, tight_end_lanes[ordinal % tight_end_lanes.size()])
		"K": return Vector2(-7.5, 0.58)
		"P": return Vector2(-12.0, 0.50)
	return Vector2(-1.0 - float(ordinal), 0.18 + float(ordinal % 7) * 0.10)


static func _defensive_offset(position_name: String, ordinal: int, _formation: String) -> Vector2:
	match position_name:
		"EDGE":
			var edge_lanes: Array[float] = [0.30, 0.70, 0.22]
			return Vector2(1.2, edge_lanes[ordinal % edge_lanes.size()])
		"DT":
			var tackle_lanes: Array[float] = [0.43, 0.57, 0.50]
			return Vector2(1.0, tackle_lanes[ordinal % tackle_lanes.size()])
		"LB":
			var linebacker_lanes: Array[float] = [0.34, 0.50, 0.66, 0.24]
			return Vector2(4.0, linebacker_lanes[ordinal % linebacker_lanes.size()])
		"CB":
			var corner_lanes: Array[float] = [0.11, 0.89, 0.24, 0.76]
			return Vector2(3.0, corner_lanes[ordinal % corner_lanes.size()])
		"S":
			var safety_lanes: Array[float] = [0.36, 0.64, 0.50]
			return Vector2(9.0, safety_lanes[ordinal % safety_lanes.size()])
	return Vector2(3.0 + float(ordinal), 0.18 + float(ordinal % 7) * 0.10)


static func _new_track(player: PlayerData, team: TeamData, offense: bool, start: Vector2, featured: bool) -> PlayActorTrack:
	var track := PlayActorTrack.new()
	track.player_id = player.id
	track.team_id = team.id
	track.display_name = player.full_name
	track.icon_label = str(player.jersey_number) if player.jersey_number > 0 else player.position
	track.position_name = player.position
	track.is_offense = offense
	track.is_featured = featured
	track.primary_color = team.primary_color
	track.secondary_color = team.secondary_color
	track.add_keyframe(0.0, start)
	track.add_keyframe(SNAP_PROGRESS, start)
	return track


static func _compose_offense_track(track: PlayActorTrack, player: PlayerData, index: int, result: PlayResult, animation: PlayAnimationData) -> void:
	var start: Vector2 = track.keyframe_positions.front()
	var direction := animation.direction
	var outcome := animation.outcome_position
	if result.play_type in ["field_goal", "punt"]:
		var coverage_end := Vector2(clampf(start.x + direction * 18.0, 0.0, 100.0), lerpf(start.y, 0.50, 0.18))
		if player.id in [result.kicker_id, result.punter_id]:
			coverage_end = Vector2(start.x + direction * 1.5, start.y)
		track.add_keyframe(0.45, start + Vector2(direction * 1.0, 0.0))
		track.add_keyframe(1.0, coverage_end)
		return
	if player.id == result.ball_carrier_id:
		var mesh := Vector2(animation.line_of_scrimmage - direction * 2.0, _outcome_lane(result))
		track.add_keyframe(0.30, mesh)
		track.add_keyframe(0.72, outcome.lerp(mesh, 0.22))
		track.add_keyframe(1.0, outcome)
		return
	if player.id == result.passer_id:
		if result.sack:
			track.add_keyframe(0.52, start - Vector2(direction * 2.5, 0.0))
			track.add_keyframe(1.0, outcome)
		else:
			track.add_keyframe(0.48, start - Vector2(direction * 2.8, 0.0))
			track.add_keyframe(1.0, start - Vector2(direction * 1.2, 0.0))
		return
	if result.play_type == "pass" and player.position in ["WR", "TE", "RB"]:
		var is_target := player.id == result.target_id
		var depth := _target_depth(result) if is_target else _complementary_route_depth(result, index)
		var route_y := _route_lane(start.y, result, index, is_target)
		var route_end := Vector2(clampf(animation.line_of_scrimmage + direction * depth, 0.0, 100.0), route_y)
		track.add_keyframe(0.48, start.lerp(route_end, 0.42))
		if is_target:
			track.add_keyframe(0.74, route_end)
			track.add_keyframe(1.0, outcome if result.completed_pass else route_end)
		else:
			track.add_keyframe(1.0, route_end)
		return
	if player.position in OFFENSIVE_LINE_POSITIONS or player.position == "TE":
		var block_depth := clampf(float(result.yards), -2.0, 4.0) if result.play_type == "run" else -1.2
		var block_end := Vector2(start.x + direction * block_depth, lerpf(start.y, outcome.y, 0.12))
		track.add_keyframe(0.56, block_end)
		track.add_keyframe(1.0, block_end + Vector2(direction * 0.6, 0.0))
		return
	var support_end := Vector2(start.x + direction * clampf(float(result.yards), 0.5, 6.0), lerpf(start.y, outcome.y, 0.30))
	track.add_keyframe(0.56, start.lerp(support_end, 0.55))
	track.add_keyframe(1.0, support_end)


static func _compose_defense_track(track: PlayActorTrack, player: PlayerData, index: int, result: PlayResult, animation: PlayAnimationData) -> void:
	var start: Vector2 = track.keyframe_positions.front()
	var direction := animation.direction
	var outcome := animation.outcome_position
	if result.play_type in ["field_goal", "punt"]:
		var return_lane := 0.50 + (float(index % 5) - 2.0) * 0.08
		track.add_keyframe(0.48, start + Vector2(-direction * 3.0, 0.0))
		track.add_keyframe(1.0, Vector2(outcome.x, clampf(return_lane, 0.08, 0.92)))
		return
	if player.id == result.interceptor_id:
		var catch_point := Vector2(outcome.x, outcome.y)
		track.add_keyframe(0.55, start.lerp(catch_point, 0.55))
		track.add_keyframe(0.78, catch_point)
		track.add_keyframe(1.0, catch_point - Vector2(direction * 2.0, 0.0))
		return
	if player.id in result.tackler_ids or player.id in [result.sack_player_id, result.forced_fumble_player_id, result.pass_defender_id]:
		track.add_keyframe(0.52, start.lerp(outcome, 0.45))
		track.add_keyframe(1.0, outcome)
		return
	if result.play_type == "pass" and player.position in ["CB", "S", "LB"]:
		var coverage_depth := _target_depth(result) * (0.78 if player.position == "CB" else 0.58)
		var coverage_y := _route_lane(start.y, result, index, false)
		var coverage_end := Vector2(clampf(animation.line_of_scrimmage + direction * coverage_depth, 0.0, 100.0), coverage_y)
		track.add_keyframe(0.52, start.lerp(coverage_end, 0.52))
		track.add_keyframe(1.0, coverage_end)
		return
	if player.position in DEFENSIVE_FRONT_POSITIONS:
		var pressure_end := Vector2(animation.line_of_scrimmage - direction * 3.5, lerpf(start.y, 0.50, 0.35))
		track.add_keyframe(0.55, pressure_end)
		track.add_keyframe(1.0, pressure_end)
		return
	var pursuit: Vector2 = start.lerp(outcome, 0.78)
	track.add_keyframe(0.58, start.lerp(pursuit, 0.45))
	track.add_keyframe(1.0, pursuit)


static func _compose_ball_track(animation: PlayAnimationData, result: PlayResult) -> void:
	var snap_position := Vector2(animation.line_of_scrimmage, 0.50)
	animation.add_ball_keyframe(0.0, snap_position)
	animation.add_ball_keyframe(SNAP_PROGRESS, snap_position)
	if result.play_type == "punt":
		var punter := animation.track_for_player(result.punter_id)
		var punt_start := punter.sample(0.30) if punter != null else snap_position - Vector2(animation.direction * 12.0, 0.0)
		animation.add_ball_keyframe(0.30, punt_start)
		animation.add_ball_keyframe(0.86, animation.outcome_position)
		animation.add_ball_keyframe(1.0, animation.outcome_position)
		animation.ball_is_kick = true
		return
	if result.play_type == "field_goal":
		var kicker := animation.track_for_player(result.kicker_id)
		var kick_start := kicker.sample(0.35) if kicker != null else snap_position - Vector2(animation.direction * 7.0, 0.0)
		var goal_x := 100.0 if animation.direction > 0.0 else 0.0
		animation.outcome_position = Vector2(goal_x, 0.50)
		animation.add_ball_keyframe(0.34, kick_start)
		animation.add_ball_keyframe(0.88, animation.outcome_position)
		animation.add_ball_keyframe(1.0, animation.outcome_position)
		animation.ball_is_kick = true
		return
	if result.play_type == "run":
		var carrier := animation.track_for_player(result.ball_carrier_id)
		var handoff := carrier.sample(0.30) if carrier != null else snap_position - Vector2(animation.direction * 2.0, 0.0)
		animation.add_ball_keyframe(0.30, handoff)
		animation.add_ball_keyframe(1.0, carrier.sample(1.0) if carrier != null else animation.outcome_position)
		return
	var passer := animation.track_for_player(result.passer_id)
	var release := passer.sample(0.48) if passer != null else snap_position - Vector2(animation.direction * 4.0, 0.0)
	animation.add_ball_keyframe(0.32, release)
	animation.add_ball_keyframe(0.48, release)
	if result.sack:
		animation.add_ball_keyframe(1.0, animation.outcome_position)
		return
	if result.call_id == "spike":
		animation.add_ball_keyframe(0.62, Vector2(animation.line_of_scrimmage + animation.direction * 1.0, 0.50))
		animation.add_ball_keyframe(1.0, Vector2(animation.line_of_scrimmage + animation.direction * 1.0, 0.50))
		animation.ball_visible_until = 0.72
		return
	var recipient_id := result.interceptor_id if result.interception else result.target_id
	var recipient := animation.track_for_player(recipient_id)
	var arrival := recipient.sample(0.74) if recipient != null else animation.outcome_position
	if not result.completed_pass and not result.interception:
		arrival.y = clampf(arrival.y + (0.055 if result.sequence % 2 == 0 else -0.055), 0.04, 0.96)
	animation.add_ball_keyframe(0.74, arrival)
	animation.add_ball_keyframe(1.0, recipient.sample(1.0) if recipient != null and (result.completed_pass or result.interception) else arrival)
	if not result.completed_pass and not result.interception:
		animation.ball_visible_until = 0.84


static func _absolute_yard(relative_yard: int, direction: float) -> float:
	return float(relative_yard) if direction > 0.0 else 100.0 - float(relative_yard)


static func _outcome_yards(result: PlayResult) -> float:
	if result.play_type == "field_goal":
		return float(100 - result.starting_field_position)
	if result.interception:
		return _target_depth(result)
	if result.play_type == "pass" and not result.completed_pass and not result.sack:
		return _target_depth(result)
	return float(result.yards)


static func _target_depth(result: PlayResult) -> float:
	if result.matchup_context.has("air_yards"):
		return clampf(float(result.matchup_context["air_yards"]), 1.0, 40.0)
	if result.call_id in ["four_verticals", "post_corner", "max_protect_shot"]:
		return 24.0
	if result.call_id in ["curls", "flood", "levels", "play_action_cross", "bootleg", "te_seam"]:
		return 13.0
	if result.call_id == "rb_screen":
		return 2.0
	return 7.0


static func _complementary_route_depth(result: PlayResult, index: int) -> float:
	var target_depth := _target_depth(result)
	var adjustment := float([-5.0, 3.0, 7.0, -2.0][index % 4])
	return clampf(target_depth + adjustment, 3.0, 32.0)


static func _route_lane(start_y: float, result: PlayResult, index: int, is_target: bool) -> float:
	if result.call_id in ["quick_slants", "levels", "mesh", "play_action_cross"]:
		return clampf(0.50 + (0.08 if start_y < 0.5 else -0.08), 0.08, 0.92)
	if result.call_id in ["flood", "bootleg", "post_corner"]:
		return 0.16 if result.sequence % 2 == 0 else 0.84
	if is_target:
		return clampf(start_y + (0.08 if index % 2 == 0 else -0.08), 0.08, 0.92)
	return clampf(start_y + (float(index % 3) - 1.0) * 0.05, 0.08, 0.92)


static func _outcome_lane(result: PlayResult) -> float:
	var lane := str(result.matchup_context.get("lane_label", "")).to_lower()
	if "left" in lane:
		return 0.34
	if "right" in lane:
		return 0.66
	if result.call_id in ["flood", "bootleg", "post_corner"]:
		return 0.18 if result.sequence % 2 == 0 else 0.82
	return 0.46 if result.sequence % 2 == 0 else 0.54


static func _duration_for(result: PlayResult) -> float:
	if result.play_type in ["punt", "field_goal"]:
		return 4.0
	if result.call_id in ["kneel", "spike"]:
		return 2.4
	if result.play_type == "pass" or result.sack:
		return clampf(3.4 + _target_depth(result) * 0.025, 3.4, 4.3)
	return clampf(2.8 + maxf(float(result.yards), 0.0) * 0.035, 2.8, 4.2)


static func _outcome_label(result: PlayResult) -> String:
	if result.touchdown:
		return "TOUCHDOWN"
	if result.interception:
		return "INTERCEPTION"
	if result.fumble_lost:
		return "FUMBLE RECOVERED"
	if result.sack:
		return "SACK"
	if result.play_type == "field_goal":
		return "FIELD GOAL GOOD" if result.field_goal_made else "NO GOOD"
	if result.play_type == "punt":
		return "TOUCHBACK" if result.punt_touchback else "PUNT DOWNED"
	if result.play_type == "pass" and not result.completed_pass:
		return "INCOMPLETE"
	if result.first_down:
		return "FIRST DOWN"
	if result.yards > 0:
		return "+%d YARDS" % result.yards
	if result.yards < 0:
		return "%d YARDS" % result.yards
	return "NO GAIN"


static func _outcome_color(result: PlayResult) -> Color:
	if result.touchdown or result.first_down or result.field_goal_made:
		return GridironTheme.ACCENT
	if result.interception or result.fumble_lost or result.sack:
		return GridironTheme.DANGER
	if result.play_type == "pass" and not result.completed_pass:
		return GridironTheme.WARM
	return Color("58c9ff")


static func _is_featured(player_id: String, result: PlayResult) -> bool:
	return player_id in [
		result.passer_id, result.target_id, result.ball_carrier_id, result.sack_player_id,
		result.interceptor_id, result.fumbler_id, result.forced_fumble_player_id,
		result.recovery_player_id, result.pass_defender_id, result.kicker_id,
		result.punter_id, result.returner_id,
	] or player_id in result.tackler_ids
