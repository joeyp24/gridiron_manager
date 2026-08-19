class_name SaveRepository
extends RefCounted

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://gridiron_manager/career.json"

var save_path: String
var last_error := ""


func _init(path: String = DEFAULT_PATH) -> void:
	save_path = path


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_career(career: CareerSession) -> bool:
	last_error = ""
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var directory := absolute_path.get_base_dir()
	var directory_error := DirAccess.make_dir_recursive_absolute(directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		last_error = "Unable to create the save directory."
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		last_error = "Unable to open the career save for writing."
		return false
	var payload := {
		"save_version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"career": career.to_dict(),
	}
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	return true


func load_career() -> CareerSession:
	last_error = ""
	if not has_save():
		last_error = "No career save was found."
		return null
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "Unable to open the career save."
		return null
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		last_error = "The career save is not valid JSON."
		return null
	var payload: Dictionary = json.data
	var version := int(payload.get("save_version", 0))
	if version > SAVE_VERSION or version < 1:
		last_error = "This career save version is not supported."
		return null
	var migrated := _migrate(payload, version)
	return CareerSession.from_dict(migrated.get("career", {}))


func _migrate(payload: Dictionary, _version: int) -> Dictionary:
	return payload
