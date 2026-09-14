extends Control

signal back_requested
signal game_plan_saved
signal player_profile_requested(player_id: String)

var _career: CareerSession
var _report: OpponentScoutingReportData
var _plan: WeeklyGamePlanData
var _metric_grid: GridContainer
var _content_grid: GridContainer
var _intel_grid: GridContainer
var _offense_menu: OptionButton
var _defense_menu: OptionButton
var _offense_points_menu: OptionButton
var _defense_points_menu: OptionButton
var _points_label: Label
var _offense_description: Label
var _defense_description: Label
var _effects_host: VBoxContainer
var _status_label: Label
var _save_button: Button


func setup(career: CareerSession) -> void:
	_career = career
	_plan = _career.current_game_plan()
	_report = _career.current_opponent_report()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 760)
	scroll.add_child(page)

	var header := UIFactory.hbox(12)
	var team := _career.user_team()
	header.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	var heading := UIFactory.vbox(1)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(UIFactory.label("WEEKLY GAME PLAN", "PageTitleLabel"))
	var opponent := _career.next_opponent()
	heading.add_child(UIFactory.label(
		"Prepare for %s · %s" % [opponent.display_name(), _career.current_week_label()] if opponent != null else "No managed-club matchup this week",
		"MutedLabel"
	))
	header.add_child(heading)
	var back := UIFactory.button("←  CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	page.add_child(header)

	if _plan == null or _report == null or opponent == null:
		var empty := UIFactory.card("AccentPanel")
		empty.add_child(UIFactory.wrapped_label("Your club has no opponent this week. Use the open date for roster management, then simulate the league slate to continue.", "SectionTitleLabel"))
		page.add_child(empty)
		return

	page.add_child(_build_briefing_banner(opponent))
	_metric_grid = GridContainer.new()
	_metric_grid.columns = 4
	_metric_grid.add_theme_constant_override("h_separation", 12)
	_metric_grid.add_theme_constant_override("v_separation", 12)
	_metric_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_metric_grid)
	_metric_grid.add_child(_metric_card("OFFENSIVE IDENTITY", _report.tendency_label(), "%d%% run rate" % roundi(_report.run_rate * 100.0)))
	_metric_grid.add_child(_metric_card("PRIMARY PERSONNEL", _report.favorite_personnel, "Most-used grouping"))
	_metric_grid.add_child(_metric_card("PRESSURE RATE", "%d%%" % roundi(_report.blitz_rate * 100.0), _report.favorite_defensive_call))
	_metric_grid.add_child(_metric_card("COVERAGE", _report.preferred_coverage, "Most-used family"))

	_content_grid = GridContainer.new()
	_content_grid.columns = 2
	_content_grid.add_theme_constant_override("h_separation", 14)
	_content_grid.add_theme_constant_override("v_separation", 14)
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_content_grid)
	_content_grid.add_child(_build_scouting_card(opponent))
	_content_grid.add_child(_build_plan_card())

	_intel_grid = GridContainer.new()
	_intel_grid.columns = 3
	_intel_grid.add_theme_constant_override("h_separation", 14)
	_intel_grid.add_theme_constant_override("v_separation", 14)
	_intel_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_intel_grid)
	_intel_grid.add_child(_build_key_players_card(opponent))
	_intel_grid.add_child(_build_notes_card("MATCHUP EDGES", "Ratings comparisons for this opponent", _report.matchup_notes))
	_intel_grid.add_child(_build_notes_card("AVAILABILITY", "Opponent injury report", _report.injury_notes))


func _build_briefing_banner(opponent: TeamData) -> PanelContainer:
	var card := UIFactory.card("AccentPanel")
	var row := UIFactory.hbox(16)
	card.add_child(row)
	var copy := UIFactory.vbox(3)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label("OPPONENT BRIEFING", "EyebrowLabel"))
	copy.add_child(UIFactory.label("%s %s" % [opponent.abbreviation, _report.confidence_label()], "SectionTitleLabel"))
	copy.add_child(UIFactory.wrapped_label(
		"%d recent game%s analyzed. Recommendations use only film available before this matchup." % [_report.games_analyzed, "" if _report.games_analyzed == 1 else "s"] if _report.games_analyzed > 0 else "No current-season film is available yet. The early report uses roster quality and established club tendencies.",
		"MutedLabel"
	))
	row.add_child(copy)
	row.add_child(_briefing_metric("CONFIDENCE", "%d%%" % _report.confidence))
	row.add_child(_briefing_metric("OPPONENT OVR", str(opponent.overall_rating())))
	return card


func _build_scouting_card(opponent: TeamData) -> PanelContainer:
	var card := _section_card("SCOUTING REPORT", "Observed performance and call tendencies")
	var column: VBoxContainer = card.get_child(0)
	var performance := GridContainer.new()
	performance.columns = 2
	performance.add_theme_constant_override("h_separation", 8)
	performance.add_theme_constant_override("v_separation", 8)
	performance.add_child(_small_metric("POINTS / GAME", _film_value(_report.points_per_game)))
	performance.add_child(_small_metric("YARDS / GAME", _film_value(_report.yards_per_game, 0)))
	performance.add_child(_small_metric("POINTS ALLOWED", _film_value(_report.points_allowed_per_game)))
	performance.add_child(_small_metric("YARDS ALLOWED", _film_value(_report.yards_allowed_per_game, 0)))
	column.add_child(performance)
	column.add_child(UIFactory.divider())
	column.add_child(UIFactory.label("MOST-CALLED OFFENSE", "EyebrowLabel"))
	column.add_child(UIFactory.wrapped_label(_report.favorite_offensive_call, "BodyLabel"))
	column.add_child(UIFactory.label("PASS PROFILE", "EyebrowLabel"))
	column.add_child(UIFactory.wrapped_label(
		"%d%% quick concepts · %d%% deep concepts" % [roundi(_report.quick_pass_rate * 100.0), roundi(_report.deep_pass_rate * 100.0)],
		"BodyLabel"
	))
	column.add_child(UIFactory.divider())
	column.add_child(UIFactory.label("WHAT THEY DO WELL", "EyebrowLabel"))
	for note in _report.strengths:
		column.add_child(_bullet(note, opponent.primary_color))
	column.add_child(UIFactory.label("WHERE TO ATTACK", "EyebrowLabel"))
	for note in _report.vulnerabilities:
		column.add_child(_bullet(note, GridironTheme.ACCENT))
	return card


func _build_plan_card() -> PanelContainer:
	var card := _section_card("PREPARATION BOARD", "Allocate six points across the two units")
	var column: VBoxContainer = card.get_child(0)
	column.add_child(UIFactory.label("OFFENSIVE PRIORITY", "EyebrowLabel"))
	_offense_menu = _focus_menu(WeeklyGamePlanData.OFFENSIVE_FOCUSES, true, _plan.offensive_focus)
	column.add_child(_offense_menu)
	_offense_description = UIFactory.wrapped_label("", "MutedLabel")
	column.add_child(_offense_description)
	column.add_child(UIFactory.label("OFFENSIVE PREPARATION", "EyebrowLabel"))
	_offense_points_menu = _points_menu(_plan.offensive_points)
	column.add_child(_offense_points_menu)
	column.add_child(UIFactory.divider())
	column.add_child(UIFactory.label("DEFENSIVE PRIORITY", "EyebrowLabel"))
	_defense_menu = _focus_menu(WeeklyGamePlanData.DEFENSIVE_FOCUSES, false, _plan.defensive_focus)
	column.add_child(_defense_menu)
	_defense_description = UIFactory.wrapped_label("", "MutedLabel")
	column.add_child(_defense_description)
	column.add_child(UIFactory.label("DEFENSIVE PREPARATION", "EyebrowLabel"))
	_defense_points_menu = _points_menu(_plan.defensive_points)
	column.add_child(_defense_points_menu)

	var budget := UIFactory.card("InsetPanel")
	var budget_column := UIFactory.vbox(5)
	budget.add_child(budget_column)
	_points_label = UIFactory.label("", "SectionTitleLabel")
	budget_column.add_child(_points_label)
	budget_column.add_child(UIFactory.wrapped_label("Intensive preparation creates a larger focused effect. Unused points provide no benefit, and both units cannot receive four points.", "MutedLabel"))
	column.add_child(budget)

	column.add_child(UIFactory.label("EXPECTED EFFECT", "EyebrowLabel"))
	_effects_host = UIFactory.vbox(5)
	column.add_child(_effects_host)
	_status_label = UIFactory.wrapped_label("", "CaptionLabel")
	column.add_child(_status_label)
	_save_button = UIFactory.button("SAVE WEEKLY PLAN  →", "PrimaryButton")
	_save_button.custom_minimum_size = Vector2(0, 48)
	_save_button.pressed.connect(_save_plan)
	column.add_child(_save_button)

	for menu in [_offense_menu, _defense_menu, _offense_points_menu, _defense_points_menu]:
		menu.item_selected.connect(func(_index: int): _refresh_plan_preview())
	_refresh_plan_preview()
	return card


func _build_key_players_card(opponent: TeamData) -> PanelContainer:
	var card := _section_card("KEY THREATS", "Highest-rated available opponents")
	var column: VBoxContainer = card.get_child(0)
	for player_data in _report.key_players:
		var row := UIFactory.card("InsetPanel")
		var contents := UIFactory.hbox(8)
		row.add_child(contents)
		contents.add_child(UIFactory.badge(str(player_data.get("position", "")), opponent.primary_color))
		var identity := UIFactory.vbox(0)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(UIFactory.label(str(player_data.get("name", "")), "BodyLabel"))
		identity.add_child(UIFactory.label(str(player_data.get("status", "Available")), "CaptionLabel"))
		contents.add_child(identity)
		contents.add_child(UIFactory.label(str(player_data.get("overall", 0)), "MetricLabel"))
		var view := UIFactory.button("VIEW", "GhostButton")
		var player_id := str(player_data.get("player_id", ""))
		view.pressed.connect(func(): player_profile_requested.emit(player_id))
		contents.add_child(view)
		column.add_child(row)
	return card


func _build_notes_card(title: String, subtitle: String, notes: Array[String]) -> PanelContainer:
	var card := _section_card(title, subtitle)
	var column: VBoxContainer = card.get_child(0)
	for note in notes:
		column.add_child(_bullet(note, GridironTheme.ACCENT))
	return card


func _section_card(title: String, subtitle: String) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(340, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return card


func _metric_card(title: String, value: String, subtitle: String) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(190, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(3)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "EyebrowLabel"))
	column.add_child(UIFactory.label(value, "MetricLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return card


func _small_metric(title: String, value: String) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(1)
	card.add_child(column)
	column.add_child(UIFactory.label(value, "BodyLabel"))
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	return card


func _briefing_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(112, 0)
	var value_label := UIFactory.label(value, "MetricLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.add_child(value_label)
	var title_label := UIFactory.label(title, "CaptionLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metric.add_child(title_label)
	return metric


func _bullet(text_value: String, color: Color) -> HBoxContainer:
	var row := UIFactory.hbox(7)
	var marker := UIFactory.label("◆", "CaptionLabel")
	marker.modulate = color
	row.add_child(marker)
	var copy := UIFactory.wrapped_label(text_value, "MutedLabel")
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	return row


func _focus_menu(focuses: Array[String], offense: bool, selected_focus: String) -> OptionButton:
	var menu := OptionButton.new()
	menu.custom_minimum_size = Vector2(0, 44)
	for focus_id in focuses:
		menu.add_item(
			WeeklyGamePlanData.offensive_focus_label(focus_id) if offense else WeeklyGamePlanData.defensive_focus_label(focus_id)
		)
		menu.set_item_metadata(menu.item_count - 1, focus_id)
		if focus_id == selected_focus:
			menu.select(menu.item_count - 1)
	return menu


func _points_menu(selected_points: int) -> OptionButton:
	var menu := OptionButton.new()
	menu.custom_minimum_size = Vector2(0, 44)
	var labels := ["Light", "Standard", "Strong", "Intensive"]
	for points in range(1, 5):
		menu.add_item("%d point%s · %s" % [points, "" if points == 1 else "s", labels[points - 1]])
		menu.set_item_metadata(menu.item_count - 1, points)
	menu.select(clampi(selected_points - 1, 0, 3))
	return menu


func _draft_plan() -> WeeklyGamePlanData:
	var draft := WeeklyGamePlanData.from_dict(_plan.to_dict())
	draft.offensive_focus = str(_offense_menu.get_item_metadata(_offense_menu.selected))
	draft.defensive_focus = str(_defense_menu.get_item_metadata(_defense_menu.selected))
	draft.offensive_points = int(_offense_points_menu.get_item_metadata(_offense_points_menu.selected))
	draft.defensive_points = int(_defense_points_menu.get_item_metadata(_defense_points_menu.selected))
	return draft


func _refresh_plan_preview() -> void:
	if _offense_menu == null:
		return
	var draft := _draft_plan()
	_offense_description.text = WeeklyGamePlanData.offensive_focus_description(draft.offensive_focus)
	_defense_description.text = WeeklyGamePlanData.defensive_focus_description(draft.defensive_focus)
	var remaining := draft.points_remaining()
	_points_label.text = "%d / %d POINTS USED" % [draft.points_used(), WeeklyGamePlanData.TOTAL_PREPARATION_POINTS]
	_points_label.modulate = GridironTheme.DANGER if remaining < 0 else GridironTheme.ACCENT
	for child in _effects_host.get_children():
		child.queue_free()
	for line in GamePlanningService.effect_lines(draft):
		_effects_host.add_child(_bullet(line, GridironTheme.ACCENT))
	var error := draft.validation_error()
	var locked := _career.active_simulator != null or (_career.current_matchup() != null and _career.current_matchup().played)
	_save_button.disabled = not error.is_empty() or locked
	if locked:
		_status_label.text = "The weekly plan is locked because this matchup has already started."
		_status_label.modulate = GridironTheme.TEXT_MUTED
	elif not error.is_empty():
		_status_label.text = error
		_status_label.modulate = GridironTheme.DANGER
	else:
		_status_label.text = "%d preparation point%s remain%s." % [remaining, "" if remaining == 1 else "s", " and will be unused" if remaining > 0 else ""]
		_status_label.modulate = GridironTheme.TEXT_MUTED


func _save_plan() -> void:
	var draft := _draft_plan()
	var result := _career.save_game_plan(
		draft.offensive_focus,
		draft.defensive_focus,
		draft.offensive_points,
		draft.defensive_points
	)
	_status_label.text = str(result.get("message", "Unable to save the weekly plan."))
	_status_label.modulate = GridironTheme.ACCENT if bool(result.get("ok", false)) else GridironTheme.DANGER
	if bool(result.get("ok", false)):
		_plan = result.get("plan", _plan)
		game_plan_saved.emit()


func _film_value(value: float, decimals: int = 1) -> String:
	if _report.games_analyzed <= 0:
		return "—"
	return ("%.1f" % value) if decimals > 0 else str(roundi(value))


func _apply_responsive_layout() -> void:
	if _metric_grid != null:
		_metric_grid.columns = 4 if size.x >= 1080 else (2 if size.x >= 620 else 1)
	if _content_grid != null:
		_content_grid.columns = 2 if size.x >= 900 else 1
	if _intel_grid != null:
		_intel_grid.columns = 3 if size.x >= 1120 else (2 if size.x >= 760 else 1)
