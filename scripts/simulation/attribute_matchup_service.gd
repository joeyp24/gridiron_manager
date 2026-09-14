class_name AttributeMatchupService
extends RefCounted

const SUMMARY_FALLBACKS := {
	"speed": "speed", "acceleration": "speed", "agility": "speed", "changeOfDirection": "speed", "jumping": "speed",
	"strength": "power", "hitPower": "power", "trucking": "power", "stiffArm": "power", "impactBlocking": "power",
	"awareness": "awareness", "playRecognition": "awareness", "bCVision": "awareness",
	"injury": "durability", "stamina": "durability", "toughness": "durability",
}


static func rating(player: PlayerData, attribute_name: String, fallback: float = -1.0) -> float:
	if player == null:
		return SimulationTuning.ratings_center() if fallback < 0.0 else fallback
	var base := fallback
	if base < 0.0:
		var summary_name := str(SUMMARY_FALLBACKS.get(attribute_name, "technique"))
		base = float(player.rating_for(summary_name))
	if player.madden_ratings != null:
		base = float(player.madden_ratings.rating(attribute_name, roundi(base)))
	var fatigue_penalty := float(maxi(player.overall - player.effective_overall(), 0))
	return clampf(base - fatigue_penalty, 1.0, 99.0)


static func weighted_rating(player: PlayerData, weights: Dictionary) -> float:
	if player == null or weights.is_empty():
		return SimulationTuning.ratings_center()
	var total := 0.0
	var weight_total := 0.0
	for attribute_name in weights:
		var weight := float(weights[attribute_name])
		total += rating(player, str(attribute_name)) * weight
		weight_total += weight
	return total / maxf(weight_total, 0.001)


static func group_rating(players: Array[PlayerData], weights: Dictionary, fallback: float = 75.0) -> float:
	if players.is_empty():
		return fallback
	var total := 0.0
	for player in players:
		total += weighted_rating(player, weights)
	return total / float(players.size())


static func run_matchup(
	play: PlayDefinitionData,
	blockers: Array[PlayerData],
	front: Array[PlayerData],
	runner: PlayerData,
	tackler: PlayerData
) -> Dictionary:
	var blocking_weights := {
		"runBlock": 0.30, "runBlockFinesse": 0.18, "runBlockPower": 0.18,
		"impactBlocking": 0.14, "strength": 0.10, "awareness": 0.10,
	}
	if play != null and play.has_tag("power"):
		blocking_weights["runBlockPower"] = 0.30
		blocking_weights["runBlockFinesse"] = 0.08
	elif play != null and play.has_tag("zone"):
		blocking_weights["runBlockFinesse"] = 0.28
		blocking_weights["runBlockPower"] = 0.08
	var front_weights := {
		"blockShedding": 0.28, "playRecognition": 0.20, "pursuit": 0.18,
		"tackle": 0.16, "strength": 0.12, "awareness": 0.06,
	}
	var runner_weights := {
		"bCVision": 0.20, "breakTackle": 0.14, "speed": 0.14,
		"acceleration": 0.12, "agility": 0.10, "changeOfDirection": 0.10,
		"trucking": 0.08, "jukeMove": 0.06, "spinMove": 0.03, "stiffArm": 0.03,
	}
	if play != null and play.has_tag("power"):
		runner_weights["trucking"] = 0.17
		runner_weights["speed"] = 0.08
	elif play != null and play.has_tag("outside"):
		runner_weights["speed"] = 0.20
		runner_weights["changeOfDirection"] = 0.15
	var tackle_weights := {"tackle": 0.35, "pursuit": 0.22, "hitPower": 0.14, "playRecognition": 0.14, "strength": 0.08, "awareness": 0.07}
	var blocking := group_rating(blockers, blocking_weights) + float(blockers.size() - 6) * 1.1
	var front_score := group_rating(front, front_weights) + float(front.size() - 7) * 0.9
	var carrier := weighted_rating(runner, runner_weights)
	var tackle_score := weighted_rating(tackler, tackle_weights)
	var ball_security := weighted_rating(runner, {"carrying": 0.70, "awareness": 0.20, "strength": 0.10})
	var hit_force := weighted_rating(tackler, {"hitPower": 0.45, "tackle": 0.35, "strength": 0.20})
	return {
		"blocking": blocking,
		"front": front_score,
		"blocking_edge": blocking - front_score,
		"carrier": carrier,
		"tackle": tackle_score,
		"carrier_edge": carrier - tackle_score,
		"ball_security": ball_security,
		"hit_force": hit_force,
		"lane_label": _edge_label(blocking - front_score, "clean lane", "stalemate", "penetration"),
		"finish_label": _edge_label(carrier - tackle_score, "broken tackle", "balanced contact", "secure tackle"),
	}


static func pass_matchup(
	play: PlayDefinitionData,
	defensive_call: DefensiveCallData,
	protectors: Array[PlayerData],
	rushers: Array[PlayerData],
	quarterback: PlayerData,
	receiver: PlayerData,
	cover_defender: PlayerData
) -> Dictionary:
	var protection := group_rating(protectors, {
		"passBlock": 0.34, "passBlockFinesse": 0.20, "passBlockPower": 0.20,
		"awareness": 0.12, "strength": 0.09, "impactBlocking": 0.05,
	}) + float(protectors.size() - 5) * 1.2
	var rush := group_rating(rushers, {
		"finesseMoves": 0.24, "powerMoves": 0.24, "blockShedding": 0.18,
		"acceleration": 0.14, "strength": 0.10, "playRecognition": 0.10,
	}) + float(rushers.size() - 4) * 1.25
	var accuracy_attribute := "throwAccuracyMid"
	var route_attribute := "mediumRouteRunning"
	if play != null and (play.has_tag("quick") or play.has_tag("screen")):
		accuracy_attribute = "throwAccuracyShort"
		route_attribute = "shortRouteRunning"
	elif play != null and play.has_tag("deep"):
		accuracy_attribute = "throwAccuracyDeep"
		route_attribute = "deepRouteRunning"
	var accuracy_weights := {accuracy_attribute: 0.52, "throwPower": 0.10, "awareness": 0.15, "throwUnderPressure": 0.18, "throwOnTheRun": 0.05}
	if play != null and play.has_tag("play_action"):
		accuracy_weights["playAction"] = 0.12
		accuracy_weights[accuracy_attribute] = 0.45
	var accuracy := weighted_rating(quarterback, accuracy_weights)
	var decision := weighted_rating(quarterback, {"awareness": 0.48, "throwUnderPressure": 0.30, accuracy_attribute: 0.22})
	var pocket_escape := weighted_rating(quarterback, {"breakSack": 0.48, "throwUnderPressure": 0.27, "agility": 0.15, "awareness": 0.10})
	var route := weighted_rating(receiver, {
		route_attribute: 0.40, "release": 0.16, "speed": 0.14,
		"acceleration": 0.12, "agility": 0.08, "changeOfDirection": 0.10,
	})
	var coverage_attribute := "zoneCoverage" if defensive_call != null and defensive_call.coverage == "Zone" else "manCoverage"
	var coverage := weighted_rating(cover_defender, {
		coverage_attribute: 0.44, "playRecognition": 0.16, "press": 0.10,
		"speed": 0.12, "acceleration": 0.08, "agility": 0.05, "changeOfDirection": 0.05,
	})
	var catch_score := weighted_rating(receiver, {"catching": 0.46, "catchInTraffic": 0.27, "spectacularCatch": 0.12, "awareness": 0.08, "jumping": 0.07})
	var yac := weighted_rating(receiver, {"speed": 0.22, "acceleration": 0.16, "agility": 0.15, "changeOfDirection": 0.15, "breakTackle": 0.14, "jukeMove": 0.10, "bCVision": 0.08})
	var tackle_score := weighted_rating(cover_defender, {"tackle": 0.44, "pursuit": 0.24, "hitPower": 0.15, "playRecognition": 0.10, "strength": 0.07})
	return {
		"protection": protection,
		"rush": rush,
		"pressure_edge": rush - protection,
		"accuracy": accuracy,
		"decision": decision,
		"pocket_escape": pocket_escape,
		"route": route,
		"coverage": coverage,
		"separation_edge": route - coverage,
		"catch": catch_score,
		"yac": yac,
		"tackle": tackle_score,
		"pressure_label": _edge_label(protection - rush, "clean pocket", "closing pocket", "heavy pressure"),
		"coverage_label": _edge_label(route - coverage, "separation", "tight window", "blanketed"),
		"accuracy_attribute": accuracy_attribute,
		"route_attribute": route_attribute,
	}


static func field_goal_profile(kicker: PlayerData, distance: int) -> Dictionary:
	var accuracy := rating(kicker, "kickAccuracy")
	var power := rating(kicker, "kickPower")
	var center := SimulationTuning.ratings_center()
	var chance := (
		SimulationTuning.value("special_teams", "field_goal_base_chance", 0.91)
		+ (accuracy - center) * SimulationTuning.value("special_teams", "field_goal_accuracy_coefficient", 0.006)
		+ (power - center) * SimulationTuning.value("special_teams", "field_goal_power_coefficient", 0.0025) * clampf(float(distance - 42) / 18.0, 0.0, 1.0)
		- float(maxi(distance - 35, 0)) * SimulationTuning.value("special_teams", "field_goal_distance_penalty", 0.0165)
	)
	chance = clampf(
		chance,
		SimulationTuning.value("special_teams", "minimum_field_goal_chance", 0.10),
		SimulationTuning.value("special_teams", "maximum_field_goal_chance", 0.99)
	)
	return {"accuracy": accuracy, "power": power, "chance": chance}


static func extra_point_chance(kicker: PlayerData) -> float:
	var accuracy := rating(kicker, "kickAccuracy")
	return clampf(
		SimulationTuning.value("special_teams", "extra_point_base_chance", 0.94)
		+ (accuracy - SimulationTuning.ratings_center()) * SimulationTuning.value("special_teams", "extra_point_accuracy_coefficient", 0.002),
		SimulationTuning.value("special_teams", "minimum_extra_point_chance", 0.82),
		SimulationTuning.value("special_teams", "maximum_extra_point_chance", 0.995)
	)


static func punt_profile(punter: PlayerData) -> Dictionary:
	var power := rating(punter, "kickPower")
	var accuracy := rating(punter, "kickAccuracy")
	var expected_distance := (
		SimulationTuning.value("special_teams", "punt_base_distance", 42.0)
		+ (power - SimulationTuning.ratings_center()) * SimulationTuning.value("special_teams", "punt_power_coefficient", 0.23)
	)
	return {"power": power, "accuracy": accuracy, "expected_distance": expected_distance}


static func _edge_label(edge: float, positive: String, even: String, negative: String) -> String:
	if edge >= 5.0:
		return positive
	if edge <= -5.0:
		return negative
	return even
