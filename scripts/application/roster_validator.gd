class_name RosterValidator
extends RefCounted


static func validate_team(team: TeamData, require_full_roster: bool = false) -> Array[String]:
	var errors: Array[String] = []
	if team.players.size() < TeamData.MIN_ROSTER_SIZE:
		errors.append("Roster requires at least %d players." % TeamData.MIN_ROSTER_SIZE)
	if team.players.size() > team.roster_limit:
		errors.append("Roster exceeds the %d-player limit." % team.roster_limit)
	if require_full_roster and team.players.size() != team.roster_limit:
		errors.append("Roster must contain exactly %d players before the season begins." % team.roster_limit)
	if team.payroll() > team.salary_cap:
		errors.append("Payroll exceeds the salary cap by %s." % PlayerContract.money_label(team.payroll() - team.salary_cap))
	if team.practice_squad.size() > team.practice_squad_limit:
		errors.append("Practice squad exceeds the %d-player limit." % team.practice_squad_limit)
	for position_name in TeamData.ROSTER_POSITIONS:
		if position_name == "LS" and team.roster_limit < 53:
			continue
		if team.players_at(position_name).is_empty():
			errors.append("Roster does not contain a %s." % position_name)
	var ids: Dictionary = {}
	var veteran_count := 0
	for player in team.all_contract_players():
		if ids.has(player.id):
			errors.append("Club-controlled lists contain duplicate player ID %s." % player.id)
		ids[player.id] = true
		if player.contract == null:
			errors.append("%s does not have a valid contract." % player.full_name)
		if team.practice_squad.has(player) and player.experience_years > 3:
			veteran_count += 1
	if veteran_count > team.practice_squad_veteran_limit:
		errors.append("Practice squad exceeds the %d-player veteran allowance." % team.practice_squad_veteran_limit)
	return errors


static func validate_game_day_roster(team: TeamData, require_full_active_list: bool = true) -> Array[String]:
	var errors: Array[String] = []
	var healthy_count := 0
	for player in team.players:
		if player.injury_weeks <= 0:
			healthy_count += 1
	var expected_active := mini(team.game_day_active_limit, healthy_count)
	if team.active_roster_count() > team.game_day_active_limit:
		errors.append("Game-day list exceeds the %d-player active limit." % team.game_day_active_limit)
	elif require_full_active_list and team.active_roster_count() != expected_active:
		errors.append("Game-day list should activate %d healthy players." % expected_active)
	for position_name in TeamData.ROSTER_POSITIONS:
		if position_name == "LS" and team.roster_limit < TeamData.DEFAULT_ROSTER_LIMIT:
			continue
		var healthy_at_position := false
		for player in team.players_at(position_name):
			if player.injury_weeks <= 0:
				healthy_at_position = true
				break
		if healthy_at_position and team.players_at(position_name, true).is_empty():
			errors.append("Game-day list does not activate a healthy %s." % position_name)
	return errors


static func signing_error(team: TeamData, player: PlayerData, contract: PlayerContract) -> String:
	if player == null:
		return "The selected free agent is no longer available."
	if contract == null or contract.annual_salary <= 0:
		return "The contract offer is invalid."
	if team.owned_player_by_id(player.id) != null:
		return "That player is already controlled by the club."
	if not team.has_roster_space():
		return "The roster is already at its %d-player limit." % team.roster_limit
	var cap_hit := contract.current_cap_hit()
	var cap_space := team.cap_space_for_year(contract.current_year())
	if cap_hit > cap_space:
		return "The signing needs %s more cap space." % PlayerContract.money_label(cap_hit - cap_space)
	return ""


static func release_error(team: TeamData, player: PlayerData) -> String:
	if player == null or team.player_by_id(player.id) == null:
		return "The selected player is not on this roster."
	if team.players.size() <= TeamData.MIN_ROSTER_SIZE:
		return "The club must retain at least %d players." % TeamData.MIN_ROSTER_SIZE
	if team.players_at(player.position).size() <= 1:
		return "The club must retain at least one %s." % player.position
	return ""


static func practice_squad_error(team: TeamData, player: PlayerData) -> String:
	if player == null:
		return "The selected player is no longer available."
	if team.practice_squad.size() >= team.practice_squad_limit:
		return "The practice squad is at its %d-player limit." % team.practice_squad_limit
	if team.owned_player_by_id(player.id) != null:
		return "That player is already controlled by this club."
	if player.experience_years > 3:
		var veterans := 0
		for squad_player in team.practice_squad:
			if squad_player.experience_years > 3:
				veterans += 1
		if veterans >= team.practice_squad_veteran_limit:
			return "The practice squad has used all %d veteran allowances." % team.practice_squad_veteran_limit
	return ""
