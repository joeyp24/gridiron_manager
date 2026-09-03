class_name PlayCallData
extends RefCounted

const TEMPO_NORMAL := "Normal"
const TEMPO_HURRY := "Hurry Up"
const TEMPO_CHEW := "Chew Clock"
const TEMPOS: Array[String] = [TEMPO_NORMAL, TEMPO_HURRY, TEMPO_CHEW]

var play_id: String
var tempo: String
var user_selected: bool


func _init(selected_play_id: String = "", selected_tempo: String = TEMPO_NORMAL, selected_by_user: bool = true) -> void:
	play_id = selected_play_id
	tempo = selected_tempo if selected_tempo in TEMPOS else TEMPO_NORMAL
	user_selected = selected_by_user


func to_dict() -> Dictionary:
	return {
		"play_id": play_id,
		"tempo": tempo,
		"user_selected": user_selected,
	}


static func from_dict(data: Dictionary) -> PlayCallData:
	return PlayCallData.new(
		str(data.get("play_id", "")),
		str(data.get("tempo", TEMPO_NORMAL)),
		bool(data.get("user_selected", true))
	)
