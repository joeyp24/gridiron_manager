extends Control

signal back_requested
signal free_agency_requested
signal front_office_requested
signal draft_center_requested
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
		LeagueState.PHASE_RETIREMENTS:
			_build_retirements()
		LeagueState.PHASE_DRAFT_PREPARATION:
			_build_draft_preparation()
		LeagueState.PHASE_DRAFT:
			_build_live_draft()
		LeagueState.PHASE_ROSTER_DECISIONS:
			_build_roster_decisions()
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
		{"phase": LeagueState.PHASE_RETIREMENTS, "label": "04  RETIREMENTS"},
		{"phase": LeagueState.PHASE_DRAFT_PREPARATION, "label": "05  SCOUTING"},
		{"phase": LeagueState.PHASE_DRAFT, "label": "06  DRAFT"},
		{"phase": LeagueState.PHASE_ROSTER_DECISIONS, "label": "07  ROSTER"},
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
	var personnel_year := _career.league.season_year + 1
	var exits := _career.league.retired_players_for_year(personnel_year).size()
	var personnel_title := "CAREER EXITS" if _career.league.phase in [LeagueState.PHASE_RETIREMENTS, LeagueState.PHASE_DRAFT_PREPARATION, LeagueState.PHASE_DRAFT, LeagueState.PHASE_ROSTER_DECISIONS] else "EXPIRING"
	var personnel_value := str(exits) if personnel_title == "CAREER EXITS" else str(_career.expiring_players().size())
	var personnel_detail := "%d personnel cycle" % personnel_year if personnel_title == "CAREER EXITS" else "Contracts requiring decisions"
	_summary_grid.add_child(_summary_card(personnel_title, personnel_value, personnel_detail))
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
	var readiness := _card_column("NEXT: CAREER DECISIONS", "Process position-specific retirement and league-exit evaluations")
	var ready := UIFactory.label("PERSONNEL REVIEW READY", "EyebrowLabel")
	ready.modulate = GridironTheme.ACCENT
	readiness.column.add_child(ready)
	readiness.column.add_child(UIFactory.wrapped_label("Age, position, durability, career decline, injuries, performance level, and market status all influence deterministic career decisions.", "MutedLabel"))
	var advance := UIFactory.button("PROCESS RETIREMENT DECISIONS  ->", "PrimaryButton")
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
	built.column.add_child(UIFactory.wrapped_label("Potential drives early-career growth; age increasingly affects speed and overall development. These results should shape your scouting priorities.", "MutedLabel"))
	return built.card


func _build_retirements() -> void:
	var retirement_year := _career.league.season_year + 1
	var team_records := _career.league.retired_players_for_year(retirement_year, _team.id)
	var league_records := _career.league.retired_players_for_year(retirement_year)
	var team_card := _card_column("CLUB CAREER DECISIONS", "%d departure%s affecting %s" % [team_records.size(), "" if team_records.size() == 1 else "s", _team.display_name()])
	team_card.card.custom_minimum_size = Vector2(520, 460)
	if team_records.is_empty():
		team_card.column.add_child(UIFactory.wrapped_label("No player whose latest club was %s ended their career this cycle." % _team.display_name(), "MutedLabel"))
	else:
		for record in team_records:
			team_card.column.add_child(_retirement_row(record))
	var team_dead_cap := 0
	for record in team_records:
		team_dead_cap += record.dead_cap_charge
	team_card.column.add_child(UIFactory.divider())
	var impact := UIFactory.hbox(10)
	impact.add_child(_metric("ROSTER", str(_team.players.size())))
	impact.add_child(_metric("DEAD CAP", PlayerContract.money_label(team_dead_cap)))
	impact.add_child(_metric("TOP NEED", str(DraftService.team_needs(_team, 1).front())))
	team_card.column.add_child(impact)
	_body_grid.add_child(team_card.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var league_card := _card_column("LEAGUE RETIREMENT REPORT", "%d archived career%s across all clubs and the open market" % [league_records.size(), "" if league_records.size() == 1 else "s"])
	if league_records.is_empty():
		league_card.column.add_child(UIFactory.label("No careers ended this cycle.", "MutedLabel"))
	else:
		for index in range(mini(10, league_records.size())):
			var record: RetiredPlayerData = league_records[index]
			var club := _career.league.team_by_id(record.final_team_id)
			var club_label := club.abbreviation if club != null else "FA"
			league_card.column.add_child(UIFactory.label("%s  %s  ·  %s  ·  Age %d  ·  Peak %d" % [club_label, record.full_name, record.position, record.age, record.peak_overall], "MutedLabel"))
	side.add_child(league_card.card)
	var next := _card_column("NEXT: DRAFT PREPARATION", "Replace lost depth with the incoming rookie class")
	next.column.add_child(UIFactory.wrapped_label("The generator will create a fresh position-balanced class using the same identity, physical profile, archetype, personality, and attribute rules as every other player source.", "MutedLabel"))
	var advance := UIFactory.button("BUILD %d DRAFT CLASS  ->" % retirement_year, "PrimaryButton")
	advance.pressed.connect(_advance_stage)
	next.column.add_child(advance)
	side.add_child(next.card)
	_body_grid.add_child(side)


func _retirement_row(record: RetiredPlayerData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var row := UIFactory.hbox(9)
	panel.add_child(row)
	row.add_child(UIFactory.badge(record.position, _team.primary_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label(record.full_name, "BodyLabel"))
	identity.add_child(UIFactory.label("%s · Age %d · %d seasons" % [record.departure_type, record.age, record.experience_years], "CaptionLabel"))
	row.add_child(identity)
	row.add_child(UIFactory.label("%d -> %d" % [record.peak_overall, record.final_overall], "BodyLabel"))
	if record.dead_cap_charge > 0:
		row.add_child(UIFactory.badge(PlayerContract.money_label(record.dead_cap_charge), GridironTheme.WARM))
	return panel


func _build_draft_preparation() -> void:
	var draft := _career.league.current_draft
	var overview := _card_column("DRAFT PREPARATION", "A fictional class with uncertainty, combine data, production, and personality")
	overview.card.custom_minimum_size = Vector2(520, 420)
	var first_pick := draft.next_pick_for(_team.id) if draft != null else null
	var metrics := GridContainer.new()
	metrics.columns = 2
	metrics.add_theme_constant_override("h_separation", 10)
	metrics.add_theme_constant_override("v_separation", 10)
	metrics.add_child(_metric("PROSPECTS", str(draft.prospects.size()) if draft != null else "0"))
	metrics.add_child(_metric("SCOUTING", "%d pts" % draft.scouting_points_remaining if draft != null else "0 pts"))
	metrics.add_child(_metric("FIRST PICK", first_pick.pick_label() if first_pick != null else "N/A"))
	metrics.add_child(_metric("TEAM NEEDS", " · ".join(DraftService.team_needs(_team, 3))))
	overview.column.add_child(metrics)
	overview.column.add_child(UIFactory.wrapped_label("Baseline reports intentionally show ranges. Targeted assignments narrow OVR and potential estimates and reveal verified position-specific traits.", "MutedLabel"))
	var open := UIFactory.button("OPEN DRAFT CENTER  ->", "PrimaryButton")
	open.pressed.connect(func(): draft_center_requested.emit())
	overview.column.add_child(open)
	_body_grid.add_child(overview.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var plan := _card_column("WAR ROOM PLAN", "Recommended preparation sequence")
	for item in ["1  Filter the board by your highest roster needs.", "2  Favorite priority targets across multiple rounds.", "3  Spend assignments on uncertain or high-upside players.", "4  Compare every target with your current starter."]:
		plan.column.add_child(UIFactory.wrapped_label(item, "MutedLabel"))
	side.add_child(plan.card)
	var begin := _card_column("DRAFT NIGHT", "Scouting closes when the draft begins")
	begin.column.add_child(UIFactory.wrapped_label("AI clubs will select between your turns using talent, roster need, depth, potential, and positional value.", "MutedLabel"))
	var advance := UIFactory.button("BEGIN SEVEN-ROUND DRAFT", "SecondaryButton")
	advance.pressed.connect(_advance_stage)
	begin.column.add_child(advance)
	side.add_child(begin.card)
	_body_grid.add_child(side)


func _build_live_draft() -> void:
	var draft := _career.league.current_draft
	var live := _card_column("DRAFT IN PROGRESS", "Make each club selection in the dedicated Draft Center")
	live.card.custom_minimum_size = Vector2(520, 360)
	var current := draft.current_pick() if draft != null else null
	var current_team := _career.league.team_by_id(current.owner_team_id) if current != null else null
	var clock := UIFactory.label("YOU ARE ON THE CLOCK" if current_team != null and current_team.id == _team.id else "LEAGUE ON THE CLOCK", "EyebrowLabel")
	clock.modulate = GridironTheme.WARM
	live.column.add_child(clock)
	live.column.add_child(UIFactory.label(current.pick_label() if current != null else "Draft complete", "MetricLabel"))
	live.column.add_child(UIFactory.label(current_team.display_name() if current_team != null else "Selections complete", "SectionTitleLabel"))
	var open := UIFactory.button("ENTER DRAFT CENTER  ->", "PrimaryButton")
	open.pressed.connect(func(): draft_center_requested.emit())
	live.column.add_child(open)
	_body_grid.add_child(live.card)

	var recap := _card_column("YOUR CLASS", "%d of 7 selections complete" % (draft.selections_for_team(_team.id).size() if draft != null else 0))
	if draft != null:
		for pick in draft.selections_for_team(_team.id):
			var prospect := draft.prospect_by_id(pick.selected_prospect_id)
			recap.column.add_child(UIFactory.label("%s  ·  %s %s" % [pick.pick_label(), prospect.position, prospect.full_name], "MutedLabel"))
	_body_grid.add_child(recap.card)


func _build_roster_decisions() -> void:
	var draft := _career.league.current_draft
	var class_card := _card_column("DRAFT RECAP", "%s draft grade · %d rookies signed" % [DraftService.team_draft_grade(draft, _team.id), draft.selections_for_team(_team.id).size()])
	class_card.card.custom_minimum_size = Vector2(520, 420)
	for pick in draft.selections_for_team(_team.id):
		var prospect := draft.prospect_by_id(pick.selected_prospect_id)
		class_card.column.add_child(UIFactory.label("%s  ·  %s %s  ·  %s  ·  Grade %s" % [pick.pick_label(), prospect.position, prospect.full_name, pick.value_label, pick.selection_grade], "MutedLabel"))
	var recap := UIFactory.button("OPEN FULL DRAFT RECAP", "SecondaryButton")
	recap.pressed.connect(func(): draft_center_requested.emit())
	class_card.column.add_child(recap)
	_body_grid.add_child(class_card.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var errors := RosterValidator.validate_team(_team)
	var readiness := _card_column("ROSTER DECISIONS", "Reduce the offseason roster to the active limit and clear the cap audit")
	if errors.is_empty():
		var ready := UIFactory.label("READY FOR KICKOFF", "EyebrowLabel")
		ready.modulate = GridironTheme.ACCENT
		readiness.column.add_child(ready)
		readiness.column.add_child(UIFactory.wrapped_label("Your depth chart, active roster, and payroll are legal for the new league year.", "MutedLabel"))
	else:
		var required := UIFactory.label("ACTION REQUIRED", "EyebrowLabel")
		required.modulate = GridironTheme.DANGER
		readiness.column.add_child(required)
		for error in errors:
			readiness.column.add_child(UIFactory.wrapped_label("• " + error, "MutedLabel"))
	var office := UIFactory.button("OPEN FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	readiness.column.add_child(office)
	var market := UIFactory.button("OPEN FREE AGENCY", "SecondaryButton")
	market.pressed.connect(func(): free_agency_requested.emit())
	readiness.column.add_child(market)
	var advance := UIFactory.button("START %d SEASON  ->" % (_career.league.season_year + 1), "PrimaryButton")
	advance.disabled = not errors.is_empty()
	advance.pressed.connect(_advance_stage)
	readiness.column.add_child(advance)
	side.add_child(readiness.card)
	var needs := _card_column("REMAINING NEEDS", "Post-draft depth priorities")
	for position_name in DraftService.team_needs(_team, 6):
		needs.column.add_child(UIFactory.label("%s  ·  %d rostered" % [position_name, _team.players_at(position_name).size()], "MutedLabel"))
	side.add_child(needs.card)
	_body_grid.add_child(side)


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
		LeagueState.PHASE_RETIREMENTS:
			return 3
		LeagueState.PHASE_DRAFT_PREPARATION:
			return 4
		LeagueState.PHASE_DRAFT:
			return 5
		LeagueState.PHASE_ROSTER_DECISIONS:
			return 6
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
