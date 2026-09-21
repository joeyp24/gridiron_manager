class_name CoachProgressData
extends RefCounted

const MAX_LEVEL := 30
const STARTING_POINTS := 3
var background := ""
var revision := 0
var identity_locked := false
var xp := 0
var ranks: Dictionary = {}
var milestones: Dictionary = {}
var counters: Dictionary = {}
var rewarded_games: Dictionary = {}
var rewarded_development: Dictionary = {}
var objective_year := 0
var objective_id := ""
var objective_progress := 0
var objective_claimed := false
var last_respec_year := 0
var history: Array[Dictionary] = []


func level() -> int:
	var result := 1
	while result < MAX_LEVEL and xp >= xp_for_level(result + 1):
		result += 1
	return result


static func xp_for_level(value: int) -> int:
	var steps := maxi(value - 1, 0)
	return 120 * steps + 15 * steps * steps


func earned_points() -> int:
	return STARTING_POINTS + level() - 1 + mini(milestones.size(), 6)


func rank_of(skill_id: String) -> int:
	return int(ranks.get(skill_id, 0))


func to_dict() -> Dictionary:
	return {
		"background": background, "identity_locked": identity_locked, "xp": xp,
		"ranks": ranks.duplicate(true), "milestones": milestones.duplicate(true),
		"counters": counters.duplicate(true), "rewarded_games": rewarded_games.duplicate(true),
		"rewarded_development": rewarded_development.duplicate(true),
		"objective_year": objective_year, "objective_id": objective_id,
		"objective_progress": objective_progress, "objective_claimed": objective_claimed,
		"last_respec_year": last_respec_year, "history": history.duplicate(true),
	}


static func from_dict(data: Dictionary) -> CoachProgressData:
	var coach := CoachProgressData.new()
	coach.background = str(data.get("background", ""))
	coach.identity_locked = bool(data.get("identity_locked", false))
	coach.xp = clampi(int(data.get("xp", 0)), 0, xp_for_level(MAX_LEVEL))
	for key in ["ranks", "milestones", "counters", "rewarded_games", "rewarded_development"]:
		coach.set(key, Dictionary(data.get(key, {})).duplicate(true))
	coach.objective_year = int(data.get("objective_year", 0))
	coach.objective_id = str(data.get("objective_id", ""))
	coach.objective_progress = maxi(int(data.get("objective_progress", 0)), 0)
	coach.objective_claimed = bool(data.get("objective_claimed", false))
	coach.last_respec_year = int(data.get("last_respec_year", 0))
	for entry in data.get("history", []):
		if entry is Dictionary:
			coach.history.append(entry.duplicate(true))
	return coach
