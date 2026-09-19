extends Control

signal back_requested
signal strategy_saved(values: Dictionary)

var _team: TeamData
var _settings_grid: GridContainer
var _run_menu: OptionButton
var _tempo_menu: OptionButton
var _depth_menu: OptionButton
var _aggression_menu: OptionButton
var _blitz_menu: OptionButton
var _coverage_menu: OptionButton


func setup(team: TeamData) -> void:
	_team = team


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(18)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 660)
	scroll.add_child(page)

	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(_team.abbreviation, _team.primary_color))
	var copy := UIFactory.page_heading("COACHING", "Team Strategy", "Set the identity that persists from one game week to the next.")
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var back := UIFactory.button("←  CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	page.add_child(header)

	var overview := UIFactory.card("HeroPanel")
	page.add_child(overview)
	var overview_row := UIFactory.hbox(18)
	overview.add_child(overview_row)
	var overview_copy := UIFactory.vbox(3)
	overview_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview_copy.add_child(UIFactory.label("COACHING IDENTITY", "EyebrowLabel"))
	overview_copy.add_child(UIFactory.label("Your settings influence every simulated snap", "SectionTitleLabel"))
	overview_copy.add_child(UIFactory.wrapped_label("Play selection, clock usage, target depth, pressure rate, coverage behavior, and fourth-down decisions all flow from this plan.", "MutedLabel"))
	overview_row.add_child(overview_copy)
	overview_row.add_child(_identity_metric("RUN RATE", "%d%%" % roundi(_team.run_tendency * 100.0)))
	overview_row.add_child(_identity_metric("BLITZ RATE", "%d%%" % roundi(_team.blitz_rate * 100.0)))

	_settings_grid = GridContainer.new()
	_settings_grid.columns = 2
	_settings_grid.add_theme_constant_override("h_separation", 16)
	_settings_grid.add_theme_constant_override("v_separation", 16)
	_settings_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_settings_grid)
	_settings_grid.add_child(_build_offense_card())
	_settings_grid.add_child(_build_defense_card())

	var actions := UIFactory.hbox(10)
	actions.add_child(UIFactory.spacer())
	var save := UIFactory.button("SAVE STRATEGY  →", "PrimaryButton")
	save.custom_minimum_size = Vector2(200, 48)
	save.pressed.connect(_save_strategy)
	actions.add_child(save)
	page.add_child(actions)


func _build_offense_card() -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(11)
	card.add_child(column)
	column.add_child(UIFactory.section_heading("OFFENSIVE PLAN", "Shape play calling and game pace"))
	_run_menu = _setting_menu(column, "RUN / PASS BALANCE", ["Air attack", "Balanced", "Ground control"], _trinary_index(_team.run_tendency))
	_tempo_menu = _setting_menu(column, "TEMPO", ["Methodical", "Balanced", "Up-tempo"], _trinary_index(_team.tempo))
	_depth_menu = _setting_menu(column, "PASSING DEPTH", ["Short", "Balanced", "Vertical"], _trinary_index(_team.passing_depth))
	_aggression_menu = _setting_menu(column, "FOURTH-DOWN PROFILE", ["Conservative", "Balanced", "Aggressive"], _trinary_index(_team.aggression))
	return card


func _build_defense_card() -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(11)
	card.add_child(column)
	column.add_child(UIFactory.section_heading("DEFENSIVE PLAN", "Control pressure and coverage risk"))
	_blitz_menu = _setting_menu(column, "BLITZ FREQUENCY", ["Selective", "Balanced", "Pressure-heavy"], _trinary_index(_team.blitz_rate))
	_coverage_menu = _setting_menu(column, "COVERAGE PREFERENCE", ["Zone", "Balanced", "Man"], ["Zone", "Balanced", "Man"].find(_team.coverage_preference))
	column.add_child(UIFactory.spacer(0, 12))
	var note := UIFactory.card("InsetPanel")
	note.add_child(UIFactory.wrapped_label("Pressure creates sacks and hurried decisions but can expose the secondary. Personnel quality still determines how effectively the plan is executed.", "MutedLabel"))
	column.add_child(note)
	return card


func _setting_menu(parent: VBoxContainer, label_text: String, values: Array[String], selected_index: int) -> OptionButton:
	parent.add_child(UIFactory.label(label_text, "EyebrowLabel"))
	var menu := OptionButton.new()
	menu.custom_minimum_size = Vector2(0, 44)
	for value in values:
		menu.add_item(value)
	menu.select(clampi(selected_index, 0, values.size() - 1))
	parent.add_child(menu)
	return menu


func _save_strategy() -> void:
	var scale := [0.34, 0.50, 0.68]
	var run_scale := [0.32, 0.46, 0.61]
	var coverage := ["Zone", "Balanced", "Man"]
	strategy_saved.emit({
		"run_tendency": run_scale[_run_menu.selected],
		"tempo": scale[_tempo_menu.selected],
		"passing_depth": scale[_depth_menu.selected],
		"aggression": scale[_aggression_menu.selected],
		"blitz_rate": scale[_blitz_menu.selected],
		"coverage_preference": coverage[_coverage_menu.selected],
	})


func _trinary_index(value: float) -> int:
	return 0 if value < 0.42 else (2 if value > 0.57 else 1)


func _identity_metric(label_text: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(105, 0)
	metric.add_child(UIFactory.label(value, "MetricLabel"))
	metric.add_child(UIFactory.label(label_text, "CaptionLabel"))
	return metric


func _apply_responsive_layout() -> void:
	if _settings_grid != null:
		_settings_grid.columns = 2 if size.x >= 860 else 1
