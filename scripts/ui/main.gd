extends Control

const MAIN_MENU_SCENE := preload("res://scenes/screens/main_menu.tscn")
const TEAM_SELECT_SCENE := preload("res://scenes/screens/team_select.tscn")
const MATCH_CENTER_SCENE := preload("res://scenes/screens/match_center.tscn")
const CAREER_SELECT_SCENE := preload("res://scenes/screens/career_select.tscn")
const CAREER_DASHBOARD_SCENE := preload("res://scenes/screens/career_dashboard.tscn")
const ROSTER_SCENE := preload("res://scenes/screens/roster_screen.tscn")
const STRATEGY_SCENE := preload("res://scenes/screens/strategy_screen.tscn")
const FRONT_OFFICE_SCENE := preload("res://scenes/screens/front_office_screen.tscn")
const FREE_AGENCY_SCENE := preload("res://scenes/screens/free_agency_screen.tscn")
const OFFSEASON_SCENE := preload("res://scenes/screens/offseason_screen.tscn")

var _exhibition_session := GameSession.new()
var _career: CareerSession
var _save_repository := SaveRepository.new()
var _route_host: Control
var _section_label: Label
var _brand: VBoxContainer
var _version_badge: PanelContainer
var _content_margin: MarginContainer
var _top_margin: MarginContainer
var _career_button: Button
var _roster_button: Button
var _strategy_button: Button
var _office_button: Button
var _match_button: Button


func _ready() -> void:
	theme = GridironTheme.build()
	_build_shell()
	resized.connect(_apply_responsive_shell)
	_apply_responsive_shell()
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
	top_bar.custom_minimum_size = Vector2(0, 68)
	shell.add_child(top_bar)
	_top_margin = MarginContainer.new()
	_top_margin.add_theme_constant_override("margin_left", 24)
	_top_margin.add_theme_constant_override("margin_right", 24)
	_top_margin.add_theme_constant_override("margin_top", 10)
	_top_margin.add_theme_constant_override("margin_bottom", 10)
	top_bar.add_child(_top_margin)

	var top_row := UIFactory.hbox(8)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_margin.add_child(top_row)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/branding/gridiron_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(40, 40)
	top_row.add_child(mark)
	_brand = UIFactory.vbox(0)
	_brand.custom_minimum_size = Vector2(170, 0)
	_brand.add_child(UIFactory.label("GRIDIRON", "SectionTitleLabel"))
	_brand.add_child(UIFactory.label("MANAGER", "CaptionLabel"))
	top_row.add_child(_brand)

	var portal := UIFactory.button("PORTAL", "GhostButton")
	portal.pressed.connect(_show_main_menu)
	top_row.add_child(portal)
	_career_button = UIFactory.button("CAREER", "GhostButton")
	_career_button.disabled = true
	_career_button.pressed.connect(_show_career_dashboard)
	top_row.add_child(_career_button)
	_roster_button = UIFactory.button("ROSTER", "GhostButton")
	_roster_button.disabled = true
	_roster_button.pressed.connect(_show_roster)
	top_row.add_child(_roster_button)
	_strategy_button = UIFactory.button("STRATEGY", "GhostButton")
	_strategy_button.disabled = true
	_strategy_button.pressed.connect(_show_strategy)
	top_row.add_child(_strategy_button)
	_office_button = UIFactory.button("OFFICE", "GhostButton")
	_office_button.disabled = true
	_office_button.pressed.connect(_show_front_office)
	top_row.add_child(_office_button)
	_match_button = UIFactory.button("MATCHDAY", "GhostButton")
	_match_button.disabled = true
	_match_button.pressed.connect(_show_current_match)
	top_row.add_child(_match_button)
	top_row.add_child(UIFactory.spacer())
	_section_label = UIFactory.label("PORTAL", "EyebrowLabel")
	_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_section_label)
	_version_badge = UIFactory.badge("CAREER 0.4", GridironTheme.ACCENT)
	top_row.add_child(_version_badge)

	_content_margin = MarginContainer.new()
	_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(_content_margin)
	_route_host = Control.new()
	_route_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.add_child(_route_host)


func _show_main_menu() -> void:
	_section_label.text = "PORTAL"
	var screen := MAIN_MENU_SCENE.instantiate()
	screen.setup(_save_repository.has_save())
	screen.new_career_requested.connect(_show_career_select)
	screen.continue_career_requested.connect(_continue_career)
	screen.exhibition_requested.connect(_show_team_select)
	_mount(screen)


func _show_career_select() -> void:
	_section_label.text = "CAREER / CLUB SELECTION"
	var screen := CAREER_SELECT_SCENE.instantiate()
	screen.setup(SampleLeague.create_teams())
	screen.back_requested.connect(_show_main_menu)
	screen.career_requested.connect(_start_new_career)
	_mount(screen)


func _start_new_career(team_id: String) -> void:
	var season_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_career = CareerSession.new_career(team_id, season_seed)
	_enable_career_navigation()
	_save_career()
	_show_career_dashboard()


func _continue_career() -> void:
	var loaded := _save_repository.load_career()
	if loaded == null:
		_show_main_menu()
		return
	_career = loaded
	_enable_career_navigation()
	_save_career()
	_show_career_dashboard()


func _show_career_dashboard() -> void:
	if _career == null:
		return
	_section_label.text = "CAREER / HUB"
	var screen := CAREER_DASHBOARD_SCENE.instantiate()
	screen.setup(_career)
	screen.portal_requested.connect(_show_main_menu)
	screen.play_requested.connect(_begin_career_game)
	screen.simulate_requested.connect(_simulate_career_week)
	screen.roster_requested.connect(_show_roster)
	screen.strategy_requested.connect(_show_strategy)
	screen.front_office_requested.connect(_show_front_office)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.offseason_requested.connect(_show_offseason)
	screen.save_requested.connect(_save_career)
	_mount(screen)


func _show_roster() -> void:
	if _career == null:
		return
	_section_label.text = "CAREER / DEPTH CHART"
	var screen := ROSTER_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.roster_changed.connect(_save_career)
	_mount(screen)


func _show_strategy() -> void:
	if _career == null:
		return
	_section_label.text = "CAREER / STRATEGY"
	var screen := STRATEGY_SCENE.instantiate()
	screen.setup(_career.user_team())
	screen.back_requested.connect(_show_career_dashboard)
	screen.strategy_saved.connect(_save_strategy)
	_mount(screen)


func _show_front_office() -> void:
	if _career == null:
		return
	_section_label.text = "CAREER / FRONT OFFICE"
	var screen := FRONT_OFFICE_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.front_office_changed.connect(_save_career)
	_mount(screen)


func _show_free_agency() -> void:
	if _career == null:
		return
	_section_label.text = "CAREER / FREE AGENCY"
	var screen := FREE_AGENCY_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.front_office_requested.connect(_show_front_office)
	screen.market_changed.connect(_save_career)
	_mount(screen)


func _show_offseason() -> void:
	if _career == null or not _career.league.is_offseason():
		return
	_section_label.text = "CAREER / OFFSEASON"
	var screen := OFFSEASON_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.front_office_requested.connect(_show_front_office)
	screen.offseason_changed.connect(_save_career)
	_mount(screen)


func _save_strategy(values: Dictionary) -> void:
	_career.user_team().set_strategy(values)
	_save_career()
	_show_career_dashboard()


func _simulate_career_week() -> void:
	_career.simulate_current_week()
	_save_career()
	_show_career_dashboard()


func _begin_career_game() -> void:
	var simulator := _career.begin_user_game()
	if simulator == null:
		return
	_show_career_match()


func _show_career_match() -> void:
	if _career == null or _career.active_simulator == null:
		return
	_section_label.text = "CAREER / MATCHDAY"
	_match_button.disabled = false
	var screen := MATCH_CENTER_SCENE.instantiate()
	screen.setup(_career.active_simulator, _career.user_team(), true)
	screen.career_game_finished.connect(_finish_career_game)
	_mount(screen)


func _finish_career_game() -> void:
	_career.complete_user_game()
	_match_button.disabled = true
	_save_career()
	_show_career_dashboard()


func _save_career() -> void:
	if _career != null:
		_save_repository.save_career(_career)


func _show_team_select() -> void:
	_section_label.text = "EXHIBITION / SETUP"
	var screen := TEAM_SELECT_SCENE.instantiate()
	screen.setup(_exhibition_session.teams)
	screen.back_requested.connect(_show_main_menu)
	screen.game_requested.connect(_start_exhibition)
	_mount(screen)


func _start_exhibition(team: TeamData, opponent: TeamData, strategy: Dictionary) -> void:
	var game_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_exhibition_session.start_exhibition(team, opponent, strategy, game_seed)
	_match_button.disabled = false
	_show_exhibition_match()


func _show_exhibition_match() -> void:
	if _exhibition_session.simulator == null:
		return
	_section_label.text = "EXHIBITION / MATCHDAY"
	var screen := MATCH_CENTER_SCENE.instantiate()
	screen.setup(_exhibition_session.simulator, _exhibition_session.user_team, false)
	screen.exit_requested.connect(_show_team_select)
	screen.rematch_requested.connect(_start_rematch)
	_mount(screen)


func _show_current_match() -> void:
	if _career != null and _career.active_simulator != null:
		_show_career_match()
	else:
		_show_exhibition_match()


func _start_rematch() -> void:
	var game_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_exhibition_session.start_exhibition(
		_exhibition_session.user_team,
		_exhibition_session.opponent_team,
		_exhibition_session.strategy,
		game_seed
	)
	_show_exhibition_match()


func _enable_career_navigation() -> void:
	_career_button.disabled = false
	_roster_button.disabled = false
	_strategy_button.disabled = false
	_office_button.disabled = false


func _mount(screen: Control) -> void:
	for child in _route_host.get_children():
		_route_host.remove_child(child)
		child.queue_free()
	_route_host.add_child(screen)


func _apply_responsive_shell() -> void:
	if _content_margin == null:
		return
	var compact := size.x < 1050
	var margin := 14 if compact else 28
	_content_margin.add_theme_constant_override("margin_left", margin)
	_content_margin.add_theme_constant_override("margin_right", margin)
	_content_margin.add_theme_constant_override("margin_top", 16 if compact else 22)
	_content_margin.add_theme_constant_override("margin_bottom", 16 if compact else 24)
	_top_margin.add_theme_constant_override("margin_left", margin)
	_top_margin.add_theme_constant_override("margin_right", margin)
	_brand.custom_minimum_size.x = 112 if compact else 170
	_brand.get_child(1).visible = not compact
	_section_label.visible = not compact
	_version_badge.visible = size.x >= 880
	_strategy_button.visible = size.x >= 900
	_match_button.visible = not compact or not _match_button.disabled
