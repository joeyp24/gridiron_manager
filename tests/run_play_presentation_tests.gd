extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_scrimmage_animation_composition()
	_test_deterministic_animation_composition()
	_test_special_teams_animation_composition()
	_test_every_supported_play_category()
	await _test_field_playback_controls()
	await _test_match_center_integration()

	if _failures.is_empty():
		print("PASS: %d assertions across 2D play composition, field playback, and Match Center integration." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _test_scrimmage_animation_composition() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 440921)
	simulator.state.possession_team_id = teams[0].id
	var result := simulator.simulate_called_play("inside_zone")
	var simulation_signature := simulator.state.summary_signature()
	var animation := PlayAnimationComposer.compose(result, simulator.state)
	_check(animation != null, "A completed scrimmage play should produce presentation data")
	if animation == null:
		return
	_check(animation.actor_tracks.size() == 22, "A scrimmage replay should place 22 player icons on the field")
	_check(animation.offense_track_count() == 11 and animation.defense_track_count() == 11, "A replay should preserve eleven-player units for both clubs")
	var player_ids: Dictionary = {}
	for track in animation.actor_tracks:
		player_ids[track.player_id] = true
		_check(track.is_valid(), "Every player icon should have a valid chronological movement track")
		for progress in [0.0, 0.5, 1.0]:
			var position := track.sample(progress)
			_check(position.x >= 0.0 and position.x <= 100.0 and position.y >= 0.0 and position.y <= 1.0, "Player movement should remain inside normalized field bounds")
	_check(player_ids.size() == 22, "A replay should not duplicate a player icon")
	_check(animation.track_for_player(result.ball_carrier_id) != null, "The actual ball carrier should be highlighted in the replay")
	_check(animation.ball_keyframe_positions.size() >= 3, "A running play should include snap, exchange, and finish ball positions")
	_check(animation.outcome_position.x != animation.line_of_scrimmage or result.yards == 0, "The replay endpoint should reflect the simulated yardage")
	_check(simulator.state.summary_signature() == simulation_signature, "Composing and sampling presentation data must not mutate simulation state")

	var home_simulator := FootballSimulator.new(teams[3], teams[2], 918231)
	home_simulator.state.possession_team_id = teams[3].id
	var home_result := home_simulator.simulate_called_play("inside_zone")
	var home_animation := PlayAnimationComposer.compose(home_result, home_simulator.state)
	var expected_home_x := clampf(home_animation.line_of_scrimmage - float(home_result.yards), 0.0, 100.0)
	_check(home_animation.direction < 0.0 and is_equal_approx(home_animation.outcome_position.x, expected_home_x), "The home offense should animate toward the left goal without changing relative yardage")


func _test_deterministic_animation_composition() -> void:
	var first_teams := SampleLeague.create_teams()
	var second_teams := SampleLeague.create_teams()
	var first := FootballSimulator.new(first_teams[3], first_teams[2], 771913)
	var second := FootballSimulator.new(second_teams[3], second_teams[2], 771913)
	first.state.possession_team_id = first_teams[2].id
	second.state.possession_team_id = second_teams[2].id
	var first_result := first.simulate_called_play("quick_slants")
	var second_result := second.simulate_called_play("quick_slants")
	var first_animation := PlayAnimationComposer.compose(first_result, first.state)
	var second_animation := PlayAnimationComposer.compose(second_result, second.state)
	_check(first_result.description == second_result.description, "The seeded play results used for presentation should remain deterministic")
	_check(first_animation.signature() == second_animation.signature(), "Identical outcomes should produce identical animation timelines")
	_check(first_animation.track_for_player(first_result.passer_id) != null, "A pass replay should contain the actual quarterback")
	_check(first_animation.ball_visible_until < 1.0 or first_result.completed_pass or first_result.interception or first_result.sack, "An incomplete pass should remove the loose ball after arrival")


func _test_special_teams_animation_composition() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[5], teams[4], 912733)
	simulator.state.possession_team_id = teams[4].id
	simulator.state.field_position = 65
	var result := simulator.simulate_called_play("field_goal")
	var animation := PlayAnimationComposer.compose(result, simulator.state)
	_check(animation != null and animation.actor_tracks.size() == 22, "A field-goal replay should build complete special-team units")
	_check(animation.ball_is_kick and animation.ball_keyframe_positions.size() >= 4, "A field goal should include a visible kick trajectory")
	_check(is_equal_approx(animation.outcome_position.x, 100.0), "The away offense should kick toward the correct goal line")
	_check(animation.track_for_player(result.kicker_id) != null, "The actual kicker should appear in the special-teams replay")
	_check(animation.outcome_label in ["FIELD GOAL GOOD", "NO GOOD"], "The field-goal presentation should identify the simulated result")


func _test_every_supported_play_category() -> void:
	var call_ids: Array[String] = ["inside_zone", "quick_slants", "punt", "field_goal", "kneel", "spike"]
	for index in range(call_ids.size()):
		var teams := SampleLeague.create_teams()
		var simulator := FootballSimulator.new(teams[1], teams[0], 661200 + index)
		simulator.state.possession_team_id = teams[0].id
		if call_ids[index] == "field_goal":
			simulator.state.field_position = 65
		var result := simulator.simulate_called_play(call_ids[index])
		var animation := PlayAnimationComposer.compose(result, simulator.state)
		_check(result != null and animation != null, "%s should resolve into a presentation timeline" % call_ids[index])
		if animation != null:
			_check(animation.actor_tracks.size() == 22 and animation.ball_keyframe_positions.size() >= 3, "%s should produce full player and football tracks" % call_ids[index])


func _test_field_playback_controls() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 558331)
	simulator.state.possession_team_id = teams[0].id
	var result := simulator.simulate_called_play("outside_zone")
	var animation := PlayAnimationComposer.compose(result, simulator.state)
	var field := FieldVisual.new()
	field.size = Vector2(900, 360)
	root.add_child(field)
	field.set_game_state(simulator.state)
	var finished := [0]
	field.animation_finished.connect(func(_value: PlayAnimationData): finished[0] += 1)
	field.play_animation(animation)
	await process_frame
	_check(field.is_animation_active() and field.playback_progress() >= 0.0, "The field should start an animation at the beginning of its timeline")
	field._process(animation.duration_seconds * 0.25)
	var quarter_progress := field.playback_progress()
	_check(quarter_progress >= 0.24 and quarter_progress <= 0.26, "Playback should advance from real elapsed time")
	field.toggle_pause()
	field._process(1.0)
	_check(field.is_paused() and is_equal_approx(field.playback_progress(), quarter_progress), "Pausing should freeze the replay timeline")
	field.set_playback_speed(2.0)
	field.toggle_pause()
	field._process(animation.duration_seconds * 0.10)
	_check(field.playback_progress() > quarter_progress + 0.19, "Playback speed should affect timeline advancement")
	field.skip_animation()
	_check(not field.is_animation_active() and is_equal_approx(field.playback_progress(), 1.0), "Skip should land on the final presentation frame")
	_check(finished[0] == 1, "Completing a replay should emit its finish event exactly once")
	field.replay()
	_check(field.is_animation_active() and is_equal_approx(field.playback_progress(), 0.0), "Replay should restart the retained timeline")
	field.skip_animation()
	_check(finished[0] == 2, "A replay should produce one new completion event")
	field.queue_free()


func _test_match_center_integration() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[1], teams[0], 825511)
	var user_team: TeamData = teams[0]
	simulator.state.possession_team_id = user_team.id
	simulator.state.opening_possession_team_id = user_team.id
	var packed: PackedScene = load("res://scenes/screens/match_center.tscn")
	var screen := packed.instantiate()
	screen.setup(simulator, user_team, false)
	root.add_child(screen)
	await process_frame

	var previous_play_count := simulator.state.play_count
	screen._call_play("inside_zone")
	await process_frame
	_check(simulator.state.play_count == previous_play_count + 1, "Calling a play should still resolve exactly one simulation result")
	_check(screen._field.is_animation_active(), "A single called play should automatically start its 2D replay")
	_check(screen._field.animation_data.actor_tracks.size() == 22, "Match Center should receive the complete 22-player presentation")
	_check(screen._next_button.disabled and screen._drive_button.disabled and screen._finish_button.disabled, "Simulation actions should lock while a replay is running")
	_check(not screen._pause_button.disabled and not screen._skip_button.disabled, "Playback controls should remain available during a replay")

	screen._select_animation_speed(3)
	_check(is_equal_approx(screen._field.playback_speed(), 2.0), "The Match Center speed selector should update field playback")
	screen._toggle_animation_pause()
	_check(screen._field.is_paused() and screen._pause_button.text == "RESUME", "The Match Center should expose paused state clearly")
	screen._toggle_animation_pause()
	screen._skip_animation()
	await process_frame
	_check(not screen._field.is_animation_active() and not screen._replay_button.disabled, "Finishing a replay should restore actions and enable replay")

	screen._replay_animation()
	_check(screen._field.is_animation_active(), "The completed snap should be replayable without resimulating it")
	screen._toggle_presentation(false)
	_check(not screen._field.is_animation_active() and screen._presentation_toggle.text == "2D VIEW · OFF", "Disabling presentation should dismiss playback without changing the game")
	previous_play_count = simulator.state.play_count
	screen._simulate_play()
	_check(simulator.state.play_count == previous_play_count + 1 and screen._field.animation_data == null, "With 2D view disabled, Next Play should retain immediate simulation behavior")

	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	_check(screen._body_grid.columns == 1 and not screen._field_legend.visible, "The 2D presentation should use the narrow Match Center layout")
	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	_check(screen._body_grid.columns == 2 and screen._field_legend.visible, "The 2D presentation should expose its complete legend on wide displays")
	screen.queue_free()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
