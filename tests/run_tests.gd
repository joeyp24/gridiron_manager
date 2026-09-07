extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	_test_seeded_games_are_deterministic()
	_test_playbook_catalog_and_call_validation()
	_test_called_plays_are_deterministic()
	_test_personnel_packages_and_attribute_matchups()
	_test_detailed_attributes_drive_outcomes()
	_test_clock_management_calls()
	_test_games_reach_a_legal_final_state()
	_test_statistics_balance()
	_test_player_statistics_reconcile_with_team_totals()
	_test_weekly_statistics_rollup_is_idempotent()
	_test_player_statistics_preserve_team_splits()
	_test_statistics_center_queries()
	_test_strategy_cloning_is_isolated()
	_test_full_rosters_and_depth_charts()
	_test_league_data_pack_catalog()
	_test_hybrid_player_database()
	_test_nflverse_career_flow()
	_test_round_robin_schedule()
	_test_weekly_health_progression()
	_test_active_career_game_is_resumable()
	_test_initial_contracts_and_cap_rules()
	_test_unified_player_generator()
	_test_free_agent_signing_and_release()
	_test_ai_roster_management()
	_test_trade_execution_and_draft_pick_ownership()
	_test_trade_counteroffers_and_deadline()
	_test_complete_career_season()
	_test_offseason_extensions_and_expiration()
	_test_player_development_is_deterministic()
	_test_retirement_lifecycle_is_deterministic()
	_test_retirement_archive_and_dead_cap()
	_test_draft_class_and_scouting()
	_test_draft_order_and_pick_ownership()
	_test_complete_seven_round_draft()
	_test_multi_season_career_loop()
	_test_long_run_population_balance()
	_test_career_serialization_round_trip()
	_test_save_repository_round_trip()
	_test_version_one_save_migration()
	_test_version_two_save_migration()
	_test_version_three_save_migration()
	_test_version_four_save_migration()
	_test_version_five_save_migration()
	_test_version_seven_trade_save_migration()
	_test_version_eight_statistics_save_migration()
	_test_version_nine_hybrid_ratings_save_migration()

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


func _test_playbook_catalog_and_call_validation() -> void:
	var playbook := PlaybookCatalog.pro_style_offense()
	_check(playbook.plays.size() == 26, "The pro-style call sheet should load all 26 initial concepts")
	var play_ids: Dictionary = {}
	for play in playbook.plays:
		play_ids[play.id] = true
	_check(play_ids.size() == playbook.plays.size(), "Every playbook concept should have a unique stable ID")
	_check(playbook.plays_in_category("Run").size() == 8, "The initial call sheet should contain eight run concepts")
	_check(playbook.plays_in_category("Pass").size() == 14, "The initial call sheet should contain fourteen pass concepts")
	var round_trip := PlaybookData.from_dict(JSON.parse_string(JSON.stringify(playbook.to_dict())))
	_check(round_trip.plays.size() == playbook.plays.size() and round_trip.play_by_id("four_verticals") != null, "Playbook data should survive a JSON round trip")
	var submitted := PlayCallData.from_dict(PlayCallData.new("mesh", PlayCallData.TEMPO_HURRY, true).to_dict())
	_check(submitted.play_id == "mesh" and submitted.tempo == PlayCallData.TEMPO_HURRY and submitted.user_selected, "Submitted play calls should preserve selection and tempo")

	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[0], teams[1], 22031)
	_check(not simulator.available_play_calls().is_empty(), "A legal offense should expose callable playbook concepts")
	_check(simulator.recommended_play_calls().size() == 3, "The coordinator should provide three situational recommendations")
	_check(not simulator.call_validation_error("missing_play").is_empty(), "Unknown play IDs should be rejected before simulation")
	_check(not simulator.call_validation_error("field_goal").is_empty(), "Out-of-range field goals should be unavailable")
	simulator.state.field_position = 60
	_check(simulator.call_validation_error("field_goal").is_empty(), "Field goals should become available in range")


func _test_called_plays_are_deterministic() -> void:
	var teams := SampleLeague.create_teams()
	var first := FootballSimulator.new(teams[2], teams[3], 993811)
	var second := FootballSimulator.new(teams[2], teams[3], 993811)
	for index in range(24):
		if first.state.is_final or second.state.is_final:
			break
		var play_id := "inside_zone" if index % 2 == 0 else "quick_slants"
		var first_result := first.simulate_called_play(play_id, PlayCallData.TEMPO_NORMAL)
		var second_result := second.simulate_called_play(play_id, PlayCallData.TEMPO_NORMAL)
		_check(first_result != null and second_result != null, "A legal selected concept should resolve one snap")
		if first_result == null or second_result == null:
			break
		_check(first_result.call_id == play_id and first_result.call_was_user_selected, "A resolved snap should retain its submitted call metadata")
		_check(not first_result.defensive_call_id.is_empty(), "A selected offensive call should resolve against an AI defensive call")
	_check(first.state.summary_signature() == second.state.summary_signature(), "The same seed and submitted call sequence should produce identical results")

	var neutral_defense := DefensiveCallData.new("neutral", "Neutral Front")
	neutral_defense.personnel = "Base"
	neutral_defense.coverage = "Zone"
	var repeated_play := PlaybookCatalog.pro_style_offense().play_by_id("inside_zone")
	var clean := PlayCallerService.matchup_modifiers(repeated_play, neutral_defense, [])
	var history: Array[PlayResult] = []
	for index in range(3):
		var previous := PlayResult.new()
		previous.call_id = repeated_play.id
		history.append(previous)
	var anticipated := PlayCallerService.matchup_modifiers(repeated_play, neutral_defense, history)
	_check(float(anticipated.get("yardage", 0.0)) < float(clean.get("yardage", 0.0)), "Repeating the same call should create a defensive anticipation penalty")


func _test_personnel_packages_and_attribute_matchups() -> void:
	var teams := SampleLeague.create_teams()
	var offense := teams[0]
	var defense := teams[1]
	for personnel in ["10", "11", "12", "21", "22"]:
		var lineup := PersonnelPackageService.offensive_lineup(offense, personnel)
		var expected := PersonnelPackageService.offensive_counts(personnel)
		_check(lineup.size() == 11, "%s offensive personnel should field exactly eleven players" % personnel)
		for position_name in expected:
			_check(_position_count(lineup, str(position_name)) == int(expected[position_name]), "%s personnel should honor its %s count" % [personnel, position_name])
	for personnel in ["Base", "Nickel", "Dime", "Goal Line"]:
		var lineup := PersonnelPackageService.defensive_lineup(defense, personnel)
		var expected := PersonnelPackageService.defensive_counts(personnel)
		_check(lineup.size() == 11, "%s defense should field exactly eleven players" % personnel)
		for position_name in expected:
			_check(_position_count(lineup, str(position_name)) == int(expected[position_name]), "%s defense should honor its %s count" % [personnel, position_name])

	var play := PlaybookCatalog.pro_style_offense().play_by_id("inside_zone")
	var offense_lineup := PersonnelPackageService.offensive_lineup(offense, "11")
	var defense_lineup := PersonnelPackageService.defensive_lineup(defense, "Base")
	var runner := offense.player_at("RB")
	var tackler := defense.player_at("LB")
	var run_matchup := AttributeMatchupService.run_matchup(
		play,
		PersonnelPackageService.blockers(offense_lineup, runner),
		PersonnelPackageService.rushers(defense_lineup),
		runner,
		tackler
	)
	_check(run_matchup.has("blocking_edge") and run_matchup.has("ball_security"), "The run model should expose blocking, carrying, tackling, and ball-security context")
	var simulator := FootballSimulator.new(offense, defense, 930114)
	simulator.state.possession_team_id = offense.id
	var result := simulator.simulate_called_play("inside_zone")
	_check(result != null and result.matchup_context.get("model", "") == "attribute_simulation_v2", "Resolved plays should retain their direct-attribute matchup context")
	_check(result != null and result.offensive_participant_ids.size() == 11 and result.defensive_participant_ids.size() == 11, "Resolved scrimmage plays should record both actual eleven-player packages")


func _test_detailed_attributes_drive_outcomes() -> void:
	var templates := SampleLeague.create_teams()
	var high_run_yards := 0
	var low_run_yards := 0
	var high_completions := 0
	var low_completions := 0
	var high_field_goals := 0
	var low_field_goals := 0
	for trial in range(120):
		var high_offense := templates[2].clone_with_strategy({})
		var low_offense := templates[2].clone_with_strategy({})
		var high_defense := templates[3].clone_with_strategy({})
		var low_defense := templates[3].clone_with_strategy({})
		_set_detailed_attributes(high_offense, 94)
		_set_detailed_attributes(low_offense, 56)
		var run_seed := 710000 + trial
		var high_run := FootballSimulator.new(high_offense, high_defense, run_seed)
		var low_run := FootballSimulator.new(low_offense, low_defense, run_seed)
		high_run.state.possession_team_id = high_offense.id
		low_run.state.possession_team_id = low_offense.id
		high_run_yards += high_run.simulate_called_play("inside_zone").yards
		low_run_yards += low_run.simulate_called_play("inside_zone").yards

		var high_pass := FootballSimulator.new(high_offense, high_defense, run_seed + 2000)
		var low_pass := FootballSimulator.new(low_offense, low_defense, run_seed + 2000)
		high_pass.state.possession_team_id = high_offense.id
		low_pass.state.possession_team_id = low_offense.id
		high_completions += 1 if high_pass.simulate_called_play("quick_slants").completed_pass else 0
		low_completions += 1 if low_pass.simulate_called_play("quick_slants").completed_pass else 0

		var high_kick := FootballSimulator.new(high_offense, high_defense, run_seed + 4000)
		var low_kick := FootballSimulator.new(low_offense, low_defense, run_seed + 4000)
		high_kick.state.possession_team_id = high_offense.id
		low_kick.state.possession_team_id = low_offense.id
		high_kick.state.field_position = 60
		low_kick.state.field_position = 60
		high_field_goals += 1 if high_kick.simulate_called_play("field_goal").field_goal_made else 0
		low_field_goals += 1 if low_kick.simulate_called_play("field_goal").field_goal_made else 0
	_check(high_run_yards > low_run_yards + 60, "Elite detailed attributes should create a meaningful rushing advantage across seeded trials")
	_check(high_completions > low_completions + 10, "Elite passing and receiving attributes should improve completion results across seeded trials")
	_check(high_field_goals > low_field_goals + 10, "Kick accuracy and power should directly improve field-goal results across seeded trials")


func _test_clock_management_calls() -> void:
	var teams := SampleLeague.create_teams()
	var spike_simulator := FootballSimulator.new(teams[4], teams[5], 77102)
	spike_simulator.state.quarter = 4
	spike_simulator.state.clock_seconds = 30
	spike_simulator.state.down = 1
	spike_simulator.state.add_score(spike_simulator.state.defense().id, 3)
	var recommendations := spike_simulator.recommended_play_calls()
	_check(recommendations.any(func(play: PlayDefinitionData): return play.id == "spike"), "A trailing offense inside 45 seconds should receive a spike recommendation")
	var spike := spike_simulator.simulate_called_play("spike", PlayCallData.TEMPO_HURRY)
	_check(spike != null and spike.play_type == "pass" and spike.call_id == "spike", "A spike should be recorded as a selected pass call")
	_check(spike_simulator.state.down == 2 and spike_simulator.state.clock_seconds == 29, "A spike should sacrifice one down and one second")
	_check(spike_simulator.state.stats[spike.offense_id]["passing_attempts"] == 1, "A spike should count as a team pass attempt")

	var kneel_simulator := FootballSimulator.new(teams[6], teams[7], 77103)
	kneel_simulator.state.quarter = 4
	kneel_simulator.state.clock_seconds = 70
	kneel_simulator.state.add_score(kneel_simulator.state.offense().id, 7)
	var kneel_recommendations := kneel_simulator.recommended_play_calls()
	_check(kneel_recommendations.any(func(play: PlayDefinitionData): return play.id == "kneel"), "A leading offense late in the fourth quarter should receive a kneel recommendation")
	var kneel := kneel_simulator.simulate_called_play("kneel", PlayCallData.TEMPO_CHEW)
	_check(kneel != null and kneel.play_type == "run" and kneel.ball_carrier_id == kneel_simulator.state.team_by_id(kneel.offense_id).player_at("QB").id, "A kneel should be credited to the quarterback as a rushing play")
	_check(kneel_simulator.state.clock_seconds < 35, "Chew Clock should drain the clock on a kneel-down")


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


func _test_player_statistics_reconcile_with_team_totals() -> void:
	var teams := SampleLeague.create_teams()
	var simulator := FootballSimulator.new(teams[4], teams[5], 220091)
	simulator.simulate_to_end()
	for team in [simulator.state.home_team, simulator.state.away_team]:
		var passing_attempts := 0
		var passing_completions := 0
		var passing_yards := 0
		var rushing_attempts := 0
		var rushing_yards := 0
		var receiving_yards := 0
		var interceptions := 0
		var fumbles_lost := 0
		var sacks_taken := 0
		var sack_yards_lost := 0
		var touchdowns := 0
		var field_goals := 0
		var extra_points := 0
		for line: PlayerGameStatsData in simulator.state.player_stats.values():
			if line.team_id != team.id:
				continue
			passing_attempts += line.stats.value("passing_attempts")
			passing_completions += line.stats.value("passing_completions")
			passing_yards += line.stats.value("passing_yards")
			rushing_attempts += line.stats.value("rushing_attempts")
			rushing_yards += line.stats.value("rushing_yards")
			receiving_yards += line.stats.value("receiving_yards")
			interceptions += line.stats.value("passing_interceptions")
			fumbles_lost += line.stats.value("fumbles_lost")
			sacks_taken += line.stats.value("sacks_taken")
			sack_yards_lost += line.stats.value("sack_yards_lost")
			touchdowns += line.stats.value("passing_touchdowns") + line.stats.value("rushing_touchdowns")
			field_goals += line.stats.value("field_goals_made")
			extra_points += line.stats.value("extra_points_made")
		var team_stats: Dictionary = simulator.state.stats[team.id]
		_check(passing_attempts == team_stats["passing_attempts"], "%s player pass attempts should reconcile with the team total" % team.abbreviation)
		_check(passing_completions == team_stats["passing_completions"], "%s player completions should reconcile with the team total" % team.abbreviation)
		_check(passing_yards == team_stats["gross_pass_yards"], "%s player passing yards should reconcile with gross team passing" % team.abbreviation)
		_check(receiving_yards == team_stats["gross_pass_yards"], "%s receiving yards should reconcile with gross team passing" % team.abbreviation)
		_check(team_stats["pass_yards"] == passing_yards - sack_yards_lost, "%s net passing should deduct credited sack yardage" % team.abbreviation)
		_check(rushing_attempts == team_stats["rushing_attempts"], "%s player carries should reconcile with the team total" % team.abbreviation)
		_check(rushing_yards == team_stats["rush_yards"], "%s player rushing yards should reconcile with the team total" % team.abbreviation)
		_check(interceptions + fumbles_lost == team_stats["turnovers"], "%s player turnovers should reconcile with the team total" % team.abbreviation)
		_check(sacks_taken == team_stats["sacks_allowed"], "%s player sacks taken should reconcile with the team total" % team.abbreviation)
		_check(team_stats["points"] == touchdowns * 6 + field_goals * 3 + extra_points, "%s scoring credits should reconcile with the scoreboard" % team.abbreviation)
		_check(team_stats["points"] == simulator.state.score_for(team.id), "%s statistic points should equal the final score" % team.abbreviation)


func _test_weekly_statistics_rollup_is_idempotent() -> void:
	var career := CareerSession.new_career("seattle_orcas", 73191, LeagueCatalog.SOURCE_FICTIONAL)
	career.simulate_current_week()
	var season := career.league.current_season_statistics()
	_check(season != null and season.game_books.size() == 4, "A completed eight-team week should retain four immutable game books")
	if season == null or season.game_books.is_empty():
		return
	var book: GameBookData = season.game_books.values().front()
	var player_line: PlayerGameStatsData = book.player_stats.values().front()
	var career_line := career.league.player_career_statistics(player_line.player_id)
	var games_before := career_line.stats.value("games_played")
	_check(not career.league.statistics.record_game(book), "A completed matchup should not be aggregated twice")
	_check(career.league.player_career_statistics(player_line.player_id).stats.value("games_played") == games_before, "Rejected duplicate game books should not change career totals")
	for team in career.league.teams:
		var team_line := season.team_stats_for(team.id, LeagueState.PHASE_REGULAR_SEASON)
		_check(team_line != null and team_line.value("games_played") == 1, "%s should have one weekly team-stat result" % team.abbreviation)


func _test_player_statistics_preserve_team_splits() -> void:
	var first_game := PlayerGameStatsData.new("split_player", "Split Player", "QB", "club_a", "club_b")
	first_game.mark_appearance(true)
	first_game.stats.add("passing_attempts", 24)
	first_game.stats.add("passing_yards", 241)
	var second_game := PlayerGameStatsData.new("split_player", "Split Player", "QB", "club_b", "club_c")
	second_game.mark_appearance(true)
	second_game.stats.add("passing_attempts", 31)
	second_game.stats.add("passing_yards", 318)
	var season_line := PlayerSeasonStatsData.new(2026, "split_player", "Split Player", "QB")
	season_line.record_game(first_game, LeagueState.PHASE_REGULAR_SEASON)
	season_line.record_game(second_game, LeagueState.PHASE_REGULAR_SEASON)
	_check(season_line.stats.value("games_played") == 2, "A traded player's season total should follow the player ID")
	_check(season_line.stats.value("passing_yards") == 559, "A traded player's season total should combine both clubs")
	_check((season_line.team_splits["club_a"] as StatLineData).value("passing_yards") == 241, "The former club split should remain intact after a move")
	_check((season_line.team_splits["club_b"] as StatLineData).value("passing_yards") == 318, "The new club split should receive only post-move production")


func _test_statistics_center_queries() -> void:
	var career := CareerSession.new_career("seattle_orcas", 620927, LeagueCatalog.SOURCE_FICTIONAL)
	var league := career.league
	var user_team := career.user_team()
	var preseason_user_rows := StatisticsService.player_rows(
		league,
		league.season_year,
		StatisticsService.PHASE_ALL,
		user_team.id
	)
	_check(preseason_user_rows.size() == user_team.players.size(), "Statistics queries should retain zero-stat players on the active roster")
	_check(preseason_user_rows.all(func(row: Dictionary): return (row.get("stats") as StatLineData).value("games_played") == 0), "Preseason player rows should begin at zero without disappearing")
	var preseason_teams := StatisticsService.team_rows(league, league.season_year)
	_check(preseason_teams.size() == league.teams.size(), "Team rankings should retain every club before games are played")

	career.simulate_current_week()
	var completed := StatisticsService.completed_games(league, league.season_year)
	_check(completed.size() == 4, "The game-book query should expose every completed game in an eight-team week")
	_check(StatisticsService.completed_games(league, league.season_year, StatisticsService.PHASE_POSTSEASON).is_empty(), "Postseason filters should exclude regular-season books")
	_check(StatisticsService.completed_games(league, league.season_year, StatisticsService.PHASE_ALL, user_team.id).size() == 1, "A club filter should narrow the game-book slate to that club")

	var quarterback_rows := StatisticsService.sorted_player_rows(
		StatisticsService.player_rows(league, league.season_year),
		"Passing"
	)
	_check(not quarterback_rows.is_empty(), "Passing leaders should return the league's quarterbacks")
	if not quarterback_rows.is_empty():
		var leader: Dictionary = quarterback_rows.front()
		var trailer: Dictionary = quarterback_rows.back()
		_check(StatisticsService.metric_value(leader.get("stats"), "passing_yards") >= StatisticsService.metric_value(trailer.get("stats"), "passing_yards"), "Passing leaders should default to descending yardage")
		var ascending := StatisticsService.sort_player_rows(quarterback_rows, "passing_yards", false)
		_check(StatisticsService.metric_value(ascending.front().get("stats"), "passing_yards") <= StatisticsService.metric_value(ascending.back().get("stats"), "passing_yards"), "Player statistic columns should support ascending resorting")
		var appearances := StatisticsService.player_game_log(league, str(leader.get("player_id", "")), league.season_year)
		_check(appearances.size() == 1, "A week-one participant should have one player game-log entry")
		_check(StatisticsService.player_team_splits(league, str(leader.get("player_id", "")), league.season_year).size() == 1, "An untraded player should have one club split")

	var offense_rows := StatisticsService.sorted_team_rows(StatisticsService.team_rows(league, league.season_year), "Offense")
	_check(offense_rows.size() == league.teams.size(), "Team ranking queries should return the full league")
	var points_ascending := StatisticsService.sort_team_rows(offense_rows, "points", false)
	_check(StatisticsService.metric_value(points_ascending.front().get("stats"), "points") <= StatisticsService.metric_value(points_ascending.back().get("stats"), "points"), "Team statistic columns should support ascending resorting")


func _test_strategy_cloning_is_isolated() -> void:
	var original := SampleLeague.create_teams()[0]
	var adjusted := original.clone_with_strategy({"run_tendency": 0.72, "aggression": 0.31})
	_check(is_equal_approx(adjusted.run_tendency, 0.72), "Cloned strategy did not apply run tendency")
	_check(is_equal_approx(adjusted.aggression, 0.31), "Cloned strategy did not apply aggression")
	_check(not is_equal_approx(original.run_tendency, adjusted.run_tendency), "Strategy clone mutated the source team")


func _test_full_rosters_and_depth_charts() -> void:
	var teams := SampleLeague.create_teams()
	_check(teams.size() == 8, "The prototype league should contain eight teams")
	for team in teams:
		_check(team.players.size() == 42, "%s legacy fixture should include every required position" % team.abbreviation)
		for position_name in TeamData.ROSTER_POSITIONS:
			_check(not team.depth_players(position_name).is_empty(), "%s is missing %s depth" % [team.abbreviation, position_name])
	var team: TeamData = teams.front()
	var original_starter: PlayerData = team.player_at("QB")
	var backup: PlayerData = team.depth_players("QB")[1]
	_check(team.move_on_depth_chart("QB", backup.id, -1), "A backup should be movable into the starting slot")
	_check(team.player_at("QB").id == backup.id, "Depth-chart order should determine the starter")
	backup.injure("Test injury", 2)
	_check(team.player_at("QB").id == original_starter.id, "An injured starter should be replaced by the next available player")
	original_starter.is_active = false
	_check(team.player_at("QB").is_available(), "A depleted position should use an available emergency player")
	_check(team.player_at("QB").position != "QB", "An empty quarterback room should fall back outside the position group")


func _test_league_data_pack_catalog() -> void:
	var sources := LeagueCatalog.source_descriptors()
	_check(sources.size() == 1, "Career creation should offer the complete nflverse league database")
	var first := LeagueCatalog.create_bundle(LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var second := LeagueCatalog.create_bundle(LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var first_teams: Array = first.get("teams", [])
	var second_teams: Array = second.get("teams", [])
	_check(first_teams.size() == 32, "The nflverse league should contain all 32 clubs")
	_check(first.get("free_agents", []).size() >= 100, "The nflverse league should provide an expanded free-agent market")
	_check(first.get("schedule", []).size() == 272, "The nflverse league should load the complete 2026 schedule")
	_check(first.get("source", {}).get("rating_model_version", 0) == 1, "The nflverse pack should identify its rating model")
	var player_ids: Dictionary = {}
	for team: TeamData in first_teams:
		_check(team.players.size() == 53, "%s should have a full 53-player nflverse roster" % team.abbreviation)
		_check(not team.division.is_empty(), "%s should retain its source division" % team.abbreviation)
		_check(RosterValidator.validate_team(team).is_empty(), "%s should load as a legal nflverse roster" % team.abbreviation)
		for position_name in TeamData.ROSTER_POSITIONS:
			_check(not team.depth_players(position_name).is_empty(), "%s nflverse roster is missing %s" % [team.abbreviation, position_name])
		for player in team.players:
			player_ids[player.id] = true
			_check(player.generation_source in ["NFLverse + Madden NFL 26", "Madden NFL 26"], "%s should retain hybrid source provenance" % player.full_name)
	_check(player_ids.size() == 1696, "Every rostered hybrid player should retain a unique stable ID")
	var first_team: TeamData = first_teams.front()
	var second_team: TeamData = second_teams.front()
	first_team.players.front().energy = 12
	_check(second_team.players.front().energy == 100, "Data-pack loads should create isolated mutable career objects")


func _test_hybrid_player_database() -> void:
	var bundle := LeagueCatalog.create_bundle(LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var teams: Array = bundle.get("teams", [])
	var free_agents: Array = bundle.get("free_agents", [])
	var all_players: Array[PlayerData] = []
	var source_ids: Dictionary = {}
	var complete_ratings := 0
	var matching_overalls := 0
	var valid_media_urls := 0
	for team: TeamData in teams:
		_check(team.logo_url.begins_with("https://"), "%s should retain its Madden team-mark reference" % team.abbreviation)
		for player in team.players:
			all_players.append(player)
	for player: PlayerData in free_agents:
		all_players.append(player)
	for player in all_players:
		if player.madden_ratings != null and player.madden_ratings.has_madden_source() and player.madden_ratings.attributes.size() >= 54:
			complete_ratings += 1
		if player.madden_ratings != null and player.overall == player.madden_ratings.source_overall:
			matching_overalls += 1
		if player.madden_ratings != null and (player.madden_ratings.portrait_url.is_empty() or player.madden_ratings.portrait_url.begins_with("https://")):
			valid_media_urls += 1
		if player.madden_ratings != null:
			source_ids[player.madden_ratings.source_player_id] = true
	_check(all_players.size() == 2035, "The hybrid database should include every player in the Madden ratings snapshot")
	_check(free_agents.size() == 339, "Rated players outside the 32 active rosters should populate the expanded free-agent market")
	_check(complete_ratings == all_players.size(), "Every hybrid player should retain the complete Madden attribute set")
	_check(matching_overalls == all_players.size(), "Every initial hybrid overall should match its Madden source overall")
	_check(valid_media_urls == all_players.size(), "Every remote player media reference should be empty or HTTPS")
	_check(source_ids.size() == all_players.size(), "Every hybrid player should retain a unique Madden source ID")
	var rated_player: PlayerData = all_players.front()
	var serialized := PlayerData.from_dict(JSON.parse_string(JSON.stringify(rated_player.to_dict())))
	_check(serialized.jersey_number == rated_player.jersey_number, "Player serialization should preserve jersey numbers")
	_check(serialized.madden_ratings.attributes == rated_player.madden_ratings.attributes, "Player serialization should preserve every detailed Madden attribute")
	_check(serialized.madden_ratings.portrait_url == rated_player.madden_ratings.portrait_url, "Player serialization should preserve remote portrait references")
	var projected := PlayerData.from_dict({"id": "future_player", "full_name": "Future Player", "position": "QB", "overall": 71, "speed": 78, "power": 72, "technique": 70, "awareness": 66, "durability": 80, "age": 22})
	_check(not projected.madden_ratings.has_madden_source() and projected.madden_ratings.attributes.size() >= 54, "Future generated players should receive a compatible projected attribute profile")


func _test_nflverse_career_flow() -> void:
	var career := CareerSession.new_career("nfl_buf", 260826, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	_check(career != null and career.league != null, "An nflverse career should be creatable without a network connection")
	if career == null or career.league == null:
		return
	_check(career.user_team().abbreviation == "BUF", "The selected nflverse club should become the managed team")
	_check(career.league.conference_names() == ["AFC", "NFC"], "Source conferences should drive standings and championship qualification")
	_check(career.league.data_source_id == LeagueCatalog.SOURCE_NFLVERSE_FULL, "The career should retain its league source ID")
	_check(career.league.schedule.size() == 272 and career.league.league_format.games_per_team == 17, "A full career should use the 17-game schedule format")
	_check(career.league.data_snapshot == "2026-08-26", "The career should retain its source snapshot date")
	_check(career.league.data_source_metadata.get("license", "") == "CC-BY-4.0", "The career should retain the complete source manifest")
	career.simulate_current_week()
	_check(career.league.current_week == 2, "An nflverse league should complete and advance a simulated week")
	_check(StatisticsService.completed_games(career.league, career.league.season_year).size() == 16, "Statistics queries should expose all 16 completed games in an NFL week")
	_check(StatisticsService.team_rows(career.league, career.league.season_year).size() == 32, "Statistics rankings should retain all 32 NFL clubs")
	_check(StatisticsService.player_rows(career.league, career.league.season_year, StatisticsService.PHASE_ALL, career.user_team().id).size() == 53, "Club-filtered statistics should retain the managed team's full 53-player roster")
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	_check(loaded.league.data_source_id == career.league.data_source_id, "Serialization should preserve real-data provenance")
	_check(loaded.user_team().division == career.user_team().division, "Serialization should preserve source divisions")


func _test_round_robin_schedule() -> void:
	var teams := SampleLeague.create_teams()
	var schedule := ScheduleGenerator.round_robin(teams)
	_check(schedule.size() == 28, "An eight-team round robin should contain 28 games")
	var pairings: Dictionary = {}
	for week in range(1, 8):
		var appearances: Dictionary = {}
		var week_games := 0
		for matchup in schedule:
			if matchup.week != week:
				continue
			week_games += 1
			appearances[matchup.away_team_id] = int(appearances.get(matchup.away_team_id, 0)) + 1
			appearances[matchup.home_team_id] = int(appearances.get(matchup.home_team_id, 0)) + 1
			var ids: Array[String] = [matchup.away_team_id, matchup.home_team_id]
			ids.sort()
			pairings["%s|%s" % ids] = true
		_check(week_games == 4, "Week %d should contain four games" % week)
		for team in teams:
			_check(appearances.get(team.id, 0) == 1, "%s should play once in week %d" % [team.abbreviation, week])
	_check(pairings.size() == 28, "Every pair of teams should meet exactly once")


func _test_weekly_health_progression() -> void:
	var player := SampleLeague.create_teams()[0].player_at("QB")
	player.injure("Test injury", 1)
	player.recover_for_new_week()
	_check(not player.is_available(), "A one-week injury should keep a player out of the following game")
	player.advance_injury_week()
	_check(player.is_available(), "A one-week injury should clear after one missed game")


func _test_active_career_game_is_resumable() -> void:
	var career := CareerSession.new_career("austin_outlaws", 77119, LeagueCatalog.SOURCE_FICTIONAL)
	var first := career.begin_user_game()
	var resumed := career.begin_user_game()
	_check(first == resumed, "Starting an active career matchup again should resume the same game")
	career.simulate_current_week()
	_check(career.league.current_week == 1, "Simulate week should not replace an active user matchup")
	first.simulate_to_end()
	career.complete_user_game()
	_check(career.league.current_week == 2, "Completing a resumed user matchup should advance the season")


func _test_initial_contracts_and_cap_rules() -> void:
	var teams := SampleLeague.create_teams()
	for team in teams:
		_check(team.payroll() <= team.salary_cap, "%s should begin below the salary cap" % team.abbreviation)
		_check(team.cap_space() == team.salary_cap - team.payroll(), "%s cap space should reconcile" % team.abbreviation)
		_check(RosterValidator.validate_team(team).is_empty(), "%s should begin with a legal roster" % team.abbreviation)
		for player in team.players:
			_check(player.contract != null, "%s should begin under contract" % player.full_name)
			_check(player.contract.annual_salary > 0, "%s should have a positive salary" % player.full_name)


func _test_unified_player_generator() -> void:
	var first := PlayerGenerator.generate_replacement("QB", 2028, 7, 88117)
	var second := PlayerGenerator.generate_replacement("QB", 2028, 7, 88117)
	_check(JSON.stringify(first.to_dict()) == JSON.stringify(second.to_dict()), "The unified player generator should be deterministic for identical inputs")
	_check(first.archetype in ["Field General", "Dual Threat"], "Generated quarterbacks should receive a position-specific archetype")
	_check(first.height_inches >= 72 and first.weight_lbs >= 205, "Generated quarterbacks should receive position-appropriate measurements")
	_check(not first.college.is_empty() and not first.personality.is_empty(), "Generated players should receive background and personality data")
	var generated_ids: Dictionary = {}
	for position_name in TeamData.ROSTER_POSITIONS:
		var player := PlayerGenerator.generate_free_agent(position_name, 2028, 3, 44661)
		generated_ids[player.id] = true
		_check(player.position == position_name, "Generated player positions should match the requested profile")
		_check(player.potential >= player.overall and player.career_peak_overall == player.overall, "Generated players should begin with coherent potential and career-peak values")
	_check(generated_ids.size() == TeamData.ROSTER_POSITIONS.size(), "Generated player IDs should remain unique across position groups")
	var roster_player: PlayerData = SampleLeague.create_teams().front().players.front()
	_check(not roster_player.archetype.is_empty() and roster_player.height_inches > 0, "Initial rosters should use the unified generator metadata")
	_check(roster_player.original_team_id != "" and not roster_player.team_history.is_empty(), "Initial players should retain origin and team-history metadata")


func _test_free_agent_signing_and_release() -> void:
	var career := CareerSession.new_career("boston_sentinels", 88831, LeagueCatalog.SOURCE_FICTIONAL)
	var team := career.user_team()
	var free_agent: PlayerData = career.league.free_agents.front()
	var initial_roster_size := team.players.size()
	var initial_pool_size := career.league.free_agents.size()
	var rejection_threshold := TransactionService.minimum_offer_multiplier(career.league, team, free_agent)
	var rejected := career.sign_free_agent(free_agent.id, 3, rejection_threshold - 0.03)
	_check(not bool(rejected.get("ok", false)), "A below-market contract offer should be rejected")
	_check(career.league.free_agents.size() == initial_pool_size, "A rejected offer should leave the market unchanged")
	var offer := TransactionService.market_offer(career.league, team, free_agent, 3, 1.10)
	var result := career.sign_free_agent(free_agent.id, 3, 1.10)
	_check(bool(result.get("ok", false)), "A legal premium free-agent offer should be accepted")
	_check(team.players.size() == initial_roster_size + 1, "A signing should add one roster player")
	_check(career.league.free_agents.size() == initial_pool_size - 1, "A signing should remove one free agent")
	_check(team.player_by_id(free_agent.id).contract.total_value() == offer.total_value(), "The signed contract should match the negotiated offer")
	_check(team.depth_players(free_agent.position).front().id == free_agent.id, "A superior signing should enter the appropriate depth slot")
	_check(career.league.transactions.size() == 1, "A signing should create a transaction record")
	var post_signing_payroll := team.payroll()
	var release_result := career.release_player(free_agent.id)
	_check(bool(release_result.get("ok", false)), "A newly signed player should be releasable")
	_check(team.players.size() == initial_roster_size, "A release should restore the prior roster size")
	_check(career.league.free_agent_by_id(free_agent.id) != null, "A released player should return to free agency")
	_check(team.dead_cap > 0, "A guaranteed contract release should create dead cap")
	_check(team.payroll() < post_signing_payroll, "A release should lower current payroll despite dead cap")
	_check(career.league.transactions.size() == 2, "A release should create a second transaction record")
	var kicker: PlayerData = team.players_at("K").front()
	_check(not RosterValidator.release_error(team, kicker).is_empty(), "The last player at a required position should not be releasable")
	team.roster_limit = team.players.size()
	var blocked := career.sign_free_agent(career.league.free_agents.front().id, 2, 1.10)
	_check(not bool(blocked.get("ok", false)), "A full roster should reject another signing")


func _test_ai_roster_management() -> void:
	var career := CareerSession.new_career("miami_nightjars", 91913, LeagueCatalog.SOURCE_FICTIONAL)
	var user_roster_size := career.user_team().players.size()
	var move_count := TransactionService.run_ai_roster_moves(career.league)
	_check(move_count > 0, "AI clubs should make at least one useful free-agent move")
	_check(career.league.transactions.size() >= move_count, "AI moves should be recorded in transaction history")
	_check(career.user_team().players.size() == user_roster_size, "AI roster management should not alter the user's club")
	for team in career.league.teams:
		_check(team.payroll() <= team.salary_cap, "%s AI management should preserve cap legality" % team.abbreviation)
		_check(team.players.size() <= team.roster_limit, "%s AI management should preserve roster limits" % team.abbreviation)


func _test_trade_execution_and_draft_pick_ownership() -> void:
	var career := CareerSession.new_career("miami_nightjars", 450913, LeagueCatalog.SOURCE_FICTIONAL)
	var user_team := career.user_team()
	var partner: TeamData = career.league.teams[1] if career.league.teams[1].id != user_team.id else career.league.teams[2]
	_check(career.league.future_draft_picks.size() == career.league.teams.size() * DraftService.ROUNDS * TradeService.FUTURE_PICK_YEARS, "New careers should reserve three complete years of tradable draft capital")
	var user_player: PlayerData = user_team.players_at("WR").back()
	var partner_player: PlayerData = partner.players_at("WR").back()
	var user_pick := TradeService.future_pick_for(career.league, career.league.season_year + 1, 3, user_team.id)
	var partner_pick := TradeService.future_pick_for(career.league, career.league.season_year + 1, 4, partner.id)
	var user_dead_cap := user_team.dead_cap
	var result := TradeService.execute_trade(
		career.league,
		user_team.id,
		partner.id,
		[user_player.id],
		[partner_player.id],
		[user_pick.id],
		[partner_pick.id]
	)
	_check(bool(result.get("ok", false)) and bool(result.get("executed", false)), "A legal player-and-pick package should execute atomically")
	_check(user_team.player_by_id(partner_player.id) != null and partner.player_by_id(user_player.id) != null, "Traded players should move to their receiving clubs")
	_check(partner_player.team_history.back() == user_team.id and user_player.team_history.back() == partner.id, "Completed trades should extend each player's team history")
	_check(user_pick.owner_team_id == partner.id and partner_pick.owner_team_id == user_team.id, "Completed trades should transfer future draft-pick ownership")
	_check(user_team.dead_cap > user_dead_cap, "Trading a guaranteed contract should leave the sending club with dead cap")
	_check(career.league.trade_history.size() == 1 and career.league.transactions.size() == 2, "A completed trade should create permanent trade and transaction records")
	_check(user_team.depth_players("WR").has(partner_player), "A completed trade should rebuild the receiving depth chart")
	var prior_user_count := user_team.players.size()
	var invalid := TradeService.execute_trade(career.league, user_team.id, partner.id, ["missing_player"], [user_player.id], [], [])
	_check(not bool(invalid.get("ok", false)) and user_team.players.size() == prior_user_count, "An invalid trade should leave every roster unchanged")
	var draft := DraftService.create_draft(career.league)
	var transferred_draft_pick: DraftPickData
	for pick in draft.picks:
		if pick.original_team_id == user_team.id and pick.round_number == 3:
			transferred_draft_pick = pick
			break
	_check(transferred_draft_pick != null and transferred_draft_pick.owner_team_id == partner.id, "Draft creation should honor ownership transferred in the Trade Center")
	career.league.current_draft = draft
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	_check(loaded.league.trade_history.size() == 1, "Completed trade history should survive career serialization")
	var loaded_pick: DraftPickData
	for pick in loaded.league.current_draft.picks:
		if pick.original_team_id == user_team.id and pick.round_number == 3:
			loaded_pick = pick
			break
	_check(loaded_pick != null and loaded_pick.owner_team_id == partner.id, "Traded draft-pick ownership should survive career serialization")


func _test_trade_counteroffers_and_deadline() -> void:
	var career := CareerSession.new_career("boston_sentinels", 540027, LeagueCatalog.SOURCE_FICTIONAL)
	var user_team := career.user_team()
	var partner: TeamData = career.league.teams[1] if career.league.teams[1].id != user_team.id else career.league.teams[2]
	var discounted_pick := TradeService.future_pick_for(career.league, career.league.season_year + 2, 1, user_team.id)
	var premium_pick := TradeService.future_pick_for(career.league, career.league.season_year + 1, 1, partner.id)
	var low_pick := TradeService.future_pick_for(career.league, career.league.season_year + 2, 7, user_team.id)
	var rejected := career.submit_trade(partner.id, [], [], [low_pick.id], [premium_pick.id])
	_check(not bool(rejected.get("ok", false)) and str(rejected.get("status", "")) == TradeProposalData.STATUS_REJECTED, "A materially unbalanced offer should be rejected without changing ownership")
	_check(low_pick.owner_team_id == user_team.id and premium_pick.owner_team_id == partner.id, "A rejected offer must not mutate either package")
	var response := career.submit_trade(partner.id, [], [], [discounted_pick.id], [premium_pick.id])
	_check(bool(response.get("ok", false)) and str(response.get("status", "")) == TradeProposalData.STATUS_COUNTERED, "A near-value offer should produce a deterministic AI counteroffer")
	var counter: Dictionary = response.get("counter", {})
	_check(not counter.is_empty(), "An AI counteroffer should include a complete revised package")
	var accepted := career.accept_trade_counter(counter)
	_check(bool(accepted.get("executed", false)), "The managed club should be able to accept a still-valid AI counteroffer")
	career.league.current_week = TradeService.trade_deadline_week(career.league) + 1
	var closed := career.submit_trade(partner.id, [], [], [TradeService.picks_owned_by(career.league, user_team.id).front().id], [TradeService.picks_owned_by(career.league, partner.id).front().id])
	_check(not bool(closed.get("ok", false)) and str(closed.get("message", "")).contains("closed"), "In-season trades should be rejected after the configured deadline")


func _test_complete_career_season() -> void:
	var career := CareerSession.new_career("boston_sentinels", 555123, LeagueCatalog.SOURCE_FICTIONAL)
	var guard := 0
	while not career.league.is_offseason() and guard < 12:
		career.simulate_current_week()
		guard += 1
	_check(career.league.phase == LeagueState.PHASE_SEASON_REVIEW, "A career should advance from the championship into season review")
	_check(not career.league.champion_team_id.is_empty(), "A completed season should crown a champion")
	_check(career.league.season_history.size() == 1, "A completed season should create one history record")
	_check(career.league.latest_season_record().user_record == career.league.standing_for(career.league.user_team_id).record_label(), "Season history should preserve the managed club record")
	_check(career.league.schedule.size() == 29, "A season should add one championship matchup")
	for team in career.league.teams:
		_check(career.league.standing_for(team.id).games_played() == 7, "%s should have seven regular-season decisions" % team.abbreviation)
	var championship := career.league.matchups_for_week(LeagueState.CHAMPIONSHIP_WEEK)
	_check(championship.size() == 1 and championship.front().played, "The championship should be played")


func _test_offseason_extensions_and_expiration() -> void:
	var career := CareerSession.new_career("austin_outlaws", 200211, LeagueCatalog.SOURCE_FICTIONAL)
	var team := career.user_team()
	var renewed := team.players[0]
	var expired := team.players[1]
	renewed.contract = PlayerContract.new(4_000_000, 1, 1_000_000, 2026, "Starter")
	expired.contract = PlayerContract.new(2_000_000, 1, 400_000, 2026, "Rotation")
	_complete_season(career)
	_check(career.league.latest_season_record().season_year == 2026, "Season review should archive the completed year")
	var re_signing := career.advance_offseason()
	_check(bool(re_signing.get("ok", false)) and career.league.phase == LeagueState.PHASE_RE_SIGNING, "Season review should advance to re-signing")
	var extension := career.extend_player(renewed.id, 3, 1.10)
	_check(bool(extension.get("ok", false)), "An expiring player should accept a premium extension")
	_check(renewed.contract.signed_year == 2027 and renewed.contract.expiration_year() == 2029, "An extension should begin next year and retain a fixed expiration")
	var development := career.advance_offseason()
	_check(bool(development.get("ok", false)) and career.league.phase == LeagueState.PHASE_PLAYER_DEVELOPMENT, "Re-signing should finalize contracts and run development")
	_check(team.player_by_id(renewed.id) != null, "An extended player should remain on the roster")
	_check(career.league.free_agent_by_id(expired.id) != null, "An unextended player should reach free agency")
	_check(renewed.contract.years_remaining == 3 and renewed.contract.expiration_year() == 2029, "A future-starting extension should not lose a contract year early")
	_check(career.league.development_reports_for(team.id, 2027).size() == team.players.size(), "Development should produce one report per roster player")
	var retirement_review := career.advance_offseason()
	_check(bool(retirement_review.get("ok", false)) and career.league.phase == LeagueState.PHASE_RETIREMENTS, "Development should advance into the retirement report")
	var preparation := career.advance_offseason()
	_check(bool(preparation.get("ok", false)) and career.league.phase == LeagueState.PHASE_DRAFT_PREPARATION, "Development should advance into draft preparation")
	_check(career.league.current_draft != null, "Draft preparation should generate the incoming class")
	var draft_start := career.advance_offseason()
	_check(bool(draft_start.get("ok", false)) and career.league.phase == LeagueState.PHASE_DRAFT, "Draft preparation should advance to the live draft")
	_complete_draft(career)
	_make_user_roster_legal(career)
	var rollover := career.advance_offseason()
	_check(bool(rollover.get("ok", false)), "A legal roster should be able to begin the next league year")
	_check(career.league.season_year == 2027 and career.league.phase == LeagueState.PHASE_REGULAR_SEASON, "The new league year should reset the regular season")
	_check(career.league.schedule.size() == 28 and career.league.current_week == 1, "The new league year should generate a fresh week-one schedule")
	_check(team.dead_cap == 0, "Dead cap should expire at the new league year")


func _test_player_development_is_deterministic() -> void:
	var first := CareerSession.new_career("seattle_orcas", 310031, LeagueCatalog.SOURCE_FICTIONAL)
	_complete_season(first)
	first.advance_offseason()
	var second := CareerSession.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	first.advance_offseason()
	second.advance_offseason()
	var first_reports := first.league.development_reports_for(first.league.user_team_id, 2027)
	var second_reports := second.league.development_reports_for(second.league.user_team_id, 2027)
	_check(first_reports.size() == second_reports.size() and not first_reports.is_empty(), "Cloned careers should produce matching development report counts")
	if not first_reports.is_empty() and not second_reports.is_empty():
		_check(first_reports.front().player_id == second_reports.front().player_id, "Deterministic development should preserve report ordering")
		_check(first_reports.front().new_overall == second_reports.front().new_overall, "Identical career seeds should produce identical overall development")
		_check(first_reports.front().attribute_changes == second_reports.front().attribute_changes, "Identical career seeds should produce identical attribute development")
	var quarterback := PlayerData.new("curve", "Curve QB", "QB", 80, 80, 80, 80, 80, 30, 80, 90)
	var running_back := PlayerData.new("curve", "Curve RB", "RB", 80, 80, 80, 80, 80, 30, 80, 90)
	var quarterback_best_delta := -99
	var running_back_best_delta := -99
	for curve_seed in range(32):
		var quarterback_rng := RandomNumberGenerator.new()
		quarterback_rng.seed = curve_seed
		var running_back_rng := RandomNumberGenerator.new()
		running_back_rng.seed = curve_seed
		quarterback_best_delta = maxi(quarterback_best_delta, OffseasonService._development_delta(quarterback, quarterback_rng))
		running_back_best_delta = maxi(running_back_best_delta, OffseasonService._development_delta(running_back, running_back_rng))
	_check(quarterback_best_delta > running_back_best_delta, "Position-specific career curves should give quarterbacks a longer development window than running backs")


func _test_retirement_lifecycle_is_deterministic() -> void:
	var first := CareerSession.new_career("seattle_orcas", 71191, LeagueCatalog.SOURCE_FICTIONAL)
	var forced_player: PlayerData = first.user_team().players.front()
	forced_player.age = 44
	forced_player.career_peak_overall = forced_player.overall + 8
	var second := CareerSession.from_dict(JSON.parse_string(JSON.stringify(first.to_dict())))
	var first_result := RetirementService.process_offseason(first.league)
	var second_result := RetirementService.process_offseason(second.league)
	_check(int(first_result.get("retirements", 0)) == int(second_result.get("retirements", 0)), "Identical careers should produce the same retirement count")
	_check(JSON.stringify(first.league.retired_players.front().to_dict()) == JSON.stringify(second.league.retired_players.front().to_dict()), "Retirement archives should be deterministic for identical career seeds")
	var repeat := RetirementService.process_offseason(first.league)
	_check(int(repeat.get("retirements", -1)) == 0, "A retirement cycle should be idempotent within one league year")
	_check(first.league.last_retirement_year == 2027, "The league should record the completed retirement cycle")


func _test_retirement_archive_and_dead_cap() -> void:
	var career := CareerSession.new_career("austin_outlaws", 51337, LeagueCatalog.SOURCE_FICTIONAL)
	var team := career.user_team()
	var veteran: PlayerData = team.players.front()
	veteran.age = 50
	veteran.experience_years = 18
	veteran.career_peak_overall = veteran.overall + 5
	veteran.contract = PlayerContract.new(8_000_000, 2, 8_000_000, 2026, "Starter")
	var expected_penalty: int = veteran.contract.retirement_penalty()
	var result := RetirementService.process_offseason(career.league)
	_check(bool(result.get("ok", false)), "The retirement service should complete a league personnel cycle")
	_check(team.player_by_id(veteran.id) == null, "A retiring player should be removed from the active roster")
	_check(team.dead_cap >= expected_penalty, "A retirement should apply the remaining guaranteed-money charge")
	var archived: RetiredPlayerData
	for record in career.league.retired_players:
		if record.player_id == veteran.id:
			archived = record
			break
	_check(archived != null, "A retiring player should remain available in the permanent career archive")
	if archived != null:
		_check(archived.peak_overall == veteran.career_peak_overall and archived.dead_cap_charge == expected_penalty, "The archive should preserve career peak and financial impact")
		_check(archived.team_history == veteran.team_history and archived.reason != "", "The archive should preserve team history and a retirement explanation")
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	_check(loaded.league.retired_players.size() == career.league.retired_players.size(), "Retirement archives should survive career serialization")


func _test_draft_class_and_scouting() -> void:
	var first := DraftClassGenerator.generate(2027, 61027)
	var second := DraftClassGenerator.generate(2027, 61027)
	_check(first.size() == DraftClassGenerator.POSITION_POOL.size(), "Default draft classes should preserve the compact fixture size")
	_check(JSON.stringify(first.front().to_dict()) == JSON.stringify(second.front().to_dict()), "Draft generation should be deterministic for a season seed")
	var positions: Dictionary = {}
	for prospect in first:
		positions[prospect.position] = true
	_check(positions.size() == TeamData.ROSTER_POSITIONS.size(), "Draft classes should cover every roster position")
	var career := CareerSession.new_career("denver_summit", 61027, LeagueCatalog.SOURCE_FICTIONAL)
	_complete_season(career)
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	var draft: DraftStateData = career.league.current_draft
	_check(career.league.phase == LeagueState.PHASE_DRAFT_PREPARATION and draft != null, "The offseason should expose a dedicated scouting stage")
	var target: ProspectData = draft.prospects.front()
	var report: ScoutingReportData = draft.report_for(career.league.user_team_id, target.id)
	var original_width := report.overall_high - report.overall_low
	var original_points := draft.scouting_points_remaining
	var result := career.scout_prospect(target.id)
	_check(bool(result.get("ok", false)), "A targeted scouting assignment should advance an incomplete report")
	_check(report.confidence == 50 and report.overall_high - report.overall_low < original_width, "Targeted scouting should increase confidence and narrow the rating range")
	_check(draft.scouting_points_remaining == original_points - 1, "Targeted scouting should consume one assignment")
	career.toggle_draft_favorite(target.id)
	_check(draft.is_favorite(target.id), "Prospects should be addable to a persistent favorites board")
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	var loaded_report: ScoutingReportData = loaded.league.current_draft.report_for(loaded.league.user_team_id, target.id)
	_check(loaded_report.confidence == 50 and loaded.league.current_draft.is_favorite(target.id), "Scouting reports and favorites should survive serialization")
	career.advance_offseason()
	career.auto_pick_draft_selection()
	var mid_draft_index := career.league.current_draft.current_pick_index
	var mid_draft_loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	_check(mid_draft_loaded.league.phase == LeagueState.PHASE_DRAFT, "A save should restore the live draft phase")
	_check(mid_draft_loaded.league.current_draft.current_pick_index == mid_draft_index, "A save should restore the live pick clock and completed selections")


func _test_draft_order_and_pick_ownership() -> void:
	var career := CareerSession.new_career("chicago_foundry", 72611, LeagueCatalog.SOURCE_FICTIONAL)
	_complete_season(career)
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	var draft: DraftStateData = career.league.current_draft
	_check(draft.picks.size() == 56, "An eight-team, seven-round draft should contain 56 picks")
	for round_index in range(7):
		var final_pick: DraftPickData = draft.picks[round_index * career.league.teams.size() + career.league.teams.size() - 1]
		_check(final_pick.owner_team_id == career.league.champion_team_id, "The reigning champion should pick last in round %d" % (round_index + 1))
	for pick in draft.picks:
		_check(pick.owner_team_id == pick.original_team_id, "Initial pick ownership should preserve both original and current owner IDs")


func _test_complete_seven_round_draft() -> void:
	var career := CareerSession.new_career("boston_sentinels", 91817, LeagueCatalog.SOURCE_FICTIONAL)
	_complete_season(career)
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	var draft: DraftStateData = career.league.current_draft
	var free_agents_before := career.league.free_agents.size()
	var start := career.advance_offseason()
	_check(bool(start.get("ok", false)) and career.league.phase == LeagueState.PHASE_DRAFT, "Draft night should begin after preparation")
	_complete_draft(career)
	_check(career.league.phase == LeagueState.PHASE_ROSTER_DECISIONS and draft.is_complete(), "The final selection should advance the offseason into roster decisions")
	var undrafted_count := career.league.teams.size()
	_check(draft.current_pick_index == 56 and draft.available_prospects().size() == undrafted_count, "The draft should make 56 selections and retain the undrafted prospects")
	_check(career.league.free_agents.size() >= free_agents_before + undrafted_count, "Undrafted prospects should enter the free-agent market")
	for team in career.league.teams:
		var selections := draft.selections_for_team(team.id)
		_check(selections.size() == 7, "%s should make one selection in every round" % team.abbreviation)
		for pick in selections:
			var rookie := team.player_by_id(pick.selected_player_id)
			_check(rookie != null and rookie.contract != null, "Every drafted prospect should join the selecting roster on a rookie contract")
			if rookie != null and rookie.contract != null:
				_check(rookie.contract.role == "Rookie" and rookie.contract.signed_year == draft.draft_year, "Rookie contracts should use the draft-year salary scale")
				_check(rookie.draft_round == pick.round_number and rookie.draft_pick == pick.pick_in_round, "Drafted players should preserve their draft origin")
				_check(rookie.original_team_id == team.id and rookie.team_history.has(team.id), "Drafted players should begin a persistent team history")
		if team.id != career.league.user_team_id:
			_check(RosterValidator.validate_team(team).is_empty(), "%s should complete automated post-draft roster decisions" % team.abbreviation)
	_check(DraftService.team_draft_grade(draft, career.league.user_team_id) in ["A", "B", "C", "D"], "The managed club should receive a draft recap grade")


func _test_multi_season_career_loop() -> void:
	var career := CareerSession.new_career("miami_nightjars", 808017, LeagueCatalog.SOURCE_FICTIONAL)
	for season_index in range(3):
		_complete_season(career)
		_check(career.league.season_history.size() == season_index + 1, "Each completed season should add exactly one history record")
		career.advance_offseason()
		career.advance_offseason()
		career.advance_offseason()
		career.advance_offseason()
		career.advance_offseason()
		_complete_draft(career)
		_make_user_roster_legal(career)
		var rollover := career.advance_offseason()
		_check(bool(rollover.get("ok", false)), "Season %d should roll into a legal new league year" % (2026 + season_index))
		for team in career.league.teams:
			_check(RosterValidator.validate_team(team).is_empty(), "%s should begin season %d with a legal roster" % [team.abbreviation, career.league.season_year])
	_check(career.league.season_year == 2029, "Three completed offseasons should advance the career to 2029")
	_check(career.league.season_history.size() == 3, "Multi-season careers should retain complete season history")
	_check(career.league.draft_history.size() == 3, "Multi-season careers should retain complete draft history")
	_check(career.league.development_reports_for(career.league.user_team_id).size() > career.user_team().players.size(), "Development history should persist across multiple seasons")
	_check(career.league.last_retirement_year == 2029, "Multi-season careers should process one retirement cycle per new league year")


func _test_long_run_population_balance() -> void:
	var career := CareerSession.new_career("denver_summit", 99331, LeagueCatalog.SOURCE_FICTIONAL)
	for cycle in range(3):
		if cycle > 0:
			OffseasonService.develop_players(career.league)
		RetirementService.process_offseason(career.league)
		OffseasonService.ensure_replacement_market(career.league)
		_check(career.league.free_agents.size() <= RetirementService.MAX_FREE_AGENTS_BEFORE_DRAFT + TeamData.ROSTER_POSITIONS.size(), "The pre-draft free-agent pool should remain bounded in cycle %d" % (cycle + 1))
		career.league.current_draft = DraftService.create_draft(career.league)
		career.league.phase = LeagueState.PHASE_DRAFT_PREPARATION
		career.advance_offseason()
		_complete_draft(career)
		_make_user_roster_legal(career)
		var rollover := career.advance_offseason()
		_check(bool(rollover.get("ok", false)), "Population-balance cycle %d should begin with legal rosters" % (cycle + 1))
		_check(career.league.free_agents.size() <= RetirementService.MAX_FREE_AGENTS_BEFORE_DRAFT, "The finalized free-agent market should remain bounded in cycle %d" % (cycle + 1))
		for team in career.league.teams:
			_check(RosterValidator.validate_team(team).is_empty(), "%s should remain legal after population cycle %d" % [team.abbreviation, cycle + 1])
	_check(career.league.retired_players.size() > 0, "Long-running careers should build a permanent archive of completed careers")
	_check(career.league.season_year == 2029, "Three synthetic personnel cycles should advance the league calendar predictably")


func _test_career_serialization_round_trip() -> void:
	var career := CareerSession.new_career("seattle_orcas", 44001, LeagueCatalog.SOURCE_FICTIONAL)
	career.user_team().set_strategy({"run_tendency": 0.63, "coverage_preference": "Zone"})
	career.user_team().move_on_depth_chart("RB", career.user_team().depth_players("RB")[1].id, -1)
	career.simulate_current_week()
	var encoded := JSON.stringify(career.to_dict())
	var decoded: Dictionary = JSON.parse_string(encoded)
	var loaded := CareerSession.from_dict(decoded)
	_check(loaded.league.current_week == career.league.current_week, "Serialized career should retain its week")
	_check(loaded.user_team().id == career.user_team().id, "Serialized career should retain the managed team")
	_check(is_equal_approx(loaded.user_team().run_tendency, 0.63), "Serialized career should retain strategy")
	_check(loaded.user_team().coverage_preference == "Zone", "Serialized career should retain coverage preference")
	_check(loaded.user_team().player_at("RB").id == career.user_team().player_at("RB").id, "Serialized career should retain depth order")
	_check(loaded.league.recent_results().size() == 4, "Serialized career should retain weekly results")
	_check(loaded.league.free_agents.size() == career.league.free_agents.size(), "Serialized career should retain the free-agent market")
	_check(loaded.league.transactions.size() == career.league.transactions.size(), "Serialized career should retain transaction history")
	_check(loaded.user_team().players.front().contract != null, "Serialized career should retain player contracts")
	var original_stats := career.league.current_season_statistics()
	var loaded_stats := loaded.league.current_season_statistics()
	_check(loaded_stats != null and loaded_stats.game_books.size() == original_stats.game_books.size(), "Serialized careers should retain finalized game books")
	var user_team_stats := loaded_stats.team_stats_for(loaded.league.user_team_id)
	_check(user_team_stats != null and user_team_stats.value("games_played") == 1, "Serialized careers should retain team season totals")


func _test_save_repository_round_trip() -> void:
	var path := "user://gridiron_manager/career_test.json"
	var repository := SaveRepository.new(path)
	var career := CareerSession.new_career("miami_nightjars", 91234, LeagueCatalog.SOURCE_FICTIONAL)
	career.simulate_current_week()
	_check(repository.save_career(career), "Career repository should write a versioned save")
	_check(repository.has_save(), "Career repository should find the written save")
	var loaded := repository.load_career()
	_check(loaded != null, "Career repository should load its save")
	if loaded != null:
		_check(loaded.league.current_week == 2, "Loaded save should retain week advancement")
		_check(loaded.league.user_team_id == "miami_nightjars", "Loaded save should retain the managed club")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_version_one_save_migration() -> void:
	var path := "user://gridiron_manager/career_v1_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("denver_summit", 14771, LeagueCatalog.SOURCE_FICTIONAL)
	career.simulate_current_week()
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("free_agents")
	league_data.erase("transactions")
	for team_data: Dictionary in league_data["teams"]:
		team_data.erase("salary_cap")
		team_data.erase("roster_limit")
		team_data.erase("dead_cap")
		for player_data: Dictionary in team_data["players"]:
			player_data.erase("contract")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 1, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-one career should migrate successfully")
	if loaded != null:
		_check(loaded.league.current_week == 2, "Migrated careers should retain season progress")
		_check(loaded.league.free_agents.size() == TeamData.ROSTER_POSITIONS.size() * 2, "Migrated careers should receive the initial free-agent market")
		_check(loaded.user_team().roster_limit == 45, "Legacy careers should retain their original active-roster limit")
		_check(loaded.user_team().players.front().contract != null, "Migrated careers should receive player contracts")
		_check(RosterValidator.validate_team(loaded.user_team()).is_empty(), "Migrated careers should produce a legal roster")
	DirAccess.remove_absolute(absolute_path)


func _test_version_two_save_migration() -> void:
	var path := "user://gridiron_manager/career_v2_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("chicago_foundry", 51991, LeagueCatalog.SOURCE_FICTIONAL)
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("season_history")
	league_data.erase("development_reports")
	for team_data: Dictionary in league_data["teams"]:
		for player_data: Dictionary in team_data["players"]:
			player_data.erase("potential")
			var contract_data: Dictionary = player_data["contract"]
			contract_data.erase("expires_after_year")
	for player_data: Dictionary in league_data["free_agents"]:
		player_data.erase("potential")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 2, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-two career should migrate successfully")
	if loaded != null:
		var player: PlayerData = loaded.user_team().players.front()
		_check(player.potential >= player.overall, "Version-two players should receive deterministic potential")
		_check(player.contract.expiration_year() >= loaded.league.season_year, "Version-two contracts should receive a fixed expiration year")
		_check(loaded.league.season_history.is_empty() and loaded.league.development_reports.is_empty(), "Version-two careers should receive empty history collections")
	DirAccess.remove_absolute(absolute_path)


func _test_version_three_save_migration() -> void:
	var path := "user://gridiron_manager/career_v3_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("seattle_orcas", 77881, LeagueCatalog.SOURCE_FICTIONAL)
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("current_draft")
	league_data.erase("draft_history")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 3, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-three career should migrate successfully")
	if loaded != null:
		_check(loaded.league.current_draft == null and loaded.league.draft_history.is_empty(), "Version-three careers should receive empty draft state collections")
	DirAccess.remove_absolute(absolute_path)


func _test_version_four_save_migration() -> void:
	var path := "user://gridiron_manager/career_v4_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("boston_sentinels", 66109, LeagueCatalog.SOURCE_FICTIONAL)
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("retired_players")
	league_data.erase("last_retirement_year")
	for team_data: Dictionary in league_data["teams"]:
		for player_data: Dictionary in team_data["players"]:
			_remove_v5_player_fields(player_data)
	for player_data: Dictionary in league_data["free_agents"]:
		_remove_v5_player_fields(player_data)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 4, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-four career should migrate successfully")
	if loaded != null:
		var player: PlayerData = loaded.user_team().players.front()
		_check(not player.archetype.is_empty() and player.height_inches > 0 and player.weight_lbs > 0, "Version-four players should receive generated profile metadata")
		_check(player.experience_years >= 0 and player.entry_year <= loaded.league.season_year, "Version-four players should receive career timeline metadata")
		_check(player.original_team_id == loaded.user_team().id and player.team_history.has(loaded.user_team().id), "Version-four roster players should receive team-history metadata")
		_check(loaded.league.retired_players.is_empty() and loaded.league.last_retirement_year == 0, "Version-four careers should receive empty retirement state")
	DirAccess.remove_absolute(absolute_path)


func _test_version_five_save_migration() -> void:
	var path := "user://gridiron_manager/career_v5_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("austin_outlaws", 58121, LeagueCatalog.SOURCE_FICTIONAL)
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	for field_name in ["league_name", "data_source_id", "data_source_label", "data_snapshot", "data_attribution", "data_source_metadata"]:
		league_data.erase(field_name)
	for team_data: Dictionary in league_data["teams"]:
		team_data.erase("division")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 5, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-five career should migrate successfully")
	if loaded != null:
		_check(loaded.league.data_source_id == LeagueCatalog.SOURCE_FICTIONAL, "Version-five careers should default to the original league source")
		_check(loaded.league.league_name == "Gridiron League", "Version-five careers should receive a league identity")
		_check(loaded.league.data_source_metadata.get("id", "") == LeagueCatalog.SOURCE_FICTIONAL, "Version-five careers should receive an extensible source manifest")
		_check(loaded.user_team().division.is_empty(), "Version-five teams should receive an empty optional division")
		_check(loaded.league.league_format.id == "legacy_eight" and loaded.league.league_format.regular_season_weeks == 7, "Legacy careers should migrate into an explicit compatible league format")
	DirAccess.remove_absolute(absolute_path)


func _test_version_seven_trade_save_migration() -> void:
	var path := "user://gridiron_manager/career_v7_trade_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("denver_summit", 80771, LeagueCatalog.SOURCE_FICTIONAL)
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("future_draft_picks")
	league_data.erase("trade_history")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 7, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-seven career should migrate into the trade schema")
	if loaded != null:
		var expected_picks := loaded.league.teams.size() * DraftService.ROUNDS * TradeService.FUTURE_PICK_YEARS
		_check(loaded.league.future_draft_picks.size() == expected_picks, "Version-seven careers should receive three complete years of original draft-pick ownership")
		_check(loaded.league.trade_history.is_empty(), "Version-seven careers should begin with an empty trade history")
	DirAccess.remove_absolute(absolute_path)


func _test_version_eight_statistics_save_migration() -> void:
	var path := "user://gridiron_manager/career_v8_statistics_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("austin_outlaws", 80819, LeagueCatalog.SOURCE_FICTIONAL)
	career.simulate_current_week()
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	league_data.erase("statistics")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 8, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-eight career should migrate into the statistics schema")
	if loaded != null:
		_check(loaded.league.statistics.seasons.is_empty(), "Pre-statistics saves should start recording from their next completed game")
		_check(loaded.league.statistics.career_player_totals.is_empty(), "Migration should not invent historical player totals")
	DirAccess.remove_absolute(absolute_path)


func _test_version_nine_hybrid_ratings_save_migration() -> void:
	var path := "user://gridiron_manager/career_v9_hybrid_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("nfl_buf", 90903, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var source_player: PlayerData = career.user_team().players.front()
	var source_jersey := source_player.jersey_number
	var career_data := career.to_dict()
	var league_data: Dictionary = career_data["league"]
	var team_data: Dictionary
	for candidate: Dictionary in league_data["teams"]:
		if str(candidate.get("id", "")) == career.user_team().id:
			team_data = candidate
			break
	team_data.erase("logo_url")
	for player_data: Dictionary in team_data.get("players", []):
		if str(player_data.get("id", "")) == source_player.id:
			player_data.erase("madden_ratings")
			player_data.erase("jersey_number")
			break
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"save_version": 9, "career": career_data}))
	file.close()
	var repository := SaveRepository.new(path)
	var loaded := repository.load_career()
	_check(loaded != null, "A version-nine career should migrate into the hybrid ratings schema")
	if loaded != null:
		var restored := loaded.league.player_by_id(source_player.id)
		_check(restored != null and restored.madden_ratings.has_madden_source(), "A migrated player with a stable source ID should recover the real Madden profile")
		_check(restored != null and restored.madden_ratings.attributes.size() >= 54, "Hybrid save migration should restore the complete detailed attribute set")
		_check(restored != null and restored.jersey_number == source_jersey, "Hybrid save migration should restore the source jersey number")
		_check(loaded.user_team().logo_url.begins_with("https://"), "Hybrid save migration should restore the club's remote team-mark reference")
	DirAccess.remove_absolute(absolute_path)


func _remove_v5_player_fields(player_data: Dictionary) -> void:
	for field_name in ["archetype", "personality", "height_inches", "weight_lbs", "college", "experience_years", "entry_year", "draft_round", "draft_pick", "original_team_id", "team_history", "career_peak_overall", "seasons_as_free_agent", "generation_source"]:
		player_data.erase(field_name)


func _complete_season(career: CareerSession) -> void:
	var guard := 0
	while not career.league.is_offseason() and guard < career.league.league_format.regular_season_weeks + career.league.league_format.postseason_weeks + 2:
		career.simulate_current_week()
		guard += 1


func _complete_draft(career: CareerSession) -> void:
	var guard := 0
	while career.league.phase == LeagueState.PHASE_DRAFT and guard < 10:
		var result := career.auto_pick_draft_selection()
		_check(bool(result.get("ok", false)), "The managed club should be able to auto-pick from its scouted board")
		guard += 1
	_check(guard == 7, "A complete draft should require exactly seven managed-club selections")


func _make_user_roster_legal(career: CareerSession) -> void:
	var team := career.user_team()
	var release_guard := 0
	while (team.players.size() > team.roster_limit or team.cap_space() < 0) and release_guard < 80:
		var release_candidate: PlayerData
		var release_score := -9999.0
		for player in team.players:
			if team.players_at(player.position).size() <= 1:
				continue
			var salary := player.contract.annual_salary if player.contract != null else 0
			var penalty := player.contract.release_penalty() if player.contract != null else 0
			var score := float(100 - player.overall) + float(maxi(salary - penalty, 0)) / 1_000_000.0
			if release_candidate == null or score > release_score:
				release_candidate = player
				release_score = score
		if release_candidate == null:
			break
		var release_result := career.release_player(release_candidate.id)
		if not bool(release_result.get("ok", false)):
			break
		release_guard += 1
	for position_name in TeamData.ROSTER_POSITIONS:
		if not team.players_at(position_name).is_empty():
			continue
		var required_candidate: PlayerData
		var required_salary := 2_147_483_647
		for player in career.league.free_agents:
			if player.position != position_name:
				continue
			var offer := TransactionService.market_offer(career.league, team, player, 1, 1.10)
			if required_candidate == null or offer.annual_salary < required_salary:
				required_candidate = player
				required_salary = offer.annual_salary
		if required_candidate != null and not team.has_roster_space():
			var depth_release: PlayerData
			for roster_player in team.players:
				if team.players_at(roster_player.position).size() <= 1:
					continue
				if depth_release == null or roster_player.overall < depth_release.overall:
					depth_release = roster_player
			if depth_release != null:
				career.release_player(depth_release.id)
		var cap_guard := 0
		while required_candidate != null and required_salary > team.cap_space() and cap_guard < 10:
			var cap_release: PlayerData
			var best_savings := 0
			for roster_player in team.players:
				if team.players_at(roster_player.position).size() <= 1 or roster_player.contract == null:
					continue
				var savings := roster_player.contract.annual_salary - roster_player.contract.release_penalty()
				if savings > best_savings:
					cap_release = roster_player
					best_savings = savings
			if cap_release == null or not bool(career.release_player(cap_release.id).get("ok", false)):
				break
			cap_guard += 1
		if required_candidate != null:
			career.sign_free_agent(required_candidate.id, 1, 1.10)
	var guard := 0
	while team.players.size() < team.roster_limit and guard < 100:
		var candidate: PlayerData
		var candidate_salary := 0
		for player in career.league.free_agents:
			var offer := TransactionService.market_offer(career.league, team, player, 1, 1.10)
			if offer.annual_salary <= team.cap_space() and (candidate == null or offer.annual_salary < candidate_salary):
				candidate = player
				candidate_salary = offer.annual_salary
		var signed := false
		if candidate != null:
			var result := career.sign_free_agent(candidate.id, 1, 1.10)
			signed = bool(result.get("ok", false))
		if not signed:
			break
		guard += 1


func _position_count(players: Array[PlayerData], position_name: String) -> int:
	var count := 0
	for player in players:
		if player.position == position_name:
			count += 1
	return count


func _set_detailed_attributes(team: TeamData, value: int) -> void:
	for player in team.players:
		if player.madden_ratings == null:
			continue
		for attribute_name in player.madden_ratings.attributes:
			if str(attribute_name) != "overall":
				player.madden_ratings.attributes[attribute_name] = value


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
