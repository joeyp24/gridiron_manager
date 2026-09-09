extends Control

signal back_requested
signal roster_changed
signal player_statistics_requested(player_id: String)
signal player_profile_requested(player_id: String)

const TAB_DEPTH := "Depth Chart"
const TAB_ROSTER := "53-Man Roster"
const TAB_IR := "Injured Reserve"
const TAB_PRACTICE := "Practice Squad"
const TAB_WAIVERS := "Waiver Wire"
const TABS: Array[String] = [TAB_DEPTH, TAB_ROSTER, TAB_IR, TAB_PRACTICE, TAB_WAIVERS]

var _career: CareerSession
var _team: TeamData
var _page: VBoxContainer
var _content_host: VBoxContainer
var _summary_grid: GridContainer
var _action_grids: Array[GridContainer] = []
var _attribute_metrics: Array[Control] = []
var _tab_buttons: Dictionary = {}
var _metric_labels: Dictionary = {}
var _position_menu: OptionButton
var _message_panel: PanelContainer
var _message_label: Label
var _header_subtitle: Label
var _back_button: Button
var _selected_tab := TAB_DEPTH
var _selected_position := "QB"
var _message := ""
var _message_is_error := false


func setup(career: CareerSession) -> void:
	_career = career
	_team = career.user_team()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_refresh_screen()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_page = UIFactory.vbox(16)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.custom_minimum_size = Vector2(0, 720)
	scroll.add_child(_page)

	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(_team.abbreviation, _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("ROSTER MANAGEMENT", "PageTitleLabel"))
	_header_subtitle = UIFactory.label("Build the 53, set the game-day list, and manage every reserve pathway.", "MutedLabel")
	copy.add_child(_header_subtitle)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	_back_button = UIFactory.button("←  CAREER HUB", "GhostButton")
	_back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(_back_button)
	_page.add_child(header)

	_summary_grid = GridContainer.new()
	_summary_grid.columns = 5
	_summary_grid.add_theme_constant_override("h_separation", 10)
	_summary_grid.add_theme_constant_override("v_separation", 10)
	_summary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_summary_grid)
	_summary_grid.add_child(_summary_card("53-MAN ROSTER", "roster", "League contract list"))
	_summary_grid.add_child(_summary_card("GAME-DAY ACTIVE", "active", "Healthy eligible players"))
	_summary_grid.add_child(_summary_card("INJURED RESERVE", "ir", "Protected roster spots"))
	_summary_grid.add_child(_summary_card("PRACTICE SQUAD", "practice", "Development group"))
	_summary_grid.add_child(_summary_card("WAIVER PRIORITY", "waiver", "Worst record claims first"))

	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size.y = 50
	_page.add_child(tabs_scroll)
	var tabs := UIFactory.hbox(8)
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.add_child(tabs)
	for tab_name in TABS:
		var tab := UIFactory.button(tab_name.to_upper(), "GhostButton")
		tab.custom_minimum_size.x = 150
		tab.pressed.connect(_select_tab.bind(tab_name))
		tabs.add_child(tab)
		_tab_buttons[tab_name] = tab

	_message_panel = UIFactory.card("RaisedCardPanel")
	_message_label = UIFactory.wrapped_label("", "BodyLabel")
	_message_panel.add_child(_message_label)
	_message_panel.visible = false
	_page.add_child(_message_panel)

	var content_card := UIFactory.card()
	content_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page.add_child(content_card)
	_content_host = UIFactory.vbox(10)
	content_card.add_child(_content_host)


func _refresh_screen() -> void:
	_team = _career.user_team()
	_refresh_summary()
	_refresh_message()
	for tab_name in TABS:
		var button: Button = _tab_buttons.get(tab_name)
		button.theme_type_variation = "SecondaryButton" if tab_name == _selected_tab else "GhostButton"
	for child in _content_host.get_children():
		_content_host.remove_child(child)
		child.queue_free()
	_action_grids.clear()
	_attribute_metrics.clear()
	match _selected_tab:
		TAB_DEPTH:
			_build_depth_chart()
		TAB_ROSTER:
			_build_active_roster()
		TAB_IR:
			_build_injured_reserve()
		TAB_PRACTICE:
			_build_practice_squad()
		TAB_WAIVERS:
			_build_waiver_wire()
	_apply_responsive_layout()


func _select_tab(tab_name: String) -> void:
	_selected_tab = tab_name
	_message = ""
	_refresh_screen()


func _build_depth_chart() -> void:
	_content_host.add_child(_section_heading("DEPTH CHART", "Set positional priority. The highest available player in each group starts."))
	var toolbar := UIFactory.hbox(10)
	toolbar.add_child(UIFactory.label("POSITION GROUP", "EyebrowLabel"))
	_position_menu = OptionButton.new()
	_position_menu.custom_minimum_size = Vector2(150, 44)
	for position_name in TeamData.ROSTER_POSITIONS:
		_position_menu.add_item(position_name)
	_position_menu.select(maxi(TeamData.ROSTER_POSITIONS.find(_selected_position), 0))
	_position_menu.item_selected.connect(_select_position)
	toolbar.add_child(_position_menu)
	toolbar.add_child(UIFactory.spacer())
	toolbar.add_child(UIFactory.label("Priority affects starters and simulation usage", "CaptionLabel"))
	_content_host.add_child(toolbar)
	var players := _team.depth_players(_selected_position)
	var starter := _team.player_at(_selected_position)
	if players.is_empty():
		_content_host.add_child(_empty_state("No players are assigned to this position group."))
		return
	for index in range(players.size()):
		_content_host.add_child(_depth_row(players[index], index, starter, players.size()))


func _build_active_roster() -> void:
	var expected := mini(_team.game_day_active_limit, _healthy_roster_count())
	_content_host.add_child(_section_heading(
		"53-MAN ROSTER",
		"%d game-day active · %d inactive · target %d active. Injured players can be protected on IR." % [_team.active_roster_count(), _team.players.size() - _team.active_roster_count(), expected]
	))
	var errors := RosterValidator.validate_game_day_roster(_team)
	if not errors.is_empty():
		var warning := UIFactory.card("RaisedCardPanel")
		var warning_copy := UIFactory.wrapped_label("ACTION REQUIRED · " + "  ".join(errors), "MutedLabel")
		warning_copy.modulate = GridironTheme.DANGER
		warning.add_child(warning_copy)
		_content_host.add_child(warning)
	for player in _ordered_players(_team.players):
		_content_host.add_child(_roster_row(player))


func _build_injured_reserve() -> void:
	_content_host.add_child(_section_heading(
		"INJURED RESERVE",
		"Players leave the 53-man list while retaining their contracts. The minimum stay is %d weeks." % _team.injured_reserve_minimum_weeks
	))
	if _team.injured_reserve.is_empty():
		_content_host.add_child(_empty_state("No players are currently on injured reserve."))
		return
	for player in _ordered_players(_team.injured_reserve):
		_content_host.add_child(_injured_reserve_row(player))


func _build_practice_squad() -> void:
	_content_host.add_child(_section_heading(
		"PRACTICE SQUAD",
		"%d of %d places used · %d veteran exemptions available. Other clubs may sign these players to their 53-man roster." % [_team.practice_squad.size(), _team.practice_squad_limit, _team.practice_squad_veteran_limit]
	))
	_content_host.add_child(_subheading("YOUR PRACTICE SQUAD", "Promote, release, or review club-controlled players."))
	if _team.practice_squad.is_empty():
		_content_host.add_child(_empty_state("Your practice squad is empty."))
	else:
		for player in _ordered_players(_team.practice_squad):
			_content_host.add_child(_practice_squad_row(player))

	_content_host.add_child(UIFactory.divider())
	_content_host.add_child(_subheading("AVAILABLE FREE AGENTS", "Eligible players can sign a one-year practice-squad contract."))
	var candidates := _practice_squad_free_agents()
	if candidates.is_empty():
		_content_host.add_child(_empty_state("No eligible free agents are currently available."))
	else:
		for player in candidates.slice(0, mini(12, candidates.size())):
			_content_host.add_child(_practice_candidate_row(player))

	_content_host.add_child(UIFactory.divider())
	_content_host.add_child(_subheading("OTHER CLUBS", "Poaching requires an open 53-man roster spot and a standard active contract."))
	var other_players := _other_practice_squad_players()
	if other_players.is_empty():
		_content_host.add_child(_empty_state("No players are listed on another club's practice squad."))
	else:
		for player in other_players.slice(0, mini(12, other_players.size())):
			_content_host.add_child(_poach_row(player))


func _build_waiver_wire() -> void:
	var rank := RosterTransactionService.waiver_priority_rank(_career.league, _team.id)
	_content_host.add_child(_section_heading(
		"WAIVER WIRE",
		"Your club holds priority %d of %d. Claims are awarded to the highest-priority eligible club after the deadline." % [rank, _career.league.teams.size()]
	))
	if _career.league.waiver_wire.is_empty():
		_content_host.add_child(_empty_state("The waiver wire is clear. In-season releases will appear here."))
		return
	for entry in _career.league.waiver_wire:
		_content_host.add_child(_waiver_row(entry))


func _depth_row(player: PlayerData, index: int, starter: PlayerData, room_size: int) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	var role := "STARTER" if starter != null and player.id == starter.id else "DEPTH %d" % (index + 1)
	column.add_child(_player_identity_row(player, role, _team.primary_color))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	var up := _action_button("MOVE UP", _move_player.bind(player.id, -1))
	up.disabled = index == 0
	actions.add_child(up)
	var down := _action_button("MOVE DOWN", _move_player.bind(player.id, 1))
	down.disabled = index == room_size - 1
	actions.add_child(down)
	column.add_child(actions)
	return panel


func _roster_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	var status := "GAME-DAY ACTIVE" if player.is_active else "INACTIVE"
	if player.injury_weeks > 0:
		status = "INJURED · %d WK" % player.injury_weeks
	var status_color := _team.primary_color if player.is_active else GridironTheme.BORDER
	column.add_child(_player_identity_row(player, status, status_color))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	var game_day := _action_button("MAKE INACTIVE" if player.is_active else "ACTIVATE", _toggle_game_day.bind(player.id, not player.is_active))
	game_day.disabled = player.injury_weeks > 0 and not player.is_active
	actions.add_child(game_day)
	var ir := _action_button("PLACE ON IR", _place_on_ir.bind(player.id))
	ir.disabled = player.injury_weeks <= 0
	actions.add_child(ir)
	if _career.league.is_offseason():
		actions.add_child(_action_button("MOVE TO PRACTICE SQUAD", _move_to_practice.bind(player.id)))
	var release_text := "RELEASE" if _career.league.is_offseason() else "WAIVE PLAYER"
	actions.add_child(_action_button(release_text, _release_player.bind(player.id)))
	column.add_child(actions)
	return panel


func _injured_reserve_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	var return_status := "ELIGIBLE WEEK %d" % player.eligible_return_week
	if player.injury_weeks > 0:
		return_status += " · %d WK RECOVERY" % player.injury_weeks
	column.add_child(_player_identity_row(player, return_status, GridironTheme.WARM))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	var activate := _action_button("ACTIVATE TO 53", _activate_from_ir.bind(player.id))
	activate.disabled = player.injury_weeks > 0 or (not _career.league.is_offseason() and _career.league.current_week < player.eligible_return_week) or not _team.has_roster_space()
	actions.add_child(activate)
	column.add_child(actions)
	return panel


func _practice_squad_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	column.add_child(_player_identity_row(player, "PRACTICE SQUAD", GridironTheme.BORDER))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	var promote := _action_button("PROMOTE TO 53", _promote_practice.bind(player.id))
	var roster_limit := _career.league.league_format.offseason_roster_limit if _career.league.is_offseason() else _team.roster_limit
	promote.disabled = _team.players.size() >= roster_limit
	actions.add_child(promote)
	actions.add_child(_action_button("RELEASE", _release_practice.bind(player.id)))
	column.add_child(actions)
	return panel


func _practice_candidate_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	var contract := PlayerContract.practice_squad_contract(player, _career.league.contract_start_year())
	column.add_child(_player_identity_row(player, "%s / YEAR" % PlayerContract.money_label(contract.annual_salary), GridironTheme.BORDER))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	actions.add_child(_action_button("SIGN TO PRACTICE SQUAD", _sign_practice.bind(player.id)))
	column.add_child(actions)
	return panel


func _poach_row(player: PlayerData) -> PanelContainer:
	var source := _career.league.team_for_player(player.id)
	var source_label := source.abbreviation if source != null else "OTHER CLUB"
	var source_color := source.primary_color if source != null else GridironTheme.BORDER
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	column.add_child(_player_identity_row(player, "%s PRACTICE SQUAD" % source_label, source_color))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	var poach := _action_button("SIGN TO 53", _poach_practice.bind(player.id))
	poach.disabled = not _team.has_roster_space()
	actions.add_child(poach)
	column.add_child(actions)
	return panel


func _waiver_row(entry: WaiverEntryData) -> PanelContainer:
	var player: PlayerData = entry.player
	var former := _career.league.team_by_id(entry.waived_by_team_id)
	var former_label := former.abbreviation if former != null else "FORMER CLUB"
	var salary := player.contract.annual_salary if player.contract != null else 0
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(8)
	panel.add_child(column)
	var status := "WAIVED BY %s · %s / YR · RESOLVES WEEK %d" % [former_label, PlayerContract.money_label(salary), entry.resolve_week]
	column.add_child(_player_identity_row(player, status, GridironTheme.WARM))
	column.add_child(UIFactory.label("%d CLAIM%s FILED" % [entry.claims.size(), "" if entry.claims.size() == 1 else "S"], "CaptionLabel"))
	var actions := _new_action_grid()
	actions.add_child(_action_button("VIEW PROFILE", func(): player_profile_requested.emit(player.id)))
	if entry.has_claim(_team.id):
		actions.add_child(_action_button("WITHDRAW CLAIM", _withdraw_claim.bind(entry.id)))
	else:
		var claim := _action_button("SUBMIT CLAIM", _submit_claim.bind(entry.id))
		claim.disabled = not RosterTransactionService.waiver_claim_error(_career.league, _team, entry).is_empty()
		actions.add_child(claim)
	column.add_child(actions)
	return panel


func _player_identity_row(player: PlayerData, status_text: String, status_color: Color) -> HBoxContainer:
	var row := UIFactory.hbox(10)
	row.add_child(UIFactory.badge(player.position, status_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	var contract_text := ""
	if player.contract != null:
		contract_text = " · %s/YR · %d YR" % [PlayerContract.money_label(player.contract.annual_salary), player.contract.years_remaining]
	identity.add_child(UIFactory.label("%s · Age %d · %d years pro%s" % [status_text, player.age, player.experience_years, contract_text], "CaptionLabel"))
	row.add_child(identity)
	for entry in [["SPD", player.speed], ["PWR", player.power], ["TEC", player.technique], ["AWR", player.awareness]]:
		var metric := _small_metric(str(entry[0]), str(entry[1]))
		_attribute_metrics.append(metric)
		row.add_child(metric)
	row.add_child(_small_metric("OVR", str(player.overall)))
	return row


func _new_action_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 5 if size.x >= 1040 else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grids.append(grid)
	return grid


func _action_button(text_value: String, callback: Callable) -> Button:
	var button := UIFactory.button(text_value, "GhostButton")
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	return button


func _summary_card(title: String, key: String, detail: String) -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.custom_minimum_size = Vector2(160, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(2)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	var value := UIFactory.label("—", "MetricLabel")
	column.add_child(value)
	column.add_child(UIFactory.label(detail, "CaptionLabel"))
	_metric_labels[key] = value
	return card


func _section_heading(title: String, detail: String) -> VBoxContainer:
	var heading := UIFactory.vbox(2)
	heading.add_child(UIFactory.label(title, "SectionTitleLabel"))
	heading.add_child(UIFactory.wrapped_label(detail, "MutedLabel"))
	return heading


func _subheading(title: String, detail: String) -> HBoxContainer:
	var heading := UIFactory.hbox(8)
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label(title, "EyebrowLabel"))
	copy.add_child(UIFactory.label(detail, "CaptionLabel"))
	heading.add_child(copy)
	return heading


func _empty_state(message: String) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	panel.add_child(UIFactory.wrapped_label(message, "MutedLabel"))
	return panel


func _small_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size = Vector2(48, 0)
	var value_label := UIFactory.label(value, "BodyLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(value_label)
	var caption := UIFactory.label(title, "CaptionLabel")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(caption)
	return metric


func _refresh_summary() -> void:
	if _metric_labels.is_empty():
		return
	(_metric_labels["roster"] as Label).text = "%d / %d" % [_team.players.size(), _team.roster_limit]
	(_metric_labels["active"] as Label).text = "%d / %d" % [_team.active_roster_count(), _team.game_day_active_limit]
	(_metric_labels["ir"] as Label).text = str(_team.injured_reserve.size())
	(_metric_labels["practice"] as Label).text = "%d / %d" % [_team.practice_squad.size(), _team.practice_squad_limit]
	var rank := RosterTransactionService.waiver_priority_rank(_career.league, _team.id)
	(_metric_labels["waiver"] as Label).text = "#%d" % rank


func _refresh_message() -> void:
	_message_panel.visible = not _message.is_empty()
	_message_label.text = _message
	_message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT


func _show_result(result: Dictionary) -> void:
	_message = str(result.get("message", "Roster action completed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		roster_changed.emit()
	_refresh_screen()


func _select_position(index: int) -> void:
	_selected_position = TeamData.ROSTER_POSITIONS[index]
	_refresh_screen()


func _move_player(player_id: String, direction: int) -> void:
	if _team.move_on_depth_chart(_selected_position, player_id, direction):
		_message = "Depth-chart priority updated."
		_message_is_error = false
		roster_changed.emit()
	_refresh_screen()


func _toggle_game_day(player_id: String, active: bool) -> void:
	_show_result(_career.set_player_game_day_active(player_id, active))


func _place_on_ir(player_id: String) -> void:
	_show_result(_career.place_player_on_injured_reserve(player_id))


func _activate_from_ir(player_id: String) -> void:
	_show_result(_career.activate_player_from_injured_reserve(player_id))


func _move_to_practice(player_id: String) -> void:
	_show_result(_career.assign_roster_player_to_practice_squad(player_id))


func _promote_practice(player_id: String) -> void:
	_show_result(_career.promote_practice_squad_player(player_id))


func _release_practice(player_id: String) -> void:
	_show_result(_career.release_practice_squad_player(player_id))


func _sign_practice(player_id: String) -> void:
	_show_result(_career.sign_practice_squad_player(player_id))


func _poach_practice(player_id: String) -> void:
	_show_result(_career.poach_practice_squad_player(player_id))


func _release_player(player_id: String) -> void:
	_show_result(_career.release_player(player_id))


func _submit_claim(entry_id: String) -> void:
	_show_result(_career.submit_waiver_claim(entry_id))


func _withdraw_claim(entry_id: String) -> void:
	_show_result(_career.withdraw_waiver_claim(entry_id))


func _practice_squad_free_agents() -> Array[PlayerData]:
	var candidates: Array[PlayerData] = []
	for player in _career.league.free_agents:
		if RosterValidator.practice_squad_error(_team, player).is_empty():
			candidates.append(player)
	candidates.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return candidates


func _other_practice_squad_players() -> Array[PlayerData]:
	var candidates: Array[PlayerData] = []
	for team in _career.league.teams:
		if team.id != _team.id:
			candidates.append_array(team.practice_squad)
	candidates.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return candidates


func _ordered_players(source: Array[PlayerData]) -> Array[PlayerData]:
	var ordered := source.duplicate()
	ordered.sort_custom(func(a: PlayerData, b: PlayerData):
		var position_compare := TeamData.ROSTER_POSITIONS.find(a.position) - TeamData.ROSTER_POSITIONS.find(b.position)
		return a.overall > b.overall if position_compare == 0 else position_compare < 0
	)
	return ordered


func _healthy_roster_count() -> int:
	var count := 0
	for player in _team.players:
		if player.injury_weeks <= 0:
			count += 1
	return count


func _apply_responsive_layout() -> void:
	if _summary_grid != null:
		_summary_grid.columns = 5 if size.x >= 1180 else (3 if size.x >= 780 else 2)
	for grid in _action_grids:
		grid.columns = 5 if size.x >= 1040 else (3 if size.x >= 760 else 2)
	for metric in _attribute_metrics:
		metric.visible = size.x >= 900
	if _header_subtitle != null:
		_header_subtitle.visible = size.x >= 800
	if _back_button != null:
		_back_button.text = "←  CAREER HUB" if size.x >= 720 else "←  BACK"
