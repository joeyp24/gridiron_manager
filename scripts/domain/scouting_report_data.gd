class_name ScoutingReportData
extends RefCounted

var team_id: String
var prospect_id: String
var level := 0
var confidence := 25
var overall_low := 50
var overall_high := 75
var potential_low := 55
var potential_high := 85
var revealed_attributes: Dictionary = {}
var notes: Array[String] = []


func _init(report_team_id: String = "", report_prospect_id: String = "") -> void:
	team_id = report_team_id
	prospect_id = report_prospect_id


func overall_range_label() -> String:
	return "%d-%d" % [overall_low, overall_high]


func potential_range_label() -> String:
	return "%d-%d" % [potential_low, potential_high]


func estimated_overall() -> float:
	return float(overall_low + overall_high) * 0.5


func estimated_potential() -> float:
	return float(potential_low + potential_high) * 0.5


func advance(prospect: ProspectData, seed: int) -> bool:
	if level >= 3:
		return false
	level += 1
	_recalculate(prospect, seed)
	return true


func initialize(prospect: ProspectData, seed: int) -> void:
	level = 0
	_recalculate(prospect, seed)


func to_dict() -> Dictionary:
	return {
		"team_id": team_id,
		"prospect_id": prospect_id,
		"level": level,
		"confidence": confidence,
		"overall_low": overall_low,
		"overall_high": overall_high,
		"potential_low": potential_low,
		"potential_high": potential_high,
		"revealed_attributes": revealed_attributes.duplicate(true),
		"notes": notes.duplicate(),
	}


static func from_dict(data: Dictionary) -> ScoutingReportData:
	var report := ScoutingReportData.new(str(data.get("team_id", "")), str(data.get("prospect_id", "")))
	report.level = int(data.get("level", 0))
	report.confidence = int(data.get("confidence", 25))
	report.overall_low = int(data.get("overall_low", 50))
	report.overall_high = int(data.get("overall_high", 75))
	report.potential_low = int(data.get("potential_low", 55))
	report.potential_high = int(data.get("potential_high", 85))
	report.revealed_attributes = data.get("revealed_attributes", {}).duplicate(true)
	for note in data.get("notes", []):
		report.notes.append(str(note))
	return report


func _recalculate(prospect: ProspectData, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + prospect.id.hash() * 37 + level * 1009
	var widths := [12, 8, 4, 1]
	var errors := [5, 3, 2, 0]
	var confidences := [25, 50, 75, 95]
	var width := int(widths[level])
	var error := rng.randi_range(-int(errors[level]), int(errors[level]))
	var midpoint := clampi(prospect.true_overall + error, 45, 95)
	overall_low = clampi(midpoint - width / 2, 40, 99)
	overall_high = clampi(midpoint + width - width / 2, overall_low, 99)
	var potential_error := rng.randi_range(-int(errors[level]), int(errors[level]))
	var potential_width := width + 2
	var potential_midpoint := clampi(prospect.true_potential + potential_error, 50, 97)
	potential_low = clampi(potential_midpoint - potential_width / 2, 45, 99)
	potential_high = clampi(potential_midpoint + potential_width - potential_width / 2, potential_low, 99)
	confidence = int(confidences[level])
	revealed_attributes.clear()
	var keys := _priority_attributes(prospect.position)
	var reveal_count := mini(level * 2, keys.size())
	for index in range(reveal_count):
		var key: String = keys[index]
		revealed_attributes[key] = int(prospect.get(key))
	notes.clear()
	notes.append(_production_note(prospect.production_grade))
	if level >= 1:
		notes.append("%s personality; interview profile is %s." % [prospect.personality, _personality_note(prospect.personality)])
	if level >= 2:
		notes.append(_projection_note(prospect))
	if level >= 3:
		notes.append("Scouting staff considers this evaluation complete.")


func _priority_attributes(position_name: String) -> Array[String]:
	match position_name:
		"QB":
			return ["technique", "awareness", "power", "speed", "durability"]
		"RB", "WR", "CB", "S":
			return ["speed", "technique", "awareness", "durability", "power"]
		"LT", "LG", "C", "RG", "RT", "DT", "EDGE":
			return ["power", "technique", "awareness", "durability", "speed"]
		_:
			return ["technique", "awareness", "speed", "power", "durability"]


func _production_note(grade: int) -> String:
	if grade >= 85:
		return "Dominant college production against strong opposition."
	if grade >= 72:
		return "Consistent college production with starter-level flashes."
	if grade >= 60:
		return "Useful production, though the projection leans on traits."
	return "Limited production creates meaningful projection risk."


func _personality_note(label: String) -> String:
	match label:
		"Driven", "Team Leader":
			return "a clear positive"
		"Reserved", "Independent":
			return "still being evaluated"
		_:
			return "steady"


func _projection_note(prospect: ProspectData) -> String:
	var gap := prospect.true_potential - prospect.true_overall
	if gap >= 10:
		return "High developmental ceiling, but patience may be required."
	if prospect.true_overall >= 76:
		return "Projects as an early contributor with a stable floor."
	return "Projects as a role player with room to compete for snaps."
