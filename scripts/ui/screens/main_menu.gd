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
	intro.add_child(UIFactory.page_heading("GRIDIRON MANAGER", "Front Office Command", "Build a club identity, control every decision, and own the season."))
	intro.add_child(UIFactory.spacer())
	intro.add_child(UIFactory.status_pill("CAREER SYSTEMS ONLINE", GridironTheme.ACCENT))
	page.add_child(intro)

	var hero := UIFactory.card("HeroPanel")
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hero)
	var hero_row := GridContainer.new()
	hero_row.columns = 2
	hero_row.add_theme_constant_override("h_separation", 30)
	hero_row.add_theme_constant_override("v_separation", 18)
	hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(hero_row)

	var hero_copy := UIFactory.vbox(14)
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.size_flags_stretch_ratio = 1.3
	hero_row.add_child(hero_copy)
	var hero_title := UIFactory.label("RUN THE FRANCHISE.", "DisplayLabel")
	hero_copy.add_child(hero_title)
	var summary := UIFactory.wrapped_label(
		"Control all 32 clubs through a complete pro football universe. Build the roster, manage the cap, shape the game plan, and create a championship standard.",
		"BodyLabel"
	)
	summary.modulate = Color(1, 1, 1, 0.84)
	hero_copy.add_child(summary)
	hero_copy.add_child(UIFactory.spacer(0, 6))
	var action_row := HFlowContainer.new()
	action_row.add_theme_constant_override("h_separation", 10)
	action_row.add_theme_constant_override("v_separation", 10)
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
	hero_copy.add_child(action_row)

	var overview := UIFactory.card("InsetPanel")
	overview.custom_minimum_size = Vector2(320, 0)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.size_flags_stretch_ratio = 0.8
	hero_row.add_child(overview)
	var overview_column := UIFactory.vbox(14)
	overview.add_child(overview_column)
	overview_column.add_child(UIFactory.label("CAREER OVERVIEW", "EyebrowLabel"))
	overview_column.add_child(_feature_row("32", "Professional clubs", "Every current team in one complete league"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("18", "Regular-season weeks", "The published 2026, 272-game schedule"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("53", "Players per roster", "Full depth, specialists, energy, and availability"))
	hero_row.resized.connect(func():
		hero_row.columns = 2 if hero_row.size.x >= 820 else 1
		hero_title.add_theme_font_size_override("font_size", 46 if hero_row.size.x >= 650 else 34)
	)

	var lower_grid := GridContainer.new()
	lower_grid.columns = 4
	lower_grid.add_theme_constant_override("h_separation", 16)
	lower_grid.add_theme_constant_override("v_separation", 16)
	lower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(lower_grid)
	lower_grid.add_child(_info_card("MATCHDAY", "Every week matters", "Call individual plays, watch the 2D field, or simulate the league slate from one shared football engine."))
	lower_grid.add_child(_info_card("PERSONNEL", "Build the depth chart", "Manage the active roster, reserve lists, development, contracts, trades, and the complete player market."))
	lower_grid.add_child(_info_card("FRONT OFFICE", "Think in seasons", "Navigate yearly cap charges, free agency, scouting, the draft, retirements, and long-term club building."))
	lower_grid.add_child(_info_card("LEAGUE WORLD", "Every result lives on", "Track complete player and team statistics, histories, game books, standings, and career milestones."))
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
