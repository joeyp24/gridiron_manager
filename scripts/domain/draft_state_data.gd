class_name DraftStateData
extends RefCounted

const STATUS_PREPARATION := "Preparation"
const STATUS_IN_PROGRESS := "In Progress"
const STATUS_COMPLETE := "Complete"

var draft_year: int
var status := STATUS_PREPARATION
var current_pick_index := 0
var scouting_points_remaining := 12
var prospects: Array[ProspectData] = []
var picks: Array[DraftPickData] = []
var scouting_reports: Array[ScoutingReportData] = []
var favorite_prospect_ids: Array[String] = []
var undrafted_converted := false


func _init(year: int = 2027) -> void:
	draft_year = year


func prospect_by_id(prospect_id: String) -> ProspectData:
	for prospect in prospects:
		if prospect.id == prospect_id:
			return prospect
	return null


func report_for(team_id: String, prospect_id: String) -> ScoutingReportData:
	for report in scouting_reports:
		if report.team_id == team_id and report.prospect_id == prospect_id:
			return report
	return null


func current_pick() -> DraftPickData:
	return picks[current_pick_index] if current_pick_index >= 0 and current_pick_index < picks.size() else null


func available_prospects() -> Array[ProspectData]:
	var selected: Dictionary = {}
	for pick in picks:
		if pick.is_used():
			selected[pick.selected_prospect_id] = true
	var available: Array[ProspectData] = []
	for prospect in prospects:
		if not selected.has(prospect.id):
			available.append(prospect)
	return available


func picks_for_team(team_id: String) -> Array[DraftPickData]:
	var team_picks: Array[DraftPickData] = []
	for pick in picks:
		if pick.owner_team_id == team_id:
			team_picks.append(pick)
	return team_picks


func selections_for_team(team_id: String) -> Array[DraftPickData]:
	var selections: Array[DraftPickData] = []
	for pick in picks_for_team(team_id):
		if pick.is_used():
			selections.append(pick)
	return selections


func next_pick_for(team_id: String) -> DraftPickData:
	for index in range(current_pick_index, picks.size()):
		if picks[index].owner_team_id == team_id and not picks[index].is_used():
			return picks[index]
	return null


func is_favorite(prospect_id: String) -> bool:
	return prospect_id in favorite_prospect_ids


func toggle_favorite(prospect_id: String) -> bool:
	if prospect_id in favorite_prospect_ids:
		favorite_prospect_ids.erase(prospect_id)
		return false
	favorite_prospect_ids.append(prospect_id)
	return true


func is_complete() -> bool:
	return status == STATUS_COMPLETE


func to_dict() -> Dictionary:
	var prospect_data: Array[Dictionary] = []
	for prospect in prospects:
		prospect_data.append(prospect.to_dict())
	var pick_data: Array[Dictionary] = []
	for pick in picks:
		pick_data.append(pick.to_dict())
	var report_data: Array[Dictionary] = []
	for report in scouting_reports:
		report_data.append(report.to_dict())
	return {
		"draft_year": draft_year,
		"status": status,
		"current_pick_index": current_pick_index,
		"scouting_points_remaining": scouting_points_remaining,
		"prospects": prospect_data,
		"picks": pick_data,
		"scouting_reports": report_data,
		"favorite_prospect_ids": favorite_prospect_ids.duplicate(),
		"undrafted_converted": undrafted_converted,
	}


static func from_dict(data: Dictionary) -> DraftStateData:
	var draft := DraftStateData.new(int(data.get("draft_year", 2027)))
	draft.status = str(data.get("status", STATUS_PREPARATION))
	draft.current_pick_index = int(data.get("current_pick_index", 0))
	draft.scouting_points_remaining = int(data.get("scouting_points_remaining", 12))
	for prospect_data in data.get("prospects", []):
		draft.prospects.append(ProspectData.from_dict(prospect_data))
	for pick_data in data.get("picks", []):
		draft.picks.append(DraftPickData.from_dict(pick_data))
	for report_data in data.get("scouting_reports", []):
		draft.scouting_reports.append(ScoutingReportData.from_dict(report_data))
	for prospect_id in data.get("favorite_prospect_ids", []):
		draft.favorite_prospect_ids.append(str(prospect_id))
	draft.undrafted_converted = bool(data.get("undrafted_converted", false))
	return draft
