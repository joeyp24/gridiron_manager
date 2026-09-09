class_name LeagueFormatData
extends RefCounted

var id := "legacy_eight"
var team_count := 8
var roster_size := 45
var offseason_roster_limit := 52
var game_day_active_limit := 45
var practice_squad_limit := 8
var practice_squad_veteran_limit := 4
var injured_reserve_minimum_weeks := 4
var waiver_period_weeks := 1
var regular_season_weeks := 7
var games_per_team := 7
var playoff_teams_per_conference := 1
var postseason_weeks := 1
var schedule_type := "round_robin"
var template_season := 2026


static func legacy_eight() -> LeagueFormatData:
	return LeagueFormatData.new()


static func nfl_32() -> LeagueFormatData:
	var format := LeagueFormatData.new()
	format.id = "nfl_32"
	format.team_count = 32
	format.roster_size = 53
	format.offseason_roster_limit = 90
	format.game_day_active_limit = 48
	format.practice_squad_limit = 16
	format.practice_squad_veteran_limit = 6
	format.injured_reserve_minimum_weeks = 4
	format.waiver_period_weeks = 1
	format.regular_season_weeks = 18
	format.games_per_team = 17
	format.playoff_teams_per_conference = 7
	format.postseason_weeks = 4
	format.schedule_type = "nflverse_template"
	format.template_season = 2026
	return format


func championship_week() -> int:
	return regular_season_weeks + postseason_weeks


func to_dict() -> Dictionary:
	return {
		"id": id,
		"team_count": team_count,
		"roster_size": roster_size,
		"offseason_roster_limit": offseason_roster_limit,
		"game_day_active_limit": game_day_active_limit,
		"practice_squad_limit": practice_squad_limit,
		"practice_squad_veteran_limit": practice_squad_veteran_limit,
		"injured_reserve_minimum_weeks": injured_reserve_minimum_weeks,
		"waiver_period_weeks": waiver_period_weeks,
		"regular_season_weeks": regular_season_weeks,
		"games_per_team": games_per_team,
		"playoff_teams_per_conference": playoff_teams_per_conference,
		"postseason_weeks": postseason_weeks,
		"schedule_type": schedule_type,
		"template_season": template_season,
	}


static func from_dict(data: Dictionary, fallback_team_count: int = 8) -> LeagueFormatData:
	var format := nfl_32() if fallback_team_count >= 32 else legacy_eight()
	format.id = str(data.get("id", format.id))
	format.team_count = int(data.get("team_count", fallback_team_count))
	format.roster_size = int(data.get("roster_size", format.roster_size))
	format.offseason_roster_limit = int(data.get("offseason_roster_limit", format.offseason_roster_limit))
	format.game_day_active_limit = int(data.get("game_day_active_limit", format.game_day_active_limit))
	format.practice_squad_limit = int(data.get("practice_squad_limit", format.practice_squad_limit))
	format.practice_squad_veteran_limit = int(data.get("practice_squad_veteran_limit", format.practice_squad_veteran_limit))
	format.injured_reserve_minimum_weeks = int(data.get("injured_reserve_minimum_weeks", format.injured_reserve_minimum_weeks))
	format.waiver_period_weeks = int(data.get("waiver_period_weeks", format.waiver_period_weeks))
	format.regular_season_weeks = int(data.get("regular_season_weeks", format.regular_season_weeks))
	format.games_per_team = int(data.get("games_per_team", format.games_per_team))
	format.playoff_teams_per_conference = int(data.get("playoff_teams_per_conference", format.playoff_teams_per_conference))
	format.postseason_weeks = int(data.get("postseason_weeks", format.postseason_weeks))
	format.schedule_type = str(data.get("schedule_type", format.schedule_type))
	format.template_season = int(data.get("template_season", format.template_season))
	return format
