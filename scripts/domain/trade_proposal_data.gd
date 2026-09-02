class_name TradeProposalData
extends RefCounted

const STATUS_ACCEPTED := "Accepted"
const STATUS_REJECTED := "Rejected"
const STATUS_COUNTERED := "Countered"

var id: String
var season_year: int
var week: int
var proposing_team_id: String
var responding_team_id: String
var proposer_player_ids: Array[String] = []
var responder_player_ids: Array[String] = []
var proposer_pick_ids: Array[String] = []
var responder_pick_ids: Array[String] = []
var proposer_asset_labels: Array[String] = []
var responder_asset_labels: Array[String] = []
var proposer_value := 0
var responder_value := 0
var status := STATUS_ACCEPTED
var summary := ""


func _init(
	trade_id: String = "",
	trade_year: int = 2026,
	trade_week: int = 1,
	proposer_id: String = "",
	responder_id: String = ""
) -> void:
	id = trade_id
	season_year = trade_year
	week = trade_week
	proposing_team_id = proposer_id
	responding_team_id = responder_id


func to_dict() -> Dictionary:
	return {
		"id": id,
		"season_year": season_year,
		"week": week,
		"proposing_team_id": proposing_team_id,
		"responding_team_id": responding_team_id,
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


static func from_dict(data: Dictionary) -> TradeProposalData:
	var proposal := TradeProposalData.new(
		str(data.get("id", "")),
		int(data.get("season_year", 2026)),
		int(data.get("week", 1)),
		str(data.get("proposing_team_id", "")),
		str(data.get("responding_team_id", ""))
	)
	proposal.proposer_player_ids = _string_array(data.get("proposer_player_ids", []))
	proposal.responder_player_ids = _string_array(data.get("responder_player_ids", []))
	proposal.proposer_pick_ids = _string_array(data.get("proposer_pick_ids", []))
	proposal.responder_pick_ids = _string_array(data.get("responder_pick_ids", []))
	proposal.proposer_asset_labels = _string_array(data.get("proposer_asset_labels", []))
	proposal.responder_asset_labels = _string_array(data.get("responder_asset_labels", []))
	proposal.proposer_value = int(data.get("proposer_value", 0))
	proposal.responder_value = int(data.get("responder_value", 0))
	proposal.status = str(data.get("status", STATUS_ACCEPTED))
	proposal.summary = str(data.get("summary", ""))
	return proposal


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result
