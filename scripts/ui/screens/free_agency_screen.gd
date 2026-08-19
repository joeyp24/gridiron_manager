extends Control

signal back_requested
signal front_office_requested
signal market_changed

const OFFER_MULTIPLIERS: Array[float] = [0.90, 1.00, 1.10]

var _career: CareerSession
var _team: TeamData
var _position_menu: OptionButton
var _term_menu: OptionButton
var _offer_menu: OptionButton
var _market_list: VBoxContainer
var _detail_host: VBoxContainer
var _market_grid: GridContainer
var _selected_player_id := ""
var _position_filter := "ALL"
var _message := ""
var _message_is_error := false
var _button_group := ButtonGroup.new()
var _selected_term := 3
var _selected_offer_index := 1
var _message_panel: PanelContainer
var _message_label: Label
var _cap_space_label: Label
var _roster_label: Label
var _market_count_label: Label
var _header_subtitle: Label
var _back_button: Button
var _market_guidance: Label
var _toolbar_caption: Label
var _list_caption: Label


func setup(career: CareerSession) -> void:
	_career = career
	_team = career.user_team()


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_rebuild_market()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 720)
	scroll.add_child(page)

	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge("FA", GridironTheme.WARM))
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("FREE AGENCY", "PageTitleLabel"))
	_header_subtitle = UIFactory.label("Evaluate the market, structure an offer, and improve the active roster.", "MutedLabel")
	copy.add_child(_header_subtitle)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var office := UIFactory.button("FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	header.add_child(office)
	_back_button = UIFactory.button("←  CAREER HUB", "GhostButton")
	_back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(_back_button)
	page.add_child(header)

	var cap_card := UIFactory.card("AccentPanel")
	var cap_row := UIFactory.hbox(18)
	cap_card.add_child(cap_row)
	var cap_metric := _metric("CAP SPACE", PlayerContract.money_label(_team.cap_space()))
	_cap_space_label = cap_metric.get_child(0)
	cap_row.add_child(cap_metric)
	var roster_metric := _metric("ROSTER", "%d / %d" % [_team.players.size(), _team.roster_limit])
	_roster_label = roster_metric.get_child(0)
	cap_row.add_child(roster_metric)
	var market_metric := _metric("MARKET", "%d PLAYERS" % _career.league.free_agents.size())
	_market_count_label = market_metric.get_child(0)
	cap_row.add_child(market_metric)
	cap_row.add_child(UIFactory.spacer())
	_market_guidance = UIFactory.wrapped_label("Longer terms can raise demands for older players. Market demand, age, position value, projected role, and offer strength all shape the contract.", "MutedLabel")
	_market_guidance.custom_minimum_size = Vector2(390, 0)
	cap_row.add_child(_market_guidance)
	page.add_child(cap_card)

	_message_panel = UIFactory.card("RaisedCardPanel")
	_message_panel.visible = false
	_message_label = UIFactory.wrapped_label("", "BodyLabel")
	_message_panel.add_child(_message_label)
	page.add_child(_message_panel)

	var toolbar := UIFactory.hbox(10)
	toolbar.add_child(UIFactory.label("POSITION", "EyebrowLabel"))
	_position_menu = OptionButton.new()
	_position_menu.custom_minimum_size = Vector2(145, 44)
	_position_menu.add_item("ALL POSITIONS")
	for position_name in TeamData.ROSTER_POSITIONS:
		_position_menu.add_item(position_name)
	_position_menu.item_selected.connect(_filter_position)
	toolbar.add_child(_position_menu)
	toolbar.add_child(UIFactory.spacer())
	_toolbar_caption = UIFactory.label("MARKET VALUE UPDATES WITH YOUR OFFER", "CaptionLabel")
	toolbar.add_child(_toolbar_caption)
	page.add_child(toolbar)

	_market_grid = GridContainer.new()
	_market_grid.columns = 2
	_market_grid.add_theme_constant_override("h_separation", 14)
	_market_grid.add_theme_constant_override("v_separation", 14)
	_market_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_market_grid)

	var list_card := UIFactory.card()
	list_card.custom_minimum_size = Vector2(470, 565)
	list_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list_column := UIFactory.vbox(10)
	list_card.add_child(list_column)
	var list_heading := UIFactory.hbox(8)
	list_heading.add_child(UIFactory.label("AVAILABLE PLAYERS", "SectionTitleLabel"))
	list_heading.add_child(UIFactory.spacer())
	_list_caption = UIFactory.label("OVR · AGE · ASKING", "CaptionLabel")
	list_heading.add_child(_list_caption)
	list_column.add_child(list_heading)
	var market_scroll := ScrollContainer.new()
	market_scroll.custom_minimum_size = Vector2(0, 485)
	market_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_column.add_child(market_scroll)
	_market_list = UIFactory.vbox(7)
	_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_scroll.add_child(_market_list)
	_market_grid.add_child(list_card)

	var detail_card := UIFactory.card("RaisedCardPanel")
	detail_card.custom_minimum_size = Vector2(470, 565)
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_host = UIFactory.vbox(13)
	detail_card.add_child(_detail_host)
	_market_grid.add_child(detail_card)


func _rebuild_market() -> void:
	if _market_list == null:
		return
	for child in _market_list.get_children():
		_market_list.remove_child(child)
		child.queue_free()
	_button_group = ButtonGroup.new()
	var players := _filtered_players()
	if players.is_empty():
		_selected_player_id = ""
		_market_list.add_child(UIFactory.wrapped_label("No free agents match this position filter.", "MutedLabel"))
		_refresh_summary()
		_rebuild_detail()
		return
	if _career.league.free_agent_by_id(_selected_player_id) == null or not players.any(func(player: PlayerData): return player.id == _selected_player_id):
		_selected_player_id = players.front().id
	for player in players:
		var estimate := TransactionService.market_offer(_career.league, _team, player, 2, 1.0)
		var button := UIFactory.button(
			"%s  %s\nOVR %d  ·  AGE %d  ·  %s / YR" % [player.position, player.full_name, player.overall, player.age, PlayerContract.money_label(estimate.annual_salary)],
			"TeamCardButton"
		)
		button.custom_minimum_size = Vector2(0, 68)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = _button_group
		button.button_pressed = player.id == _selected_player_id
		button.pressed.connect(_select_player.bind(player.id))
		_market_list.add_child(button)
	_refresh_summary()
	_rebuild_detail()


func _rebuild_detail() -> void:
	if _detail_host == null:
		return
	for child in _detail_host.get_children():
		_detail_host.remove_child(child)
		child.queue_free()
	var player := _career.league.free_agent_by_id(_selected_player_id)
	if player == null:
		_detail_host.add_child(UIFactory.label("NO PLAYER SELECTED", "SectionTitleLabel"))
		_detail_host.add_child(UIFactory.wrapped_label("Choose a player from the market to prepare a contract offer.", "MutedLabel"))
		return
	var heading := UIFactory.hbox(10)
	heading.add_child(UIFactory.badge(player.position, _team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(player.full_name, "SectionTitleLabel"))
	identity.add_child(UIFactory.label("Age %d · OVR %d · %s projection" % [player.age, player.overall, TransactionService.projected_role(_team, player)], "CaptionLabel"))
	heading.add_child(identity)
	heading.add_child(UIFactory.label(str(player.overall), "MetricLabel"))
	_detail_host.add_child(heading)

	var ratings := GridContainer.new()
	ratings.columns = 2
	ratings.add_theme_constant_override("h_separation", 14)
	ratings.add_theme_constant_override("v_separation", 8)
	for entry in [["SPEED", player.speed], ["POWER", player.power], ["TECHNIQUE", player.technique], ["AWARENESS", player.awareness]]:
		var bar := UIFactory.stat_bar(entry[0], entry[1], _team.primary_color)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ratings.add_child(bar)
	_detail_host.add_child(ratings)

	var current := _team.player_at(player.position)
	var comparison := UIFactory.card("InsetPanel")
	var comparison_row := UIFactory.hbox(8)
	comparison.add_child(comparison_row)
	comparison_row.add_child(UIFactory.label("CURRENT STARTER", "CaptionLabel"))
	comparison_row.add_child(UIFactory.spacer())
	comparison_row.add_child(UIFactory.label("%s · OVR %d" % [current.full_name, current.overall], "BodyLabel"))
	_detail_host.add_child(comparison)

	var offer_controls := GridContainer.new()
	offer_controls.columns = 2
	offer_controls.add_theme_constant_override("h_separation", 12)
	offer_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var term_column := UIFactory.vbox(5)
	term_column.add_child(UIFactory.label("CONTRACT TERM", "EyebrowLabel"))
	_term_menu = OptionButton.new()
	_term_menu.custom_minimum_size = Vector2(0, 44)
	for years in range(1, 5):
		_term_menu.add_item("%d YEAR%s" % [years, "" if years == 1 else "S"])
	_term_menu.select(_selected_term - 1)
	_term_menu.item_selected.connect(_change_term)
	term_column.add_child(_term_menu)
	offer_controls.add_child(term_column)
	var strength_column := UIFactory.vbox(5)
	strength_column.add_child(UIFactory.label("OFFER STRENGTH", "EyebrowLabel"))
	_offer_menu = OptionButton.new()
	_offer_menu.custom_minimum_size = Vector2(0, 44)
	_offer_menu.add_item("TEAM-FRIENDLY · 90%")
	_offer_menu.add_item("MARKET VALUE · 100%")
	_offer_menu.add_item("PREMIUM · 110%")
	_offer_menu.select(_selected_offer_index)
	_offer_menu.item_selected.connect(_change_offer)
	strength_column.add_child(_offer_menu)
	offer_controls.add_child(strength_column)
	_detail_host.add_child(offer_controls)

	var years := _selected_term
	var multiplier := OFFER_MULTIPLIERS[_selected_offer_index]
	var contract := TransactionService.market_offer(_career.league, _team, player, years, multiplier)
	var offer_card := UIFactory.card("AccentPanel")
	var offer_column := UIFactory.vbox(7)
	offer_card.add_child(offer_column)
	var value_row := GridContainer.new()
	value_row.columns = 2
	value_row.add_theme_constant_override("h_separation", 10)
	value_row.add_theme_constant_override("v_separation", 8)
	value_row.add_child(_metric("TOTAL VALUE", PlayerContract.money_label(contract.total_value())))
	value_row.add_child(_metric("ANNUAL CAP", PlayerContract.money_label(contract.annual_salary)))
	value_row.add_child(_metric("GUARANTEED", PlayerContract.money_label(contract.guaranteed_money)))
	value_row.add_child(_metric("EXPIRES", str(contract.expiration_year())))
	offer_column.add_child(value_row)
	var outlook := TransactionService.offer_outlook(_career.league, _team, player, multiplier)
	var outlook_label := UIFactory.label(outlook, "EyebrowLabel")
	outlook_label.modulate = GridironTheme.ACCENT if multiplier + 0.001 >= TransactionService.minimum_offer_multiplier(_career.league, _team, player) else GridironTheme.WARM
	offer_column.add_child(outlook_label)
	_detail_host.add_child(offer_card)

	var validation_error := RosterValidator.signing_error(_team, player, contract)
	if not validation_error.is_empty():
		var error_label := UIFactory.wrapped_label(validation_error, "MutedLabel")
		error_label.modulate = GridironTheme.DANGER
		_detail_host.add_child(error_label)
	var sign := UIFactory.button("SUBMIT CONTRACT OFFER  →", "PrimaryButton")
	sign.custom_minimum_size = Vector2(0, 48)
	sign.disabled = not validation_error.is_empty() or _career.active_simulator != null
	sign.pressed.connect(_submit_offer.bind(player.id, years, multiplier))
	_detail_host.add_child(sign)


func _filter_position(index: int) -> void:
	_position_filter = "ALL" if index == 0 else TeamData.ROSTER_POSITIONS[index - 1]
	_selected_player_id = ""
	_rebuild_market()


func _select_player(player_id: String) -> void:
	_selected_player_id = player_id
	var player := _career.league.free_agent_by_id(player_id)
	_selected_term = 3 if player != null and player.age <= 29 else 2
	_selected_offer_index = 1
	_rebuild_market()


func _change_term(index: int) -> void:
	_selected_term = index + 1
	_rebuild_detail()


func _change_offer(index: int) -> void:
	_selected_offer_index = index
	_rebuild_detail()


func _submit_offer(player_id: String, years: int, multiplier: float) -> void:
	var result := _career.sign_free_agent(player_id, years, multiplier)
	_message = str(result.get("message", "Contract offer processed."))
	_message_is_error = not bool(result.get("ok", false))
	_show_message()
	if not _message_is_error:
		market_changed.emit()
		_selected_player_id = ""
	_rebuild_market()


func _show_message() -> void:
	if _message_panel == null or _message_label == null:
		return
	_message_panel.visible = not _message.is_empty()
	_message_label.text = _message
	_message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT


func _refresh_summary() -> void:
	if _cap_space_label != null:
		_cap_space_label.text = PlayerContract.money_label(_team.cap_space())
	if _roster_label != null:
		_roster_label.text = "%d / %d" % [_team.players.size(), _team.roster_limit]
	if _market_count_label != null:
		_market_count_label.text = "%d PLAYERS" % _career.league.free_agents.size()


func _filtered_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	for player in _career.league.free_agents:
		if _position_filter == "ALL" or player.position == _position_filter:
			players.append(player)
	players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return players


func _metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.custom_minimum_size = Vector2(105, 0)
	metric.add_child(UIFactory.label(value, "MetricLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _apply_responsive_layout() -> void:
	if _market_grid != null:
		_market_grid.columns = 2 if size.x >= 1040 else 1
	if _header_subtitle != null:
		_header_subtitle.visible = size.x >= 1100
	if _back_button != null:
		_back_button.visible = size.x >= 900
	if _market_guidance != null:
		_market_guidance.visible = size.x >= 900
	if _toolbar_caption != null:
		_toolbar_caption.visible = size.x >= 900
	if _list_caption != null:
		_list_caption.visible = size.x >= 720
