extends Control

signal back_requested
signal statistics_requested(player_id: String)

var _career: CareerSession
var _initial_player_id := ""
var _selected_player_id := ""
var _search_text := ""
var _team_filter := "ALL"
var _position_filter := "ALL"

var _profile_host: VBoxContainer
var _content_grid: GridContainer
var _attribute_grid: GridContainer
var _search_input: LineEdit
var _player_menu: OptionButton
var _team_menu: OptionButton
var _position_menu: OptionButton
var _result_label: Label
var _statistics_button: Button


func setup(career: CareerSession, initial_player_id: String = "") -> void:
	_career = career
	_initial_player_id = initial_player_id
	_selected_player_id = initial_player_id


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_rebuild_player_selector()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 820)
	scroll.add_child(page)

	var header := HFlowContainer.new()
	header.add_theme_constant_override("h_separation", 12)
	header.add_theme_constant_override("v_separation", 10)
	var badge := UIFactory.badge("DB", GridironTheme.ACCENT)
	header.add_child(badge)
	var identity := UIFactory.vbox(1)
	identity.custom_minimum_size = Vector2(410, 0)
	identity.add_child(UIFactory.label("PLAYER DATABASE", "PageTitleLabel"))
	identity.add_child(UIFactory.wrapped_label("NFLverse careers, contracts, and league data joined to complete Madden NFL 26 attributes.", "MutedLabel"))
	header.add_child(identity)
	header.add_child(UIFactory.spacer())
	header.add_child(_header_metric("PLAYERS", str(_career.league.all_players().size())))
	header.add_child(_header_metric("ROSTERED", str(_career.league.all_players(false).size())))
	header.add_child(_header_metric("FREE AGENTS", str(_career.league.free_agents.size())))
	var back := UIFactory.button("←  CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	page.add_child(header)

	var filters := UIFactory.card("RaisedCardPanel")
	var filter_flow := HFlowContainer.new()
	filter_flow.add_theme_constant_override("h_separation", 12)
	filter_flow.add_theme_constant_override("v_separation", 10)
	filters.add_child(filter_flow)
	var search_group := UIFactory.vbox(5)
	search_group.add_child(UIFactory.label("SEARCH", "EyebrowLabel"))
	_search_input = LineEdit.new()
	_search_input.placeholder_text = "Player name, position, or club"
	_search_input.custom_minimum_size = Vector2(330, 44)
	_search_input.text_changed.connect(_search_changed)
	search_group.add_child(_search_input)
	filter_flow.add_child(search_group)
	var player_group := UIFactory.vbox(5)
	player_group.add_child(UIFactory.label("LEAGUE DIRECTORY", "EyebrowLabel"))
	_player_menu = OptionButton.new()
	_player_menu.custom_minimum_size = Vector2(420, 44)
	_player_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_menu.fit_to_longest_item = false
	_player_menu.clip_text = true
	_player_menu.item_selected.connect(_player_selected)
	player_group.add_child(_player_menu)
	filter_flow.add_child(player_group)
	var team_group := UIFactory.vbox(5)
	team_group.add_child(UIFactory.label("CLUB", "EyebrowLabel"))
	_team_menu = OptionButton.new()
	_team_menu.custom_minimum_size = Vector2(230, 44)
	_team_menu.add_item("ALL CLUBS")
	_team_menu.set_item_metadata(0, "ALL")
	for team in _career.league.teams:
		_team_menu.add_item(team.display_name())
		_team_menu.set_item_metadata(_team_menu.item_count - 1, team.id)
	_team_menu.add_item("FREE AGENTS")
	_team_menu.set_item_metadata(_team_menu.item_count - 1, "FA")
	_team_menu.item_selected.connect(_team_filter_changed)
	team_group.add_child(_team_menu)
	filter_flow.add_child(team_group)
	var position_group := UIFactory.vbox(5)
	position_group.add_child(UIFactory.label("POSITION", "EyebrowLabel"))
	_position_menu = OptionButton.new()
	_position_menu.custom_minimum_size = Vector2(170, 44)
	_position_menu.add_item("ALL POSITIONS")
	for position_name in TeamData.ROSTER_POSITIONS:
		_position_menu.add_item(position_name)
	_position_menu.item_selected.connect(_position_filter_changed)
	position_group.add_child(_position_menu)
	filter_flow.add_child(position_group)
	filter_flow.add_child(UIFactory.spacer())
	_result_label = UIFactory.label("", "CaptionLabel")
	filter_flow.add_child(_result_label)
	page.add_child(filters)

	_content_grid = GridContainer.new()
	_content_grid.columns = 1
	_content_grid.add_theme_constant_override("h_separation", 14)
	_content_grid.add_theme_constant_override("v_separation", 14)
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_content_grid)

	var profile_card := UIFactory.card("RaisedCardPanel")
	profile_card.custom_minimum_size = Vector2(0, 760)
	profile_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_profile_host = UIFactory.vbox(15)
	profile_card.add_child(_profile_host)
	_content_grid.add_child(profile_card)


func _rebuild_player_selector() -> void:
	if _player_menu == null:
		return
	_player_menu.clear()
	var players := _filtered_players()
	if players.is_empty():
		_result_label.text = "0 RESULTS"
		_selected_player_id = ""
		_player_menu.add_item("No players match the active filters")
		_player_menu.set_item_disabled(0, true)
		_rebuild_profile()
		return
	if not players.any(func(player: PlayerData): return player.id == _selected_player_id):
		_selected_player_id = players.front().id
	var selected_index := 0
	for player in players:
		var team := _career.league.team_for_player(player.id)
		var club := team.abbreviation if team != null else "FA"
		var jersey := "#%d " % player.jersey_number if player.jersey_number > 0 else ""
		_player_menu.add_item(
			"%s%s · %s · %s · OVR %d · AGE %d" % [jersey, player.position, player.full_name, club, player.overall, player.age]
		)
		var index := _player_menu.item_count - 1
		_player_menu.set_item_metadata(index, player.id)
		if player.id == _selected_player_id:
			selected_index = index
	_player_menu.select(selected_index)
	_result_label.text = "%d RESULT%s" % [players.size(), "" if players.size() == 1 else "S"]
	_rebuild_profile()


func _rebuild_profile() -> void:
	if _profile_host == null:
		return
	_clear(_profile_host)
	var player := _career.league.player_by_id(_selected_player_id)
	if player == null:
		_profile_host.add_child(UIFactory.label("NO PLAYER SELECTED", "SectionTitleLabel"))
		_profile_host.add_child(UIFactory.wrapped_label("Adjust the filters and select a player from the league directory dropdown to open the complete profile.", "MutedLabel"))
		return
	var team := _career.league.team_for_player(player.id)
	var team_color := team.primary_color if team != null else GridironTheme.ACCENT
	var ratings := player.madden_ratings

	var hero := HFlowContainer.new()
	hero.add_theme_constant_override("h_separation", 16)
	hero.add_theme_constant_override("v_separation", 12)
	var portrait := CachedRemoteImage.new()
	portrait.setup(
		ratings.portrait_url if ratings != null else "",
		"player_%s" % player.id,
		_initials(player.full_name),
		team_color,
		Vector2(190, 210)
	)
	hero.add_child(portrait)
	var copy := UIFactory.vbox(6)
	copy.custom_minimum_size = Vector2(310, 0)
	var club_label := team.display_name().to_upper() if team != null else "FREE AGENT"
	copy.add_child(UIFactory.label("%s · %s" % [club_label, ratings.iteration.to_upper() if ratings != null else "GRIDIRON PROJECTION"], "EyebrowLabel"))
	copy.add_child(UIFactory.label(player.full_name, "PageTitleLabel"))
	var identity_line := "%s · %s · AGE %d · %d YRS PRO" % [
		"#%d" % player.jersey_number if player.jersey_number > 0 else "NO NUMBER",
		player.position,
		player.age,
		player.experience_years,
	]
	copy.add_child(UIFactory.label(identity_line, "MutedLabel"))
	copy.add_child(UIFactory.wrapped_label("%s · %s · %d lb · %s" % [player.archetype, player.height_label(), player.weight_lbs, player.college], "BodyLabel"))
	copy.add_child(UIFactory.label(player.availability_label(), "CaptionLabel"))
	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 8)
	_statistics_button = UIFactory.button("VIEW STATISTICS", "SecondaryButton")
	_statistics_button.pressed.connect(func(): statistics_requested.emit(player.id))
	actions.add_child(_statistics_button)
	copy.add_child(actions)
	hero.add_child(copy)
	hero.add_child(UIFactory.spacer())
	var visual_column := UIFactory.vbox(10)
	var overall_card := UIFactory.card("AccentPanel")
	var overall_column := UIFactory.vbox(0)
	overall_column.alignment = BoxContainer.ALIGNMENT_CENTER
	var overall_label := UIFactory.label(str(player.overall), "DisplayLabel")
	overall_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overall_label.modulate = _rating_color(player.overall)
	overall_column.add_child(overall_label)
	var overall_caption := UIFactory.label("OVERALL", "CaptionLabel")
	overall_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overall_column.add_child(overall_caption)
	overall_card.add_child(overall_column)
	visual_column.add_child(overall_card)
	var logo_url := team.logo_url if team != null else (ratings.source_team_logo_url if ratings != null else "")
	var logo := CachedRemoteImage.new()
	logo.setup(logo_url, "team_%s" % (team.id if team != null else ratings.source_team_name), team.abbreviation if team != null else "FA", team_color, Vector2(104, 104))
	visual_column.add_child(logo)
	hero.add_child(visual_column)
	_profile_host.add_child(hero)

	_profile_host.add_child(_build_contract_card(player, team))
	_profile_host.add_child(_build_core_ratings_card(player, team_color))
	if ratings != null and not ratings.abilities.is_empty():
		_profile_host.add_child(_build_abilities_card(ratings))
	_profile_host.add_child(UIFactory.label("COMPLETE ATTRIBUTE PROFILE", "SectionTitleLabel"))
	_profile_host.add_child(UIFactory.wrapped_label("Every source attribute is retained. Position-relevant groups appear first; wider windows show two attribute groups per row.", "CaptionLabel"))
	_attribute_grid = GridContainer.new()
	_attribute_grid.columns = 2
	_attribute_grid.add_theme_constant_override("h_separation", 12)
	_attribute_grid.add_theme_constant_override("v_separation", 12)
	_attribute_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if ratings != null:
		for category_name in ratings.category_names_for(player.position):
			_attribute_grid.add_child(_attribute_card(ratings, category_name, team_color))
	_profile_host.add_child(_attribute_grid)
	_apply_responsive_layout()


func _build_contract_card(player: PlayerData, team: TeamData) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(9)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	heading.add_child(UIFactory.label("CONTRACT & STATUS", "SectionTitleLabel"))
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.badge("SIGNED" if player.contract != null else "FREE AGENT", GridironTheme.ACCENT if player.contract != null else GridironTheme.WARM))
	column.add_child(heading)
	var metrics := HFlowContainer.new()
	metrics.add_theme_constant_override("h_separation", 22)
	metrics.add_theme_constant_override("v_separation", 10)
	if player.contract != null:
		metrics.add_child(_header_metric("APY", PlayerContract.money_label(player.contract.annual_salary)))
		metrics.add_child(_header_metric("CAP HIT", PlayerContract.money_label(player.contract.current_cap_hit())))
		metrics.add_child(_header_metric("REMAINING", "%d YEAR%s" % [player.contract.years_remaining, "" if player.contract.years_remaining == 1 else "S"]))
		metrics.add_child(_header_metric("TOTAL VALUE", PlayerContract.money_label(player.contract.total_value())))
		metrics.add_child(_header_metric("GUARANTEED", PlayerContract.money_label(player.contract.total_guaranteed)))
		metrics.add_child(_header_metric("ROLE", player.contract.role.to_upper()))
	else:
		var estimate := TransactionService.market_offer(_career.league, _career.user_team(), player, 2, 1.0)
		metrics.add_child(_header_metric("MARKET ASK", "%s / YR" % PlayerContract.money_label(estimate.annual_salary)))
		metrics.add_child(_header_metric("PROJECTED ROLE", TransactionService.projected_role(_career.user_team(), player).to_upper()))
	metrics.add_child(_header_metric("CLUB", team.abbreviation if team != null else "FA"))
	column.add_child(metrics)
	return card


func _build_core_ratings_card(player: PlayerData, color: Color) -> PanelContainer:
	var card := UIFactory.card("AccentPanel")
	var column := UIFactory.vbox(10)
	card.add_child(column)
	var heading := UIFactory.hbox(8)
	heading.add_child(UIFactory.label("PLAYER DNA", "SectionTitleLabel"))
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.label("SOURCE OVR %d" % player.madden_ratings.source_overall, "CaptionLabel"))
	column.add_child(heading)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 9)
	for entry in [["SPEED", player.speed], ["POWER", player.power], ["TECHNIQUE", player.technique], ["AWARENESS", player.awareness], ["DURABILITY", player.durability], ["POTENTIAL", player.potential]]:
		var bar := UIFactory.stat_bar(str(entry[0]), int(entry[1]), color)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(bar)
	column.add_child(grid)
	var details := "Source: %s" % player.madden_ratings.source
	if not player.madden_ratings.running_style.is_empty():
		details += " · Running style: %s" % player.madden_ratings.running_style
	column.add_child(UIFactory.wrapped_label(details, "CaptionLabel"))
	return card


func _build_abilities_card(ratings: PlayerRatingsData) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(9)
	card.add_child(column)
	column.add_child(UIFactory.label("SIGNATURE ABILITIES", "SectionTitleLabel"))
	for ability in ratings.abilities:
		var heading := UIFactory.hbox(8)
		heading.add_child(UIFactory.badge(str(ability.get("type", "ABILITY")).to_upper(), GridironTheme.WARM))
		heading.add_child(UIFactory.label(str(ability.get("label", "Ability")), "BodyLabel"))
		column.add_child(heading)
		column.add_child(UIFactory.wrapped_label(str(ability.get("description", "")), "MutedLabel"))
	return card


func _attribute_card(ratings: PlayerRatingsData, category_name: String, color: Color) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(300, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(8)
	card.add_child(column)
	column.add_child(UIFactory.label(category_name.to_upper(), "EyebrowLabel"))
	for row in ratings.rows_for_category(category_name):
		column.add_child(UIFactory.stat_bar(str(row.label), int(row.value), color))
	return card


func _filtered_players() -> Array[PlayerData]:
	var players: Array[PlayerData] = []
	for player in _career.league.all_players():
		var team := _career.league.team_for_player(player.id)
		if _team_filter == "FA" and team != null:
			continue
		if _team_filter not in ["ALL", "FA"] and (team == null or team.id != _team_filter):
			continue
		if _position_filter != "ALL" and player.position != _position_filter:
			continue
		if not _search_text.is_empty():
			var haystack := "%s %s %s" % [player.full_name, player.position, team.display_name() if team != null else "free agent"]
			if not haystack.to_lower().contains(_search_text):
				continue
		players.append(player)
	players.sort_custom(func(a: PlayerData, b: PlayerData):
		if a.overall != b.overall:
			return a.overall > b.overall
		return a.full_name < b.full_name
	)
	return players


func _select_player(player_id: String) -> void:
	_selected_player_id = player_id
	for index in range(_player_menu.item_count):
		if str(_player_menu.get_item_metadata(index)) == player_id:
			_player_menu.select(index)
			break
	_rebuild_profile()


func _player_selected(index: int) -> void:
	var player_id := str(_player_menu.get_item_metadata(index))
	if player_id.is_empty():
		return
	_selected_player_id = player_id
	_rebuild_profile()


func _search_changed(value: String) -> void:
	_search_text = value.strip_edges().to_lower()
	_rebuild_player_selector()


func _team_filter_changed(index: int) -> void:
	_team_filter = str(_team_menu.get_item_metadata(index))
	_rebuild_player_selector()


func _position_filter_changed(index: int) -> void:
	_position_filter = "ALL" if index == 0 else TeamData.ROSTER_POSITIONS[index - 1]
	_rebuild_player_selector()


func _header_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(1)
	metric.custom_minimum_size = Vector2(92, 0)
	var value_label := UIFactory.label(value, "MetricLabel")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(value_label)
	var title_label := UIFactory.label(title, "CaptionLabel")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	metric.add_child(title_label)
	return metric


func _initials(full_name: String) -> String:
	var words := full_name.split(" ", false)
	var result := ""
	for word in words:
		if not word.is_empty():
			result += word.substr(0, 1).to_upper()
	return result.substr(0, 2)


func _rating_color(value: int) -> Color:
	if value >= 90:
		return GridironTheme.ACCENT
	if value >= 80:
		return Color("68b6ff")
	if value >= 70:
		return GridironTheme.WARM
	return GridironTheme.TEXT_MUTED


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _apply_responsive_layout() -> void:
	if _content_grid != null:
		_content_grid.columns = 1
	if _attribute_grid != null:
		_attribute_grid.columns = 2 if size.x >= 1180 else 1
