class_name SimulationTuning
extends RefCounted

const DATA_PATH := "res://data/simulation/attribute_tuning.json"

static var _cached_data: Dictionary = {}


static func data() -> Dictionary:
	if not _cached_data.is_empty():
		return _cached_data
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_cached_data = Dictionary(parsed)
	return _cached_data


static func value(section: String, key: String, fallback: float) -> float:
	var section_data = data().get(section, {})
	if section_data is Dictionary:
		return float(section_data.get(key, fallback))
	return fallback


static func ratings_center() -> float:
	return float(data().get("ratings_center", 75.0))
