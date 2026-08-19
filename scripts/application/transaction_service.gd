class_name TransactionService
extends RefCounted


static func market_offer(
	league: LeagueState,
	team: TeamData,
	player: PlayerData,
	years: int,
	offer_multiplier: float = 1.0
) -> PlayerContract:
	var term := clampi(years, 1, 4)
	var premium := maxi(player.overall - 55, 0)
	var salary := float(950_000 + premium * premium * 15_000)
	salary *= _position_multiplier(player.position)
	salary *= lerpf(0.96, 1.15, _market_demand(league, player))
	var preferred_term := 4 if player.age <= 25 else (3 if player.age <= 29 else (2 if player.age <= 32 else 1))
	if term > preferred_term:
		salary *= 1.0 + float(term - preferred_term) * 0.035
	salary *= clampf(offer_multiplier, 0.80, 1.25)
	var rounded_salary := maxi(750_000, roundi(salary / 100_000.0) * 100_000)
	var role_name := projected_role(team, player)
	var guarantee_rate := 0.56 if role_name == "Franchise" else (0.42 if role_name == "Starter" else (0.28 if role_name == "Rotation" else 0.18))
	return PlayerContract.new(
		rounded_salary,
		term,
		roundi(float(rounded_salary * term) * guarantee_rate),
		league.contract_start_year(),
		role_name
	)


static func extension_offer(
	league: LeagueState,
	team: TeamData,
	player: PlayerData,
	years: int,
	offer_multiplier: float = 1.0
) -> PlayerContract:
	var contract := market_offer(league, team, player, years, offer_multiplier * 0.96)
	contract.role = projected_role(team, player)
	return contract


static func minimum_extension_multiplier(player: PlayerData) -> float:
	var threshold := 0.94
	if player.overall >= 88:
		threshold += 0.04
	if player.age >= 32:
		threshold -= 0.03
	return clampf(threshold, 0.88, 1.02)


static func extension_outlook(player: PlayerData, multiplier: float) -> String:
	var threshold := minimum_extension_multiplier(player)
	if multiplier + 0.001 >= threshold:
		return "PLAYER IS PREPARED TO RE-SIGN"
	if multiplier + 0.05 >= threshold:
		return "OFFER NEEDS IMPROVEMENT"
	return "PLAYER WILL TEST FREE AGENCY"


static func extend_player(
	league: LeagueState,
	team_id: String,
	player_id: String,
	years: int,
	offer_multiplier: float = 1.0
) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null or player.contract == null:
		return _failure("The selected player is not under contract with this club.")
	if not player.contract.is_expiring_after(league.season_year):
		return _failure("Only expiring contracts can be renewed during this stage.")
	if offer_multiplier + 0.001 < minimum_extension_multiplier(player):
		return _failure("%s declined the extension and intends to test the market." % player.full_name)
	var old_salary := player.contract.annual_salary
	var contract := extension_offer(league, team, player, years, offer_multiplier)
	var projected_payroll := team.payroll() - old_salary + contract.annual_salary
	if projected_payroll > team.salary_cap:
		return _failure("The extension needs %s more projected cap space." % PlayerContract.money_label(projected_payroll - team.salary_cap))
	player.contract = contract
	var details := "Extended %s on a %d-year, %s contract through %d." % [
		player.full_name,
		contract.years_remaining,
		PlayerContract.money_label(contract.total_value()),
		contract.expiration_year(),
	]
	_record(league, "Extension", team, player, details, contract.annual_salary - old_salary)
	return {"ok": true, "message": details, "contract": contract}


static func minimum_offer_multiplier(league: LeagueState, team: TeamData, player: PlayerData) -> float:
	var threshold := 0.88 + _market_demand(league, player) * 0.08
	var role_name := projected_role(team, player)
	if role_name == "Franchise":
		threshold += 0.04
	elif role_name == "Starter":
		threshold += 0.02
	return clampf(threshold, 0.88, 1.02)


static func offer_outlook(league: LeagueState, team: TeamData, player: PlayerData, multiplier: float) -> String:
	var threshold := minimum_offer_multiplier(league, team, player)
	if multiplier + 0.001 >= threshold:
		return "PLAYER IS PREPARED TO ACCEPT"
	if multiplier + 0.05 >= threshold:
		return "OFFER IS BELOW EXPECTATIONS"
	return "PLAYER WILL DECLINE THIS OFFER"


static func projected_role(team: TeamData, player: PlayerData) -> String:
	var starter := team.player_at(player.position)
	if player.overall >= 88 or starter == null or player.overall >= starter.overall + 3:
		return "Franchise" if player.overall >= 88 else "Starter"
	if player.overall >= starter.overall - 2:
		return "Starter"
	if player.overall >= starter.overall - 7:
		return "Rotation"
	return "Depth"


static func sign_free_agent(
	league: LeagueState,
	team_id: String,
	player_id: String,
	years: int,
	offer_multiplier: float = 1.0
) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := league.free_agent_by_id(player_id)
	if team == null or player == null:
		return _failure("The selected free agent is no longer available.")
	var required_multiplier := minimum_offer_multiplier(league, team, player)
	if offer_multiplier + 0.001 < required_multiplier:
		return _failure("%s rejected the offer as below market expectations." % player.full_name)
	var contract := market_offer(league, team, player, years, offer_multiplier)
	var validation_error := RosterValidator.signing_error(team, player, contract)
	if not validation_error.is_empty():
		return _failure(validation_error)
	league.free_agents.erase(player)
	player.contract = contract
	player.is_active = true
	if not team.add_player(player):
		player.contract = null
		league.free_agents.append(player)
		return _failure("The roster could not accept this signing.")
	var details := "Signed %s to a %d-year, %s contract with %s guaranteed." % [
		player.full_name,
		contract.years_remaining,
		PlayerContract.money_label(contract.total_value()),
		PlayerContract.money_label(contract.guaranteed_money),
	]
	_record(league, "Signing", team, player, details, contract.annual_salary)
	return {"ok": true, "message": details, "contract": contract}


static func release_player(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on this roster.")
	var validation_error := RosterValidator.release_error(team, player)
	if not validation_error.is_empty():
		return _failure(validation_error)
	var released_contract := player.contract
	var penalty := released_contract.release_penalty() if released_contract != null else 0
	var salary_removed := released_contract.annual_salary if released_contract != null else 0
	team.dead_cap += penalty
	team.remove_player(player.id)
	player.contract = null
	player.is_active = true
	league.free_agents.append(player)
	league.free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
	var details := "Released %s, clearing %s in salary and adding %s in dead cap." % [
		player.full_name,
		PlayerContract.money_label(salary_removed),
		PlayerContract.money_label(penalty),
	]
	_record(league, "Release", team, player, details, penalty - salary_removed)
	return {"ok": true, "message": details, "dead_cap": penalty}


static func run_ai_roster_moves(league: LeagueState) -> int:
	var move_count := 0
	for team in league.teams:
		if team.id == league.user_team_id:
			continue
		var candidate := _best_ai_candidate(league, team)
		if candidate == null:
			continue
		if not team.has_roster_space():
			var weakest := _weakest_player_at(team, candidate.position)
			if weakest == null or candidate.overall < weakest.overall + 3:
				continue
			var release_result := release_player(league, team.id, weakest.id)
			if not bool(release_result.get("ok", false)):
				continue
		var years := 4 if candidate.age <= 25 else (3 if candidate.age <= 29 else 2)
		var result := sign_free_agent(league, team.id, candidate.id, years, 1.05)
		if bool(result.get("ok", false)):
			move_count += 1
	return move_count


static func _best_ai_candidate(league: LeagueState, team: TeamData) -> PlayerData:
	var best: PlayerData
	var best_score := 0.0
	for candidate in league.free_agents:
		var position_players := team.players_at(candidate.position)
		if position_players.is_empty():
			return candidate
		var average := 0.0
		for roster_player in position_players:
			average += roster_player.overall
		average /= float(position_players.size())
		var score := float(candidate.overall) - average
		if position_players.size() <= 2:
			score += 2.5
		var offer := market_offer(league, team, candidate, 2, 1.05)
		if offer.annual_salary > team.cap_space():
			continue
		if score > best_score:
			best = candidate
			best_score = score
	return best


static func _weakest_player_at(team: TeamData, position_name: String) -> PlayerData:
	var weakest: PlayerData
	for player in team.players_at(position_name):
		if weakest == null or player.overall < weakest.overall:
			weakest = player
	return weakest


static func _market_demand(league: LeagueState, player: PlayerData) -> float:
	if league.teams.is_empty():
		return 0.0
	var interested := 0
	for team in league.teams:
		var starter := team.player_at(player.position)
		if starter == null or player.overall >= starter.overall - 3:
			interested += 1
	return float(interested) / float(league.teams.size())


static func _position_multiplier(position_name: String) -> float:
	match position_name:
		"QB":
			return 1.46
		"EDGE", "LT", "CB", "WR":
			return 1.18
		"DT", "LB", "S", "RT":
			return 1.09
		"K", "P":
			return 0.74
		_:
			return 1.0


static func _record(
	league: LeagueState,
	type_name: String,
	team: TeamData,
	player: PlayerData,
	details: String,
	cap_change: int
) -> void:
	var transaction := TransactionData.new(
		"transaction_%d_%d" % [league.season_year, league.transactions.size() + 1],
		league.season_year,
		league.current_week,
		type_name,
		team.id,
		player.id,
		player.full_name,
		details,
		cap_change
	)
	var verb := "sign"
	if type_name == "Release":
		verb = "release"
	elif type_name == "Extension":
		verb = "extend"
	league.record_transaction(transaction, "%s %s %s." % [team.display_name(), verb, player.full_name])


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
