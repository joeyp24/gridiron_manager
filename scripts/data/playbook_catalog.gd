class_name PlaybookCatalog
extends RefCounted

const PRO_STYLE_PATH := "res://data/playbooks/pro_style_offense.json"
const MULTIPLE_DEFENSE_PATH := "res://data/playbooks/multiple_defense.json"

static var _pro_style_cache: PlaybookData
static var _multiple_defense_cache: DefensivePlaybookData


static func pro_style_offense() -> PlaybookData:
	if _pro_style_cache == null:
		_pro_style_cache = _load_playbook(PRO_STYLE_PATH)
	return _pro_style_cache


static func multiple_defense() -> DefensivePlaybookData:
	if _multiple_defense_cache == null:
		_multiple_defense_cache = _load_defensive_playbook(MULTIPLE_DEFENSE_PATH)
	return _multiple_defense_cache


static func _load_playbook(path: String) -> PlaybookData:
	if not FileAccess.file_exists(path):
		push_error("Missing playbook data: %s" % path)
		return PlaybookData.new("missing", "Missing Playbook")
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid playbook data: %s" % path)
		return PlaybookData.new("invalid", "Invalid Playbook")
	return PlaybookData.from_dict(Dictionary(parsed))


static func _load_defensive_playbook(path: String) -> DefensivePlaybookData:
	if not FileAccess.file_exists(path):
		push_error("Missing defensive playbook data: %s" % path)
		return DefensivePlaybookData.new("missing", "Missing Defensive Playbook")
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid defensive playbook data: %s" % path)
		return DefensivePlaybookData.new("invalid", "Invalid Defensive Playbook")
	return DefensivePlaybookData.from_dict(Dictionary(parsed))
