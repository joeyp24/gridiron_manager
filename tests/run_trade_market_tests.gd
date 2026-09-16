extends SceneTree

var _failures: Array[String] = []
var _assertions := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_team_strategy_and_market_setup()
	_test_trade_block_offers_and_responses()
	_test_counter_and_offer_expiration()
	_test_pending_offer_limits_and_identity()
	_test_cpu_trade_cycle()
	if _failures.is_empty():
		print("PASS: %d assertions across AI team strategy, trade blocks, incoming offers, counters, CPU deals, and persistence." % _assertions)
		quit(0)
	else:
		for failure in _failures:
			printerr("FAIL: " + failure)
		quit(1)


func _test_team_strategy_and_market_setup() -> void:
	var career := CareerSession.new_career("nfl_buf", 910271, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var league := career.league
	_check(league.trade_blocks.size() == league.teams.size(), "Every club should have an initialized trade-block ledger")
	var recognized_directions := [
		TradeMarketService.DIRECTION_CONTENDER,
		TradeMarketService.DIRECTION_PLAYOFF,
		TradeMarketService.DIRECTION_NEUTRAL,
		TradeMarketService.DIRECTION_RETOOLING,
		TradeMarketService.DIRECTION_REBUILDING,
	]
	for team in league.teams:
		_check(TradeMarketService.team_direction(league, team) in recognized_directions, "Every AI club should receive a recognized competitive direction")
		var needs := TradeMarketService.team_needs(league, team)
		_check(needs.size() == 5 and int(needs.front().get("score", -1)) >= int(needs.back().get("score", -1)), "AI position needs should be ranked and limited for each club")
		if team.id != league.user_team_id:
			for player_id in league.trade_block_for(team.id):
				_check(player_id not in TradeMarketService.protected_player_ids(league, team), "AI trade blocks should exclude protected franchise players")


func _test_trade_block_offers_and_responses() -> void:
	var career := CareerSession.new_career("nfl_buf", 910283, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var listing := _list_player_with_offer(career)
	_check(not listing.is_empty(), "Placing an eligible player on the trade block should generate at least one legal incoming offer")
	if listing.is_empty():
		return
	var target: PlayerData = listing.get("player")
	var offers := TradeMarketService.pending_offers_for_user(career.league)
	_check(offers.size() >= 1 and offers.size() <= TradeMarketService.MAX_OFFERS_PER_PLAYER, "A listed player should receive a controlled number of active offers")
	var offer: TradeOfferData = offers.front()
	var preview := TradeService.preview_proposal(
		career.league,
		offer.proposing_team_id,
		offer.responding_team_id,
		offer.proposer_player_ids,
		offer.responder_player_ids,
		offer.proposer_pick_ids,
		offer.responder_pick_ids
	)
	_check(bool(preview.get("ok", false)), "Generated incoming offers should satisfy roster, cap, contract, and pick-ownership rules")
	_check(offer.target_player_id == target.id and offer.responder_player_ids == [target.id], "Incoming offers should identify the exact player placed on the block")
	var loaded := CareerSession.from_dict(JSON.parse_string(JSON.stringify(career.to_dict())))
	_check(loaded.league.trade_block_for(loaded.league.user_team_id).has(target.id), "The user trade block should survive career serialization")
	_check(loaded.league.trade_offers.size() == career.league.trade_offers.size(), "Incoming offers should survive career serialization")
	if offers.size() > 1:
		var declined: TradeOfferData = offers[1]
		var decline_result := career.decline_incoming_trade_offer(declined.id)
		_check(bool(decline_result.get("ok", false)) and declined.status == TradeOfferData.STATUS_DECLINED, "The user should be able to decline an incoming trade offer")
	var proposing_team_id := offer.proposing_team_id
	var incoming_player_id: String = offer.proposer_player_ids.front()
	var accept_result := career.accept_incoming_trade_offer(offer.id)
	_check(bool(accept_result.get("executed", false)), "The user should be able to accept a still-valid incoming trade offer")
	_check(career.user_team().player_by_id(incoming_player_id) != null and career.league.team_by_id(proposing_team_id).player_by_id(target.id) != null, "Accepting an offer should transfer both players to their new clubs")
	_check(target.id not in career.league.trade_block_for(career.league.user_team_id), "A traded player should be removed from the user's trade block")
	_check(offer.status == TradeOfferData.STATUS_ACCEPTED and career.league.trade_history.size() == 1, "Accepted market offers should retain their outcome and create permanent trade history")


func _test_counter_and_offer_expiration() -> void:
	var career := CareerSession.new_career("nfl_buf", 910297, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var listing := _list_player_with_offer(career)
	_check(not listing.is_empty(), "A second market should produce an offer for counteroffer testing")
	if listing.is_empty():
		return
	var offer: TradeOfferData = TradeMarketService.pending_offers_for_user(career.league).front()
	var counter_result := career.counter_incoming_trade_offer(
		offer.id,
		offer.responder_player_ids,
		offer.proposer_player_ids,
		offer.responder_pick_ids,
		offer.proposer_pick_ids
	)
	_check(bool(counter_result.get("ok", false)), "The user should be able to counter an incoming offer through the existing AI negotiation engine")
	_check(offer.status in [TradeOfferData.STATUS_COUNTERED, TradeOfferData.STATUS_ACCEPTED], "A submitted counter should be recorded against its originating offer")

	var expiry_career := CareerSession.new_career("nfl_buf", 910301, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var expiry_listing := _list_player_with_offer(expiry_career)
	if not expiry_listing.is_empty():
		var expiring_offer: TradeOfferData = TradeMarketService.pending_offers_for_user(expiry_career.league).front()
		expiry_career.league.current_week = expiring_offer.expires_week
		expiry_career.league.last_trade_market_week = 0
		TradeMarketService.process_week(expiry_career.league)
		_check(expiring_offer.status == TradeOfferData.STATUS_EXPIRED, "Unanswered offers should expire on their stated week")


func _test_cpu_trade_cycle() -> void:
	var career := CareerSession.new_career("nfl_buf", 910319, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	var result := TradeMarketService.run_cpu_trade_cycle(career.league, true)
	_check(bool(result.get("executed", false)), "A forced AI market cycle should locate and complete a legal CPU-to-CPU trade")
	if bool(result.get("executed", false)):
		var trade: TradeProposalData = career.league.trade_history.front()
		_check(trade.proposing_team_id != career.league.user_team_id and trade.responding_team_id != career.league.user_team_id, "CPU trade cycles should not move assets from the managed club")
		_check(float(trade.proposer_value) / float(maxi(trade.responder_value, 1)) >= 0.90, "CPU-to-CPU deals should stay inside the guarded fair-value floor")
		_check(RosterValidator.validate_team(career.league.team_by_id(trade.proposing_team_id), true).is_empty(), "The buying CPU roster should remain legal after its trade")
		_check(RosterValidator.validate_team(career.league.team_by_id(trade.responding_team_id), true).is_empty(), "The selling CPU roster should remain legal after its trade")


func _test_pending_offer_limits_and_identity() -> void:
	var career := CareerSession.new_career("nfl_buf", 910311, LeagueCatalog.SOURCE_NFLVERSE_FULL)
	for player in career.user_team().players:
		if career.league.trade_block_for(career.league.user_team_id).size() >= TradeMarketService.MAX_USER_BLOCK_PLAYERS:
			break
		career.toggle_trade_block(player.id, true)
	var pending := TradeMarketService.pending_offers_for_user(career.league)
	_check(pending.size() <= TradeMarketService.MAX_PENDING_USER_OFFERS, "Immediate interest across several listed players should respect the global pending-offer cap")
	var offer_ids: Dictionary = {}
	for offer in career.league.trade_offers:
		offer_ids[offer.id] = true
	_check(offer_ids.size() == career.league.trade_offers.size(), "Every generated market offer should retain a unique persistent ID")


func _list_player_with_offer(career: CareerSession) -> Dictionary:
	var players := career.user_team().players.duplicate()
	players.sort_custom(func(a: PlayerData, b: PlayerData):
		if a.overall != b.overall:
			return a.overall > b.overall
		return a.age < b.age
	)
	for player: PlayerData in players:
		var result := career.toggle_trade_block(player.id, true)
		if int(result.get("generated_offers", 0)) > 0:
			return {"player": player, "result": result}
		career.toggle_trade_block(player.id, false)
	return {}


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
