class_name LeagueSimulator
extends RefCounted

const INJURIES: Array[String] = [
	"Ankle sprain", "Hamstring strain", "Shoulder bruise", "Knee sprain", "Concussion protocol"
]


static func create_season(user_team_id: String, seed: int) -> LeagueState:
	var teams := SampleLeague.create_teams()
	var league := LeagueState.new(teams, user_team_id, seed)
	league.schedule = ScheduleGenerator.round_robin(teams)
	league.free_agents = SampleLeague.create_free_agents()
	league.news.append("The 2026 Gridiron League season is ready for kickoff.")
	return league


static func prepare_current_week(league: LeagueState) -> void:
	if league.prepared_week == league.current_week:
		return
	for team in league.teams:
		for player in team.players:
			player.recover_for_new_week()
	league.prepared_week = league.current_week


static func simulate_matchup(league: LeagueState, matchup: MatchupData) -> GameStateData:
	var home := league.team_by_id(matchup.home_team_id)
	var away := league.team_by_id(matchup.away_team_id)
	var game_seed := _matchup_seed(league, matchup)
	var simulator := FootballSimulator.new(home, away, game_seed, matchup.phase == "Championship")
	simulator.simulate_to_end()
	league.record_game(matchup, simulator.state)
	_process_postgame(home, game_seed + 17)
	_process_postgame(away, game_seed + 31)
	return simulator.state


static func process_played_matchup(league: LeagueState, matchup: MatchupData, game: GameStateData) -> void:
	league.record_game(matchup, game)
	var game_seed := _matchup_seed(league, matchup)
	_process_postgame(league.team_by_id(matchup.home_team_id), game_seed + 17)
	_process_postgame(league.team_by_id(matchup.away_team_id), game_seed + 31)


static func simulate_remaining_week(league: LeagueState) -> Array[GameStateData]:
	var games: Array[GameStateData] = []
	for matchup in league.matchups_for_week(league.current_week):
		if not matchup.played:
			games.append(simulate_matchup(league, matchup))
	return games


static func _process_postgame(team: TeamData, seed: int) -> void:
	var starter_ids: Dictionary = {}
	var injured_before_game: Dictionary = {}
	for position_name in TeamData.ROSTER_POSITIONS:
		var starter := team.player_at(position_name)
		if starter != null:
			starter_ids[starter.id] = true
	for player in team.players:
		if player.injury_weeks > 0:
			injured_before_game[player.id] = true
		elif player.is_active:
			player.apply_game_fatigue(starter_ids.has(player.id))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for player in team.players:
		if injured_before_game.has(player.id):
			player.advance_injury_week()
			continue
		if not player.is_available():
			continue
		var starter_multiplier := 1.45 if starter_ids.has(player.id) else 0.50
		var durability_risk := float(100 - player.durability) * 0.00034
		var fatigue_risk := float(100 - player.energy) * 0.00020
		var injury_chance := (0.004 + durability_risk + fatigue_risk) * starter_multiplier
		if rng.randf() < injury_chance:
			var injury_label := INJURIES[rng.randi_range(0, INJURIES.size() - 1)]
			var weeks := rng.randi_range(1, 4)
			if injury_label == "Concussion protocol":
				weeks = rng.randi_range(1, 2)
			player.injure(injury_label, weeks)


static func _matchup_seed(league: LeagueState, matchup: MatchupData) -> int:
	return league.season_seed + matchup.week * 1009 + matchup.id.hash()
