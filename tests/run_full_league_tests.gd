extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("FULL_LEAGUE_TEST: loading data pack")
	var bundle := LeagueCatalog.create_bundle(LeagueCatalog.SOURCE_NFLVERSE_FULL)
	print("FULL_LEAGUE_TEST: data pack loaded")
	var teams: Array = bundle.get("teams", [])
	var free_agents: Array = bundle.get("free_agents", [])
	var schedule: Array = bundle.get("schedule", [])
	_check(teams.size() == 32, "The complete league must contain 32 teams")
	_check(free_agents.size() >= 100, "The complete league must contain an expanded free-agent market")
	_check(schedule.size() == 272, "The 2026 regular season must contain 272 games")
	var team_ids: Dictionary = {}
	var player_ids: Dictionary = {}
	for team: TeamData in teams:
		team_ids[team.id] = true
		_check(team.players.size() == 53, "%s must have 53 players" % team.abbreviation)
		_check(RosterValidator.validate_team(team, true).is_empty(), "%s must have a legal full roster" % team.abbreviation)
		for player in team.players:
			_check(not player_ids.has(player.id), "%s must have a unique player ID" % player.full_name)
			player_ids[player.id] = true
	_check(team_ids.size() == 32 and player_ids.size() == 1696, "Team and player identities must be complete and unique")

	var games_by_team: Dictionary = {}
	var weeks_by_team: Dictionary = {}
	for matchup: MatchupData in schedule:
		for team_id in [matchup.away_team_id, matchup.home_team_id]:
			games_by_team[team_id] = int(games_by_team.get(team_id, 0)) + 1
			var week_key := "%s|%d" % [team_id, matchup.week]
			_check(not weeks_by_team.has(week_key), "%s cannot play twice in week %d" % [team_id, matchup.week])
			weeks_by_team[week_key] = true
	for team_id in team_ids:
		_check(int(games_by_team.get(team_id, 0)) == 17, "%s must play 17 games" % team_id)

	print("FULL_LEAGUE_TEST: creating career")
	var career := CareerSession.new_career("nfl_buf", 320532, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	_check(career.league.future_draft_picks.size() == 32 * DraftService.ROUNDS * TradeService.FUTURE_PICK_YEARS, "The complete league should reserve three seven-round years of tradable picks")
	for conference in career.league.conference_names():
		var projected := career.league.projected_playoff_team_ids(conference)
		_check(projected.size() == 7, "%s must project seven playoff qualifiers" % conference)
		for division_name in career.league.division_names(conference):
			var division_leader: String = career.league.sorted_division_standings(division_name).front().team_id
			_check(projected.slice(0, 4).has(division_leader), "%s leader must hold a top-four seed" % division_name)
	print("FULL_LEAGUE_TEST: simulating season")
	var guard := 0
	while not career.league.is_offseason() and guard < 26:
		career.simulate_current_week()
		guard += 1
	_check(career.league.phase == LeagueState.PHASE_SEASON_REVIEW, "The 32-team season must reach season review")
	_check(not career.league.champion_team_id.is_empty(), "The playoffs must crown a champion")
	_check(career.league.matchups_for_week(19).size() == 6, "Wild Card weekend must contain six games")
	_check(career.league.matchups_for_week(20).size() == 4, "The Divisional round must contain four games")
	_check(career.league.matchups_for_week(21).size() == 2, "Conference Championship weekend must contain two games")
	_check(career.league.matchups_for_week(22).size() == 1, "The championship round must contain one game")

	print("FULL_LEAGUE_TEST: validating future schedule and draft")
	var future := ScheduleGenerator.from_template(career.league.schedule_template, career.league.teams, 2027, 2026)
	_check(future.size() == 272, "Future seasons must retain a 272-game schedule")
	var future_ids: Dictionary = {}
	for matchup in future:
		future_ids[matchup.id] = true
	_check(future_ids.size() == future.size(), "Future schedule IDs must remain unique")
	var draft := DraftService.create_draft(career.league)
	_check(draft.picks.size() == 224, "A 32-team seven-round draft must contain 224 picks")
	_check(draft.prospects.size() == 256, "The draft pool must include selections and priority free agents")

	if _failures.is_empty():
		print("PASS: %d assertions across full-league data, schedule, postseason, and draft checks." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
