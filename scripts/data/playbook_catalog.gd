class_name PlaybookCatalog
extends RefCounted

const PRO_STYLE_PATH := "res://data/playbooks/pro_style_offense.json"

static var _pro_style_cache: PlaybookData


static func pro_style_offense() -> PlaybookData:
	if _pro_style_cache == null:
		_pro_style_cache = _load_playbook(PRO_STYLE_PATH)
	return _pro_style_cache


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
