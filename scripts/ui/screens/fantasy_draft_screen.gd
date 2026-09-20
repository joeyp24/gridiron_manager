extends Control

signal portal_requested
signal draft_changed
signal draft_completed
signal player_profile_requested(player_id: String)

const BOARD_LIMIT := 64

var _career: CareerSession
var _team: TeamData
var _page: VBoxContainer
var _body_grid: GridContainer
var _metric_grid: GridContainer
var _header_detail: Label
var _search_input: LineEdit
var _selected_player_id := ""
var _position_filter := ""
var _search_text := ""
var _message := ""
var _message_is_error := false


func setup(career: CareerSession) -> void:
	_career = career
	_team = career.user_team()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_page = UIFactory.vbox(16)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.custom_minimum_size = Vector2(0, 780)
	scroll.add_child(_page)
	_rebuild()


func _rebuild() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	var draft := _career.league.fantasy_draft
	if draft == null:
		_build_unavailable_state()
		return
	_build_header(draft)
	_build_metrics(draft)
	if not _message.is_empty():
		var message_card := UIFactory.card("RaisedCardPanel")
		var message_label := UIFactory.wrapped_label(_message, "BodyLabel")
		message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT
		message_card.add_child(message_label)
		_page.add_child(message_card)
	if draft.status == FantasyDraftStateData.STATUS_READY:
		_build_ready_state(draft)
	else:
		_build_live_room(draft)
	_apply_responsive_layout()


func _build_unavailable_state() -> void:
	var card := UIFactory.card("RaisedCardPanel")
	var column := UIFactory.vbox(10)
	card.add_child(column)
	column.add_child(UIFactory.label("FANTASY DRAFT", "PageTitleLabel"))
	column.add_child(UIFactory.wrapped_label("This career does not have an active fantasy draft.", "MutedLabel"))
	var portal := UIFactory.button("RETURN TO PORTAL", "PrimaryButton")
	portal.pressed.connect(func(): portal_requested.emit())
	column.add_child(portal)
	_page.add_child(card)


func _build_header(draft: FantasyDraftStateData) -> void:
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge("53 ROUNDS", _team.primary_color))
	var copy := UIFactory.page_heading("LEAGUE RESET", "Fantasy Draft War Room")
	_header_detail = UIFactory.label(_draft_subtitle(draft), "MutedLabel")
	copy.add_child(_header_detail)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var exit_button := UIFactory.button("SAVE & EXIT", "GhostButton")
	exit_button.pressed.connect(func(): portal_requested.emit())
	header.add_child(exit_button)
	_page.add_child(header)


func _build_metrics(draft: FantasyDraftStateData) -> void:
	_metric_grid = GridContainer.new()
	_metric_grid.columns = 4
	_metric_grid.add_theme_constant_override("h_separation", 10)
	_metric_grid.add_theme_constant_override("v_separation", 10)
	_metric_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := draft.current_pick()
	var next_user := draft.next_pick_for(_team.id)
	_metric_grid.add_child(_metric_card("YOUR DRAFT SLOT", "#%d" % draft.user_draft_slot(_team.id), "Randomized first-round order"))
	_metric_grid.add_child(_metric_card("ON THE CLOCK", _pick_owner_label(current), current.pick_label() if current != null else "Draft complete"))
	_metric_grid.add_child(_metric_card("YOUR NEXT PICK", next_user.pick_label() if next_user != null else "COMPLETE", "%d / %d rostered" % [_team.players.size(), _team.roster_limit]))
	_metric_grid.add_child(_metric_card("AVAILABLE POOL", str(_career.league.free_agents.size()), "%d selections complete" % draft.current_pick_index))
	_page.add_child(_metric_grid)


func _build_ready_state(draft: FantasyDraftStateData) -> void:
	var hero := UIFactory.card("HeroPanel")
	var hero_row := UIFactory.hbox(16)
	hero.add_child(hero_row)
	var copy := UIFactory.vbox(6)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label("BUILD THE LEAGUE FROM SCRATCH", "EyebrowLabel"))
	copy.add_child(UIFactory.label("Every player. Every club. One shared draft pool.", "SectionTitleLabel"))
	copy.add_child(UIFactory.wrapped_label("The league will run a 53-round snake draft. Existing contracts travel with players, AI clubs balance talent, positional value, scheme, age, needs, and the salary cap, and the undrafted players become free agents.", "BodyLabel"))
	hero_row.add_child(copy)
	var actions := UIFactory.vbox(8)
	var begin := UIFactory.button("ENTER LIVE DRAFT  ->", "PrimaryButton")
	begin.pressed.connect(_begin_draft)
	actions.add_child(begin)
	var simulate := UIFactory.button("SIMULATE ENTIRE DRAFT", "SecondaryButton")
	simulate.pressed.connect(_simulate_remainder)
	actions.add_child(simulate)
	hero_row.add_child(actions)
	_page.add_child(hero)

	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)
	_body_grid.add_child(_draft_order_card(draft))
	var rules := _card_column("DRAFT FORMAT", "A league-wide roster reset with season-ready safeguards")
	_add_rule(rules.column, "SNAKE ORDER", "Round two reverses round one, and every following round alternates.")
	_add_rule(rules.column, "COMPLETE ROSTERS", "All 32 clubs make 53 selections with every required position covered.")
	_add_rule(rules.column, "CAP AWARE", "Contract values remain attached and each club reserves room to complete its roster.")
	_add_rule(rules.column, "RESUMABLE", "Save and leave at any selection. The pool, order, and every pick return exactly as they were.")
	_body_grid.add_child(rules.card)


func _build_live_room(draft: FantasyDraftStateData) -> void:
	_build_filters()
	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)
	_body_grid.add_child(_player_board(draft))
	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_player_detail(draft))
	side.add_child(_pick_controls(draft))
	side.add_child(_roster_construction_card())
	side.add_child(_recent_picks_card(draft))
	_body_grid.add_child(side)


func _build_filters() -> void:
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 10)
	toolbar.add_theme_constant_override("v_separation", 8)
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Search the draft pool"
	_search_input.text = _search_text
	_search_input.custom_minimum_size = Vector2(260, 44)
	_search_input.text_submitted.connect(func(_value: String): _apply_search())
	toolbar.add_child(_search_input)
	var search_button := UIFactory.button("SEARCH", "SecondaryButton")
	search_button.pressed.connect(_apply_search)
	toolbar.add_child(search_button)
	var position_menu := OptionButton.new()
	position_menu.custom_minimum_size = Vector2(170, 44)
	position_menu.add_item("ALL POSITIONS")
	for position_name in TeamData.ROSTER_POSITIONS:
		position_menu.add_item(position_name)
	position_menu.select(0 if _position_filter.is_empty() else TeamData.ROSTER_POSITIONS.find(_position_filter) + 1)
	position_menu.item_selected.connect(_change_position_filter)
	toolbar.add_child(position_menu)
	toolbar.add_child(UIFactory.badge("NEEDS  %s" % "  ·  ".join(FantasyDraftService.team_needs(_team, 4)), GridironTheme.ACCENT_DARK))
	_page.add_child(toolbar)


func _player_board(draft: FantasyDraftStateData) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(610, 650)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label("AVAILABLE PLAYER BOARD", "SectionTitleLabel"))
	column.add_child(UIFactory.label("Ranked for your roster · select a row to open its dossier", "CaptionLabel"))
	var players := FantasyDraftService.ranked_pool(_career.league, _position_filter, _search_text)
	if players.is_empty():
		column.add_child(UIFactory.wrapped_label("No available players match those filters.", "MutedLabel"))
		return card
	if _selected_player_id.is_empty() or not _pool_contains(players, _selected_player_id):
		_selected_player_id = players.front().id
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows := UIFactory.vbox(5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	var group := ButtonGroup.new()
	for index in range(mini(BOARD_LIMIT, players.size())):
		var player := players[index]
		var row := UIFactory.button("%3d   %-4s   %-24s   OVR %d   AGE %d   %s" % [index + 1, player.position, player.full_name, player.overall, player.age, _contract_label(player)], "TeamCardButton")
		row.toggle_mode = true
		row.button_group = group
		row.button_pressed = player.id == _selected_player_id
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(_select_player.bind(player.id))
		rows.add_child(row)
	column.add_child(scroll)
	if players.size() > BOARD_LIMIT:
		column.add_child(UIFactory.label("Showing the top %d of %d matches. Refine search or position to see more." % [BOARD_LIMIT, players.size()], "CaptionLabel"))
	return card


func _player_detail(_draft: FantasyDraftStateData) -> PanelContainer:
	var built := _card_column("PLAYER DOSSIER", "Overall, contract, attributes, and roster fit")
	var player := _career.league.free_agent_by_id(_selected_player_id)
	if player == null:
		built.column.add_child(UIFactory.wrapped_label("Select an available player to review him.", "MutedLabel"))
		return built.card
	var identity := UIFactory.hbox(10)
	identity.add_child(UIFactory.badge(player.position, _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label(player.full_name, "SectionTitleLabel"))
	copy.add_child(UIFactory.label("%s · %s · %d'%d\" · %d lb" % [player.archetype, player.college, player.height_inches / 12, player.height_inches % 12, player.weight_lbs], "MutedLabel"))
	identity.add_child(copy)
	identity.add_child(UIFactory.label(str(player.overall), "MetricLabel"))
	built.column.add_child(identity)
	var metrics := GridContainer.new()
	metrics.columns = 3
	metrics.add_theme_constant_override("h_separation", 8)
	metrics.add_child(_mini_metric("AGE", str(player.age)))
	metrics.add_child(_mini_metric("POTENTIAL", str(player.potential)))
	metrics.add_child(_mini_metric("CONTRACT", _contract_label(player)))
	built.column.add_child(metrics)
	if player.madden_ratings != null:
		built.column.add_child(UIFactory.label("TOP ATTRIBUTES", "EyebrowLabel"))
		var attributes: Array[String] = []
		for attribute in player.madden_ratings.top_attributes(6):
			attributes.append("%s %d" % [str(attribute.label), int(attribute.value)])
		built.column.add_child(UIFactory.wrapped_label("  ·  ".join(attributes), "BodyLabel"))
	var error := FantasyDraftService.selection_error(_career.league, _team, player)
	var fit_label := UIFactory.wrapped_label("ELIGIBLE · Fits the current roster and cap plan." if error.is_empty() else "UNAVAILABLE · %s" % error, "CaptionLabel")
	fit_label.modulate = GridironTheme.ACCENT if error.is_empty() else GridironTheme.DANGER
	built.column.add_child(fit_label)
	var profile := UIFactory.button("VIEW FULL PLAYER PROFILE", "SecondaryButton")
	profile.pressed.connect(func(): player_profile_requested.emit(player.id))
	built.column.add_child(profile)
	return built.card


func _pick_controls(draft: FantasyDraftStateData) -> PanelContainer:
	var current := draft.current_pick()
	var user_on_clock := current != null and current.team_id == _team.id
	var built := _card_column("PICK CONTROL", "Selections are final; the league advances to your next pick automatically")
	var clock := UIFactory.label("YOU ARE ON THE CLOCK" if user_on_clock else "LEAGUE SIMULATION ACTIVE", "EyebrowLabel")
	clock.modulate = GridironTheme.WARM if user_on_clock else GridironTheme.TEXT_MUTED
	built.column.add_child(clock)
	var select := UIFactory.button("DRAFT SELECTED PLAYER  ->", "PrimaryButton")
	var player := _career.league.free_agent_by_id(_selected_player_id)
	select.disabled = not user_on_clock or player == null or not FantasyDraftService.selection_error(_career.league, _team, player).is_empty()
	select.pressed.connect(_draft_selected_player)
	built.column.add_child(select)
	var auto_pick := UIFactory.button("AUTO-PICK & ADVANCE", "SecondaryButton")
	auto_pick.disabled = not user_on_clock
	auto_pick.pressed.connect(_auto_pick)
	built.column.add_child(auto_pick)
	var simulate := UIFactory.button("SIMULATE REMAINING DRAFT", "GhostButton")
	simulate.pressed.connect(_simulate_remainder)
	built.column.add_child(simulate)
	return built.card


func _roster_construction_card() -> PanelContainer:
	var built := _card_column("ROSTER CONSTRUCTION", "%d of %d players · %s cap space" % [_team.players.size(), _team.roster_limit, PlayerContract.money_label(_team.cap_space())])
	var counts := FantasyDraftService.roster_counts(_team)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	for position_name in TeamData.ROSTER_POSITIONS:
		var current := int(counts.get(position_name, 0))
		var target := int(FantasyDraftService.TARGET_DEPTH.get(position_name, 1))
		var badge := UIFactory.badge("%s %d/%d" % [position_name, current, target], GridironTheme.ACCENT_DARK if current >= target else Color("2a3a3d"))
		grid.add_child(badge)
	built.column.add_child(grid)
	return built.card


func _recent_picks_card(draft: FantasyDraftStateData) -> PanelContainer:
	var built := _card_column("RECENT PICKS", "Latest selections from around the league")
	var recent := draft.recent_selections(7)
	if recent.is_empty():
		built.column.add_child(UIFactory.label("No selections have been made.", "MutedLabel"))
	for pick in recent:
		var team := _career.league.team_by_id(pick.team_id)
		built.column.add_child(UIFactory.label("#%d  %s  ·  %s %s  ·  OVR %d" % [pick.overall_pick, team.abbreviation, pick.selected_position, pick.selected_player_name, pick.selected_overall], "MutedLabel"))
	return built.card


func _draft_order_card(draft: FantasyDraftStateData) -> PanelContainer:
	var built := _card_column("ROUND ONE ORDER", "Randomized once for this career; even rounds reverse")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 440)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var rows := UIFactory.vbox(5)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for index in range(draft.draft_order.size()):
		var team := _career.league.team_by_id(draft.draft_order[index])
		var row := UIFactory.card("InsetPanel")
		var line := UIFactory.hbox(8)
		row.add_child(line)
		line.add_child(UIFactory.label("%02d" % (index + 1), "MetricLabel"))
		line.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
		line.add_child(UIFactory.label(team.display_name(), "BodyLabel"))
		line.add_child(UIFactory.spacer())
		if team.id == _team.id:
			line.add_child(UIFactory.badge("YOU", GridironTheme.WARM))
		rows.add_child(row)
	built.column.add_child(scroll)
	return built.card


func _add_rule(column: VBoxContainer, title: String, detail: String) -> void:
	var panel := UIFactory.card("InsetPanel")
	var copy := UIFactory.vbox(3)
	panel.add_child(copy)
	copy.add_child(UIFactory.label(title, "EyebrowLabel"))
	copy.add_child(UIFactory.wrapped_label(detail, "MutedLabel"))
	column.add_child(panel)


func _metric_card(title: String, value: String, detail: String) -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.custom_minimum_size = Vector2(190, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(2)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	column.add_child(UIFactory.label(value, "MetricLabel"))
	column.add_child(UIFactory.label(detail, "CaptionLabel"))
	return card


func _mini_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric.add_child(UIFactory.label(value, "BodyLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _card_column(title: String, subtitle: String) -> Dictionary:
	var card := UIFactory.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return {"card": card, "column": column}


func _draft_subtitle(draft: FantasyDraftStateData) -> String:
	if draft.status == FantasyDraftStateData.STATUS_READY:
		return "A randomized, salary-cap-aware snake draft for every active player."
	return "Live league draft · 53 rounds · every selection can be saved and resumed."


func _pick_owner_label(pick: FantasyDraftPickData) -> String:
	if pick == null:
		return "COMPLETE"
	var team := _career.league.team_by_id(pick.team_id)
	return "YOU" if team.id == _team.id else team.abbreviation


func _contract_label(player: PlayerData) -> String:
	return player.contract.summary_label() if player.contract != null else "Projected deal"


func _pool_contains(players: Array[PlayerData], player_id: String) -> bool:
	for player in players:
		if player.id == player_id:
			return true
	return false


func _select_player(player_id: String) -> void:
	_selected_player_id = player_id
	_rebuild()


func _apply_search() -> void:
	_search_text = _search_input.text.strip_edges()
	_selected_player_id = ""
	_rebuild()


func _change_position_filter(index: int) -> void:
	_position_filter = "" if index == 0 else TeamData.ROSTER_POSITIONS[index - 1]
	_selected_player_id = ""
	_rebuild()


func _begin_draft() -> void:
	_show_result(_career.start_fantasy_draft())


func _draft_selected_player() -> void:
	var result := _career.select_fantasy_player(_selected_player_id)
	_selected_player_id = ""
	_show_result(result)


func _auto_pick() -> void:
	var result := _career.auto_pick_fantasy_selection()
	_selected_player_id = ""
	_show_result(result)


func _simulate_remainder() -> void:
	_show_result(_career.simulate_fantasy_draft())


func _show_result(result: Dictionary) -> void:
	_message = str(result.get("message", "Draft action processed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		draft_changed.emit()
	if _career.league.fantasy_draft != null and _career.league.fantasy_draft.is_complete():
		draft_completed.emit()
		return
	_rebuild()


func _apply_responsive_layout() -> void:
	if _body_grid != null:
		_body_grid.columns = 2 if size.x >= 1120 else 1
	if _metric_grid != null:
		_metric_grid.columns = 4 if size.x >= 1060 else (2 if size.x >= 620 else 1)
	if _header_detail != null:
		_header_detail.visible = size.x >= 830
