class_name CoachProgressionService
extends RefCounted

const BACKGROUNDS := ["offense", "defense", "development", "management"]
const OBJECTIVES := {
	"wins": {"label": "Win 8 games", "target": 8},
	"scoring": {"label": "Score 28+ points in 6 games", "target": 6},
	"defense": {"label": "Allow 17 or fewer points in 6 games", "target": 6},
	"clean": {"label": "Finish 8 games without a turnover", "target": 8},
}
const MILESTONES := {"wins_10": 10, "wins_25": 25, "wins_50": 50, "wins_100": 100}


static func initialize(league: LeagueState) -> void:
	for team in league.teams:
		if team.coach == null:
			team.coach = CoachProgressData.new()
			if team.id != league.user_team_id:
				team.coach.background = BACKGROUNDS[absi(("%d:%s" % [league.season_seed, team.id]).hash()) % BACKGROUNDS.size()]
				spend_ai(team.coach, league.season_seed + team.id.hash())
		sanitize(team.coach)
		ensure_objective(team.coach, league, team.id)


static func spent_points(coach: CoachProgressData, branch: String = "") -> int:
	var result := 0
	for skill_id in coach.ranks:
		var definition := CoachSkillCatalog.skill(str(skill_id))
		if not definition.is_empty() and (branch.is_empty() or definition["branch"] == branch):
			result += coach.rank_of(str(skill_id)) * int(definition.get("cost", 1))
	return result


static func available_points(coach: CoachProgressData) -> int:
	return maxi(coach.earned_points() - spent_points(coach), 0)


static func unlock_error(coach: CoachProgressData, skill_id: String) -> String:
	var definition := CoachSkillCatalog.skill(skill_id)
	if definition.is_empty():
		return "Unknown coaching skill."
	if coach.background.is_empty():
		return "Choose your coaching background first."
	if coach.rank_of(skill_id) >= int(definition["max_rank"]):
		return "Maximum rank reached."
	if available_points(coach) < int(definition["cost"]):
		return "Not enough skill points."
	for required in definition.get("requires", []):
		if coach.rank_of(str(required)) <= 0:
			return "Requires " + str(CoachSkillCatalog.skill(str(required)).get("name", required)) + "."
	if spent_points(coach, str(definition["branch"])) < int(definition["branch_points"]):
		return "Requires %d points invested in this branch." % int(definition["branch_points"])
	var group := str(definition.get("exclusive_group", ""))
	var signatures := 0
	for other_id in coach.ranks:
		var other := CoachSkillCatalog.skill(str(other_id))
		if coach.rank_of(str(other_id)) <= 0 or other.is_empty():
			continue
		if not group.is_empty() and other_id != skill_id and other.get("exclusive_group", "") == group:
			return "Conflicts with your chosen " + str(other["name"]) + " specialization."
		if bool(other.get("signature", false)):
			signatures += 1
	if bool(definition.get("signature", false)) and signatures >= 2:
		return "A coach can master at most two signature skills."
	return ""


static func unlock(coach: CoachProgressData, skill_id: String) -> Dictionary:
	var error := unlock_error(coach, skill_id)
	if not error.is_empty():
		return {"ok": false, "message": error}
	coach.ranks[skill_id] = coach.rank_of(skill_id) + 1
	coach.revision += 1
	coach.identity_locked = true
	return {"ok": true, "message": "%s upgraded to rank %d." % [CoachSkillCatalog.skill(skill_id)["name"], coach.rank_of(skill_id)]}


static func choose_background(coach: CoachProgressData, background: String) -> Dictionary:
	if background not in BACKGROUNDS or coach.identity_locked:
		return {"ok": false, "message": "Your background is permanent after your first skill purchase."}
	coach.background = background
	return {"ok": true, "message": "Coaching background selected. Spend your starting points to define your identity."}


static func respec(league: LeagueState, coach: CoachProgressData) -> Dictionary:
	if not league.is_offseason() or coach.last_respec_year == league.season_year or coach.ranks.is_empty():
		return {"ok": false, "message": "Retraining is available once per offseason, with at least one learned skill."}
	coach.ranks.clear()
	coach.last_respec_year = league.season_year
	coach.revision += 1
	return {"ok": true, "message": "All spent points refunded. Your background and career achievements are retained."}


static func sanitize(coach: CoachProgressData) -> void:
	# Replay only valid purchases in catalog order. Unknown, conflicting, over-budget,
	# and prerequisite-bypassing save entries cannot grant effects.
	if coach.background not in BACKGROUNDS:
		coach.background = ""
	for milestone in coach.milestones.keys():
		if milestone not in ["wins_10", "wins_25", "wins_50", "wins_100", "playoff_win", "championship"] or not bool(coach.milestones[milestone]):
			coach.milestones.erase(milestone)
	var desired := coach.ranks.duplicate()
	coach.ranks.clear()
	for definition in CoachSkillCatalog.skills():
		var skill_id := str(definition["id"])
		for unused in range(clampi(int(desired.get(skill_id, 0)), 0, int(definition["max_rank"]))):
			if not unlock_error(coach, skill_id).is_empty():
				break
			coach.ranks[skill_id] = coach.rank_of(skill_id) + 1
	if not coach.ranks.is_empty():
		coach.identity_locked = true
	coach.revision += 1


static func spend_ai(coach: CoachProgressData, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var preferences: Dictionary = {}
	for branch in BACKGROUNDS:
		preferences[branch] = rng.randi_range(0, 1)
	for attempt in range(80):
		var candidates: Array = []
		var weights: Array[float] = []
		var total := 0.0
		for definition in CoachSkillCatalog.skills():
			if not unlock_error(coach, str(definition["id"])).is_empty():
				continue
			var weight := 7.0 if definition["branch"] == coach.background else 1.0
			var lane_index := 0 if str(definition["lane"]) in ["ground", "pressure", "youth", "tempo"] else 1
			if lane_index == int(preferences[definition["branch"]]):
				weight *= 3.0
			weight *= float(definition["tier"])
			candidates.append(definition)
			weights.append(weight)
			total += weight
		if candidates.is_empty():
			return
		var pick := rng.randf() * total
		for index in range(candidates.size()):
			pick -= weights[index]
			if pick <= 0:
				unlock(coach, str(candidates[index]["id"]))
				break


static func ensure_objective(coach: CoachProgressData, league: LeagueState, team_id: String) -> void:
	if coach.objective_year == league.season_year and OBJECTIVES.has(coach.objective_id):
		return
	var keys := OBJECTIVES.keys()
	coach.objective_id = str(keys[absi(("%s:%d:%d" % [team_id, league.season_seed, league.season_year]).hash()) % keys.size()])
	coach.objective_year = league.season_year
	coach.objective_progress = 0
	coach.objective_claimed = false


static func award_game(league: LeagueState, matchup: MatchupData, game: GameStateData) -> void:
	if not matchup.played or not game.is_final:
		return
	for team_id in [matchup.home_team_id, matchup.away_team_id]:
		var team := league.team_by_id(team_id)
		if team == null or team.coach == null:
			continue
		var coach := team.coach
		var key := "%d:%s" % [league.season_year, matchup.id]
		if coach.rewarded_games.has(key):
			continue
		coach.rewarded_games[key] = true
		ensure_objective(coach, league, team.id)
		var scored := game.score_for(team.id)
		var allowed := game.score_for(matchup.opponent_id(team.id))
		var won := scored > allowed
		var turnover_count := int(game.stats.get(team.id, {}).get("turnovers", 0))
		var earned := 45 + (35 if won else 0)
		if matchup.phase != "Regular Season":
			earned += 45
		var background_success := (coach.background == "offense" and scored >= 28) or (coach.background == "defense" and allowed <= 17) or (coach.background == "management" and turnover_count == 0)
		if background_success:
			earned += 20
		coach.counters["games"] = int(coach.counters.get("games", 0)) + 1
		if won:
			coach.counters["wins"] = int(coach.counters.get("wins", 0)) + 1
		for milestone in MILESTONES:
			if int(coach.counters.get("wins", 0)) >= int(MILESTONES[milestone]):
				coach.milestones[milestone] = true
		if won and matchup.phase != "Regular Season":
			coach.milestones["playoff_win"] = true
		if won and matchup.phase == LeagueState.PHASE_CHAMPIONSHIP:
			coach.milestones["championship"] = true
			earned += 150
		var succeeded := {"wins": won, "scoring": scored >= 28, "defense": allowed <= 17, "clean": turnover_count == 0}
		if not coach.objective_claimed and bool(succeeded.get(coach.objective_id, false)):
			coach.objective_progress += 1
			if coach.objective_progress >= int(OBJECTIVES[coach.objective_id]["target"]):
				coach.objective_claimed = true
				earned += 250
		_award_xp(coach, earned, "%d W%d · %s %d–%d" % [league.season_year, matchup.week, "Win" if won else "Game", scored, allowed])
		if team.id != league.user_team_id:
			spend_ai(coach, team.id.hash() + league.season_seed)


static func award_development(league: LeagueState, team: TeamData, improved: int) -> void:
	if team.coach == null:
		return
	var key := str(league.season_year)
	if team.coach.rewarded_development.has(key):
		return
	team.coach.rewarded_development[key] = true
	_award_xp(team.coach, 80 + mini(improved, 20) * (8 if team.coach.background == "development" else 4), "%d player development · %d improved" % [league.season_year, improved])
	if team.id != league.user_team_id:
		spend_ai(team.coach, team.id.hash() + league.season_seed)


static func _award_xp(coach: CoachProgressData, amount: int, reason: String) -> void:
	var before := coach.level()
	coach.xp = mini(coach.xp + amount, CoachProgressData.xp_for_level(CoachProgressData.MAX_LEVEL))
	coach.history.push_front({"reason": reason, "xp": amount, "levels": coach.level() - before})
	while coach.history.size() > 20:
		coach.history.pop_back()
