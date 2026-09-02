class_name ScheduleGenerator
extends RefCounted


static func clone_schedule(source: Array[MatchupData]) -> Array[MatchupData]:
	var cloned: Array[MatchupData] = []
	for matchup in source:
		cloned.append(MatchupData.from_dict(matchup.to_dict()))
	return cloned


static func from_template(
	template: Array[MatchupData],
	teams: Array[TeamData],
	season_year: int,
	template_season: int
) -> Array[MatchupData]:
	if template.is_empty():
		return round_robin(teams, season_year, season_year * 7919)
	var team_map: Dictionary = {}
	var divisions: Dictionary = {}
	for team in teams:
		var division_key := "%s|%s" % [team.conference, team.division]
		if not divisions.has(division_key):
			divisions[division_key] = []
		divisions[division_key].append(team.id)
	var offset := posmod(season_year - template_season, 4)
	for division_ids: Array in divisions.values():
		division_ids.sort()
		for index in range(division_ids.size()):
			team_map[str(division_ids[index])] = str(division_ids[(index + offset) % division_ids.size()])
	var generated: Array[MatchupData] = []
	for source in template:
		var away_id := str(team_map.get(source.away_team_id, source.away_team_id))
		var home_id := str(team_map.get(source.home_team_id, source.home_team_id))
		generated.append(MatchupData.new(
			"%d_%02d_%s_%s" % [season_year, source.week, away_id.trim_prefix("nfl_").to_upper(), home_id.trim_prefix("nfl_").to_upper()],
			source.week,
			away_id,
			home_id,
			"Regular Season"
		))
	return generated


static func round_robin(teams: Array[TeamData], season_year: int = 0, seed: int = 0) -> Array[MatchupData]:
	var rotation: Array[String] = []
	for team in teams:
		rotation.append(team.id)
	if season_year > 0 and not rotation.is_empty():
		var offset := absi(seed + season_year * 17) % rotation.size()
		for index in range(offset):
			rotation.append(rotation.pop_front())
	if rotation.size() % 2 != 0:
		rotation.append("BYE")
	var schedule: Array[MatchupData] = []
	var round_count := rotation.size() - 1
	var games_per_round := rotation.size() / 2
	for round_index in range(round_count):
		for pair_index in range(games_per_round):
			var first := rotation[pair_index]
			var second := rotation[rotation.size() - 1 - pair_index]
			if first == "BYE" or second == "BYE":
				continue
			var away_id := first
			var home_id := second
			if (round_index + pair_index + season_year) % 2 == 0:
				away_id = second
				home_id = first
			schedule.append(MatchupData.new(
				"%sweek_%d_%s_%s" % ["season_%d_" % season_year if season_year > 0 else "", round_index + 1, away_id, home_id],
				round_index + 1,
				away_id,
				home_id
			))
		var moving_team: String = rotation.pop_back()
		rotation.insert(1, moving_team)
	return schedule
