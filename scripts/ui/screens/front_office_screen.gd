extends Control

signal back_requested
signal free_agency_requested
signal trade_center_requested
signal front_office_changed

var _career: CareerSession
var _team: TeamData
var _page: VBoxContainer
var _message := ""
var _message_is_error := false
var _summary_grid: GridContainer
var _body_grid: GridContainer
var _header_subtitle: Label
var _back_button: Button


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
	_page.custom_minimum_size = Vector2(0, 720)
	scroll.add_child(_page)
	_rebuild()


func _rebuild() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_build_header()
	_build_finance_summary()
	if not _message.is_empty():
		var message_card := UIFactory.card("AccentPanel" if not _message_is_error else "RaisedCardPanel")
		var message_label := UIFactory.wrapped_label(_message, "BodyLabel")
		message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT
		message_card.add_child(message_label)
		_page.add_child(message_card)
	_build_body()
	_apply_responsive_layout()


func _build_header() -> void:
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(_team.abbreviation, _team.primary_color))
	var copy := UIFactory.page_heading("CLUB OPERATIONS", "Contracts & Cap")
	_header_subtitle = UIFactory.label("Manage contracts, cap space, roster legality, and club transactions.", "MutedLabel")
	copy.add_child(_header_subtitle)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var trades := UIFactory.button("TRADE CENTER", "SecondaryButton")
	trades.custom_minimum_size = Vector2(145, 46)
	trades.pressed.connect(func(): trade_center_requested.emit())
	header.add_child(trades)
	var market := UIFactory.button("FREE AGENCY  →", "PrimaryButton")
	market.custom_minimum_size = Vector2(165, 46)
	market.pressed.connect(func(): free_agency_requested.emit())
	header.add_child(market)
	_back_button = UIFactory.button("←  CAREER HUB", "GhostButton")
	_back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(_back_button)
	_page.add_child(header)


func _build_finance_summary() -> void:
	_summary_grid = GridContainer.new()
	_summary_grid.columns = 4
	_summary_grid.add_theme_constant_override("h_separation", 12)
	_summary_grid.add_theme_constant_override("v_separation", 12)
	_summary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_summary_grid)
	_summary_grid.add_child(_summary_card("TOTAL PAYROLL", PlayerContract.money_label(_team.payroll()), "Including dead money"))
	_summary_grid.add_child(_summary_card("CAP SPACE", PlayerContract.money_label(_team.cap_space()), "Available this season"))
	_summary_grid.add_child(_summary_card("DEAD CAP", PlayerContract.money_label(_team.dead_cap), "Committed to released players"))
	_summary_grid.add_child(_summary_card("ROSTER", "%d / %d" % [_team.players.size(), _team.roster_limit], "%d-player minimum" % TeamData.MIN_ROSTER_SIZE))
	var usage := roundi(float(_team.payroll()) / float(_team.salary_cap) * 100.0)
	var usage_card := UIFactory.card("HeroPanel")
	var usage_column := UIFactory.vbox(8)
	usage_card.add_child(usage_column)
	var usage_header := UIFactory.hbox(8)
	usage_header.add_child(UIFactory.label("SALARY CAP UTILIZATION", "EyebrowLabel"))
	usage_header.add_child(UIFactory.spacer())
	usage_header.add_child(UIFactory.label("%d%%" % usage, "SectionTitleLabel"))
	usage_column.add_child(usage_header)
	usage_column.add_child(UIFactory.stat_bar("%s OF %s" % [PlayerContract.money_label(_team.payroll()), PlayerContract.money_label(_team.salary_cap)], clampi(usage, 0, 100), _team.primary_color))
	_page.add_child(usage_card)


func _build_body() -> void:
	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)
	_body_grid.add_child(_build_contracts_card())
	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_build_compliance_card())
	side.add_child(_build_transactions_card())
	_body_grid.add_child(side)


func _build_contracts_card() -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(620, 520)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(10)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	heading.add_child(UIFactory.label("CONTRACT LEDGER", "SectionTitleLabel"))
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.label("Sorted by current cap hit", "CaptionLabel"))
	column.add_child(heading)
	var roster_scroll := ScrollContainer.new()
	roster_scroll.custom_minimum_size = Vector2(0, 445)
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(roster_scroll)
	var list := UIFactory.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_scroll.add_child(list)
	var ordered := _team.all_contract_players()
	ordered.sort_custom(func(a: PlayerData, b: PlayerData):
		return a.contract.current_cap_hit() > b.contract.current_cap_hit()
	)
	for player: PlayerData in ordered:
		list.add_child(_contract_row(player))
	return card


func _contract_row(player: PlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(9)
	panel.add_child(row)
	row.add_child(UIFactory.badge(player.position, _team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.custom_minimum_size = Vector2(170, 0)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(player.full_name, "BodyLabel"))
	identity.add_child(UIFactory.label("Age %d · OVR %d · %s" % [player.age, player.overall, player.roster_status], "CaptionLabel"))
	row.add_child(identity)
	row.add_child(_small_metric("ROLE", player.contract.role))
	row.add_child(_small_metric("CAP HIT", PlayerContract.money_label(player.contract.current_cap_hit())))
	row.add_child(_small_metric("APY", PlayerContract.money_label(player.contract.annual_salary)))
	row.add_child(_small_metric("TERM / EXP", "%d YR · %d" % [player.contract.years_remaining, player.contract.expiration_year()]))
	var release := UIFactory.button("RELEASE", "DangerButton")
	release.custom_minimum_size = Vector2(86, 40)
	release.disabled = _team.player_by_id(player.id) == null or not RosterValidator.release_error(_team, player).is_empty() or _career.active_simulator != null
	release.pressed.connect(_release_player.bind(player.id))
	row.add_child(release)
	return panel


func _build_compliance_card() -> PanelContainer:
	var errors := RosterValidator.validate_team(_team)
	if not _career.league.is_offseason():
		errors.append_array(RosterValidator.validate_game_day_roster(_team))
	var card := UIFactory.card("AccentPanel" if errors.is_empty() else "RaisedCardPanel")
	var column := UIFactory.vbox(8)
	card.add_child(column)
	column.add_child(UIFactory.label("ROSTER COMPLIANCE", "SectionTitleLabel"))
	if errors.is_empty():
		column.add_child(UIFactory.label("LEGAL FOR MATCHDAY", "EyebrowLabel"))
		column.add_child(UIFactory.wrapped_label("The club is below the cap, within roster limits, carries every required position group, and has a legal game-day list.", "MutedLabel"))
	else:
		column.add_child(UIFactory.label("ACTION REQUIRED", "EyebrowLabel"))
		for error in errors:
			column.add_child(UIFactory.wrapped_label("• " + error, "MutedLabel"))
	return card


func _build_transactions_card() -> PanelContainer:
	var card := UIFactory.card()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label("LEAGUE TRANSACTIONS", "SectionTitleLabel"))
	column.add_child(UIFactory.label("Latest signings and releases", "CaptionLabel"))
	var transactions := _career.league.recent_transactions(8)
	if transactions.is_empty():
		column.add_child(UIFactory.wrapped_label("No transactions have been filed this season.", "MutedLabel"))
	else:
		for transaction in transactions:
			var team := _career.league.team_by_id(transaction.team_id)
			var entry := UIFactory.card("InsetPanel")
			var entry_column := UIFactory.vbox(2)
			entry.add_child(entry_column)
			entry_column.add_child(UIFactory.label("%s · %s" % [team.abbreviation, transaction.transaction_type.to_upper()], "EyebrowLabel"))
			entry_column.add_child(UIFactory.label(transaction.player_name, "BodyLabel"))
			entry_column.add_child(UIFactory.wrapped_label(transaction.details, "CaptionLabel"))
			column.add_child(entry)
	return card


func _summary_card(title: String, value: String, detail: String) -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.custom_minimum_size = Vector2(190, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(2)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "CaptionLabel"))
	column.add_child(UIFactory.label(value, "MetricLabel"))
	column.add_child(UIFactory.label(detail, "CaptionLabel"))
	return card


func _small_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.custom_minimum_size = Vector2(92, 0)
	metric.add_child(UIFactory.label(value, "BodyLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _release_player(player_id: String) -> void:
	var result := _career.release_player(player_id)
	_message = str(result.get("message", "Roster action completed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		front_office_changed.emit()
	_rebuild()


func _apply_responsive_layout() -> void:
	if _summary_grid != null:
		_summary_grid.columns = 4 if size.x >= 1100 else 2
	if _body_grid != null:
		_body_grid.columns = 2 if size.x >= 1080 else 1
	if _header_subtitle != null:
		_header_subtitle.visible = size.x >= 980
	if _back_button != null:
		_back_button.visible = size.x >= 900
