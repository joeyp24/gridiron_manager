extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	_test_seeded_games_are_deterministic()
	_test_games_reach_a_legal_final_state()
	_test_statistics_balance()
	_test_strategy_cloning_is_isolated()

	if _failures.is_empty():
		print("PASS: %d assertions across simulation and domain checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		printerr("%d assertion(s) failed." % _failures.size())
		quit(1)


func _test_seeded_games_are_deterministic() -> void:
	var teams := SampleLeague.create_teams()
	var first := FootballSimulator.new(teams[0], teams[1], 424242)
	var second := FootballSimulator.new(teams[0], teams[1], 424242)
	first.simulate_to_end()
	second.simulate_to_end()
	_check(first.state.summary_signature() == second.state.summary_signature(), "Identical seeds should produce identical games")
	_check(first.state.play_count == second.state.play_count, "Deterministic games should have the same play count")


func _test_games_reach_a_legal_final_state() -> void:
	var teams := SampleLeague.create_teams()
	for index in range(24):
		var home := teams[index % teams.size()]
		var away := teams[(index + 1) % teams.size()]
		var simulator := FootballSimulator.new(home, away, 1000 + index)
		simulator.simulate_to_end()
		var state := simulator.state
		_check(state.is_final, "Game %d did not reach a final state" % index)
		_check(state.play_count > 0 and state.play_count <= 500, "Game %d produced an illegal play count" % index)
		_check(state.home_score >= 0 and state.away_score >= 0, "Game %d produced a negative score" % index)
		_check(state.field_position >= 1 and state.field_position <= 100, "Game %d ended outside the field" % index)


func _test_statistics_balance() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[2], teams[3], 8675309)
	simulator.simulate_to_end()
	for team in [simulator.state.home_team, simulator.state.away_team]:
		var stats: Dictionary = simulator.state.stats[team.id]
		_check(stats["total_yards"] == stats["pass_yards"] + stats["rush_yards"], "%s yardage categories do not balance" % team.abbreviation)
		_check(stats["plays"] >= stats["turnovers"], "%s has more turnovers than recorded plays" % team.abbreviation)
		_check(stats["possession_seconds"] >= 0, "%s has negative possession time" % team.abbreviation)


func _test_strategy_cloning_is_isolated() -> void:
	var original := SampleLeague.create_teams()[0]
	var adjusted := original.clone_with_strategy({"run_tendency": 0.72, "aggression": 0.31})
	_check(is_equal_approx(adjusted.run_tendency, 0.72), "Cloned strategy did not apply run tendency")
	_check(is_equal_approx(adjusted.aggression, 0.31), "Cloned strategy did not apply aggression")
	_check(not is_equal_approx(original.run_tendency, adjusted.run_tendency), "Strategy clone mutated the source team")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
