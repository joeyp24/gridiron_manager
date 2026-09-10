class_name WeekSimulationTask
extends RefCounted

const MODE_FULL_WEEK := "Full Week"
const MODE_POSTGAME := "Postgame"

const STAGE_PREPARE := "Prepare"
const STAGE_GAMES := "Games"
const STAGE_LEAGUE_OPERATIONS := "League Operations"
const STAGE_FINALIZE := "Finalize"
const STAGE_COMPLETE := "Complete"

var mode := MODE_FULL_WEEK
var completed_week := 1
var stage := STAGE_PREPARE
var pending_matchups: Array[MatchupData] = []
var next_matchup_index := 0
var completed_units := 0
var total_units := 3
var status_text := "PREPARING WEEK"
var detail_text := "Checking game-day rosters and weekly health."


func _init(task_mode: String = MODE_FULL_WEEK, week: int = 1, matchups: Array[MatchupData] = []) -> void:
	mode = task_mode
	completed_week = week
	pending_matchups = matchups
	total_units = pending_matchups.size() + 3
	if mode == MODE_POSTGAME:
		status_text = "RECORDING FINAL RESULT"
		detail_text = "Finalizing the managed club's game book and injury report."


func is_complete() -> bool:
	return stage == STAGE_COMPLETE


func progress_ratio() -> float:
	if total_units <= 0:
		return 1.0
	return clampf(float(completed_units) / float(total_units), 0.0, 1.0)


func completed_game_count() -> int:
	return next_matchup_index


func total_game_count() -> int:
	return pending_matchups.size()
