extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/screens/career_select.tscn")
	var screen := packed.instantiate()
	screen.setup()
	root.add_child(screen)
	await process_frame

	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	screen._select_source(0)
	await process_frame
	_check(screen._team_grid.columns == 1, "Career clubs should reflow to one column on a narrow display")
	_check(screen._team_buttons.size() == 32, "The real-data source should render all 32 selectable club cards")
	_check(screen._selected_source_id == LeagueCatalog.SOURCE_NFLVERSE_FULL, "The complete league database should be active")
	_check(screen._details_host.get_child_count() > 0, "The selected real-data club should render its profile")
	_check(screen._mode_selector.item_count == 2, "Career creation should offer standard and fantasy-draft formats")
	screen._select_career_mode(1)
	_check(screen._selected_career_mode == LeagueState.CAREER_MODE_FANTASY_DRAFT, "Career creation should retain the fantasy-draft selection")
	_check("53-player" in screen._mode_description.text, "The fantasy-draft option should explain the complete roster format")

	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	await process_frame
	_check(screen._team_grid.columns == 4, "Career clubs should use four columns on a wide display")
	screen._select_source(0)
	await process_frame
	_check(screen._selected_source_id == LeagueCatalog.SOURCE_NFLVERSE_FULL, "The full league should remain the only new-career database")
	_check(screen._team_buttons.size() == 32, "Refreshing the database should replace rather than duplicate club cards")

	screen.queue_free()

	var fantasy_career := CareerSession.new_career("nfl_buf", 891177, LeagueCatalog.SOURCE_NFLVERSE_FULL, LeagueState.CAREER_MODE_FANTASY_DRAFT)
	var fantasy_scene: PackedScene = load("res://scenes/screens/fantasy_draft_screen.tscn")
	var fantasy_screen := fantasy_scene.instantiate()
	fantasy_screen.setup(fantasy_career)
	root.add_child(fantasy_screen)
	await process_frame
	_check(fantasy_screen._metric_grid.get_child_count() == 4, "The Fantasy Draft should show order, clock, next pick, and pool metrics")
	_check(fantasy_screen._body_grid.get_child_count() == 2, "The ready room should show the complete order and format safeguards")
	fantasy_screen.size = Vector2(540, 900)
	fantasy_screen._apply_responsive_layout()
	_check(fantasy_screen._metric_grid.columns == 1 and fantasy_screen._body_grid.columns == 1, "The Fantasy Draft should stack metrics and content on a narrow display")
	var fantasy_changes := [0]
	fantasy_screen.draft_changed.connect(func(): fantasy_changes[0] += 1)
	fantasy_screen._begin_draft()
	await process_frame
	_check(fantasy_career.league.fantasy_draft.status == FantasyDraftStateData.STATUS_IN_PROGRESS, "Entering the live draft should start the league simulation")
	_check(fantasy_career.league.fantasy_draft.current_pick().team_id == fantasy_career.league.user_team_id, "The live room should stop with the managed club on the clock")
	_check(not fantasy_screen._selected_player_id.is_empty(), "The live player board should select its top available player")
	_check(fantasy_screen._body_grid.get_child_count() == 2, "The live room should show the player board and draft controls")
	_check(fantasy_changes[0] == 1, "Starting the draft should request an immediate career save")
	fantasy_screen.size = Vector2(1440, 900)
	fantasy_screen._apply_responsive_layout()
	_check(fantasy_screen._metric_grid.columns == 4 and fantasy_screen._body_grid.columns == 2, "The Fantasy Draft should use its full war-room layout on a wide display")
	fantasy_screen._auto_pick()
	await process_frame
	_check(fantasy_career.user_team().players.size() == 1, "Fantasy auto-pick should add one player to the managed roster")
	_check(fantasy_changes[0] == 2, "A fantasy selection should request an immediate career save")
	fantasy_screen.queue_free()

	var career := CareerSession.new_career("nfl_buf", 882601, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var trade_scene: PackedScene = load("res://scenes/screens/trade_center_screen.tscn")
	var trade_screen := trade_scene.instantiate()
	trade_screen.setup(career)
	root.add_child(trade_screen)
	await process_frame
	trade_screen.size = Vector2(540, 900)
	trade_screen._apply_responsive_layout()
	_check(trade_screen._asset_grid.columns == 1, "Trade assets should stack into one column on a narrow display")
	_check(trade_screen._partners.size() == 31, "The Trade Center should expose every other club as a negotiation partner")
	_check(trade_screen._user_asset_buttons.size() >= 70 and trade_screen._partner_asset_buttons.size() >= 70, "The Trade Center should render full rosters and three years of draft capital")
	var user_pick: DraftPickData = TradeService.picks_owned_by(career.league, career.user_team().id).front()
	trade_screen._toggle_pick(true, true, user_pick.id)
	_check(trade_screen._user_pick_ids.has(user_pick.id) and trade_screen._offer_host.get_child_count() > 0, "Selecting a trade asset should refresh the live deal evaluation")
	trade_screen.size = Vector2(1440, 900)
	trade_screen._apply_responsive_layout()
	_check(trade_screen._asset_grid.columns == 3, "Trade assets and the deal room should use three columns on a wide display")
	trade_screen._select_partner(1)
	await process_frame
	_check(trade_screen._user_pick_ids.is_empty() and trade_screen._partner.id == trade_screen._partners[1].id, "Changing trade partners should clear stale offer assets")
	trade_screen.queue_free()

	var stats_career := career
	stats_career.simulate_current_week()
	var quarterback: PlayerData = stats_career.user_team().player_at("QB")
	var statistics_scene: PackedScene = load("res://scenes/screens/statistics_center_screen.tscn")
	var statistics_screen := statistics_scene.instantiate()
	statistics_screen.setup(stats_career, quarterback.id)
	root.add_child(statistics_screen)
	await process_frame
	_check(statistics_screen._selected_view == "PLAYER PROFILE", "Roster navigation should open the requested player's statistical profile")
	_check(statistics_screen._player_finder_card.size.y <= 120, "The player finder should remain a compact profile control")
	_check(statistics_screen._player_picker_menu.size.y <= 48, "The player picker should not stretch vertically")
	statistics_screen.size = Vector2(540, 900)
	statistics_screen._apply_responsive_layout()
	_check(statistics_screen._content_grid.columns == 1, "Player profile cards should stack on a narrow display")
	var statistics_profile_routes: Array[String] = []
	statistics_screen.player_profile_requested.connect(func(player_id: String): statistics_profile_routes.append(player_id))
	statistics_screen._full_profile_button.pressed.emit()
	_check(statistics_profile_routes == [quarterback.id], "A Statistics Center dossier should route to the selected full player profile")

	statistics_screen._select_view("LEAGUE LEADERS")
	await process_frame
	_check(statistics_screen._category_buttons.size() == StatisticsService.PLAYER_CATEGORIES.size(), "League leaders should expose every statistical category")
	_check(not statistics_screen._leader_rows.is_empty(), "League leaders should render recorded and zero-stat players")
	_check(statistics_screen._player_table_body.get_child_count() == mini(statistics_screen._leader_rows.size(), 100) + 1, "The league-leader table should build its header and visible player rows")
	_check(statistics_screen._player_table_scroll.size.y >= statistics_screen._player_table_body.get_combined_minimum_size().y, "The league-leader viewport should expose every built row to the page scrollbar")
	statistics_screen._sort_players("passing_yards")
	await process_frame
	var low_line: StatLineData = statistics_screen._leader_rows.front().get("stats")
	var high_line: StatLineData = statistics_screen._leader_rows.back().get("stats")
	_check(StatisticsService.metric_value(low_line, "passing_yards") <= StatisticsService.metric_value(high_line, "passing_yards"), "Clicking an active leader column should reverse its sort direction")

	statistics_screen._select_view("TEAM RANKINGS")
	await process_frame
	_check(statistics_screen._team_rows.size() == stats_career.league.teams.size(), "Team rankings should render every club")
	_check(statistics_screen._team_table_body.get_child_count() == statistics_screen._team_rows.size() + 1, "The team-ranking table should build one row for every club")
	_check(statistics_screen._team_table_scroll.size.y >= statistics_screen._team_table_body.get_combined_minimum_size().y, "The team-ranking viewport should expose every club row to the page scrollbar")
	statistics_screen._sort_teams("points")
	await process_frame
	var top_team_line: StatLineData = statistics_screen._team_rows.front().get("stats")
	var bottom_team_line: StatLineData = statistics_screen._team_rows.back().get("stats")
	_check(StatisticsService.metric_value(top_team_line, "points") >= StatisticsService.metric_value(bottom_team_line, "points"), "A newly selected team column should sort from highest to lowest")

	statistics_screen._select_view("GAME BOOKS")
	await process_frame
	_check(statistics_screen._game_books.size() == 16, "Game Books should list every completed NFL week-one game")
	_check(statistics_screen._content_grid.columns == 1, "Game Book list and detail should stack on a narrow display")
	statistics_screen.size = Vector2(1440, 900)
	statistics_screen._apply_responsive_layout()
	_check(statistics_screen._content_grid.columns == 2, "Game Book list and detail should share a row on a wide display")
	var participant_id := str(statistics_screen._game_books.front().player_stats.keys().front())
	statistics_screen._open_player(participant_id)
	await process_frame
	_check(statistics_screen._selected_view == "PLAYER PROFILE" and statistics_screen._selected_player_id == participant_id, "Box-score participants should link to their full player profile")
	statistics_screen.queue_free()

	var players_scene: PackedScene = load("res://scenes/screens/players_screen.tscn")
	var players_screen := players_scene.instantiate()
	players_screen.setup(stats_career, quarterback.id)
	root.add_child(players_screen)
	await process_frame
	_check(players_screen._selected_player_id == quarterback.id, "The Player Database should open a directly requested player")
	_check(players_screen._player_menu.item_count == 2035, "The compact player dropdown should expose the complete searchable league directory")
	_check(str(players_screen._player_menu.get_item_metadata(players_screen._player_menu.selected)) == quarterback.id, "The player dropdown should select a directly requested profile")
	_check(players_screen._result_label.text.begins_with("2035 RESULTS"), "The Player Database should report the complete hybrid player pool")
	_check(players_screen._content_grid.get_child_count() == 1, "The Player Database should reserve its content area for the full-width player profile")
	_check(players_screen._attribute_grid.get_child_count() == PlayerRatingsData.CATEGORY_FIELDS.size(), "The full player profile should render every Madden attribute category")
	_check(players_screen._profile_host.get_child_count() >= 6, "The full player profile should include identity, contract, ratings, and attribute sections")
	players_screen.size = Vector2(540, 900)
	players_screen._apply_responsive_layout()
	_check(players_screen._content_grid.columns == 1 and players_screen._attribute_grid.columns == 1, "The full-width player profile and attributes should stack on a narrow display")
	players_screen.size = Vector2(1440, 900)
	players_screen._apply_responsive_layout()
	_check(players_screen._content_grid.columns == 1 and players_screen._attribute_grid.columns == 2, "A wide display should keep the profile full width and show two attribute groups per row")
	var alternate_player_id := str(players_screen._player_menu.get_item_metadata(1))
	players_screen._player_menu.select(1)
	players_screen._player_menu.item_selected.emit(1)
	_check(players_screen._selected_player_id == alternate_player_id, "Selecting a player from the compact dropdown should rebuild that player's profile")
	players_screen._search_changed(quarterback.full_name)
	_check(players_screen._player_menu.item_count >= 1 and players_screen._selected_player_id == quarterback.id, "Searching the compact directory should narrow the dropdown and select the matching player")
	players_screen._search_changed("")
	var player_statistics_routes: Array[String] = []
	players_screen.statistics_requested.connect(func(player_id: String): player_statistics_routes.append(player_id))
	players_screen._statistics_button.pressed.emit()
	_check(player_statistics_routes == [quarterback.id], "A full player profile should route back to that player's statistics")
	players_screen.queue_free()

	var free_agency_scene: PackedScene = load("res://scenes/screens/free_agency_screen.tscn")
	var free_agency_screen := free_agency_scene.instantiate()
	free_agency_screen.setup(stats_career)
	root.add_child(free_agency_screen)
	await process_frame
	var selected_free_agent_id: String = free_agency_screen._selected_player_id
	var free_agent_profile_routes: Array[String] = []
	free_agency_screen.player_profile_requested.connect(func(player_id: String): free_agent_profile_routes.append(player_id))
	free_agency_screen._full_profile_button.pressed.emit()
	_check(not selected_free_agent_id.is_empty() and free_agent_profile_routes == [selected_free_agent_id], "Free agency should route its selected player to the full attribute profile")
	free_agency_screen.queue_free()

	var match_teams := SampleLeague.create_teams()
	var play_simulator := FootballSimulator.new(match_teams[0], match_teams[1], 99021)
	var coached_team: TeamData = match_teams[0]
	play_simulator.state.possession_team_id = coached_team.id
	play_simulator.state.opening_possession_team_id = coached_team.id
	var match_scene: PackedScene = load("res://scenes/screens/match_center.tscn")
	var match_screen := match_scene.instantiate()
	match_screen.setup(play_simulator, coached_team, false)
	root.add_child(match_screen)
	await process_frame
	_check(match_screen._call_sheet_card.visible and match_screen._recommendation_buttons.size() == 3, "Coach mode should show three recommended calls when the user has possession")
	_check(match_screen._displayed_play_ids.size() == 3, "The recommended call sheet should render three selectable concepts")
	_check(match_screen._next_button.visible and match_screen._drive_button.visible and match_screen._finish_button.visible, "Coach mode should preserve every existing simulation-forward control")
	match_screen.size = Vector2(540, 900)
	match_screen._apply_responsive_layout()
	_check(match_screen._body_grid.columns == 1 and match_screen._play_grid.columns == 1, "The field, feed, and call sheet should stack on a narrow display")
	match_screen.size = Vector2(1440, 900)
	match_screen._apply_responsive_layout()
	_check(match_screen._body_grid.columns == 2 and match_screen._play_grid.columns == 3, "The Match Center and call sheet should use their wide layouts when space permits")
	var prior_play_count := play_simulator.state.play_count
	match_screen._call_play("kneel")
	await process_frame
	_check(play_simulator.state.play_count == prior_play_count + 1 and play_simulator.state.play_history.back().call_id == "kneel", "Selecting a call-sheet play should resolve exactly that concept")
	match_screen._select_play_category("PASS")
	await process_frame
	_check(match_screen._displayed_play_ids.size() == 14, "The full pass section should expose every passing concept")
	var drive_number := play_simulator.state.drive_number
	var drive_play_count := play_simulator.state.play_count
	match_screen._simulate_drive()
	await process_frame
	_check(play_simulator.state.play_count > drive_play_count and (play_simulator.state.drive_number > drive_number or play_simulator.state.is_final), "The existing Simulate Drive control should still advance an automatically called series")
	match_screen._finish_game()
	await process_frame
	_check(play_simulator.state.is_final, "The existing Finish Game control should still complete an automatically called game")
	match_screen.queue_free()
	if _failures.is_empty():
		print("PASS: %d assertions across responsive career creation, Fantasy Draft, Trade Center, Statistics Center, Player Database, free agency, and playcalling checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
