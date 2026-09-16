class_name TradeOfferData
extends RefCounted

const STATUS_PENDING := "Pending"
const STATUS_ACCEPTED := "Accepted"
const STATUS_DECLINED := "Declined"
const STATUS_COUNTERED := "Countered"
const STATUS_EXPIRED := "Expired"

var id := ""
var season_year := 2026
var week := 1
var expires_week := 1
var proposing_team_id := ""
var responding_team_id := ""
var target_player_id := ""
var parent_offer_id := ""
var proposer_player_ids: Array[String] = []
var responder_player_ids: Array[String] = []
var proposer_pick_ids: Array[String] = []
var responder_pick_ids: Array[String] = []
var proposer_asset_labels: Array[String] = []
var responder_asset_labels: Array[String] = []
var proposer_value := 0
var responder_value := 0
var status := STATUS_PENDING
var summary := ""


func _init(
	offer_id: String = "",
	offer_year: int = 2026,
	offer_week: int = 1,
	proposer_id: String = "",
	responder_id: String = ""
) -> void:
	id = offer_id
	season_year = offer_year
	week = offer_week
	expires_week = offer_week
	proposing_team_id = proposer_id
	responding_team_id = responder_id


func is_pending() -> bool:
	return status == STATUS_PENDING


func involves_player(player_id: String) -> bool:
	return player_id in proposer_player_ids or player_id in responder_player_ids


func involves_pick(pick_id: String) -> bool:
	return pick_id in proposer_pick_ids or pick_id in responder_pick_ids


func to_dict() -> Dictionary:
	return {
		"id": id,
		"season_year": season_year,
		"week": week,
		"expires_week": expires_week,
		"proposing_team_id": proposing_team_id,
		"responding_team_id": responding_team_id,
		"target_player_id": target_player_id,
		"parent_offer_id": parent_offer_id,
		"proposer_player_ids": proposer_player_ids.duplicate(),
		"responder_player_ids": responder_player_ids.duplicate(),
		"proposer_pick_ids": proposer_pick_ids.duplicate(),
		"responder_pick_ids": responder_pick_ids.duplicate(),
		"proposer_asset_labels": proposer_asset_labels.duplicate(),
		"responder_asset_labels": responder_asset_labels.duplicate(),
		"proposer_value": proposer_value,
		"responder_value": responder_value,
		"status": status,
		"summary": summary,
	}


static func from_dict(data: Dictionary) -> TradeOfferData:
	var offer := TradeOfferData.new(
		str(data.get("id", "")),
		int(data.get("season_year", 2026)),
		int(data.get("week", 1)),
		str(data.get("proposing_team_id", "")),
		str(data.get("responding_team_id", ""))
	)
	offer.expires_week = int(data.get("expires_week", offer.week))
	offer.target_player_id = str(data.get("target_player_id", ""))
	offer.parent_offer_id = str(data.get("parent_offer_id", ""))
	offer.proposer_player_ids = _string_array(data.get("proposer_player_ids", []))
	offer.responder_player_ids = _string_array(data.get("responder_player_ids", []))
	offer.proposer_pick_ids = _string_array(data.get("proposer_pick_ids", []))
	offer.responder_pick_ids = _string_array(data.get("responder_pick_ids", []))
	offer.proposer_asset_labels = _string_array(data.get("proposer_asset_labels", []))
	offer.responder_asset_labels = _string_array(data.get("responder_asset_labels", []))
	offer.proposer_value = int(data.get("proposer_value", 0))
	offer.responder_value = int(data.get("responder_value", 0))
	offer.status = str(data.get("status", STATUS_PENDING))
	offer.summary = str(data.get("summary", ""))
	return offer


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
