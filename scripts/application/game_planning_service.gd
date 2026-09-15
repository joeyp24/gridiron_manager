class_name GamePlanningService
extends RefCounted

const RECENT_GAMES_LIMIT := 4


static func ensure_weekly_plans(league: LeagueState) -> void:
	if league == null or league.is_offseason():
		return
	for matchup in league.matchups_for_week(league.current_week):
		for team_id in [matchup.away_team_id, matchup.home_team_id]:
			plan_for_matchup(league, matchup, team_id, true)


static func current_user_plan(league: LeagueState) -> WeeklyGamePlanData:
	if league == null:
		return null
	var matchup := league.current_user_matchup()
	return plan_for_matchup(league, matchup, league.user_team_id, true) if matchup != null else null


static func plan_for_matchup(
	league: LeagueState,
	matchup: MatchupData,
	team_id: String,
	create_if_missing: bool = false
) -> WeeklyGamePlanData:
	if league == null or matchup == null or not matchup.includes(team_id):
		return null
	var key := plan_key(league.season_year, matchup.week, matchup.id, team_id)
	var existing: WeeklyGamePlanData = league.weekly_game_plans.get(key)
	if existing != null or not create_if_missing:
		return existing
	var opponent_id := matchup.opponent_id(team_id)
	var report := build_report(league, opponent_id, team_id, matchup.week)
	var plan := WeeklyGamePlanData.new(league.season_year, matchup.week, matchup.id, team_id, opponent_id)
	plan.created_from_games = report.games_analyzed
	plan.scouting_confidence = report.confidence
	plan.ai_controlled = team_id != league.user_team_id
	if plan.ai_controlled:
		_configure_ai_plan(plan, league.team_by_id(team_id), league.team_by_id(opponent_id), report)
	league.weekly_game_plans[key] = plan
	return plan


static func save_user_plan(
	league: LeagueState,
	offensive_focus: String,
	defensive_focus: String,
	offensive_points: int,
	defensive_points: int
) -> Dictionary:
	if league == null or league.is_offseason():
		return _failure("Weekly preparation is only available during the season.")
	var matchup := league.current_user_matchup()
	if matchup == null:
		return _failure("There is no managed-club matchup to prepare for this week.")
	if matchup.played:
		return _failure("This matchup has already been completed.")
	var plan := plan_for_matchup(league, matchup, league.user_team_id, true)
	var candidate := WeeklyGamePlanData.from_dict(plan.to_dict())
	candidate.offensive_focus = offensive_focus
	candidate.defensive_focus = defensive_focus
	candidate.offensive_points = offensive_points
	candidate.defensive_points = defensive_points
	var error := candidate.validation_error()
	if not error.is_empty():
		return _failure(error)
	plan.offensive_focus = candidate.offensive_focus
	plan.defensive_focus = candidate.defensive_focus
	plan.offensive_points = candidate.offensive_points
	plan.defensive_points = candidate.defensive_points
	var report := build_report(league, plan.opponent_id, plan.team_id, matchup.week)
	plan.created_from_games = report.games_analyzed
	plan.scouting_confidence = report.confidence
	plan.ai_controlled = false
	return {
		"ok": true,
		"message": "Weekly game plan saved: %s." % plan.summary(),
		"plan": plan,
	}


static func build_report(
	league: LeagueState,
	opponent_id: String,
	viewer_team_id: String = "",
	before_week: int = 0
) -> OpponentScoutingReportData:
	var report := OpponentScoutingReportData.new()
	if league == null:
		return report
	report.season_year = league.season_year
	report.week = league.current_week if before_week <= 0 else before_week
	report.viewer_team_id = viewer_team_id
	report.opponent_team_id = opponent_id
	var opponent := league.team_by_id(opponent_id)
	if opponent == null:
		return report

	var books := _recent_books(league, opponent_id, report.week)
	report.games_analyzed = books.size()
	report.confidence = 25 if books.is_empty() else clampi(34 + books.size() * 15, 34, 94)
	var run_calls := 0
	var pass_calls := 0
	var quick_calls := 0
	var deep_calls := 0
	var blitz_calls := 0
	var points_for := 0
	var yards_for := 0
	var points_allowed := 0
	var yards_allowed := 0
	var personnel_counts: Dictionary = {}
	var offensive_call_counts: Dictionary = {}
	var offensive_call_names: Dictionary = {}
	var defensive_call_counts: Dictionary = {}
	var defensive_call_names: Dictionary = {}
	var coverage_counts: Dictionary = {}

	for book: GameBookData in books:
		var opponent_line := book.team_line(opponent_id)
		var other_id := book.home_team_id if opponent_id == book.away_team_id else book.away_team_id
		var other_line := book.team_line(other_id)
		if opponent_line != null:
			points_for += opponent_line.value("points")
			yards_for += opponent_line.value("total_yards")
		if other_line != null:
			points_allowed += other_line.value("points")
			yards_allowed += other_line.value("total_yards")
		for call_value in book.play_calls:
			var call := Dictionary(call_value)
			if str(call.get("offense_id", "")) == opponent_id:
				var play_type := _ledger_play_type(call)
				if play_type in ["run", "pass", "sack"]:
					report.offensive_snaps += 1
					var personnel := str(call.get("offensive_call_personnel", "11"))
					_increment(personnel_counts, personnel)
					var call_id := str(call.get("offensive_call_id", ""))
					if not call_id.is_empty():
						_increment(offensive_call_counts, call_id)
						offensive_call_names[call_id] = str(call.get("offensive_call_name", call_id))
				if play_type == "run":
					run_calls += 1
				elif play_type in ["pass", "sack"]:
					pass_calls += 1
					var tags := _ledger_offensive_tags(call)
					quick_calls += 1 if tags.has("quick") or tags.has("screen") else 0
					deep_calls += 1 if tags.has("deep") else 0
			if str(call.get("defense_id", "")) == opponent_id:
				report.defensive_snaps += 1
				var defensive_id := str(call.get("defensive_call_id", ""))
				if not defensive_id.is_empty():
					_increment(defensive_call_counts, defensive_id)
					defensive_call_names[defensive_id] = str(call.get("defensive_call_name", defensive_id))
				var coverage := str(call.get("defensive_call_coverage", "Balanced"))
				_increment(coverage_counts, coverage)
				var defensive_tags := Array(call.get("defensive_call_tags", []))
				if int(call.get("defensive_call_rusher_count", 4)) >= 5 or defensive_tags.has("blitz") or defensive_tags.has("zone_blitz"):
					blitz_calls += 1

	var game_count := maxi(books.size(), 1)
	report.points_per_game = float(points_for) / float(game_count)
	report.yards_per_game = float(yards_for) / float(game_count)
	report.points_allowed_per_game = float(points_allowed) / float(game_count)
	report.yards_allowed_per_game = float(yards_allowed) / float(game_count)
	report.run_rate = float(run_calls) / float(maxi(run_calls + pass_calls, 1)) if not books.is_empty() else opponent.run_tendency
	report.quick_pass_rate = float(quick_calls) / float(maxi(pass_calls, 1))
	report.deep_pass_rate = float(deep_calls) / float(maxi(pass_calls, 1))
	report.blitz_rate = float(blitz_calls) / float(maxi(report.defensive_snaps, 1)) if not books.is_empty() else opponent.blitz_rate
	report.favorite_personnel = _most_used_key(personnel_counts, "11")
	var favorite_offensive_id := _most_used_key(offensive_call_counts)
	report.favorite_offensive_call = str(offensive_call_names.get(favorite_offensive_id, "Insufficient film"))
	var favorite_defensive_id := _most_used_key(defensive_call_counts)
	report.favorite_defensive_call = str(defensive_call_names.get(favorite_defensive_id, "Insufficient film"))
	report.preferred_coverage = _most_used_key(coverage_counts, opponent.coverage_preference)
	_populate_personnel_intel(report, opponent)
	_populate_performance_intel(report, opponent, not books.is_empty())
	_populate_matchup_intel(report, league.team_by_id(viewer_team_id), opponent)
	return report


static func snap_modifiers(
	play: PlayDefinitionData,
	offensive_plan: WeeklyGamePlanData,
	defensive_plan: WeeklyGamePlanData
) -> Dictionary:
	var modifiers := {
		"yardage": 0.0,
		"completion": 0.0,
		"sack": 0.0,
		"interception": 0.0,
		"fumble": 0.0,
		"explosive": 0.0,
	}
	if play == null:
		return modifiers
	if offensive_plan != null:
		var strength := float(offensive_plan.offensive_points)
		match offensive_plan.offensive_focus:
			WeeklyGamePlanData.OFFENSE_GROUND:
				if play.play_type == "run":
					modifiers["yardage"] += 0.16 * strength
			WeeklyGamePlanData.OFFENSE_QUICK:
				if play.play_type == "pass" and (play.has_tag("quick") or play.has_tag("screen")):
					modifiers["completion"] += 0.006 * strength
					modifiers["sack"] -= 0.003 * strength
				if play.has_tag("deep"):
					modifiers["yardage"] -= 0.12 * strength
			WeeklyGamePlanData.OFFENSE_VERTICAL:
				if play.play_type == "pass" and play.has_tag("deep"):
					modifiers["yardage"] += 0.34 * strength
					modifiers["explosive"] += 0.006 * strength
					modifiers["completion"] -= 0.002 * strength
					modifiers["interception"] += 0.0007 * strength
			WeeklyGamePlanData.OFFENSE_PROTECTION:
				if play.play_type == "pass":
					modifiers["sack"] -= 0.004 * strength
					modifiers["completion"] += 0.002 * strength
			_:
				modifiers["yardage"] += 0.025 * strength

	if defensive_plan != null:
		var strength := float(defensive_plan.defensive_points)
		match defensive_plan.defensive_focus:
			WeeklyGamePlanData.DEFENSE_RUN:
				if play.play_type == "run":
					modifiers["yardage"] -= 0.17 * strength
					modifiers["fumble"] += 0.0004 * strength
			WeeklyGamePlanData.DEFENSE_EXPLOSIVES:
				if play.play_type == "pass":
					modifiers["explosive"] -= 0.007 * strength
					if play.has_tag("deep"):
						modifiers["yardage"] -= 0.30 * strength
					modifiers["completion"] += 0.0015 * strength
			WeeklyGamePlanData.DEFENSE_PRESSURE:
				if play.play_type == "pass":
					modifiers["sack"] += 0.0045 * strength
					modifiers["interception"] += 0.0008 * strength
					modifiers["explosive"] += 0.004 * strength
			WeeklyGamePlanData.DEFENSE_SPY:
				if play.play_type == "run" and play.runner_position == "QB":
					modifiers["yardage"] -= 0.42 * strength
				if play.play_type == "pass":
					modifiers["sack"] -= 0.001 * strength
			_:
				modifiers["yardage"] -= 0.025 * strength
	return modifiers


static func offensive_recommendation_adjustment(play: PlayDefinitionData, plan: WeeklyGamePlanData) -> float:
	if play == null or plan == null:
		return 0.0
	var weight := float(plan.offensive_points) * 2.6
	match plan.offensive_focus:
		WeeklyGamePlanData.OFFENSE_GROUND:
			return weight if play.play_type == "run" else -weight * 0.35
		WeeklyGamePlanData.OFFENSE_QUICK:
			return weight if play.has_tag("quick") or play.has_tag("screen") else (-weight * 0.35 if play.has_tag("deep") else 0.0)
		WeeklyGamePlanData.OFFENSE_VERTICAL:
			return weight if play.has_tag("deep") else 0.0
		WeeklyGamePlanData.OFFENSE_PROTECTION:
			return weight if play.has_tag("max_protect") or play.has_tag("quick") else 0.0
	return 0.0


static func defensive_recommendation_adjustment(call: DefensiveCallData, plan: WeeklyGamePlanData) -> float:
	if call == null or plan == null:
		return 0.0
	var weight := float(plan.defensive_points) * 2.6
	match plan.defensive_focus:
		WeeklyGamePlanData.DEFENSE_RUN:
			return weight if call.has_tag("run_commit") or call.category == "Base" else 0.0
		WeeklyGamePlanData.DEFENSE_EXPLOSIVES:
			return weight if call.has_tag("prevent") or call.shell in ["Quarters", "Cover 6"] else 0.0
		WeeklyGamePlanData.DEFENSE_PRESSURE:
			return weight if call.has_tag("blitz") or call.has_tag("simulated_pressure") else 0.0
		WeeklyGamePlanData.DEFENSE_SPY:
			return weight if call.has_tag("spy") else 0.0
	return 0.0


static func effect_lines(plan: WeeklyGamePlanData) -> Array[String]:
	var lines: Array[String] = []
	if plan == null:
		return lines
	lines.append("%s · %d offensive preparation point%s" % [plan.offense_label(), plan.offensive_points, "" if plan.offensive_points == 1 else "s"])
	lines.append("%s · %d defensive preparation point%s" % [plan.defense_label(), plan.defensive_points, "" if plan.defensive_points == 1 else "s"])
	lines.append(WeeklyGamePlanData.offensive_focus_description(plan.offensive_focus))
	lines.append(WeeklyGamePlanData.defensive_focus_description(plan.defensive_focus))
	return lines


static func plan_key(season_year: int, week: int, matchup_id: String, team_id: String) -> String:
	return "%d:%d:%s:%s" % [season_year, week, matchup_id, team_id]


static func _recent_books(league: LeagueState, team_id: String, before_week: int) -> Array[GameBookData]:
	var result: Array[GameBookData] = []
	var season := league.statistics.season(league.season_year)
	if season == null:
		return result
	for matchup_id in season.game_books:
		var book: GameBookData = season.game_books[matchup_id]
		if book.week >= before_week or (book.away_team_id != team_id and book.home_team_id != team_id):
			continue
		result.append(book)
	result.sort_custom(func(a: GameBookData, b: GameBookData):
		if a.week != b.week:
			return a.week > b.week
		return a.matchup_id < b.matchup_id
	)
	if result.size() > RECENT_GAMES_LIMIT:
		result.resize(RECENT_GAMES_LIMIT)
	return result


static func _ledger_play_type(call: Dictionary) -> String:
	var stored := str(call.get("play_type", ""))
	if not stored.is_empty():
		return stored
	var definition := PlaybookCatalog.pro_style_offense().play_by_id(str(call.get("offensive_call_id", "")))
	return definition.play_type if definition != null else ""


static func _ledger_offensive_tags(call: Dictionary) -> Array:
	var stored := Array(call.get("offensive_call_tags", []))
	if not stored.is_empty():
		return stored
	var definition := PlaybookCatalog.pro_style_offense().play_by_id(str(call.get("offensive_call_id", "")))
	return definition.tags if definition != null else []


static func _configure_ai_plan(
	plan: WeeklyGamePlanData,
	team: TeamData,
	opponent: TeamData,
	report: OpponentScoutingReportData
) -> void:
	if team == null or opponent == null:
		return
	var offense_edge := team.effective_offense_rating() - opponent.effective_defense_rating()
	var defense_edge := team.effective_defense_rating() - opponent.effective_offense_rating()
	if offense_edge >= defense_edge + 4:
		plan.offensive_points = 4
		plan.defensive_points = 2
	elif defense_edge >= offense_edge + 4:
		plan.offensive_points = 2
		plan.defensive_points = 4
	else:
		plan.offensive_points = 3
		plan.defensive_points = 3

	var opponent_front := _unit_rating(opponent, ["DT", "EDGE", "LB"])
	var opponent_secondary := _unit_rating(opponent, ["CB", "S"])
	if report.blitz_rate >= 0.52:
		plan.offensive_focus = WeeklyGamePlanData.OFFENSE_PROTECTION
	elif opponent_front + 3 < opponent_secondary:
		plan.offensive_focus = WeeklyGamePlanData.OFFENSE_GROUND
	elif opponent_secondary + 3 < opponent_front:
		plan.offensive_focus = WeeklyGamePlanData.OFFENSE_VERTICAL
	else:
		plan.offensive_focus = WeeklyGamePlanData.OFFENSE_QUICK if team.passing_depth <= 0.48 else WeeklyGamePlanData.OFFENSE_BALANCED

	var quarterback := opponent.player_at("QB")
	var quarterback_mobility := AttributeMatchupService.weighted_rating(quarterback, {
		"speed": 0.40, "acceleration": 0.25, "agility": 0.20, "breakSack": 0.15,
	}) if quarterback != null else 50.0
	if quarterback_mobility >= 84.0:
		plan.defensive_focus = WeeklyGamePlanData.DEFENSE_SPY
	elif report.run_rate >= 0.55:
		plan.defensive_focus = WeeklyGamePlanData.DEFENSE_RUN
	elif report.deep_pass_rate >= 0.22:
		plan.defensive_focus = WeeklyGamePlanData.DEFENSE_EXPLOSIVES
	elif opponent.effective_offense_rating() >= team.effective_defense_rating() + 4:
		plan.defensive_focus = WeeklyGamePlanData.DEFENSE_PRESSURE
	else:
		plan.defensive_focus = WeeklyGamePlanData.DEFENSE_BALANCED


static func _populate_personnel_intel(report: OpponentScoutingReportData, opponent: TeamData) -> void:
	var players := opponent.players.duplicate()
	players.sort_custom(func(a: PlayerData, b: PlayerData):
		if a.effective_overall() != b.effective_overall():
			return a.effective_overall() > b.effective_overall()
		return a.id < b.id
	)
	for player: PlayerData in players:
		if report.key_players.size() >= 3:
			break
		if player.is_available():
			report.key_players.append({
				"player_id": player.id,
				"name": player.full_name,
				"position": player.position,
				"overall": player.effective_overall(),
				"status": player.availability_label(),
			})
	for player: PlayerData in opponent.injured_players():
		report.injury_notes.append("%s · %s · %s" % [player.full_name, player.position, player.availability_label()])
	if report.injury_notes.is_empty():
		report.injury_notes.append("No current injury absence is listed for the opponent.")


static func _populate_performance_intel(
	report: OpponentScoutingReportData,
	opponent: TeamData,
	has_film: bool
) -> void:
	if report.run_rate >= 0.56:
		report.strengths.append("A run-first offense consistently forces extra defenders into the fit.")
	elif report.run_rate <= 0.42:
		report.strengths.append("A pass-first offense stresses coverage depth and substitution packages.")
	else:
		report.strengths.append("Balanced sequencing makes early-down calls difficult to predict.")
	if has_film and report.points_per_game >= 25.0:
		report.strengths.append("Recent scoring output is strong at %.1f points per game." % report.points_per_game)
	elif opponent.effective_offense_rating() >= 80:
		report.strengths.append("The offensive lineup grades as an upper-tier unit.")
	if has_film and report.points_allowed_per_game >= 25.0:
		report.vulnerabilities.append("The defense has allowed %.1f points per game over the available film." % report.points_allowed_per_game)
	elif opponent.effective_defense_rating() <= 76:
		report.vulnerabilities.append("The defensive lineup can be stressed by sustained execution.")
	if report.blitz_rate >= 0.52:
		report.vulnerabilities.append("Frequent pressure creates opportunities for quick throws and protection answers.")
	elif report.blitz_rate <= 0.28:
		report.vulnerabilities.append("A conservative rush gives the quarterback time when protection holds.")
	if report.vulnerabilities.is_empty():
		report.vulnerabilities.append("No pronounced statistical weakness is visible in the current sample.")


static func _populate_matchup_intel(
	report: OpponentScoutingReportData,
	viewer: TeamData,
	opponent: TeamData
) -> void:
	if viewer == null:
		return
	var offense_edge := viewer.effective_offense_rating() - opponent.effective_defense_rating()
	var defense_edge := viewer.effective_defense_rating() - opponent.effective_offense_rating()
	report.matchup_notes.append(_edge_note("Your offense", "their defense", offense_edge))
	report.matchup_notes.append(_edge_note("Your defense", "their offense", defense_edge))
	var receiver_edge := _unit_rating(viewer, ["WR", "TE"]) - _unit_rating(opponent, ["CB", "S"])
	report.matchup_notes.append(_edge_note("Your receivers", "their secondary", receiver_edge))
	var trench_edge := _unit_rating(viewer, ["LT", "LG", "C", "RG", "RT"]) - _unit_rating(opponent, ["DT", "EDGE"])
	report.matchup_notes.append(_edge_note("Your pass protection", "their front", trench_edge))


static func _edge_note(first_label: String, second_label: String, edge: int) -> String:
	if edge >= 4:
		return "%s hold a %d-point ratings edge over %s." % [first_label, edge, second_label]
	if edge <= -4:
		return "%s face a %d-point ratings disadvantage against %s." % [first_label, absi(edge), second_label]
	return "%s and %s grade as an even matchup." % [first_label, second_label]


static func _unit_rating(team: TeamData, positions: Array[String]) -> int:
	if team == null:
		return 50
	var total := 0
	var count := 0
	for position_name in positions:
		var player := team.player_at(position_name)
		if player != null:
			total += player.effective_overall()
			count += 1
	return roundi(float(total) / float(count)) if count > 0 else 50


static func _increment(counts: Dictionary, key: String) -> void:
	if key.is_empty():
		return
	counts[key] = int(counts.get(key, 0)) + 1


static func _most_used_key(counts: Dictionary, fallback: String = "") -> String:
	var result := fallback
	var best_count := -1
	for key_value in counts:
		var key := str(key_value)
		var count := int(counts[key_value])
		if count > best_count or (count == best_count and key < result):
			result = key
			best_count = count
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
