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
	_test_offseason_extensions_and_expiration()
	_test_player_development_is_deterministic()
	_test_draft_class_and_scouting()
	_test_draft_order_and_pick_ownership()
	_test_complete_seven_round_draft()
	_test_multi_season_career_loop()
	_test_career_serialization_round_trip()
	_test_save_repository_round_trip()
	_test_version_one_save_migration()
	_test_version_two_save_migration()
	_test_version_three_save_migration()

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
	var career := CareerSession.new_career("austin_outlaws", 200211)
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
	var first := CareerSession.new_career("seattle_orcas", 310031)
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


func _test_draft_class_and_scouting() -> void:
	var first := DraftClassGenerator.generate(2027, 61027)
	var second := DraftClassGenerator.generate(2027, 61027)
	_check(first.size() == 86, "Each draft class should provide enough prospects for seven rounds and priority free agents")
	_check(JSON.stringify(first.front().to_dict()) == JSON.stringify(second.front().to_dict()), "Draft generation should be deterministic for a season seed")
	var positions: Dictionary = {}
	for prospect in first:
		positions[prospect.position] = true
	_check(positions.size() == TeamData.ROSTER_POSITIONS.size(), "Draft classes should cover every roster position")
	var career := CareerSession.new_career("denver_summit", 61027)
	_complete_season(career)
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
	var career := CareerSession.new_career("chicago_foundry", 72611)
	_complete_season(career)
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
	var career := CareerSession.new_career("boston_sentinels", 91817)
	_complete_season(career)
	career.advance_offseason()
	career.advance_offseason()
	career.advance_offseason()
	var draft: DraftStateData = career.league.current_draft
	var free_agents_before := career.league.free_agents.size()
	var start := career.advance_offseason()
	_check(bool(start.get("ok", false)) and career.league.phase == LeagueState.PHASE_DRAFT, "Draft night should begin after preparation")
	_complete_draft(career)
	_check(career.league.phase == LeagueState.PHASE_ROSTER_DECISIONS and draft.is_complete(), "The final selection should advance the offseason into roster decisions")
	_check(draft.current_pick_index == 56 and draft.available_prospects().size() == 30, "The draft should make 56 selections and retain 30 undrafted prospects")
	_check(career.league.free_agents.size() >= free_agents_before + 30, "Undrafted prospects should enter the free-agent market")
	for team in career.league.teams:
		var selections := draft.selections_for_team(team.id)
		_check(selections.size() == 7, "%s should make one selection in every round" % team.abbreviation)
		for pick in selections:
			var rookie := team.player_by_id(pick.selected_player_id)
			_check(rookie != null and rookie.contract != null, "Every drafted prospect should join the selecting roster on a rookie contract")
			if rookie != null and rookie.contract != null:
				_check(rookie.contract.role == "Rookie" and rookie.contract.signed_year == draft.draft_year, "Rookie contracts should use the draft-year salary scale")
		if team.id != career.league.user_team_id:
			_check(RosterValidator.validate_team(team).is_empty(), "%s should complete automated post-draft roster decisions" % team.abbreviation)
	_check(DraftService.team_draft_grade(draft, career.league.user_team_id) in ["A", "B", "C", "D"], "The managed club should receive a draft recap grade")


func _test_multi_season_career_loop() -> void:
	var career := CareerSession.new_career("miami_nightjars", 808017)
	for season_index in range(3):
		_complete_season(career)
		_check(career.league.season_history.size() == season_index + 1, "Each completed season should add exactly one history record")
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


func _test_version_two_save_migration() -> void:
	var path := "user://gridiron_manager/career_v2_test.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var career := CareerSession.new_career("chicago_foundry", 51991)
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
	var career := CareerSession.new_career("seattle_orcas", 77881)
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


func _complete_season(career: CareerSession) -> void:
	var guard := 0
	while not career.league.is_offseason() and guard < 12:
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
		var required_salary := 0
		for player in career.league.free_agents:
			if player.position != position_name:
				continue
			var offer := TransactionService.market_offer(career.league, team, player, 1, 1.10)
			if offer.annual_salary <= team.cap_space() and (required_candidate == null or offer.annual_salary < required_salary):
				required_candidate = player
				required_salary = offer.annual_salary
		if required_candidate != null:
			career.sign_free_agent(required_candidate.id, 1, 1.10)
	var guard := 0
	while team.players.size() < TeamData.MIN_ROSTER_SIZE and guard < 80:
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


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
