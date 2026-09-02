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
	for position_name in TeamData.ROSTER_POSITIONS:
		if position_name == "LS" and team.roster_limit < 53:
			continue
		if team.players_at(position_name).is_empty():
			errors.append("Roster does not contain a %s." % position_name)
	var ids: Dictionary = {}
	for player in team.players:
		if ids.has(player.id):
			errors.append("Roster contains duplicate player ID %s." % player.id)
		ids[player.id] = true
		if player.contract == null:
			errors.append("%s does not have a valid contract." % player.full_name)
	return errors


static func signing_error(team: TeamData, player: PlayerData, contract: PlayerContract) -> String:
	if player == null:
		return "The selected free agent is no longer available."
	if contract == null or contract.annual_salary <= 0:
		return "The contract offer is invalid."
	if team.player_by_id(player.id) != null:
		return "That player is already on the roster."
	if not team.has_roster_space():
		return "The roster is already at its %d-player limit." % team.roster_limit
	if contract.annual_salary > team.cap_space():
		return "The signing needs %s more cap space." % PlayerContract.money_label(contract.annual_salary - team.cap_space())
	return ""


static func release_error(team: TeamData, player: PlayerData) -> String:
	if player == null or team.player_by_id(player.id) == null:
		return "The selected player is not on this roster."
	if team.players.size() <= TeamData.MIN_ROSTER_SIZE:
		return "The club must retain at least %d players." % TeamData.MIN_ROSTER_SIZE
	if team.players_at(player.position).size() <= 1:
		return "The club must retain at least one %s." % player.position
	return ""
