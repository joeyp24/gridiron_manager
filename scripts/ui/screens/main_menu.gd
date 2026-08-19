extends Control

signal new_exhibition_requested


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var page := UIFactory.vbox(18)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var intro := UIFactory.hbox(12)
	intro.add_child(UIFactory.label("FRONT OFFICE", "EyebrowLabel"))
	intro.add_child(UIFactory.label("  /  ", "CaptionLabel"))
	intro.add_child(UIFactory.label("WEDNESDAY, PRESEASON WEEK 1", "CaptionLabel"))
	intro.add_child(UIFactory.spacer())
	intro.add_child(UIFactory.badge("SYSTEMS ONLINE", GridironTheme.ACCENT))
	page.add_child(intro)

	var hero := UIFactory.card("AccentPanel")
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(hero)
	var hero_row := UIFactory.hbox(36)
	hero.add_child(hero_row)

	var hero_copy := UIFactory.vbox(14)
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_copy.size_flags_stretch_ratio = 1.35
	hero_row.add_child(hero_copy)
	hero_copy.add_child(UIFactory.label("BUILD THE STANDARD.", "DisplayLabel"))
	var summary := UIFactory.wrapped_label(
		"Take control of a football organization where every roster decision, tactical adjustment, and fourth-down call shapes the result.",
		"BodyLabel"
	)
	summary.custom_minimum_size = Vector2(460, 0)
	summary.modulate = Color(1, 1, 1, 0.84)
	hero_copy.add_child(summary)
	hero_copy.add_child(UIFactory.spacer(0, 6))
	var primary_action := UIFactory.button("START EXHIBITION", "PrimaryButton")
	primary_action.custom_minimum_size = Vector2(220, 48)
	primary_action.pressed.connect(func(): new_exhibition_requested.emit())
	var action_row := UIFactory.hbox(12)
	action_row.add_child(primary_action)
	var build_note := UIFactory.label("Playable vertical slice", "MutedLabel")
	build_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_row.add_child(build_note)
	action_row.add_child(UIFactory.spacer())
	hero_copy.add_child(action_row)

	var overview := UIFactory.card("InsetPanel")
	overview.custom_minimum_size = Vector2(350, 0)
	overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overview.size_flags_stretch_ratio = 0.85
	hero_row.add_child(overview)
	var overview_column := UIFactory.vbox(16)
	overview.add_child(overview_column)
	overview_column.add_child(UIFactory.label("PROTOTYPE OVERVIEW", "EyebrowLabel"))
	overview_column.add_child(_feature_row("04", "Fictional clubs", "Distinct rosters and identities"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("60", "Minute simulation", "Full regulation game clock"))
	overview_column.add_child(UIFactory.divider())
	overview_column.add_child(_feature_row("01", "Decision loop", "Plan, simulate, review"))

	var lower_grid := UIFactory.hbox(18)
	page.add_child(lower_grid)
	lower_grid.add_child(_info_card(
		"MATCH ENGINE",
		"Every snap has context",
		"Ratings, field position, down-and-distance, score, and tactical intent all influence outcomes.",
		"SEE THE STATE"
	))
	lower_grid.add_child(_info_card(
		"TEAM IDENTITY",
		"Choose how you win",
		"Compare club strengths, inspect key players, and set your offensive balance before kickoff.",
		"SET THE PLAN"
	))
	lower_grid.add_child(_info_card(
		"BUILT TO GROW",
		"A foundation for careers",
		"The league, simulation, and interface layers are separated for progressive expansion.",
		"EXTENSIBLE CORE"
	))


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


func _info_card(eyebrow: String, title: String, body: String, footer: String) -> PanelContainer:
	var panel := UIFactory.card()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(10)
	panel.add_child(column)
	column.add_child(UIFactory.label(eyebrow, "EyebrowLabel"))
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	var description := UIFactory.wrapped_label(body, "MutedLabel")
	description.custom_minimum_size = Vector2(0, 44)
	column.add_child(description)
	column.add_child(UIFactory.spacer(0, 4))
	column.add_child(UIFactory.label(footer + "  →", "CaptionLabel"))
	return panel
