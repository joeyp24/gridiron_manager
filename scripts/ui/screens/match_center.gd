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
var _field_legend: Label
var _presentation_enabled := true
var _presentation_toggle: Button
var _animation_status: Label
var _animation_progress: ProgressBar
var _pause_button: Button
var _replay_button: Button
var _skip_button: Button
var _speed_menu: OptionButton
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
var _call_sheet_card: PanelContainer
var _call_sheet_title: Label
var _call_sheet_context: Label
var _call_sheet_status: Label
var _play_grid: GridContainer
var _tempo_group: VBoxContainer
var _tempo_menu: OptionButton
var _play_category_buttons: Dictionary = {}
var _recommendation_buttons: Array[Button] = []
var _displayed_play_ids: Array[String] = []
var _selected_play_category := "RECOMMENDED"
var _call_sheet_mode := ""


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

	var scoreboard := UIFactory.card("HeroPanel")
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
	field_header.add_child(UIFactory.section_heading("2D PLAY VIEW", "Live tactical movement and assignments"))
	field_header.add_child(UIFactory.spacer())
	_field_legend = UIFactory.label("GOLD: GAIN / SPY  ·  BLUE: SCRIMMAGE / COVERAGE  ·  RED: PRESSURE", "CaptionLabel")
	field_header.add_child(_field_legend)
	field_column.add_child(field_header)
	_field = FieldVisual.new()
	_field.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_field.animation_finished.connect(_on_animation_finished)
	_field.playback_changed.connect(_update_animation_controls)
	field_column.add_child(_field)
	_build_presentation_controls(field_column)

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
	_build_call_sheet(match_column)

	var feed_card := UIFactory.card()
	feed_card.custom_minimum_size = Vector2(300, 300)
	feed_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_card.size_flags_stretch_ratio = 0.82
	_body_grid.add_child(feed_card)
	var feed_column := UIFactory.vbox(10)
	feed_card.add_child(feed_column)
	var feed_header := UIFactory.hbox(8)
	feed_header.add_child(UIFactory.section_heading("PLAY-BY-PLAY", "Newest events appear first"))
	feed_header.add_child(UIFactory.spacer())
	feed_header.add_child(UIFactory.badge("LIVE", GridironTheme.DANGER))
	feed_column.add_child(feed_header)
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


func _build_call_sheet(parent: VBoxContainer) -> void:
	_call_sheet_card = UIFactory.card("RaisedCardPanel")
	_call_sheet_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_call_sheet_card)
	var column := UIFactory.vbox(10)
	_call_sheet_card.add_child(column)

	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 10)
	header.add_theme_constant_override("v_separation", 8)
	var identity := UIFactory.vbox(1)
	identity.custom_minimum_size.x = 260
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label("COACH MODE", "EyebrowLabel"))
	_call_sheet_title = UIFactory.label("Offensive Call Sheet", "SectionTitleLabel")
	identity.add_child(_call_sheet_title)
	_call_sheet_context = UIFactory.wrapped_label("Choose a concept or use the simulation controls below.", "CaptionLabel")
	_call_sheet_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(_call_sheet_context)
	header.add_child(identity)
	_tempo_group = UIFactory.vbox(3)
	_tempo_group.add_child(UIFactory.label("TEMPO", "EyebrowLabel"))
	_tempo_menu = OptionButton.new()
	_tempo_menu.custom_minimum_size = Vector2(150, 40)
	for tempo_name in PlayCallData.TEMPOS:
		_tempo_menu.add_item(tempo_name)
		_tempo_menu.set_item_metadata(_tempo_menu.item_count - 1, tempo_name)
	_tempo_group.add_child(_tempo_menu)
	header.add_child(_tempo_group)
	column.add_child(header)

	var category_flow := HFlowContainer.new()
	category_flow.add_theme_constant_override("h_separation", 8)
	category_flow.add_theme_constant_override("v_separation", 8)
	for category_name in ["RECOMMENDED", "RUN", "PASS", "SPECIAL / CLOCK", "BASE", "NICKEL", "DIME", "GOAL LINE", "PREVENT"]:
		var category_button := UIFactory.button(category_name, "SecondaryButton" if category_name == _selected_play_category else "GhostButton")
		category_button.pressed.connect(_select_play_category.bind(category_name))
		category_flow.add_child(category_button)
		_play_category_buttons[category_name] = category_button
	column.add_child(category_flow)

	_play_grid = GridContainer.new()
	_play_grid.columns = 2
	_play_grid.add_theme_constant_override("h_separation", 8)
	_play_grid.add_theme_constant_override("v_separation", 8)
	_play_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_play_grid)
	_call_sheet_status = UIFactory.wrapped_label("", "CaptionLabel")
	column.add_child(_call_sheet_status)


func _build_presentation_controls(parent: VBoxContainer) -> void:
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
	parent.add_child(controls)
	var status_block := UIFactory.vbox(1)
	status_block.custom_minimum_size = Vector2(160, 0)
	status_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_block.add_child(UIFactory.label("PLAY PRESENTATION", "EyebrowLabel"))
	_animation_status = UIFactory.wrapped_label("Ready for the next snap.", "CaptionLabel")
	status_block.add_child(_animation_status)
	controls.add_child(status_block)

	_presentation_toggle = UIFactory.button("2D VIEW · ON", "SecondaryButton")
	_presentation_toggle.toggle_mode = true
	_presentation_toggle.button_pressed = true
	_presentation_toggle.toggled.connect(_toggle_presentation)
	controls.add_child(_presentation_toggle)
	_pause_button = UIFactory.button("PAUSE", "GhostButton")
	_pause_button.pressed.connect(_toggle_animation_pause)
	controls.add_child(_pause_button)
	_replay_button = UIFactory.button("REPLAY", "GhostButton")
	_replay_button.pressed.connect(_replay_animation)
	controls.add_child(_replay_button)
	_skip_button = UIFactory.button("SKIP", "GhostButton")
	_skip_button.pressed.connect(_skip_animation)
	controls.add_child(_skip_button)
	_speed_menu = OptionButton.new()
	_speed_menu.custom_minimum_size = Vector2(92, 44)
	for speed in [0.5, 1.0, 1.5, 2.0]:
		_speed_menu.add_item("%.1f×" % speed)
		_speed_menu.set_item_metadata(_speed_menu.item_count - 1, speed)
	_speed_menu.select(1)
	_speed_menu.item_selected.connect(_select_animation_speed)
	controls.add_child(_speed_menu)

	_animation_progress = ProgressBar.new()
	_animation_progress.show_percentage = false
	_animation_progress.custom_minimum_size = Vector2(0, 6)
	parent.add_child(_animation_progress)
	_update_animation_controls()


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
	if _field.is_animation_active():
		return
	var result := _simulator.simulate_next_play()
	_present_play(result)


func _simulate_drive() -> void:
	_field.clear_animation()
	_simulator.simulate_drive()
	_refresh()


func _finish_game() -> void:
	_field.clear_animation()
	_simulator.simulate_to_end()
	_refresh()


func _select_play_category(category_name: String) -> void:
	_selected_play_category = category_name
	_rebuild_call_sheet()


func _call_play(play_id: String) -> void:
	if _field.is_animation_active():
		_call_sheet_status.text = "Finish or skip the current 2D replay before calling the next play."
		return
	if _simulator.state.is_final or _simulator.state.possession_team_id != _user_team.id:
		_call_sheet_status.text = "Play calls are available when your offense has possession."
		return
	var tempo := PlayCallData.TEMPO_NORMAL
	if _tempo_menu.selected >= 0:
		tempo = str(_tempo_menu.get_item_metadata(_tempo_menu.selected))
	var error := _simulator.call_validation_error(play_id)
	if not error.is_empty():
		_call_sheet_status.text = error
		return
	var result := _simulator.simulate_called_play(play_id, tempo)
	if result == null:
		_call_sheet_status.text = "The call could not be submitted in this situation."
		return
	_present_play(result)


func _call_defense(call_id: String) -> void:
	if _field.is_animation_active():
		_call_sheet_status.text = "Finish or skip the current 2D replay before calling the next play."
		return
	var state := _simulator.state
	if state.is_final or state.defense().id != _user_team.id:
		_call_sheet_status.text = "Defensive calls are available when the opponent has possession."
		return
	var error := _simulator.defensive_call_validation_error(call_id)
	if not error.is_empty():
		_call_sheet_status.text = error
		return
	var result := _simulator.simulate_called_defense(call_id)
	if result == null:
		_call_sheet_status.text = "The defensive call could not be submitted in this situation."
		return
	_present_play(result)


func _present_play(result: PlayResult) -> void:
	_refresh()
	if result == null or not _presentation_enabled:
		return
	var animation := PlayAnimationComposer.compose(result, _simulator.state)
	if animation == null:
		return
	_field.play_animation(animation)
	_set_action_controls()


func _toggle_presentation(enabled: bool) -> void:
	_presentation_enabled = enabled
	_presentation_toggle.text = "2D VIEW · ON" if enabled else "2D VIEW · OFF"
	_presentation_toggle.theme_type_variation = "SecondaryButton" if enabled else "GhostButton"
	if not enabled:
		_field.clear_animation()
		_animation_status.text = "2D playback disabled. Simulation controls remain available."
	_set_action_controls()


func _toggle_animation_pause() -> void:
	_field.toggle_pause()


func _replay_animation() -> void:
	if not _presentation_enabled:
		return
	_field.replay()
	_set_action_controls()


func _skip_animation() -> void:
	_field.skip_animation()


func _select_animation_speed(index: int) -> void:
	if index < 0:
		return
	_field.set_playback_speed(float(_speed_menu.get_item_metadata(index)))


func _on_animation_finished(_animation: PlayAnimationData) -> void:
	_refresh()


func _update_animation_controls() -> void:
	if _field == null or _animation_status == null:
		return
	var active := _field.is_animation_active()
	var has_replay := _field.animation_data != null
	_pause_button.disabled = not active
	_pause_button.text = "RESUME" if _field.is_paused() else "PAUSE"
	_skip_button.disabled = not active
	_replay_button.disabled = not has_replay or active or not _presentation_enabled
	_speed_menu.disabled = not _presentation_enabled
	_animation_progress.value = _field.playback_progress() * 100.0
	if not _presentation_enabled:
		_animation_status.text = "2D playback disabled. Simulation controls remain available."
	elif active:
		var progress := _field.playback_progress()
		if _field.is_paused():
			_animation_status.text = "Replay paused · %.1f× speed" % _field.playback_speed()
		elif progress < 0.14:
			_animation_status.text = "Pre-snap alignment · %s" % _field.animation_data.call_name
		elif progress < 0.72:
			_animation_status.text = "Play developing · %.1f× speed" % _field.playback_speed()
		else:
			_animation_status.text = "Result · %s" % _field.animation_data.outcome_label
	elif has_replay:
		_animation_status.text = "Replay complete · %s" % _field.animation_data.outcome_label
	else:
		_animation_status.text = "Ready for the next snap."
	_set_action_controls()


func _set_action_controls() -> void:
	if _field == null or _next_button == null:
		return
	var state := _simulator.state
	var animation_active := _field.is_animation_active()
	var controls_enabled := not state.is_final and not animation_active
	_next_button.disabled = not controls_enabled
	_drive_button.disabled = not controls_enabled
	_finish_button.disabled = not controls_enabled
	var user_on_offense := not state.is_final and state.possession_team_id == _user_team.id
	var user_on_defense := not state.is_final and state.defense().id == _user_team.id
	if _tempo_menu != null:
		_tempo_menu.disabled = not user_on_offense or animation_active
	for category_button in _play_category_buttons.values():
		category_button.disabled = (not user_on_offense and not user_on_defense) or animation_active
	if _play_grid != null:
		for child in _play_grid.get_children():
			if child is Button:
				child.disabled = (not user_on_offense and not user_on_defense) or animation_active


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
	_rebuild_call_sheet()
	_set_action_controls()
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
	if _play_grid != null:
		_play_grid.columns = 3 if size.x >= 1350 else (2 if size.x >= 720 else 1)
	if _field_legend != null:
		_field_legend.visible = size.x >= 760


func _rebuild_call_sheet() -> void:
	if _call_sheet_card == null:
		return
	_recommendation_buttons.clear()
	_displayed_play_ids.clear()
	for child in _play_grid.get_children():
		_play_grid.remove_child(child)
		child.queue_free()
	var state := _simulator.state
	var user_on_offense := not state.is_final and state.possession_team_id == _user_team.id
	var user_on_defense := not state.is_final and state.defense().id == _user_team.id
	var new_mode := "OFFENSE" if user_on_offense else "DEFENSE"
	if new_mode != _call_sheet_mode:
		_call_sheet_mode = new_mode
		_selected_play_category = "RECOMMENDED"
	_call_sheet_title.text = "Offensive Call Sheet" if user_on_offense else "Defensive Call Sheet"
	_tempo_group.visible = user_on_offense
	_tempo_menu.disabled = not user_on_offense
	for category_name in _play_category_buttons:
		var button: Button = _play_category_buttons[category_name]
		var offense_category: bool = str(category_name) in ["RUN", "PASS", "SPECIAL / CLOCK"]
		var defense_category: bool = str(category_name) in ["BASE", "NICKEL", "DIME", "GOAL LINE", "PREVENT"]
		button.visible = category_name == "RECOMMENDED" or (user_on_offense and offense_category) or (user_on_defense and defense_category)
		button.disabled = state.is_final
		button.theme_type_variation = "SecondaryButton" if category_name == _selected_play_category else "GhostButton"
	if state.is_final:
		_call_sheet_context.text = "The final whistle has ended coach mode."
		_call_sheet_status.text = "Review the completed game or use the return controls below."
		return
	_call_sheet_context.text = "%s · %s · %s ball" % [state.down_and_distance_label(), state.field_position_label(), state.offense().abbreviation]
	if user_on_defense:
		_rebuild_defensive_calls(state)
		return

	var plays: Array[PlayDefinitionData] = []
	if _selected_play_category == "RECOMMENDED":
		plays = _simulator.recommended_play_calls(3)
	else:
		for play in _simulator.available_play_calls():
			if _selected_play_category == "RUN" and play.category == "Run":
				plays.append(play)
			elif _selected_play_category == "PASS" and play.category == "Pass":
				plays.append(play)
			elif _selected_play_category == "SPECIAL / CLOCK" and play.category in ["Special", "Clock"]:
				plays.append(play)
	_call_sheet_status.text = "Calls resolve against the opponent coordinator, player ratings, fatigue, and recent tendencies."
	if plays.is_empty():
		_call_sheet_status.text = "No calls in this section are available for the current personnel and field position."
		return
	for play in plays:
		var button := UIFactory.button(
			"%s\n%s · %s PERSONNEL\n%s · %s RISK" % [play.display_name.to_upper(), play.formation, play.personnel, play.concept, play.risk.to_upper()],
			"TeamCardButton"
		)
		button.custom_minimum_size = Vector2(210, 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = play.description
		button.pressed.connect(_call_play.bind(play.id))
		_play_grid.add_child(button)
		_displayed_play_ids.append(play.id)
		if _selected_play_category == "RECOMMENDED":
			_recommendation_buttons.append(button)
	_apply_responsive_layout()


func _rebuild_defensive_calls(state: GameStateData) -> void:
	var calls: Array[DefensiveCallData] = []
	if _selected_play_category == "RECOMMENDED":
		calls = _simulator.recommended_defensive_calls(3)
	else:
		var category_name := _selected_play_category.capitalize()
		for call in _simulator.available_defensive_calls():
			if call.category == category_name:
				calls.append(call)
	_call_sheet_status.text = "Your call sets the personnel, front, coverage shell, and rush plan. The opposing offense is called by its AI coordinator."
	if calls.is_empty():
		_call_sheet_status.text = "No calls in this section are available with the current game-day personnel."
		return
	for call in calls:
		var detail := "%s FRONT · %s · RUSH %d" % [call.front.to_upper(), call.shell.to_upper(), call.rusher_count]
		if _selected_play_category == "RECOMMENDED":
			detail = "%s · %s" % [PlayCallerService.defensive_recommendation_reason(state, call).to_upper(), detail]
		var button := UIFactory.button(
			"%s\n%s PERSONNEL · %s\n%s · %s RISK" % [
				call.display_name.to_upper(), call.personnel.to_upper(), call.coverage.to_upper(), detail, call.risk.to_upper()
			],
			"TeamCardButton"
		)
		button.custom_minimum_size = Vector2(210, 94 if _selected_play_category == "RECOMMENDED" else 82)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = call.description
		button.pressed.connect(_call_defense.bind(call.id))
		_play_grid.add_child(button)
		_displayed_play_ids.append(call.id)
		if _selected_play_category == "RECOMMENDED":
			_recommendation_buttons.append(button)
	_apply_responsive_layout()


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
	if not play.call_name.is_empty():
		var offense_marker := " · USER" if play.call_was_user_selected else ""
		var defense_marker := " · USER" if play.defensive_call_was_user_selected else ""
		column.add_child(UIFactory.wrapped_label(
			"%s%s · %s personnel · %s  vs  %s%s · %s · %s" % [
				play.call_name, offense_marker, play.call_personnel, play.call_tempo,
				play.defensive_call_name, defense_marker, play.defensive_call_personnel, play.defensive_call_shell,
			],
			"CaptionLabel"
		))
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
