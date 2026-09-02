class_name RetirementService
extends RefCounted

const MAX_FREE_AGENTS_BEFORE_DRAFT := 160
const MIN_FREE_AGENTS_PER_POSITION := 6
const RETIREMENT_AGES := {
	"QB": 34, "RB": 29, "WR": 30, "TE": 31,
	"LT": 32, "LG": 32, "C": 32, "RG": 32, "RT": 32,
	"EDGE": 31, "DT": 31, "LB": 30, "CB": 30, "S": 30,
	"K": 34, "P": 34, "LS": 34,
}
const HARD_RETIREMENT_AGES := {
	"QB": 44, "RB": 36, "WR": 38, "TE": 39,
	"LT": 41, "LG": 41, "C": 41, "RG": 41, "RT": 41,
	"EDGE": 39, "DT": 40, "LB": 38, "CB": 38, "S": 39,
	"K": 44, "P": 44, "LS": 44,
}


static func process_offseason(league: LeagueState) -> Dictionary:
	var retirement_year := league.season_year + 1
	if league.last_retirement_year == retirement_year:
		return {"ok": true, "retirements": 0, "market_exits": 0, "dead_cap": 0}
	var retirement_count := 0
	var dead_cap_total := 0
	for team in league.teams:
		for player: PlayerData in team.players.duplicate():
			if not should_retire(player, retirement_year, league.season_seed, false):
				continue
			var penalty: int = player.contract.retirement_penalty() if player.contract != null else 0
			team.dead_cap += penalty
			team.remove_player(player.id)
			_archive_player(league, player, team.id, retirement_year, "Retirement", _retirement_reason(player), penalty)
			_record_departure(league, player, team.id, retirement_year, penalty, "Retirement")
			retirement_count += 1
			dead_cap_total += penalty
	for player: PlayerData in league.free_agents.duplicate():
		if not should_retire(player, retirement_year, league.season_seed, true):
			continue
		league.free_agents.erase(player)
		var last_team_id: String = player.team_history.back() if not player.team_history.is_empty() else ""
		_archive_player(league, player, last_team_id, retirement_year, "Retirement", _retirement_reason(player), 0)
		_record_departure(league, player, last_team_id, retirement_year, 0, "Retirement")
		retirement_count += 1
	var market_exits := _balance_free_agent_market(league, retirement_year)
	league.last_retirement_year = retirement_year
	league.news.push_front("League personnel report: %d retirement%s and %d additional career exit%s recorded." % [
		retirement_count,
		"" if retirement_count == 1 else "s",
		market_exits,
		"" if market_exits == 1 else "s",
	])
	while league.news.size() > 12:
		league.news.pop_back()
	return {"ok": true, "retirements": retirement_count, "market_exits": market_exits, "dead_cap": dead_cap_total}


static func should_retire(player: PlayerData, retirement_year: int, league_seed: int, is_free_agent: bool) -> bool:
	var minimum_age := int(RETIREMENT_AGES.get(player.position, 31))
	var hard_age := int(HARD_RETIREMENT_AGES.get(player.position, 40))
	if player.age >= hard_age:
		return true
	if player.age < minimum_age:
		return false
	var probability := 0.04 + float(player.age - minimum_age) * 0.105
	probability += float(maxi(player.career_peak_overall - player.overall, 0)) * 0.018
	if player.overall < 65:
		probability += 0.16
	elif player.overall >= 85:
		probability -= 0.10
	if player.durability < 65:
		probability += 0.08
	if player.injury_weeks > 0:
		probability += 0.06
	if is_free_agent:
		probability += 0.05 + float(player.seasons_as_free_agent) * 0.045
	probability = clampf(probability, 0.02, 0.92)
	var roll_seed := absi(league_seed + retirement_year * 104729 + player.id.hash() * 31)
	var roll := float(roll_seed % 10_000) / 10_000.0
	return roll < probability


static func balance_free_agent_market(league: LeagueState, archive_year: int) -> int:
	return _balance_free_agent_market(league, archive_year)


static func _balance_free_agent_market(league: LeagueState, retirement_year: int) -> int:
	var exit_count := 0
	var guard := 0
	var guard_limit := league.free_agents.size() + 1
	while league.free_agents.size() > MAX_FREE_AGENTS_BEFORE_DRAFT and guard < guard_limit:
		var position_counts: Dictionary = {}
		for free_agent in league.free_agents:
			position_counts[free_agent.position] = int(position_counts.get(free_agent.position, 0)) + 1
		var candidate: PlayerData
		var candidate_score := 9999.0
		for player in league.free_agents:
			if int(position_counts.get(player.position, 0)) <= MIN_FREE_AGENTS_PER_POSITION:
				continue
			var score := float(player.overall) + float(player.potential) * 0.18
			score -= float(player.age - 21) * 0.45
			score -= float(player.seasons_as_free_agent) * 2.5
			if player.seasons_as_free_agent < 1 and player.age < int(RETIREMENT_AGES.get(player.position, 31)):
				score += 20.0
			if candidate == null or score < candidate_score:
				candidate = player
				candidate_score = score
		if candidate == null:
			break
		league.free_agents.erase(candidate)
		var last_team_id: String = candidate.team_history.back() if not candidate.team_history.is_empty() else ""
		var reason := "Left professional football after being unable to secure a roster role."
		if candidate.seasons_as_free_agent > 0:
			reason = "Left professional football after %d season%s without securing a roster role." % [candidate.seasons_as_free_agent, "" if candidate.seasons_as_free_agent == 1 else "s"]
		_archive_player(league, candidate, last_team_id, retirement_year, "League Exit", reason, 0)
		_record_departure(league, candidate, last_team_id, retirement_year, 0, "League Exit")
		exit_count += 1
		guard += 1
	return exit_count


static func _archive_player(
	league: LeagueState,
	player: PlayerData,
	final_team_id: String,
	retirement_year: int,
	departure_type: String,
	reason: String,
	dead_cap_charge: int
) -> void:
	var record := RetiredPlayerData.new(
		player.id,
		player.full_name,
		player.position,
		retirement_year,
		player.age,
		player.overall,
		maxi(player.career_peak_overall, player.overall),
		player.experience_years,
		final_team_id,
		player.original_team_id,
		player.entry_year,
		player.draft_round,
		player.draft_pick,
		player.archetype,
		player.personality,
		player.college,
		departure_type,
		reason,
		dead_cap_charge
	)
	record.team_history = player.team_history.duplicate()
	league.retired_players.append(record)


static func _record_departure(
	league: LeagueState,
	player: PlayerData,
	team_id: String,
	retirement_year: int,
	dead_cap_charge: int,
	departure_type: String
) -> void:
	var details := "%s ended their professional career after %d season%s." % [player.full_name, player.experience_years, "" if player.experience_years == 1 else "s"]
	if dead_cap_charge > 0:
		details += " The retirement creates %s in dead cap." % PlayerContract.money_label(dead_cap_charge)
	var transaction := TransactionData.new(
		"career_exit_%d_%s" % [retirement_year, player.id],
		retirement_year,
		0,
		departure_type,
		team_id,
		player.id,
		player.full_name,
		details,
		dead_cap_charge
	)
	league.record_transaction(transaction, "%s (%s) announces the end of their playing career." % [player.full_name, player.position])


static func _retirement_reason(player: PlayerData) -> String:
	var minimum_age := int(RETIREMENT_AGES.get(player.position, 31))
	if player.age >= int(HARD_RETIREMENT_AGES.get(player.position, 40)):
		return "Reached the end of a long professional career."
	if player.career_peak_overall - player.overall >= 7:
		return "Retired following a sustained decline from their career peak."
	if player.durability < 65 or player.injury_weeks > 0:
		return "Stepped away after the physical demands of their career."
	if player.age <= minimum_age + 1:
		return "Chose to step away while still capable of contributing."
	return "Retired after completing their professional career."
