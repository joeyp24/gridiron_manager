class_name OffseasonService
extends RefCounted

const POSITION_DECLINE_AGE := {
	"QB": 33, "RB": 27, "WR": 29, "TE": 30,
	"LT": 31, "LG": 31, "C": 31, "RG": 31, "RT": 31,
	"EDGE": 30, "DT": 31, "LB": 29, "CB": 29, "S": 30,
	"K": 35, "P": 35, "LS": 35,
}
const POSITION_SPEED_DECLINE_AGE := {
	"QB": 31, "RB": 27, "WR": 28, "TE": 29,
	"EDGE": 29, "LB": 28, "CB": 28, "S": 29,
	"K": 33, "P": 33, "LS": 33,
}


static func advance_stage(league: LeagueState) -> Dictionary:
	match league.phase:
		LeagueState.PHASE_SEASON_REVIEW, "Complete":
			RosterTransactionService.prepare_offseason(league)
			_open_new_league_finances(league)
			var extensions := run_ai_re_signing(league)
			league.phase = LeagueState.PHASE_RE_SIGNING
			league.news.push_front("Re-signing is open. %d league contract%s completed." % [extensions, " was" if extensions == 1 else "s were"])
			_trim_news(league)
			return _success("Re-signing is now open. Review your expiring contracts.")
		LeagueState.PHASE_RE_SIGNING:
			var expirations := advance_contracts(league)
			ensure_replacement_market(league)
			var reports := develop_players(league)
			league.phase = LeagueState.PHASE_PLAYER_DEVELOPMENT
			league.news.push_front("Development reviews are complete for %d players; %d contracts expired." % [reports, expirations])
			_trim_news(league)
			return _success("Contract decisions are final and development reports are ready.")
		LeagueState.PHASE_PLAYER_DEVELOPMENT:
			var retirement_result := RetirementService.process_offseason(league)
			ensure_replacement_market(league)
			league.phase = LeagueState.PHASE_RETIREMENTS
			return _success("Career decisions are complete: %d retirements and %d additional league exits." % [int(retirement_result.get("retirements", 0)), int(retirement_result.get("market_exits", 0))])
		LeagueState.PHASE_RETIREMENTS:
			if league.current_draft == null:
				league.current_draft = DraftService.create_draft(league)
			league.phase = LeagueState.PHASE_DRAFT_PREPARATION
			league.news.push_front("The %d rookie class is available. Scouting assignments are now open." % league.current_draft.draft_year)
			_trim_news(league)
			return _success("Draft preparation is open. Scout the class and build your board.")
		LeagueState.PHASE_DRAFT_PREPARATION:
			return DraftService.start_draft(league)
		LeagueState.PHASE_DRAFT:
			return {"ok": false, "message": "Complete your selections in the Draft Center before advancing."}
		LeagueState.PHASE_ROSTER_DECISIONS:
			prepare_post_draft_ai_rosters(league)
			var errors := RosterValidator.validate_team(
				league.user_team(),
				league.league_format.roster_size >= TeamData.DEFAULT_ROSTER_LIMIT
			)
			if not errors.is_empty():
				return {"ok": false, "message": "Your roster is not ready for the new league year.", "errors": errors}
			start_new_league_year(league)
			return _success("The %d season is underway." % league.season_year)
	return {"ok": false, "message": "The league is not currently in an offseason stage."}


static func advance_contracts(league: LeagueState) -> int:
	var expiration_count := 0
	for team in league.teams:
		for player in team.all_contract_players():
			if player.contract == null or player.contract.signed_year > league.season_year:
				continue
			if player.contract.is_expiring_after(league.season_year):
				team.remove_owned_player(player.id)
				player.contract = null
				player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
				league.free_agents.append(player)
				_record_expiration(league, team, player)
				expiration_count += 1
			else:
				player.contract.years_remaining = maxi(1, player.contract.expiration_year() - league.season_year)
	league.free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return expiration_count


static func develop_players(league: LeagueState) -> int:
	var report_year := league.season_year + 1
	for existing in league.development_reports:
		if existing.season_year == report_year:
			return 0
	var report_count := 0
	for team in league.teams:
		for player in team.all_contract_players():
			league.development_reports.append(_develop_player(league, player, team.id, report_year))
			report_count += 1
	for player in league.free_agents:
		league.development_reports.append(_develop_player(league, player, "", report_year))
		report_count += 1
	while league.development_reports.size() > 2500:
		league.development_reports.pop_front()
	return report_count


static func run_ai_re_signing(league: LeagueState) -> int:
	var extension_count := 0
	for team in league.teams:
		if team.id == league.user_team_id:
			continue
		var expiring: Array[PlayerData] = []
		for player in team.all_contract_players():
			if player.contract != null and player.contract.is_expiring_after(league.season_year):
				expiring.append(player)
		expiring.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		for player in expiring:
			var required_depth := team.players_at(player.position).size() <= 1
			var age_threshold := 82 if player.age >= 33 else (76 if player.age >= 30 else 70)
			if not required_depth and player.overall < age_threshold:
				continue
			var years := 1 if player.age >= 33 else (2 if player.age >= 30 else (3 if player.age >= 26 else 4))
			var proposed := TransactionService.extension_offer(league, team, player, years, 1.05)
			var projected_payroll := team.payroll() - player.contract.annual_salary + proposed.annual_salary
			if projected_payroll > team.salary_cap - 15_000_000:
				continue
			var result := TransactionService.extend_player(league, team.id, player.id, years, 1.05)
			if bool(result.get("ok", false)):
				extension_count += 1
	return extension_count


static func run_ai_offseason_roster_building(league: LeagueState) -> int:
	var move_count := 0
	for team in league.teams:
		if team.id == league.user_team_id:
			continue
		for position_name in TeamData.ROSTER_POSITIONS:
			if not team.players_at(position_name).is_empty():
				continue
			if not team.has_roster_space():
				var release_candidate := _best_ai_release_candidate(team)
				if release_candidate != null:
					var release_result := TransactionService.release_player(league, team.id, release_candidate.id)
					if bool(release_result.get("ok", false)):
						move_count += 1
			var required_candidate := _best_affordable_candidate(league, team, position_name, true)
			if required_candidate != null and _ai_sign(league, team, required_candidate):
				move_count += 1
		var guard := 0
		while team.players.size() < team.roster_limit and guard < 120:
			var candidate := _best_affordable_candidate(league, team, "", true)
			if candidate == null or not _ai_sign(league, team, candidate):
				break
			move_count += 1
			guard += 1
	return move_count


static func prepare_post_draft_ai_rosters(league: LeagueState) -> int:
	var move_count := 0
	for team in league.teams:
		if team.id == league.user_team_id:
			continue
		move_count += _trim_ai_practice_squad(league, team)
		var guard := 0
		while (team.players.size() > team.roster_limit or team.cap_space() < 0) and guard < 80:
			var candidate := _best_ai_release_candidate(team)
			if candidate == null:
				break
			var result := RosterTransactionService.move_to_practice_squad(league, team.id, candidate.id)
			if not bool(result.get("ok", false)):
				result = TransactionService.release_player(league, team.id, candidate.id)
			if not bool(result.get("ok", false)):
				break
			move_count += 1
			guard += 1
	ensure_replacement_market(league)
	move_count += run_ai_offseason_roster_building(league)
	return move_count


static func _trim_ai_practice_squad(league: LeagueState, team: TeamData) -> int:
	var release_count := 0
	var guard := 0
	while guard < 40:
		var veterans: Array[PlayerData] = []
		for player in team.practice_squad:
			if player.experience_years > 3:
				veterans.append(player)
		var over_total := team.practice_squad.size() - team.practice_squad_limit
		var over_veterans := veterans.size() - team.practice_squad_veteran_limit
		if over_total <= 0 and over_veterans <= 0:
			break
		var candidates := veterans if over_veterans > 0 else team.practice_squad.duplicate()
		candidates.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall < b.overall)
		if candidates.is_empty():
			break
		var result := RosterTransactionService.release_from_practice_squad(league, team.id, candidates.front().id)
		if not bool(result.get("ok", false)):
			break
		release_count += 1
		guard += 1
	return release_count


static func ensure_replacement_market(league: LeagueState) -> int:
	var additions := 0
	for position_name in TeamData.ROSTER_POSITIONS:
		var missing_slots := 0
		for team in league.teams:
			if team.players_at(position_name).is_empty():
				missing_slots += 1
		var available := 0
		for player in league.free_agents:
			if player.position == position_name and player.overall <= 65:
				available += 1
		while available < missing_slots + 1:
			var replacement := _unique_replacement(league, position_name, additions)
			replacement.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
			league.free_agents.append(replacement)
			available += 1
			additions += 1
	var total_deficit := 0
	for team in league.teams:
		total_deficit += maxi(team.roster_limit - team.players.size(), 0)
	var affordable_count := 0
	for player in league.free_agents:
		if player.overall <= 65:
			affordable_count += 1
	var position_index := 0
	while affordable_count < total_deficit + league.teams.size():
		var position_name := TeamData.ROSTER_POSITIONS[position_index % TeamData.ROSTER_POSITIONS.size()]
		var replacement := _unique_replacement(league, position_name, additions)
		replacement.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
		league.free_agents.append(replacement)
		additions += 1
		affordable_count += 1
		position_index += 1
	league.free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	return additions


static func start_new_league_year(league: LeagueState) -> void:
	RetirementService.balance_free_agent_market(league, league.season_year + 1)
	if league.current_draft != null and league.current_draft.is_complete():
		var already_archived := false
		for archived in league.draft_history:
			if archived.draft_year == league.current_draft.draft_year:
				already_archived = true
				break
		if not already_archived:
			league.draft_history.append(league.current_draft)
		while league.draft_history.size() > 10:
			league.draft_history.pop_front()
	league.current_draft = null
	league.season_year += 1
	TradeService.prune_past_draft_picks(league)
	TradeService.ensure_future_draft_picks(league)
	league.current_week = 1
	league.prepared_week = 0
	league.phase = LeagueState.PHASE_REGULAR_SEASON
	league.champion_team_id = ""
	league.season_seed = absi(league.season_seed * 31 + league.season_year * 7919) % 2_147_483_647
	league.standings.clear()
	for team in league.teams:
		team.dead_cap = 0
		for player in team.all_contract_players():
			player.advance_to_league_year(league.season_year, false)
			player.energy = 100
			player.injury_type = ""
			player.injury_weeks = 0
		team.initialize_depth_chart()
		league.standings[team.id] = StandingData.new(team.id)
	for player in league.free_agents:
		player.advance_to_league_year(league.season_year, true)
		player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
	RosterTransactionService.prepare_new_season(league)
	league.playoff_seeds.clear()
	league.schedule = ScheduleGenerator.from_template(
		league.schedule_template,
		league.teams,
		league.season_year,
		league.league_format.template_season
	) if not league.schedule_template.is_empty() else ScheduleGenerator.round_robin(league.teams, league.season_year, league.season_seed)
	league.news.push_front("The %d %s season is ready for kickoff." % [league.season_year, league.league_name])
	_trim_news(league)


static func _develop_player(league: LeagueState, player: PlayerData, team_id: String, report_year: int) -> DevelopmentReportData:
	var rng := RandomNumberGenerator.new()
	rng.seed = league.season_seed + league.season_year * 104729 + player.id.hash()
	var old_age := player.age
	var old_overall := player.overall
	var overall_delta := _development_delta(player, rng)
	player.overall = clampi(player.overall + overall_delta, 45, 99)
	if overall_delta > 0:
		player.overall = mini(player.overall, player.potential)
	if player.madden_ratings != null:
		player.madden_ratings.apply_overall_delta(player.overall - old_overall)
	var changes := {}
	for attribute_name in ["speed", "power", "technique", "awareness", "durability"]:
		var old_value := int(player.get(attribute_name))
		var attribute_delta := overall_delta + rng.randi_range(-1, 1)
		if attribute_name == "speed" and old_age >= int(POSITION_SPEED_DECLINE_AGE.get(player.position, 30)):
			attribute_delta -= 1
		if attribute_name == "awareness" and old_age >= 27:
			attribute_delta += rng.randi_range(0, 1)
		var new_value := clampi(old_value + attribute_delta, 40, 99)
		player.set(attribute_name, new_value)
		changes[attribute_name] = new_value - old_value
	player.age += 1
	player.experience_years = maxi(report_year - player.entry_year, 0)
	player.career_peak_overall = maxi(player.career_peak_overall, player.overall)
	player.energy = 100
	return DevelopmentReportData.new(
		report_year,
		player.id,
		player.full_name,
		team_id,
		player.position,
		old_age,
		player.age,
		old_overall,
		player.overall,
		player.potential,
		changes
	)


static func _development_delta(player: PlayerData, rng: RandomNumberGenerator) -> int:
	var upside := maxi(player.potential - player.overall, 0)
	var decline_age := int(POSITION_DECLINE_AGE.get(player.position, 30))
	if player.age <= 22:
		return rng.randi_range(1 if upside > 0 else 0, mini(4, upside)) if upside > 0 else 0
	if player.age <= 25:
		return rng.randi_range(0, mini(3, upside)) if upside > 0 else rng.randi_range(-1, 0)
	if player.age <= mini(28, decline_age - 2):
		return rng.randi_range(-1, mini(2, upside))
	if player.age <= decline_age:
		return rng.randi_range(-1, mini(1, upside))
	if player.age <= decline_age + 3:
		return rng.randi_range(-2, 0)
	return rng.randi_range(-3, -1)


static func _best_affordable_candidate(
	league: LeagueState,
	team: TeamData,
	position_name: String = "",
	prefer_affordable: bool = false
) -> PlayerData:
	var best: PlayerData
	var best_salary := 0
	for player in league.free_agents:
		if not position_name.is_empty() and player.position != position_name:
			continue
		var offer := TransactionService.market_offer(league, team, player, 1 if player.age >= 31 else 2, 1.10)
		if offer.annual_salary > team.cap_space():
			continue
		if best == null or (prefer_affordable and offer.annual_salary < best_salary) or (not prefer_affordable and player.overall > best.overall):
			best = player
			best_salary = offer.annual_salary
	return best


static func _best_ai_release_candidate(team: TeamData) -> PlayerData:
	var candidate: PlayerData
	var candidate_score := -9999.0
	for player in team.players:
		if player.contract != null and player.contract.role == "Rookie":
			continue
		if team.players_at(player.position).size() <= 1:
			continue
		var salary := player.contract.annual_salary if player.contract != null else 0
		var penalty := player.contract.release_penalty() if player.contract != null else 0
		var savings := maxi(salary - penalty, 0)
		var score := float(100 - player.overall) + float(savings) / 1_000_000.0 * 1.8
		if player.age >= 31:
			score += float(player.age - 30) * 1.5
		if candidate == null or score > candidate_score:
			candidate = player
			candidate_score = score
	return candidate


static func _unique_replacement(league: LeagueState, position_name: String, starting_index: int) -> PlayerData:
	var market_index := starting_index
	while true:
		var replacement := PlayerGenerator.generate_replacement(position_name, league.season_year + 1, market_index, league.season_seed)
		if league.free_agent_by_id(replacement.id) == null:
			return replacement
		market_index += 1
	return null


static func _ai_sign(league: LeagueState, team: TeamData, player: PlayerData) -> bool:
	var years := 1 if player.age >= 31 else (3 if player.age <= 26 else 2)
	var result := TransactionService.sign_free_agent(league, team.id, player.id, years, 1.10)
	return bool(result.get("ok", false))


static func _record_expiration(league: LeagueState, team: TeamData, player: PlayerData) -> void:
	var details := "%s's contract expired; the player entered free agency." % player.full_name
	var transaction := TransactionData.new(
		"transaction_%d_%d" % [league.season_year, league.transactions.size() + 1],
		league.season_year,
		league.current_week,
		"Expiration",
		team.id,
		player.id,
		player.full_name,
		details,
		0
	)
	league.record_transaction(transaction, "%s allows %s's contract to expire." % [team.display_name(), player.full_name])


static func _open_new_league_finances(league: LeagueState) -> void:
	for team in league.teams:
		team.salary_cap = roundi(float(team.salary_cap) * 1.07 / 100_000.0) * 100_000
		team.dead_cap = 0


static func _trim_news(league: LeagueState) -> void:
	while league.news.size() > 12:
		league.news.pop_back()


static func _success(message: String) -> Dictionary:
	return {"ok": true, "message": message}
