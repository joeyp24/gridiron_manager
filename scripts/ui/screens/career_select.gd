extends Control

signal back_requested
signal career_requested(source_id: String, team_id: String, career_mode: String)

var _teams: Array[TeamData] = []
var _sources: Array[Dictionary] = []
var _selected_source_id := LeagueCatalog.SOURCE_NFLVERSE_FULL
var _selected_index := 0
var _selected_career_mode := LeagueState.CAREER_MODE_STANDARD
var _team_grid: GridContainer
var _details_host: VBoxContainer
var _source_selector: OptionButton
var _source_description: Label
var _mode_selector: OptionButton
var _mode_description: Label
var _team_buttons: Array[Button] = []
var _button_group := ButtonGroup.new()


func setup() -> void:
	_sources = LeagueCatalog.source_descriptors()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_select_source(0)


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(18)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 760)
	scroll.add_child(page)

	var heading := UIFactory.hbox(12)
	var copy := UIFactory.page_heading("CAREER SETUP", "Choose Your Club", "Select one of 32 clubs to lead through the 2026 season and beyond.")
	heading.add_child(copy)
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.status_pill("2026 SEASON", GridironTheme.ACCENT))
	page.add_child(heading)

	var source_card := UIFactory.card("RaisedCardPanel")
	var source_row := UIFactory.hbox(14)
	source_card.add_child(source_row)
	var source_copy := UIFactory.vbox(2)
	source_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_copy.add_child(UIFactory.label("LEAGUE DATABASE", "EyebrowLabel"))
	_source_description = UIFactory.wrapped_label("", "MutedLabel")
	source_copy.add_child(_source_description)
	source_row.add_child(source_copy)
	_source_selector = OptionButton.new()
	_source_selector.custom_minimum_size = Vector2(250, 44)
	for source in _sources:
		_source_selector.add_item(str(source.get("label", "LEAGUE")))
	_source_selector.item_selected.connect(_select_source)
	source_row.add_child(_source_selector)
	page.add_child(source_card)

	var mode_card := UIFactory.card("RaisedCardPanel")
	var mode_row := UIFactory.hbox(14)
	mode_card.add_child(mode_row)
	var mode_copy := UIFactory.vbox(2)
	mode_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_copy.add_child(UIFactory.label("CAREER FORMAT", "EyebrowLabel"))
	_mode_description = UIFactory.wrapped_label("Use the authentic opening rosters and begin at Week 1.", "MutedLabel")
	mode_copy.add_child(_mode_description)
	mode_row.add_child(mode_copy)
	_mode_selector = OptionButton.new()
	_mode_selector.custom_minimum_size = Vector2(250, 44)
	_mode_selector.add_item("STANDARD ROSTERS")
	_mode_selector.add_item("FANTASY DRAFT")
	_mode_selector.item_selected.connect(_select_career_mode)
	mode_row.add_child(_mode_selector)
	page.add_child(mode_card)

	_team_grid = GridContainer.new()
	_team_grid.columns = 4
	_team_grid.add_theme_constant_override("h_separation", 12)
	_team_grid.add_theme_constant_override("v_separation", 12)
	_team_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_team_grid)

	var details_card := UIFactory.card("RaisedCardPanel")
	details_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(details_card)
	_details_host = UIFactory.vbox(14)
	details_card.add_child(_details_host)

	var actions := UIFactory.hbox(10)
	var back := UIFactory.button("←  BACK", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	actions.add_child(back)
	actions.add_child(UIFactory.spacer())
	var begin := UIFactory.button("BEGIN CAREER  →", "PrimaryButton")
	begin.custom_minimum_size = Vector2(200, 48)
	begin.pressed.connect(func():
		if not _teams.is_empty():
			career_requested.emit(_selected_source_id, _teams[_selected_index].id, _selected_career_mode)
	)
	actions.add_child(begin)
	page.add_child(actions)


func _select_source(index: int) -> void:
	if _sources.is_empty():
		return
	var source: Dictionary = _sources[clampi(index, 0, _sources.size() - 1)]
	_selected_source_id = str(source.get("id", LeagueCatalog.SOURCE_NFLVERSE_FULL))
	_source_description.text = "%s — %s" % [str(source.get("title", "")), str(source.get("description", ""))]
	var bundle := LeagueCatalog.create_bundle(_selected_source_id)
	_teams.clear()
	for team in bundle.get("teams", []):
		_teams.append(team)
	_rebuild_team_grid()
	if not _teams.is_empty():
		_select_team(0)


func _select_career_mode(index: int) -> void:
	_selected_career_mode = LeagueState.CAREER_MODE_FANTASY_DRAFT if index == 1 else LeagueState.CAREER_MODE_STANDARD
	_mode_description.text = (
		"Randomize a 32-team snake order, draft complete 53-player rosters, and begin the normal season."
		if _selected_career_mode == LeagueState.CAREER_MODE_FANTASY_DRAFT
		else "Use the authentic opening rosters and begin at Week 1."
	)


func _rebuild_team_grid() -> void:
	for child in _team_grid.get_children():
		_team_grid.remove_child(child)
		child.queue_free()
	_team_buttons.clear()
	_button_group = ButtonGroup.new()
	for index in range(_teams.size()):
		var team := _teams[index]
		var location := team.division if not team.division.is_empty() else team.conference.to_upper()
		var button := UIFactory.button(
			"%s\n%s · %s · OVR %d" % [team.display_name(), team.abbreviation, location, team.overall_rating()],
			"TeamCardButton"
		)
		button.custom_minimum_size = Vector2(225, 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _button_group
		button.pressed.connect(_select_team.bind(index))
		_team_buttons.append(button)
		_team_grid.add_child(button)


func _select_team(index: int) -> void:
	_selected_index = clampi(index, 0, _teams.size() - 1)
	for button_index in range(_team_buttons.size()):
		_team_buttons[button_index].button_pressed = button_index == _selected_index
	_rebuild_details()


func _rebuild_details() -> void:
	for child in _details_host.get_children():
		_details_host.remove_child(child)
		child.queue_free()
	var team := _teams[_selected_index]
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.add_child(UIFactory.label(team.display_name(), "SectionTitleLabel"))
	var competition := "%s · %s" % [team.conference, team.division] if not team.division.is_empty() else "%s Conference" % team.conference
	identity.add_child(UIFactory.label("%s · %d-player roster" % [competition, team.players.size()], "CaptionLabel"))
	header.add_child(identity)
	header.add_child(UIFactory.spacer())
	header.add_child(UIFactory.label(str(team.overall_rating()), "MetricLabel"))
	_details_host.add_child(header)
	var ratings := GridContainer.new()
	ratings.columns = 3
	ratings.add_theme_constant_override("h_separation", 20)
	ratings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for entry in [
		["OFFENSE", team.effective_offense_rating()],
		["DEFENSE", team.effective_defense_rating()],
		["SPECIAL TEAMS", team.effective_special_teams_rating()],
	]:
		var bar := UIFactory.stat_bar(entry[0], entry[1], team.primary_color)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ratings.add_child(bar)
	_details_host.add_child(ratings)
	var summary := UIFactory.hbox(18)
	summary.add_child(_profile_metric("OFFENSIVE IDENTITY", _offense_label(team.run_tendency)))
	summary.add_child(_profile_metric("DECISION PROFILE", _aggression_label(team.aggression)))
	summary.add_child(_profile_metric("AVAILABLE PLAYERS", str(team.active_roster_count())))
	summary.add_child(_profile_metric("STARTING QB", team.player_at("QB").full_name))
	_details_host.add_child(summary)


func _profile_metric(title: String, value: String) -> VBoxContainer:
	var column := UIFactory.vbox(2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	column.add_child(UIFactory.label(value, "BodyLabel"))
	return column


func _offense_label(value: float) -> String:
	if value >= 0.55:
		return "Ground control"
	if value <= 0.40:
		return "Air attack"
	return "Balanced"


func _aggression_label(value: float) -> String:
	if value >= 0.60:
		return "Aggressive"
	if value <= 0.40:
		return "Conservative"
	return "Balanced"


func _apply_responsive_layout() -> void:
	if _team_grid == null:
		return
	if size.x >= 1220:
		_team_grid.columns = 4
	elif size.x >= 760:
		_team_grid.columns = 2
	else:
		_team_grid.columns = 1
