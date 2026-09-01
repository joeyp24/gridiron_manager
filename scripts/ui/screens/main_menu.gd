extends Control

signal new_career_requested
signal continue_career_requested
signal exhibition_requested

var _has_save := false


func setup(has_save: bool) -> void:
	_has_save = has_save


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(18)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 660)
	scroll.add_child(page)

	var intro := UIFactory.hbox(12)
	intro.add_child(UIFactory.label("FRONT OFFICE", "EyebrowLabel"))
	intro.add_child(UIFactory.label("  /  ", "CaptionLabel"))
	intro.add_child(UIFactory.label("2026 GRIDIRON LEAGUE", "CaptionLabel"))
	intro.add_child(UIFactory.spacer())
	intro.add_child(UIFactory.badge("CAREER SYSTEMS ONLINE", GridironTheme.ACCENT))
	page.add_child(intro)

	var hero := UIFactory.card("AccentPanel")
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hero)
	var hero_row := UIFactory.hbox(32)
	hero.add_child(hero_row)

	var hero_copy := UIFactory.vbox(14)
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.size_flags_stretch_ratio = 1.3
	hero_row.add_child(hero_copy)
	hero_copy.add_child(UIFactory.label("BUILD THE STANDARD.", "DisplayLabel"))
	var summary := UIFactory.wrapped_label(
		"Take control of a club across a complete season. Set your depth chart, establish a tactical identity, navigate injuries, and chase the championship.",
		"BodyLabel"
	)
	summary.modulate = Color(1, 1, 1, 0.84)
	hero_copy.add_child(summary)
	hero_copy.add_child(UIFactory.spacer(0, 6))
	var action_row := UIFactory.hbox(10)
	var primary_text := "CONTINUE CAREER" if _has_save else "START NEW CAREER"
	var primary_action := UIFactory.button(primary_text, "PrimaryButton")
	primary_action.custom_minimum_size = Vector2(210, 48)
	if _has_save:
		primary_action.pressed.connect(func(): continue_career_requested.emit())
	else:
		primary_action.pressed.connect(func(): new_career_requested.emit())
	action_row.add_child(primary_action)
	if _has_save:
		var new_career := UIFactory.button("NEW CAREER", "SecondaryButton")
		new_career.pressed.connect(func(): new_career_requested.emit())
		action_row.add_child(new_career)
	var exhibition := UIFactory.button("QUICK EXHIBITION", "GhostButton")
	exhibition.pressed.connect(func(): exhibition_requested.emit())
	action_row.add_child(exhibition)
	action_row.add_child(UIFactory.spacer())
	hero_copy.add_child(action_row)

	var overview := UIFactory.card("InsetPanel")
	overview.custom_minimum_size = Vector2(320, 0)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.size_flags_stretch_ratio = 0.8
	hero_row.add_child(overview)
	var overview_column := UIFactory.vbox(14)
	overview.add_child(overview_column)
	overview_column.add_child(UIFactory.label("CAREER OVERVIEW", "EyebrowLabel"))
	overview_column.add_child(_feature_row("02", "League databases", "Original clubs or an nflverse real-data preview"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("07", "Regular-season weeks", "Every club plays every opponent"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("41", "Players per roster", "Depth, energy, and availability"))

	var lower_grid := GridContainer.new()
	lower_grid.columns = 4
	lower_grid.add_theme_constant_override("h_separation", 16)
	lower_grid.add_theme_constant_override("v_separation", 16)
	lower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(lower_grid)
	lower_grid.add_child(_info_card("SEASON MODE", "Every week matters", "Play your matchup or simulate the slate, then track the standings and the championship race."))
	lower_grid.add_child(_info_card("ROSTER CONTROL", "Build the depth chart", "Order starters and backups, manage active status, and respond when injuries change the plan."))
	lower_grid.add_child(_info_card("FRONT OFFICE", "Build within the cap", "Negotiate contracts, sign free agents, release players, and follow every league transaction."))
	lower_grid.add_child(_info_card("PERSISTENT CAREER", "Continue where you left off", "Versioned saves preserve results, tactics, contracts, cap state, transactions, fatigue, and injuries."))
	resized.connect(func(): lower_grid.columns = 4 if size.x >= 1180 else (2 if size.x >= 720 else 1))


func _feature_row(metric: String, title: String, detail: String) -> HBoxContainer:
	var row := UIFactory.hbox(14)
	var number := UIFactory.label(metric, "MetricLabel")
	number.custom_minimum_size = Vector2(48, 0)
	row.add_child(number)
	var copy := UIFactory.vbox(2)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label(title, "BodyLabel"))
	copy.add_child(UIFactory.label(detail, "CaptionLabel"))
	row.add_child(copy)
	return row


func _info_card(eyebrow: String, title: String, body: String) -> PanelContainer:
	var panel := UIFactory.card()
	panel.custom_minimum_size = Vector2(250, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	panel.add_child(column)
	column.add_child(UIFactory.label(eyebrow, "EyebrowLabel"))
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.wrapped_label(body, "MutedLabel"))
	return panel
