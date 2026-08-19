class_name ScheduleGenerator
extends RefCounted


static func round_robin(teams: Array[TeamData]) -> Array[MatchupData]:
	var rotation: Array[String] = []
	for team in teams:
		rotation.append(team.id)
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
			if (round_index + pair_index) % 2 == 0:
				away_id = second
				home_id = first
			schedule.append(MatchupData.new(
				"week_%d_%s_%s" % [round_index + 1, away_id, home_id],
				round_index + 1,
				away_id,
				home_id
			))
		var moving_team: String = rotation.pop_back()
		rotation.insert(1, moving_team)
	return schedule
