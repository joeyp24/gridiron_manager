extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_plan_budget_and_round_trip()
	_test_ai_plans_are_complete_and_deterministic()
	_test_reports_use_actual_game_books()
	_test_plan_changes_calls_and_snap_modifiers()
	_test_league_persistence_and_migration()
	await _test_responsive_game_plan_screen()
	if _failures.is_empty():
		print("PASS: %d assertions across scouting reports, weekly plans, AI planning, simulation effects, persistence, and responsive UI." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _test_plan_budget_and_round_trip() -> void:
	var plan := WeeklyGamePlanData.new(2026, 4, "week4", "club_a", "club_b")
	plan.offensive_focus = WeeklyGamePlanData.OFFENSE_VERTICAL
	plan.defensive_focus = WeeklyGamePlanData.DEFENSE_PRESSURE
	plan.offensive_points = 4
	plan.defensive_points = 2
	_check(plan.is_valid() and plan.points_used() == 6, "A four-two plan should use the complete legal preparation budget")
	plan.defensive_points = 4
	_check(not plan.is_valid() and "more than six" in plan.validation_error(), "A four-four plan should be rejected")
	plan.defensive_points = 2
	var restored := WeeklyGamePlanData.from_dict(JSON.parse_string(JSON.stringify(plan.to_dict())))
	_check(restored.summary() == plan.summary() and restored.matchup_id == plan.matchup_id, "Weekly plan identity and choices should survive serialization")


func _test_ai_plans_are_complete_and_deterministic() -> void:
	var first := _sample_league(41027)
	var second := _sample_league(41027)
	GamePlanningService.ensure_weekly_plans(first)
	GamePlanningService.ensure_weekly_plans(second)
	_check(first.weekly_game_plans.size() == first.matchups_for_week(1).size() * 2, "Every team playing in the week should receive a game plan")
	_check(first.weekly_game_plans.size() == second.weekly_game_plans.size(), "Equivalent leagues should create the same number of plans")
	for key in first.weekly_game_plans:
		var first_plan: WeeklyGamePlanData = first.weekly_game_plans[key]
		var second_plan: WeeklyGamePlanData = second.weekly_game_plans[key]
		_check(first_plan.is_valid(), "AI and default user plans should always respect the weekly budget")
		_check(second_plan != null and second_plan.summary() == first_plan.summary(), "AI game planning should be deterministic for identical league state")


func _test_reports_use_actual_game_books() -> void:
	var league := _sample_league(51088)
	GamePlanningService.ensure_weekly_plans(league)
	var week_one := league.matchups_for_week(1)
	var observed_team_id: String = week_one.front().away_team_id
	LeagueSimulator.simulate_remaining_week(league)
	league.advance_after_completed_week()
	var report := GamePlanningService.build_report(league, observed_team_id, league.user_team_id)
	_check(report.games_analyzed == 1 and report.offensive_snaps > 0 and report.defensive_snaps > 0, "A week-two report should analyze the opponent's completed week-one film")
	_check(report.favorite_offensive_call != "Insufficient film" and report.favorite_defensive_call != "Insufficient film", "Call ledgers should produce named offensive and defensive tendencies")
	_check(report.confidence > 25 and report.points_per_game >= 0.0 and report.yards_per_game > 0.0, "Observed film should increase confidence and expose performance rates")
	_check(report.key_players.size() == 3 and not report.matchup_notes.is_empty(), "A report should identify key opponents and ratings-based matchup edges")
	var season := league.statistics.season(league.season_year)
	var book: GameBookData = season.game_books.values().front()
	var ledger_call: Dictionary = book.play_calls.front()
	_check(ledger_call.has("offensive_call_personnel") and ledger_call.has("defensive_call_tags"), "Game books should retain the personnel and pressure metadata needed by scouting")


func _test_plan_changes_calls_and_snap_modifiers() -> void:
	var teams := SampleLeague.create_teams()
	var offense_plan := WeeklyGamePlanData.new(2026, 1, "test", teams[0].id, teams[1].id)
	offense_plan.offensive_focus = WeeklyGamePlanData.OFFENSE_GROUND
	offense_plan.offensive_points = 4
	offense_plan.defensive_points = 2
	var defense_plan := WeeklyGamePlanData.new(2026, 1, "test", teams[1].id, teams[0].id)
	defense_plan.defensive_focus = WeeklyGamePlanData.DEFENSE_RUN
	defense_plan.offensive_points = 2
	defense_plan.defensive_points = 4
	var plans := {teams[0].id: offense_plan, teams[1].id: defense_plan}
	var simulator := FootballSimulator.new(teams[1], teams[0], 60117, false, null, null, plans)
	simulator.state.possession_team_id = teams[0].id
	var inside_zone := simulator.play_by_id("inside_zone")
	var base := simulator.defensive_call_by_id("base_cover_3")
	var prepared := PlayCallerService.matchup_modifiers(inside_zone, base, [], simulator.state)
	var unprepared := PlayCallerService.matchup_modifiers(inside_zone, base, [])
	_check(float(prepared["yardage"]) < float(unprepared["yardage"]), "A four-point run defense should outweigh a four-point ground emphasis on the same snap")
	var result := simulator.simulate_next_play(PlayCallData.new("inside_zone"), DefensiveCallData.from_dict(base.to_dict()))
	var plan_context: Dictionary = result.matchup_context.get("game_plan", {})
	_check(plan_context.get("offensive_focus", "") == WeeklyGamePlanData.OFFENSE_GROUND, "Completed snaps should expose the applied offensive preparation")
	_check(plan_context.get("defensive_focus", "") == WeeklyGamePlanData.DEFENSE_RUN, "Completed snaps should expose the applied defensive preparation")
	var run_adjustment := GamePlanningService.offensive_recommendation_adjustment(inside_zone, offense_plan)
	var pass_adjustment := GamePlanningService.offensive_recommendation_adjustment(simulator.play_by_id("four_verticals"), offense_plan)
	_check(run_adjustment > pass_adjustment, "Ground preparation should move run concepts above unrelated passes on the call sheet")


func _test_league_persistence_and_migration() -> void:
	var league := _sample_league(71093)
	var plan := GamePlanningService.current_user_plan(league)
	var saved := GamePlanningService.save_user_plan(
		league,
		WeeklyGamePlanData.OFFENSE_QUICK,
		WeeklyGamePlanData.DEFENSE_PRESSURE,
		2,
		4
	)
	_check(bool(saved.get("ok", false)), "A legal user plan should save")
	var restored := LeagueState.from_dict(JSON.parse_string(JSON.stringify(league.to_dict())))
	var restored_plan := GamePlanningService.current_user_plan(restored)
	_check(restored_plan.offensive_focus == WeeklyGamePlanData.OFFENSE_QUICK and restored_plan.defensive_points == 4, "League serialization should preserve the weekly plan")
	var invalid := GamePlanningService.save_user_plan(league, WeeklyGamePlanData.OFFENSE_VERTICAL, WeeklyGamePlanData.DEFENSE_RUN, 4, 4)
	_check(not bool(invalid.get("ok", true)) and plan.offensive_focus == WeeklyGamePlanData.OFFENSE_QUICK, "An invalid allocation should not corrupt the saved plan")
	var repository := SaveRepository.new("user://game_plan_migration_test.json")
	var payload := {"save_version": 12, "career": {"league": league.to_dict()}}
	payload["career"]["league"].erase("weekly_game_plans")
	var migrated := repository._migrate(payload, 12)
	_check(int(migrated.get("save_version", 0)) == SaveRepository.SAVE_VERSION and migrated["career"]["league"].has("weekly_game_plans"), "Version-twelve saves should migrate through the current schema with an empty weekly-plan collection")


func _test_responsive_game_plan_screen() -> void:
	var league := _sample_league(81822)
	var career := CareerSession.new(league)
	var packed: PackedScene = load("res://scenes/screens/game_plan_screen.tscn")
	var screen := packed.instantiate()
	screen.setup(career)
	root.add_child(screen)
	await process_frame
	_check(screen._metric_grid.get_child_count() == 4, "The briefing should show four opponent tendency metrics")
	_check(screen._content_grid.get_child_count() == 2 and screen._intel_grid.get_child_count() == 3, "The screen should include scouting, planning, threats, matchups, and availability")
	_check(screen._offense_menu.item_count == WeeklyGamePlanData.OFFENSIVE_FOCUSES.size(), "Every offensive priority should be selectable")
	_check(screen._defense_menu.item_count == WeeklyGamePlanData.DEFENSIVE_FOCUSES.size(), "Every defensive priority should be selectable")
	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	_check(screen._metric_grid.columns == 1 and screen._content_grid.columns == 1 and screen._intel_grid.columns == 1, "The full game-plan screen should stack cleanly on a narrow display")
	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	_check(screen._metric_grid.columns == 4 and screen._content_grid.columns == 2 and screen._intel_grid.columns == 3, "The game-plan screen should use the full desktop layout")
	var saves := [0]
	screen.game_plan_saved.connect(func(): saves[0] += 1)
	screen._offense_points_menu.select(3)
	screen._defense_points_menu.select(1)
	screen._save_plan()
	_check(saves[0] == 1 and career.current_game_plan().offensive_points == 4, "Saving from the UI should update the career and emit a persistence request")
	screen.queue_free()


func _sample_league(seed: int) -> LeagueState:
	var teams := SampleLeague.create_teams()
	var league := LeagueState.new(teams, teams[0].id, seed)
	league.league_format = LeagueFormatData.legacy_eight()
	league.schedule = ScheduleGenerator.round_robin(teams, league.season_year, seed)
	return league


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
