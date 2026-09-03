class_name PlayerRatingsData
extends RefCounted

const CATEGORY_FIELDS := {
	"Physical": ["speed", "acceleration", "agility", "changeOfDirection", "strength", "jumping", "stamina", "injury", "toughness", "awareness"],
	"Passing": ["throwPower", "throwAccuracyShort", "throwAccuracyMid", "throwAccuracyDeep", "throwOnTheRun", "throwUnderPressure", "playAction", "breakSack"],
	"Ball Carrier": ["bCVision", "carrying", "breakTackle", "trucking", "jukeMove", "spinMove", "stiffArm"],
	"Receiving": ["catching", "catchInTraffic", "spectacularCatch", "release", "shortRouteRunning", "mediumRouteRunning", "deepRouteRunning"],
	"Blocking": ["passBlock", "passBlockFinesse", "passBlockPower", "runBlock", "runBlockFinesse", "runBlockPower", "impactBlocking", "leadBlock"],
	"Defense": ["tackle", "hitPower", "pursuit", "playRecognition", "blockShedding", "finesseMoves", "powerMoves", "manCoverage", "zoneCoverage", "press"],
	"Special Teams": ["kickPower", "kickAccuracy", "kickReturn"],
}

const ATTRIBUTE_LABELS := {
	"bCVision": "BALL CARRIER VISION",
	"catchInTraffic": "CATCH IN TRAFFIC",
	"changeOfDirection": "CHANGE OF DIRECTION",
	"deepRouteRunning": "DEEP ROUTE RUNNING",
	"finesseMoves": "FINESSE MOVES",
	"hitPower": "HIT POWER",
	"impactBlocking": "IMPACT BLOCKING",
	"jukeMove": "JUKE MOVE",
	"kickAccuracy": "KICK ACCURACY",
	"kickPower": "KICK POWER",
	"kickReturn": "KICK RETURN",
	"leadBlock": "LEAD BLOCK",
	"manCoverage": "MAN COVERAGE",
	"mediumRouteRunning": "MEDIUM ROUTE RUNNING",
	"passBlock": "PASS BLOCK",
	"passBlockFinesse": "PASS BLOCK FINESSE",
	"passBlockPower": "PASS BLOCK POWER",
	"playAction": "PLAY ACTION",
	"playRecognition": "PLAY RECOGNITION",
	"powerMoves": "POWER MOVES",
	"runBlock": "RUN BLOCK",
	"runBlockFinesse": "RUN BLOCK FINESSE",
	"runBlockPower": "RUN BLOCK POWER",
	"shortRouteRunning": "SHORT ROUTE RUNNING",
	"spectacularCatch": "SPECTACULAR CATCH",
	"spinMove": "SPIN MOVE",
	"stiffArm": "STIFF ARM",
	"throwAccuracyDeep": "DEEP ACCURACY",
	"throwAccuracyMid": "MEDIUM ACCURACY",
	"throwAccuracyShort": "SHORT ACCURACY",
	"throwOnTheRun": "THROW ON THE RUN",
	"throwPower": "THROW POWER",
	"throwUnderPressure": "THROW UNDER PRESSURE",
	"zoneCoverage": "ZONE COVERAGE",
}

var source := "Gridiron projection"
var source_player_id := ""
var source_overall := 50
var iteration := ""
var archetype := "Balanced"
var portrait_url := ""
var source_team_name := ""
var source_team_logo_url := ""
var running_style := ""
var attributes: Dictionary = {}
var abilities: Array[Dictionary] = []


func has_madden_source() -> bool:
	return source.begins_with("Madden") and not source_player_id.is_empty()


func rating(attribute_name: String, fallback: int = 50) -> int:
	return int(attributes.get(attribute_name, fallback))


func category_names_for(position: String) -> Array[String]:
	var preferred: Array[String] = []
	match position:
		"QB":
			preferred = ["Passing", "Physical", "Ball Carrier"]
		"RB":
			preferred = ["Ball Carrier", "Receiving", "Physical"]
		"WR":
			preferred = ["Receiving", "Physical", "Ball Carrier"]
		"TE":
			preferred = ["Receiving", "Blocking", "Physical"]
		"LT", "LG", "C", "RG", "RT", "LS":
			preferred = ["Blocking", "Physical"]
		"EDGE", "DT", "LB", "CB", "S":
			preferred = ["Defense", "Physical"]
		"K", "P":
			preferred = ["Special Teams", "Physical"]
	for category_name in CATEGORY_FIELDS:
		if not preferred.has(category_name):
			preferred.append(category_name)
	return preferred


func rows_for_category(category_name: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for attribute_name in CATEGORY_FIELDS.get(category_name, []):
		if attributes.has(attribute_name):
			rows.append({
				"id": attribute_name,
				"label": attribute_label(attribute_name),
				"value": rating(attribute_name),
			})
	return rows


func top_attributes(limit: int = 5) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for attribute_name in attributes:
		if attribute_name == "overall":
			continue
		rows.append({
			"id": str(attribute_name),
			"label": attribute_label(str(attribute_name)),
			"value": int(attributes[attribute_name]),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.value) != int(b.value):
			return int(a.value) > int(b.value)
		return str(a.label) < str(b.label)
	)
	if rows.size() > limit:
		rows.resize(limit)
	return rows


func apply_overall_delta(delta: int) -> void:
	if delta == 0:
		return
	for attribute_name in attributes:
		if attribute_name == "overall":
			continue
		attributes[attribute_name] = clampi(int(attributes[attribute_name]) + delta, 10, 99)
	attributes["overall"] = clampi(int(attributes.get("overall", source_overall)) + delta, 40, 99)


func to_dict() -> Dictionary:
	return {
		"source": source,
		"source_player_id": source_player_id,
		"source_overall": source_overall,
		"iteration": iteration,
		"archetype": archetype,
		"portrait_url": portrait_url,
		"source_team_name": source_team_name,
		"source_team_logo_url": source_team_logo_url,
		"running_style": running_style,
		"attributes": attributes.duplicate(true),
		"abilities": abilities.duplicate(true),
	}


static func from_dict(data: Dictionary) -> PlayerRatingsData:
	var ratings := PlayerRatingsData.new()
	ratings.source = str(data.get("source", "Gridiron projection"))
	ratings.source_player_id = str(data.get("source_player_id", ""))
	ratings.source_overall = int(data.get("source_overall", 50))
	ratings.iteration = str(data.get("iteration", ""))
	ratings.archetype = str(data.get("archetype", "Balanced"))
	ratings.portrait_url = str(data.get("portrait_url", ""))
	ratings.source_team_name = str(data.get("source_team_name", ""))
	ratings.source_team_logo_url = str(data.get("source_team_logo_url", ""))
	ratings.running_style = str(data.get("running_style", ""))
	ratings.attributes = Dictionary(data.get("attributes", {})).duplicate(true)
	for ability_data in data.get("abilities", []):
		ratings.abilities.append(Dictionary(ability_data).duplicate(true))
	return ratings


static func from_summary(
	player_id: String,
	position: String,
	overall: int,
	speed: int,
	power: int,
	technique: int,
	awareness: int,
	durability: int,
	player_archetype: String = "Balanced"
) -> PlayerRatingsData:
	var ratings := PlayerRatingsData.new()
	ratings.source_player_id = player_id
	ratings.source_overall = overall
	ratings.archetype = player_archetype
	for category_name in CATEGORY_FIELDS:
		for attribute_name in CATEGORY_FIELDS[category_name]:
			ratings.attributes[attribute_name] = technique
	ratings.attributes["overall"] = overall
	for attribute_name in ["speed", "acceleration", "agility", "changeOfDirection", "jumping"]:
		ratings.attributes[attribute_name] = speed
	for attribute_name in ["strength", "hitPower", "trucking", "stiffArm", "impactBlocking"]:
		ratings.attributes[attribute_name] = power
	for attribute_name in ["awareness", "playRecognition", "bCVision"]:
		ratings.attributes[attribute_name] = awareness
	for attribute_name in ["injury", "stamina", "toughness"]:
		ratings.attributes[attribute_name] = durability
	if position in ["K", "P"]:
		ratings.attributes["kickPower"] = power
		ratings.attributes["kickAccuracy"] = technique
	return ratings


static func attribute_label(attribute_name: String) -> String:
	if ATTRIBUTE_LABELS.has(attribute_name):
		return str(ATTRIBUTE_LABELS[attribute_name])
	var readable := ""
	for index in range(attribute_name.length()):
		var character := attribute_name.substr(index, 1)
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			readable += " "
		readable += character
	return readable.to_upper()
