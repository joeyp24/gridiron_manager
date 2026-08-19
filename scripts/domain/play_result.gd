class_name PlayResult
extends RefCounted

var sequence: int
var quarter: int
var clock_seconds: int
var offense_id: String
var title: String
var description: String
var play_type: String
var yards: int
var points: int
var drive_ended: bool
var possession_changed: bool
var scoring_play: bool


func _init() -> void:
	sequence = 0
	quarter = 1
	clock_seconds = 900
	offense_id = ""
	title = ""
	description = ""
	play_type = ""
	yards = 0
	points = 0
	drive_ended = false
	possession_changed = false
	scoring_play = false


func clock_label() -> String:
	var minutes := clock_seconds / 60
	var seconds := clock_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func quarter_label() -> String:
	return "OT" if quarter > 4 else "Q%d" % quarter
