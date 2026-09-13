class_name PlayAnimationData
extends RefCounted

var sequence := 0
var title := ""
var description := ""
var play_type := ""
var call_name := ""
var defensive_call_name := ""
var defensive_shell := ""
var offense_team_id := ""
var defense_team_id := ""
var offense_abbreviation := ""
var defense_abbreviation := ""
var offense_color := Color.WHITE
var defense_color := Color.WHITE
var direction := 1.0
var line_of_scrimmage := 25.0
var line_to_gain := 35.0
var outcome_position := Vector2(25.0, 0.5)
var outcome_label := "PLAY COMPLETE"
var outcome_color := GridironTheme.ACCENT
var outcome_progress := 0.82
var duration_seconds := 3.4
var ball_visible_from := 0.0
var ball_visible_until := 1.0
var ball_is_kick := false
var actor_tracks: Array[PlayActorTrack] = []
var ball_keyframe_times: Array[float] = []
var ball_keyframe_positions: Array[Vector2] = []


func add_ball_keyframe(progress: float, field_position: Vector2) -> void:
	var normalized_time := clampf(progress, 0.0, 1.0)
	var normalized_position := Vector2(clampf(field_position.x, 0.0, 100.0), clampf(field_position.y, 0.02, 0.98))
	if not ball_keyframe_times.is_empty() and is_equal_approx(normalized_time, ball_keyframe_times.back()):
		ball_keyframe_positions[ball_keyframe_positions.size() - 1] = normalized_position
		return
	ball_keyframe_times.append(normalized_time)
	ball_keyframe_positions.append(normalized_position)


func ball_position_at(progress: float) -> Vector2:
	if ball_keyframe_positions.is_empty():
		return outcome_position
	var normalized_time := clampf(progress, 0.0, 1.0)
	if normalized_time <= ball_keyframe_times.front():
		return ball_keyframe_positions.front()
	for index in range(1, ball_keyframe_times.size()):
		if normalized_time <= ball_keyframe_times[index]:
			var segment_length := ball_keyframe_times[index] - ball_keyframe_times[index - 1]
			var weight := 1.0 if segment_length <= 0.0 else (normalized_time - ball_keyframe_times[index - 1]) / segment_length
			return ball_keyframe_positions[index - 1].lerp(ball_keyframe_positions[index], weight)
	return ball_keyframe_positions.back()


func track_for_player(player_id: String) -> PlayActorTrack:
	for track in actor_tracks:
		if track.player_id == player_id:
			return track
	return null


func offense_track_count() -> int:
	return actor_tracks.filter(func(track: PlayActorTrack): return track.is_offense).size()


func defense_track_count() -> int:
	return actor_tracks.size() - offense_track_count()


func signature() -> String:
	var values: Array[String] = [str(sequence), play_type, outcome_label, defensive_call_name, defensive_shell]
	for track in actor_tracks:
		values.append("%s:%s:%s" % [track.player_id, track.assignment_role, track.keyframe_positions])
	values.append("ball:" + str(ball_keyframe_positions))
	return "|".join(values)
