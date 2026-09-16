extends Control

signal back_requested
signal front_office_requested
signal trade_changed

var _career: CareerSession
var _team: TeamData
var _partner: TeamData
var _partners: Array[TeamData] = []
var _partner_index := 0
var _user_player_ids: Array[String] = []
var _partner_player_ids: Array[String] = []
var _user_pick_ids: Array[String] = []
var _partner_pick_ids: Array[String] = []
var _counter: Dictionary = {}
var _countering_offer_id := ""
var _message := ""
var _message_is_error := false
var _page: VBoxContainer
var _market_grid: GridContainer
var _market_watch_grid: GridContainer
var _asset_grid: GridContainer
var _offer_host: VBoxContainer
var _partner_select: OptionButton
var _trade_block_select: OptionButton
var _header_subtitle: Label
var _back_button: Button
var _user_asset_buttons: Array[BaseButton] = []
var _partner_asset_buttons: Array[BaseButton] = []


func setup(career: CareerSession) -> void:
	_career = career
	_team = career.user_team()
	for team in career.league.teams:
		if team.id != _team.id:
			_partners.append(team)
	_partners.sort_custom(func(a: TeamData, b: TeamData): return a.display_name() < b.display_name())
	if not _partners.is_empty():
		_partner = _partners.front()


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
	_page.custom_minimum_size = Vector2(0, 820)
	scroll.add_child(_page)
	_rebuild()


func _rebuild() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_user_asset_buttons.clear()
	_partner_asset_buttons.clear()
	_build_header()
	_build_market_dashboard()
	_build_partner_selector()
	if not _message.is_empty():
		var message_card := UIFactory.card("RaisedCardPanel" if _message_is_error else "AccentPanel")
		var message_label := UIFactory.wrapped_label(_message, "BodyLabel")
		message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT
		message_card.add_child(message_label)
		_page.add_child(message_card)
	_asset_grid = GridContainer.new()
	_asset_grid.columns = 3
	_asset_grid.add_theme_constant_override("h_separation", 14)
	_asset_grid.add_theme_constant_override("v_separation", 14)
	_asset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_asset_grid)
	_asset_grid.add_child(_build_team_assets(_team, true))
	_asset_grid.add_child(_build_offer_card())
	_asset_grid.add_child(_build_team_assets(_partner, false))
	_page.add_child(_build_trade_history())
	_apply_responsive_layout()


func _build_header() -> void:
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(_team.abbreviation, _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("TRADE CENTER", "PageTitleLabel"))
	_header_subtitle = UIFactory.label("Manage the trade block, review incoming offers, and negotiate across the league.", "MutedLabel")
	copy.add_child(_header_subtitle)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	header.add_child(UIFactory.badge(TradeService.trade_window_label(_career.league), GridironTheme.ACCENT if TradeService.trades_open(_career.league) else GridironTheme.DANGER))
	var office := UIFactory.button("FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	header.add_child(office)
	_back_button = UIFactory.button("←  CAREER HUB", "GhostButton")
	_back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(_back_button)
	_page.add_child(header)


func _build_market_dashboard() -> void:
	var section_header := UIFactory.hbox(10)
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("LIVE TRADE MARKET", "SectionTitleLabel"))
	copy.add_child(UIFactory.label("Team needs, competitive direction, and roster value drive every offer.", "CaptionLabel"))
	section_header.add_child(copy)
	section_header.add_child(UIFactory.spacer())
	section_header.add_child(UIFactory.badge("%d ACTIVE OFFER%s" % [
		TradeMarketService.pending_offers_for_user(_career.league).size(),
		"" if TradeMarketService.pending_offers_for_user(_career.league).size() == 1 else "S",
	], GridironTheme.WARM))
	_page.add_child(section_header)

	_market_grid = GridContainer.new()
	_market_grid.columns = 2
	_market_grid.add_theme_constant_override("h_separation", 14)
	_market_grid.add_theme_constant_override("v_separation", 14)
	_market_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_market_grid)
	_market_grid.add_child(_build_trade_block_card())
	_market_grid.add_child(_build_incoming_offers_card())
	_page.add_child(_build_market_watch_card())


func _build_trade_block_card() -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(420, 0)
	var column := UIFactory.vbox(9)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	var title_copy := UIFactory.vbox(1)
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_child(UIFactory.label("YOUR TRADE BLOCK", "SectionTitleLabel"))
	title_copy.add_child(UIFactory.label("Listed players are evaluated by every AI front office now and after each week.", "CaptionLabel"))
	heading.add_child(title_copy)
	var block := _career.league.trade_block_for(_team.id)
	heading.add_child(UIFactory.badge("%d / %d" % [block.size(), TradeMarketService.MAX_USER_BLOCK_PLAYERS], _team.primary_color))
	column.add_child(heading)
	column.add_child(UIFactory.divider())
	var add_row := UIFactory.hbox(8)
	_trade_block_select = OptionButton.new()
	_trade_block_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_trade_block_select.custom_minimum_size = Vector2(280, 42)
	var available := _team.players.duplicate()
	available.sort_custom(func(a: PlayerData, b: PlayerData):
		if a.overall != b.overall:
			return a.overall > b.overall
		return a.full_name < b.full_name
	)
	for player: PlayerData in available:
		if player.id in block or player.contract == null:
			continue
		_trade_block_select.add_item("%s · %s · %d OVR" % [player.position, player.full_name, player.overall])
		_trade_block_select.set_item_metadata(_trade_block_select.item_count - 1, player.id)
	add_row.add_child(_trade_block_select)
	var add_button := UIFactory.button("ADD TO BLOCK", "PrimaryButton")
	add_button.disabled = _trade_block_select.item_count == 0 or not TradeService.trades_open(_career.league) or _career.active_simulator != null
	add_button.pressed.connect(_add_trade_block_player)
	add_row.add_child(add_button)
	column.add_child(add_row)
	if block.is_empty():
		var empty := UIFactory.card("InsetPanel")
		empty.add_child(UIFactory.wrapped_label("No players are listed. Add a player to invite offers without committing to a trade.", "MutedLabel"))
		column.add_child(empty)
	else:
		for player_id in block:
			var player := _team.player_by_id(player_id)
			if player != null:
				column.add_child(_trade_block_player_row(player))
	var needs := TradeMarketService.team_needs(_career.league, _team, 3)
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 7)
	footer.add_theme_constant_override("v_separation", 7)
	footer.add_child(UIFactory.badge(TradeMarketService.team_direction(_career.league, _team).to_upper(), GridironTheme.ACCENT))
	for need in needs:
		footer.add_child(UIFactory.badge("NEED %s" % str(need.get("position", "")), GridironTheme.WARM))
	column.add_child(footer)
	return card


func _trade_block_player_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	row.add_child(UIFactory.badge(player.position, _team.primary_color))
	var identity := UIFactory.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	identity.add_child(UIFactory.label("%d OVR · AGE %d · VALUE %d" % [player.overall, player.age, TradeService.player_trade_value(player)], "CaptionLabel"))
	row.add_child(identity)
	var remove := UIFactory.button("REMOVE", "GhostButton")
	remove.disabled = _career.active_simulator != null
	remove.pressed.connect(_remove_trade_block_player.bind(player.id))
	row.add_child(remove)
	return panel


func _build_incoming_offers_card() -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(420, 0)
	var column := UIFactory.vbox(9)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	var title_copy := UIFactory.vbox(1)
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_child(UIFactory.label("INCOMING OFFERS", "SectionTitleLabel"))
	title_copy.add_child(UIFactory.label("Accept, decline, or load any proposal into the Deal Room as a counter.", "CaptionLabel"))
	heading.add_child(title_copy)
	column.add_child(heading)
	column.add_child(UIFactory.divider())
	var offers := TradeMarketService.pending_offers_for_user(_career.league)
	if offers.is_empty():
		var empty := UIFactory.card("InsetPanel")
		var empty_copy := UIFactory.vbox(3)
		empty.add_child(empty_copy)
		empty_copy.add_child(UIFactory.label("NO ACTIVE OFFERS", "EyebrowLabel"))
		empty_copy.add_child(UIFactory.wrapped_label("Place a player on the trade block to alert interested teams. New proposals can also arrive when a week is completed.", "MutedLabel"))
		column.add_child(empty)
	else:
		for offer in offers:
			column.add_child(_incoming_offer_card(offer))
	var recent := TradeMarketService.recent_offers_for_user(_career.league, 8)
	var resolved_count := 0
	for offer in recent:
		if not offer.is_pending():
			resolved_count += 1
	if resolved_count > 0:
		column.add_child(UIFactory.label("%d RECENT RESOLVED OFFER%s SAVED IN MARKET HISTORY" % [resolved_count, "" if resolved_count == 1 else "S"], "CaptionLabel"))
	return card


func _incoming_offer_card(offer: TradeOfferData) -> PanelContainer:
	var proposer := _career.league.team_by_id(offer.proposing_team_id)
	var panel := UIFactory.card("AccentPanel")
	var column := UIFactory.vbox(6)
	panel.add_child(column)
	var heading := UIFactory.hbox(7)
	heading.add_child(UIFactory.badge(proposer.abbreviation, proposer.primary_color))
	var heading_copy := UIFactory.vbox(0)
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_child(UIFactory.label(proposer.display_name(), "BodyLabel"))
	heading_copy.add_child(UIFactory.label("EXPIRES AFTER WEEK %d" % offer.expires_week, "CaptionLabel"))
	heading.add_child(heading_copy)
	heading.add_child(UIFactory.badge(TradeMarketService.team_direction(_career.league, proposer).to_upper(), GridironTheme.WARM))
	column.add_child(heading)
	column.add_child(_offer_package_panel("YOU RECEIVE", offer.proposer_asset_labels, offer.proposer_value, proposer.primary_color))
	column.add_child(_offer_package_panel("YOU SEND", offer.responder_asset_labels, offer.responder_value, _team.primary_color))
	var actions := UIFactory.hbox(7)
	var accept := UIFactory.button("ACCEPT", "PrimaryButton")
	accept.disabled = _career.active_simulator != null
	accept.pressed.connect(_accept_market_offer.bind(offer.id))
	actions.add_child(accept)
	var counter := UIFactory.button("COUNTER", "SecondaryButton")
	counter.disabled = _career.active_simulator != null
	counter.pressed.connect(_load_market_counter.bind(offer.id))
	actions.add_child(counter)
	var decline := UIFactory.button("DECLINE", "GhostButton")
	decline.disabled = _career.active_simulator != null
	decline.pressed.connect(_decline_market_offer.bind(offer.id))
	actions.add_child(decline)
	column.add_child(actions)
	return panel


func _offer_package_panel(title: String, labels: Array[String], value: int, color: Color) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(2)
	panel.add_child(column)
	var header := UIFactory.hbox(6)
	header.add_child(UIFactory.label(title, "EyebrowLabel"))
	header.add_child(UIFactory.spacer())
	var value_label := UIFactory.label("%d VALUE" % value, "CaptionLabel")
	value_label.modulate = color
	header.add_child(value_label)
	column.add_child(header)
	for label_text in labels:
		column.add_child(UIFactory.wrapped_label(label_text, "BodyLabel"))
	return panel


func _build_market_watch_card() -> PanelContainer:
	var card := UIFactory.card()
	var column := UIFactory.vbox(8)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	var copy := UIFactory.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label("LEAGUE MARKET WATCH", "SectionTitleLabel"))
	copy.add_child(UIFactory.label("AI clubs protect their core, shop surplus talent, and buy according to roster needs.", "CaptionLabel"))
	heading.add_child(copy)
	column.add_child(heading)
	_market_watch_grid = GridContainer.new()
	_market_watch_grid.columns = 3
	_market_watch_grid.add_theme_constant_override("h_separation", 8)
	_market_watch_grid.add_theme_constant_override("v_separation", 8)
	_market_watch_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_market_watch_grid)
	var entries: Array[Dictionary] = []
	for team in _partners:
		for player_id in _career.league.trade_block_for(team.id):
			var player := team.player_by_id(player_id)
			if player != null:
				entries.append({"team": team, "player": player, "value": TradeService.player_trade_value(player, _team)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("value", 0)) > int(b.get("value", 0)))
	for entry in entries.slice(0, mini(entries.size(), 6)):
		_market_watch_grid.add_child(_market_watch_entry(entry))
	if entries.is_empty():
		_market_watch_grid.add_child(UIFactory.wrapped_label("No AI-listed players are available in the current trade window.", "MutedLabel"))
	return card


func _market_watch_entry(entry: Dictionary) -> PanelContainer:
	var team: TeamData = entry.get("team")
	var player: PlayerData = entry.get("player")
	var panel := UIFactory.card("InsetPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(3)
	panel.add_child(column)
	var header := UIFactory.hbox(6)
	header.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	header.add_child(UIFactory.label(TradeMarketService.team_direction(_career.league, team).to_upper(), "CaptionLabel"))
	column.add_child(header)
	column.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	var needs := TradeMarketService.team_needs(_career.league, team, 2)
	var need_labels: Array[String] = []
	for need in needs:
		need_labels.append(str(need.get("position", "")))
	column.add_child(UIFactory.label("%s · %d OVR · NEEDS %s" % [player.position, player.overall, "/".join(need_labels)], "CaptionLabel"))
	return panel


func _build_partner_selector() -> void:
	var card := UIFactory.card("RaisedCardPanel")
	var row := UIFactory.hbox(12)
	card.add_child(row)
	var copy := UIFactory.vbox(1)
	copy.custom_minimum_size = Vector2(210, 0)
	copy.add_child(UIFactory.label("TRADE PARTNER", "EyebrowLabel"))
	copy.add_child(UIFactory.label("Select a front office to negotiate with", "CaptionLabel"))
	row.add_child(copy)
	_partner_select = OptionButton.new()
	_partner_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_partner_select.custom_minimum_size = Vector2(280, 44)
	for team in _partners:
		_partner_select.add_item("%s · %s %s" % [team.abbreviation, team.city, team.nickname])
	_partner_select.select(clampi(_partner_index, 0, maxi(_partners.size() - 1, 0)))
	_partner_select.item_selected.connect(_select_partner)
	row.add_child(_partner_select)
	if _partner != null:
		row.add_child(UIFactory.badge(TradeMarketService.team_direction(_career.league, _partner).to_upper(), GridironTheme.WARM))
		row.add_child(_small_metric("PARTNER CAP", PlayerContract.money_label(_partner.cap_space())))
		row.add_child(_small_metric("PARTNER OVR", str(_partner.overall_rating())))
	_page.add_child(card)


func _build_team_assets(team: TeamData, user_side: bool) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(350, 640)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(10)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	heading.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label("YOU SEND" if user_side else "YOU RECEIVE", "EyebrowLabel"))
	identity.add_child(UIFactory.label(team.display_name(), "SectionTitleLabel"))
	heading.add_child(identity)
	column.add_child(heading)
	var summary := HFlowContainer.new()
	summary.add_theme_constant_override("h_separation", 10)
	summary.add_child(UIFactory.label("%d PLAYERS" % team.players.size(), "CaptionLabel"))
	summary.add_child(UIFactory.label("%s CAP" % PlayerContract.money_label(team.cap_space()), "CaptionLabel"))
	summary.add_child(UIFactory.label("%d PICKS" % TradeService.picks_owned_by(_career.league, team.id).size(), "CaptionLabel"))
	column.add_child(summary)
	column.add_child(UIFactory.divider())
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0, 535)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(list_scroll)
	var list := UIFactory.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)
	list.add_child(UIFactory.label("PLAYERS", "EyebrowLabel"))
	var players := team.players.duplicate()
	players.sort_custom(func(a: PlayerData, b: PlayerData):
		var a_value := TradeService.player_trade_value(a, _partner if user_side else _team)
		var b_value := TradeService.player_trade_value(b, _partner if user_side else _team)
		return a_value > b_value
	)
	for player: PlayerData in players:
		list.add_child(_player_asset_row(team, player, user_side))
	list.add_child(UIFactory.divider())
	list.add_child(UIFactory.label("DRAFT CAPITAL", "EyebrowLabel"))
	for pick in TradeService.picks_owned_by(_career.league, team.id):
		list.add_child(_pick_asset_row(pick, user_side))
	return card


func _player_asset_row(team: TeamData, player: PlayerData, user_side: bool) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	var toggle := CheckButton.new()
	toggle.button_pressed = player.id in (_user_player_ids if user_side else _partner_player_ids)
	toggle.disabled = not TradeService.trades_open(_career.league) or _career.active_simulator != null
	toggle.toggled.connect(_toggle_player.bind(user_side, player.id))
	row.add_child(toggle)
	if user_side:
		_user_asset_buttons.append(toggle)
	else:
		_partner_asset_buttons.append(toggle)
	row.add_child(UIFactory.badge(player.position, team.primary_color))
	var identity := UIFactory.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var player_name := UIFactory.label(player.full_name, "BodyLabel")
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	player_name.clip_text = true
	identity.add_child(player_name)
	var contract_label := UIFactory.label("Age %d · %s · %d yr" % [player.age, PlayerContract.money_label(player.contract.annual_salary), player.contract.years_remaining], "CaptionLabel")
	contract_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	contract_label.clip_text = true
	identity.add_child(contract_label)
	row.add_child(identity)
	var value := TradeService.player_trade_value(player, _partner if user_side else _team)
	row.add_child(_small_metric("OVR / VALUE", "%d · %d" % [player.overall, value]))
	return panel


func _pick_asset_row(pick: DraftPickData, user_side: bool) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	var toggle := CheckButton.new()
	toggle.button_pressed = pick.id in (_user_pick_ids if user_side else _partner_pick_ids)
	toggle.disabled = not TradeService.trades_open(_career.league) or _career.active_simulator != null
	toggle.toggled.connect(_toggle_pick.bind(user_side, pick.id))
	row.add_child(toggle)
	if user_side:
		_user_asset_buttons.append(toggle)
	else:
		_partner_asset_buttons.append(toggle)
	var identity := UIFactory.vbox(0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label("%d ROUND %d" % [pick.draft_year, pick.round_number], "BodyLabel"))
	identity.add_child(UIFactory.label(TradeService.pick_description(_career.league, pick).get_slice(" · ", 1), "CaptionLabel"))
	row.add_child(identity)
	row.add_child(_small_metric("TRADE VALUE", str(TradeService.draft_pick_value(_career.league, pick))))
	return panel


func _build_offer_card() -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.custom_minimum_size = Vector2(350, 640)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_host = UIFactory.vbox(10)
	card.add_child(_offer_host)
	_refresh_offer_summary()
	return card


func _refresh_offer_summary() -> void:
	if _offer_host == null:
		return
	for child in _offer_host.get_children():
		_offer_host.remove_child(child)
		child.queue_free()
	_offer_host.add_child(UIFactory.label("DEAL ROOM", "SectionTitleLabel"))
	_offer_host.add_child(UIFactory.label("AI evaluation updates as assets are selected", "CaptionLabel"))
	_offer_host.add_child(UIFactory.divider())
	var preview := _career.preview_trade(_partner.id, _user_player_ids, _partner_player_ids, _user_pick_ids, _partner_pick_ids)
	var selected_total := _user_player_ids.size() + _partner_player_ids.size() + _user_pick_ids.size() + _partner_pick_ids.size()
	var interest := str(preview.get("interest", TradeProposalData.STATUS_REJECTED))
	var status_text := "BUILD AN OFFER" if selected_total == 0 else interest.to_upper()
	var status_color := GridironTheme.WARM if selected_total == 0 else (GridironTheme.ACCENT if interest == TradeProposalData.STATUS_ACCEPTED else (Color("f5a623") if interest == TradeProposalData.STATUS_COUNTERED else GridironTheme.DANGER))
	_offer_host.add_child(UIFactory.badge(status_text, status_color))
	var values := GridContainer.new()
	values.columns = 2
	values.add_theme_constant_override("h_separation", 8)
	values.add_theme_constant_override("v_separation", 8)
	values.add_child(_value_card("VALUE SENT", int(preview.get("proposer_value", 0)), _team.primary_color))
	values.add_child(_value_card("VALUE RECEIVED", int(preview.get("responder_value", 0)), _partner.primary_color))
	_offer_host.add_child(values)
	_offer_host.add_child(_package_summary("YOUR PACKAGE", _user_player_ids.size(), _user_pick_ids.size()))
	_offer_host.add_child(_package_summary("RETURN PACKAGE", _partner_player_ids.size(), _partner_pick_ids.size()))
	_offer_host.add_child(UIFactory.divider())
	_offer_host.add_child(UIFactory.label("CAP PROJECTION", "EyebrowLabel"))
	_offer_host.add_child(_cap_row(_team, int(preview.get("proposer_projected_payroll", _team.payroll()))))
	_offer_host.add_child(_cap_row(_partner, int(preview.get("responder_projected_payroll", _partner.payroll()))))
	var errors: Array = preview.get("errors", [])
	if not errors.is_empty():
		var validation := UIFactory.card("InsetPanel")
		var validation_column := UIFactory.vbox(4)
		validation.add_child(validation_column)
		validation_column.add_child(UIFactory.label("DEAL CHECK", "EyebrowLabel"))
		for error in errors.slice(0, mini(errors.size(), 4)):
			validation_column.add_child(UIFactory.wrapped_label("• " + str(error), "CaptionLabel"))
		_offer_host.add_child(validation)
	var submit := UIFactory.button("SUBMIT OFFER  →", "PrimaryButton")
	submit.disabled = not bool(preview.get("ok", false)) or _career.active_simulator != null
	submit.pressed.connect(_submit_trade)
	_offer_host.add_child(submit)
	if not _counter.is_empty():
		_offer_host.add_child(_build_counter_card())


func _build_counter_card() -> PanelContainer:
	var card := UIFactory.card("AccentPanel")
	var column := UIFactory.vbox(7)
	card.add_child(column)
	column.add_child(UIFactory.label("COUNTEROFFER RECEIVED", "EyebrowLabel"))
	column.add_child(UIFactory.wrapped_label("%s has adjusted the package and will approve these terms." % _partner.display_name(), "BodyLabel"))
	column.add_child(UIFactory.label("YOU SEND · %d VALUE" % int(_counter.get("proposer_value", 0)), "CaptionLabel"))
	for label_text in _counter_asset_labels(true):
		column.add_child(UIFactory.wrapped_label("• " + label_text, "CaptionLabel"))
	column.add_child(UIFactory.label("YOU RECEIVE · %d VALUE" % int(_counter.get("responder_value", 0)), "CaptionLabel"))
	for label_text in _counter_asset_labels(false):
		column.add_child(UIFactory.wrapped_label("• " + label_text, "CaptionLabel"))
	var accept := UIFactory.button("ACCEPT COUNTER", "PrimaryButton")
	accept.pressed.connect(_accept_counter)
	column.add_child(accept)
	var decline := UIFactory.button("DECLINE", "GhostButton")
	decline.pressed.connect(func(): _counter.clear(); _refresh_offer_summary())
	column.add_child(decline)
	return card


func _build_trade_history() -> PanelContainer:
	var card := UIFactory.card()
	var column := UIFactory.vbox(8)
	card.add_child(column)
	column.add_child(UIFactory.label("TRADE WIRE", "SectionTitleLabel"))
	column.add_child(UIFactory.label("Completed league deals are permanently recorded in the career save.", "CaptionLabel"))
	var shown := 0
	for trade in _career.league.trade_history:
		if shown >= 6:
			break
		var entry := UIFactory.card("InsetPanel")
		var entry_column := UIFactory.vbox(2)
		entry.add_child(entry_column)
		entry_column.add_child(UIFactory.label("%d · WEEK %d · ACCEPTED" % [trade.season_year, trade.week], "EyebrowLabel"))
		entry_column.add_child(UIFactory.wrapped_label(trade.summary, "BodyLabel"))
		column.add_child(entry)
		shown += 1
	if shown == 0:
		column.add_child(UIFactory.wrapped_label("No trades have been completed in this career.", "MutedLabel"))
	return card


func _value_card(title: String, value: int, color: Color) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(2)
	card.add_child(column)
	var metric := UIFactory.label(str(value), "MetricLabel")
	metric.modulate = color
	column.add_child(metric)
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	return card


func _package_summary(title: String, player_count: int, pick_count: int) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	card.add_child(row)
	row.add_child(UIFactory.label(title, "EyebrowLabel"))
	row.add_child(UIFactory.spacer())
	row.add_child(UIFactory.label("%d PLAYER%s · %d PICK%s" % [player_count, "" if player_count == 1 else "S", pick_count, "" if pick_count == 1 else "S"], "CaptionLabel"))
	return card


func _cap_row(team: TeamData, projected_payroll: int) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	card.add_child(row)
	row.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	row.add_child(UIFactory.label(PlayerContract.money_label(projected_payroll), "BodyLabel"))
	row.add_child(UIFactory.spacer())
	var space := team.salary_cap - projected_payroll
	var space_label := UIFactory.label("%s SPACE" % PlayerContract.money_label(space), "CaptionLabel")
	space_label.modulate = GridironTheme.DANGER if space < 0 else GridironTheme.TEXT_MUTED
	row.add_child(space_label)
	return card


func _small_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.custom_minimum_size = Vector2(78, 0)
	metric.add_child(UIFactory.label(value, "BodyLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _select_partner(index: int) -> void:
	if index < 0 or index >= _partners.size():
		return
	_partner_index = index
	_partner = _partners[index]
	_user_player_ids.clear()
	_partner_player_ids.clear()
	_user_pick_ids.clear()
	_partner_pick_ids.clear()
	_counter.clear()
	_countering_offer_id = ""
	_message = ""
	_rebuild()


func _add_trade_block_player() -> void:
	if _trade_block_select == null or _trade_block_select.selected < 0:
		return
	var player_id := str(_trade_block_select.get_item_metadata(_trade_block_select.selected))
	var result := _career.toggle_trade_block(player_id, true)
	_message = str(result.get("message", "Trade block updated."))
	_message_is_error = not bool(result.get("ok", false))
	if bool(result.get("ok", false)):
		trade_changed.emit()
	_rebuild()


func _remove_trade_block_player(player_id: String) -> void:
	var result := _career.toggle_trade_block(player_id, false)
	_message = str(result.get("message", "Trade block updated."))
	_message_is_error = not bool(result.get("ok", false))
	if bool(result.get("ok", false)):
		trade_changed.emit()
	_rebuild()


func _accept_market_offer(offer_id: String) -> void:
	var result := _career.accept_incoming_trade_offer(offer_id)
	_message = str(result.get("message", "Trade offer processed."))
	_message_is_error = not bool(result.get("ok", false))
	if bool(result.get("executed", false)):
		_clear_offer()
		trade_changed.emit()
	_rebuild()


func _decline_market_offer(offer_id: String) -> void:
	var result := _career.decline_incoming_trade_offer(offer_id)
	_message = str(result.get("message", "Trade offer processed."))
	_message_is_error = not bool(result.get("ok", false))
	if bool(result.get("ok", false)):
		trade_changed.emit()
	_rebuild()


func _load_market_counter(offer_id: String) -> void:
	var offer := _career.league.trade_offer_by_id(offer_id)
	if offer == null or not offer.is_pending():
		_message = "That offer is no longer available."
		_message_is_error = true
		_rebuild()
		return
	for index in range(_partners.size()):
		if _partners[index].id == offer.proposing_team_id:
			_partner_index = index
			_partner = _partners[index]
			break
	_user_player_ids = offer.responder_player_ids.duplicate()
	_partner_player_ids = offer.proposer_player_ids.duplicate()
	_user_pick_ids = offer.responder_pick_ids.duplicate()
	_partner_pick_ids = offer.proposer_pick_ids.duplicate()
	_counter.clear()
	_countering_offer_id = offer.id
	_message = "Offer terms loaded into the Deal Room. Adjust the package, then submit your counter."
	_message_is_error = false
	_rebuild()


func _toggle_player(pressed: bool, user_side: bool, player_id: String) -> void:
	var selected := _user_player_ids if user_side else _partner_player_ids
	if pressed and player_id not in selected:
		selected.append(player_id)
	elif not pressed:
		selected.erase(player_id)
	_counter.clear()
	_refresh_offer_summary()


func _toggle_pick(pressed: bool, user_side: bool, pick_id: String) -> void:
	var selected := _user_pick_ids if user_side else _partner_pick_ids
	if pressed and pick_id not in selected:
		selected.append(pick_id)
	elif not pressed:
		selected.erase(pick_id)
	_counter.clear()
	_refresh_offer_summary()


func _submit_trade() -> void:
	var was_countering := not _countering_offer_id.is_empty()
	var result: Dictionary
	if was_countering:
		result = _career.counter_incoming_trade_offer(
			_countering_offer_id,
			_user_player_ids,
			_partner_player_ids,
			_user_pick_ids,
			_partner_pick_ids
		)
	else:
		result = _career.submit_trade(
			_partner.id,
			_user_player_ids,
			_partner_player_ids,
			_user_pick_ids,
			_partner_pick_ids
		)
	_message = str(result.get("message", "Trade proposal processed."))
	_message_is_error = not bool(result.get("ok", false))
	_counter = Dictionary(result.get("counter", {})).duplicate(true)
	if bool(result.get("executed", false)) or (bool(result.get("ok", false)) and was_countering):
		trade_changed.emit()
	if bool(result.get("executed", false)):
		_clear_offer()
	_rebuild()


func _accept_counter() -> void:
	var result := _career.accept_trade_counter(_counter, _countering_offer_id)
	_message = str(result.get("message", "Counteroffer processed."))
	_message_is_error = not bool(result.get("ok", false))
	if bool(result.get("executed", false)):
		_clear_offer()
		trade_changed.emit()
	else:
		_counter.clear()
	_rebuild()


func _clear_offer() -> void:
	_user_player_ids.clear()
	_partner_player_ids.clear()
	_user_pick_ids.clear()
	_partner_pick_ids.clear()
	_counter.clear()
	_countering_offer_id = ""


func _counter_asset_labels(proposer_side: bool) -> Array[String]:
	var source_team := _team if proposer_side else _partner
	var player_ids: Array = _counter.get("proposer_player_ids" if proposer_side else "responder_player_ids", [])
	var pick_ids: Array = _counter.get("proposer_pick_ids" if proposer_side else "responder_pick_ids", [])
	var labels: Array[String] = []
	for player_id in player_ids:
		var player := source_team.player_by_id(str(player_id))
		if player != null:
			labels.append("%s · %s · %d OVR" % [player.full_name, player.position, player.overall])
	for pick_id in pick_ids:
		var pick := TradeService.future_pick_by_id(_career.league, str(pick_id))
		if pick != null:
			labels.append(TradeService.pick_description(_career.league, pick).capitalize())
	return labels


func _apply_responsive_layout() -> void:
	if _market_grid != null:
		_market_grid.columns = 2 if size.x >= 980 else 1
	if _market_watch_grid != null:
		_market_watch_grid.columns = 3 if size.x >= 1280 else (2 if size.x >= 760 else 1)
	if _asset_grid != null:
		_asset_grid.columns = 3 if size.x >= 1180 else 1
	if _header_subtitle != null:
		_header_subtitle.visible = size.x >= 1500
	if _back_button != null:
		_back_button.visible = size.x >= 880
