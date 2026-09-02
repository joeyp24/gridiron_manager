class_name StatLineData
extends RefCounted

const TRACKED_STATS: Array[String] = [
	"games_played", "games_started",
	"offensive_snaps", "defensive_snaps", "special_teams_snaps",
	"passing_attempts", "passing_completions", "passing_yards", "passing_touchdowns",
	"passing_interceptions", "sacks_taken", "sack_yards_lost", "longest_completion",
	"rushing_attempts", "rushing_yards", "rushing_touchdowns", "longest_rush",
	"receiving_targets", "receptions", "receiving_yards", "receiving_touchdowns",
	"receiving_drops", "longest_reception",
	"fumbles", "fumbles_lost",
	"tackles", "assisted_tackles", "tackles_for_loss", "sacks", "quarterback_hits",
	"defensive_interceptions", "interception_return_yards", "interception_return_touchdowns",
	"passes_defended", "forced_fumbles", "fumble_recoveries", "defensive_touchdowns",
	"field_goal_attempts", "field_goals_made", "field_goal_yards", "longest_field_goal",
	"extra_point_attempts", "extra_points_made",
	"punts", "punt_yards", "net_punt_yards", "punts_inside_20", "punt_touchbacks", "longest_punt",
	"kick_returns", "kick_return_yards", "kick_return_touchdowns",
	"punt_returns", "punt_return_yards", "punt_return_touchdowns",
	"plays", "total_yards", "pass_yards", "gross_pass_yards", "rush_yards",
	"first_downs", "turnovers", "possession_seconds", "points", "points_allowed",
	"third_down_attempts", "third_down_conversions", "fourth_down_attempts", "fourth_down_conversions",
	"sacks_allowed", "sack_yards_allowed", "defensive_sacks", "defensive_interceptions_team",
	"forced_fumbles_team", "fumble_recoveries_team",
]

var values: Dictionary = {}


func _init(initial_values: Dictionary = {}) -> void:
	for stat_name in initial_values:
		values[stat_name] = int(initial_values[stat_name])


func value(stat_name: String) -> int:
	return int(values.get(stat_name, 0))


func set_value(stat_name: String, amount: int) -> void:
	values[stat_name] = amount


func add(stat_name: String, amount: int = 1) -> void:
	values[stat_name] = value(stat_name) + amount


func maximize(stat_name: String, amount: int) -> void:
	values[stat_name] = maxi(value(stat_name), amount)


func merge(other: StatLineData) -> void:
	if other == null:
		return
	for stat_name in other.values:
		add(str(stat_name), int(other.values[stat_name]))


func has_activity() -> bool:
	for stat_name in values:
		if stat_name not in ["games_played", "games_started"] and int(values[stat_name]) != 0:
			return true
	return false


func to_dict() -> Dictionary:
	return values.duplicate(true)


static func from_dict(data: Dictionary) -> StatLineData:
	return StatLineData.new(data)
