extends Control

signal back_requested
signal game_requested(team: TeamData, opponent: TeamData, strategy: Dictionary)

var _teams: Array[TeamData] = []
var _selected_index := 0
var _team_buttons: Array[Button] = []
var _team_button_group := ButtonGroup.new()
var _details_host: Control
var _opponent_menu: OptionButton
var _offense_menu: OptionButton
var _aggression_menu: OptionButton
var _start_button: Button


func setup(teams: Array[TeamData]) -> void:
	_teams = teams


func _ready() -> void:
	_build_interface()
	if not _teams.is_empty():
		_select_team(0)


func _build_interface() -> void:
	var page := UIFactory.vbox(16)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var heading := UIFactory.hbox(12)
	var heading_copy := UIFactory.vbox(2)
	heading_copy.add_child(UIFactory.label("CHOOSE YOUR CLUB", "PageTitleLabel"))
	heading_copy.add_child(UIFactory.label("Compare personnel, appoint your opponent, and set the game plan.", "MutedLabel"))
	heading.add_child(heading_copy)
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.badge("EXHIBITION", GridironTheme.WARM))
	page.add_child(heading)

	var body := UIFactory.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	var team_panel := UIFactory.card()
	team_panel.custom_minimum_size = Vector2(318, 0)
	body.add_child(team_panel)
	var team_column := UIFactory.vbox(10)
	team_panel.add_child(team_column)
	team_column.add_child(UIFactory.label("AVAILABLE CLUBS", "EyebrowLabel"))
	team_column.add_child(UIFactory.label("Prototype League", "SectionTitleLabel"))
	team_column.add_child(UIFactory.label("Four distinct roster philosophies", "CaptionLabel"))
	team_column.add_child(UIFactory.spacer(0, 4))
	for index in range(_teams.size()):
		var team := _teams[index]
		var team_button := UIFactory.button(
			"%s\n%s  ·  OVR %d" % [team.display_name(), team.conference.to_upper(), team.overall_rating()],
			"TeamCardButton"
		)
		team_button.custom_minimum_size = Vector2(0, 74)
		team_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		team_button.toggle_mode = true
		team_button.button_group = _team_button_group
		team_button.pressed.connect(_select_team.bind(index))
		_team_buttons.append(team_button)
		team_column.add_child(team_button)

	_details_host = Control.new()
	_details_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_details_host)

	var footer := UIFactory.hbox(12)
	var back_button := UIFactory.button("←  BACK", "GhostButton")
	back_button.pressed.connect(func(): back_requested.emit())
	footer.add_child(back_button)
	footer.add_child(UIFactory.spacer())
	_start_button = UIFactory.button("START EXHIBITION  →", "PrimaryButton")
	_start_button.custom_minimum_size = Vector2(220, 48)
	_start_button.pressed.connect(_start_game)
	footer.add_child(_start_button)
	page.add_child(footer)


func _select_team(index: int) -> void:
	if _teams.is_empty():
		return
	_selected_index = clampi(index, 0, _teams.size() - 1)
	for button_index in range(_team_buttons.size()):
		_team_buttons[button_index].button_pressed = button_index == _selected_index
	_rebuild_details()


func _rebuild_details() -> void:
	for child in _details_host.get_children():
		_details_host.remove_child(child)
		child.queue_free()

	var team := _teams[_selected_index]
	var details := UIFactory.vbox(16)
	details.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_details_host.add_child(details)

	var overview := UIFactory.card("RaisedCardPanel")
	details.add_child(overview)
	var overview_column := UIFactory.vbox(14)
	overview.add_child(overview_column)
	var identity := UIFactory.hbox(14)
	identity.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	var identity_copy := UIFactory.vbox(2)
	identity_copy.add_child(UIFactory.label(team.display_name(), "PageTitleLabel"))
	identity_copy.add_child(UIFactory.label("%s Conference  ·  Prototype roster" % team.conference, "MutedLabel"))
	identity.add_child(identity_copy)
	identity.add_child(UIFactory.spacer())
	var overall := UIFactory.vbox(0)
	var overall_number := UIFactory.label(str(team.overall_rating()), "MetricLabel")
	overall_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overall.add_child(overall_number)
	var overall_label := UIFactory.label("OVERALL", "CaptionLabel")
	overall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	overall.add_child(overall_label)
	identity.add_child(overall)
	overview_column.add_child(identity)

	var ratings := GridContainer.new()
	ratings.columns = 3
	ratings.add_theme_constant_override("h_separation", 18)
	ratings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var offense_bar := UIFactory.stat_bar("OFFENSE", team.offense_rating, team.primary_color)
	offense_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings.add_child(offense_bar)
	var defense_bar := UIFactory.stat_bar("DEFENSE", team.defense_rating, team.primary_color)
	defense_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings.add_child(defense_bar)
	var special_bar := UIFactory.stat_bar("SPECIAL TEAMS", team.special_teams_rating, team.primary_color)
	special_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ratings.add_child(special_bar)
	overview_column.add_child(ratings)

	var lower := UIFactory.hbox(16)
	lower.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(lower)
	lower.add_child(_build_roster_card(team))
	lower.add_child(_build_plan_card(team))


func _build_roster_card(team: TeamData) -> PanelContainer:
	var roster_card := UIFactory.card()
	roster_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_card.size_flags_stretch_ratio = 1.35
	var roster_column := UIFactory.vbox(10)
	roster_card.add_child(roster_column)
	var title_row := UIFactory.hbox(8)
	title_row.add_child(UIFactory.label("KEY PERSONNEL", "SectionTitleLabel"))
	title_row.add_child(UIFactory.spacer())
	title_row.add_child(UIFactory.label("OVR", "CaptionLabel"))
	roster_column.add_child(title_row)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_column.add_child(scroll)
	var player_list := UIFactory.vbox(4)
	player_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(player_list)
	for player in team.players:
		player_list.add_child(_player_row(player, team.primary_color))
	return roster_card


func _player_row(player: PlayerData, color: Color) -> PanelContainer:
	var row_panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(10)
	row_panel.add_child(row)
	row.add_child(UIFactory.badge(player.position, color))
	var copy := UIFactory.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	copy.add_child(UIFactory.label("Age %d  ·  AWR %d  ·  TEC %d" % [player.age, player.awareness, player.technique], "CaptionLabel"))
	row.add_child(copy)
	var rating := UIFactory.label(str(player.overall), "MetricLabel")
	rating.modulate = _rating_color(player.overall)
	rating.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rating)
	return row_panel


func _build_plan_card(team: TeamData) -> PanelContainer:
	var plan_card := UIFactory.card()
	plan_card.custom_minimum_size = Vector2(330, 0)
	plan_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_card.size_flags_stretch_ratio = 0.85
	var plan := UIFactory.vbox(10)
	plan_card.add_child(plan)
	plan.add_child(UIFactory.label("GAME PLAN", "SectionTitleLabel"))
	plan.add_child(UIFactory.label("High-level tendencies guide the play caller.", "CaptionLabel"))
	plan.add_child(UIFactory.spacer(0, 4))
	plan.add_child(UIFactory.label("OPPONENT", "EyebrowLabel"))
	_opponent_menu = OptionButton.new()
	_opponent_menu.custom_minimum_size = Vector2(0, 44)
	for candidate in _teams:
		if candidate.id == team.id:
			continue
		_opponent_menu.add_item(candidate.display_name())
		_opponent_menu.set_item_metadata(_opponent_menu.item_count - 1, candidate.id)
	plan.add_child(_opponent_menu)
	plan.add_child(UIFactory.label("OFFENSIVE IDENTITY", "EyebrowLabel"))
	_offense_menu = OptionButton.new()
	_offense_menu.custom_minimum_size = Vector2(0, 44)
	_offense_menu.add_item("Balanced")
	_offense_menu.add_item("Ground control")
	_offense_menu.add_item("Air attack")
	if team.run_tendency >= 0.54:
		_offense_menu.select(1)
	elif team.run_tendency <= 0.40:
		_offense_menu.select(2)
	plan.add_child(_offense_menu)
	plan.add_child(UIFactory.label("DECISION PROFILE", "EyebrowLabel"))
	_aggression_menu = OptionButton.new()
	_aggression_menu.custom_minimum_size = Vector2(0, 44)
	_aggression_menu.add_item("Conservative")
	_aggression_menu.add_item("Balanced")
	_aggression_menu.add_item("Aggressive")
	_aggression_menu.select(2 if team.aggression >= 0.58 else 1)
	plan.add_child(_aggression_menu)
	plan.add_child(UIFactory.spacer())
	plan.add_child(UIFactory.wrapped_label(
		"These settings affect play selection, risk, and fourth-down decisions throughout the simulation.",
		"CaptionLabel"
	))
	return plan_card


func _start_game() -> void:
	if _teams.is_empty() or _opponent_menu.item_count == 0:
		return
	var opponent_id := str(_opponent_menu.get_item_metadata(_opponent_menu.selected))
	var opponent: TeamData
	for candidate in _teams:
		if candidate.id == opponent_id:
			opponent = candidate
			break
	if opponent == null:
		return
	var run_tendencies := [0.46, 0.60, 0.32]
	var aggression_values := [0.34, 0.50, 0.70]
	var strategy := {
		"run_tendency": run_tendencies[_offense_menu.selected],
		"aggression": aggression_values[_aggression_menu.selected],
	}
	game_requested.emit(_teams[_selected_index], opponent, strategy)


func _rating_color(value: int) -> Color:
	if value >= 86:
		return GridironTheme.ACCENT
	if value >= 80:
		return Color("79c8ff")
	if value >= 75:
		return GridironTheme.WARM
	return GridironTheme.TEXT_MUTED
