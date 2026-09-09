class_name RosterTransactionService
extends RefCounted

const AI_PRACTICE_SQUAD_TARGET := 4


static func initialize_league(league: LeagueState) -> void:
	for team in league.teams:
		team.configure_roster_rules(league.league_format)
		for player in team.players:
			player.set_roster_status(PlayerData.STATUS_ACTIVE_ROSTER, league.current_week)
		team.configure_game_day_roster()
	for player in league.free_agents:
		player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)


static func place_on_injured_reserve(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on the 53-man roster.")
	if player.injury_weeks <= 0:
		return _failure("Only an injured player can be moved to injured reserve.")
	team.remove_player(player.id)
	player.set_roster_status(PlayerData.STATUS_INJURED_RESERVE, league.current_week)
	player.eligible_return_week = league.current_week + team.injured_reserve_minimum_weeks
	team.injured_reserve.append(player)
	team.configure_game_day_roster()
	var details := "Placed %s on injured reserve; eligible to return in Week %d." % [player.full_name, player.eligible_return_week]
	_record(league, "Injured Reserve", team, player, details, 0)
	return {"ok": true, "message": details, "player": player}


static func activate_from_injured_reserve(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.injured_reserve_player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on injured reserve.")
	if player.injury_weeks > 0:
		return _failure("%s still has %d recovery week%s remaining." % [player.full_name, player.injury_weeks, "" if player.injury_weeks == 1 else "s"])
	if league.current_week < player.eligible_return_week and not league.is_offseason():
		return _failure("%s cannot return before Week %d." % [player.full_name, player.eligible_return_week])
	if not team.has_roster_space():
		return _failure("Create a spot on the %d-player roster before activating %s." % [team.roster_limit, player.full_name])
	team.injured_reserve.erase(player)
	player.eligible_return_week = 0
	player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
	if not team.add_player(player):
		team.injured_reserve.append(player)
		player.set_roster_status(PlayerData.STATUS_INJURED_RESERVE, league.current_week)
		return _failure("The roster could not accept this activation.")
	team.configure_game_day_roster()
	var details := "Activated %s from injured reserve to the 53-man roster." % player.full_name
	_record(league, "IR Activation", team, player, details, 0)
	return {"ok": true, "message": details, "player": player}


static func set_game_day_active(league: LeagueState, team_id: String, player_id: String, active: bool) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on the active roster.")
	if active:
		if player.injury_weeks > 0:
			return _failure("An injured player cannot be activated for game day.")
		if player.is_active:
			return _failure("%s is already game-day active." % player.full_name)
		if team.active_roster_count() >= team.game_day_active_limit:
			return _failure("The game-day list is already at its %d-player limit." % team.game_day_active_limit)
		player.set_roster_status(PlayerData.STATUS_ACTIVE_ROSTER, league.current_week)
		return {"ok": true, "message": "%s is active for game day." % player.full_name}
	if not player.is_active:
		return _failure("%s is already game-day inactive." % player.full_name)
	player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
	var errors := RosterValidator.validate_game_day_roster(team, false)
	if not errors.is_empty():
		player.set_roster_status(PlayerData.STATUS_ACTIVE_ROSTER, league.current_week)
		return _failure(errors.front())
	return {"ok": true, "message": "%s is inactive for game day." % player.full_name}


static func sign_to_practice_squad(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := league.free_agent_by_id(player_id)
	if team == null or player == null:
		return _failure("The selected free agent is no longer available.")
	var validation_error := RosterValidator.practice_squad_error(team, player)
	if not validation_error.is_empty():
		return _failure(validation_error)
	var contract := PlayerContract.practice_squad_contract(player, league.contract_start_year())
	if contract.annual_salary > team.cap_space():
		return _failure("The practice-squad contract needs %s more cap space." % PlayerContract.money_label(contract.annual_salary - team.cap_space()))
	league.free_agents.erase(player)
	player.contract = contract
	player.record_team(team.id)
	player.set_roster_status(PlayerData.STATUS_PRACTICE_SQUAD, league.current_week)
	team.practice_squad.append(player)
	var details := "Signed %s to the practice squad on a %s contract." % [player.full_name, PlayerContract.money_label(contract.annual_salary)]
	_record(league, "Practice Squad Signing", team, player, details, contract.annual_salary)
	return {"ok": true, "message": details, "player": player}


static func move_to_practice_squad(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	if not league.is_offseason():
		return _failure("Direct practice-squad assignments are available during offseason roster decisions.")
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on the offseason roster.")
	var existing_contract := player.contract
	var practice_contract := PlayerContract.practice_squad_contract(player, league.contract_start_year())
	var current_salary := existing_contract.annual_salary if existing_contract != null else 0
	var penalty := existing_contract.release_penalty() if existing_contract != null else 0
	var additional_cap_cost := practice_contract.annual_salary + penalty - current_salary
	if additional_cap_cost > team.cap_space():
		return _failure("The practice-squad assignment needs %s more cap space after dead money." % PlayerContract.money_label(additional_cap_cost - team.cap_space()))
	team.remove_player(player.id)
	var validation_error := RosterValidator.practice_squad_error(team, player)
	if not validation_error.is_empty():
		team.add_player(player, league.league_format.offseason_roster_limit)
		return _failure(validation_error)
	team.dead_cap += penalty
	player.contract = practice_contract
	player.set_roster_status(PlayerData.STATUS_PRACTICE_SQUAD, league.current_week)
	team.practice_squad.append(player)
	var details := "Assigned %s to the practice squad during roster cutdowns." % player.full_name
	_record(league, "Practice Squad Assignment", team, player, details, penalty)
	return {"ok": true, "message": details, "player": player}


static func promote_from_practice_squad(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.practice_squad_player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on this practice squad.")
	if not team.has_roster_space() and not league.is_offseason():
		return _failure("Create a spot on the %d-player roster before promoting %s." % [team.roster_limit, player.full_name])
	var allowed_limit := league.league_format.offseason_roster_limit if league.is_offseason() else team.roster_limit
	if team.players.size() >= allowed_limit:
		return _failure("The offseason roster is already at its %d-player limit." % allowed_limit)
	var old_salary := player.contract.annual_salary if player.contract != null else 0
	var contract := PlayerContract.initial_contract(player, league.contract_start_year(), team.players_at(player.position).size())
	if contract.annual_salary - old_salary > team.cap_space():
		return _failure("The promotion needs %s more cap space." % PlayerContract.money_label(contract.annual_salary - old_salary - team.cap_space()))
	team.practice_squad.erase(player)
	player.contract = contract
	player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
	team.add_player(player, allowed_limit)
	team.configure_game_day_roster()
	var details := "Promoted %s from the practice squad to the active roster." % player.full_name
	_record(league, "Practice Squad Promotion", team, player, details, contract.annual_salary - old_salary)
	return {"ok": true, "message": details, "player": player}


static func release_from_practice_squad(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.practice_squad_player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on this practice squad.")
	var salary := player.contract.annual_salary if player.contract != null else 0
	team.practice_squad.erase(player)
	player.contract = null
	player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
	league.free_agents.append(player)
	_sort_free_agents(league)
	var details := "Released %s from the practice squad into free agency." % player.full_name
	_record(league, "Practice Squad Release", team, player, details, -salary)
	return {"ok": true, "message": details, "player": player}


static func poach_practice_squad_player(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var destination := league.team_by_id(team_id)
	var source := league.team_for_player(player_id)
	var player := source.practice_squad_player_by_id(player_id) if source != null else null
	if destination == null or source == null or player == null or source.id == destination.id:
		return _failure("The selected player is not available from another practice squad.")
	if not destination.has_roster_space():
		return _failure("A practice-squad signing must join the %d-player roster; create a spot first." % destination.roster_limit)
	var old_salary := player.contract.annual_salary if player.contract != null else 0
	var contract := PlayerContract.initial_contract(player, league.contract_start_year(), destination.players_at(player.position).size())
	if contract.annual_salary > destination.cap_space():
		return _failure("The signing needs %s more cap space." % PlayerContract.money_label(contract.annual_salary - destination.cap_space()))
	source.practice_squad.erase(player)
	player.contract = contract
	player.record_team(destination.id)
	player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
	destination.add_player(player)
	destination.configure_game_day_roster()
	var details := "Signed %s from %s's practice squad to the active roster." % [player.full_name, source.display_name()]
	_record(league, "Practice Squad Signing", destination, player, details, contract.annual_salary - old_salary)
	return {"ok": true, "message": details, "player": player, "former_team": source}


static func waive_player(league: LeagueState, team_id: String, player_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var player := team.player_by_id(player_id) if team != null else null
	if team == null or player == null:
		return _failure("The selected player is not on this roster.")
	var validation_error := RosterValidator.release_error(team, player)
	if not validation_error.is_empty():
		return _failure(validation_error)
	if league.is_offseason():
		return _release_directly(league, team, player)
	var contract := player.contract
	var salary_removed := contract.annual_salary if contract != null else 0
	var penalty := contract.release_penalty() if contract != null else 0
	team.dead_cap += penalty
	team.remove_player(player.id)
	player.set_roster_status(PlayerData.STATUS_WAIVERS, league.current_week)
	league.waiver_sequence += 1
	var entry := WaiverEntryData.new(
		"waiver_%d_%d" % [league.season_year, league.waiver_sequence],
		player,
		team.id,
		league.season_year,
		league.current_week,
		league.current_week + league.league_format.waiver_period_weeks
	)
	league.waiver_wire.append(entry)
	team.configure_game_day_roster()
	var details := "Waived %s, clearing %s in salary and adding %s in dead cap. Claims resolve after Week %d." % [player.full_name, PlayerContract.money_label(salary_removed), PlayerContract.money_label(penalty), entry.resolve_week]
	_record(league, "Waived", team, player, details, penalty - salary_removed)
	return {"ok": true, "message": details, "entry": entry, "dead_cap": penalty}


static func submit_waiver_claim(league: LeagueState, team_id: String, entry_id: String) -> Dictionary:
	var team := league.team_by_id(team_id)
	var entry := league.waiver_entry_by_id(entry_id)
	var validation_error := waiver_claim_error(league, team, entry)
	if not validation_error.is_empty():
		return _failure(validation_error)
	entry.add_claim(team.id)
	return {"ok": true, "message": "%s submitted a waiver claim for %s. Priority will decide the award." % [team.display_name(), entry.player.full_name], "entry": entry}


static func withdraw_waiver_claim(league: LeagueState, team_id: String, entry_id: String) -> Dictionary:
	var entry := league.waiver_entry_by_id(entry_id)
	if entry == null or not entry.remove_claim(team_id):
		return _failure("This club does not have a claim to withdraw.")
	return {"ok": true, "message": "The waiver claim for %s was withdrawn." % entry.player.full_name}


static func waiver_claim_error(league: LeagueState, team: TeamData, entry: WaiverEntryData) -> String:
	if team == null or entry == null or entry.player == null:
		return "The selected waiver entry is no longer available."
	if entry.has_claim(team.id):
		return "This club has already submitted a claim."
	if entry.waived_by_team_id == team.id:
		return "A club cannot reclaim the player it just waived."
	if not team.has_roster_space():
		return "Create a spot on the %d-player roster before submitting a claim." % team.roster_limit
	var salary := entry.player.contract.annual_salary if entry.player.contract != null else 0
	if salary > team.cap_space():
		return "The claimed contract needs %s more cap space." % PlayerContract.money_label(salary - team.cap_space())
	return ""


static func resolve_waivers(league: LeagueState, force: bool = false) -> Dictionary:
	var awarded := 0
	var cleared := 0
	var priority := waiver_priority(league)
	for entry in league.waiver_wire.duplicate():
		if not force and league.current_week < entry.resolve_week:
			continue
		var winner: TeamData
		for team in priority:
			if entry.has_claim(team.id) and waiver_claim_error_for_resolution(team, entry).is_empty():
				winner = team
				break
		league.waiver_wire.erase(entry)
		if winner != null:
			var player: PlayerData = entry.player
			if player.contract == null:
				player.contract = PlayerContract.initial_contract(player, league.contract_start_year(), winner.players_at(player.position).size())
			player.record_team(winner.id)
			player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
			winner.add_player(player)
			winner.configure_game_day_roster()
			var details := "%s claimed %s on waivers from %s." % [winner.display_name(), player.full_name, _team_label(league, entry.waived_by_team_id)]
			_record(league, "Waiver Claim", winner, player, details, player.contract.annual_salary)
			awarded += 1
		else:
			var player: PlayerData = entry.player
			player.contract = null
			player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
			league.free_agents.append(player)
			var former_team := league.team_by_id(entry.waived_by_team_id)
			if former_team != null:
				_record(league, "Cleared Waivers", former_team, player, "%s cleared waivers and entered free agency." % player.full_name, 0)
			cleared += 1
	_sort_free_agents(league)
	return {"ok": true, "message": "%d waiver claim%s awarded; %d player%s cleared." % [awarded, "" if awarded == 1 else "s", cleared, "" if cleared == 1 else "s"], "awarded": awarded, "cleared": cleared}


static func waiver_priority(league: LeagueState) -> Array[TeamData]:
	var ordered: Array[TeamData] = []
	var standings := league.sorted_standings()
	standings.reverse()
	for standing in standings:
		var team := league.team_by_id(standing.team_id)
		if team != null:
			ordered.append(team)
	return ordered


static func waiver_priority_rank(league: LeagueState, team_id: String) -> int:
	var priority := waiver_priority(league)
	for index in range(priority.size()):
		if priority[index].id == team_id:
			return index + 1
	return 0


static func run_ai_roster_management(league: LeagueState) -> int:
	var move_count := 0
	for team in league.teams:
		for player in team.injured_reserve:
			if player.injury_weeks > 0:
				player.advance_injury_week()
			player.recover_for_new_week()
		if team.id == league.user_team_id:
			continue
		for player in team.players.duplicate():
			if player.injury_weeks >= 2:
				var ir_result := place_on_injured_reserve(league, team.id, player.id)
				if bool(ir_result.get("ok", false)):
					move_count += 1
		var returners := team.injured_reserve.duplicate()
		returners.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		for player: PlayerData in returners:
			if team.has_roster_space() and player.injury_weeks <= 0 and league.current_week >= player.eligible_return_week:
				var activation := activate_from_injured_reserve(league, team.id, player.id)
				if bool(activation.get("ok", false)):
					move_count += 1
		while team.has_roster_space() and not team.practice_squad.is_empty():
			var promotion := _best_practice_squad_promotion(team)
			if promotion == null:
				break
			var promoted := promote_from_practice_squad(league, team.id, promotion.id)
			if not bool(promoted.get("ok", false)):
				break
			move_count += 1
			if team.players.size() >= team.roster_limit:
				break
	_submit_ai_claims(league)
	var resolution := resolve_waivers(league)
	move_count += int(resolution.get("awarded", 0)) + int(resolution.get("cleared", 0))
	for team in league.teams:
		if team.id == league.user_team_id:
			if not RosterValidator.validate_game_day_roster(team).is_empty():
				team.configure_game_day_roster()
			continue
		while team.practice_squad.size() < mini(AI_PRACTICE_SQUAD_TARGET, team.practice_squad_limit):
			var candidate := _best_practice_squad_candidate(league, team)
			if candidate == null:
				break
			var signed := sign_to_practice_squad(league, team.id, candidate.id)
			if not bool(signed.get("ok", false)):
				break
			move_count += 1
		team.configure_game_day_roster()
	return move_count


static func prepare_offseason(league: LeagueState) -> void:
	resolve_waivers(league, true)
	for team in league.teams:
		for player in team.injured_reserve.duplicate():
			team.injured_reserve.erase(player)
			player.eligible_return_week = 0
			player.set_roster_status(PlayerData.STATUS_GAME_DAY_INACTIVE, league.current_week)
			team.add_player(player, league.league_format.offseason_roster_limit)
		team.initialize_depth_chart()


static func prepare_new_season(league: LeagueState) -> void:
	for team in league.teams:
		team.configure_roster_rules(league.league_format)
		for player in team.players:
			player.eligible_return_week = 0
		team.configure_game_day_roster()
	for player in league.free_agents:
		player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)


static func waiver_claim_error_for_resolution(team: TeamData, entry: WaiverEntryData) -> String:
	if not team.has_roster_space():
		return "Roster full"
	var salary := entry.player.contract.annual_salary if entry.player.contract != null else 0
	return "Insufficient cap" if salary > team.cap_space() else ""


static func _submit_ai_claims(league: LeagueState) -> void:
	for entry in league.waiver_wire:
		for team in league.teams:
			if team.id == league.user_team_id or team.id == entry.waived_by_team_id or entry.has_claim(team.id):
				continue
			if not waiver_claim_error_for_resolution(team, entry).is_empty():
				continue
			var room := team.players_at(entry.player.position)
			var weakest: PlayerData
			for roster_player in room:
				if weakest == null or roster_player.overall < weakest.overall:
					weakest = roster_player
			var need := room.is_empty() or entry.player.overall >= weakest.overall + 3
			var roll := absi(league.season_seed + league.current_week * 1009 + entry.player.id.hash() + team.id.hash()) % 100
			if need and roll < 42:
				entry.add_claim(team.id)


static func _best_practice_squad_promotion(team: TeamData) -> PlayerData:
	var best: PlayerData
	var best_score := -9999
	for player in team.practice_squad:
		var score := player.overall + (12 if team.players_at(player.position).is_empty() else 0)
		if best == null or score > best_score:
			best = player
			best_score = score
	return best


static func _best_practice_squad_candidate(league: LeagueState, team: TeamData) -> PlayerData:
	var best: PlayerData
	var best_score := -9999
	for player in league.free_agents:
		if not RosterValidator.practice_squad_error(team, player).is_empty():
			continue
		var contract := PlayerContract.practice_squad_contract(player, league.contract_start_year())
		if contract.annual_salary > team.cap_space():
			continue
		var score := player.overall + (8 if team.players_at(player.position).size() <= 1 else 0) - maxi(player.age - 25, 0)
		if best == null or score > best_score:
			best = player
			best_score = score
	return best


static func _release_directly(league: LeagueState, team: TeamData, player: PlayerData) -> Dictionary:
	var contract := player.contract
	var salary_removed := contract.annual_salary if contract != null else 0
	var penalty := contract.release_penalty() if contract != null else 0
	team.dead_cap += penalty
	team.remove_player(player.id)
	player.contract = null
	player.set_roster_status(PlayerData.STATUS_FREE_AGENT, league.current_week)
	league.free_agents.append(player)
	_sort_free_agents(league)
	var details := "Released %s, clearing %s in salary and adding %s in dead cap." % [player.full_name, PlayerContract.money_label(salary_removed), PlayerContract.money_label(penalty)]
	_record(league, "Release", team, player, details, penalty - salary_removed)
	return {"ok": true, "message": details, "dead_cap": penalty}


static func _record(league: LeagueState, type_name: String, team: TeamData, player: PlayerData, details: String, cap_change: int) -> void:
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
	league.record_transaction(transaction, details)


static func _sort_free_agents(league: LeagueState) -> void:
	league.free_agents.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)


static func _team_label(league: LeagueState, team_id: String) -> String:
	var team := league.team_by_id(team_id)
	return team.display_name() if team != null else "his former club"


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}
