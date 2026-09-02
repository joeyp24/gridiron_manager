class_name GameStateData
extends RefCounted

var home_team: TeamData
var away_team: TeamData
var possession_team_id: String
var opening_possession_team_id: String
var home_score := 0
var away_score := 0
var quarter := 1
var clock_seconds := 900
var down := 1
var yards_to_first := 10
var field_position := 25
var play_count := 0
var drive_number := 1
var is_final := false
var stats: Dictionary = {}
var player_stats: Dictionary = {}
var play_history: Array[PlayResult] = []


func _init(home: TeamData = null, away: TeamData = null) -> void:
	home_team = home
	away_team = away
	if home != null and away != null:
		possession_team_id = away.id
		opening_possession_team_id = away.id
		stats[home.id] = _empty_stats()
		stats[away.id] = _empty_stats()


func offense() -> TeamData:
	return home_team if possession_team_id == home_team.id else away_team


func defense() -> TeamData:
	return away_team if possession_team_id == home_team.id else home_team


func team_by_id(team_id: String) -> TeamData:
	if home_team != null and home_team.id == team_id:
		return home_team
	if away_team != null and away_team.id == team_id:
		return away_team
	return null


func score_for(team_id: String) -> int:
	return home_score if team_id == home_team.id else away_score


func add_score(team_id: String, points: int) -> void:
	if team_id == home_team.id:
		home_score += points
	else:
		away_score += points


func switch_possession(reset_to_25: bool = false) -> void:
	possession_team_id = away_team.id if possession_team_id == home_team.id else home_team.id
	field_position = 25 if reset_to_25 else clampi(100 - field_position, 1, 99)
	down = 1
	yards_to_first = mini(10, 100 - field_position)
	drive_number += 1


func game_clock_label() -> String:
	var minutes := clock_seconds / 60
	var seconds := clock_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func quarter_label() -> String:
	return "FINAL" if is_final else ("OT" if quarter > 4 else "Q%d" % quarter)


func down_and_distance_label() -> String:
	if is_final:
		return "GAME COMPLETE"
	var suffix := "th"
	if down == 1:
		suffix = "st"
	elif down == 2:
		suffix = "nd"
	elif down == 3:
		suffix = "rd"
	var distance := "Goal" if field_position + yards_to_first >= 100 else str(yards_to_first)
	return "%d%s & %s" % [down, suffix, distance]


func field_position_label() -> String:
	if field_position == 50:
		return "50"
	if field_position < 50:
		return "%s %d" % [offense().abbreviation, field_position]
	return "%s %d" % [defense().abbreviation, 100 - field_position]


func summary_signature() -> String:
	var totals: Array[String] = []
	for play in play_history:
		totals.append("%s:%s:%s:%s:%d:%d" % [play.offense_id, play.play_type, play.passer_id, play.ball_carrier_id, play.yards, play.points])
	return "%d-%d|%s" % [away_score, home_score, ",".join(totals)]


func _empty_stats() -> Dictionary:
	var team_stats: Dictionary = {}
	for stat_name in StatLineData.TRACKED_STATS:
		team_stats[stat_name] = 0
	return team_stats
