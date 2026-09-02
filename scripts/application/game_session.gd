class_name GameSession
extends RefCounted

var teams: Array[TeamData]
var user_team: TeamData
var opponent_team: TeamData
var strategy := {
	"run_tendency": 0.46,
	"aggression": 0.50,
}
var simulator: FootballSimulator


func _init() -> void:
	var bundle := LeagueCatalog.create_bundle(LeagueCatalog.SOURCE_NFLVERSE_FULL)
	teams = []
	for team in bundle.get("teams", []):
		teams.append(team)


func start_exhibition(
	selected_team: TeamData,
	selected_opponent: TeamData,
	selected_strategy: Dictionary,
	game_seed: int
) -> FootballSimulator:
	user_team = selected_team.clone_with_strategy(selected_strategy)
	opponent_team = selected_opponent.clone_with_strategy({})
	strategy = selected_strategy.duplicate(true)
	simulator = FootballSimulator.new(user_team, opponent_team, game_seed)
	return simulator


func find_team(team_id: String) -> TeamData:
	for team in teams:
		if team.id == team_id:
			return team
	return null
