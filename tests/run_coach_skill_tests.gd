extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_and_unlocks()
	_test_ai_and_save()
	_test_gameplay_effects()
	_test_matched_snap_balance()
	_test_rewards_and_lifecycle()
	_test_postgame_integration()
	await _test_ui()
	if _failures.is_empty():
		print("PASS: %d coach progression assertions across every skill, seeded builds, gameplay effects, XP idempotence, save migration, and responsive UI." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _coach(background: String = "offense") -> CoachProgressData:
	var result := CoachProgressData.new()
	result.background = background
	result.xp = CoachProgressData.xp_for_level(CoachProgressData.MAX_LEVEL)
	return result


func _league(seed: int = 1783) -> LeagueState:
	var teams := SampleLeague.create_teams()
	var result := LeagueState.new(teams, teams[0].id, seed)
	result.schedule = ScheduleGenerator.round_robin(teams, result.season_year, seed)
	CoachProgressionService.initialize(result)
	return result


func _train_lane(coach: CoachProgressData, branch: String, lane: String) -> void:
	for skill in CoachSkillCatalog.skills():
		if skill["branch"] != branch or (int(skill["tier"]) >= 3 and skill["lane"] != lane):
			continue
		for rank_index in range(int(skill["max_rank"])):
			var result := CoachProgressionService.unlock(coach, str(skill["id"]))
			_check(bool(result["ok"]), "Legal investment must unlock " + str(skill["name"]) + ": " + str(result["message"]))


func _test_catalog_and_unlocks() -> void:
	_check(CoachSkillCatalog.skills().size() == 40, "The catalog must contain forty skills")
	var ids: Dictionary = {}
	for skill in CoachSkillCatalog.skills():
		_check(not ids.has(skill["id"]), "Skill IDs must be unique")
		ids[skill["id"]] = true
		_check(not CoachSkillCatalog.effect_text(skill).is_empty(), "Every skill must explain its effects")
		for required in skill["requires"]:
			_check(not CoachSkillCatalog.skill(str(required)).is_empty(), "All prerequisite IDs must exist")
		for effect in skill["effects"]:
			_check(not effect["values"].is_empty(), "Every skill must grant a real effect")
	var newcomer := CoachProgressData.new()
	_check(not CoachProgressionService.unlock(newcomer, "offense_ground_1")["ok"], "Background selection precedes purchases")
	_check(CoachProgressionService.choose_background(newcomer, "defense")["ok"], "A newcomer can choose any background")
	_check(CoachProgressionService.unlock(newcomer, "offense_ground_1")["ok"], "Background does not restrict other branches")
	_check(not CoachProgressionService.choose_background(newcomer, "offense")["ok"], "The first purchase makes background permanent")
	_check(not CoachProgressionService.unlock(newcomer, "offense_air_5")["ok"], "A signature cannot bypass prerequisites")
	_check(CoachProgressionService.available_points(newcomer) == 2, "Each purchase consumes its advertised cost")
	for branch in ["offense", "defense", "development", "management"]:
		var lanes: Array = []
		for skill in CoachSkillCatalog.skills():
			if skill["branch"] == branch and not lanes.has(skill["lane"]):
				lanes.append(skill["lane"])
		for lane in lanes:
			var coach := _coach()
			_train_lane(coach, branch, lane)
			_check(coach.rank_of("%s_%s_5" % [branch, lane]) == 1, "Every signature must be reachable")
			var other := str(lanes[1] if lane == lanes[0] else lanes[0])
			_check("Conflicts" in CoachProgressionService.unlock_error(coach, "%s_%s_3" % [branch, other]), "Opposing identities must be mutually exclusive")
			_check("Maximum" in CoachProgressionService.unlock_error(coach, "%s_%s_5" % [branch, lane]), "Signatures cannot be ranked twice")
			var before := coach.ranks.duplicate()
			CoachProgressionService.sanitize(coach)
			_check(coach.ranks == before, "Valid builds must survive sanitization unchanged")
	var veteran := _coach()
	for milestone in ["wins_10", "wins_25", "wins_50", "wins_100", "playoff_win", "championship"]:
		veteran.milestones[milestone] = true
	_check(veteran.earned_points() == 38, "The lifetime budget must cap at thirty-eight points")
	_train_lane(veteran, "offense", "air")
	_train_lane(veteran, "defense", "coverage")
	_check(CoachProgressionService.spent_points(veteran) == 30, "Two completed paths should leave room for supporting skills")


func _test_ai_and_save() -> void:
	var builds: Dictionary = {}
	for seed in range(12):
		var first := _coach(["offense", "defense", "development", "management"][seed % 4])
		var second := _coach(first.background)
		CoachProgressionService.spend_ai(first, seed + 180)
		CoachProgressionService.spend_ai(second, seed + 180)
		_check(first.ranks == second.ranks, "AI spending must be deterministic for equal seeds")
		_check(CoachProgressionService.spent_points(first) <= first.earned_points(), "AI must never overspend")
		var before := first.ranks.duplicate()
		CoachProgressionService.sanitize(first)
		_check(first.ranks == before, "AI must obey all prerequisite and specialization rules")
		builds[JSON.stringify(first.ranks)] = true
	_check(builds.size() >= 8, "Seeds and backgrounds must create diverse complete AI builds")
	var league := _league()
	var career := CareerSession.new(league)
	career.choose_coach_background("development")
	career.learn_coach_skill("development_youth_1")
	var loaded := CareerSession.from_dict(career.to_dict())
	_check(loaded.user_team().coach.to_dict() == career.user_team().coach.to_dict(), "A save roundtrip must preserve all coach state")
	var clone := career.user_team().clone_with_strategy({})
	clone.coach.ranks.clear()
	_check(career.user_team().coach.rank_of("development_youth_1") == 1, "Simulation cloning must isolate coach state")
	var payload := {"save_version": 15, "career": career.to_dict()}
	for team in payload["career"]["league"]["teams"]:
		team.erase("coach")
	var repository := SaveRepository.new("res://test-results/coach-save-test.json")
	var migrated: Dictionary = repository._migrate(payload, 15)
	_check(migrated["save_version"] == 16, "Schema fifteen must migrate to sixteen")
	var old_career := CareerSession.from_dict(migrated["career"])
	_check(old_career.user_team().coach.xp == 0 and CoachProgressionService.available_points(old_career.user_team().coach) == 3, "Old careers receive starting points without fabricated XP")
	var old_snapshot := old_career.to_dict()
	var reloaded := CareerSession.from_dict(old_snapshot)
	_check(reloaded.user_team().coach.to_dict() == old_career.user_team().coach.to_dict(), "Repeated loads must not reset progression or reroll objectives")
	_check(repository.save_career(career), "Coach state must save through the actual repository")
	_check(repository.load_career().user_team().coach.ranks == career.user_team().coach.ranks, "The actual save repository must restore learned ranks")
	var corrupted := _coach()
	corrupted.ranks = {"unknown": 100, "offense_air_5": 100, "offense_ground_1": -8}
	CoachProgressionService.sanitize(corrupted)
	_check(corrupted.ranks.is_empty(), "Unknown, negative, and prerequisite-bypassing ranks must not grant bonuses")


func _test_gameplay_effects() -> void:
	var teams := SampleLeague.create_teams()
	var offense := teams[0]
	var defense := teams[1]
	offense.coach = _coach()
	_train_lane(offense.coach, "offense", "ground")
	var state := GameStateData.new(defense, offense)
	var book := PlaybookCatalog.pro_style_offense()
	var defense_book := PlaybookCatalog.multiple_defense()
	var defensive_call: DefensiveCallData = defense_book.calls[0]
	var run: PlayDefinitionData
	var pass_play: PlayDefinitionData
	for play in book.plays:
		if play.play_type == "run" and run == null:
			run = play
		if play.has_tag("deep"):
			pass_play = play
	state.quarter = 4
	state.away_score = 21
	state.home_score = 7
	var leading := CoachEffectService.snap_modifiers(state, run, defensive_call)
	state.away_score = 0
	var trailing := CoachEffectService.snap_modifiers(state, run, defensive_call)
	_check(float(leading.get("yardage", 0)) > float(trailing.get("yardage", 0)), "Closer must activate only with a late lead")
	offense.coach = _coach()
	_train_lane(offense.coach, "offense", "air")
	var air := CoachEffectService.snap_modifiers(state, pass_play, defensive_call)
	_check(float(air.get("explosive", 0)) > 0 and float(air.get("interception", 0)) > 0, "Vertical builds must grant explosive upside with turnover risk")
	_check(CoachEffectService.recommendation_adjustment(state, pass_play) > 0, "Coaching strengths should change play recommendations")
	defense.coach = _coach("defense")
	_train_lane(defense.coach, "defense", "coverage")
	var covered := CoachEffectService.snap_modifiers(state, pass_play, defensive_call)
	_check(float(covered.get("explosive", 0)) < float(air.get("explosive", 0)), "A coverage build must counter explosive offense")
	for key in covered:
		_check(absf(float(covered[key])) <= float(CoachEffectService.SNAP_CAPS[key]), "Combined coaching modifiers must remain bounded")
	var empty_team := teams[2]
	_check(CoachEffectService.recovery_bonus(empty_team) == 0, "Teams without coaches must remain neutral")
	offense.coach = _coach("development")
	_train_lane(offense.coach, "development", "youth")
	var youngster := offense.player_at("QB")
	youngster.age = 22
	youngster.potential = 99
	var growth := 0
	for seed in range(100):
		growth += CoachEffectService.development_adjustment(offense, youngster, 0, seed)
	_check(growth > 25 and growth < 85, "Development perks should improve odds without guaranteeing growth")
	youngster.overall = youngster.potential
	_check(CoachEffectService.development_adjustment(offense, youngster, 0, 1) == 0, "Coaching must respect player potential")
	offense.coach = _coach("management")
	_train_lane(offense.coach, "management", "control")
	_check(CoachEffectService.preparation_budget(offense) == 7, "Film Room must grant exactly one preparation point")
	_check(CoachEffectService.value(offense, "field_goal", "special") > 0, "Special Teams School must affect field-goal accuracy")
	var first := FootballSimulator.new(offense, defense, 9182)
	var second := FootballSimulator.new(offense, defense, 9182)
	first.simulate_to_end()
	second.simulate_to_end()
	_check(first.state.summary_signature() == second.state.summary_signature(), "Coached full-game simulation must remain reproducible")
	var neutral_offense := offense.clone_with_strategy({})
	var neutral_defense := defense.clone_with_strategy({})
	neutral_offense.coach = null
	neutral_defense.coach = null
	var neutral := FootballSimulator.new(neutral_offense, neutral_defense, 9182)
	neutral.simulate_to_end()
	_check(first.state.summary_signature() != neutral.state.summary_signature(), "Distinct coach builds must change an actual seeded game")
	_check(first.state.play_history.any(func(play: PlayResult): return play.matchup_context.has("coaching")), "Resolved plays must retain their applied coaching contributions")


func _test_rewards_and_lifecycle() -> void:
	var league := _league(897)
	var user := league.user_team()
	user.coach.background = "offense"
	var matchup := league.current_user_matchup()
	var game := GameStateData.new(league.team_by_id(matchup.home_team_id), league.team_by_id(matchup.away_team_id))
	game.is_final = true
	game.add_score(user.id, 35)
	game.add_score(matchup.opponent_id(user.id), 14)
	CoachProgressionService.award_game(league, matchup, game)
	_check(user.coach.xp == 0, "Unrecorded games must not grant XP")
	matchup.played = true
	CoachProgressionService.award_game(league, matchup, game)
	var xp := user.coach.xp
	_check(xp == 100, "Game, win, and offensive-background XP should sum correctly")
	CoachProgressionService.award_game(league, matchup, game)
	_check(user.coach.xp == xp, "Recording the same game twice must not duplicate XP")
	var restored := CareerSession.from_dict(CareerSession.new(league).to_dict())
	CoachProgressionService.award_game(restored.league, matchup, game)
	_check(restored.user_team().coach.xp == xp, "Reward deduplication must survive save/load")
	user.coach.objective_id = "scoring"
	user.coach.objective_progress = 5
	for index in range(2):
		var next := MatchupData.new("reward_%d" % index, index + 2, matchup.away_team_id, matchup.home_team_id)
		next.played = true
		CoachProgressionService.award_game(league, next, game)
	_check(user.coach.objective_claimed and user.coach.xp == xp + 450, "An objective should pay once even when its condition recurs")
	CoachProgressionService.award_development(league, user, 10)
	var developed_xp := user.coach.xp
	CoachProgressionService.award_development(league, user, 10)
	_check(user.coach.xp == developed_xp, "Offseason development rewards must be idempotent")
	user.coach = _coach("management")
	_train_lane(user.coach, "management", "control")
	matchup.played = false
	var plan := GamePlanningService.current_user_plan(league)
	_check(plan.preparation_budget == 7, "Current weekly plans must inherit Film Room")
	var result := GamePlanningService.save_user_plan(league, "balanced", "balanced", 4, 3)
	_check(result["ok"], "Seven-point plans must save when Film Room is learned")
	var career := CareerSession.new(league)
	career.active_simulator = FootballSimulator.new(game.home_team, game.away_team, 81)
	var snapshot := user.coach.ranks.duplicate()
	_check(not career.learn_coach_skill("development_youth_1")["ok"] and user.coach.ranks == snapshot, "Active matches must lock coach purchases")
	career.active_simulator = null
	_check(not career.retrain_coach()["ok"], "In-season respecs must be rejected")
	league.phase = LeagueState.PHASE_SEASON_REVIEW
	_check(career.retrain_coach()["ok"], "Offseason retraining must refund the build")
	_check(user.coach.ranks.is_empty() and user.coach.background == "management", "Retraining preserves background and removes effects")
	_check(CoachEffectService.preparation_budget(user) == 6, "Respecs must invalidate cached effects")
	career.learn_coach_skill("management_control_1")
	_check(not career.retrain_coach()["ok"], "A second respec in the same offseason must be rejected")
	league.phase = LeagueState.PHASE_REGULAR_SEASON
	plan = GamePlanningService.current_user_plan(league)
	_check(plan.preparation_budget == 6 and plan.is_valid(), "Removing Film Room must normalize an existing plan without corrupting it")
	league.season_year += 1
	CoachProgressionService.ensure_objective(user.coach, league, user.id)
	_check(user.coach.objective_progress == 0 and not user.coach.objective_claimed, "New seasons must reset seasonal objectives while retaining career XP")


func _test_postgame_integration() -> void:
	var automatic := _league(788)
	var auto_matchup := automatic.current_user_matchup()
	var auto_game := LeagueSimulator.simulate_matchup(automatic, auto_matchup)
	_check(auto_game.is_final and auto_matchup.played, "Automatic simulation must record a completed game")
	_check(automatic.user_team().coach.xp >= 45, "Automatic simulation must award coach XP")
	var manual := _league(788)
	var manual_matchup := manual.current_user_matchup()
	var simulator := FootballSimulator.new(manual.team_by_id(manual_matchup.home_team_id), manual.team_by_id(manual_matchup.away_team_id), 887)
	simulator.simulate_to_end()
	LeagueSimulator.process_played_matchup(manual, manual_matchup, simulator.state)
	var xp := manual.user_team().coach.xp
	_check(xp >= 45 and manual_matchup.played, "Interactive postgame processing must award coach XP")
	var energy := manual.user_team().players[0].energy
	LeagueSimulator.process_played_matchup(manual, manual_matchup, simulator.state)
	_check(manual.user_team().coach.xp == xp and manual.user_team().players[0].energy == energy, "Repeated interactive postgame processing must not duplicate progression or fatigue")


func _test_matched_snap_balance() -> void:
	var teams := SampleLeague.create_teams()
	var coached := teams[0]
	coached.coach = _coach()
	_train_lane(coached.coach, "offense", "ground")
	var neutral := coached.clone_with_strategy({})
	neutral.coach = null
	var coached_yards := 0
	var neutral_yards := 0
	for seed in range(128):
		var first := FootballSimulator.new(coached, teams[1], seed + 40800)
		var second := FootballSimulator.new(neutral, teams[1], seed + 40800)
		first.state.possession_team_id = coached.id
		second.state.possession_team_id = neutral.id
		coached_yards += first.simulate_called_play("inside_zone").yards
		neutral_yards += second.simulate_called_play("inside_zone").yards
	var difference := float(coached_yards - neutral_yards) / 128.0
	_check(difference > 0.3 and difference < 1.6, "A developed ground identity must improve matched runs within the coaching yardage bounds")
	print("Coach balance: ground build adds %.2f yards per matched inside-zone snap across 128 seeds." % difference)


func _test_ui() -> void:
	var career := CareerSession.new(_league())
	var scene: PackedScene = load("res://scenes/screens/coach_skills_screen.tscn")
	var screen := scene.instantiate()
	screen.setup(career)
	screen.theme = GridironTheme.build()
	root.add_child(screen)
	await process_frame
	_check(screen._tree.skill_nodes.size() == 10, "Each branch should show its complete ten-node tree")
	screen.size = Vector2(540, 900)
	screen._apply_responsive_layout()
	await process_frame
	_check(screen._tree.columns == 1 and screen._body.columns == 1, "Narrow screens must stack the tree and detail panels")
	_check(screen._body.get_child(0) == screen._detail_card, "Compact screens must put the purchase inspector before the long skill tree")
	screen._choose_background("offense")
	screen._select_skill("offense_ground_1")
	_check(not screen._buy_button.disabled, "An available root should be purchasable after background selection")
	var changes := [0]
	screen.coach_changed.connect(func(): changes[0] += 1)
	screen._buy_button.pressed.emit()
	_check(career.user_team().coach.rank_of("offense_ground_1") == 1 and changes[0] == 1, "Purchases should update career state and request saving exactly once")
	screen.size = Vector2(1440, 900)
	screen._apply_responsive_layout()
	await process_frame
	_check(screen._tree.columns == 2 and screen._body.columns == 2, "Wide screens must show connected paths beside their detail panel")
	_check(screen._body.get_child(0) != screen._detail_card, "Wide screens must restore the tree beside the inspector")
	screen._viewed_team = career.league.teams[1]
	screen._rebuild()
	_check(screen._buy_button.disabled, "Opposing coaches must be read-only")
	screen.queue_free()
	await process_frame
