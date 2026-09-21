class_name CoachEffectService
extends RefCounted

const SNAP_CAPS := {"yardage": 1.6, "completion": 0.06, "sack": 0.035, "interception": 0.012, "fumble": 0.006, "explosive": 0.035}


static func effects(coach: CoachProgressData) -> Array:
	if coach == null:
		return []
	if coach.get_meta("effect_revision", -1) == coach.revision:
		return coach.get_meta("effects", [])
	var result: Array = []
	for skill_id in coach.ranks:
		var definition := CoachSkillCatalog.skill(str(skill_id))
		var rank := clampi(coach.rank_of(str(skill_id)), 0, int(definition.get("max_rank", 0)))
		if rank <= 0:
			continue
		for source in definition.get("effects", []):
			var effect: Dictionary = source.duplicate(true)
			effect["name"] = definition["name"]
			for key in effect["values"]:
				effect["values"][key] = float(effect["values"][key]) * rank
			result.append(effect)
	coach.set_meta("effect_revision", coach.revision)
	coach.set_meta("effects", result)
	return result


static func value(team: TeamData, key: String, scope: String) -> float:
	if team == null:
		return 0.0
	var total := 0.0
	for effect in effects(team.coach):
		if effect["scope"] == scope:
			total += float(effect["values"].get(key, 0.0))
	return total


static func preparation_budget(team: TeamData) -> int:
	return 6 + clampi(roundi(value(team, "preparation", "weekly")), 0, 1)


static func recovery_bonus(team: TeamData) -> int:
	return clampi(roundi(value(team, "recovery", "weekly")), 0, 5)


static func development_adjustment(team: TeamData, player: PlayerData, delta: int, seed: int) -> int:
	if team == null or team.coach == null:
		return 0
	var chance := 0.0
	for effect in effects(team.coach):
		if effect["scope"] != "development" or not _player_matches(str(effect["filter"]), player):
			continue
		chance += float(effect["values"].get("retention" if delta < 0 else "development", 0.0))
	if chance <= 0 or (delta >= 0 and (player.age > 28 or player.overall + delta >= player.potential)):
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + player.id.hash() + 7499
	return 1 if rng.randf() < clampf(chance, 0.0, 0.65) else 0


static func _player_matches(filter: String, player: PlayerData) -> bool:
	match filter:
		"young": return player.age <= 25
		"veteran": return player.age >= 29
		"trench": return player.position in ["OT", "OG", "C", "DT", "EDGE"]
		"all": return true
	return player.position == filter


static func snap_modifiers(state: GameStateData, play: PlayDefinitionData, defense: DefensiveCallData) -> Dictionary:
	var result: Dictionary = {}
	if play.play_type not in ["run", "pass"]:
		return result
	for scope in ["offense", "defense"]:
		var team := state.offense() if scope == "offense" else state.defense()
		for effect in effects(team.coach):
			if effect["scope"] != scope or not _play_matches(str(effect["filter"]), play, defense):
				continue
			if not _condition_matches(str(effect["condition"]), state, team):
				continue
			for key in effect["values"]:
				if SNAP_CAPS.has(key):
					result[key] = float(result.get(key, 0.0)) + float(effect["values"][key])
	for key in result:
		result[key] = clampf(float(result[key]), -float(SNAP_CAPS[key]), float(SNAP_CAPS[key]))
	return result


static func recommendation_adjustment(state: GameStateData, play: PlayDefinitionData) -> float:
	var total := 0.0
	for effect in effects(state.offense().coach):
		if effect["scope"] != "offense" or not _play_matches(str(effect["filter"]), play, null):
			continue
		if _condition_matches(str(effect["condition"]), state, state.offense()):
			var values: Dictionary = effect["values"]
			total += float(values.get("yardage", 0.0)) * 5.0 + float(values.get("completion", 0.0)) * 200.0 + float(values.get("explosive", 0.0)) * 100.0
	return clampf(total, -12.0, 12.0)


static func defensive_recommendation_adjustment(state: GameStateData, call: DefensiveCallData) -> float:
	var total := 0.0
	for effect in effects(state.defense().coach):
		if effect["scope"] != "defense" or not _condition_matches(str(effect["condition"]), state, state.defense()):
			continue
		if effect["filter"] == "blitz" and call.has_tag("blitz"):
			total += float(effect["values"].get("sack", 0.0)) * 400.0
		if effect["values"].has("explosive") and float(effect["values"]["explosive"]) < 0 and call.coverage == "Zone":
			total += 4.0
	return clampf(total, 0.0, 12.0)


static func _play_matches(filter: String, play: PlayDefinitionData, defense: DefensiveCallData) -> bool:
	match filter:
		"scrimmage": return play.play_type in ["run", "pass"]
		"run", "pass": return play.play_type == filter
		"qb_run": return play.play_type == "run" and play.runner_position == "QB"
		"outside_run": return play.play_type == "run" and play.has_tag("outside")
		"blitz": return play.play_type == "pass" and defense != null and defense.has_tag("blitz")
		"all": return true
	return play.has_tag(filter)


static func _condition_matches(condition: String, state: GameStateData, team: TeamData) -> bool:
	var opponent := state.away_team if team.id == state.home_team.id else state.home_team
	var lead := state.score_for(team.id) - state.score_for(opponent.id)
	match condition:
		"always": return true
		"opening": return state.drive_number <= 4
		"third_down": return state.down == 3
		"fourth_down": return state.down == 4
		"long": return state.yards_to_first >= 7
		"red_zone": return state.field_position >= 80
		"two_minute": return state.quarter in [2, 4] and state.clock_seconds <= 120
		"second_half": return state.quarter >= 3
		"trailing": return lead < 0
		"leading_late": return state.quarter >= 4 and lead > 0
		"trailing_late": return state.quarter >= 4 and lead < 0
	return false
