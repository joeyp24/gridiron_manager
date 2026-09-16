class_name TradeMarketService
extends RefCounted

const DIRECTION_CONTENDER := "Contender"
const DIRECTION_PLAYOFF := "Playoff Hopeful"
const DIRECTION_NEUTRAL := "Evaluating"
const DIRECTION_RETOOLING := "Retooling"
const DIRECTION_REBUILDING := "Rebuilding"

const MAX_USER_BLOCK_PLAYERS := 8
const MAX_AI_BLOCK_PLAYERS := 3
const MAX_PENDING_USER_OFFERS := 10
const MAX_OFFERS_PER_PLAYER := 2
const MAX_OFFER_ARCHIVE := 80

const DEPTH_TARGETS := {
	"QB": 3, "RB": 4, "WR": 6, "TE": 3,
	"LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
	"EDGE": 4, "DT": 4, "LB": 6, "CB": 6, "S": 4,
	"K": 1, "P": 1, "LS": 1,
}
const STARTER_TARGETS := {
	"QB": 82, "RB": 77, "WR": 79, "TE": 77,
	"LT": 80, "LG": 76, "C": 77, "RG": 76, "RT": 78,
	"EDGE": 80, "DT": 78, "LB": 77, "CB": 80, "S": 78,
	"K": 75, "P": 74, "LS": 68,
}


static func initialize_market(league: LeagueState) -> void:
	if league == null:
		return
	for team in league.teams:
		if not league.trade_blocks.has(team.id):
			league.set_trade_block(team.id, [])
	league.reconcile_trade_market()
	refresh_ai_trade_blocks(league)


static func team_direction(league: LeagueState, team: TeamData) -> String:
	if league == null or team == null:
		return DIRECTION_NEUTRAL
	var standing := league.standing_for(team.id)
	var games := standing.games_played() if standing != null else 0
	var win_rate := standing.win_percentage() if standing != null else 0.5
	var power := team.overall_rating()
	if games >= 4:
		if win_rate >= 0.66 or (win_rate >= 0.58 and power >= 80):
			return DIRECTION_CONTENDER
		if win_rate >= 0.46:
			return DIRECTION_PLAYOFF
		if win_rate <= 0.28:
			return DIRECTION_REBUILDING
		return DIRECTION_RETOOLING
	if power >= 83:
		return DIRECTION_CONTENDER
	if power >= 79:
		return DIRECTION_PLAYOFF
	if power <= 74:
		return DIRECTION_REBUILDING
	return DIRECTION_NEUTRAL


static func team_needs(league: LeagueState, team: TeamData, limit: int = 5) -> Array[Dictionary]:
	var needs: Array[Dictionary] = []
	if team == null:
		return needs
	for position_name in TeamData.ROSTER_POSITIONS:
		var players := team.players_at(position_name)
		players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		var starter: PlayerData = players.front() if not players.is_empty() else null
		var starter_rating := starter.overall if starter != null else 40
		var rating_gap := maxi(int(STARTER_TARGETS.get(position_name, 76)) - starter_rating, 0)
		var depth_gap := maxi(int(DEPTH_TARGETS.get(position_name, 2)) - players.size(), 0)
		var injury_pressure := 0
		for player in players:
			if player.injury_weeks > 0:
				injury_pressure += mini(player.injury_weeks, 4)
		var age_pressure := maxi((starter.age if starter != null else 31) - 29, 0)
		var score := rating_gap * 5 + depth_gap * 10 + injury_pressure * 3 + age_pressure * 2
		if position_name == "QB":
			score = roundi(float(score) * 1.18)
		needs.append({
			"position": position_name,
			"score": score,
			"starter_overall": starter_rating,
			"depth": players.size(),
			"reason": _need_reason(rating_gap, depth_gap, injury_pressure, age_pressure),
		})
	needs.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return str(a.get("position", "")) < str(b.get("position", ""))
	)
	return needs.slice(0, mini(limit, needs.size()))


static func protected_player_ids(league: LeagueState, team: TeamData) -> Array[String]:
	var protected: Array[String] = []
	if team == null:
		return protected
	var direction := team_direction(league, team)
	for player in team.players:
		var franchise_quarterback := player.position == "QB" and player.overall >= 80 and player.age <= 32
		var elite_player := player.overall >= 89 and (player.age <= 31 or direction != DIRECTION_REBUILDING)
		var young_core := player.age <= 24 and (player.overall >= 80 or player.potential >= 86)
		var contender_core := direction == DIRECTION_CONTENDER and player.age <= 29 and player.overall >= 85
		if franchise_quarterback or elite_player or young_core or contender_core:
			protected.append(player.id)
	return protected


static func refresh_ai_trade_blocks(league: LeagueState) -> void:
	if league == null:
		return
	for team in league.teams:
		if team.id == league.user_team_id:
			continue
		league.set_trade_block(team.id, _ai_block_candidates(league, team))


static func toggle_user_trade_block(league: LeagueState, player_id: String, listed: bool) -> Dictionary:
	if league == null:
		return _failure("The trade market is unavailable.")
	if listed and not TradeService.trades_open(league):
		return _failure("The trade window is closed. Players cannot be added to the block right now.")
	var team := league.user_team()
	var player := team.player_by_id(player_id) if team != null else null
	if player == null or player.contract == null:
		return _failure("Only players on your active contracted roster can be placed on the trade block.")
	var block := league.trade_block_for(team.id)
	if listed:
		if player_id in block:
			return {"ok": true, "generated_offers": 0, "message": "%s is already on the trade block." % player.full_name}
		if block.size() >= MAX_USER_BLOCK_PLAYERS:
			return _failure("Your trade block can hold up to %d players." % MAX_USER_BLOCK_PLAYERS)
		block.append(player_id)
		league.set_trade_block(team.id, block)
		_add_news(league, "Trade rumor: %s have made %s available." % [team.display_name(), player.full_name])
		var generated := generate_incoming_offers_for_player(league, player_id, true)
		return {
			"ok": true,
			"generated_offers": generated,
			"message": "%s is now on the trade block. %s" % [
				player.full_name,
				("%d offer%s arrived." % [generated, "" if generated == 1 else "s"]) if generated > 0 else "Teams will continue evaluating him each week.",
			],
		}
	block.erase(player_id)
	league.set_trade_block(team.id, block)
	for offer in league.trade_offers:
		if offer.is_pending() and offer.target_player_id == player_id and offer.responding_team_id == team.id:
			offer.status = TradeOfferData.STATUS_EXPIRED
	return {"ok": true, "generated_offers": 0, "message": "%s has been removed from the trade block." % player.full_name}


static func pending_offers_for_user(league: LeagueState) -> Array[TradeOfferData]:
	var offers: Array[TradeOfferData] = []
	if league == null:
		return offers
	league.reconcile_trade_market()
	for offer in league.trade_offers:
		if offer.responding_team_id == league.user_team_id and offer.is_pending():
			offers.append(offer)
	return offers


static func recent_offers_for_user(league: LeagueState, limit: int = 8) -> Array[TradeOfferData]:
	var offers: Array[TradeOfferData] = []
	if league == null:
		return offers
	for offer in league.trade_offers:
		if offer.responding_team_id == league.user_team_id:
			offers.append(offer)
			if offers.size() >= limit:
				break
	return offers


static func accept_incoming_offer(league: LeagueState, offer_id: String) -> Dictionary:
	var offer := league.trade_offer_by_id(offer_id) if league != null else null
	var validation := _validate_pending_user_offer(league, offer)
	if not validation.is_empty():
		return _failure(validation)
	var result := TradeService.execute_trade(
		league,
		offer.proposing_team_id,
		offer.responding_team_id,
		offer.proposer_player_ids,
		offer.responder_player_ids,
		offer.proposer_pick_ids,
		offer.responder_pick_ids
	)
	if bool(result.get("executed", false)):
		offer.status = TradeOfferData.STATUS_ACCEPTED
		league.reconcile_trade_market()
		_expire_conflicting_offers(league, offer)
		result["message"] = "Incoming offer accepted. " + str(result.get("message", "Trade completed."))
	return result


static func decline_incoming_offer(league: LeagueState, offer_id: String) -> Dictionary:
	var offer := league.trade_offer_by_id(offer_id) if league != null else null
	var validation := _validate_pending_user_offer(league, offer)
	if not validation.is_empty():
		return _failure(validation)
	offer.status = TradeOfferData.STATUS_DECLINED
	var proposer := league.team_by_id(offer.proposing_team_id)
	return {"ok": true, "executed": false, "status": offer.status, "message": "Offer from %s declined." % proposer.display_name()}


static func submit_incoming_counter(
	league: LeagueState,
	offer_id: String,
	user_player_ids: Array,
	partner_player_ids: Array,
	user_pick_ids: Array,
	partner_pick_ids: Array
) -> Dictionary:
	var offer := league.trade_offer_by_id(offer_id) if league != null else null
	var validation := _validate_pending_user_offer(league, offer)
	if not validation.is_empty():
		return _failure(validation)
	var result := TradeService.submit_proposal(
		league,
		league.user_team_id,
		offer.proposing_team_id,
		user_player_ids,
		partner_player_ids,
		user_pick_ids,
		partner_pick_ids
	)
	if bool(result.get("ok", false)):
		offer.status = TradeOfferData.STATUS_ACCEPTED if bool(result.get("executed", false)) else TradeOfferData.STATUS_COUNTERED
		league.reconcile_trade_market()
		if bool(result.get("executed", false)):
			_expire_conflicting_offers(league, offer)
	return result


static func mark_counter_offer_completed(league: LeagueState, offer_id: String) -> void:
	var offer := league.trade_offer_by_id(offer_id) if league != null else null
	if offer == null:
		return
	offer.status = TradeOfferData.STATUS_ACCEPTED
	league.reconcile_trade_market()
	_expire_conflicting_offers(league, offer)


static func process_week(league: LeagueState) -> Dictionary:
	if league == null or league.last_trade_market_week == league.current_week:
		return {"generated_offers": 0, "cpu_trade": false}
	league.last_trade_market_week = league.current_week
	league.reconcile_trade_market()
	_expire_old_offers(league)
	if not TradeService.trades_open(league):
		return {"generated_offers": 0, "cpu_trade": false}
	refresh_ai_trade_blocks(league)
	var generated := 0
	for player_id in league.trade_block_for(league.user_team_id):
		if pending_offers_for_user(league).size() >= MAX_PENDING_USER_OFFERS:
			break
		generated += generate_incoming_offers_for_player(league, player_id, false)
	var cpu_result := run_cpu_trade_cycle(league)
	return {"generated_offers": generated, "cpu_trade": bool(cpu_result.get("executed", false))}


static func generate_incoming_offers_for_player(league: LeagueState, player_id: String, immediate: bool = false) -> int:
	if league == null or not TradeService.trades_open(league):
		return 0
	var seller := league.user_team()
	var target := seller.player_by_id(player_id) if seller != null else null
	if target == null or player_id not in league.trade_block_for(league.user_team_id):
		return 0
	var pending_total := pending_offers_for_user(league).size()
	if pending_total >= MAX_PENDING_USER_OFFERS:
		return 0
	var existing_teams: Array[String] = []
	var existing_count := 0
	for offer in league.trade_offers:
		if offer.is_pending() and offer.target_player_id == player_id and offer.responding_team_id == seller.id:
			existing_teams.append(offer.proposing_team_id)
			existing_count += 1
	if existing_count >= MAX_OFFERS_PER_PLAYER:
		return 0
	var candidates := _interested_teams(league, seller, target)
	var generated := 0
	for buyer in candidates:
		if buyer.id in existing_teams or _recent_trade_pair(league, buyer.id, seller.id):
			continue
		var terms := _build_offer_terms(league, buyer, seller, target)
		if terms.is_empty():
			continue
		var offer := _create_offer(league, buyer, seller, target, terms)
		league.trade_offers.push_front(offer)
		_add_news(league, "Trade offer: %s have contacted %s about %s." % [buyer.display_name(), seller.display_name(), target.full_name])
		generated += 1
		if pending_total + generated >= MAX_PENDING_USER_OFFERS:
			break
		if existing_count + generated >= MAX_OFFERS_PER_PLAYER:
			break
		if not immediate and generated >= 1:
			break
	_trim_offer_archive(league)
	return generated


static func run_cpu_trade_cycle(league: LeagueState, force: bool = false) -> Dictionary:
	if league == null or not TradeService.trades_open(league):
		return {"ok": false, "executed": false, "message": "The trade window is closed."}
	if not force and league.last_cpu_trade_week == league.current_week:
		return {"ok": false, "executed": false, "message": "The weekly AI trade cycle is complete."}
	var deadline := TradeService.trade_deadline_week(league)
	var chance := 18
	if league.phase == LeagueState.PHASE_REGULAR_SEASON and league.current_week >= deadline - 2:
		chance = 58
	var activity_roll := absi(league.season_seed + league.season_year * 41 + league.current_week * 977) % 100
	if not force and activity_roll >= chance:
		return {"ok": true, "executed": false, "message": "No CPU trade was completed this week."}
	refresh_ai_trade_blocks(league)
	var sellers: Array[TeamData] = []
	for team in league.teams:
		if team.id != league.user_team_id and not league.trade_block_for(team.id).is_empty():
			sellers.append(team)
	sellers.sort_custom(func(a: TeamData, b: TeamData):
		return _seller_priority(league, a) > _seller_priority(league, b)
	)
	for seller in sellers:
		for target_id in league.trade_block_for(seller.id):
			var target := seller.player_by_id(target_id)
			if target == null:
				continue
			for buyer in _interested_teams(league, seller, target):
				if buyer.id == league.user_team_id or _recent_trade_pair(league, buyer.id, seller.id):
					continue
				var terms := _build_offer_terms(league, buyer, seller, target)
				if terms.is_empty():
					continue
				var preview: Dictionary = terms.get("preview", {})
				var value_ratio := float(preview.get("proposer_value", 0)) / float(maxi(int(preview.get("responder_value", 0)), 1))
				if value_ratio < 0.90:
					continue
				var result := TradeService.execute_trade(
					league,
					buyer.id,
					seller.id,
					terms.get("proposer_player_ids", []),
					[target.id],
					terms.get("proposer_pick_ids", []),
					[]
				)
				if bool(result.get("executed", false)):
					league.last_cpu_trade_week = league.current_week
					league.reconcile_trade_market()
					return result
	return {"ok": true, "executed": false, "message": "No legal CPU trade matched the market this week."}


static func _ai_block_candidates(league: LeagueState, team: TeamData) -> Array[String]:
	var candidates: Array[Dictionary] = []
	var protected := protected_player_ids(league, team)
	var direction := team_direction(league, team)
	for player in team.players:
		if player.id in protected or player.contract == null:
			continue
		var position_players := team.players_at(player.position)
		position_players.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		var depth_rank := position_players.find(player)
		if position_players.size() <= 1:
			continue
		var score := depth_rank * 12 + maxi(player.age - 27, 0) * 5
		if player.contract.years_remaining <= 1:
			score += 18
		if player.contract.annual_salary >= 10_000_000:
			score += 8
		if direction == DIRECTION_REBUILDING and player.age >= 29:
			score += 24
		elif direction == DIRECTION_CONTENDER and depth_rank == 0:
			score -= 28
		if player.injury_weeks > 0:
			score -= 8
		if score >= 18:
			candidates.append({"id": player.id, "score": score, "value": TradeService.player_trade_value(player)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return int(a.get("value", 0)) > int(b.get("value", 0))
	)
	var result: Array[String] = []
	for candidate in candidates.slice(0, mini(MAX_AI_BLOCK_PLAYERS, candidates.size())):
		result.append(str(candidate.get("id", "")))
	return result


static func _interested_teams(league: LeagueState, seller: TeamData, target: PlayerData) -> Array[TeamData]:
	var candidates: Array[Dictionary] = []
	for team in league.teams:
		if team.id == seller.id:
			continue
		var same_position: Array[PlayerData] = team.players_at(target.position)
		same_position.sort_custom(func(a: PlayerData, b: PlayerData): return a.overall > b.overall)
		var starter_rating: int = same_position.front().overall if not same_position.is_empty() else 40
		var needs: Array[Dictionary] = team_needs(league, team, TeamData.ROSTER_POSITIONS.size())
		var need_score: int = 0
		for need in needs:
			if str(need.get("position", "")) == target.position:
				need_score = int(need.get("score", 0))
				break
		var upgrade: int = target.overall - starter_rating
		var direction: String = team_direction(league, team)
		var direction_bonus: int = 12 if direction in [DIRECTION_CONTENDER, DIRECTION_PLAYOFF] else 4
		if direction == DIRECTION_REBUILDING and target.age >= 29:
			direction_bonus -= 20
		var score: int = need_score + upgrade * 8 + direction_bonus
		if target.age <= 25 and target.potential >= 82:
			score += 10
		if score >= 8:
			candidates.append({
				"team": team,
				"score": score,
				"tie": absi((team.id + target.id).hash() + league.season_seed + league.current_week * 13) % 1000,
			})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary):
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return int(a.get("tie", 0)) < int(b.get("tie", 0))
	)
	var result: Array[TeamData] = []
	for candidate in candidates:
		result.append(candidate.get("team"))
	return result


static func _build_offer_terms(league: LeagueState, buyer: TeamData, seller: TeamData, target: PlayerData) -> Dictionary:
	var target_value := TradeService.player_trade_value(target, buyer)
	var buyer_protected := protected_player_ids(league, buyer)
	var buyer_block := league.trade_block_for(buyer.id)
	var occupied_assets := _pending_asset_ids(league)
	var choices: Array[Dictionary] = []
	for outgoing in buyer.players:
		if outgoing.id in buyer_protected or outgoing.id in occupied_assets or outgoing.contract == null:
			continue
		if outgoing.overall >= target.overall + 3:
			continue
		if outgoing.position != target.position and buyer.players_at(outgoing.position).size() <= 1:
			continue
		var outgoing_value := TradeService.player_trade_value(outgoing, seller)
		if outgoing_value > roundi(float(target_value) * 1.16):
			continue
		var pick_ids := _best_pick_package(league, buyer, outgoing_value, target_value, occupied_assets)
		var preview := TradeService.preview_proposal(league, buyer.id, seller.id, [outgoing.id], [target.id], pick_ids, [])
		if not bool(preview.get("ok", false)):
			continue
		var ratio := float(preview.get("proposer_value", 0)) / float(maxi(int(preview.get("responder_value", 0)), 1))
		if ratio < 0.76 or ratio > 1.16:
			continue
		var score := absf(0.94 - ratio)
		if outgoing.position == target.position:
			score -= 0.10
		if outgoing.id in buyer_block:
			score -= 0.08
		choices.append({
			"proposer_player_ids": [outgoing.id],
			"proposer_pick_ids": pick_ids,
			"preview": preview,
			"score": score,
		})
	choices.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("score", 99.0)) < float(b.get("score", 99.0)))
	return choices.front() if not choices.is_empty() else {}


static func _best_pick_package(
	league: LeagueState,
	buyer: TeamData,
	player_value: int,
	target_value: int,
	occupied_assets: Dictionary
) -> Array[String]:
	var candidates: Array[DraftPickData] = []
	for pick in TradeService.picks_owned_by(league, buyer.id):
		if not occupied_assets.has(pick.id) and pick.draft_year <= league.season_year + 2:
			candidates.append(pick)
	var combinations: Array[Array] = [[]]
	for index in range(candidates.size()):
		combinations.append([candidates[index]])
		for second_index in range(index + 1, candidates.size()):
			combinations.append([candidates[index], candidates[second_index]])
	var best_ids: Array[String] = []
	var best_score := INF
	for combination in combinations:
		var total := player_value
		var ids: Array[String] = []
		for pick: DraftPickData in combination:
			total += TradeService.draft_pick_value(league, pick)
			ids.append(pick.id)
		var ratio := float(total) / float(maxi(target_value, 1))
		if ratio < 0.76 or ratio > 1.16:
			continue
		var score := absf(0.94 - ratio) + float(ids.size()) * 0.015
		if score < best_score:
			best_score = score
			best_ids = ids
	return best_ids


static func _create_offer(
	league: LeagueState,
	buyer: TeamData,
	seller: TeamData,
	target: PlayerData,
	terms: Dictionary
) -> TradeOfferData:
	var sequence := 1
	var id_prefix := "offer_%d_w%d_%s_%s" % [league.season_year, league.current_week, buyer.id, target.id]
	var offer_id := "%s_%d" % [id_prefix, sequence]
	while league.trade_offer_by_id(offer_id) != null:
		sequence += 1
		offer_id = "%s_%d" % [id_prefix, sequence]
	var offer := TradeOfferData.new(
		offer_id,
		league.season_year,
		league.current_week,
		buyer.id,
		seller.id
	)
	offer.expires_week = league.current_week + 2
	if league.phase == LeagueState.PHASE_REGULAR_SEASON:
		offer.expires_week = mini(offer.expires_week, TradeService.trade_deadline_week(league))
	offer.target_player_id = target.id
	offer.proposer_player_ids = _string_array(terms.get("proposer_player_ids", []))
	offer.responder_player_ids = [target.id]
	offer.proposer_pick_ids = _string_array(terms.get("proposer_pick_ids", []))
	var preview: Dictionary = terms.get("preview", {})
	offer.proposer_value = int(preview.get("proposer_value", 0))
	offer.responder_value = int(preview.get("responder_value", 0))
	offer.proposer_asset_labels = _asset_labels(league, buyer, offer.proposer_player_ids, offer.proposer_pick_ids)
	offer.responder_asset_labels = _asset_labels(league, seller, offer.responder_player_ids, [])
	offer.summary = "%s offer %s to %s for %s." % [
		buyer.display_name(),
		_package_label(offer.proposer_asset_labels),
		seller.display_name(),
		target.full_name,
	]
	return offer


static func _validate_pending_user_offer(league: LeagueState, offer: TradeOfferData) -> String:
	if league == null or offer == null:
		return "That trade offer could not be found."
	if not offer.is_pending():
		return "That trade offer is no longer active."
	if offer.responding_team_id != league.user_team_id:
		return "That offer was not sent to your club."
	if not TradeService.trades_open(league):
		return "The trade window is closed."
	league.reconcile_trade_market()
	return "That trade offer is no longer valid after recent roster changes." if not offer.is_pending() else ""


static func _expire_old_offers(league: LeagueState) -> void:
	for offer in league.trade_offers:
		if not offer.is_pending():
			continue
		if offer.season_year != league.season_year or league.current_week >= offer.expires_week:
			offer.status = TradeOfferData.STATUS_EXPIRED


static func _expire_conflicting_offers(league: LeagueState, completed: TradeOfferData) -> void:
	for offer in league.trade_offers:
		if offer == completed or not offer.is_pending():
			continue
		var conflicts := false
		for player_id in completed.proposer_player_ids + completed.responder_player_ids:
			if offer.involves_player(player_id):
				conflicts = true
		for pick_id in completed.proposer_pick_ids + completed.responder_pick_ids:
			if offer.involves_pick(pick_id):
				conflicts = true
		if conflicts:
			offer.status = TradeOfferData.STATUS_EXPIRED


static func _pending_asset_ids(league: LeagueState) -> Dictionary:
	var ids: Dictionary = {}
	for offer in league.trade_offers:
		if not offer.is_pending():
			continue
		for asset_id in offer.proposer_player_ids + offer.responder_player_ids + offer.proposer_pick_ids + offer.responder_pick_ids:
			ids[asset_id] = true
	return ids


static func _recent_trade_pair(league: LeagueState, first_team_id: String, second_team_id: String) -> bool:
	for trade in league.trade_history:
		if trade.season_year != league.season_year or league.current_week - trade.week > 3:
			continue
		var same_pair := (
			trade.proposing_team_id == first_team_id and trade.responding_team_id == second_team_id
		) or (
			trade.proposing_team_id == second_team_id and trade.responding_team_id == first_team_id
		)
		if same_pair:
			return true
	return false


static func _seller_priority(league: LeagueState, team: TeamData) -> int:
	var direction := team_direction(league, team)
	var direction_score: int = int({
		DIRECTION_REBUILDING: 50,
		DIRECTION_RETOOLING: 38,
		DIRECTION_NEUTRAL: 24,
		DIRECTION_PLAYOFF: 12,
		DIRECTION_CONTENDER: 4,
	}.get(direction, 20))
	return direction_score + league.trade_block_for(team.id).size() * 3


static func _need_reason(rating_gap: int, depth_gap: int, injury_pressure: int, age_pressure: int) -> String:
	if depth_gap > 0:
		return "Depth shortage"
	if injury_pressure > 0:
		return "Injury cover"
	if rating_gap > 0:
		return "Starter upgrade"
	if age_pressure > 0:
		return "Future starter"
	return "Roster depth"


static func _asset_labels(league: LeagueState, team: TeamData, player_ids: Array[String], pick_ids: Array[String]) -> Array[String]:
	var labels: Array[String] = []
	for player_id in player_ids:
		var player := team.player_by_id(player_id)
		if player != null:
			labels.append("%s (%s, %d OVR)" % [player.full_name, player.position, player.overall])
	for pick_id in pick_ids:
		var pick := TradeService.future_pick_by_id(league, pick_id)
		if pick != null:
			labels.append(TradeService.pick_description(league, pick).capitalize())
	return labels


static func _package_label(labels: Array[String]) -> String:
	if labels.is_empty():
		return "no assets"
	return labels.front() if labels.size() == 1 else ", ".join(labels)


static func _trim_offer_archive(league: LeagueState) -> void:
	while league.trade_offers.size() > MAX_OFFER_ARCHIVE:
		league.trade_offers.pop_back()


static func _add_news(league: LeagueState, headline: String) -> void:
	league.news.push_front(headline)
	while league.news.size() > 12:
		league.news.pop_back()


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "executed": false, "status": "Invalid", "message": message}
