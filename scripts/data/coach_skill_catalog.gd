class_name CoachSkillCatalog
extends RefCounted

const PATH := "res://data/coaching/skill_tree.json"
static var _data: Dictionary = {}
static var _by_id: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
			for entry in _data.get("skills", []):
				_by_id[str(entry["id"])] = entry
	return _data


static func skills() -> Array:
	return data().get("skills", [])


static func branches() -> Array:
	return data().get("branches", [])


static func skill(skill_id: String) -> Dictionary:
	data()
	return _by_id.get(skill_id, {})


static func effect_text(definition: Dictionary, rank: int = 1) -> String:
	var lines: Array[String] = []
	for effect in definition.get("effects", []):
		var values: Dictionary = effect.get("values", {})
		var parts: Array[String] = []
		for key in values:
			var value := float(values[key]) * rank
			var label := str(key).replace("_", " ").capitalize()
			if key in ["completion", "sack", "interception", "fumble", "explosive", "field_goal"]:
				parts.append("%s %+.1f percentage points" % [label, value * 100.0])
			elif key in ["development", "retention"]:
				parts.append("%+.0f%% chance of %s" % [value * 100.0, "one extra growth point" if key == "development" else "preventing one decline point"])
			elif key == "injury":
				parts.append("Injury risk %+.0f%%" % (value * 100.0))
			else:
				parts.append("%s %+.2f" % [label, value])
		lines.append("%s · %s · %s: %s" % [
			str(effect.get("scope", "")).capitalize(),
			str(effect.get("filter", "")).replace("_", " "),
			str(effect.get("condition", "")).replace("_", " "),
			", ".join(parts)])
	return "\n".join(lines)
