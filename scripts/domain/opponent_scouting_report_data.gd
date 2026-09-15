class_name OpponentScoutingReportData
extends RefCounted

var season_year := 2026
var week := 1
var viewer_team_id := ""
var opponent_team_id := ""
var games_analyzed := 0
var confidence := 25
var offensive_snaps := 0
var defensive_snaps := 0
var run_rate := 0.50
var quick_pass_rate := 0.0
var deep_pass_rate := 0.0
var blitz_rate := 0.42
var points_per_game := 0.0
var yards_per_game := 0.0
var points_allowed_per_game := 0.0
var yards_allowed_per_game := 0.0
var favorite_personnel := "11"
var favorite_offensive_call := "Insufficient film"
var favorite_defensive_call := "Insufficient film"
var preferred_coverage := "Balanced"
var strengths: Array[String] = []
var vulnerabilities: Array[String] = []
var matchup_notes: Array[String] = []
var key_players: Array[Dictionary] = []
var injury_notes: Array[String] = []


func confidence_label() -> String:
	if confidence >= 80:
		return "HIGH CONFIDENCE"
	if confidence >= 55:
		return "MODERATE CONFIDENCE"
	return "EARLY READ"


func tendency_label() -> String:
	if run_rate >= 0.56:
		return "Run-first"
	if run_rate <= 0.42:
		return "Pass-first"
	return "Balanced"


func to_dict() -> Dictionary:
	return {
		"season_year": season_year,
		"week": week,
		"viewer_team_id": viewer_team_id,
		"opponent_team_id": opponent_team_id,
		"games_analyzed": games_analyzed,
		"confidence": confidence,
		"offensive_snaps": offensive_snaps,
		"defensive_snaps": defensive_snaps,
		"run_rate": run_rate,
		"quick_pass_rate": quick_pass_rate,
		"deep_pass_rate": deep_pass_rate,
		"blitz_rate": blitz_rate,
		"points_per_game": points_per_game,
		"yards_per_game": yards_per_game,
		"points_allowed_per_game": points_allowed_per_game,
		"yards_allowed_per_game": yards_allowed_per_game,
		"favorite_personnel": favorite_personnel,
		"favorite_offensive_call": favorite_offensive_call,
		"favorite_defensive_call": favorite_defensive_call,
		"preferred_coverage": preferred_coverage,
		"strengths": strengths.duplicate(),
		"vulnerabilities": vulnerabilities.duplicate(),
		"matchup_notes": matchup_notes.duplicate(),
		"key_players": key_players.duplicate(true),
		"injury_notes": injury_notes.duplicate(),
	}


static func from_dict(data: Dictionary) -> OpponentScoutingReportData:
	var report := OpponentScoutingReportData.new()
	report.season_year = int(data.get("season_year", 2026))
	report.week = int(data.get("week", 1))
	report.viewer_team_id = str(data.get("viewer_team_id", ""))
	report.opponent_team_id = str(data.get("opponent_team_id", ""))
	report.games_analyzed = int(data.get("games_analyzed", 0))
	report.confidence = int(data.get("confidence", 25))
	report.offensive_snaps = int(data.get("offensive_snaps", 0))
	report.defensive_snaps = int(data.get("defensive_snaps", 0))
	report.run_rate = float(data.get("run_rate", 0.50))
	report.quick_pass_rate = float(data.get("quick_pass_rate", 0.0))
	report.deep_pass_rate = float(data.get("deep_pass_rate", 0.0))
	report.blitz_rate = float(data.get("blitz_rate", 0.42))
	report.points_per_game = float(data.get("points_per_game", 0.0))
	report.yards_per_game = float(data.get("yards_per_game", 0.0))
	report.points_allowed_per_game = float(data.get("points_allowed_per_game", 0.0))
	report.yards_allowed_per_game = float(data.get("yards_allowed_per_game", 0.0))
	report.favorite_personnel = str(data.get("favorite_personnel", "11"))
	report.favorite_offensive_call = str(data.get("favorite_offensive_call", "Insufficient film"))
	report.favorite_defensive_call = str(data.get("favorite_defensive_call", "Insufficient film"))
	report.preferred_coverage = str(data.get("preferred_coverage", "Balanced"))
	for value in Array(data.get("strengths", [])):
		report.strengths.append(str(value))
	for value in Array(data.get("vulnerabilities", [])):
		report.vulnerabilities.append(str(value))
	for value in Array(data.get("matchup_notes", [])):
		report.matchup_notes.append(str(value))
	for value in Array(data.get("key_players", [])):
		report.key_players.append(Dictionary(value).duplicate(true))
	for value in Array(data.get("injury_notes", [])):
		report.injury_notes.append(str(value))
	return report
