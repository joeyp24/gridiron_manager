class_name MatchupData
extends RefCounted

var id: String
var week: int
var away_team_id: String
var home_team_id: String
var phase: String
var played := false
var away_score := 0
var home_score := 0
var away_stats: Dictionary = {}
var home_stats: Dictionary = {}


func _init(
	matchup_id: String = "",
	matchup_week: int = 1,
	away_id: String = "",
	home_id: String = "",
	matchup_phase: String = "Regular Season"
) -> void:
	id = matchup_id
	week = matchup_week
	away_team_id = away_id
	home_team_id = home_id
	phase = matchup_phase


func includes(team_id: String) -> bool:
	return away_team_id == team_id or home_team_id == team_id


func opponent_id(team_id: String) -> String:
	return home_team_id if away_team_id == team_id else away_team_id


func winner_id() -> String:
	if not played or away_score == home_score:
		return ""
	return away_team_id if away_score > home_score else home_team_id


func scoreline() -> String:
	return "%d–%d" % [away_score, home_score] if played else "vs"


func to_dict() -> Dictionary:
	return {
		"id": id,
		"week": week,
		"away_team_id": away_team_id,
		"home_team_id": home_team_id,
		"phase": phase,
		"played": played,
		"away_score": away_score,
		"home_score": home_score,
		"away_stats": away_stats.duplicate(true),
		"home_stats": home_stats.duplicate(true),
	}


static func from_dict(data: Dictionary) -> MatchupData:
	var matchup := MatchupData.new(
		str(data.get("id", "")),
		int(data.get("week", 1)),
		str(data.get("away_team_id", "")),
		str(data.get("home_team_id", "")),
		str(data.get("phase", "Regular Season"))
	)
	matchup.played = bool(data.get("played", false))
	matchup.away_score = int(data.get("away_score", 0))
	matchup.home_score = int(data.get("home_score", 0))
	matchup.away_stats = data.get("away_stats", {}).duplicate(true)
	matchup.home_stats = data.get("home_stats", {}).duplicate(true)
	return matchup
