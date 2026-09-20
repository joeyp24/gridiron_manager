extends Control

signal back_requested
signal draft_changed
signal front_office_requested

var _career: CareerSession
var _team: TeamData
var _page: VBoxContainer
var _body_grid: GridContainer
var _header_detail: Label
var _selected_prospect_id := ""
var _position_filter := ""
var _favorites_only := false
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
	var draft := _career.league.current_draft
	if draft == null:
		_build_empty_state()
		return
	_build_header(draft)
	_build_pick_strip(draft)
	if not _message.is_empty():
		var message_card := UIFactory.card("RaisedCardPanel")
		var message_label := UIFactory.wrapped_label(_message, "BodyLabel")
		message_label.modulate = GridironTheme.DANGER if _message_is_error else GridironTheme.ACCENT
		message_card.add_child(message_label)
		_page.add_child(message_card)
	if draft.is_complete():
		_build_recap(draft)
	else:
		_build_draft_room(draft)
	_apply_responsive_layout()


func _build_empty_state() -> void:
	var card := UIFactory.card("RaisedCardPanel")
	var column := UIFactory.vbox(10)
	card.add_child(column)
	column.add_child(UIFactory.label("DRAFT CENTER", "PageTitleLabel"))
	column.add_child(UIFactory.wrapped_label("The next draft class becomes available after player development.", "MutedLabel"))
	var back := UIFactory.button("BACK TO OFFSEASON", "PrimaryButton")
	back.pressed.connect(func(): back_requested.emit())
	column.add_child(back)
	_page.add_child(card)


func _build_header(draft: DraftStateData) -> void:
	var header := UIFactory.hbox(12)
	header.add_child(UIFactory.badge(str(draft.draft_year), _team.primary_color))
	var copy := UIFactory.page_heading("COLLEGE PERSONNEL", "Draft Center")
	_header_detail = UIFactory.label(_draft_subtitle(draft), "MutedLabel")
	copy.add_child(_header_detail)
	header.add_child(copy)
	header.add_child(UIFactory.spacer())
	var office := UIFactory.button("FRONT OFFICE", "SecondaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	header.add_child(office)
	var back := UIFactory.button("BACK TO OFFSEASON", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	_page.add_child(header)


func _build_pick_strip(draft: DraftStateData) -> void:
	var strip := GridContainer.new()
	strip.columns = 4
	strip.add_theme_constant_override("h_separation", 10)
	strip.add_theme_constant_override("v_separation", 10)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current := draft.current_pick()
	var next_user := draft.next_pick_for(_team.id)
	strip.add_child(_metric_card("STATUS", draft.status.to_upper(), "%d of %d selections" % [draft.current_pick_index, draft.picks.size()]))
	strip.add_child(_metric_card("ON THE CLOCK", _pick_owner_label(current), current.pick_label() if current != null else "Draft complete"))
	strip.add_child(_metric_card("YOUR NEXT PICK", next_user.pick_label() if next_user != null else "COMPLETE", "%d selections made" % draft.selections_for_team(_team.id).size()))
	strip.add_child(_metric_card("SCOUTING", "%d PTS" % draft.scouting_points_remaining, "Targeted assignments remaining"))
	_page.add_child(strip)


func _build_draft_room(draft: DraftStateData) -> void:
	_build_filters(draft)
	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)

	var board := _card_column("SCOUTING BOARD", "Estimated grades reflect your club's information, not hidden true ratings")
	board.card.custom_minimum_size = Vector2(590, 560)
	var prospects := DraftService.ranked_board(_career.league, _position_filter, _favorites_only)
	if prospects.is_empty():
		board.column.add_child(UIFactory.wrapped_label("No available prospects match these filters.", "MutedLabel"))
	else:
		if _selected_prospect_id.is_empty() or not _available_contains(prospects, _selected_prospect_id):
			_selected_prospect_id = prospects.front().id
		var group := ButtonGroup.new()
		for index in range(mini(32, prospects.size())):
			var prospect := prospects[index]
			var report := draft.report_for(_team.id, prospect.id)
			var favorite := "★" if draft.is_favorite(prospect.id) else " "
			var row := UIFactory.button("%s  %2d  %-4s  %-22s  OVR %s  POT %s" % [favorite, prospect.consensus_rank, prospect.position, prospect.full_name, report.overall_range_label(), report.potential_range_label()], "TeamCardButton")
			row.toggle_mode = true
			row.button_group = group
			row.button_pressed = prospect.id == _selected_prospect_id
			row.alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.pressed.connect(_select_prospect.bind(prospect.id))
			board.column.add_child(row)
	_body_grid.add_child(board.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_prospect_detail(draft))
	if draft.status == DraftStateData.STATUS_PREPARATION:
		side.add_child(_preparation_actions(draft))
	else:
		side.add_child(_live_draft_actions(draft))
	side.add_child(_recent_picks_card(draft))
	_body_grid.add_child(side)


func _build_filters(draft: DraftStateData) -> void:
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 10)
	toolbar.add_theme_constant_override("v_separation", 8)
	var position_menu := OptionButton.new()
	position_menu.custom_minimum_size = Vector2(170, 44)
	position_menu.add_item("ALL POSITIONS")
	for position_name in TeamData.ROSTER_POSITIONS:
		position_menu.add_item(position_name)
	position_menu.select(0 if _position_filter.is_empty() else TeamData.ROSTER_POSITIONS.find(_position_filter) + 1)
	position_menu.item_selected.connect(_change_position_filter)
	toolbar.add_child(position_menu)
	var favorites := UIFactory.button("★  FAVORITES ONLY", "SecondaryButton")
	favorites.toggle_mode = true
	favorites.button_pressed = _favorites_only
	favorites.pressed.connect(_toggle_favorites_filter)
	toolbar.add_child(favorites)
	var needs := DraftService.team_needs(_team)
	toolbar.add_child(UIFactory.badge("NEEDS  %s" % "  ·  ".join(needs), GridironTheme.ACCENT_DARK))
	toolbar.add_child(UIFactory.spacer())
	if draft.status == DraftStateData.STATUS_PREPARATION:
		var begin := UIFactory.button("BEGIN DRAFT  ->", "PrimaryButton")
		begin.pressed.connect(_begin_draft)
		toolbar.add_child(begin)
	_page.add_child(toolbar)


func _prospect_detail(draft: DraftStateData) -> PanelContainer:
	var built := _card_column("PROSPECT DOSSIER", "Scouting report and roster comparison")
	var prospect := draft.prospect_by_id(_selected_prospect_id)
	if prospect == null:
		built.column.add_child(UIFactory.wrapped_label("Select an available prospect to open the dossier.", "MutedLabel"))
		return built.card
	var report := draft.report_for(_team.id, prospect.id)
	var identity := UIFactory.hbox(10)
	identity.add_child(UIFactory.badge(prospect.position, _team.primary_color))
	var copy := UIFactory.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label(prospect.full_name, "SectionTitleLabel"))
	copy.add_child(UIFactory.label("%s · %s · Age %d" % [prospect.college, prospect.archetype, prospect.age], "MutedLabel"))
	identity.add_child(copy)
	identity.add_child(UIFactory.label("#%d" % prospect.consensus_rank, "MetricLabel"))
	built.column.add_child(identity)
	var grade_grid := GridContainer.new()
	grade_grid.columns = 3
	grade_grid.add_theme_constant_override("h_separation", 8)
	grade_grid.add_child(_mini_metric("OVR RANGE", report.overall_range_label()))
	grade_grid.add_child(_mini_metric("POT RANGE", report.potential_range_label()))
	grade_grid.add_child(_mini_metric("CONFIDENCE", "%d%%" % report.confidence))
	built.column.add_child(grade_grid)
	built.column.add_child(UIFactory.label("%s  ·  %d lb  ·  %s projection" % [prospect.height_label(), prospect.weight_lbs, prospect.projected_round_label()], "MutedLabel"))
	built.column.add_child(UIFactory.label("COMBINE", "EyebrowLabel"))
	var combine := UIFactory.hbox(8)
	combine.add_child(_mini_metric("40-YARD", "%.2fs" % prospect.forty_time))
	combine.add_child(_mini_metric("BENCH", "%d reps" % prospect.bench_reps))
	combine.add_child(_mini_metric("SHUTTLE", "%.2fs" % prospect.shuttle_time))
	built.column.add_child(combine)
	built.column.add_child(UIFactory.label("SCOUTED TRAITS", "EyebrowLabel"))
	if report.revealed_attributes.is_empty():
		built.column.add_child(UIFactory.label("Complete targeted scouting to reveal verified attributes.", "MutedLabel"))
	else:
		var trait_text: Array[String] = []
		for key in report.revealed_attributes:
			trait_text.append("%s %d" % [str(key).capitalize(), int(report.revealed_attributes[key])])
		built.column.add_child(UIFactory.wrapped_label("  ·  ".join(trait_text), "BodyLabel"))
	for note in report.notes:
		built.column.add_child(UIFactory.wrapped_label("• " + note, "MutedLabel"))
	var starter := _team.player_at(prospect.position)
	if starter != null:
		built.column.add_child(UIFactory.divider())
		built.column.add_child(UIFactory.label("CURRENT STARTER", "EyebrowLabel"))
		built.column.add_child(UIFactory.label("%s  ·  OVR %d  ·  Age %d" % [starter.full_name, starter.overall, starter.age], "BodyLabel"))
	return built.card


func _preparation_actions(draft: DraftStateData) -> PanelContainer:
	var built := _card_column("WAR ROOM ACTIONS", "%d targeted assignments remain" % draft.scouting_points_remaining)
	var prospect := draft.prospect_by_id(_selected_prospect_id)
	if prospect == null:
		return built.card
	var report := draft.report_for(_team.id, prospect.id)
	var favorite := UIFactory.button("REMOVE FAVORITE" if draft.is_favorite(prospect.id) else "ADD TO FAVORITES", "SecondaryButton")
	favorite.pressed.connect(_toggle_selected_favorite)
	built.column.add_child(favorite)
	var scout := UIFactory.button("ASSIGN TARGETED SCOUT", "PrimaryButton")
	scout.disabled = draft.scouting_points_remaining <= 0 or report.level >= 3
	scout.pressed.connect(_scout_selected)
	built.column.add_child(scout)
	return built.card


func _live_draft_actions(draft: DraftStateData) -> PanelContainer:
	var current := draft.current_pick()
	var user_on_clock := current != null and current.owner_team_id == _team.id
	var built := _card_column("PICK CONTROL", "Your selection is final and signs the rookie automatically")
	var clock := UIFactory.label("YOU ARE ON THE CLOCK" if user_on_clock else "LEAGUE SIMULATION ACTIVE", "EyebrowLabel")
	clock.modulate = GridironTheme.WARM if user_on_clock else GridironTheme.TEXT_MUTED
	built.column.add_child(clock)
	var favorite := UIFactory.button("REMOVE FAVORITE" if draft.is_favorite(_selected_prospect_id) else "ADD TO FAVORITES", "SecondaryButton")
	favorite.disabled = draft.prospect_by_id(_selected_prospect_id) == null
	favorite.pressed.connect(_toggle_selected_favorite)
	built.column.add_child(favorite)
	var select := UIFactory.button("SELECT PROSPECT  ->", "PrimaryButton")
	select.disabled = not user_on_clock or draft.prospect_by_id(_selected_prospect_id) == null
	select.pressed.connect(_make_selection)
	built.column.add_child(select)
	var auto_pick := UIFactory.button("AUTO-PICK BEST ON BOARD", "GhostButton")
	auto_pick.disabled = not user_on_clock
	auto_pick.pressed.connect(_auto_pick)
	built.column.add_child(auto_pick)
	return built.card


func _recent_picks_card(draft: DraftStateData) -> PanelContainer:
	var built := _card_column("RECENT PICKS", "League selections update after each of your picks")
	var recent := DraftService.recent_selections(draft, 6)
	if recent.is_empty():
		built.column.add_child(UIFactory.label("No selections have been made.", "MutedLabel"))
	for pick in recent:
		var prospect := draft.prospect_by_id(pick.selected_prospect_id)
		var team := _career.league.team_by_id(pick.owner_team_id)
		built.column.add_child(UIFactory.label("#%d  %s  ·  %s %s" % [pick.overall_pick, team.abbreviation, prospect.position, prospect.full_name], "MutedLabel"))
	return built.card


func _build_recap(draft: DraftStateData) -> void:
	var hero := UIFactory.card("AccentPanel")
	var hero_row := UIFactory.hbox(14)
	hero.add_child(hero_row)
	var copy := UIFactory.vbox(2)
	copy.add_child(UIFactory.label("DRAFT COMPLETE", "EyebrowLabel"))
	copy.add_child(UIFactory.label("%s earned a %s draft grade" % [_team.display_name(), DraftService.team_draft_grade(draft, _team.id)], "SectionTitleLabel"))
	copy.add_child(UIFactory.label("Rookies are signed. Finalize the active roster before the new season.", "MutedLabel"))
	hero_row.add_child(copy)
	hero_row.add_child(UIFactory.spacer())
	var office := UIFactory.button("FINALIZE ROSTER  ->", "PrimaryButton")
	office.pressed.connect(func(): front_office_requested.emit())
	hero_row.add_child(office)
	_page.add_child(hero)

	_body_grid = GridContainer.new()
	_body_grid.columns = 2
	_body_grid.add_theme_constant_override("h_separation", 14)
	_body_grid.add_theme_constant_override("v_separation", 14)
	_body_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(_body_grid)
	var class_card := _card_column("YOUR DRAFT CLASS", "%d selections · rookie salary scale applied" % draft.selections_for_team(_team.id).size())
	for pick in draft.selections_for_team(_team.id):
		var prospect := draft.prospect_by_id(pick.selected_prospect_id)
		var player := _team.player_by_id(pick.selected_player_id)
		var row := UIFactory.card("InsetPanel")
		var line := UIFactory.hbox(8)
		row.add_child(line)
		line.add_child(UIFactory.badge(prospect.position, _team.primary_color))
		var identity := UIFactory.vbox(1)
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		identity.add_child(UIFactory.label(prospect.full_name, "BodyLabel"))
		identity.add_child(UIFactory.label("%s · %s" % [pick.pick_label(), pick.value_label], "CaptionLabel"))
		line.add_child(identity)
		line.add_child(UIFactory.label("OVR %d" % player.overall, "BodyLabel"))
		line.add_child(UIFactory.badge(pick.selection_grade, GridironTheme.ACCENT if pick.selection_grade in ["A", "B"] else GridironTheme.WARM))
		class_card.column.add_child(row)
	_body_grid.add_child(class_card.card)

	var side := UIFactory.vbox(14)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var league_grades := _card_column("LEAGUE GRADES", "Value against consensus board")
	for team in _career.league.teams:
		var grade_row := UIFactory.hbox(8)
		grade_row.add_child(UIFactory.label(team.display_name(), "MutedLabel"))
		grade_row.add_child(UIFactory.spacer())
		grade_row.add_child(UIFactory.badge(DraftService.team_draft_grade(draft, team.id), team.primary_color))
		league_grades.column.add_child(grade_row)
	side.add_child(league_grades.card)
	var needs_card := _card_column("REMAINING NEEDS", "Depth priorities after the draft")
	for need in DraftService.team_needs(_team, 6):
		var starter := _team.player_at(need)
		needs_card.column.add_child(UIFactory.label("%s  ·  %s" % [need, "No starter" if starter == null else "%s (OVR %d)" % [starter.full_name, starter.overall]], "MutedLabel"))
	side.add_child(needs_card.card)
	_body_grid.add_child(side)


func _draft_subtitle(draft: DraftStateData) -> String:
	if draft.status == DraftStateData.STATUS_PREPARATION:
		return "Build your board, resolve uncertainty, and prepare for seven rounds."
	if draft.status == DraftStateData.STATUS_IN_PROGRESS:
		return "Live draft · AI clubs balance talent, need, depth, upside, and positional value."
	return "Review every selection, value result, club grade, and remaining need."


func _pick_owner_label(pick: DraftPickData) -> String:
	if pick == null:
		return "COMPLETE"
	var team := _career.league.team_by_id(pick.owner_team_id)
	return "YOU" if team.id == _team.id else team.abbreviation


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


func _available_contains(prospects: Array[ProspectData], prospect_id: String) -> bool:
	for prospect in prospects:
		if prospect.id == prospect_id:
			return true
	return false


func _select_prospect(prospect_id: String) -> void:
	_selected_prospect_id = prospect_id
	_rebuild()


func _change_position_filter(index: int) -> void:
	_position_filter = "" if index == 0 else TeamData.ROSTER_POSITIONS[index - 1]
	_selected_prospect_id = ""
	_rebuild()


func _toggle_favorites_filter() -> void:
	_favorites_only = not _favorites_only
	_selected_prospect_id = ""
	_rebuild()


func _toggle_selected_favorite() -> void:
	var result := _career.toggle_draft_favorite(_selected_prospect_id)
	_show_result(result)


func _scout_selected() -> void:
	var result := _career.scout_prospect(_selected_prospect_id)
	_show_result(result)


func _begin_draft() -> void:
	var result := _career.advance_offseason()
	_show_result(result)


func _make_selection() -> void:
	var result := _career.select_draft_prospect(_selected_prospect_id)
	_selected_prospect_id = ""
	_show_result(result)


func _auto_pick() -> void:
	var result := _career.auto_pick_draft_selection()
	_selected_prospect_id = ""
	_show_result(result)


func _show_result(result: Dictionary) -> void:
	_message = str(result.get("message", "Draft action processed."))
	_message_is_error = not bool(result.get("ok", false))
	if not _message_is_error:
		draft_changed.emit()
	_rebuild()


func _apply_responsive_layout() -> void:
	if _body_grid != null:
		_body_grid.columns = 2 if size.x >= 1080 else 1
	if _header_detail != null:
		_header_detail.visible = size.x >= 820
