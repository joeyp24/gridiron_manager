class_name HybridRatingsCatalog
extends RefCounted

const HYBRID_PACK_PATH := "res://data/leagues/nflverse_2026_full.json"

static var _player_payloads: Dictionary = {}
static var _team_logos: Dictionary = {}
static var _loaded := false


static func hydrate_league(league: LeagueState) -> void:
	if league == null:
		return
	if league.data_source_id not in [LeagueCatalog.SOURCE_NFLVERSE_FULL, LeagueCatalog.SOURCE_NFLVERSE_PREVIEW]:
		return
	var needs_source_data := false
	for team in league.teams:
		if team.logo_url.is_empty():
			needs_source_data = true
			break
		for player in team.all_contract_players():
			if _is_source_player_missing_ratings(player):
				needs_source_data = true
				break
		if needs_source_data:
			break
	if not needs_source_data:
		for player in league.free_agents:
			if _is_source_player_missing_ratings(player):
				needs_source_data = true
				break
	if not needs_source_data:
		return
	_ensure_loaded()
	for team in league.teams:
		if team.logo_url.is_empty():
			team.logo_url = str(_team_logos.get(team.id, ""))
		for player in team.all_contract_players():
			_hydrate_player(player)
	for player in league.free_agents:
		_hydrate_player(player)


static func _is_source_player_missing_ratings(player: PlayerData) -> bool:
	if player == null or (player.madden_ratings != null and player.madden_ratings.has_madden_source()):
		return false
	return player.id.begins_with("00-") or player.id.begins_with("madden_26_")


static func _hydrate_player(player: PlayerData) -> void:
	if player == null or (player.madden_ratings != null and player.madden_ratings.has_madden_source()):
		return
	var payload = _player_payloads.get(player.id)
	if not payload is Dictionary:
		return
	var ratings_data = payload.get("madden_ratings")
	if not ratings_data is Dictionary:
		return
	var ratings := PlayerRatingsData.from_dict(ratings_data)
	ratings.apply_overall_delta(player.overall - ratings.source_overall)
	player.madden_ratings = ratings
	player.jersey_number = int(payload.get("jersey_number", player.jersey_number))


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(HYBRID_PACK_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	for team_data in parsed.get("teams", []):
		var team_id := str(team_data.get("id", ""))
		_team_logos[team_id] = str(team_data.get("logo_url", ""))
		for player_data in team_data.get("players", []):
			_player_payloads[str(player_data.get("id", ""))] = player_data
	for player_data in parsed.get("free_agents", []):
		_player_payloads[str(player_data.get("id", ""))] = player_data
