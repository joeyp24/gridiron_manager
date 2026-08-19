extends Control

const MAIN_MENU_SCENE := preload("res://scenes/screens/main_menu.tscn")
const TEAM_SELECT_SCENE := preload("res://scenes/screens/team_select.tscn")
const MATCH_CENTER_SCENE := preload("res://scenes/screens/match_center.tscn")

var _session := GameSession.new()
var _route_host: Control
var _section_label: Label
var _portal_button: Button
var _club_button: Button
var _match_button: Button


func _ready() -> void:
	theme = GridironTheme.build()
	_build_shell()
	_show_main_menu()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = GridironTheme.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var shell := UIFactory.vbox(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shell)

	var top_bar := UIFactory.card("TopBarPanel")
	top_bar.custom_minimum_size = Vector2(0, 74)
	shell.add_child(top_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 32)
	top_margin.add_theme_constant_override("margin_right", 32)
	top_margin.add_theme_constant_override("margin_top", 12)
	top_margin.add_theme_constant_override("margin_bottom", 12)
	top_bar.add_child(top_margin)

	var top_row := UIFactory.hbox(12)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_margin.add_child(top_row)

	var mark := TextureRect.new()
	mark.texture = load("res://assets/branding/gridiron_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(42, 42)
	top_row.add_child(mark)

	var brand := UIFactory.vbox(0)
	brand.custom_minimum_size = Vector2(196, 0)
	brand.add_child(UIFactory.label("GRIDIRON", "SectionTitleLabel"))
	brand.add_child(UIFactory.label("MANAGER", "CaptionLabel"))
	top_row.add_child(brand)

	_portal_button = UIFactory.button("PORTAL", "GhostButton")
	_portal_button.pressed.connect(_show_main_menu)
	top_row.add_child(_portal_button)
	_club_button = UIFactory.button("CLUB", "GhostButton")
	_club_button.pressed.connect(_show_team_select)
	top_row.add_child(_club_button)
	_match_button = UIFactory.button("MATCHDAY", "GhostButton")
	_match_button.disabled = true
	_match_button.pressed.connect(_show_current_match)
	top_row.add_child(_match_button)
	top_row.add_child(UIFactory.spacer())

	_section_label = UIFactory.label("PORTAL", "EyebrowLabel")
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_section_label)
	top_row.add_child(UIFactory.badge("PROTOTYPE 0.1", GridironTheme.ACCENT))

	var content_margin := MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 32)
	content_margin.add_theme_constant_override("margin_right", 32)
	content_margin.add_theme_constant_override("margin_top", 24)
	content_margin.add_theme_constant_override("margin_bottom", 28)
	shell.add_child(content_margin)

	_route_host = Control.new()
	_route_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(_route_host)


func _show_main_menu() -> void:
	_section_label.text = "PORTAL"
	_mount(MAIN_MENU_SCENE.instantiate())
	var screen := _route_host.get_child(0)
	screen.new_exhibition_requested.connect(_show_team_select)


func _show_team_select() -> void:
	_section_label.text = "CLUB / EXHIBITION SETUP"
	var screen := TEAM_SELECT_SCENE.instantiate()
	screen.setup(_session.teams)
	screen.back_requested.connect(_show_main_menu)
	screen.game_requested.connect(_start_game)
	_mount(screen)


func _start_game(team: TeamData, opponent: TeamData, strategy: Dictionary) -> void:
	var game_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_session.start_exhibition(team, opponent, strategy, game_seed)
	_match_button.disabled = false
	_show_current_match()


func _show_current_match() -> void:
	if _session.simulator == null:
		return
	_section_label.text = "MATCHDAY / LIVE CENTER"
	var screen := MATCH_CENTER_SCENE.instantiate()
	screen.setup(_session.simulator, _session.user_team)
	screen.exit_requested.connect(_show_team_select)
	screen.rematch_requested.connect(_start_rematch)
	_mount(screen)


func _start_rematch() -> void:
	var game_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_session.start_exhibition(_session.user_team, _session.opponent_team, _session.strategy, game_seed)
	_show_current_match()


func _mount(screen: Control) -> void:
	for child in _route_host.get_children():
		_route_host.remove_child(child)
		child.queue_free()
	_route_host.add_child(screen)
