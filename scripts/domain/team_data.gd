class_name TeamData
extends RefCounted

var id: String
var city: String
var nickname: String
var abbreviation: String
var conference: String
var primary_color: Color
var secondary_color: Color
var offense_rating: int
var defense_rating: int
var special_teams_rating: int
var run_tendency: float
var aggression: float
var players: Array[PlayerData] = []


func _init(
	team_id: String = "",
	team_city: String = "",
	team_nickname: String = "",
	team_abbreviation: String = "",
	team_conference: String = "",
	team_primary_color: Color = Color.WHITE,
	team_secondary_color: Color = Color.BLACK,
	offense: int = 50,
	defense: int = 50,
	special_teams: int = 50,
	team_players: Array[PlayerData] = []
) -> void:
	id = team_id
	city = team_city
	nickname = team_nickname
	abbreviation = team_abbreviation
	conference = team_conference
	primary_color = team_primary_color
	secondary_color = team_secondary_color
	offense_rating = offense
	defense_rating = defense
	special_teams_rating = special_teams
	players = team_players
	run_tendency = 0.46
	aggression = 0.50


func display_name() -> String:
	return "%s %s" % [city, nickname]


func overall_rating() -> int:
	return roundi(
		float(offense_rating) * 0.45
		+ float(defense_rating) * 0.45
		+ float(special_teams_rating) * 0.10
	)


func player_at(position_name: String) -> PlayerData:
	for player in players:
		if player.position == position_name:
			return player
	return players.front() if not players.is_empty() else null


func clone_with_strategy(strategy: Dictionary) -> TeamData:
	var clone := TeamData.new(
		id,
		city,
		nickname,
		abbreviation,
		conference,
		primary_color,
		secondary_color,
		offense_rating,
		defense_rating,
		special_teams_rating,
		players.duplicate()
	)
	clone.run_tendency = strategy.get("run_tendency", run_tendency)
	clone.aggression = strategy.get("aggression", aggression)
	return clone
