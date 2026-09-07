class_name FantasyDraftStateData
extends RefCounted

const STATUS_READY := "Ready"
const STATUS_IN_PROGRESS := "In Progress"
const STATUS_COMPLETE := "Complete"

var status := STATUS_READY
var draft_seed := 0
var current_pick_index := 0
var total_rounds := 53
var original_pool_size := 0
var draft_order: Array[String] = []
var picks: Array[FantasyDraftPickData] = []


func _init(seed: int = 0) -> void:
	draft_seed = seed


func current_pick() -> FantasyDraftPickData:
	return picks[current_pick_index] if current_pick_index >= 0 and current_pick_index < picks.size() else null


func next_pick_for(team_id: String) -> FantasyDraftPickData:
	for index in range(current_pick_index, picks.size()):
		if picks[index].team_id == team_id and not picks[index].is_used():
			return picks[index]
	return null


func selections_for_team(team_id: String) -> Array[FantasyDraftPickData]:
	var result: Array[FantasyDraftPickData] = []
	for pick in picks:
		if pick.team_id == team_id and pick.is_used():
			result.append(pick)
	return result


func recent_selections(limit: int = 8) -> Array[FantasyDraftPickData]:
	var result: Array[FantasyDraftPickData] = []
	for index in range(mini(current_pick_index, picks.size()) - 1, -1, -1):
		if picks[index].is_used():
			result.append(picks[index])
			if result.size() >= limit:
				break
	return result


func user_draft_slot(team_id: String) -> int:
	return draft_order.find(team_id) + 1


func is_complete() -> bool:
	return status == STATUS_COMPLETE


func to_dict() -> Dictionary:
	var pick_data: Array[Dictionary] = []
	for pick in picks:
		pick_data.append(pick.to_dict())
	return {
		"status": status,
		"draft_seed": draft_seed,
		"current_pick_index": current_pick_index,
		"total_rounds": total_rounds,
		"original_pool_size": original_pool_size,
		"draft_order": draft_order.duplicate(),
		"picks": pick_data,
	}


static func from_dict(data: Dictionary) -> FantasyDraftStateData:
	var draft := FantasyDraftStateData.new(int(data.get("draft_seed", 0)))
	draft.status = str(data.get("status", STATUS_READY))
	draft.current_pick_index = int(data.get("current_pick_index", 0))
	draft.total_rounds = int(data.get("total_rounds", 53))
	draft.original_pool_size = int(data.get("original_pool_size", 0))
	for team_id in data.get("draft_order", []):
		draft.draft_order.append(str(team_id))
	for pick_data in data.get("picks", []):
		draft.picks.append(FantasyDraftPickData.from_dict(pick_data))
	return draft
