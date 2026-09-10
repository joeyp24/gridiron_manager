class_name FieldVisual
extends Control

signal animation_started(animation: PlayAnimationData)
signal animation_finished(animation: PlayAnimationData)
signal playback_changed

var game_state: GameStateData
var animation_data: PlayAnimationData
var _elapsed_seconds := 0.0
var _playback_speed := 1.0
var _playing := false
var _completion_emitted := false


func _ready() -> void:
	custom_minimum_size = Vector2(320, 310)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_game_state(value: GameStateData) -> void:
	game_state = value
	queue_redraw()


func play_animation(value: PlayAnimationData) -> void:
	if value == null:
		return
	animation_data = value
	_elapsed_seconds = 0.0
	_playing = true
	_completion_emitted = false
	set_process(true)
	queue_redraw()
	animation_started.emit(animation_data)
	playback_changed.emit()


func clear_animation() -> void:
	animation_data = null
	_elapsed_seconds = 0.0
	_playing = false
	_completion_emitted = false
	set_process(false)
	queue_redraw()
	playback_changed.emit()


func toggle_pause() -> void:
	if not is_animation_active():
		return
	_playing = not _playing
	set_process(_playing)
	queue_redraw()
	playback_changed.emit()


func replay() -> void:
	if animation_data == null:
		return
	_elapsed_seconds = 0.0
	_playing = true
	_completion_emitted = false
	set_process(true)
	queue_redraw()
	animation_started.emit(animation_data)
	playback_changed.emit()


func skip_animation() -> void:
	if not is_animation_active():
		return
	_elapsed_seconds = animation_data.duration_seconds
	_complete_playback()


func set_playback_speed(value: float) -> void:
	_playback_speed = clampf(value, 0.5, 2.0)
	playback_changed.emit()


func playback_speed() -> float:
	return _playback_speed


func playback_progress() -> float:
	if animation_data == null or animation_data.duration_seconds <= 0.0:
		return 0.0
	return clampf(_elapsed_seconds / animation_data.duration_seconds, 0.0, 1.0)


func is_animation_active() -> bool:
	return animation_data != null and not _completion_emitted


func is_paused() -> bool:
	return is_animation_active() and not _playing


func _process(delta: float) -> void:
	if not _playing or animation_data == null:
		return
	_elapsed_seconds += delta * _playback_speed
	if _elapsed_seconds >= animation_data.duration_seconds:
		_elapsed_seconds = animation_data.duration_seconds
		_complete_playback()
	else:
		queue_redraw()
		playback_changed.emit()


func _complete_playback() -> void:
	_playing = false
	set_process(false)
	queue_redraw()
	if not _completion_emitted:
		_completion_emitted = true
		animation_finished.emit(animation_data)
	playback_changed.emit()


func _draw() -> void:
	var outer := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	if outer.size.x <= 0.0 or outer.size.y <= 0.0:
		return
	draw_style_box(_rounded_box(Color("071319"), 14), outer)
	var field := outer.grow(-12)
	draw_style_box(_rounded_box(Color("0c493d"), 8), field)

	var yard_bounds := _visible_yard_bounds()
	var playing_field := _draw_end_zones(field, yard_bounds)
	_draw_field_markings(playing_field, yard_bounds)
	_draw_scrimmage_context(playing_field, yard_bounds)
	if animation_data == null:
		_draw_idle_marker(playing_field, yard_bounds)
		return

	var progress := playback_progress()
	_draw_route_traces(playing_field, yard_bounds, progress)
	for track in animation_data.actor_tracks:
		if not track.is_offense:
			_draw_actor(track, playing_field, yard_bounds, progress)
	for track in animation_data.actor_tracks:
		if track.is_offense:
			_draw_actor(track, playing_field, yard_bounds, progress)
	_draw_ball(playing_field, yard_bounds, progress)
	_draw_outcome(playing_field, yard_bounds, progress)
	if is_paused():
		_draw_paused(field)


func _visible_yard_bounds() -> Vector2:
	if animation_data == null:
		return Vector2(0.0, 100.0)
	var progress := playback_progress()
	var travel := absf(animation_data.outcome_position.x - animation_data.line_of_scrimmage)
	var view_width := clampf(travel + 27.0, 42.0, 72.0)
	var lead_center := animation_data.line_of_scrimmage + animation_data.direction * minf(7.0, view_width * 0.14)
	var follow_weight := clampf((progress - 0.24) / 0.70, 0.0, 1.0)
	var center := lerpf(lead_center, animation_data.outcome_position.x, follow_weight * 0.72)
	var minimum := center - view_width * 0.5
	var maximum := center + view_width * 0.5
	if minimum < 0.0:
		maximum -= minimum
		minimum = 0.0
	if maximum > 100.0:
		minimum -= maximum - 100.0
		maximum = 100.0
	return Vector2(maxf(minimum, 0.0), minf(maximum, 100.0))


func _draw_end_zones(field: Rect2, yard_bounds: Vector2) -> Rect2:
	var left_zone_width := field.size.x * 0.085 if yard_bounds.x <= 0.01 else 0.0
	var right_zone_width := field.size.x * 0.085 if yard_bounds.y >= 99.99 else 0.0
	var playing_field := Rect2(
		field.position + Vector2(left_zone_width, 0.0),
		Vector2(field.size.x - left_zone_width - right_zone_width, field.size.y)
	)
	if left_zone_width > 0.0:
		var left_color := game_state.away_team.primary_color.darkened(0.42) if game_state != null else Color("244a50")
		draw_rect(Rect2(field.position, Vector2(left_zone_width, field.size.y)), left_color)
		_draw_end_zone_label(game_state.away_team.abbreviation if game_state != null else "AWAY", Rect2(field.position, Vector2(left_zone_width, field.size.y)))
	if right_zone_width > 0.0:
		var right_color := game_state.home_team.primary_color.darkened(0.42) if game_state != null else Color("244a50")
		var zone := Rect2(Vector2(field.end.x - right_zone_width, field.position.y), Vector2(right_zone_width, field.size.y))
		draw_rect(zone, right_color)
		_draw_end_zone_label(game_state.home_team.abbreviation if game_state != null else "HOME", zone)
	return playing_field


func _draw_field_markings(field: Rect2, yard_bounds: Vector2) -> void:
	var first_yard := ceili(yard_bounds.x / 5.0) * 5
	var final_yard := floori(yard_bounds.y / 5.0) * 5
	for yard in range(first_yard, final_yard + 1, 5):
		var x := _yard_to_screen(float(yard), field, yard_bounds)
		var major := yard % 10 == 0
		var line_color := Color(0.87, 0.97, 0.92, 0.50 if major else 0.23)
		draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), line_color, 1.2 if major else 1.0)
		if major and yard > 0 and yard < 100:
			_draw_yard_number(yard, x, field)
	var first_hash := ceili(yard_bounds.x)
	var final_hash := floori(yard_bounds.y)
	for yard in range(first_hash, final_hash + 1):
		var hash_x := _yard_to_screen(float(yard), field, yard_bounds)
		for lateral in [0.39, 0.61]:
			draw_line(
				Vector2(hash_x, lerpf(field.position.y, field.end.y, lateral - 0.025)),
				Vector2(hash_x, lerpf(field.position.y, field.end.y, lateral + 0.025)),
				Color(0.9, 1.0, 0.95, 0.28),
				1.0
			)


func _draw_scrimmage_context(field: Rect2, yard_bounds: Vector2) -> void:
	if game_state == null:
		return
	var line_of_scrimmage := _idle_absolute_position()
	var line_to_gain := _idle_absolute_first_down()
	if animation_data != null:
		line_of_scrimmage = animation_data.line_of_scrimmage
		line_to_gain = animation_data.line_to_gain
	if line_to_gain >= yard_bounds.x and line_to_gain <= yard_bounds.y:
		var gain_x := _yard_to_screen(line_to_gain, field, yard_bounds)
		draw_line(Vector2(gain_x, field.position.y), Vector2(gain_x, field.end.y), GridironTheme.WARM, 3.0)
	if line_of_scrimmage >= yard_bounds.x and line_of_scrimmage <= yard_bounds.y:
		var scrimmage_x := _yard_to_screen(line_of_scrimmage, field, yard_bounds)
		draw_line(Vector2(scrimmage_x, field.position.y), Vector2(scrimmage_x, field.end.y), Color("58c9ff"), 3.0)


func _draw_idle_marker(field: Rect2, yard_bounds: Vector2) -> void:
	if game_state == null:
		return
	var marker_position := Vector2(
		_yard_to_screen(_idle_absolute_position(), field, yard_bounds),
		field.position.y + field.size.y * 0.50
	)
	var marker_color := game_state.offense().primary_color
	draw_circle(marker_position, 23.0, Color("071319"))
	draw_circle(marker_position, 19.0, marker_color)
	var font := get_theme_default_font()
	draw_string(font, marker_position + Vector2(-20, 5), game_state.offense().abbreviation, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, _contrast_color(marker_color))


func _draw_route_traces(field: Rect2, yard_bounds: Vector2, progress: float) -> void:
	if animation_data == null or progress > 0.82:
		return
	for track in animation_data.actor_tracks:
		if not track.is_offense or (not track.is_featured and track.position_name not in ["WR", "TE"]):
			continue
		var points := PackedVector2Array()
		for field_position in track.keyframe_positions:
			points.append(_field_to_screen(field_position, field, yard_bounds))
		if points.size() >= 2:
			var route_color := Color(track.primary_color.lightened(0.28), 0.44 if track.is_featured else 0.22)
			draw_polyline(points, route_color, 1.6 if track.is_featured else 1.0, true)


func _draw_actor(track: PlayActorTrack, field: Rect2, yard_bounds: Vector2, progress: float) -> void:
	var position := _field_to_screen(track.sample(progress), field, yard_bounds)
	var radius := clampf(field.size.y * 0.038, 8.0, 12.0)
	if track.is_featured:
		var pulse := 2.0 + sin(progress * TAU * 4.0) * 1.5
		draw_circle(position, radius + 4.0 + pulse, Color(GridironTheme.WARM, 0.52), false, 2.0)
	var outline_color := track.secondary_color
	if _color_distance(track.primary_color, outline_color) < 0.22:
		outline_color = Color.WHITE
	if track.is_offense:
		draw_circle(position, radius + 2.5, Color("071319"))
		draw_circle(position, radius + 1.0, outline_color)
		draw_circle(position, radius - 1.2, track.primary_color)
	else:
		var diamond := PackedVector2Array([
			position + Vector2(0.0, -radius - 2.0), position + Vector2(radius + 2.0, 0.0),
			position + Vector2(0.0, radius + 2.0), position + Vector2(-radius - 2.0, 0.0),
		])
		draw_colored_polygon(diamond, Color("071319"))
		var inner := PackedVector2Array([
			position + Vector2(0.0, -radius), position + Vector2(radius, 0.0),
			position + Vector2(0.0, radius), position + Vector2(-radius, 0.0),
		])
		draw_colored_polygon(inner, track.primary_color)
		draw_polyline(PackedVector2Array([inner[0], inner[1], inner[2], inner[3], inner[0]]), outline_color, 1.5, true)
	var font := get_theme_default_font()
	var font_size := clampi(roundi(radius * 0.92), 8, 12)
	draw_string(font, position + Vector2(-radius, float(font_size) * 0.36), track.icon_label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, font_size, _contrast_color(track.primary_color))
	if field.size.x >= 600.0 and radius >= 11.5:
		draw_string(font, position + Vector2(-18.0, radius + 11.0), track.position_name, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 8, Color(0.95, 1.0, 0.97, 0.78))


func _draw_ball(field: Rect2, yard_bounds: Vector2, progress: float) -> void:
	if animation_data == null or progress < animation_data.ball_visible_from or progress > animation_data.ball_visible_until:
		return
	var ball_field_position := animation_data.ball_position_at(progress)
	var position := _field_to_screen(ball_field_position, field, yard_bounds)
	var airborne := progress > 0.34 and progress < 0.88
	if animation_data.ball_is_kick and airborne:
		position.y -= sin(clampf((progress - 0.34) / 0.54, 0.0, 1.0) * PI) * field.size.y * 0.13
		draw_circle(Vector2(position.x, _field_to_screen(ball_field_position, field, yard_bounds).y), 5.0, Color(0.0, 0.0, 0.0, 0.20))
	var ball_radius := 6.5 if size.x >= 600.0 else 5.0
	draw_circle(position, ball_radius + 4.0, Color(GridironTheme.WARM, 0.22))
	draw_set_transform(position, animation_data.direction * 0.18, Vector2(1.45, 0.78))
	draw_circle(Vector2.ZERO, ball_radius + 1.5, Color("071319"))
	draw_circle(Vector2.ZERO, ball_radius, Color("8d4d2f"))
	draw_line(Vector2(-2.0, 0.0), Vector2(2.0, 0.0), Color("f4e8d1"), 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_outcome(field: Rect2, yard_bounds: Vector2, progress: float) -> void:
	if animation_data == null or progress < animation_data.outcome_progress:
		return
	var position := _field_to_screen(animation_data.outcome_position, field, yard_bounds)
	var reveal := clampf((progress - animation_data.outcome_progress) / 0.12, 0.0, 1.0)
	var ring_radius := lerpf(8.0, 25.0, reveal)
	draw_circle(position, ring_radius, Color(animation_data.outcome_color, 0.82 * reveal), false, 3.0)
	var label_size := Vector2(154.0, 28.0)
	var label_position := position + Vector2(-label_size.x * 0.5, -48.0)
	label_position.x = clampf(label_position.x, field.position.x + 4.0, field.end.x - label_size.x - 4.0)
	label_position.y = clampf(label_position.y, field.position.y + 4.0, field.end.y - label_size.y - 4.0)
	var label_rect := Rect2(label_position, label_size)
	draw_style_box(_outcome_box(Color(animation_data.outcome_color, 0.92 * reveal)), label_rect)
	var font := get_theme_default_font()
	draw_string(font, label_rect.position + Vector2(8.0, 19.0), animation_data.outcome_label, HORIZONTAL_ALIGNMENT_CENTER, label_rect.size.x - 16.0, 11, GridironTheme.INK)


func _draw_paused(field: Rect2) -> void:
	var panel_size := Vector2(124.0, 42.0)
	var panel := Rect2(field.get_center() - panel_size * 0.5, panel_size)
	draw_style_box(_rounded_box(Color(0.02, 0.08, 0.10, 0.90), 8), panel)
	var font := get_theme_default_font()
	draw_string(font, panel.position + Vector2(8.0, 27.0), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 16.0, 14, GridironTheme.TEXT)


func _draw_yard_number(yard: int, x: float, field: Rect2) -> void:
	var number := yard if yard <= 50 else 100 - yard
	var font := get_theme_default_font()
	draw_string(font, Vector2(x - 16.0, field.position.y + 22.0), str(number), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 10, Color(0.92, 1.0, 0.96, 0.43))
	draw_string(font, Vector2(x - 16.0, field.end.y - 12.0), str(number), HORIZONTAL_ALIGNMENT_CENTER, 32.0, 10, Color(0.92, 1.0, 0.96, 0.43))


func _draw_end_zone_label(label: String, zone: Rect2) -> void:
	var font := get_theme_default_font()
	draw_string(font, Vector2(zone.position.x, zone.get_center().y + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, zone.size.x, 11, Color.WHITE)


func _field_to_screen(field_position: Vector2, field: Rect2, yard_bounds: Vector2) -> Vector2:
	return Vector2(
		_yard_to_screen(field_position.x, field, yard_bounds),
		lerpf(field.position.y + 18.0, field.end.y - 18.0, clampf(field_position.y, 0.0, 1.0))
	)


func _yard_to_screen(yard: float, field: Rect2, yard_bounds: Vector2) -> float:
	var span := maxf(yard_bounds.y - yard_bounds.x, 1.0)
	return field.position.x + (yard - yard_bounds.x) / span * field.size.x


func _idle_absolute_position() -> float:
	if game_state == null:
		return 25.0
	return float(game_state.field_position) if game_state.possession_team_id == game_state.away_team.id else 100.0 - float(game_state.field_position)


func _idle_absolute_first_down() -> float:
	if game_state == null:
		return 35.0
	var direction := 1.0 if game_state.possession_team_id == game_state.away_team.id else -1.0
	return clampf(_idle_absolute_position() + direction * float(game_state.yards_to_first), 0.0, 100.0)


func _contrast_color(color: Color) -> Color:
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	return GridironTheme.INK if luminance > 0.58 else Color.WHITE


func _color_distance(first: Color, second: Color) -> float:
	return absf(first.r - second.r) + absf(first.g - second.g) + absf(first.b - second.b)


func _rounded_box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _outcome_box(color: Color) -> StyleBoxFlat:
	var style := _rounded_box(color, 6)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	style.shadow_size = 5
	return style
