class_name StatisticsService
extends RefCounted

const PHASE_ALL := "All Games"
const PHASE_REGULAR := "Regular Season"
const PHASE_POSTSEASON := "Postseason"

const PLAYER_CATEGORIES := {
	"Passing": {
		"positions": ["QB"],
		"sort": "passing_yards",
		"columns": [
			["GP", "games_played"], ["CMP", "passing_completions"], ["ATT", "passing_attempts"],
			["CMP%", "completion_percentage"], ["YDS", "passing_yards"], ["TD", "passing_touchdowns"],
			["INT", "passing_interceptions"], ["SACK", "sacks_taken"], ["RATE", "passer_rating"],
		],
	},
	"Rushing": {
		"positions": ["QB", "RB", "WR", "TE"],
		"sort": "rushing_yards",
		"columns": [
			["GP", "games_played"], ["ATT", "rushing_attempts"], ["YDS", "rushing_yards"],
			["AVG", "yards_per_carry"], ["TD", "rushing_touchdowns"], ["LONG", "longest_rush"],
			["FUM", "fumbles"],
		],
	},
	"Receiving": {
		"positions": ["RB", "WR", "TE"],
		"sort": "receiving_yards",
		"columns": [
			["GP", "games_played"], ["TGT", "receiving_targets"], ["REC", "receptions"],
			["YDS", "receiving_yards"], ["AVG", "yards_per_reception"], ["TD", "receiving_touchdowns"],
			["DROP", "receiving_drops"], ["LONG", "longest_reception"],
		],
	},
	"Defense": {
		"positions": ["EDGE", "DT", "LB", "CB", "S"],
		"sort": "total_tackles",
		"columns": [
			["GP", "games_played"], ["TKL", "total_tackles"], ["TFL", "tackles_for_loss"],
			["SACK", "sacks"], ["INT", "defensive_interceptions"], ["PD", "passes_defended"],
			["FF", "forced_fumbles"], ["FR", "fumble_recoveries"],
		],
	},
	"Kicking": {
		"positions": ["K"],
		"sort": "field_goals_made",
		"columns": [
			["GP", "games_played"], ["FGM", "field_goals_made"], ["FGA", "field_goal_attempts"],
			["FG%", "field_goal_percentage"], ["LONG", "longest_field_goal"],
			["XPM", "extra_points_made"], ["XPA", "extra_point_attempts"],
		],
	},
	"Punting": {
		"positions": ["P"],
		"sort": "punt_yards",
		"columns": [
			["GP", "games_played"], ["PUNTS", "punts"], ["AVG", "punt_average"],
			["NET", "net_punt_average"], ["IN20", "punts_inside_20"],
			["TB", "punt_touchbacks"], ["LONG", "longest_punt"],
		],
	},
}

const TEAM_CATEGORIES := {
	"Offense": {
		"sort": "yards_per_game",
		"descending": true,
		"columns": [
			["GP", "games_played"], ["PPG", "points_per_game"], ["YPG", "yards_per_game"],
			["PASS", "pass_yards"], ["RUSH", "rush_yards"], ["1D", "first_downs"], ["TO", "turnovers"],
		],
	},
	"Defense": {
		"sort": "points_allowed_per_game",
		"descending": false,
		"columns": [
			["GP", "games_played"], ["PA/G", "points_allowed_per_game"], ["SACK", "defensive_sacks"],
			["INT", "defensive_interceptions_team"], ["FF", "forced_fumbles_team"],
			["FR", "fumble_recoveries_team"], ["TKL", "total_tackles"],
		],
	},
	"Scoring": {
		"sort": "points",
		"descending": true,
		"columns": [
			["GP", "games_played"], ["PTS", "points"], ["PPG", "points_per_game"],
			["PASS TD", "passing_touchdowns"], ["RUSH TD", "rushing_touchdowns"],
			["FG", "field_goals_made"], ["XP", "extra_points_made"],
		],
	},
	"Situational": {
		"sort": "third_down_percentage",
		"descending": true,
		"columns": [
			["GP", "games_played"], ["1D", "first_downs"], ["3D ATT", "third_down_attempts"],
			["3D CONV", "third_down_conversions"], ["3D%", "third_down_percentage"],
			["4D ATT", "fourth_down_attempts"], ["4D CONV", "fourth_down_conversions"], ["4D%", "fourth_down_percentage"],
		],
	},
	"Special Teams": {
		"sort": "field_goal_percentage",
		"descending": true,
		"columns": [
			["GP", "games_played"], ["FGM", "field_goals_made"], ["FGA", "field_goal_attempts"],
			["FG%", "field_goal_percentage"], ["PUNTS", "punts"],
			["PUNT AVG", "punt_average"], ["NET AVG", "net_punt_average"], ["IN20", "punts_inside_20"],
		],
	},
}


static func season_years(league: LeagueState) -> Array[int]:
	var years: Array[int] = [league.season_year]
	for key in league.statistics.seasons:
		var year := int(key)
		if not years.has(year):
			years.append(year)
	years.sort()
	years.reverse()
	return years


static func player_category_names() -> Array[String]:
	var names: Array[String] = []
	for category_name in PLAYER_CATEGORIES:
		names.append(str(category_name))
	return names


static func team_category_names() -> Array[String]:
	var names: Array[String] = []
	for category_name in TEAM_CATEGORIES:
		names.append(str(category_name))
	return names


static func player_rows(
	league: LeagueState,
	year: int,
	phase_filter: String = PHASE_ALL,
	team_filter: String = "",
	position_filter: String = ""
) -> Array[Dictionary]:
	var accumulated: Dictionary = {}
	var metadata: Dictionary = {}
	var teams_by_player: Dictionary = {}
	var season := league.statistics.season(year)
	if season != null:
		for book: GameBookData in season.game_books.values():
			if not _phase_matches(book.phase, phase_filter):
				continue
			for player_id in book.player_stats:
				var game_line: PlayerGameStatsData = book.player_stats[player_id]
				if not team_filter.is_empty() and game_line.team_id != team_filter:
					continue
				metadata[player_id] = {
					"player_id": game_line.player_id,
					"full_name": game_line.full_name,
					"position": game_line.position,
				}
				if not accumulated.has(player_id):
					accumulated[player_id] = StatLineData.new()
				(accumulated[player_id] as StatLineData).merge(game_line.stats)
				if not teams_by_player.has(player_id):
					teams_by_player[player_id] = []
				var player_teams: Array = teams_by_player[player_id]
				if not player_teams.has(game_line.team_id):
					player_teams.append(game_line.team_id)
	if year == league.season_year:
		for team in league.teams:
			if not team_filter.is_empty() and team.id != team_filter:
				continue
			for player in team.players:
				_add_zero_player(metadata, accumulated, teams_by_player, player, team.id)
		if team_filter.is_empty():
			for player in league.free_agents:
				_add_zero_player(metadata, accumulated, teams_by_player, player, "")
	var rows: Array[Dictionary] = []
	for player_id in metadata:
		var meta: Dictionary = metadata[player_id]
		if not position_filter.is_empty() and str(meta.get("position", "")) != position_filter:
			continue
		var team_ids: Array = teams_by_player.get(player_id, [])
		rows.append({
			"player_id": str(player_id),
			"full_name": str(meta.get("full_name", "Unknown Player")),
			"position": str(meta.get("position", "")),
			"team_ids": team_ids.duplicate(),
			"team_label": _team_label(league, team_ids),
			"stats": accumulated.get(player_id, StatLineData.new()),
		})
	return rows


static func sorted_player_rows(rows: Array[Dictionary], category_name: String) -> Array[Dictionary]:
	var category: Dictionary = PLAYER_CATEGORIES.get(category_name, PLAYER_CATEGORIES["Passing"])
	var positions: Array = category.get("positions", [])
	var filtered: Array[Dictionary] = []
	for row in rows:
		if positions.is_empty() or str(row.get("position", "")) in positions:
			filtered.append(row)
	return sort_player_rows(filtered, str(category.get("sort", "games_played")))


static func sort_player_rows(rows: Array[Dictionary], stat_name: String, descending: bool = true) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary):
		var first := metric_value(a.get("stats"), stat_name)
		var second := metric_value(b.get("stats"), stat_name)
		if not is_equal_approx(first, second):
			return first > second if descending else first < second
		return str(a.get("full_name", "")) < str(b.get("full_name", ""))
	)
	return sorted


static func team_rows(
	league: LeagueState,
	year: int,
	phase_filter: String = PHASE_ALL
) -> Array[Dictionary]:
	var totals: Dictionary = {}
	for team in league.teams:
		totals[team.id] = StatLineData.new()
	var season := league.statistics.season(year)
	if season != null:
		for book: GameBookData in season.game_books.values():
			if not _phase_matches(book.phase, phase_filter):
				continue
			for team_id in book.team_stats:
				if not totals.has(team_id):
					totals[team_id] = StatLineData.new()
				(totals[team_id] as StatLineData).merge(book.team_stats[team_id])
	var rows: Array[Dictionary] = []
	for team in league.teams:
		rows.append({
			"team_id": team.id,
			"team_name": team.display_name(),
			"abbreviation": team.abbreviation,
			"conference": team.conference,
			"division": team.division,
			"color": team.primary_color,
			"stats": totals[team.id],
		})
	return rows


static func sorted_team_rows(rows: Array[Dictionary], category_name: String) -> Array[Dictionary]:
	var category: Dictionary = TEAM_CATEGORIES.get(category_name, TEAM_CATEGORIES["Offense"])
	var sort_stat := str(category.get("sort", "points"))
	var descending := bool(category.get("descending", true))
	return sort_team_rows(rows, sort_stat, descending)


static func sort_team_rows(rows: Array[Dictionary], stat_name: String, descending: bool = true) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = rows.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary):
		var first := metric_value(a.get("stats"), stat_name)
		var second := metric_value(b.get("stats"), stat_name)
		if not is_equal_approx(first, second):
			return first > second if descending else first < second
		return str(a.get("team_name", "")) < str(b.get("team_name", ""))
	)
	return sorted


static func player_game_log(
	league: LeagueState,
	player_id: String,
	year: int,
	phase_filter: String = PHASE_ALL
) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var season := league.statistics.season(year)
	if season == null:
		return entries
	for book: GameBookData in season.game_books.values():
		if not _phase_matches(book.phase, phase_filter):
			continue
		var line := book.player_line(player_id)
		if line == null:
			continue
		var is_away := line.team_id == book.away_team_id
		var team_score := book.away_score if is_away else book.home_score
		var opponent_score := book.home_score if is_away else book.away_score
		entries.append({
			"matchup_id": book.matchup_id,
			"week": book.week,
			"phase": book.phase,
			"team_id": line.team_id,
			"opponent_team_id": line.opponent_team_id,
			"result": "W" if team_score > opponent_score else ("L" if team_score < opponent_score else "T"),
			"score": "%d-%d" % [team_score, opponent_score],
			"stats": line.stats,
			"book": book,
		})
	entries.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("week", 0)) < int(b.get("week", 0)))
	return entries


static func player_team_splits(
	league: LeagueState,
	player_id: String,
	year: int,
	phase_filter: String = PHASE_ALL
) -> Array[Dictionary]:
	var splits: Dictionary = {}
	for entry in player_game_log(league, player_id, year, phase_filter):
		var team_id := str(entry.get("team_id", ""))
		if not splits.has(team_id):
			splits[team_id] = StatLineData.new()
		(splits[team_id] as StatLineData).merge(entry.get("stats"))
	var rows: Array[Dictionary] = []
	for team_id in splits:
		var team := league.team_by_id(str(team_id))
		rows.append({
			"team_id": str(team_id),
			"team_label": team.abbreviation if team != null else "FA",
			"stats": splits[team_id],
		})
	return rows


static func completed_games(
	league: LeagueState,
	year: int,
	phase_filter: String = PHASE_ALL,
	team_filter: String = ""
) -> Array[GameBookData]:
	var books: Array[GameBookData] = []
	var season := league.statistics.season(year)
	if season == null:
		return books
	for book: GameBookData in season.game_books.values():
		if not _phase_matches(book.phase, phase_filter):
			continue
		if not team_filter.is_empty() and team_filter not in [book.away_team_id, book.home_team_id]:
			continue
		books.append(book)
	books.sort_custom(func(a: GameBookData, b: GameBookData):
		if a.week != b.week:
			return a.week > b.week
		return a.matchup_id < b.matchup_id
	)
	return books


static func metric_value(stats: StatLineData, stat_name: String) -> float:
	if stats == null:
		return 0.0
	match stat_name:
		"completion_percentage":
			return _percentage(stats.value("passing_completions"), stats.value("passing_attempts"))
		"passer_rating":
			return _passer_rating(stats)
		"yards_per_carry":
			return _average(stats.value("rushing_yards"), stats.value("rushing_attempts"))
		"yards_per_reception":
			return _average(stats.value("receiving_yards"), stats.value("receptions"))
		"field_goal_percentage":
			return _percentage(stats.value("field_goals_made"), stats.value("field_goal_attempts"))
		"punt_average":
			return _average(stats.value("punt_yards"), stats.value("punts"))
		"net_punt_average":
			return _average(stats.value("net_punt_yards"), stats.value("punts"))
		"total_tackles":
			return float(stats.value("tackles") + stats.value("assisted_tackles"))
		"points_per_game":
			return _average(stats.value("points"), stats.value("games_played"))
		"points_allowed_per_game":
			return _average(stats.value("points_allowed"), stats.value("games_played"))
		"yards_per_game":
			return _average(stats.value("total_yards"), stats.value("games_played"))
		"third_down_percentage":
			return _percentage(stats.value("third_down_conversions"), stats.value("third_down_attempts"))
		"fourth_down_percentage":
			return _percentage(stats.value("fourth_down_conversions"), stats.value("fourth_down_attempts"))
		_:
			return float(stats.value(stat_name))


static func format_metric(stats: StatLineData, stat_name: String) -> String:
	if stat_name in [
		"completion_percentage", "passer_rating", "yards_per_carry", "yards_per_reception",
		"field_goal_percentage", "punt_average", "net_punt_average", "points_per_game",
		"points_allowed_per_game", "yards_per_game", "third_down_percentage", "fourth_down_percentage",
	]:
		return "%.1f" % metric_value(stats, stat_name)
	return str(roundi(metric_value(stats, stat_name)))


static func _add_zero_player(
	metadata: Dictionary,
	accumulated: Dictionary,
	teams_by_player: Dictionary,
	player: PlayerData,
	team_id: String
) -> void:
	if not metadata.has(player.id):
		metadata[player.id] = {
			"player_id": player.id,
			"full_name": player.full_name,
			"position": player.position,
		}
	if not accumulated.has(player.id):
		accumulated[player.id] = StatLineData.new()
	if not teams_by_player.has(player.id):
		teams_by_player[player.id] = []
	var player_teams: Array = teams_by_player[player.id]
	if not team_id.is_empty() and not player_teams.has(team_id):
		player_teams.append(team_id)


static func _team_label(league: LeagueState, team_ids: Array) -> String:
	if team_ids.is_empty():
		return "FA"
	var labels: Array[String] = []
	for team_id in team_ids:
		var team := league.team_by_id(str(team_id))
		labels.append(team.abbreviation if team != null else str(team_id).to_upper())
	return "/".join(labels)


static func _phase_matches(actual_phase: String, phase_filter: String) -> bool:
	if phase_filter == PHASE_ALL:
		return true
	if phase_filter == PHASE_POSTSEASON:
		return actual_phase != PHASE_REGULAR
	return actual_phase == phase_filter


static func _average(total: int, attempts: int) -> float:
	return float(total) / float(attempts) if attempts > 0 else 0.0


static func _percentage(successes: int, attempts: int) -> float:
	return _average(successes * 100, attempts)


static func _passer_rating(stats: StatLineData) -> float:
	var attempts := stats.value("passing_attempts")
	if attempts <= 0:
		return 0.0
	var completions := stats.value("passing_completions")
	var yards := stats.value("passing_yards")
	var touchdowns := stats.value("passing_touchdowns")
	var interceptions := stats.value("passing_interceptions")
	var a := clampf((float(completions) / attempts - 0.3) * 5.0, 0.0, 2.375)
	var b := clampf((float(yards) / attempts - 3.0) * 0.25, 0.0, 2.375)
	var c := clampf(float(touchdowns) / attempts * 20.0, 0.0, 2.375)
	var d := clampf(2.375 - float(interceptions) / attempts * 25.0, 0.0, 2.375)
	return (a + b + c + d) / 6.0 * 100.0
