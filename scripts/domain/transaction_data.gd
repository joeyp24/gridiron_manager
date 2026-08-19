class_name TransactionData
extends RefCounted

var id: String
var season_year: int
var week: int
var transaction_type: String
var team_id: String
var player_id: String
var player_name: String
var details: String
var cap_change: int


func _init(
	transaction_id: String = "",
	transaction_year: int = 2026,
	transaction_week: int = 1,
	type_name: String = "Signing",
	club_id: String = "",
	athlete_id: String = "",
	athlete_name: String = "",
	transaction_details: String = "",
	transaction_cap_change: int = 0
) -> void:
	id = transaction_id
	season_year = transaction_year
	week = transaction_week
	transaction_type = type_name
	team_id = club_id
	player_id = athlete_id
	player_name = athlete_name
	details = transaction_details
	cap_change = transaction_cap_change


func to_dict() -> Dictionary:
	return {
		"id": id,
		"season_year": season_year,
		"week": week,
		"transaction_type": transaction_type,
		"team_id": team_id,
		"player_id": player_id,
		"player_name": player_name,
		"details": details,
		"cap_change": cap_change,
	}


static func from_dict(data: Dictionary) -> TransactionData:
	return TransactionData.new(
		str(data.get("id", "")),
		int(data.get("season_year", 2026)),
		int(data.get("week", 1)),
		str(data.get("transaction_type", "Signing")),
		str(data.get("team_id", "")),
		str(data.get("player_id", "")),
		str(data.get("player_name", "")),
		str(data.get("details", "")),
		int(data.get("cap_change", 0))
	)
