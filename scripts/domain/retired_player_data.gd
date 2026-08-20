class_name RetiredPlayerData
extends RefCounted

var player_id: String
var full_name: String
var position: String
var retirement_year: int
var age: int
var final_overall: int
var peak_overall: int
var experience_years: int
var final_team_id: String
var original_team_id: String
var team_history: Array[String] = []
var entry_year: int
var draft_round: int
var draft_pick: int
var archetype: String
var personality: String
var college: String
var departure_type: String
var reason: String
var dead_cap_charge: int


func _init(
	athlete_id: String = "",
	athlete_name: String = "Unknown Player",
	position_name: String = "",
	year: int = 2027,
	retirement_age: int = 30,
	overall: int = 50,
	career_peak: int = 50,
	experience: int = 0,
	last_team_id: String = "",
	first_team_id: String = "",
	career_entry_year: int = 2026,
	selected_round: int = 0,
	selected_pick: int = 0,
	player_archetype: String = "Balanced",
	player_personality: String = "Professional",
	player_college: String = "Independent",
	exit_type: String = "Retirement",
	exit_reason: String = "Retired from professional football.",
	cap_charge: int = 0
) -> void:
	player_id = athlete_id
	full_name = athlete_name
	position = position_name
	retirement_year = year
	age = retirement_age
	final_overall = overall
	peak_overall = career_peak
	experience_years = experience
	final_team_id = last_team_id
	original_team_id = first_team_id
	entry_year = career_entry_year
	draft_round = selected_round
	draft_pick = selected_pick
	archetype = player_archetype
	personality = player_personality
	college = player_college
	departure_type = exit_type
	reason = exit_reason
	dead_cap_charge = cap_charge


func draft_origin_label() -> String:
	return "Round %d, Pick %d" % [draft_round, draft_pick] if draft_round > 0 else "Undrafted"


func to_dict() -> Dictionary:
	return {
		"player_id": player_id,
		"full_name": full_name,
		"position": position,
		"retirement_year": retirement_year,
		"age": age,
		"final_overall": final_overall,
		"peak_overall": peak_overall,
		"experience_years": experience_years,
		"final_team_id": final_team_id,
		"original_team_id": original_team_id,
		"team_history": team_history.duplicate(),
		"entry_year": entry_year,
		"draft_round": draft_round,
		"draft_pick": draft_pick,
		"archetype": archetype,
		"personality": personality,
		"college": college,
		"departure_type": departure_type,
		"reason": reason,
		"dead_cap_charge": dead_cap_charge,
	}


static func from_dict(data: Dictionary) -> RetiredPlayerData:
	var record := RetiredPlayerData.new(
		str(data.get("player_id", "")),
		str(data.get("full_name", "Unknown Player")),
		str(data.get("position", "")),
		int(data.get("retirement_year", 2027)),
		int(data.get("age", 30)),
		int(data.get("final_overall", 50)),
		int(data.get("peak_overall", 50)),
		int(data.get("experience_years", 0)),
		str(data.get("final_team_id", "")),
		str(data.get("original_team_id", "")),
		int(data.get("entry_year", 2026)),
		int(data.get("draft_round", 0)),
		int(data.get("draft_pick", 0)),
		str(data.get("archetype", "Balanced")),
		str(data.get("personality", "Professional")),
		str(data.get("college", "Independent")),
		str(data.get("departure_type", "Retirement")),
		str(data.get("reason", "Retired from professional football.")),
		int(data.get("dead_cap_charge", 0))
	)
	for team_id in data.get("team_history", []):
		record.team_history.append(str(team_id))
	return record
