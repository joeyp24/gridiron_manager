extends Control

signal back_requested

const VIEW_LEADERS := "LEAGUE LEADERS"
const VIEW_TEAMS := "TEAM RANKINGS"
const VIEW_PLAYER := "PLAYER PROFILE"
const VIEW_GAMES := "GAME BOOKS"
const VIEWS: Array[String] = [VIEW_LEADERS, VIEW_TEAMS, VIEW_PLAYER, VIEW_GAMES]

var _career: CareerSession
var _league: LeagueState
var _initial_player_id := ""
var _selected_view := VIEW_LEADERS
var _selected_player_category := "Passing"
var _selected_team_category := "Offense"
var _selected_year := 2026
var _selected_phase := StatisticsService.PHASE_ALL
var _selected_team_id := ""
var _selected_position := ""
var _selected_player_id := ""
var _selected_book_id := ""
var _player_sort_stat := "passing_yards"
var _player_sort_descending := true
var _team_sort_stat := "yards_per_game"
var _team_sort_descending := true

var _content_host: VBoxContainer
var _view_buttons: Dictionary = {}
var _season_menu: OptionButton
var _phase_menu: OptionButton
var _team_menu: OptionButton
var _position_menu: OptionButton
var _content_grid: GridContainer
var _leader_rows: Array[Dictionary] = []
var _team_rows: Array[Dictionary] = []
var _game_books: Array[GameBookData] = []
var _category_buttons: Array[Button] = []


func setup(career: CareerSession, initial_player_id: String = "") -> void:
	_career = career
	_league = career.league
	_selected_year = _league.season_year
	_initial_player_id = initial_player_id
	_selected_player_id = initial_player_id
	if not initial_player_id.is_empty():
		_selected_view = VIEW_PLAYER


func _ready() -> void:
	_build_interface()
	resized.connect(_apply_responsive_layout)
	_apply_responsive_layout()
	_rebuild_content()


func _build_interface() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := UIFactory.vbox(16)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(0, 760)
	scroll.add_child(page)

	var header := UIFactory.hbox(14)
	header.add_child(UIFactory.badge("DATA", _league.user_team().primary_color))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label("LEAGUE INTELLIGENCE", "EyebrowLabel"))
	identity.add_child(UIFactory.label("Statistics Center", "PageTitleLabel"))
	identity.add_child(UIFactory.label("Every game, every club, every player — from weekly form to career production.", "MutedLabel"))
	header.add_child(identity)
	var back := UIFactory.button("←  CAREER HUB", "GhostButton")
	back.pressed.connect(func(): back_requested.emit())
	header.add_child(back)
	page.add_child(header)

	var current_season := _league.statistics.season(_league.season_year)
	var game_count := current_season.game_books.size() if current_season != null else 0
	var coverage := UIFactory.card("RaisedCardPanel")
	page.add_child(coverage)
	var coverage_flow := HFlowContainer.new()
	coverage_flow.add_theme_constant_override("h_separation", 28)
	coverage_flow.add_theme_constant_override("v_separation", 12)
	coverage.add_child(coverage_flow)
	coverage_flow.add_child(_header_metric("GAMES TRACKED", str(game_count)))
	coverage_flow.add_child(_header_metric("PLAYER CAREERS", str(_league.statistics.career_player_totals.size())))
	coverage_flow.add_child(_header_metric("SEASONS", str(StatisticsService.season_years(_league).size())))
	coverage_flow.add_child(_header_metric("CLUBS", str(_league.teams.size())))
	var coverage_copy := UIFactory.wrapped_label("Completed games are locked into the historical record and roll into season and career totals exactly once.", "CaptionLabel")
	coverage_copy.custom_minimum_size = Vector2(360, 0)
	coverage_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coverage_flow.add_child(coverage_copy)

	var navigation := HFlowContainer.new()
	navigation.add_theme_constant_override("h_separation", 8)
	navigation.add_theme_constant_override("v_separation", 8)
	var view_group := ButtonGroup.new()
	for view_name in VIEWS:
		var button := UIFactory.button(view_name, "SecondaryButton" if view_name == _selected_view else "GhostButton")
		button.toggle_mode = true
		button.button_group = view_group
		button.button_pressed = view_name == _selected_view
		button.pressed.connect(_select_view.bind(view_name))
		navigation.add_child(button)
		_view_buttons[view_name] = button
	page.add_child(navigation)

	var filter_card := UIFactory.card()
	page.add_child(filter_card)
	var filters := HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 14)
	filters.add_theme_constant_override("v_separation", 10)
	filter_card.add_child(filters)
	filters.add_child(_filter_group("SEASON", _build_season_menu()))
	filters.add_child(_filter_group("SPLIT", _build_phase_menu()))
	filters.add_child(_filter_group("CLUB", _build_team_menu()))
	filters.add_child(_filter_group("POSITION", _build_position_menu()))
	var helper := UIFactory.wrapped_label("Filters update leaders, profiles, rankings, and historical game books without changing the underlying totals.", "CaptionLabel")
	helper.custom_minimum_size = Vector2(300, 0)
	helper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(helper)

	_content_host = UIFactory.vbox(14)
	_content_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_content_host)


func _build_season_menu() -> OptionButton:
	_season_menu = OptionButton.new()
	_season_menu.custom_minimum_size = Vector2(126, 44)
	for year in StatisticsService.season_years(_league):
		_season_menu.add_item(str(year))
		_season_menu.set_item_metadata(_season_menu.item_count - 1, year)
	_season_menu.item_selected.connect(func(index: int):
		_selected_year = int(_season_menu.get_item_metadata(index))
		_selected_book_id = ""
		_rebuild_content()
	)
	return _season_menu


func _build_phase_menu() -> OptionButton:
	_phase_menu = OptionButton.new()
	_phase_menu.custom_minimum_size = Vector2(168, 44)
	for phase_name in [StatisticsService.PHASE_ALL, StatisticsService.PHASE_REGULAR, StatisticsService.PHASE_POSTSEASON]:
		_phase_menu.add_item(phase_name)
		_phase_menu.set_item_metadata(_phase_menu.item_count - 1, phase_name)
	_phase_menu.item_selected.connect(func(index: int):
		_selected_phase = str(_phase_menu.get_item_metadata(index))
		_selected_book_id = ""
		_rebuild_content()
	)
	return _phase_menu


func _build_team_menu() -> OptionButton:
	_team_menu = OptionButton.new()
	_team_menu.custom_minimum_size = Vector2(184, 44)
	_team_menu.add_item("All clubs")
	_team_menu.set_item_metadata(0, "")
	var teams := _league.teams.duplicate()
	teams.sort_custom(func(a: TeamData, b: TeamData): return a.display_name() < b.display_name())
	for team in teams:
		_team_menu.add_item("%s · %s" % [team.abbreviation, team.city])
		_team_menu.set_item_metadata(_team_menu.item_count - 1, team.id)
	_team_menu.item_selected.connect(func(index: int):
		_selected_team_id = str(_team_menu.get_item_metadata(index))
		_selected_book_id = ""
		_rebuild_content()
	)
	return _team_menu


func _build_position_menu() -> OptionButton:
	_position_menu = OptionButton.new()
	_position_menu.custom_minimum_size = Vector2(128, 44)
	_position_menu.add_item("All positions")
	_position_menu.set_item_metadata(0, "")
	for position_name in TeamData.ROSTER_POSITIONS:
		_position_menu.add_item(position_name)
		_position_menu.set_item_metadata(_position_menu.item_count - 1, position_name)
	_position_menu.item_selected.connect(func(index: int):
		_selected_position = str(_position_menu.get_item_metadata(index))
		_rebuild_content()
	)
	return _position_menu


func _filter_group(title: String, menu: OptionButton) -> VBoxContainer:
	var group := UIFactory.vbox(4)
	group.add_child(UIFactory.label(title, "EyebrowLabel"))
	group.add_child(menu)
	return group


func _select_view(view_name: String) -> void:
	_selected_view = view_name
	for name in _view_buttons:
		var button: Button = _view_buttons[name]
		button.button_pressed = name == view_name
		button.theme_type_variation = "SecondaryButton" if name == view_name else "GhostButton"
	_rebuild_content()


func _rebuild_content() -> void:
	if _content_host == null:
		return
	_clear(_content_host)
	_content_grid = null
	_category_buttons.clear()
	match _selected_view:
		VIEW_TEAMS:
			_build_team_rankings()
		VIEW_PLAYER:
			_build_player_profile()
		VIEW_GAMES:
			_build_game_books()
		_:
			_build_league_leaders()
	_apply_responsive_layout()


func _build_league_leaders() -> void:
	_content_host.add_child(_section_heading("LEAGUE LEADERS", "Sortable production across every recorded player and club split."))
	_content_host.add_child(_category_navigation(StatisticsService.player_category_names(), _selected_player_category, _select_player_category))
	var rows := StatisticsService.player_rows(_league, _selected_year, _selected_phase, _selected_team_id, _selected_position)
	_leader_rows = StatisticsService.sorted_player_rows(rows, _selected_player_category)
	_leader_rows = StatisticsService.sort_player_rows(_leader_rows, _player_sort_stat, _player_sort_descending)
	if _leader_rows.is_empty():
		_content_host.add_child(_empty_state("No players match these filters yet."))
		return
	var podium := HFlowContainer.new()
	podium.add_theme_constant_override("h_separation", 12)
	podium.add_theme_constant_override("v_separation", 12)
	var category: Dictionary = StatisticsService.PLAYER_CATEGORIES[_selected_player_category]
	var sort_stat := _player_sort_stat
	for index in range(mini(3, _leader_rows.size())):
		var row: Dictionary = _leader_rows[index]
		var card := UIFactory.card("AccentPanel" if index == 0 else "RaisedCardPanel")
		card.custom_minimum_size = Vector2(260, 0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var column := UIFactory.vbox(5)
		card.add_child(column)
		column.add_child(UIFactory.label("#%d · %s" % [index + 1, _selected_player_category.to_upper()], "EyebrowLabel"))
		var player_button := UIFactory.button(str(row.get("full_name", "Unknown Player")), "GhostButton")
		player_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_button.pressed.connect(_open_player.bind(str(row.get("player_id", ""))))
		column.add_child(player_button)
		column.add_child(UIFactory.label("%s · %s" % [row.get("position", ""), row.get("team_label", "FA")], "CaptionLabel"))
		column.add_child(UIFactory.label(StatisticsService.format_metric(row.get("stats"), sort_stat), "MetricLabel"))
		column.add_child(UIFactory.label(_metric_label(sort_stat), "CaptionLabel"))
		podium.add_child(card)
	_content_host.add_child(podium)
	_content_host.add_child(_player_table(_leader_rows, category))


func _build_team_rankings() -> void:
	_content_host.add_child(_section_heading("TEAM RANKINGS", "Club performance normalized across the selected season and phase."))
	_content_host.add_child(_category_navigation(StatisticsService.team_category_names(), _selected_team_category, _select_team_category))
	_team_rows = StatisticsService.sorted_team_rows(
		StatisticsService.team_rows(_league, _selected_year, _selected_phase),
		_selected_team_category
	)
	_team_rows = StatisticsService.sort_team_rows(_team_rows, _team_sort_stat, _team_sort_descending)
	if not _selected_team_id.is_empty():
		_team_rows = _team_rows.filter(func(row: Dictionary): return str(row.get("team_id", "")) == _selected_team_id)
	var category: Dictionary = StatisticsService.TEAM_CATEGORIES[_selected_team_category]
	_content_host.add_child(_team_table(_team_rows, category))


func _build_player_profile() -> void:
	var all_rows := StatisticsService.player_rows(_league, _selected_year, _selected_phase)
	var selectable_rows := StatisticsService.player_rows(_league, _selected_year, _selected_phase, _selected_team_id, _selected_position)
	var filters_active := not _selected_team_id.is_empty() or not _selected_position.is_empty()
	var profile_rows := selectable_rows if filters_active else all_rows
	var row := _find_player_row(profile_rows, _selected_player_id)
	if row.is_empty():
		if not selectable_rows.is_empty():
			_selected_player_id = str(selectable_rows.front().get("player_id", ""))
		elif not filters_active:
			var starter := _league.user_team().player_at("QB")
			_selected_player_id = starter.id if starter != null else ""
		row = _find_player_row(profile_rows, _selected_player_id)
	if row.is_empty():
		_content_host.add_child(_empty_state("No player profile is available for this season."))
		return
	_selected_player_id = str(row.get("player_id", ""))
	var team_label := str(row.get("team_label", "FA"))
	var heading := UIFactory.hbox(12)
	heading.add_child(UIFactory.badge(str(row.get("position", "")), _player_color(row)))
	var identity := UIFactory.vbox(1)
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_child(UIFactory.label("PLAYER DOSSIER · %s" % team_label, "EyebrowLabel"))
	identity.add_child(UIFactory.label(str(row.get("full_name", "Unknown Player")), "PageTitleLabel"))
	identity.add_child(UIFactory.label("%d season · %s" % [_selected_year, _selected_phase], "MutedLabel"))
	heading.add_child(identity)
	var back_to_leaders := UIFactory.button("VIEW LEADERS", "SecondaryButton")
	back_to_leaders.pressed.connect(_select_view.bind(VIEW_LEADERS))
	heading.add_child(back_to_leaders)
	_content_host.add_child(heading)
	_content_host.add_child(_player_picker(selectable_rows, _selected_player_id))

	_content_grid = GridContainer.new()
	_content_grid.columns = 2
	_content_grid.add_theme_constant_override("h_separation", 14)
	_content_grid.add_theme_constant_override("v_separation", 14)
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_content_grid)
	_content_grid.add_child(_profile_summary_card(row))
	_content_grid.add_child(_career_summary_card(row))
	_content_grid.add_child(_team_splits_card(row))
	_content_grid.add_child(_career_history_card(row))
	_content_grid.add_child(_game_log_card(row))


func _build_game_books() -> void:
	_content_host.add_child(_section_heading("GAME BOOKS", "Final scores, team comparisons, and complete participant box scores."))
	_game_books = StatisticsService.completed_games(_league, _selected_year, _selected_phase, _selected_team_id)
	if _game_books.is_empty():
		_content_host.add_child(_empty_state("No completed games match these filters."))
		return
	if _selected_book_id.is_empty() or not _game_books.any(func(book: GameBookData): return book.matchup_id == _selected_book_id):
		_selected_book_id = _game_books.front().matchup_id
	var selected_book: GameBookData
	for book in _game_books:
		if book.matchup_id == _selected_book_id:
			selected_book = book
			break
	_content_grid = GridContainer.new()
	_content_grid.columns = 2
	_content_grid.add_theme_constant_override("h_separation", 14)
	_content_grid.add_theme_constant_override("v_separation", 14)
	_content_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_host.add_child(_content_grid)
	_content_grid.add_child(_game_list_card())
	_content_grid.add_child(_game_detail_card(selected_book))


func _category_navigation(names: Array[String], selected: String, callback: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for category_name in names:
		var button := UIFactory.button(category_name.to_upper(), "SecondaryButton" if category_name == selected else "GhostButton")
		button.pressed.connect(callback.bind(category_name))
		flow.add_child(button)
		_category_buttons.append(button)
	return flow


func _select_player_category(category_name: String) -> void:
	_selected_player_category = category_name
	var category: Dictionary = StatisticsService.PLAYER_CATEGORIES[category_name]
	_player_sort_stat = str(category.get("sort", "games_played"))
	_player_sort_descending = true
	_rebuild_content()


func _select_team_category(category_name: String) -> void:
	_selected_team_category = category_name
	var category: Dictionary = StatisticsService.TEAM_CATEGORIES[category_name]
	_team_sort_stat = str(category.get("sort", "points"))
	_team_sort_descending = bool(category.get("descending", true))
	_rebuild_content()


func _sort_players(stat_name: String) -> void:
	if _player_sort_stat == stat_name:
		_player_sort_descending = not _player_sort_descending
	else:
		_player_sort_stat = stat_name
		_player_sort_descending = true
	_rebuild_content()


func _sort_teams(stat_name: String) -> void:
	if _team_sort_stat == stat_name:
		_team_sort_descending = not _team_sort_descending
	else:
		_team_sort_stat = stat_name
		_team_sort_descending = true
	_rebuild_content()


func _open_player(player_id: String) -> void:
	_selected_player_id = player_id
	_select_view(VIEW_PLAYER)


func _player_table(rows: Array[Dictionary], category: Dictionary) -> PanelContainer:
	var card := UIFactory.card()
	var column := UIFactory.vbox(8)
	card.add_child(column)
	var table_columns: Array = category.get("columns", [])
	var visible_count := mini(rows.size(), 100)
	column.add_child(UIFactory.label("%d PLAYER%s · TOP %d SHOWN" % [rows.size(), "" if rows.size() == 1 else "S", visible_count], "CaptionLabel"))
	var table_scroll := ScrollContainer.new()
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(table_scroll)
	var table := UIFactory.vbox(4)
	table.custom_minimum_size.x = 400 + table_columns.size() * 78
	table_scroll.add_child(table)
	table.add_child(_player_table_row({}, table_columns, -1, true))
	for index in range(visible_count):
		table.add_child(_player_table_row(rows[index], table_columns, index, false))
	return card


func _player_table_row(row: Dictionary, columns: Array, index: int, header: bool) -> PanelContainer:
	var panel := UIFactory.card("RaisedCardPanel" if header else "InsetPanel")
	var line := UIFactory.hbox(4)
	panel.add_child(line)
	line.add_child(_table_label("RK" if header else str(index + 1), 42, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	if header:
		line.add_child(_table_label("PLAYER", 210, "CaptionLabel"))
	else:
		var player_button := UIFactory.button(str(row.get("full_name", "Unknown Player")), "GhostButton")
		player_button.custom_minimum_size = Vector2(210, 36)
		player_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		player_button.pressed.connect(_open_player.bind(str(row.get("player_id", ""))))
		line.add_child(player_button)
	line.add_child(_table_label("POS" if header else str(row.get("position", "")), 52, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	line.add_child(_table_label("CLUB" if header else str(row.get("team_label", "FA")), 72, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var stats: StatLineData = row.get("stats")
	for definition in columns:
		var label_text := str(definition[0])
		var stat_name := str(definition[1])
		if header:
			line.add_child(_sort_button(label_text, stat_name, 74, true))
		else:
			line.add_child(_table_label(StatisticsService.format_metric(stats, stat_name), 74, "BodyLabel", HORIZONTAL_ALIGNMENT_RIGHT))
	return panel


func _team_table(rows: Array[Dictionary], category: Dictionary) -> PanelContainer:
	var card := UIFactory.card()
	var column := UIFactory.vbox(8)
	card.add_child(column)
	var table_columns: Array = category.get("columns", [])
	column.add_child(UIFactory.label("%d CLUBS · %s · %d" % [rows.size(), _selected_phase.to_upper(), _selected_year], "CaptionLabel"))
	var table_scroll := ScrollContainer.new()
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(table_scroll)
	var table := UIFactory.vbox(4)
	table.custom_minimum_size.x = 400 + table_columns.size() * 82
	table_scroll.add_child(table)
	table.add_child(_team_table_row({}, table_columns, -1, true))
	for index in range(rows.size()):
		table.add_child(_team_table_row(rows[index], table_columns, index, false))
	return card


func _team_table_row(row: Dictionary, columns: Array, index: int, header: bool) -> PanelContainer:
	var panel := UIFactory.card("RaisedCardPanel" if header else "InsetPanel")
	var line := UIFactory.hbox(4)
	panel.add_child(line)
	line.add_child(_table_label("RK" if header else str(index + 1), 42, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	line.add_child(_table_label("CLUB" if header else str(row.get("team_name", "")), 240, "CaptionLabel" if header else "BodyLabel"))
	line.add_child(_table_label("CONF" if header else str(row.get("conference", "")), 64, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	var stats: StatLineData = row.get("stats")
	for definition in columns:
		var stat_name := str(definition[1])
		if header:
			line.add_child(_sort_button(str(definition[0]), stat_name, 78, false))
		else:
			line.add_child(_table_label(StatisticsService.format_metric(stats, stat_name), 78, "BodyLabel", HORIZONTAL_ALIGNMENT_RIGHT))
	return panel


func _sort_button(title: String, stat_name: String, width: float, player_table: bool) -> Button:
	var active := (_player_sort_stat == stat_name) if player_table else (_team_sort_stat == stat_name)
	var descending := _player_sort_descending if player_table else _team_sort_descending
	var arrow := " ↓" if descending else " ↑"
	var button := UIFactory.button(title + (arrow if active else ""), "GhostButton")
	button.custom_minimum_size = Vector2(width, 36)
	button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.tooltip_text = "Sort by %s" % title
	if player_table:
		button.pressed.connect(_sort_players.bind(stat_name))
	else:
		button.pressed.connect(_sort_teams.bind(stat_name))
	return button


func _player_picker(rows: Array[Dictionary], selected_player_id: String) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 8)
	card.add_child(flow)
	flow.add_child(UIFactory.label("PLAYER FINDER", "EyebrowLabel"))
	var sorted_rows: Array[Dictionary] = rows.duplicate()
	sorted_rows.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.get("full_name", "")) < str(b.get("full_name", "")))
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(320, 44)
	var selected_index := 0
	for index in range(sorted_rows.size()):
		var player_row: Dictionary = sorted_rows[index]
		picker.add_item("%s · %s · %s" % [player_row.get("full_name", "Unknown Player"), player_row.get("position", ""), player_row.get("team_label", "FA")])
		picker.set_item_metadata(index, str(player_row.get("player_id", "")))
		if str(player_row.get("player_id", "")) == selected_player_id:
			selected_index = index
	if picker.item_count > 0:
		picker.select(selected_index)
	picker.disabled = picker.item_count == 0
	picker.item_selected.connect(func(index: int): _open_player(str(picker.get_item_metadata(index))))
	flow.add_child(picker)
	var description := "Use the club and position filters above to narrow the directory."
	flow.add_child(UIFactory.wrapped_label(description, "CaptionLabel"))
	return card


func _profile_summary_card(row: Dictionary) -> PanelContainer:
	var card := _profile_card("SEASON SNAPSHOT", "%d · %s" % [_selected_year, _selected_phase])
	var column: VBoxContainer = card.get_child(0)
	var stats: StatLineData = row.get("stats")
	column.add_child(_metric_flow(_profile_metrics(str(row.get("position", "")), stats)))
	column.add_child(UIFactory.label("%d offensive · %d defensive · %d special-teams snaps" % [stats.value("offensive_snaps"), stats.value("defensive_snaps"), stats.value("special_teams_snaps")], "CaptionLabel"))
	return card


func _career_summary_card(row: Dictionary) -> PanelContainer:
	var career_line := _league.player_career_statistics(str(row.get("player_id", "")))
	var stats := career_line.stats if career_line != null else StatLineData.new()
	var card := _profile_card("CAREER TOTALS", "Production follows the permanent player ID")
	var column: VBoxContainer = card.get_child(0)
	column.add_child(_metric_flow(_profile_metrics(str(row.get("position", "")), stats)))
	column.add_child(UIFactory.label("%d games · %d starts" % [stats.value("games_played"), stats.value("games_started")], "CaptionLabel"))
	return card


func _team_splits_card(row: Dictionary) -> PanelContainer:
	var splits := StatisticsService.player_team_splits(_league, str(row.get("player_id", "")), _selected_year, _selected_phase)
	var card := _profile_card("CLUB SPLITS", "Production remains separated after a trade")
	var column: VBoxContainer = card.get_child(0)
	if splits.is_empty():
		column.add_child(UIFactory.label("No game appearances in this split.", "MutedLabel"))
	else:
		for split in splits:
			var line := UIFactory.card("InsetPanel")
			var row_box := UIFactory.hbox(8)
			line.add_child(row_box)
			row_box.add_child(UIFactory.badge(str(split.get("team_label", "FA")), GridironTheme.BORDER))
			row_box.add_child(UIFactory.label(_compact_stat_line(str(row.get("position", "")), split.get("stats")), "MutedLabel"))
			column.add_child(line)
	return card


func _career_history_card(row: Dictionary) -> PanelContainer:
	var card := _profile_card("SEASON HISTORY", "Year-by-year career production")
	var column: VBoxContainer = card.get_child(0)
	var found := false
	for year in StatisticsService.season_years(_league):
		var season_rows := StatisticsService.player_rows(_league, year, StatisticsService.PHASE_ALL)
		var season_row := _find_player_row(season_rows, str(row.get("player_id", "")))
		if season_row.is_empty() or (season_row.get("stats") as StatLineData).value("games_played") <= 0:
			continue
		found = true
		var line := UIFactory.card("InsetPanel")
		var history_row := UIFactory.hbox(8)
		line.add_child(history_row)
		history_row.add_child(UIFactory.label(str(year), "EyebrowLabel"))
		history_row.add_child(UIFactory.label(str(season_row.get("team_label", "FA")), "CaptionLabel"))
		history_row.add_child(UIFactory.spacer())
		history_row.add_child(UIFactory.label(_compact_stat_line(str(row.get("position", "")), season_row.get("stats")), "MutedLabel"))
		column.add_child(line)
	if not found:
		column.add_child(UIFactory.label("Career history begins after the first recorded appearance.", "MutedLabel"))
	return card


func _game_log_card(row: Dictionary) -> PanelContainer:
	var entries := StatisticsService.player_game_log(_league, str(row.get("player_id", "")), _selected_year, _selected_phase)
	var card := _profile_card("GAME LOG", "%d recorded appearance%s" % [entries.size(), "" if entries.size() == 1 else "s"])
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column: VBoxContainer = card.get_child(0)
	if entries.is_empty():
		column.add_child(UIFactory.label("No weekly production recorded for this split.", "MutedLabel"))
		return card
	for entry in entries:
		var opponent := _league.team_by_id(str(entry.get("opponent_team_id", "")))
		var line := UIFactory.card("InsetPanel")
		var log_row := UIFactory.hbox(8)
		line.add_child(log_row)
		log_row.add_child(UIFactory.label("W%d" % int(entry.get("week", 0)), "EyebrowLabel"))
		log_row.add_child(UIFactory.badge(str(entry.get("result", "T")), _result_color(str(entry.get("result", "T")))))
		var opponent_name := opponent.abbreviation if opponent != null else "OPP"
		log_row.add_child(UIFactory.label("vs %s · %s" % [opponent_name, entry.get("score", "0-0")], "BodyLabel"))
		log_row.add_child(UIFactory.spacer())
		log_row.add_child(UIFactory.label(_compact_stat_line(str(row.get("position", "")), entry.get("stats")), "MutedLabel"))
		column.add_child(line)
	return card


func _game_list_card() -> PanelContainer:
	var card := _profile_card("COMPLETED SLATE", "%d games match the active filters" % _game_books.size())
	card.custom_minimum_size.x = 330
	var column: VBoxContainer = card.get_child(0)
	for index in range(mini(_game_books.size(), 30)):
		var book := _game_books[index]
		var away := _league.team_by_id(book.away_team_id)
		var home := _league.team_by_id(book.home_team_id)
		var button := UIFactory.button("W%d · %s  %d  @  %s  %d" % [book.week, away.abbreviation, book.away_score, home.abbreviation, book.home_score], "SecondaryButton" if book.matchup_id == _selected_book_id else "GhostButton")
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_game_book.bind(book.matchup_id))
		column.add_child(button)
	if _game_books.size() > 30:
		column.add_child(UIFactory.label("Showing the 30 most recent games. Select a club to narrow the slate.", "CaptionLabel"))
	return card


func _select_game_book(matchup_id: String) -> void:
	_selected_book_id = matchup_id
	_rebuild_content()


func _game_detail_card(book: GameBookData) -> PanelContainer:
	var card := UIFactory.card("RaisedCardPanel")
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(12)
	card.add_child(column)
	var away := _league.team_by_id(book.away_team_id)
	var home := _league.team_by_id(book.home_team_id)
	column.add_child(UIFactory.label("WEEK %d · %s" % [book.week, book.phase.to_upper()], "EyebrowLabel"))
	var scoreboard := UIFactory.hbox(14)
	scoreboard.add_child(_score_block(away, book.away_score))
	var final := UIFactory.vbox(1)
	final.custom_minimum_size.x = 90
	var final_label := UIFactory.label("FINAL", "EyebrowLabel")
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final.add_child(final_label)
	final.add_child(UIFactory.label("—", "MetricLabel"))
	scoreboard.add_child(final)
	scoreboard.add_child(_score_block(home, book.home_score))
	column.add_child(scoreboard)
	column.add_child(_team_comparison(book, away, home))
	column.add_child(UIFactory.label("PLAYER BOX SCORE", "SectionTitleLabel"))
	column.add_child(_book_player_table(book, away))
	column.add_child(_book_player_table(book, home))
	return card


func _score_block(team: TeamData, score: int) -> VBoxContainer:
	var block := UIFactory.vbox(2)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var badge_row := UIFactory.hbox(6)
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	block.add_child(badge_row)
	var score_label := UIFactory.label(str(score), "ScoreLabel")
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(score_label)
	var name := UIFactory.label(team.display_name(), "CaptionLabel")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block.add_child(name)
	return block


func _team_comparison(book: GameBookData, away: TeamData, home: TeamData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(5)
	panel.add_child(column)
	var header := UIFactory.hbox(8)
	header.add_child(_table_label(away.abbreviation, 80, "EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_table_label("TEAM COMPARISON", 180, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
	header.add_child(_table_label(home.abbreviation, 80, "EyebrowLabel", HORIZONTAL_ALIGNMENT_CENTER))
	column.add_child(header)
	for definition in [["TOTAL YARDS", "total_yards"], ["PASS", "pass_yards"], ["RUSH", "rush_yards"], ["FIRST DOWNS", "first_downs"], ["TURNOVERS", "turnovers"], ["SACKS ALLOWED", "sacks_allowed"]]:
		var line := UIFactory.hbox(8)
		line.add_child(_table_label(StatisticsService.format_metric(book.team_line(away.id), definition[1]), 80, "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER))
		line.add_child(_table_label(definition[0], 180, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
		line.add_child(_table_label(StatisticsService.format_metric(book.team_line(home.id), definition[1]), 80, "BodyLabel", HORIZONTAL_ALIGNMENT_CENTER))
		column.add_child(line)
	return panel


func _book_player_table(book: GameBookData, team: TeamData) -> PanelContainer:
	var panel := UIFactory.card("InsetPanel")
	var column := UIFactory.vbox(4)
	panel.add_child(column)
	var heading := UIFactory.hbox(6)
	heading.add_child(UIFactory.badge(team.abbreviation, team.primary_color))
	heading.add_child(UIFactory.label(team.display_name().to_upper(), "EyebrowLabel"))
	heading.add_child(UIFactory.spacer())
	heading.add_child(UIFactory.label("ALL PARTICIPANTS", "CaptionLabel"))
	column.add_child(heading)
	var players: Array[PlayerGameStatsData] = []
	for line: PlayerGameStatsData in book.player_stats.values():
		if line.team_id == team.id:
			players.append(line)
	players.sort_custom(func(a: PlayerGameStatsData, b: PlayerGameStatsData):
		var first_position := TeamData.ROSTER_POSITIONS.find(a.position)
		var second_position := TeamData.ROSTER_POSITIONS.find(b.position)
		if first_position != second_position:
			return first_position < second_position
		return a.full_name < b.full_name
	)
	for player in players:
		var row := UIFactory.hbox(6)
		var open := UIFactory.button(player.full_name, "GhostButton")
		open.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open.custom_minimum_size.x = 190
		open.pressed.connect(_open_player.bind(player.player_id))
		row.add_child(open)
		row.add_child(_table_label(player.position, 48, "CaptionLabel", HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(UIFactory.spacer())
		row.add_child(UIFactory.label(_compact_stat_line(player.position, player.stats), "MutedLabel"))
		column.add_child(row)
	return panel


func _profile_metrics(position: String, stats: StatLineData) -> Array[Dictionary]:
	var definitions: Array = []
	if position == "QB":
		definitions = [["GAMES", "games_played"], ["PASS YDS", "passing_yards"], ["PASS TD", "passing_touchdowns"], ["INT", "passing_interceptions"], ["RATING", "passer_rating"]]
	elif position in ["RB", "WR", "TE"]:
		definitions = [["GAMES", "games_played"], ["RUSH YDS", "rushing_yards"], ["REC", "receptions"], ["REC YDS", "receiving_yards"], ["TOTAL TD", "total_touchdowns"]]
	elif position in ["EDGE", "DT", "LB", "CB", "S"]:
		definitions = [["GAMES", "games_played"], ["TACKLES", "total_tackles"], ["TFL", "tackles_for_loss"], ["SACKS", "sacks"], ["INT", "defensive_interceptions"]]
	elif position == "K":
		definitions = [["GAMES", "games_played"], ["FGM", "field_goals_made"], ["FGA", "field_goal_attempts"], ["FG%", "field_goal_percentage"], ["XP", "extra_points_made"]]
	elif position == "P":
		definitions = [["GAMES", "games_played"], ["PUNTS", "punts"], ["AVG", "punt_average"], ["NET", "net_punt_average"], ["IN20", "punts_inside_20"]]
	else:
		definitions = [["GAMES", "games_played"], ["STARTS", "games_started"], ["OFF SNAPS", "offensive_snaps"], ["DEF SNAPS", "defensive_snaps"], ["ST SNAPS", "special_teams_snaps"]]
	var metrics: Array[Dictionary] = []
	for definition in definitions:
		var stat_name := str(definition[1])
		var value: String = str(_total_touchdowns(stats)) if stat_name == "total_touchdowns" else StatisticsService.format_metric(stats, stat_name)
		metrics.append({"label": str(definition[0]), "value": value})
	return metrics


func _metric_flow(metrics: Array[Dictionary]) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 20)
	flow.add_theme_constant_override("v_separation", 10)
	for data in metrics:
		var metric := UIFactory.vbox(0)
		metric.custom_minimum_size.x = 82
		metric.add_child(UIFactory.label(str(data.get("value", "0")), "MetricLabel"))
		metric.add_child(UIFactory.label(str(data.get("label", "STAT")), "CaptionLabel"))
		flow.add_child(metric)
	return flow


func _compact_stat_line(position: String, stats: StatLineData) -> String:
	if stats == null:
		return "No recorded statistics"
	if position == "QB":
		return "%d/%d, %d YDS, %d TD, %d INT" % [stats.value("passing_completions"), stats.value("passing_attempts"), stats.value("passing_yards"), stats.value("passing_touchdowns"), stats.value("passing_interceptions")]
	if position in ["RB", "WR", "TE"]:
		return "%d RUSH, %d REC, %d YDS, %d TD" % [stats.value("rushing_yards"), stats.value("receptions"), stats.value("receiving_yards"), _total_touchdowns(stats)]
	if position in ["EDGE", "DT", "LB", "CB", "S"]:
		return "%d TKL, %d TFL, %d SACK, %d INT" % [roundi(StatisticsService.metric_value(stats, "total_tackles")), stats.value("tackles_for_loss"), stats.value("sacks"), stats.value("defensive_interceptions")]
	if position == "K":
		return "%d/%d FG, LONG %d, %d XP" % [stats.value("field_goals_made"), stats.value("field_goal_attempts"), stats.value("longest_field_goal"), stats.value("extra_points_made")]
	if position == "P":
		return "%d PUNTS, %.1f AVG, %d IN20" % [stats.value("punts"), StatisticsService.metric_value(stats, "punt_average"), stats.value("punts_inside_20")]
	return "%d STARTS · %d SNAPS" % [stats.value("games_started"), stats.value("offensive_snaps") + stats.value("defensive_snaps") + stats.value("special_teams_snaps")]


func _profile_card(title: String, subtitle: String) -> PanelContainer:
	var card := UIFactory.card()
	card.custom_minimum_size = Vector2(360, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := UIFactory.vbox(8)
	card.add_child(column)
	column.add_child(UIFactory.label(title, "SectionTitleLabel"))
	column.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	return card


func _section_heading(title: String, subtitle: String) -> HBoxContainer:
	var heading := UIFactory.hbox(10)
	var copy := UIFactory.vbox(1)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(UIFactory.label(title, "SectionTitleLabel"))
	copy.add_child(UIFactory.label(subtitle, "CaptionLabel"))
	heading.add_child(copy)
	return heading


func _header_metric(title: String, value: String) -> VBoxContainer:
	var metric := UIFactory.vbox(0)
	metric.custom_minimum_size.x = 104
	metric.add_child(UIFactory.label(value, "MetricLabel"))
	metric.add_child(UIFactory.label(title, "CaptionLabel"))
	return metric


func _table_label(text_value: String, width: float, variation: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := UIFactory.label(text_value, variation)
	label.custom_minimum_size.x = width
	label.horizontal_alignment = alignment
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label


func _empty_state(message: String) -> PanelContainer:
	var card := UIFactory.card("InsetPanel")
	var copy := UIFactory.wrapped_label(message, "MutedLabel")
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(copy)
	return card


func _find_player_row(rows: Array[Dictionary], player_id: String) -> Dictionary:
	for row in rows:
		if str(row.get("player_id", "")) == player_id:
			return row
	return {}


func _player_color(row: Dictionary) -> Color:
	var team_ids: Array = row.get("team_ids", [])
	if team_ids.is_empty():
		return GridironTheme.BORDER
	var team := _league.team_by_id(str(team_ids.back()))
	return team.primary_color if team != null else GridironTheme.BORDER


func _result_color(result: String) -> Color:
	if result == "W":
		return GridironTheme.ACCENT
	if result == "L":
		return GridironTheme.DANGER
	return GridironTheme.WARM


func _metric_label(stat_name: String) -> String:
	return stat_name.replace("_", " ").to_upper()


func _total_touchdowns(stats: StatLineData) -> int:
	return stats.value("rushing_touchdowns") + stats.value("receiving_touchdowns")


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _apply_responsive_layout() -> void:
	if _content_grid != null:
		_content_grid.columns = 2 if size.x >= 1080 else 1
