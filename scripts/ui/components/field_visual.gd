class_name FieldVisual
extends Control

var game_state: GameStateData


func _ready() -> void:
	custom_minimum_size = Vector2(320, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_game_state(value: GameStateData) -> void:
	game_state = value
	queue_redraw()


func _draw() -> void:
	var outer := Rect2(Vector2(10, 10), size - Vector2(20, 20))
	draw_style_box(_rounded_box(Color("071319"), 14), outer)
	var field := outer.grow(-18)
	draw_style_box(_rounded_box(Color("0c493d"), 8), field)

	var end_zone_width := field.size.x * 0.075
	var playing_field := Rect2(
		field.position + Vector2(end_zone_width, 0),
		Vector2(field.size.x - end_zone_width * 2.0, field.size.y)
	)
	var away_color := Color("244a50")
	var home_color := Color("244a50")
	if game_state != null:
		away_color = game_state.away_team.primary_color.darkened(0.47)
		home_color = game_state.home_team.primary_color.darkened(0.47)
	draw_rect(Rect2(field.position, Vector2(end_zone_width, field.size.y)), away_color)
	draw_rect(
		Rect2(Vector2(field.end.x - end_zone_width, field.position.y), Vector2(end_zone_width, field.size.y)),
		home_color
	)

	for index in range(11):
		var x := playing_field.position.x + playing_field.size.x * float(index) / 10.0
		var line_color := Color(0.87, 0.97, 0.92, 0.34 if index % 5 != 0 else 0.55)
		draw_line(Vector2(x, playing_field.position.y), Vector2(x, playing_field.end.y), line_color, 1.0)
		if index > 0 and index < 10:
			_draw_yard_number(index, x, playing_field)

	for hash_index in range(41):
		var hash_x := playing_field.position.x + playing_field.size.x * float(hash_index) / 40.0
		draw_line(
			Vector2(hash_x, playing_field.position.y + playing_field.size.y * 0.44),
			Vector2(hash_x, playing_field.position.y + playing_field.size.y * 0.48),
			Color(0.9, 1.0, 0.95, 0.30),
			1.0
		)
		draw_line(
			Vector2(hash_x, playing_field.position.y + playing_field.size.y * 0.52),
			Vector2(hash_x, playing_field.position.y + playing_field.size.y * 0.56),
			Color(0.9, 1.0, 0.95, 0.30),
			1.0
		)

	if game_state == null:
		return

	_draw_end_zone_labels(field, end_zone_width)
	var absolute_position := float(game_state.field_position)
	var absolute_first_down := float(game_state.field_position + game_state.yards_to_first)
	if game_state.possession_team_id == game_state.home_team.id:
		absolute_position = 100.0 - float(game_state.field_position)
		absolute_first_down = 100.0 - float(game_state.field_position + game_state.yards_to_first)
	var ball_x := playing_field.position.x + playing_field.size.x * absolute_position / 100.0
	var first_down_x := playing_field.position.x + playing_field.size.x * clampf(absolute_first_down, 0.0, 100.0) / 100.0

	draw_line(
		Vector2(first_down_x, playing_field.position.y),
		Vector2(first_down_x, playing_field.end.y),
		GridironTheme.WARM,
		3.0
	)
	draw_line(
		Vector2(ball_x, playing_field.position.y),
		Vector2(ball_x, playing_field.end.y),
		Color("58c9ff"),
		3.0
	)

	var marker_color := game_state.offense().primary_color
	var marker_position := Vector2(ball_x, playing_field.position.y + playing_field.size.y * 0.50)
	draw_circle(marker_position, 23.0, Color("071319"))
	draw_circle(marker_position, 19.0, marker_color)
	var font := get_theme_default_font()
	draw_string(
		font,
		marker_position + Vector2(-20, 5),
		game_state.offense().abbreviation,
		HORIZONTAL_ALIGNMENT_CENTER,
		40,
		13,
		GridironTheme.INK
	)


func _draw_yard_number(index: int, x: float, field: Rect2) -> void:
	var number := index * 10 if index <= 5 else (10 - index) * 10
	var font := get_theme_default_font()
	draw_string(
		font,
		Vector2(x - 16, field.position.y + 24),
		str(number),
		HORIZONTAL_ALIGNMENT_CENTER,
		32,
		11,
		Color(0.92, 1.0, 0.96, 0.44)
	)
	draw_string(
		font,
		Vector2(x - 16, field.end.y - 14),
		str(number),
		HORIZONTAL_ALIGNMENT_CENTER,
		32,
		11,
		Color(0.92, 1.0, 0.96, 0.44)
	)


func _draw_end_zone_labels(field: Rect2, end_zone_width: float) -> void:
	var font := get_theme_default_font()
	draw_string(
		font,
		Vector2(field.position.x, field.position.y + field.size.y * 0.53),
		game_state.away_team.abbreviation,
		HORIZONTAL_ALIGNMENT_CENTER,
		end_zone_width,
		12,
		Color.WHITE
	)
	draw_string(
		font,
		Vector2(field.end.x - end_zone_width, field.position.y + field.size.y * 0.53),
		game_state.home_team.abbreviation,
		HORIZONTAL_ALIGNMENT_CENTER,
		end_zone_width,
		12,
		Color.WHITE
	)


func _rounded_box(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
