class_name LeagueDataPackProvider
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 2


static func load_bundle(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open league data pack: %s" % path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("League data pack is not a JSON object: %s" % path)
		return {}
	var pack: Dictionary = parsed
	if int(pack.get("schema_version", 0)) != SUPPORTED_SCHEMA_VERSION:
		push_error("Unsupported league data-pack schema in %s" % path)
		return {}

	var teams: Array[TeamData] = []
	for team_data in pack.get("teams", []):
		teams.append(TeamData.from_dict(team_data))
	var free_agents: Array[PlayerData] = []
	for player_data in pack.get("free_agents", []):
		free_agents.append(PlayerData.from_dict(player_data))
	if teams.is_empty():
		push_error("League data pack contains no teams: %s" % path)
		return {}
	var schedule: Array[MatchupData] = []
	for matchup_data in pack.get("schedule", []):
		schedule.append(MatchupData.from_dict(matchup_data))
	return {
		"teams": teams,
		"free_agents": free_agents,
		"schedule": schedule,
		"league_format": LeagueFormatData.from_dict(Dictionary(pack.get("league_format", {})), teams.size()),
		"source": Dictionary(pack.get("source", {})).duplicate(true),
	}
