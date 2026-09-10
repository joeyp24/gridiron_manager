extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_incremental_week_simulation()
	_test_postgame_simulation()
	await _test_loading_overlay()
	await _test_shell_simulation_integration()

	if _failures.is_empty():
		print("PASS: %d assertions across staged simulation and loading-overlay checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _test_incremental_week_simulation() -> void:
	var career := CareerSession.new_career("boston_sentinels", 920311, LeagueCatalog.SOURCE_FICTIONAL)
	var comparison := CareerSession.new_career("boston_sentinels", 920311, LeagueCatalog.SOURCE_FICTIONAL)
	var task := career.start_week_simulation()
	_check(task != null, "A legal career week should create a staged simulation task")
	if task == null:
		return
	_check(task.stage == WeekSimulationTask.STAGE_PREPARE, "A staged week should begin with preparation")
	_check(task.total_game_count() == 4, "The focused eight-team fixture should queue all four weekly games")
	var previous_progress := task.progress_ratio()
	var stages: Array[String] = []
	while not task.is_complete():
		var prior_stage := task.stage
		var played_before := _played_games(career, 1)
		stages.append(prior_stage)
		_check(career.advance_week_simulation(task), "Each active simulation stage should advance successfully")
		_check(task.progress_ratio() >= previous_progress, "Simulation progress should never move backward")
		if prior_stage == WeekSimulationTask.STAGE_GAMES:
			_check(_played_games(career, 1) == played_before + 1, "A game stage should resolve exactly one matchup per frame")
		previous_progress = task.progress_ratio()
	_check(task.progress_ratio() == 1.0, "A completed simulation task should report 100 percent")
	_check(career.active_week_simulation == null, "The transient task should clear after finalization")
	_check(career.league.current_week == 2 and _played_games(career, 1) == 4, "Staged simulation should complete and advance the full week")
	_check(WeekSimulationTask.STAGE_LEAGUE_OPERATIONS in stages and WeekSimulationTask.STAGE_FINALIZE in stages, "The workflow should expose league-operation and finalization stages")

	comparison.simulate_current_week()
	_check(_week_signature(career, 1) == _week_signature(comparison, 1), "The staged workflow should preserve deterministic weekly results")


func _test_postgame_simulation() -> void:
	var career := CareerSession.new_career("seattle_orcas", 771905, LeagueCatalog.SOURCE_FICTIONAL)
	var simulator := career.begin_user_game()
	_check(simulator != null, "A legal managed matchup should enter Matchday")
	if simulator == null:
		return
	simulator.simulate_to_end()
	var managed_matchup := career.active_matchup
	var task := career.start_postgame_simulation()
	_check(task != null and task.mode == WeekSimulationTask.MODE_POSTGAME, "A finished managed game should create a postgame task")
	if task == null:
		return
	_check(task.total_game_count() == 3, "Postgame processing should exclude the already-played managed matchup")
	career.advance_week_simulation(task)
	_check(managed_matchup.played, "The postgame preparation stage should record the managed result")
	while not task.is_complete():
		career.advance_week_simulation(task)
	_check(_played_games(career, 1) == 4, "Postgame processing should complete the rest of the league schedule")
	_check(career.active_simulator == null and career.active_matchup == null, "Finalization should clear the completed Matchday state")
	_check(career.league.current_week == 2, "Postgame processing should advance the career calendar")


func _test_loading_overlay() -> void:
	var host := Control.new()
	host.size = Vector2(540, 720)
	root.add_child(host)
	var overlay := SimulationLoadingOverlay.new()
	host.add_child(overlay)
	await process_frame

	var team := SampleLeague.create_teams()[0]
	overlay.begin_operation("SIMULATING WEEK 1", "Resolving every league matchup.", team)
	overlay.update_progress(0.42, "SIMULATING BOS @ SEA", "League game 2 of 4")
	_check(overlay.visible and overlay.mouse_filter == Control.MOUSE_FILTER_STOP, "The loading layer should be visible and modal during simulation")
	_check(is_equal_approx(overlay.progress_value(), 42.0), "The loading layer should display the supplied progress")
	_check(overlay.status_text() == "SIMULATING BOS @ SEA", "The loading layer should display the active simulation stage")
	_check(overlay.is_processing(), "The activity indicator should animate while work is running")

	host.size = Vector2(320, 640)
	await process_frame
	_check(overlay.panel_minimum_width() == 280.0, "The loading card should fit a narrow window")
	_check(overlay.panel_width() <= host.size.x, "The complete loading card should remain inside a narrow window")
	host.size = Vector2(1440, 900)
	await process_frame
	_check(overlay.panel_minimum_width() == 680.0, "The loading card should use a restrained width on wide displays")
	overlay.finish_operation()
	_check(not overlay.visible and not overlay.is_processing(), "Completing an operation should hide and stop the loading layer")
	host.queue_free()


func _test_shell_simulation_integration() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	main._career = CareerSession.new_career("miami_nightjars", 662901, LeagueCatalog.SOURCE_FICTIONAL)
	var save_path := "res://test-results/simulation_loading_save.json"
	main._save_repository = SaveRepository.new(save_path)
	var task: WeekSimulationTask = main._career.start_week_simulation()
	await main._run_week_simulation(task, "SIMULATING WEEK 1", "Integration check")
	_check(main._career.league.current_week == 2, "The shell coordinator should drive the staged task through completion")
	_check(not main._simulation_overlay.visible, "The shell coordinator should dismiss the overlay after saving")
	_check(main._save_repository.has_save(), "The shell coordinator should save only after the week is finalized")
	var saved: CareerSession = main._save_repository.load_career()
	_check(saved != null and saved.league.current_week == 2, "The completed save should contain the advanced league state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	main.queue_free()


func _played_games(career: CareerSession, week: int) -> int:
	return career.league.matchups_for_week(week).filter(func(matchup: MatchupData): return matchup.played).size()


func _week_signature(career: CareerSession, week: int) -> String:
	var values: Array[String] = []
	for matchup in career.league.matchups_for_week(week):
		values.append("%s:%d-%d" % [matchup.id, matchup.away_score, matchup.home_score])
	return "|".join(values)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
