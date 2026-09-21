extends Control

const MAIN_MENU_SCENE := preload("res://scenes/screens/main_menu.tscn")
const TEAM_SELECT_SCENE := preload("res://scenes/screens/team_select.tscn")
const MATCH_CENTER_SCENE := preload("res://scenes/screens/match_center.tscn")
const CAREER_SELECT_SCENE := preload("res://scenes/screens/career_select.tscn")
const CAREER_DASHBOARD_SCENE := preload("res://scenes/screens/career_dashboard.tscn")
const ROSTER_SCENE := preload("res://scenes/screens/roster_screen.tscn")
const STRATEGY_SCENE := preload("res://scenes/screens/strategy_screen.tscn")
const GAME_PLAN_SCENE := preload("res://scenes/screens/game_plan_screen.tscn")
const FRONT_OFFICE_SCENE := preload("res://scenes/screens/front_office_screen.tscn")
const FREE_AGENCY_SCENE := preload("res://scenes/screens/free_agency_screen.tscn")
const OFFSEASON_SCENE := preload("res://scenes/screens/offseason_screen.tscn")
const DRAFT_CENTER_SCENE := preload("res://scenes/screens/draft_center_screen.tscn")
const TRADE_CENTER_SCENE := preload("res://scenes/screens/trade_center_screen.tscn")
const STATISTICS_CENTER_SCENE := preload("res://scenes/screens/statistics_center_screen.tscn")
const PLAYERS_SCENE := preload("res://scenes/screens/players_screen.tscn")
const FANTASY_DRAFT_SCENE := preload("res://scenes/screens/fantasy_draft_screen.tscn")
const COACH_SKILLS_SCENE := preload("res://scenes/screens/coach_skills_screen.tscn")

var _exhibition_session := GameSession.new()
var _career: CareerSession
var _save_repository := SaveRepository.new()
var _route_host: Control
var _simulation_overlay: SimulationLoadingOverlay
var _section_label: Label
var _section_context: Label
var _sidebar: PanelContainer
var _sidebar_margin: MarginContainer
var _brand_copy: VBoxContainer
var _nav_section_labels: Array[Label] = []
var _nav_buttons: Dictionary = {}
var _nav_titles: Dictionary = {}
var _nav_short_titles: Dictionary = {}
var _version_badge: PanelContainer
var _content_margin: MarginContainer
var _top_margin: MarginContainer
var _team_context_badge: PanelContainer
var _team_context_label: Label
var _week_context_label: Label
var _career_button: Button
var _roster_button: Button
var _statistics_button: Button
var _players_button: Button
var _strategy_button: Button
var _game_plan_button: Button
var _office_button: Button
var _free_agency_button: Button
var _trade_button: Button
var _match_button: Button
var _coach_button: Button
var _save_state_badge: PanelContainer


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

	var atmosphere := ColorRect.new()
	atmosphere.color = Color(GridironTheme.BLUE, 0.035)
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	atmosphere.custom_minimum_size = Vector2(0, 320)
	atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(atmosphere)

	var shell := UIFactory.hbox(0)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shell)

	_sidebar = UIFactory.card("SidebarPanel")
	_sidebar.custom_minimum_size = Vector2(238, 0)
	shell.add_child(_sidebar)
	_sidebar_margin = MarginContainer.new()
	_sidebar_margin.add_theme_constant_override("margin_left", 14)
	_sidebar_margin.add_theme_constant_override("margin_right", 14)
	_sidebar_margin.add_theme_constant_override("margin_top", 16)
	_sidebar_margin.add_theme_constant_override("margin_bottom", 14)
	_sidebar.add_child(_sidebar_margin)
	var sidebar_column := UIFactory.vbox(7)
	var nav_scroll := ScrollContainer.new()
	nav_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	nav_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar_margin.add_child(nav_scroll)
	sidebar_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav_scroll.add_child(sidebar_column)

	var brand_row := UIFactory.hbox(10)
	brand_row.custom_minimum_size = Vector2(0, 48)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/branding/gridiron_mark.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(38, 38)
	brand_row.add_child(mark)
	_brand_copy = UIFactory.vbox(0)
	_brand_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_brand_copy.add_child(UIFactory.label("GRIDIRON", "SectionTitleLabel"))
	_brand_copy.add_child(UIFactory.label("FRONT OFFICE", "NavSectionLabel"))
	brand_row.add_child(_brand_copy)
	sidebar_column.add_child(brand_row)
	sidebar_column.add_child(UIFactory.spacer(0, 5))

	_add_nav_section(sidebar_column, "SYSTEM")
	_add_nav_button(sidebar_column, "portal", "Portal", "P", _show_main_menu)
	_add_nav_section(sidebar_column, "CLUB")
	_career_button = _add_nav_button(sidebar_column, "career", "Career Hub", "H", _show_career_dashboard)
	_roster_button = _add_nav_button(sidebar_column, "roster", "Roster", "R", _show_roster)
	_players_button = _add_nav_button(sidebar_column, "players", "Player Database", "D", _show_players)
	_add_nav_section(sidebar_column, "PERFORMANCE")
	_coach_button = _add_nav_button(sidebar_column, "coach", "Coach Skills", "K", _show_coach_skills)
	_strategy_button = _add_nav_button(sidebar_column, "strategy", "Team Strategy", "T", _show_strategy)
	_game_plan_button = _add_nav_button(sidebar_column, "game_plan", "Weekly Game Plan", "G", _show_game_plan)
	_statistics_button = _add_nav_button(sidebar_column, "statistics", "Statistics", "S", _show_statistics)
	_add_nav_section(sidebar_column, "FRONT OFFICE")
	_office_button = _add_nav_button(sidebar_column, "office", "Contracts", "C", _show_front_office)
	_free_agency_button = _add_nav_button(sidebar_column, "free_agency", "Free Agency", "F", _show_free_agency)
	_trade_button = _add_nav_button(sidebar_column, "trades", "Trade Center", "X", _show_trade_center)
	_match_button = _add_nav_button(sidebar_column, "match", "Matchday", "M", _show_current_match)
	sidebar_column.add_child(UIFactory.spacer())
	_save_state_badge = UIFactory.status_pill("LOCAL CAREER", GridironTheme.ACCENT)
	sidebar_column.add_child(_save_state_badge)
	_version_badge = UIFactory.status_pill("BUILD 0.9", GridironTheme.TEXT_MUTED)
	sidebar_column.add_child(_version_badge)

	var content_column := UIFactory.vbox(0)
	content_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(content_column)
	var top_bar := UIFactory.card("TopBarPanel")
	top_bar.custom_minimum_size = Vector2(0, 72)
	content_column.add_child(top_bar)
	_top_margin = MarginContainer.new()
	_top_margin.add_theme_constant_override("margin_left", 26)
	_top_margin.add_theme_constant_override("margin_right", 26)
	_top_margin.add_theme_constant_override("margin_top", 11)
	_top_margin.add_theme_constant_override("margin_bottom", 11)
	top_bar.add_child(_top_margin)

	var top_row := UIFactory.hbox(12)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_margin.add_child(top_row)
	var section_copy := UIFactory.vbox(1)
	section_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_section_context = UIFactory.label("GRIDIRON MANAGER", "NavSectionLabel")
	section_copy.add_child(_section_context)
	_section_label = UIFactory.label("PORTAL", "SectionTitleLabel")
	section_copy.add_child(_section_label)
	top_row.add_child(section_copy)
	top_row.add_child(UIFactory.spacer())
	_week_context_label = UIFactory.label("NO ACTIVE CAREER", "CaptionLabel")
	_week_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_week_context_label)
	_team_context_label = UIFactory.label("FRONT OFFICE", "BodyLabel")
	_team_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_team_context_label)
	_team_context_badge = UIFactory.status_pill("GM", GridironTheme.BLUE)
	top_row.add_child(_team_context_badge)

	_content_margin = MarginContainer.new()
	_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_column.add_child(_content_margin)
	_route_host = Control.new()
	_route_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_route_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.add_child(_route_host)

	_simulation_overlay = SimulationLoadingOverlay.new()
	add_child(_simulation_overlay)
	_set_section("PORTAL", "portal")
	_enable_career_navigation()


func _add_nav_section(parent: VBoxContainer, title: String) -> void:
	var section := UIFactory.label(title, "NavSectionLabel")
	section.custom_minimum_size = Vector2(0, 20)
	_nav_section_labels.append(section)
	parent.add_child(section)


func _add_nav_button(parent: VBoxContainer, key: String, title: String, short_title: String, callback: Callable) -> Button:
	var button := UIFactory.button(title, "NavButton")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 39)
	button.tooltip_text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	_nav_buttons[key] = button
	_nav_titles[key] = title
	_nav_short_titles[key] = short_title
	return button


func _show_main_menu() -> void:
	_set_section("PORTAL", "portal")
	var screen := MAIN_MENU_SCENE.instantiate()
	screen.setup(_save_repository.has_save())
	screen.new_career_requested.connect(_show_career_select)
	screen.continue_career_requested.connect(_continue_career)
	screen.exhibition_requested.connect(_show_team_select)
	_mount(screen)


func _show_career_select() -> void:
	_set_section("NEW CAREER / CLUB SELECTION", "portal")
	var screen := CAREER_SELECT_SCENE.instantiate()
	screen.setup()
	screen.back_requested.connect(_show_main_menu)
	screen.career_requested.connect(_start_new_career)
	_mount(screen)


func _start_new_career(source_id: String, team_id: String, career_mode: String) -> void:
	var season_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	_career = CareerSession.new_career(team_id, season_seed, source_id, career_mode)
	_enable_career_navigation()
	_save_career()
	if _career.league.is_fantasy_draft_active():
		_show_fantasy_draft()
	else:
		_show_career_dashboard()


func _continue_career() -> void:
	var loaded := _save_repository.load_career()
	if loaded == null:
		_show_main_menu()
		return
	_career = loaded
	_enable_career_navigation()
	_save_career()
	if _career.league.is_fantasy_draft_active():
		_show_fantasy_draft()
	else:
		_show_career_dashboard()


func _show_career_dashboard() -> void:
	if _career == null:
		return
	if _career.league.is_fantasy_draft_active():
		_show_fantasy_draft()
		return
	_game_plan_button.disabled = _career.league.is_offseason()
	_set_section("CAREER HUB", "career")
	var screen := CAREER_DASHBOARD_SCENE.instantiate()
	screen.setup(_career)
	screen.portal_requested.connect(_show_main_menu)
	screen.play_requested.connect(_begin_career_game)
	screen.simulate_requested.connect(_simulate_career_week)
	screen.roster_requested.connect(_show_roster)
	screen.strategy_requested.connect(_show_strategy)
	screen.game_plan_requested.connect(_show_game_plan)
	screen.front_office_requested.connect(_show_front_office)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.trade_center_requested.connect(_show_trade_center)
	screen.statistics_requested.connect(_show_statistics)
	screen.players_requested.connect(_show_players)
	screen.coach_requested.connect(_show_coach_skills)
	screen.offseason_requested.connect(_show_offseason)
	screen.save_requested.connect(_save_career)
	_mount(screen)


func _show_fantasy_draft() -> void:
	if _career == null or _career.league.fantasy_draft == null:
		return
	if not _career.league.is_fantasy_draft_active():
		_enable_career_navigation()
		_show_career_dashboard()
		return
	_set_section("FANTASY DRAFT", "career")
	var screen := FANTASY_DRAFT_SCENE.instantiate()
	screen.setup(_career)
	screen.portal_requested.connect(_show_main_menu)
	screen.draft_changed.connect(_save_career)
	screen.draft_completed.connect(_finish_fantasy_draft)
	screen.player_profile_requested.connect(_show_players)
	_mount(screen)


func _finish_fantasy_draft() -> void:
	_enable_career_navigation()
	_save_career()
	_show_career_dashboard()


func _show_roster() -> void:
	if _career == null:
		return
	_set_section("ROSTER MANAGEMENT", "roster")
	var screen := ROSTER_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.roster_changed.connect(_save_career)
	screen.player_statistics_requested.connect(_show_statistics)
	screen.player_profile_requested.connect(_show_players)
	_mount(screen)


func _show_statistics(initial_player_id: String = "") -> void:
	if _career == null:
		return
	_set_section("LEAGUE STATISTICS", "statistics")
	var screen := STATISTICS_CENTER_SCENE.instantiate()
	screen.setup(_career, initial_player_id)
	screen.back_requested.connect(_show_career_dashboard)
	screen.player_profile_requested.connect(_show_players)
	_mount(screen)


func _show_players(initial_player_id: String = "") -> void:
	if _career == null:
		return
	_set_section("PLAYER DATABASE", "players")
	var screen := PLAYERS_SCENE.instantiate()
	screen.setup(_career, initial_player_id)
	screen.back_requested.connect(_show_career_dashboard)
	screen.statistics_requested.connect(_show_statistics)
	_mount(screen)


func _show_strategy() -> void:
	if _career == null:
		return
	_set_section("TEAM STRATEGY", "strategy")
	var screen := STRATEGY_SCENE.instantiate()
	screen.setup(_career.user_team())
	screen.back_requested.connect(_show_career_dashboard)
	screen.strategy_saved.connect(_save_strategy)
	_mount(screen)


func _show_coach_skills() -> void:
	if _career == null or _career.league.is_fantasy_draft_active():
		return
	_set_section("COACH SKILL TREE", "coach")
	var screen := COACH_SKILLS_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.coach_changed.connect(_save_career)
	_mount(screen)


func _show_game_plan() -> void:
	if _career == null or _career.league.is_offseason():
		return
	_set_section("WEEKLY GAME PLAN", "game_plan")
	var screen := GAME_PLAN_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.game_plan_saved.connect(_save_career)
	screen.player_profile_requested.connect(_show_players)
	_mount(screen)


func _show_front_office() -> void:
	if _career == null:
		return
	_set_section("CONTRACTS & CAP", "office")
	var screen := FRONT_OFFICE_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.trade_center_requested.connect(_show_trade_center)
	screen.front_office_changed.connect(_save_career)
	_mount(screen)


func _show_free_agency() -> void:
	if _career == null:
		return
	_set_section("FREE AGENCY", "free_agency")
	var screen := FREE_AGENCY_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.front_office_requested.connect(_show_front_office)
	screen.market_changed.connect(_save_career)
	screen.player_profile_requested.connect(_show_players)
	_mount(screen)


func _show_trade_center() -> void:
	if _career == null:
		return
	_set_section("TRADE CENTER", "trades")
	var screen := TRADE_CENTER_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.front_office_requested.connect(_show_front_office)
	screen.trade_changed.connect(_save_career)
	_mount(screen)


func _show_offseason() -> void:
	if _career == null or not _career.league.is_offseason():
		return
	_set_section("OFFSEASON CONTROL ROOM", "office")
	var screen := OFFSEASON_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_career_dashboard)
	screen.free_agency_requested.connect(_show_free_agency)
	screen.front_office_requested.connect(_show_front_office)
	screen.draft_center_requested.connect(_show_draft_center)
	screen.offseason_changed.connect(_save_career)
	_mount(screen)


func _show_draft_center() -> void:
	if _career == null or _career.league.current_draft == null:
		return
	_set_section("DRAFT CENTER", "office")
	var screen := DRAFT_CENTER_SCENE.instantiate()
	screen.setup(_career)
	screen.back_requested.connect(_show_offseason)
	screen.front_office_requested.connect(_show_front_office)
	screen.draft_changed.connect(_save_career)
	_mount(screen)


func _save_strategy(values: Dictionary) -> void:
	_career.user_team().set_strategy(values)
	_save_career()
	_show_career_dashboard()


func _simulate_career_week() -> void:
	var week_label := _career.current_week_label()
	var task := _career.start_week_simulation()
	if task == null:
		return
	await _run_week_simulation(
		task,
		"SIMULATING %s" % week_label,
		"Resolving every matchup, roster decision, and league update."
	)
	_show_career_dashboard()


func _begin_career_game() -> void:
	var simulator := _career.begin_user_game()
	if simulator == null:
		return
	_show_career_match()


func _show_career_match() -> void:
	if _career == null or _career.active_simulator == null:
		return
	_set_section("MATCHDAY", "match")
	_match_button.disabled = false
	var screen := MATCH_CENTER_SCENE.instantiate()
	screen.setup(_career.active_simulator, _career.user_team(), true)
	screen.career_game_finished.connect(_finish_career_game)
	_mount(screen)


func _finish_career_game() -> void:
	var week_label := _career.current_week_label()
	var task := _career.start_postgame_simulation()
	if task == null:
		return
	await _run_week_simulation(
		task,
		"FINALIZING %s" % week_label,
		"Recording your result and completing the rest of the league schedule."
	)
	_show_career_dashboard()


func _run_week_simulation(task: WeekSimulationTask, title: String, subtitle: String) -> void:
	_match_button.disabled = true
	_simulation_overlay.begin_operation(title, subtitle, _career.user_team())
	while not task.is_complete():
		_simulation_overlay.update_progress(task.progress_ratio() * 0.94, task.status_text, task.detail_text)
		await get_tree().process_frame
		_career.advance_week_simulation(task)
	_simulation_overlay.update_progress(0.97, "SAVING CAREER", "Writing the completed week, statistics, and transactions to your career file.")
	await get_tree().process_frame
	_save_career()
	_simulation_overlay.update_progress(1.0, "WEEK COMPLETE", "Your career is up to date and ready for the next decision.")
	await get_tree().process_frame
	_simulation_overlay.finish_operation()


func _save_career() -> void:
	if _career != null:
		_save_repository.save_career(_career)


func _show_team_select() -> void:
	_set_section("QUICK EXHIBITION", "portal")
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
	_set_section("EXHIBITION MATCHDAY", "match")
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
	var has_career := _career != null
	var draft_active := _career != null and _career.league.is_fantasy_draft_active()
	_career_button.disabled = not has_career
	_coach_button.disabled = not has_career or draft_active
	_roster_button.disabled = not has_career or draft_active
	_players_button.disabled = not has_career or draft_active
	_statistics_button.disabled = not has_career or draft_active
	_strategy_button.disabled = not has_career or draft_active
	_game_plan_button.disabled = not has_career or draft_active or (_career != null and _career.league.is_offseason())
	_office_button.disabled = not has_career or draft_active
	_free_agency_button.disabled = not has_career or draft_active
	_trade_button.disabled = not has_career or draft_active
	_match_button.disabled = true
	_refresh_shell_context()


func _set_section(title: String, nav_key: String) -> void:
	if _section_label != null:
		_section_label.text = title
	for key in _nav_buttons:
		var nav_button: Button = _nav_buttons[key]
		nav_button.theme_type_variation = "NavButtonActive" if str(key) == nav_key else "NavButton"
	_refresh_shell_context()


func _refresh_shell_context() -> void:
	if _team_context_label == null:
		return
	if _career == null:
		_section_context.text = "GRIDIRON MANAGER / COMMAND CENTER"
		_team_context_label.text = "FRONT OFFICE"
		_week_context_label.text = "NO ACTIVE CAREER"
		_set_context_badge("GM", GridironTheme.BLUE)
		return
	var team := _career.user_team()
	var standing := _career.league.standing_for(team.id)
	var record := standing.record_label() if standing != null else "0-0"
	_section_context.text = "%d SEASON / %s" % [_career.league.season_year, team.abbreviation]
	_team_context_label.text = "%s  ·  %s" % [team.display_name(), record]
	_week_context_label.text = _career.current_week_label().to_upper()
	_set_context_badge(team.abbreviation, team.primary_color)


func _set_context_badge(text_value: String, color: Color) -> void:
	if _team_context_badge == null:
		return
	var badge_label: Label = _team_context_badge.get_child(0)
	badge_label.text = text_value
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_team_context_badge.add_theme_stylebox_override("panel", style)
	var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	badge_label.add_theme_color_override("font_color", GridironTheme.INK if luminance > 0.52 else GridironTheme.TEXT)


func _mount(screen: Control) -> void:
	for child in _route_host.get_children():
		_route_host.remove_child(child)
		child.queue_free()
	_route_host.add_child(screen)
	screen.modulate = Color(1, 1, 1, 0)
	screen.position.x = 10
	var transition := create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transition.tween_property(screen, "modulate", Color.WHITE, 0.16)
	transition.tween_property(screen, "position:x", 0.0, 0.16)
	_refresh_shell_context()


func _apply_responsive_shell() -> void:
	if _content_margin == null:
		return
	var compact := size.x < 1160
	var narrow := size.x < 760
	var margin := 10 if narrow else (16 if compact else 28)
	_content_margin.add_theme_constant_override("margin_left", margin)
	_content_margin.add_theme_constant_override("margin_right", margin)
	_content_margin.add_theme_constant_override("margin_top", 12 if compact else 22)
	_content_margin.add_theme_constant_override("margin_bottom", 12 if compact else 22)
	_top_margin.add_theme_constant_override("margin_left", margin)
	_top_margin.add_theme_constant_override("margin_right", margin)
	_sidebar.custom_minimum_size.x = 66 if narrow else (78 if compact else 238)
	_sidebar_margin.add_theme_constant_override("margin_left", 9 if compact else 14)
	_sidebar_margin.add_theme_constant_override("margin_right", 9 if compact else 14)
	_brand_copy.visible = not compact
	for section in _nav_section_labels:
		section.visible = not compact
	for key in _nav_buttons:
		var nav_button: Button = _nav_buttons[key]
		nav_button.text = str(_nav_short_titles[key]) if compact else str(_nav_titles[key])
		nav_button.alignment = HORIZONTAL_ALIGNMENT_CENTER if compact else HORIZONTAL_ALIGNMENT_LEFT
	_version_badge.visible = not compact
	_save_state_badge.visible = not compact
	_team_context_label.visible = size.x >= 920
	_week_context_label.visible = size.x >= 780
