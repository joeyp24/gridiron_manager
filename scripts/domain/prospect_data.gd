class_name ProspectData
extends RefCounted

var id: String
var full_name: String
var position: String
var archetype: String
var age: int
var height_inches: int
var weight_lbs: int
var college: String
var production_grade: int
var personality: String
var true_overall: int
var true_potential: int
var speed: int
var power: int
var technique: int
var awareness: int
var durability: int
var forty_time: float
var bench_reps: int
var shuttle_time: float
var consensus_rank: int
var projected_round: int


func _init(
	prospect_id: String = "",
	prospect_name: String = "Unknown Prospect",
	prospect_position: String = "",
	prospect_archetype: String = "Balanced",
	prospect_age: int = 22,
	prospect_height: int = 72,
	prospect_weight: int = 220,
	prospect_college: String = "Independent",
	prospect_production: int = 60,
	prospect_personality: String = "Professional",
	prospect_overall: int = 60,
	prospect_potential: int = 70,
	prospect_speed: int = 60,
	prospect_power: int = 60,
	prospect_technique: int = 60,
	prospect_awareness: int = 60,
	prospect_durability: int = 75,
	prospect_forty: float = 4.75,
	prospect_bench: int = 18,
	prospect_shuttle: float = 4.35,
	prospect_rank: int = 0,
	prospect_round: int = 7
) -> void:
	id = prospect_id
	full_name = prospect_name
	position = prospect_position
	archetype = prospect_archetype
	age = prospect_age
	height_inches = prospect_height
	weight_lbs = prospect_weight
	college = prospect_college
	production_grade = prospect_production
	personality = prospect_personality
	true_overall = prospect_overall
	true_potential = prospect_potential
	speed = prospect_speed
	power = prospect_power
	technique = prospect_technique
	awareness = prospect_awareness
	durability = prospect_durability
	forty_time = prospect_forty
	bench_reps = prospect_bench
	shuttle_time = prospect_shuttle
	consensus_rank = prospect_rank
	projected_round = prospect_round


func height_label() -> String:
	return "%d'%d\"" % [height_inches / 12, height_inches % 12]


func projected_round_label() -> String:
	return "Round %d" % projected_round if projected_round <= 7 else "Priority FA"


func to_player(draft_year: int) -> PlayerData:
	var player := PlayerData.new(
		"rookie_%d_%s" % [draft_year, id],
		full_name,
		position,
		true_overall,
		speed,
		power,
		technique,
		awareness,
		age,
		durability,
		true_potential
	)
	player.archetype = archetype
	player.personality = personality
	player.height_inches = height_inches
	player.weight_lbs = weight_lbs
	player.college = college
	player.entry_year = draft_year
	player.experience_years = 0
	player.career_peak_overall = true_overall
	player.generation_source = "Draft Class"
	return player


func to_dict() -> Dictionary:
	return {
		"id": id,
		"full_name": full_name,
		"position": position,
		"archetype": archetype,
		"age": age,
		"height_inches": height_inches,
		"weight_lbs": weight_lbs,
		"college": college,
		"production_grade": production_grade,
		"personality": personality,
		"true_overall": true_overall,
		"true_potential": true_potential,
		"speed": speed,
		"power": power,
		"technique": technique,
		"awareness": awareness,
		"durability": durability,
		"forty_time": forty_time,
		"bench_reps": bench_reps,
		"shuttle_time": shuttle_time,
		"consensus_rank": consensus_rank,
		"projected_round": projected_round,
	}


static func from_dict(data: Dictionary) -> ProspectData:
	return ProspectData.new(
		str(data.get("id", "")),
		str(data.get("full_name", "Unknown Prospect")),
		str(data.get("position", "")),
		str(data.get("archetype", "Balanced")),
		int(data.get("age", 22)),
		int(data.get("height_inches", 72)),
		int(data.get("weight_lbs", 220)),
		str(data.get("college", "Independent")),
		int(data.get("production_grade", 60)),
		str(data.get("personality", "Professional")),
		int(data.get("true_overall", 60)),
		int(data.get("true_potential", 70)),
		int(data.get("speed", 60)),
		int(data.get("power", 60)),
		int(data.get("technique", 60)),
		int(data.get("awareness", 60)),
		int(data.get("durability", 75)),
		float(data.get("forty_time", 4.75)),
		int(data.get("bench_reps", 18)),
		float(data.get("shuttle_time", 4.35)),
		int(data.get("consensus_rank", 0)),
		int(data.get("projected_round", 7))
	)
