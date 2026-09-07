class_name SaveRepository
extends RefCounted

const SAVE_VERSION := 11
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
	var career := CareerSession.from_dict(migrated.get("career", {}))
	HybridRatingsCatalog.hydrate_league(career.league)
	return career


func _migrate(payload: Dictionary, version: int) -> Dictionary:
	var migrated := payload.duplicate(true)
	var current_version := version
	if current_version == 1:
		migrated = _migrate_v1_to_v2(migrated)
		current_version = 2
	if current_version == 2:
		migrated = _migrate_v2_to_v3(migrated)
		current_version = 3
	if current_version == 3:
		migrated = _migrate_v3_to_v4(migrated)
		current_version = 4
	if current_version == 4:
		migrated = _migrate_v4_to_v5(migrated)
		current_version = 5
	if current_version == 5:
		migrated = _migrate_v5_to_v6(migrated)
		current_version = 6
	if current_version == 6:
		migrated = _migrate_v6_to_v7(migrated)
		current_version = 7
	if current_version == 7:
		migrated = _migrate_v7_to_v8(migrated)
		current_version = 8
	if current_version == 8:
		migrated = _migrate_v8_to_v9(migrated)
		current_version = 9
	if current_version == 9:
		migrated = _migrate_v9_to_v10(migrated)
		current_version = 10
	if current_version == 10:
		migrated = _migrate_v10_to_v11(migrated)
		current_version = 11
	migrated["save_version"] = current_version
	return migrated


func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var season_year := int(league_data.get("season_year", 2026))
	var team_data_list: Array = league_data.get("teams", [])
	var migrated_roster_limit := 45 if team_data_list.size() < 32 else TeamData.DEFAULT_ROSTER_LIMIT
	for team_data: Dictionary in team_data_list:
		team_data["salary_cap"] = int(team_data.get("salary_cap", TeamData.DEFAULT_SALARY_CAP))
		team_data["roster_limit"] = int(team_data.get("roster_limit", migrated_roster_limit))
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


func _migrate_v2_to_v3(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var team_data_list: Array = league_data.get("teams", [])
	for team_data: Dictionary in team_data_list:
		for player_data: Dictionary in team_data.get("players", []):
			_add_v3_player_fields(player_data)
	for player_data: Dictionary in league_data.get("free_agents", []):
		_add_v3_player_fields(player_data)
	league_data["season_history"] = league_data.get("season_history", [])
	league_data["development_reports"] = league_data.get("development_reports", [])
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 3
	return payload


func _add_v3_player_fields(player_data: Dictionary) -> void:
	if not player_data.has("potential"):
		player_data["potential"] = PlayerData.initial_potential(
			str(player_data.get("id", "")),
			int(player_data.get("overall", 50)),
			int(player_data.get("age", 24))
		)
	var contract_data = player_data.get("contract")
	if contract_data is Dictionary and not contract_data.has("expires_after_year"):
		contract_data["expires_after_year"] = int(contract_data.get("signed_year", 2026)) + int(contract_data.get("years_remaining", 1)) - 1


func _migrate_v3_to_v4(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	league_data["current_draft"] = league_data.get("current_draft", null)
	league_data["draft_history"] = league_data.get("draft_history", [])
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 4
	return payload


func _migrate_v4_to_v5(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var season_year := int(league_data.get("season_year", 2026))
	var season_seed := int(league_data.get("season_seed", 0))
	for team_data: Dictionary in league_data.get("teams", []):
		var team_id := str(team_data.get("id", ""))
		for player_data: Dictionary in team_data.get("players", []):
			_add_v5_player_fields(player_data, team_id, season_year, season_seed)
	for player_data: Dictionary in league_data.get("free_agents", []):
		_add_v5_player_fields(player_data, "", season_year, season_seed)
	league_data["retired_players"] = league_data.get("retired_players", [])
	league_data["last_retirement_year"] = int(league_data.get("last_retirement_year", 0))
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 5
	return payload


func _add_v5_player_fields(player_data: Dictionary, team_id: String, season_year: int, season_seed: int) -> void:
	var player_id := str(player_data.get("id", ""))
	var position_name := str(player_data.get("position", ""))
	var age := int(player_data.get("age", 24))
	var profile := PlayerGenerator.generate_replacement(position_name, season_year, absi(player_id.hash()) % 10_000, season_seed)
	player_data["archetype"] = str(player_data.get("archetype", profile.archetype))
	player_data["personality"] = str(player_data.get("personality", profile.personality))
	player_data["height_inches"] = int(player_data.get("height_inches", profile.height_inches))
	player_data["weight_lbs"] = int(player_data.get("weight_lbs", profile.weight_lbs))
	player_data["college"] = str(player_data.get("college", profile.college))
	var experience := int(player_data.get("experience_years", maxi(age - 21, 0)))
	player_data["experience_years"] = experience
	player_data["entry_year"] = int(player_data.get("entry_year", season_year - experience))
	player_data["draft_round"] = int(player_data.get("draft_round", 0))
	player_data["draft_pick"] = int(player_data.get("draft_pick", 0))
	player_data["original_team_id"] = str(player_data.get("original_team_id", team_id))
	player_data["team_history"] = player_data.get("team_history", [team_id] if not team_id.is_empty() else [])
	player_data["career_peak_overall"] = int(player_data.get("career_peak_overall", player_data.get("overall", 50)))
	player_data["seasons_as_free_agent"] = int(player_data.get("seasons_as_free_agent", 0))
	player_data["generation_source"] = str(player_data.get("generation_source", "Legacy Migration"))


func _migrate_v5_to_v6(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	league_data["league_name"] = str(league_data.get("league_name", "Gridiron League"))
	league_data["data_source_id"] = str(league_data.get("data_source_id", LeagueCatalog.SOURCE_FICTIONAL))
	league_data["data_source_label"] = str(league_data.get("data_source_label", "ORIGINAL LEAGUE"))
	league_data["data_snapshot"] = str(league_data.get("data_snapshot", ""))
	league_data["data_attribution"] = str(league_data.get("data_attribution", "Original fictional league content generated by Gridiron Manager."))
	league_data["data_source_metadata"] = Dictionary(league_data.get("data_source_metadata", {
		"id": LeagueCatalog.SOURCE_FICTIONAL,
		"label": "ORIGINAL LEAGUE",
		"league_name": "Gridiron League",
		"attribution": league_data["data_attribution"],
	})).duplicate(true)
	for team_data: Dictionary in league_data.get("teams", []):
		team_data["division"] = str(team_data.get("division", ""))
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 6
	return payload


func _migrate_v6_to_v7(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var team_count := Array(league_data.get("teams", [])).size()
	var format := LeagueFormatData.nfl_32() if team_count >= 32 else LeagueFormatData.legacy_eight()
	league_data["league_format"] = Dictionary(league_data.get("league_format", format.to_dict())).duplicate(true)
	league_data["schedule_template"] = league_data.get("schedule_template", [])
	league_data["playoff_seeds"] = Dictionary(league_data.get("playoff_seeds", {})).duplicate(true)
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 7
	return payload


func _migrate_v7_to_v8(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	var season_year := int(league_data.get("season_year", 2026))
	var picks: Array[Dictionary] = []
	for draft_year in range(season_year + 1, season_year + TradeService.FUTURE_PICK_YEARS + 1):
		for round_number in range(1, DraftService.ROUNDS + 1):
			for team_data: Dictionary in league_data.get("teams", []):
				var team_id := str(team_data.get("id", ""))
				picks.append(DraftPickData.new(
					"future_%d_r%d_%s" % [draft_year, round_number, team_id],
					draft_year,
					round_number,
					0,
					0,
					team_id,
					team_id
				).to_dict())
	league_data["future_draft_picks"] = league_data.get("future_draft_picks", picks)
	league_data["trade_history"] = league_data.get("trade_history", [])
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 8
	return payload


func _migrate_v8_to_v9(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	league_data["statistics"] = Dictionary(league_data.get("statistics", LeagueStatisticsData.new().to_dict())).duplicate(true)
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 9
	return payload


func _migrate_v9_to_v10(payload: Dictionary) -> Dictionary:
	# Detailed ratings are optional in older payloads. PlayerData creates a
	# projection during deserialization and HybridRatingsCatalog replaces it with
	# the real source snapshot whenever the permanent player ID is available.
	payload["save_version"] = 10
	return payload


func _migrate_v10_to_v11(payload: Dictionary) -> Dictionary:
	var career_data: Dictionary = payload.get("career", {})
	var league_data: Dictionary = career_data.get("league", {})
	league_data["career_mode"] = str(league_data.get("career_mode", LeagueState.CAREER_MODE_STANDARD))
	league_data["fantasy_draft"] = league_data.get("fantasy_draft", null)
	career_data["league"] = league_data
	payload["career"] = career_data
	payload["save_version"] = 11
	return payload
