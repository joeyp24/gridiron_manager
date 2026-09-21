extends Control

signal back_requested
signal coach_changed

var _career: CareerSession
var _viewed_team: TeamData
var _page: VBoxContainer
var _tree: CoachSkillGraph
var _body: GridContainer
var _summary: GridContainer
var _details: VBoxContainer
var _selected_branch := "offense"
var _selected_skill := ""
var _message := ""
var _buy_button: Button
var _respec_dialog: ConfirmationDialog
var _scroll: ScrollContainer
var _detail_card: PanelContainer


func setup(career: CareerSession) -> void:
	_career = career
	_viewed_team = career.user_team()


func _ready() -> void:
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_page = UIFactory.vbox(16)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_page)
	_respec_dialog = ConfirmationDialog.new()
	_respec_dialog.title = "Retrain coaching skills?"
	_respec_dialog.dialog_text = "Refund every skill point and remove the current build's effects. This can be done only once this offseason. Your coaching background stays permanent."
	_respec_dialog.confirmed.connect(func(): _apply_result(_career.retrain_coach()))
	add_child(_respec_dialog)
	resized.connect(_apply_responsive_layout)
	_rebuild()


func _rebuild() -> void:
	for child in _page.get_children():
		_page.remove_child(child)
		child.queue_free()
	var coach := _viewed_team.coach
	var owned := _viewed_team.id == _career.league.user_team_id
	CoachProgressionService.ensure_objective(coach, _career.league, _viewed_team.id)
	var header := UIFactory.page_heading("COACHING IDENTITY", "Coach Skill Tree", "Shape your career through specializations, situational strengths, and long-term player development.")
	_page.add_child(header)
	var toolbar := HFlowContainer.new()
	toolbar.add_theme_constant_override("h_separation", 10)
	toolbar.add_theme_constant_override("v_separation", 8)
	var teams := OptionButton.new()
	teams.custom_minimum_size = Vector2(240, 42)
	teams.fit_to_longest_item = false
	for team in _career.league.teams:
		teams.add_item(team.display_name() + (" · YOU" if team.id == _career.league.user_team_id else ""))
		teams.set_item_metadata(teams.item_count - 1, team.id)
		if team.id == _viewed_team.id:
			teams.select(teams.item_count - 1)
	teams.item_selected.connect(func(index: int):
		_viewed_team = _career.league.team_by_id(str(teams.get_item_metadata(index)))
		_message = ""
		_rebuild()
	)
	toolbar.add_child(teams)
	var back := UIFactory.button("CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	toolbar.add_child(back)
	if owned:
		var retrain := UIFactory.button("RETRAIN BUILD", "SecondaryButton")
		retrain.disabled = not _career.coach_change_error().is_empty() or not _career.league.is_offseason() or coach.last_respec_year == _career.league.season_year or coach.ranks.is_empty()
		retrain.tooltip_text = "Refund all skills once per offseason. Your background remains permanent."
		retrain.pressed.connect(func(): _respec_dialog.popup_centered())
		toolbar.add_child(retrain)
	_page.add_child(toolbar)

	_summary = GridContainer.new()
	_summary.add_theme_constant_override("h_separation", 12)
	_summary.add_theme_constant_override("v_separation", 12)
	_summary.add_child(UIFactory.metric_card("Coach level", str(coach.level()), "Maximum level 30"))
	_summary.add_child(UIFactory.metric_card("Available points", str(CoachProgressionService.available_points(coach)), "%d spent · maximum 38 career points" % CoachProgressionService.spent_points(coach)))
	_summary.add_child(UIFactory.metric_card("Background", coach.background.capitalize() if not coach.background.is_empty() else "CHOOSE BELOW", "Background shapes bonus XP"))
	_summary.add_child(UIFactory.metric_card("Milestones", "%d / 6" % coach.milestones.size(), "10 / 25 / 50 / 100 wins, playoff win, title"))
	_page.add_child(_summary)
	var progress := UIFactory.card("HeroPanel")
	var progress_column := UIFactory.vbox(6)
	progress.add_child(progress_column)
	var next_xp := CoachProgressData.xp_for_level(mini(coach.level() + 1, CoachProgressData.MAX_LEVEL))
	progress_column.add_child(UIFactory.label("CAREER XP · %d / %d" % [coach.xp, next_xp], "EyebrowLabel"))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var floor_xp := CoachProgressData.xp_for_level(coach.level())
	bar.max_value = maxi(next_xp - floor_xp, 1)
	bar.value = bar.max_value if coach.level() == CoachProgressData.MAX_LEVEL else coach.xp - floor_xp
	progress_column.add_child(bar)
	var objective: Dictionary = CoachProgressionService.OBJECTIVES[coach.objective_id]
	progress_column.add_child(UIFactory.wrapped_label("%d objective · %s · %d / %d · %s" % [
		coach.objective_year, objective["label"], coach.objective_progress, objective["target"], "250 XP CLAIMED" if coach.objective_claimed else "250 XP reward"
	], "BodyLabel"))
	progress_column.add_child(UIFactory.wrapped_label("Games: 45 XP, wins: +35, playoff games: +45, titles: +150. Offense earns +20 for 28+ points; Defense +20 for allowing 17 or fewer; Management +20 for turnover-free games. Development earns double growth XP in the offseason.", "CaptionLabel"))
	_page.add_child(progress)

	if owned and not coach.identity_locked:
		var intro := UIFactory.card("RaisedCardPanel")
		var column := UIFactory.vbox(10)
		intro.add_child(column)
		column.add_child(UIFactory.section_heading("CHOOSE YOUR BACKGROUND", "All branches remain available. Your background becomes permanent on your first purchase."))
		var choices := HFlowContainer.new()
		choices.add_theme_constant_override("h_separation", 10)
		for branch in CoachSkillCatalog.branches():
			var button := UIFactory.button(str(branch["name"]), "SecondaryButton" if coach.background == branch["id"] else "GhostButton")
			button.disabled = not _career.coach_change_error().is_empty()
			button.pressed.connect(_choose_background.bind(str(branch["id"])))
			choices.add_child(button)
		column.add_child(choices)
		_page.add_child(intro)
	if not _message.is_empty():
		_page.add_child(UIFactory.wrapped_label(_message, "BodyLabel"))
	if not owned:
		_page.add_child(UIFactory.status_pill("OPPONENT COACH · READ ONLY", GridironTheme.BLUE))
	elif not _career.coach_change_error().is_empty():
		_page.add_child(UIFactory.wrapped_label(_career.coach_change_error(), "WarningLabel"))
	var branches := HFlowContainer.new()
	branches.add_theme_constant_override("h_separation", 8)
	branches.add_theme_constant_override("v_separation", 8)
	for branch in CoachSkillCatalog.branches():
		var button := UIFactory.button("%s · %d PTS" % [branch["name"], CoachProgressionService.spent_points(coach, str(branch["id"]))], "SecondaryButton" if branch["id"] == _selected_branch else "GhostButton")
		button.pressed.connect(_select_branch.bind(str(branch["id"])))
		branches.add_child(button)
	_page.add_child(branches)
	_page.add_child(UIFactory.wrapped_label("Two paths per branch. Tier 3 identities are mutually exclusive within their branch. Invest 2 / 5 / 8 / 12 branch points to reach later tiers. Signature skills cost two points; master at most two across the whole tree.", "MutedLabel"))

	_body = GridContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("h_separation", 18)
	_body.add_theme_constant_override("v_separation", 18)
	_page.add_child(_body)
	_tree = CoachSkillGraph.new()
	_tree.coach = coach
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.add_theme_constant_override("h_separation", 16)
	_tree.add_theme_constant_override("v_separation", 30)
	_body.add_child(_tree)
	for definition in CoachSkillCatalog.skills():
		if definition["branch"] != _selected_branch:
			continue
		if _selected_skill.is_empty():
			_selected_skill = str(definition["id"])
		var node := _skill_card(definition, coach)
		_tree.add_child(node)
		_tree.skill_nodes[definition["id"]] = node
		_tree.definitions.append(definition)
	var detail_card := UIFactory.card("RaisedCardPanel")
	_detail_card = detail_card
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_details = UIFactory.vbox(12)
	detail_card.add_child(_details)
	_body.add_child(detail_card)
	_refresh_details()
	var history := UIFactory.card()
	var history_column := UIFactory.vbox(8)
	history.add_child(history_column)
	history_column.add_child(UIFactory.section_heading("PROGRESSION JOURNAL", "Most recent career rewards"))
	if coach.history.is_empty():
		history_column.add_child(UIFactory.wrapped_label("Play or simulate games to begin earning XP.", "MutedLabel"))
	for entry in coach.history.slice(0, 8):
		history_column.add_child(UIFactory.wrapped_label("+%d XP · %s%s" % [entry.get("xp", 0), entry.get("reason", ""), " · LEVEL UP" if int(entry.get("levels", 0)) > 0 else ""], "BodyLabel"))
	_page.add_child(history)
	_apply_responsive_layout()


func _skill_card(definition: Dictionary, coach: CoachProgressData) -> PanelContainer:
	var skill_id := str(definition["id"])
	var rank := coach.rank_of(skill_id)
	var error := CoachProgressionService.unlock_error(coach, skill_id)
	var panel := UIFactory.card("AccentPanel" if rank > 0 else "CardPanel")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(7)
	panel.add_child(column)
	var status := "LEARNED" if rank > 0 else ("AVAILABLE" if error.is_empty() else "LOCKED")
	column.add_child(UIFactory.label("TIER %d · %s · %s" % [definition["tier"], str(definition["lane"]).to_upper(), status], "EyebrowLabel"))
	var button := UIFactory.button(str(definition["name"]), "SecondaryButton" if skill_id == _selected_skill else "GhostButton")
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.tooltip_text = CoachSkillCatalog.effect_text(definition) + "\n" + error
	button.pressed.connect(_select_skill.bind(skill_id))
	column.add_child(button)
	panel.set_meta("select_button", button)
	column.add_child(UIFactory.label("RANK %d / %d · %d PT%s%s" % [rank, definition["max_rank"], definition["cost"], "S" if int(definition["cost"]) > 1 else "", " · SIGNATURE" if definition["signature"] else ""], "CaptionLabel"))
	var requirements: Array = definition.get("requires", [])
	column.add_child(UIFactory.wrapped_label("START HERE" if requirements.is_empty() else "Requires " + str(CoachSkillCatalog.skill(str(requirements[0]))["name"]), "CaptionLabel"))
	return panel


func _refresh_details() -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var definition := CoachSkillCatalog.skill(_selected_skill)
	if definition.is_empty():
		return
	var coach := _viewed_team.coach
	var rank := coach.rank_of(_selected_skill)
	_details.add_child(UIFactory.section_heading(str(definition["name"]), "Rank %d / %d" % [rank, definition["max_rank"]]))
	_details.add_child(UIFactory.wrapped_label("EACH RANK", "EyebrowLabel"))
	_details.add_child(UIFactory.wrapped_label(CoachSkillCatalog.effect_text(definition), "BodyLabel"))
	if rank > 0:
		_details.add_child(UIFactory.wrapped_label("CURRENT TOTAL\n" + CoachSkillCatalog.effect_text(definition, rank), "MutedLabel"))
	_details.add_child(UIFactory.wrapped_label("Requires %d points already invested in this branch.%s" % [
		definition["branch_points"], " Locks the competing identity in this branch." if not str(definition["exclusive_group"]).is_empty() else ""
	], "CaptionLabel"))
	var error := CoachProgressionService.unlock_error(coach, _selected_skill)
	var owned := _viewed_team.id == _career.league.user_team_id
	_buy_button = UIFactory.button("LEARN NEXT RANK · %d PT%s" % [definition["cost"], "S" if int(definition["cost"]) > 1 else ""], "PrimaryButton")
	_buy_button.disabled = not owned or not error.is_empty() or not _career.coach_change_error().is_empty()
	_buy_button.pressed.connect(func(): _apply_result(_career.learn_coach_skill(_selected_skill)))
	_details.add_child(_buy_button)
	if not error.is_empty():
		_details.add_child(UIFactory.wrapped_label(error, "WarningLabel"))
	_details.add_child(UIFactory.divider())
	_details.add_child(UIFactory.section_heading("ACTIVE BUILD", "Conditional bonuses apply only in their stated situations."))
	_details.add_child(UIFactory.wrapped_label("Combined snap limits: ±1.6 yards, ±6 completion points, ±3.5 sack/explosive points, ±1.2 interception points, ±0.6 fumble points. Development chances cap at 65%.", "CaptionLabel"))
	for skill_id in coach.ranks:
		var active := CoachSkillCatalog.skill(str(skill_id))
		_details.add_child(UIFactory.wrapped_label("%s · Rank %d\n%s" % [active.get("name", skill_id), coach.rank_of(str(skill_id)), CoachSkillCatalog.effect_text(active, coach.rank_of(str(skill_id)))], "CaptionLabel"))
	if coach.ranks.is_empty():
		_details.add_child(UIFactory.wrapped_label("No skills learned yet.", "MutedLabel"))


func _select_branch(branch: String) -> void:
	_selected_branch = branch
	_selected_skill = ""
	_rebuild()


func _select_skill(skill_id: String) -> void:
	_selected_skill = skill_id
	for node_id in _tree.skill_nodes:
		var button: Button = _tree.skill_nodes[node_id].get_meta("select_button")
		button.theme_type_variation = "SecondaryButton" if node_id == skill_id else "GhostButton"
	_refresh_details()
	if _body.columns == 1:
		_reveal_purchase.call_deferred()


func _reveal_purchase() -> void:
	# A purchase or team switch can rebuild the inspector before deferred layout.
	# Resolve the current button instead of retaining a detached control.
	if is_instance_valid(_buy_button) and _scroll.is_ancestor_of(_buy_button) and _body.columns == 1:
		_scroll.ensure_control_visible(_buy_button)


func _choose_background(background: String) -> void:
	_apply_result(_career.choose_coach_background(background))


func _apply_result(result: Dictionary) -> void:
	_message = str(result.get("message", ""))
	if bool(result.get("ok", false)):
		coach_changed.emit()
	_rebuild()


func _apply_responsive_layout() -> void:
	if _body == null:
		return
	_summary.columns = 4 if size.x >= 1100 else (2 if size.x >= 520 else 1)
	_body.columns = 2 if size.x >= 1000 else 1
	_body.move_child(_detail_card if _body.columns == 1 else _tree, 0)
	_tree.columns = 2 if size.x >= 650 else 1
	_tree.queue_redraw()
