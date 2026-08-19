extends Control

signal back_requested
signal free_agency_requested
signal front_office_requested
signal offseason_changed

const OFFER_MULTIPLIERS: Array[float] = [0.90, 1.00, 1.10]

var _career: CareerSession
var _team: TeamData
var _page: VBoxContainer
var _body_grid: GridContainer
var _summary_grid: GridContainer
var _header_subtitle: Label
var _back_button: Button
var _selected_player_id := ""
var _selected_term := 2
var _selected_offer_index := 1
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
	_page.custom_minimum_size = Vector2(0, 760)
	scroll.add_child(_page)
	_rebuild()


func _rebuild() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	_build_header()
	_build_stage_tracker()
	_build_summary()
	if not _message.is_empty():
		var message_card := UIFactory.card("RaisedCardPanel")
		var message_label := UIFactory.wrapped_label(_message, "BodyLabel")
		message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT
		message_card.add_child(message_label)
		_page.add_child(message_card)
	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)
	match _career.league.phase:
		LeagueState.PHASE_SEASON_REVIEW, "Complete":
			_build_season_review()
		LeagueState.PHASE_RE_SIGNING:
			_build_re_signing()
		LeagueState.PHASE_PLAYER_DEVELOPMENT:
			_build_development()
	_apply_responsive_layout()


func _build_header() -> void:
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(str(_career.league.season_year), _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.add_child(UIFactory.label("OFFSEASON CONTROL ROOM", "PageTitleLabel"))
	_header_subtitle = UIFactory.label("Close one campaign, make personnel decisions, and prepare the next.", "MutedLabel")
	copy.add_child(_header_subtitle)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var office := UIFactory.button("FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	header.add_child(office)
	_back_button = UIFactory.button("BACK TO CAREER", "GhostButton")
	_back_button.pressed.connect(func(): back_requested.emit())
	header.add_child(_back_button)
	_page.add_child(header)


func _build_stage_tracker() -> void:
	var tracker := HFlowContainer.new()
	tracker.add_theme_constant_override("h_separation", 8)
	tracker.add_theme_constant_override("v_separation", 8)
	var stages := [
		{"phase": LeagueState.PHASE_SEASON_REVIEW, "label": "01  SEASON REVIEW"},
		{"phase": LeagueState.PHASE_RE_SIGNING, "label": "02  RE-SIGNING"},
		{"phase": LeagueState.PHASE_PLAYER_DEVELOPMENT, "label": "03  DEVELOPMENT"},
		{"phase": "New League Year", "label": "04  NEW LEAGUE YEAR"},
	]
	var active_index := _stage_index(_career.league.phase)
	for index in range(stages.size()):
		var stage: Dictionary = stages[index]
		var color := _team.primary_color if index == active_index else GridironTheme.BORDER
		var badge := UIFactory.badge(str(stage["label"]), color)
		badge.modulate = Color.WHITE if index <= active_index else Color(1, 1, 1, 0.55)
		tracker.add_child(badge)
	_page.add_child(tracker)


func _build_summary() -> void:
	_summary_grid = GridContainer.new()
	_summary_grid.columns = 4
	_summary_grid.add_theme_constant_override("h_separation", 12)
	_summary_grid.add_theme_constant_override("v_separation", 12)
	_summary_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_summary_grid)
	var record := _career.league.latest_season_record()
	_summary_grid.add_child(_summary_card("SEASON", str(_career.league.season_year), _career.league.phase))
	_summary_grid.add_child(_summary_card("CLUB RECORD", record.user_record if record != null else "0-0", _team.display_name()))
	_summary_grid.add_child(_summary_card("EXPIRING", str(_career.expiring_players().size()), "Contracts requiring decisions"))
	_summary_grid.add_child(_summary_card("CAP SPACE", PlayerContract.money_label(_team.cap_space()), "%d / %d rostered" % [_team.players.size(), _team.roster_limit]))


func _build_season_review() -> void:
	var league := _career.league
	var record := league.latest_season_record()
	var review := _card_column("SEASON REVIEW", "A permanent snapshot of the completed campaign")
	review.card.custom_minimum_size = Vector2(520, 0)
	if record == null:
		review.column.add_child(UIFactory.wrapped_label("The final season record is unavailable.", "MutedLabel"))
	else:
		var champion := league.team_by_id(record.champion_team_id)
		var title_panel := UIFactory.card("AccentPanel")
		var title_row := UIFactory.hbox(12)
		title_panel.add_child(title_row)
		title_row.add_child(UIFactory.badge(champion.abbreviation, champion.primary_color))
		var title_copy := UIFactory.vbox(2)
		title_copy.add_child(UIFactory.label("%d LEAGUE CHAMPIONS" % record.season_year, "EyebrowLabel"))
		title_copy.add_child(UIFactory.label(champion.display_name(), "SectionTitleLabel"))
		title_copy.add_child(UIFactory.label(record.championship_score, "MutedLabel"))
		title_row.add_child(title_copy)
		review.column.add_child(title_panel)
		for conference in ["Atlantic", "Frontier"]:
			review.column.add_child(UIFactory.label(conference.to_upper(), "EyebrowLabel"))
			for entry in record.standings:
				if str(entry.get("conference", "")) == conference:
					review.column.add_child(_history_standing_row(entry))
	_body_grid.add_child(review.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var decision := _card_column("NEXT: RE-SIGNING", "Secure core players before contracts expire")
	decision.column.add_child(UIFactory.wrapped_label("You have %d expiring contract%s. AI clubs will make their own retention decisions when this stage opens." % [_career.expiring_players().size(), "" if _career.expiring_players().size() == 1 else "s"], "MutedLabel"))
	decision.column.add_child(UIFactory.spacer(0, 6))
	var advance := UIFactory.button("BEGIN RE-SIGNING  ->", "PrimaryButton")
	advance.pressed.connect(_advance_stage)
	decision.column.add_child(advance)
	side.add_child(decision.card)
	side.add_child(_history_card())
	_body_grid.add_child(side)


func _build_re_signing() -> void:
	var ledger := _card_column("EXPIRING CONTRACTS", "Select a player to prepare an extension")
	ledger.card.custom_minimum_size = Vector2(520, 520)
	var expiring := _career.expiring_players()
	if expiring.is_empty():
		ledger.column.add_child(UIFactory.wrapped_label("Every player under contract is secured beyond this season.", "MutedLabel"))
	else:
		if _selected_player_id.is_empty() or _career.user_team().player_by_id(_selected_player_id) == null:
			_selected_player_id = expiring.front().id
		var button_group := ButtonGroup.new()
		for player in expiring:
			var select := UIFactory.button("%s   %s   OVR %d   %s" % [player.position, player.full_name, player.overall, PlayerContract.money_label(player.contract.annual_salary)], "TeamCardButton")
			select.toggle_mode = true
			select.button_group = button_group
			select.button_pressed = player.id == _selected_player_id
			select.pressed.connect(_select_player.bind(player.id))
			ledger.column.add_child(select)
	_body_grid.add_child(ledger.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not expiring.is_empty():
		side.add_child(_extension_card())
	var actions := _card_column("FINALIZE DECISIONS", "Unextended contracts will enter free agency")
	actions.column.add_child(UIFactory.wrapped_label("Finalizing also advances every active contract by one year and runs the league-wide development cycle.", "MutedLabel"))
	var market := UIFactory.button("OPEN FREE AGENCY", "SecondaryButton")
	market.pressed.connect(func(): free_agency_requested.emit())
	actions.column.add_child(market)
	var advance := UIFactory.button("FINALIZE & RUN DEVELOPMENT  ->", "PrimaryButton")
	advance.pressed.connect(_advance_stage)
	actions.column.add_child(advance)
	side.add_child(actions.card)
	_body_grid.add_child(side)


func _extension_card() -> PanelContainer:
	var player := _team.player_by_id(_selected_player_id)
	var built := _card_column("EXTENSION PROPOSAL", "A new deal begins next league year")
	if player == null:
		return built.card
	var identity := UIFactory.hbox(10)
	identity.add_child(UIFactory.badge(player.position, _team.primary_color))
	var name_copy := UIFactory.vbox(1)
	name_copy.add_child(UIFactory.label(player.full_name, "SectionTitleLabel"))
	name_copy.add_child(UIFactory.label("Age %d  |  OVR %d  |  POT %d" % [player.age, player.overall, player.potential], "MutedLabel"))
	identity.add_child(name_copy)
	built.column.add_child(identity)
	var controls := UIFactory.hbox(10)
	var term_menu := OptionButton.new()
	term_menu.custom_minimum_size = Vector2(145, 44)
	for term in range(1, 5):
		term_menu.add_item("%d YEAR%s" % [term, "" if term == 1 else "S"])
	term_menu.select(_selected_term - 1)
	term_menu.item_selected.connect(_change_term)
	controls.add_child(term_menu)
	var offer_menu := OptionButton.new()
	offer_menu.custom_minimum_size = Vector2(170, 44)
	offer_menu.add_item("TEAM-FRIENDLY")
	offer_menu.add_item("MARKET VALUE")
	offer_menu.add_item("PREMIUM")
	offer_menu.select(_selected_offer_index)
	offer_menu.item_selected.connect(_change_offer)
	controls.add_child(offer_menu)
	built.column.add_child(controls)
	var multiplier := OFFER_MULTIPLIERS[_selected_offer_index]
	var contract := TransactionService.extension_offer(_career.league, _team, player, _selected_term, multiplier)
	var values := GridContainer.new()
	values.columns = 2
	values.add_theme_constant_override("h_separation", 10)
	values.add_theme_constant_override("v_separation", 8)
	values.add_child(_metric("TOTAL VALUE", PlayerContract.money_label(contract.total_value())))
	values.add_child(_metric("ANNUAL CAP", PlayerContract.money_label(contract.annual_salary)))
	values.add_child(_metric("GUARANTEED", PlayerContract.money_label(contract.guaranteed_money)))
	values.add_child(_metric("THROUGH", str(contract.expiration_year())))
	built.column.add_child(values)
	var outlook := UIFactory.label(TransactionService.extension_outlook(player, multiplier), "EyebrowLabel")
	outlook.modulate = GridironTheme.ACCENT if multiplier + 0.001 >= TransactionService.minimum_extension_multiplier(player) else GridironTheme.WARM
	built.column.add_child(outlook)
	var submit := UIFactory.button("SUBMIT EXTENSION OFFER", "PrimaryButton")
	submit.pressed.connect(_submit_extension.bind(player.id))
	built.column.add_child(submit)
	return built.card


func _build_development() -> void:
	var reports := _career.league.development_reports_for(_team.id, _career.league.season_year + 1)
	var report_card := _card_column("PLAYER DEVELOPMENT", "%d squad reports for the upcoming season" % reports.size())
	report_card.card.custom_minimum_size = Vector2(520, 560)
	if reports.is_empty():
		report_card.column.add_child(UIFactory.wrapped_label("No development reports are available.", "MutedLabel"))
	else:
		for report in reports:
			report_card.column.add_child(_development_row(report))
	_body_grid.add_child(report_card.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var roster_errors := RosterValidator.validate_team(_team)
	var readiness := _card_column("LEAGUE YEAR READINESS", "Roster and cap audit")
	if roster_errors.is_empty():
		var ready := UIFactory.label("READY FOR KICKOFF", "EyebrowLabel")
		ready.modulate = GridironTheme.ACCENT
		readiness.column.add_child(ready)
		readiness.column.add_child(UIFactory.wrapped_label("The roster is legal. Starting the new year clears dead cap, resets health, and generates a fresh schedule.", "MutedLabel"))
	else:
		var action := UIFactory.label("ACTION REQUIRED", "EyebrowLabel")
		action.modulate = GridironTheme.DANGER
		readiness.column.add_child(action)
		for error in roster_errors:
			readiness.column.add_child(UIFactory.wrapped_label("- " + error, "MutedLabel"))
	var market := UIFactory.button("OPEN FREE AGENCY", "SecondaryButton")
	market.pressed.connect(func(): free_agency_requested.emit())
	readiness.column.add_child(market)
	var advance := UIFactory.button("START %d SEASON  ->" % (_career.league.season_year + 1), "PrimaryButton")
	advance.disabled = not roster_errors.is_empty()
	advance.pressed.connect(_advance_stage)
	readiness.column.add_child(advance)
	side.add_child(readiness.card)
	side.add_child(_development_summary(reports))
	_body_grid.add_child(side)


func _development_summary(reports: Array[DevelopmentReportData]) -> PanelContainer:
	var built := _card_column("SQUAD TREND", "Year-over-year movement")
	var risers := 0
	var fallers := 0
	var net_change := 0
	for report in reports:
		net_change += report.overall_change()
		if report.overall_change() > 0:
			risers += 1
		elif report.overall_change() < 0:
			fallers += 1
	var metrics := UIFactory.hbox(10)
	metrics.add_child(_metric("RISERS", str(risers)))
	metrics.add_child(_metric("FALLERS", str(fallers)))
	metrics.add_child(_metric("NET OVR", "%+d" % net_change))
	built.column.add_child(metrics)
	built.column.add_child(UIFactory.wrapped_label("Potential drives early-career growth; age increasingly affects speed and overall development. Retirements remain deferred until the draft pipeline is added.", "MutedLabel"))
	return built.card


func _development_row(report: DevelopmentReportData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(9)
	panel.add_child(row)
	row.add_child(UIFactory.badge(report.position, _team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(report.player_name, "BodyLabel"))
	identity.add_child(UIFactory.label("Age %d  |  Potential %d" % [report.new_age, report.potential], "CaptionLabel"))
	row.add_child(identity)
	row.add_child(UIFactory.label("%d -> %d" % [report.previous_overall, report.new_overall], "BodyLabel"))
	var trend := UIFactory.label(report.trend_label(), "EyebrowLabel")
	trend.modulate = GridironTheme.ACCENT if report.overall_change() > 0 else (GridironTheme.DANGER if report.overall_change() < 0 else GridironTheme.TEXT_MUTED)
	row.add_child(trend)
	return panel


func _history_card() -> PanelContainer:
	var built := _card_column("CAREER HISTORY", "%d completed season%s" % [_career.league.season_history.size(), "" if _career.league.season_history.size() == 1 else "s"])
	for record in _career.league.season_history:
		var champion := _career.league.team_by_id(record.champion_team_id)
		built.column.add_child(UIFactory.wrapped_label("%d  |  %s champions  |  %s" % [record.season_year, champion.display_name(), record.championship_score], "MutedLabel"))
	return built.card


func _history_standing_row(entry: Dictionary) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(8)
	panel.add_child(row)
	var name := UIFactory.label(str(entry.get("team_name", "Unknown")), "BodyLabel")
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if str(entry.get("team_id", "")) == _career.league.user_team_id:
		name.modulate = GridironTheme.ACCENT
	row.add_child(name)
	row.add_child(UIFactory.label(str(entry.get("record", "0-0")), "BodyLabel"))
	row.add_child(UIFactory.label("%+d" % int(entry.get("point_differential", 0)), "CaptionLabel"))
	return panel


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


func _card_column(title: String, subtitle: String) -> Dictionary:
	var card := UIFactory.card()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return {"card": card, "column": column}


func _metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metric.add_child(UIFactory.label(value, "MetricLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _stage_index(phase: String) -> int:
	match phase:
		LeagueState.PHASE_RE_SIGNING:
			return 1
		LeagueState.PHASE_PLAYER_DEVELOPMENT:
			return 2
	return 0


func _select_player(player_id: String) -> void:
	_selected_player_id = player_id
	_selected_term = 2
	_selected_offer_index = 1
	_rebuild()


func _change_term(index: int) -> void:
	_selected_term = index + 1
	_rebuild()


func _change_offer(index: int) -> void:
	_selected_offer_index = index
	_rebuild()


func _submit_extension(player_id: String) -> void:
	var result := _career.extend_player(player_id, _selected_term, OFFER_MULTIPLIERS[_selected_offer_index])
	_message = str(result.get("message", "Extension offer processed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		_selected_player_id = ""
		offseason_changed.emit()
	_rebuild()


func _advance_stage() -> void:
	var result := _career.advance_offseason()
	_message = str(result.get("message", "Offseason stage processed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		offseason_changed.emit()
		if not _career.league.is_offseason():
			back_requested.emit()
			return
	_rebuild()


func _apply_responsive_layout() -> void:
	if _summary_grid != null:
		_summary_grid.columns = 4 if size.x >= 1100 else 2
	if _body_grid != null:
		_body_grid.columns = 2 if size.x >= 1040 else 1
	if _header_subtitle != null:
		_header_subtitle.visible = size.x >= 980
	if _back_button != null:
		_back_button.visible = size.x >= 860
