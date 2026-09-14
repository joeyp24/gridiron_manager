class_name PlayResult
extends RefCounted

var sequence: int
var quarter: int
var clock_seconds: int
var offense_id: String
var defense_id: String
var down: int
var yards_to_first: int
var starting_field_position: int
var call_id: String
var call_name: String
var call_formation: String
var call_personnel: String
var call_concept: String
var call_tempo: String
var call_tags: Array[String] = []
var call_was_user_selected: bool
var defensive_call_id: String
var defensive_call_name: String
var defensive_call_category: String
var defensive_call_personnel: String
var defensive_call_coverage: String
var defensive_call_front: String
var defensive_call_shell: String
var defensive_call_rusher_count: int
var defensive_call_tags: Array[String] = []
var defensive_call_was_user_selected: bool
var title: String
var description: String
var play_type: String
var yards: int
var net_yards: int
var points: int
var drive_ended: bool
var possession_changed: bool
var scoring_play: bool
var first_down: bool
var touchdown: bool
var completed_pass: bool
var dropped_pass: bool
var interception: bool
var sack: bool
var fumble: bool
var fumble_lost: bool
var pass_defended: bool
var field_goal_made: bool
var punt_touchback: bool
var extra_point_attempted: bool
var extra_point_made: bool
var kick_distance: int
var passer_id: String
var target_id: String
var ball_carrier_id: String
var sack_player_id: String
var interceptor_id: String
var fumbler_id: String
var forced_fumble_player_id: String
var recovery_player_id: String
var pass_defender_id: String
var kicker_id: String
var punter_id: String
var returner_id: String
var tackler_ids: Array[String] = []
var offensive_participant_ids: Array[String] = []
var defensive_participant_ids: Array[String] = []
var special_teams_participant_ids: Array[String] = []
var offensive_starter_ids: Array[String] = []
var defensive_starter_ids: Array[String] = []
var matchup_context: Dictionary = {}


func _init() -> void:
	sequence = 0
	quarter = 1
	clock_seconds = 900
	offense_id = ""
	defense_id = ""
	down = 1
	yards_to_first = 10
	starting_field_position = 25
	call_id = ""
	call_name = ""
	call_formation = ""
	call_personnel = ""
	call_concept = ""
	call_tempo = PlayCallData.TEMPO_NORMAL
	call_tags = []
	call_was_user_selected = false
	defensive_call_id = ""
	defensive_call_name = ""
	defensive_call_category = ""
	defensive_call_personnel = ""
	defensive_call_coverage = ""
	defensive_call_front = ""
	defensive_call_shell = ""
	defensive_call_rusher_count = 4
	defensive_call_tags = []
	defensive_call_was_user_selected = false
	title = ""
	description = ""
	play_type = ""
	yards = 0
	net_yards = 0
	points = 0
	drive_ended = false
	possession_changed = false
	scoring_play = false
	first_down = false
	touchdown = false
	completed_pass = false
	dropped_pass = false
	interception = false
	sack = false
	fumble = false
	fumble_lost = false
	pass_defended = false
	field_goal_made = false
	punt_touchback = false
	extra_point_attempted = false
	extra_point_made = false
	kick_distance = 0
	passer_id = ""
	target_id = ""
	ball_carrier_id = ""
	sack_player_id = ""
	interceptor_id = ""
	fumbler_id = ""
	forced_fumble_player_id = ""
	recovery_player_id = ""
	pass_defender_id = ""
	kicker_id = ""
	punter_id = ""
	returner_id = ""
	matchup_context = {}


func clock_label() -> String:
	var minutes := clock_seconds / 60
	var seconds := clock_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func quarter_label() -> String:
	return "OT" if quarter > 4 else "Q%d" % quarter
