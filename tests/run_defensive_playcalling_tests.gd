extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_defensive_playbook_catalog()
	_test_situational_recommendations()
	_test_selected_defense_reaches_the_simulator()
	_test_defensive_calls_change_outcomes()
	_test_game_books_preserve_calls()
	await _test_match_center_defensive_call_sheet()

	if _failures.is_empty():
		print("PASS: %d assertions across defensive playbooks, recommendations, outcomes, game books, and Match Center integration." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _test_defensive_playbook_catalog() -> void:
	var playbook := PlaybookCatalog.multiple_defense()
	_check(playbook.calls.size() == 18, "The multiple defense should load all 18 calls")
	var ids: Dictionary = {}
	for call in playbook.calls:
		ids[call.id] = true
		_check(call.personnel in PersonnelPackageService.DEFENSIVE_PACKAGES, "%s should use a supported personnel package" % call.display_name)
		_check(not call.front.is_empty() and not call.shell.is_empty(), "%s should define a front and coverage shell" % call.display_name)
		_check(call.rusher_count >= 2 and call.rusher_count <= 7, "%s should use a legal pressure count" % call.display_name)
	_check(ids.size() == playbook.calls.size(), "Every defensive call should have a unique stable ID")
	_check(playbook.calls_in_category("Base").size() == 5, "The defensive book should contain five Base calls")
	_check(playbook.calls_in_category("Nickel").size() == 8, "The defensive book should contain eight Nickel calls")
	_check(playbook.calls_in_category("Dime").size() == 3, "The defensive book should contain three Dime calls")
	_check(playbook.calls_in_category("Goal Line").size() == 1, "The defensive book should contain a Goal Line call")
	_check(playbook.calls_in_category("Prevent").size() == 1, "The defensive book should contain a Prevent call")
	var round_trip := DefensivePlaybookData.from_dict(JSON.parse_string(JSON.stringify(playbook.to_dict())))
	var fire_zone := round_trip.call_by_id("fire_zone_3")
	_check(fire_zone != null and fire_zone.has_tag("zone_blitz") and fire_zone.rusher_count == 5, "Defensive playbook data should survive a JSON round trip")

	var teams := SampleLeague.create_teams()
	var prevent_lineup := PersonnelPackageService.defensive_lineup(teams[0], "Prevent")
	_check(prevent_lineup.size() == 11, "Prevent personnel should field eleven actual defenders")


func _test_situational_recommendations() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 740211)
	simulator.state.possession_team_id = teams[1].id
	simulator.state.down = 3
	simulator.state.yards_to_first = 11
	var long_yardage := simulator.recommended_defensive_calls(4)
	_check(long_yardage.any(func(call: DefensiveCallData): return call.has_tag("pass_commit")), "Long yardage should recommend a pass-focused coverage")

	simulator.state.down = 3
	simulator.state.yards_to_first = 1
	var short_yardage := simulator.recommended_defensive_calls(4)
	_check(short_yardage.any(func(call: DefensiveCallData): return call.has_tag("run_commit")), "Short yardage should recommend a run commitment")

	simulator.state.field_position = 95
	var goal_line := simulator.recommended_defensive_calls(4)
	_check(goal_line.any(func(call: DefensiveCallData): return call.has_tag("goal_line")), "A snap inside the five should recommend the Goal Line package")

	simulator.state.field_position = 65
	simulator.state.quarter = 4
	simulator.state.clock_seconds = 85
	simulator.state.add_score(simulator.state.defense().id, 7)
	var late_lead := simulator.recommended_defensive_calls(4)
	_check(late_lead.any(func(call: DefensiveCallData): return call.has_tag("prevent")), "A late defensive lead should make Prevent available as a recommendation")


func _test_selected_defense_reaches_the_simulator() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 880311)
	simulator.state.possession_team_id = teams[1].id
	var result := simulator.simulate_called_defense("nickel_cover_0_blitz")
	_check(result != null, "A legal user defensive call should resolve one snap")
	if result == null:
		return
	_check(result.defensive_call_id == "nickel_cover_0_blitz" and result.defensive_call_was_user_selected, "The result should retain the selected defensive call")
	_check(result.defensive_call_personnel == "Nickel" and result.defensive_call_shell == "Cover 0", "The result should retain personnel and coverage metadata")
	_check(not result.call_id.is_empty() and not result.call_was_user_selected, "The opposing AI coordinator should supply the offensive call")
	_check(result.defensive_participant_ids.size() == 11, "A called defense should record the complete on-field unit")

	var pass_simulator := FootballSimulator.new(teams[1], teams[0], 880312)
	pass_simulator.state.possession_team_id = teams[1].id
	var selected := _selected_call("nickel_cover_0_blitz")
	var pass_result := pass_simulator.simulate_next_play(PlayCallData.new("four_verticals"), selected)
	_check(pass_result != null and pass_result.matchup_context.get("rush_participant_ids", []).size() == 6, "Cover 0 should send its configured six-player pressure group")
	_check(pass_result != null and pass_result.matchup_context.get("coverage_shell", "") == "Cover 0", "The pass matchup should expose the chosen coverage shell")
	var blitz_animation := PlayAnimationComposer.compose(pass_result, pass_simulator.state)
	var pressure_tracks := blitz_animation.actor_tracks.filter(func(track: PlayActorTrack): return track.assignment_role in ["RUSH", "BLITZ"])
	_check(blitz_animation.defensive_shell == "Cover 0" and pressure_tracks.size() == 6, "The 2D presentation should draw the chosen shell and all six pressure paths")

	var spy_simulator := FootballSimulator.new(teams[1], teams[0], 880313)
	spy_simulator.state.possession_team_id = teams[1].id
	var spy_result := spy_simulator.simulate_next_play(PlayCallData.new("quick_slants"), _selected_call("nickel_qb_spy"))
	var spy_animation := PlayAnimationComposer.compose(spy_result, spy_simulator.state)
	_check(spy_animation.actor_tracks.any(func(track: PlayActorTrack): return track.assignment_role == "SPY"), "The 2D presentation should include the selected quarterback-spy path")


func _test_defensive_calls_change_outcomes() -> void:
	var playbook := PlaybookCatalog.pro_style_offense()
	var inside_zone := playbook.play_by_id("inside_zone")
	var read_option := playbook.play_by_id("read_option")
	var verticals := playbook.play_by_id("four_verticals")
	var bear := PlaybookCatalog.multiple_defense().call_by_id("bear_run_commit")
	var prevent := PlaybookCatalog.multiple_defense().call_by_id("prevent_quarters")
	var spy := PlaybookCatalog.multiple_defense().call_by_id("nickel_qb_spy")
	var blitz := PlaybookCatalog.multiple_defense().call_by_id("nickel_cover_0_blitz")
	var bear_run := PlayCallerService.matchup_modifiers(inside_zone, bear, [])
	var prevent_run := PlayCallerService.matchup_modifiers(inside_zone, prevent, [])
	_check(float(bear_run["yardage"]) < float(prevent_run["yardage"]), "Run Commit should concede fewer expected rushing yards than Prevent")
	var spy_run := PlayCallerService.matchup_modifiers(read_option, spy, [])
	var normal_run := PlayCallerService.matchup_modifiers(read_option, PlaybookCatalog.multiple_defense().call_by_id("nickel_cover_3"), [])
	_check(float(spy_run["yardage"]) < float(normal_run["yardage"]), "A spy should reduce expected quarterback-run yardage")
	var blitz_pass := PlayCallerService.matchup_modifiers(verticals, blitz, [])
	var prevent_pass := PlayCallerService.matchup_modifiers(verticals, prevent, [])
	_check(float(blitz_pass["sack"]) > float(prevent_pass["sack"]), "Cover 0 pressure should create more sack probability than Prevent")
	_check(float(blitz_pass["explosive"]) > float(prevent_pass["explosive"]), "Cover 0 should expose more explosive-play risk than Prevent")

	var teams := SampleLeague.create_teams()
	var bear_yards := 0
	var prevent_yards := 0
	var blitz_sacks := 0
	var prevent_sacks := 0
	var blitz_explosives := 0
	var prevent_explosives := 0
	for trial in range(120):
		var run_seed := 920000 + trial
		var bear_sim := FootballSimulator.new(teams[1], teams[0], run_seed)
		var prevent_sim := FootballSimulator.new(teams[1], teams[0], run_seed)
		bear_sim.state.possession_team_id = teams[1].id
		prevent_sim.state.possession_team_id = teams[1].id
		bear_yards += bear_sim.simulate_next_play(PlayCallData.new("inside_zone"), _selected_call("bear_run_commit")).yards
		prevent_yards += prevent_sim.simulate_next_play(PlayCallData.new("inside_zone"), _selected_call("prevent_quarters")).yards

		var pass_seed := 930000 + trial
		var blitz_sim := FootballSimulator.new(teams[1], teams[0], pass_seed)
		var prevent_pass_sim := FootballSimulator.new(teams[1], teams[0], pass_seed)
		blitz_sim.state.possession_team_id = teams[1].id
		prevent_pass_sim.state.possession_team_id = teams[1].id
		var blitz_result := blitz_sim.simulate_next_play(PlayCallData.new("four_verticals"), _selected_call("nickel_cover_0_blitz"))
		var prevent_result := prevent_pass_sim.simulate_next_play(PlayCallData.new("four_verticals"), _selected_call("prevent_quarters"))
		blitz_sacks += 1 if blitz_result.sack else 0
		prevent_sacks += 1 if prevent_result.sack else 0
		blitz_explosives += 1 if bool(blitz_result.matchup_context.get("explosive_play", false)) else 0
		prevent_explosives += 1 if bool(prevent_result.matchup_context.get("explosive_play", false)) else 0
	_check(bear_yards + 100 < prevent_yards, "Run Commit should materially suppress rushing production across seeded trials")
	_check(blitz_sacks > prevent_sacks, "Aggressive pressure should create more actual sacks across seeded trials")
	_check(blitz_explosives > prevent_explosives, "Prevent should allow fewer actual explosive passes across seeded trials")


func _test_game_books_preserve_calls() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 550191)
	simulator.state.possession_team_id = teams[1].id
	simulator.simulate_next_play(PlayCallData.new("quick_slants"), _selected_call("nickel_cover_1_robber"))
	simulator.simulate_next_play(PlayCallData.new("inside_zone"), _selected_call("base_cover_3"))
	var matchup := MatchupData.new("defense_test", 1, teams[1].id, teams[0].id)
	var book := GameBookData.from_game(matchup, simulator.state, 2026)
	_check(book.play_calls.size() == simulator.state.play_history.size(), "A game book should preserve one call record per snap")
	_check(book.play_calls[0].get("defensive_call_id", "") == "nickel_cover_1_robber", "The game book should preserve the defensive call ID")
	_check(bool(book.play_calls[0].get("defensive_call_was_user_selected", false)), "The game book should identify user-selected defensive calls")
	var restored := GameBookData.from_dict(JSON.parse_string(JSON.stringify(book.to_dict())))
	_check(restored.play_calls.size() == book.play_calls.size(), "Defensive call records should survive game-book serialization")
	_check(restored.play_calls[0].get("defensive_call_id", "") == book.play_calls[0].get("defensive_call_id", ""), "Serialized game books should retain the defensive call identity")


func _test_match_center_defensive_call_sheet() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 221109)
	var user_team: TeamData = teams[0]
	simulator.state.possession_team_id = teams[1].id
	var packed: PackedScene = load("res://scenes/screens/match_center.tscn")
	var screen := packed.instantiate()
	screen.setup(simulator, user_team, false)
	root.add_child(screen)
	await process_frame
	_check(screen._call_sheet_title.text == "Defensive Call Sheet", "Opponent possession should open the Defensive Call Sheet")
	_check(not screen._tempo_group.visible, "Offensive tempo controls should stay hidden while calling defense")
	_check(screen._play_category_buttons["BASE"].visible and screen._play_category_buttons["PREVENT"].visible, "The defensive personnel filters should be visible")
	_check(not screen._play_category_buttons["RUN"].visible and not screen._play_category_buttons["PASS"].visible, "Offensive concept filters should be hidden on defense")
	_check(screen._displayed_play_ids.size() == 3, "The defensive coordinator should show three situational recommendations")

	var previous_count := simulator.state.play_count
	screen._call_defense("fire_zone_3")
	await process_frame
	_check(simulator.state.play_count == previous_count + 1, "Submitting a defensive call should resolve exactly one snap")
	_check(simulator.state.play_history.back().defensive_call_was_user_selected, "The Match Center should mark the submitted defensive call as user-selected")
	_check(screen._field.is_animation_active(), "A user-called defensive snap should start the 2D presentation")
	screen._skip_animation()
	await process_frame

	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	_check(screen._body_grid.columns == 1 and screen._play_grid.columns == 1, "The defensive call sheet should use one column on a narrow display")
	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	_check(screen._body_grid.columns == 2 and screen._play_grid.columns == 3, "The defensive call sheet should use the full wide-screen layout")
	screen.queue_free()


func _selected_call(call_id: String) -> DefensiveCallData:
	var source := PlaybookCatalog.multiple_defense().call_by_id(call_id)
	var selected := DefensiveCallData.from_dict(source.to_dict())
	selected.user_selected = true
	return selected


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
