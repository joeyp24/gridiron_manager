class_name WeeklyGamePlanData
extends RefCounted

const TOTAL_PREPARATION_POINTS := 6
const MIN_UNIT_POINTS := 1
const MAX_UNIT_POINTS := 4

const OFFENSE_BALANCED := "balanced"
const OFFENSE_GROUND := "ground_control"
const OFFENSE_QUICK := "quick_game"
const OFFENSE_VERTICAL := "attack_deep"
const OFFENSE_PROTECTION := "extra_protection"

const DEFENSE_BALANCED := "balanced"
const DEFENSE_RUN := "stop_run"
const DEFENSE_EXPLOSIVES := "limit_explosives"
const DEFENSE_PRESSURE := "pressure_qb"
const DEFENSE_SPY := "qb_spy"

const OFFENSIVE_FOCUSES: Array[String] = [
	OFFENSE_BALANCED,
	OFFENSE_GROUND,
	OFFENSE_QUICK,
	OFFENSE_VERTICAL,
	OFFENSE_PROTECTION,
]
const DEFENSIVE_FOCUSES: Array[String] = [
	DEFENSE_BALANCED,
	DEFENSE_RUN,
	DEFENSE_EXPLOSIVES,
	DEFENSE_PRESSURE,
	DEFENSE_SPY,
]

var season_year := 2026
var week := 1
var matchup_id := ""
var team_id := ""
var opponent_id := ""
var offensive_focus := OFFENSE_BALANCED
var defensive_focus := DEFENSE_BALANCED
var offensive_points := 3
var defensive_points := 3
var created_from_games := 0
var scouting_confidence := 25
var ai_controlled := false


func _init(
	plan_year: int = 2026,
	plan_week: int = 1,
	plan_matchup_id: String = "",
	plan_team_id: String = "",
	plan_opponent_id: String = ""
) -> void:
	season_year = plan_year
	week = plan_week
	matchup_id = plan_matchup_id
	team_id = plan_team_id
	opponent_id = plan_opponent_id


func points_used() -> int:
	return offensive_points + defensive_points


func points_remaining() -> int:
	return TOTAL_PREPARATION_POINTS - points_used()


func validation_error() -> String:
	if not offensive_focus in OFFENSIVE_FOCUSES:
		return "Choose a valid offensive priority."
	if not defensive_focus in DEFENSIVE_FOCUSES:
		return "Choose a valid defensive priority."
	if offensive_points < MIN_UNIT_POINTS or offensive_points > MAX_UNIT_POINTS:
		return "Offensive preparation must use between one and four points."
	if defensive_points < MIN_UNIT_POINTS or defensive_points > MAX_UNIT_POINTS:
		return "Defensive preparation must use between one and four points."
	if points_used() > TOTAL_PREPARATION_POINTS:
		return "This plan uses more than six weekly preparation points."
	return ""


func is_valid() -> bool:
	return validation_error().is_empty()


func offense_label() -> String:
	return offensive_focus_label(offensive_focus)


func defense_label() -> String:
	return defensive_focus_label(defensive_focus)


func summary() -> String:
	return "%s (%d) · %s (%d)" % [offense_label(), offensive_points, defense_label(), defensive_points]


func to_dict() -> Dictionary:
	return {
		"season_year": season_year,
		"week": week,
		"matchup_id": matchup_id,
		"team_id": team_id,
		"opponent_id": opponent_id,
		"offensive_focus": offensive_focus,
		"defensive_focus": defensive_focus,
		"offensive_points": offensive_points,
		"defensive_points": defensive_points,
		"created_from_games": created_from_games,
		"scouting_confidence": scouting_confidence,
		"ai_controlled": ai_controlled,
	}


static func from_dict(data: Dictionary) -> WeeklyGamePlanData:
	var plan := WeeklyGamePlanData.new(
		int(data.get("season_year", 2026)),
		int(data.get("week", 1)),
		str(data.get("matchup_id", "")),
		str(data.get("team_id", "")),
		str(data.get("opponent_id", ""))
	)
	plan.offensive_focus = str(data.get("offensive_focus", OFFENSE_BALANCED))
	plan.defensive_focus = str(data.get("defensive_focus", DEFENSE_BALANCED))
	plan.offensive_points = int(data.get("offensive_points", 3))
	plan.defensive_points = int(data.get("defensive_points", 3))
	plan.created_from_games = int(data.get("created_from_games", 0))
	plan.scouting_confidence = int(data.get("scouting_confidence", 25))
	plan.ai_controlled = bool(data.get("ai_controlled", false))
	return plan


static func offensive_focus_label(focus_id: String) -> String:
	match focus_id:
		OFFENSE_GROUND:
			return "Ground Control"
		OFFENSE_QUICK:
			return "Quick Game"
		OFFENSE_VERTICAL:
			return "Attack Deep"
		OFFENSE_PROTECTION:
			return "Extra Protection"
	return "Balanced Offense"


static func defensive_focus_label(focus_id: String) -> String:
	match focus_id:
		DEFENSE_RUN:
			return "Stop the Run"
		DEFENSE_EXPLOSIVES:
			return "Limit Explosives"
		DEFENSE_PRESSURE:
			return "Pressure the QB"
		DEFENSE_SPY:
			return "Quarterback Spy"
	return "Balanced Defense"


static func offensive_focus_description(focus_id: String) -> String:
	match focus_id:
		OFFENSE_GROUND:
			return "Improves designed runs and makes run concepts more prominent on the call sheet."
		OFFENSE_QUICK:
			return "Improves quick-pass timing and reduces pressure at the cost of fewer vertical opportunities."
		OFFENSE_VERTICAL:
			return "Creates more explosive-pass opportunities with additional incompletion and turnover risk."
		OFFENSE_PROTECTION:
			return "Reduces sacks and stabilizes passing efficiency against pressure-heavy opponents."
	return "Spreads preparation across the full offensive call sheet without a specialized bonus."


static func defensive_focus_description(focus_id: String) -> String:
	match focus_id:
		DEFENSE_RUN:
			return "Improves run fits and increases the value of run-focused defensive calls."
		DEFENSE_EXPLOSIVES:
			return "Suppresses deep gains while conceding a little efficiency underneath."
		DEFENSE_PRESSURE:
			return "Raises sack and disruption chances while accepting additional explosive-play risk."
		DEFENSE_SPY:
			return "Limits quarterback rushing and scrambling while committing a defender to containment."
	return "Maintains a sound response to both run and pass without overcommitting resources."
