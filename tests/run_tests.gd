extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	_test_seeded_games_are_deterministic()
	_test_games_reach_a_legal_final_state()
	_test_statistics_balance()
	_test_strategy_cloning_is_isolated()
	_test_full_rosters_and_depth_charts()
	_test_round_robin_schedule()
	_test_weekly_health_progression()
	_test_active_career_game_is_resumable()
	_test_initial_contracts_and_cap_rules()
	_test_free_agent_signing_and_release()
	_test_ai_roster_management()
	_test_complete_career_season()
	_test_career_serialization_round_trip()
	_test_save_repository_round_trip()
	_test_version_one_save_migration()

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


func _test_full_rosters_and_depth_charts() -> void:
	var teams := SampleLeague.create_teams()
	_check(teams.size() == 8, "The prototype league should contain eight teams")
	for team in teams:
		_check(team.players.size() == 41, "%s should have a 41-player prototype roster" % team.abbreviation)
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
	var career := CareerSession.new_career("austin_outlaws", 77119)
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


func _test_free_agent_signing_and_release() -> void:
	var career := CareerSession.new_career("boston_sentinels", 88831)
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
	var career := CareerSession.new_career("miami_nightjars", 91913)
	var user_roster_size := career.user_team().players.size()
	var move_count := TransactionService.run_ai_roster_moves(career.league)
	_check(move_count > 0, "AI clubs should make at least one useful free-agent move")
	_check(career.league.transactions.size() >= move_count, "AI moves should be recorded in transaction history")
	_check(career.user_team().players.size() == user_roster_size, "AI roster management should not alter the user's club")
	for team in career.league.teams:
		_check(team.payroll() <= team.salary_cap, "%s AI management should preserve cap legality" % team.abbreviation)
		_check(team.players.size() <= team.roster_limit, "%s AI management should preserve roster limits" % team.abbreviation)


func _test_complete_career_season() -> void:
	var career := CareerSession.new_career("boston_sentinels", 555123)
	var guard := 0
	while career.league.phase != "Complete" and guard < 12:
		career.simulate_current_week()
		guard += 1
	_check(career.league.phase == "Complete", "A career should advance through the championship")
	_check(not career.league.champion_team_id.is_empty(), "A completed season should crown a champion")
	_check(career.league.schedule.size() == 29, "A season should add one championship matchup")
	for team in career.league.teams:
		_check(career.league.standing_for(team.id).games_played() == 7, "%s should have seven regular-season decisions" % team.abbreviation)
	var championship := career.league.matchups_for_week(LeagueState.CHAMPIONSHIP_WEEK)
	_check(championship.size() == 1 and championship.front().played, "The championship should be played")


func _test_career_serialization_round_trip() -> void:
	var career := CareerSession.new_career("seattle_orcas", 44001)
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


func _test_save_repository_round_trip() -> void:
	var path := "user://gridiron_manager/career_test.json"
	var repository := SaveRepository.new(path)
	var career := CareerSession.new_career("miami_nightjars", 91234)
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
	var career := CareerSession.new_career("denver_summit", 14771)
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
		_check(loaded.league.free_agents.size() == 32, "Migrated careers should receive the initial free-agent market")
		_check(loaded.user_team().players.front().contract != null, "Migrated careers should receive player contracts")
		_check(RosterValidator.validate_team(loaded.user_team()).is_empty(), "Migrated careers should produce a legal roster")
	DirAccess.remove_absolute(absolute_path)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
