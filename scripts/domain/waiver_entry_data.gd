class_name WaiverEntryData
extends RefCounted

var id := ""
var player: PlayerData
var waived_by_team_id := ""
var season_year := 2026
var waived_week := 1
var resolve_week := 2
var claims: Array[String] = []


func _init(
	entry_id: String = "",
	waived_player: PlayerData = null,
	former_team_id: String = "",
	year: int = 2026,
	week: int = 1,
	resolution_week: int = 2
) -> void:
	id = entry_id
	player = waived_player
	waived_by_team_id = former_team_id
	season_year = year
	waived_week = week
	resolve_week = resolution_week


func has_claim(team_id: String) -> bool:
	return claims.has(team_id)


func add_claim(team_id: String) -> bool:
	if team_id.is_empty() or claims.has(team_id):
		return false
	claims.append(team_id)
	return true


func remove_claim(team_id: String) -> bool:
	if not claims.has(team_id):
		return false
	claims.erase(team_id)
	return true


func to_dict() -> Dictionary:
	return {
		"id": id,
		"player": player.to_dict() if player != null else null,
		"waived_by_team_id": waived_by_team_id,
		"season_year": season_year,
		"waived_week": waived_week,
		"resolve_week": resolve_week,
		"claims": claims.duplicate(),
	}


static func from_dict(data: Dictionary) -> WaiverEntryData:
	var player_data = data.get("player")
	var entry := WaiverEntryData.new(
		str(data.get("id", "")),
		PlayerData.from_dict(player_data) if player_data is Dictionary else null,
		str(data.get("waived_by_team_id", "")),
		int(data.get("season_year", 2026)),
		int(data.get("waived_week", 1)),
		int(data.get("resolve_week", 2))
	)
	for team_id in data.get("claims", []):
		entry.claims.append(str(team_id))
	return entry
