extends Control

signal exit_requested
signal rematch_requested
signal career_game_finished

var _simulator: FootballSimulator
var _user_team: TeamData
var _career_mode := false
var _away_score: Label
var _home_score: Label
var _clock_label: Label
var _quarter_label: Label
var _situation_label: Label
var _possession_label: Label
var _field: FieldVisual
var _last_play_title: Label
var _last_play_description: Label
var _feed_list: VBoxContainer
var _metrics_row: HBoxContainer
var _next_button: Button
var _drive_button: Button
var _finish_button: Button
var _rematch_button: Button
var _return_button: Button
var _final_label: Label
var _body_grid: GridContainer


func setup(simulator: FootballSimulator, user_team: TeamData, career_mode: bool = false) -> void:
	_simulator = simulator
	_user_team = user_team
	_career_mode = career_mode


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_refresh()


func _build_interface() -> void:
	var outer_scroll := ScrollContainer.new()
	outer_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(outer_scroll)
	var page := UIFactory.vbox(14)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 690)
	outer_scroll.add_child(page)

	var context := UIFactory.hbox(10)
	context.add_child(UIFactory.label("LIVE MATCH CENTER", "EyebrowLabel"))
	context.add_child(UIFactory.label("  /  ", "CaptionLabel"))
	context.add_child(UIFactory.label("2026 GRIDIRON LEAGUE · MATCHDAY", "CaptionLabel"))
	context.add_child(UIFactory.spacer())
	_final_label = UIFactory.label("GAME IN PROGRESS", "EyebrowLabel")
	context.add_child(_final_label)
	page.add_child(context)

	var scoreboard := UIFactory.card("RaisedCardPanel")
	page.add_child(scoreboard)
	var score_row := UIFactory.hbox(20)
	scoreboard.add_child(score_row)
	score_row.add_child(_build_team_score(_simulator.state.away_team, false))

	var clock_block := UIFactory.vbox(0)
	clock_block.custom_minimum_size = Vector2(230, 0)
	clock_block.alignment = BoxContainer.ALIGNMENT_CENTER
	_quarter_label = UIFactory.label("Q1", "EyebrowLabel")
	_quarter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_block.add_child(_quarter_label)
	_clock_label = UIFactory.label("15:00", "MetricLabel")
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_block.add_child(_clock_label)
	_situation_label = UIFactory.label("1st & 10", "BodyLabel")
	_situation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_block.add_child(_situation_label)
	_possession_label = UIFactory.label("", "CaptionLabel")
	_possession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_block.add_child(_possession_label)
	score_row.add_child(clock_block)
	score_row.add_child(_build_team_score(_simulator.state.home_team, true))

	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 16)
	_body_grid.add_theme_constant_override("v_separation", 16)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(_body_grid)

	var match_column := UIFactory.vbox(12)
	match_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match_column.size_flags_stretch_ratio = 1.7
	_body_grid.add_child(match_column)
	var field_card := UIFactory.card()
	field_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	match_column.add_child(field_card)
	var field_column := UIFactory.vbox(8)
	field_card.add_child(field_column)
	var field_header := UIFactory.hbox(8)
	field_header.add_child(UIFactory.label("FIELD POSITION", "SectionTitleLabel"))
	field_header.add_child(UIFactory.spacer())
	field_header.add_child(UIFactory.label("GOLD: LINE TO GAIN", "CaptionLabel"))
	field_header.add_child(UIFactory.label("  BLUE: SCRIMMAGE", "CaptionLabel"))
	field_column.add_child(field_header)
	_field = FieldVisual.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	field_column.add_child(_field)

	var last_play := UIFactory.card("AccentPanel")
	match_column.add_child(last_play)
	var last_play_row := UIFactory.hbox(14)
	last_play.add_child(last_play_row)
	_last_play_title = UIFactory.label("Kickoff ready", "SectionTitleLabel")
	_last_play_title.custom_minimum_size = Vector2(150, 0)
	last_play_row.add_child(_last_play_title)
	_last_play_description = UIFactory.wrapped_label(
		"The captains are at midfield. Advance one snap, a full drive, or the entire game.",
		"MutedLabel"
	)
	_last_play_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_play_row.add_child(_last_play_description)

	_metrics_row = UIFactory.hbox(10)
	match_column.add_child(_metrics_row)

	var feed_card := UIFactory.card()
	feed_card.custom_minimum_size = Vector2(300, 300)
	feed_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_card.size_flags_stretch_ratio = 0.82
	_body_grid.add_child(feed_card)
	var feed_column := UIFactory.vbox(10)
	feed_card.add_child(feed_column)
	var feed_header := UIFactory.hbox(8)
	feed_header.add_child(UIFactory.label("PLAY-BY-PLAY", "SectionTitleLabel"))
	feed_header.add_child(UIFactory.spacer())
	feed_header.add_child(UIFactory.badge("LIVE", GridironTheme.DANGER))
	feed_column.add_child(feed_header)
	feed_column.add_child(UIFactory.label("Newest events appear first", "CaptionLabel"))
	var feed_scroll := ScrollContainer.new()
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	feed_column.add_child(feed_scroll)
	_feed_list = UIFactory.vbox(7)
	_feed_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_scroll.add_child(_feed_list)

	var controls := UIFactory.hbox(10)
	var exit_button := UIFactory.button("←  EXIT MATCH", "GhostButton")
	exit_button.visible = not _career_mode
	exit_button.pressed.connect(func(): exit_requested.emit())
	controls.add_child(exit_button)
	controls.add_child(UIFactory.spacer())
	_return_button = UIFactory.button("RETURN TO CAREER", "PrimaryButton")
	_return_button.visible = false
	_return_button.pressed.connect(func(): career_game_finished.emit())
	controls.add_child(_return_button)
	_rematch_button = UIFactory.button("NEW REMATCH", "SecondaryButton")
	_rematch_button.visible = false
	_rematch_button.pressed.connect(func(): rematch_requested.emit())
	controls.add_child(_rematch_button)
	_next_button = UIFactory.button("NEXT PLAY", "SecondaryButton")
	_next_button.pressed.connect(_simulate_play)
	controls.add_child(_next_button)
	_drive_button = UIFactory.button("SIMULATE DRIVE", "SecondaryButton")
	_drive_button.pressed.connect(_simulate_drive)
	controls.add_child(_drive_button)
	_finish_button = UIFactory.button("FINISH GAME  →", "PrimaryButton")
	_finish_button.custom_minimum_size = Vector2(170, 44)
	_finish_button.pressed.connect(_finish_game)
	controls.add_child(_finish_button)
	page.add_child(controls)


func _build_team_score(team: TeamData, align_right: bool) -> HBoxContainer:
	var block := UIFactory.hbox(12)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var location := UIFactory.label(team.city.to_upper(), "CaptionLabel")
	var nickname := UIFactory.label(team.nickname, "SectionTitleLabel")
	var score := UIFactory.label("0", "ScoreLabel")
	if align_right:
		location.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		nickname.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		block.add_child(identity)
		block.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
		block.add_child(score)
		_home_score = score
	else:
		score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		block.add_child(score)
		block.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
		block.add_child(identity)
		_away_score = score
	identity.add_child(location)
	identity.add_child(nickname)
	return block


func _simulate_play() -> void:
	_simulator.simulate_next_play()
	_refresh()


func _simulate_drive() -> void:
	_simulator.simulate_drive()
	_refresh()


func _finish_game() -> void:
	_simulator.simulate_to_end()
	_refresh()


func _refresh() -> void:
	var state := _simulator.state
	_away_score.text = str(state.away_score)
	_home_score.text = str(state.home_score)
	_quarter_label.text = state.quarter_label()
	_clock_label.text = "--:--" if state.is_final else state.game_clock_label()
	_situation_label.text = state.down_and_distance_label()
	_possession_label.text = "%s BALL · %s" % [state.offense().abbreviation, state.field_position_label()]
	_field.set_game_state(state)

	if not state.play_history.is_empty():
		var latest: PlayResult = state.play_history.back()
		_last_play_title.text = latest.title.to_upper()
		_last_play_description.text = latest.description
	_rebuild_feed()
	_rebuild_metrics()

	var controls_enabled := not state.is_final
	_next_button.disabled = not controls_enabled
	_drive_button.disabled = not controls_enabled
	_finish_button.disabled = not controls_enabled
	_rematch_button.visible = state.is_final and not _career_mode
	_return_button.visible = state.is_final and _career_mode
	_final_label.text = "FINAL" if state.is_final else "GAME IN PROGRESS"
	_final_label.modulate = GridironTheme.WARM if state.is_final else Color.WHITE
	if state.is_final:
		_last_play_title.text = "FINAL"
		_last_play_description.text = _final_summary()


func _apply_responsive_layout() -> void:
	if _body_grid != null:
		_body_grid.columns = 2 if size.x >= 980 else 1


func _rebuild_feed() -> void:
	for child in _feed_list.get_children():
		_feed_list.remove_child(child)
		child.queue_free()
	var history := _simulator.state.play_history
	if history.is_empty():
		var ready := UIFactory.card("InsetPanel")
		ready.add_child(UIFactory.wrapped_label("Opening kickoff awaiting simulation.", "MutedLabel"))
		_feed_list.add_child(ready)
		return
	var first_index := maxi(history.size() - 30, 0)
	for index in range(history.size() - 1, first_index - 1, -1):
		_feed_list.add_child(_play_feed_row(history[index]))


func _play_feed_row(play: PlayResult) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	if play.scoring_play:
		var scoring_style := StyleBoxFlat.new()
		scoring_style.bg_color = Color(GridironTheme.ACCENT, 0.10)
		scoring_style.border_color = Color(GridironTheme.ACCENT, 0.30)
		scoring_style.set_border_width_all(1)
		scoring_style.corner_radius_top_left = 8
		scoring_style.corner_radius_top_right = 8
		scoring_style.corner_radius_bottom_left = 8
		scoring_style.corner_radius_bottom_right = 8
		scoring_style.content_margin_left = 12
		scoring_style.content_margin_right = 12
		scoring_style.content_margin_top = 10
		scoring_style.content_margin_bottom = 10
		panel.add_theme_stylebox_override("panel", scoring_style)
	var column := UIFactory.vbox(3)
	panel.add_child(column)
	var meta := UIFactory.hbox(6)
	meta.add_child(UIFactory.label("%s · %s" % [play.quarter_label(), play.clock_label()], "CaptionLabel"))
	meta.add_child(UIFactory.spacer())
	meta.add_child(UIFactory.label(play.title.to_upper(), "EyebrowLabel"))
	column.add_child(meta)
	column.add_child(UIFactory.wrapped_label(play.description, "MutedLabel"))
	return panel


func _rebuild_metrics() -> void:
	for child in _metrics_row.get_children():
		_metrics_row.remove_child(child)
		child.queue_free()
	var state := _simulator.state
	_metrics_row.add_child(_metric_card("TOTAL YARDS", "total_yards", state))
	_metrics_row.add_child(_metric_card("PASS", "pass_yards", state))
	_metrics_row.add_child(_metric_card("RUSH", "rush_yards", state))
	_metrics_row.add_child(_metric_card("TURNOVERS", "turnovers", state))


func _metric_card(title: String, key: String, state: GameStateData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(3)
	panel.add_child(column)
	var title_label := UIFactory.label(title, "CaptionLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title_label)
	var numbers := UIFactory.label(
		"%d   —   %d" % [state.stats[state.away_team.id][key], state.stats[state.home_team.id][key]],
		"BodyLabel"
	)
	numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(numbers)
	var teams := UIFactory.label("%s         %s" % [state.away_team.abbreviation, state.home_team.abbreviation], "CaptionLabel")
	teams.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(teams)
	return panel


func _final_summary() -> String:
	var state := _simulator.state
	if state.away_score == state.home_score:
		return "%s and %s finish level at %d." % [state.away_team.display_name(), state.home_team.display_name(), state.home_score]
	var winner := state.away_team if state.away_score > state.home_score else state.home_team
	return "%s wins %d–%d after %d simulated plays." % [winner.display_name(), maxi(state.away_score, state.home_score), mini(state.away_score, state.home_score), state.play_count]
