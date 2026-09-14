class_name PlayActorTrack
extends RefCounted

var player_id := ""
var team_id := ""
var display_name := ""
var icon_label := ""
var position_name := ""
var assignment_role := ""
var is_offense := false
var is_featured := false
var primary_color := Color.WHITE
var secondary_color := Color.BLACK
var keyframe_times: Array[float] = []
var keyframe_positions: Array[Vector2] = []


func add_keyframe(progress: float, field_position: Vector2) -> void:
	var normalized_time := clampf(progress, 0.0, 1.0)
	var normalized_position := Vector2(clampf(field_position.x, 0.0, 100.0), clampf(field_position.y, 0.04, 0.96))
	if not keyframe_times.is_empty() and normalized_time < keyframe_times.back():
		push_error("Play animation keyframes must be added in chronological order")
		return
	if not keyframe_times.is_empty() and is_equal_approx(normalized_time, keyframe_times.back()):
		keyframe_positions[keyframe_positions.size() - 1] = normalized_position
		return
	keyframe_times.append(normalized_time)
	keyframe_positions.append(normalized_position)


func sample(progress: float) -> Vector2:
	if keyframe_positions.is_empty():
		return Vector2.ZERO
	var normalized_time := clampf(progress, 0.0, 1.0)
	if normalized_time <= keyframe_times.front():
		return keyframe_positions.front()
	for index in range(1, keyframe_times.size()):
		if normalized_time <= keyframe_times[index]:
			var segment_length := keyframe_times[index] - keyframe_times[index - 1]
			var weight := 1.0 if segment_length <= 0.0 else (normalized_time - keyframe_times[index - 1]) / segment_length
			return keyframe_positions[index - 1].lerp(keyframe_positions[index], _smooth(weight))
	return keyframe_positions.back()


func is_valid() -> bool:
	return not player_id.is_empty() and keyframe_times.size() == keyframe_positions.size() and keyframe_times.size() >= 2


func _smooth(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)
