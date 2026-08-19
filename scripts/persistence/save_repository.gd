class_name SaveRepository
extends RefCounted

const SAVE_VERSION := 2
const DEFAULT_PATH := "user://gridiron_manager/career.json"

var save_path: String
var last_error := ""


func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_career(career: CareerSession) -> bool:
	last_error = ""
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var directory := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "Unable to create the save directory."
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "Unable to open the career save for writing."
		return false
	var payload := {
		"save_version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"career": career.to_dict(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_career() -> CareerSession:
	last_error = ""
	if not has_save():
		last_error = "No career save was found."
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "Unable to open the career save."
		return null
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		last_error = "The career save is not valid JSON."
		return null
	var payload: Dictionary = json.data
	var version := int(payload.get("save_version", 0))
	if version > SAVE_VERSION or version < 1:
		last_error = "This career save version is not supported."
		return null
	var migrated := _migrate(payload, version)
	return CareerSession.from_dict(migrated.get("career", {}))


func _migrate(payload: Dictionary, version: int) -> Dictionary:
	var migrated := payload.duplicate(true)
	var current_version := version
	if current_version == 1:
		migrated = _migrate_v1_to_v2(migrated)
		current_version = 2
	migrated["save_version"] = current_version
	return migrated


func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var season_year := int(league_data.get("season_year", 2026))
	var team_data_list: Array = league_data.get("teams", [])
	for team_data: Dictionary in team_data_list:
		team_data["salary_cap"] = int(team_data.get("salary_cap", TeamData.DEFAULT_SALARY_CAP))
		team_data["roster_limit"] = int(team_data.get("roster_limit", TeamData.DEFAULT_ROSTER_LIMIT))
		team_data["dead_cap"] = int(team_data.get("dead_cap", 0))
		var position_depth: Dictionary = {}
		var player_data_list: Array = team_data.get("players", [])
		for player_data: Dictionary in player_data_list:
			if player_data.has("contract") and player_data["contract"] != null:
				continue
			var player := PlayerData.from_dict(player_data)
			var depth_index := int(position_depth.get(player.position, 0))
			position_depth[player.position] = depth_index + 1
			player_data["contract"] = PlayerContract.initial_contract(player, season_year, depth_index).to_dict()
	league_data["teams"] = team_data_list
	if not league_data.has("free_agents"):
		var free_agent_data: Array[Dictionary] = []
		for player in SampleLeague.create_free_agents():
			free_agent_data.append(player.to_dict())
		league_data["free_agents"] = free_agent_data
	league_data["transactions"] = league_data.get("transactions", [])
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 2
	return payload
