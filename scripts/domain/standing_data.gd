class_name StandingData
extends RefCounted

var team_id: String
var wins := 0
var losses := 0
var ties := 0
var conference_wins := 0
var conference_losses := 0
var points_for := 0
var points_against := 0


func _init(id: String = "") -> void:
	team_id = id


func games_played() -> int:
	return wins + losses + ties


func win_percentage() -> float:
	var played := games_played()
	return (float(wins) + float(ties) * 0.5) / float(played) if played > 0 else 0.0


func point_differential() -> int:
	return points_for - points_against


func record_label() -> String:
	return "%d-%d" % [wins, losses] if ties == 0 else "%d-%d-%d" % [wins, losses, ties]


func conference_record_label() -> String:
	return "%d-%d" % [conference_wins, conference_losses]


func to_dict() -> Dictionary:
	return {
		"team_id": team_id,
		"wins": wins,
		"losses": losses,
		"ties": ties,
		"conference_wins": conference_wins,
		"conference_losses": conference_losses,
		"points_for": points_for,
		"points_against": points_against,
	}


static func from_dict(data: Dictionary) -> StandingData:
	var standing := StandingData.new(str(data.get("team_id", "")))
	standing.wins = int(data.get("wins", 0))
	standing.losses = int(data.get("losses", 0))
	standing.ties = int(data.get("ties", 0))
	standing.conference_wins = int(data.get("conference_wins", 0))
	standing.conference_losses = int(data.get("conference_losses", 0))
	standing.points_for = int(data.get("points_for", 0))
	standing.points_against = int(data.get("points_against", 0))
	return standing
