extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var career := CareerSession.new_career("nfl_buf", 862091, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var league := career.league
	var user_team := career.user_team()
	var partner: TeamData = league.teams[1] if league.teams[1].id != user_team.id else league.teams[2]
	_check(league.teams.size() == 32, "Trade validation must run against all 32 clubs")
	_check(league.future_draft_picks.size() == 32 * DraftService.ROUNDS * TradeService.FUTURE_PICK_YEARS, "The full league must reserve 672 tradable future picks")
	_check(TradeService.picks_owned_by(league, user_team.id).size() == DraftService.ROUNDS * TradeService.FUTURE_PICK_YEARS, "Every club must begin with 21 owned future picks")
	var user_pick := TradeService.future_pick_for(league, league.season_year + 1, 3, user_team.id)
	var partner_pick := TradeService.future_pick_for(league, league.season_year + 1, 4, partner.id)
	var legal_pair := _legal_player_pair(career, partner, user_pick, partner_pick)
	_check(not legal_pair.is_empty(), "The full league should contain a legal one-for-one player trade")
	if not legal_pair.is_empty():
		var user_player: PlayerData = legal_pair.get("user")
		var partner_player: PlayerData = legal_pair.get("partner")
		var result := career.submit_trade(partner.id, [user_player.id], [partner_player.id], [user_pick.id], [partner_pick.id])
		if not bool(result.get("executed", false)):
			result = TradeService.execute_trade(league, user_team.id, partner.id, [user_player.id], [partner_player.id], [user_pick.id], [partner_pick.id])
		_check(bool(result.get("executed", false)), "A validated full-league package must execute")
		_check(user_team.player_by_id(partner_player.id) != null and partner.player_by_id(user_player.id) != null, "Full-league players must change clubs after execution")
		_check(user_pick.owner_team_id == partner.id and partner_pick.owner_team_id == user_team.id, "Full-league draft capital must change owners")
		_check(RosterValidator.validate_team(user_team, true).is_empty() and RosterValidator.validate_team(partner, true).is_empty(), "Both 53-player rosters must remain legal after a trade")
		_check(league.trade_history.size() == 1 and league.transactions.size() == 2, "The full-league trade must be recorded once with both club ledger entries")
		var draft := DraftService.create_draft(league)
		var transferred: DraftPickData
		for pick in draft.picks:
			if pick.original_team_id == user_team.id and pick.round_number == 3:
				transferred = pick
				break
		_check(transferred != null and transferred.owner_team_id == partner.id, "The live draft must honor Trade Center ownership")
		league.current_draft = draft
		var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
		_check(loaded.league.trade_history.size() == 1 and loaded.league.current_draft != null, "Trades and the resulting draft order must survive serialization")
	league.current_week = TradeService.trade_deadline_week(league) + 1
	_check(not TradeService.trades_open(league), "The complete league trade window must close after Week 9")
	if _failures.is_empty():
		print("PASS: %d assertions across 32-team trades, draft ownership, roster legality, and persistence." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _legal_player_pair(career: CareerSession, partner: TeamData, user_pick: DraftPickData, partner_pick: DraftPickData) -> Dictionary:
	var user_team := career.user_team()
	for position_name in TeamData.ROSTER_POSITIONS:
		if user_team.players_at(position_name).size() <= 1 or partner.players_at(position_name).size() <= 1:
			continue
		for user_player in user_team.players_at(position_name):
			for partner_player in partner.players_at(position_name):
				var preview := career.preview_trade(partner.id, [user_player.id], [partner_player.id], [user_pick.id], [partner_pick.id])
				if bool(preview.get("ok", false)):
					return {"user": user_player, "partner": partner_player}
	return {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
