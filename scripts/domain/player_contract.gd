class_name PlayerContract
extends RefCounted

const SOURCE_GENERATED := "Gridiron generated"
const SOURCE_LEGACY := "Legacy estimate"

# annual_salary is the contract's average annual value (APY). Salary-cap
# accounting must use current_cap_hit(), because real contracts rarely charge
# the same amount against the cap every season.
var annual_salary: int
var years_remaining: int
var guaranteed_money: int
var signed_year: int
var role: String
var expires_after_year: int
var total_contract_value: int
var total_guaranteed: int
var yearly_cap_hits: Dictionary
var yearly_cash: Dictionary
var yearly_release_penalties: Dictionary
var yearly_trade_penalties: Dictionary
var contract_type: String
var source_label: String
var source_url: String
var source_snapshot: String


func _init(
	contract_salary: int = 0,
	contract_years: int = 1,
	contract_guarantee: int = 0,
	contract_signed_year: int = 2026,
	contract_role: String = "Depth",
	contract_expiration_year: int = 0,
	contract_total_value: int = 0,
	contract_total_guaranteed: int = -1,
	contract_cap_hits: Dictionary = {},
	contract_cash: Dictionary = {},
	contract_release_penalties: Dictionary = {},
	contract_trade_penalties: Dictionary = {},
	contract_type_name: String = "Standard",
	contract_source_label: String = SOURCE_GENERATED,
	contract_source_url: String = "",
	contract_source_snapshot: String = ""
) -> void:
	annual_salary = maxi(contract_salary, 0)
	years_remaining = maxi(contract_years, 1)
	guaranteed_money = maxi(contract_guarantee, 0)
	signed_year = contract_signed_year
	role = contract_role
	expires_after_year = contract_expiration_year if contract_expiration_year > 0 else signed_year + years_remaining - 1
	total_contract_value = maxi(contract_total_value, annual_salary * years_remaining)
	total_guaranteed = guaranteed_money if contract_total_guaranteed < 0 else maxi(contract_total_guaranteed, 0)
	yearly_cap_hits = _normalized_schedule(contract_cap_hits)
	yearly_cash = _normalized_schedule(contract_cash)
	yearly_release_penalties = _normalized_schedule(contract_release_penalties)
	yearly_trade_penalties = _normalized_schedule(contract_trade_penalties)
	contract_type = contract_type_name
	source_label = contract_source_label
	source_url = contract_source_url
	source_snapshot = contract_source_snapshot
	_fill_missing_schedules()


func total_value() -> int:
	return total_contract_value


func remaining_value() -> int:
	var total := 0
	for year in range(current_year(), expires_after_year + 1):
		total += cash_for_year(year)
	return total


func expiration_year() -> int:
	return expires_after_year


func current_year() -> int:
	return expires_after_year - years_remaining + 1


func is_expiring_after(season_year: int) -> bool:
	return expires_after_year <= season_year


func cap_hit_for_year(season_year: int) -> int:
	if season_year < current_year() or season_year > expires_after_year:
		return 0
	return int(yearly_cap_hits.get(str(season_year), annual_salary))


func current_cap_hit() -> int:
	return cap_hit_for_year(current_year())


func cash_for_year(season_year: int) -> int:
	if season_year < current_year() or season_year > expires_after_year:
		return 0
	return int(yearly_cash.get(str(season_year), annual_salary))


func current_cash_payment() -> int:
	return cash_for_year(current_year())


func release_penalty(season_year: int = 0) -> int:
	var year := current_year() if season_year <= 0 else season_year
	if yearly_release_penalties.has(str(year)):
		return int(yearly_release_penalties[str(year)])
	return mini(guaranteed_money / maxi(years_remaining, 1), cap_hit_for_year(year))


func retirement_penalty(season_year: int = 0) -> int:
	return release_penalty(season_year)


func trade_penalty(season_year: int = 0) -> int:
	var year := current_year() if season_year <= 0 else season_year
	if yearly_trade_penalties.has(str(year)):
		return int(yearly_trade_penalties[str(year)])
	return release_penalty(year)


func advance_to_year(season_year: int) -> void:
	years_remaining = maxi(1, expires_after_year - season_year + 1)


func summary_label() -> String:
	return "%s APY / %d yr" % [money_label(annual_salary), years_remaining]


func to_dict() -> Dictionary:
	return {
		"annual_salary": annual_salary,
		"years_remaining": years_remaining,
		"guaranteed_money": guaranteed_money,
		"signed_year": signed_year,
		"role": role,
		"expires_after_year": expires_after_year,
		"total_contract_value": total_contract_value,
		"total_guaranteed": total_guaranteed,
		"yearly_cap_hits": yearly_cap_hits.duplicate(true),
		"yearly_cash": yearly_cash.duplicate(true),
		"yearly_release_penalties": yearly_release_penalties.duplicate(true),
		"yearly_trade_penalties": yearly_trade_penalties.duplicate(true),
		"contract_type": contract_type,
		"source_label": source_label,
		"source_url": source_url,
		"source_snapshot": source_snapshot,
	}


static func from_dict(data: Dictionary) -> PlayerContract:
	return PlayerContract.new(
		int(data.get("annual_salary", 0)),
		int(data.get("years_remaining", 1)),
		int(data.get("guaranteed_money", data.get("total_guaranteed", 0))),
		int(data.get("signed_year", 2026)),
		str(data.get("role", "Depth")),
		int(data.get("expires_after_year", int(data.get("signed_year", 2026)) + int(data.get("years_remaining", 1)) - 1)),
		int(data.get("total_contract_value", 0)),
		int(data.get("total_guaranteed", data.get("guaranteed_money", 0))),
		Dictionary(data.get("yearly_cap_hits", {})),
		Dictionary(data.get("yearly_cash", {})),
		Dictionary(data.get("yearly_release_penalties", {})),
		Dictionary(data.get("yearly_trade_penalties", {})),
		str(data.get("contract_type", "Legacy")),
		str(data.get("source_label", SOURCE_LEGACY)),
		str(data.get("source_url", "")),
		str(data.get("source_snapshot", ""))
	)


static func generated_contract(
	contract_salary: int,
	contract_years: int,
	contract_guarantee: int,
	contract_signed_year: int,
	contract_role: String,
	contract_type_name: String = "Standard"
) -> PlayerContract:
	var years := maxi(contract_years, 1)
	var apy := maxi(contract_salary, 0)
	var total := apy * years
	var cap_hits: Dictionary = {}
	var cash: Dictionary = {}
	var release_penalties: Dictionary = {}
	var trade_penalties: Dictionary = {}
	var weights: Array[float] = []
	var weight_total := 0.0
	for index in range(years):
		var weight := 0.84 + float(index) * 0.11
		weights.append(weight)
		weight_total += weight
	var allocated := 0
	for index in range(years):
		var year := contract_signed_year + index
		var cap_hit := total - allocated if index == years - 1 else roundi(float(total) * weights[index] / weight_total / 50_000.0) * 50_000
		allocated += cap_hit
		cap_hits[str(year)] = cap_hit
		cash[str(year)] = apy
		var unearned_guarantee := roundi(float(contract_guarantee) * float(years - index) / float(years) / 50_000.0) * 50_000
		release_penalties[str(year)] = mini(unearned_guarantee, total)
		trade_penalties[str(year)] = roundi(float(unearned_guarantee) * 0.65 / 50_000.0) * 50_000
	return PlayerContract.new(
		apy, years, contract_guarantee, contract_signed_year, contract_role,
		contract_signed_year + years - 1, total, contract_guarantee, cap_hits, cash,
		release_penalties, trade_penalties, contract_type_name, SOURCE_GENERATED
	)


static func initial_contract(player: PlayerData, season_year: int, depth_index: int = 0) -> PlayerContract:
	var premium := maxi(player.overall - 60, 0)
	var salary := 850_000 + premium * premium * 12_000
	salary = roundi(float(salary) * _position_multiplier(player.position) / 100_000.0) * 100_000
	var role_name := "Starter" if depth_index == 0 else ("Rotation" if depth_index <= 2 else "Depth")
	if depth_index == 0 and player.overall >= 88:
		role_name = "Franchise"
	var years := 4 if player.age <= 24 else (3 if player.age <= 28 else (2 if player.age <= 31 else 1))
	var guarantee_rate := 0.52 if role_name == "Franchise" else (0.38 if role_name == "Starter" else 0.22)
	return generated_contract(salary, years, roundi(float(salary * years) * guarantee_rate), season_year, role_name)


static func fantasy_draft_contract(player: PlayerData, season_year: int) -> PlayerContract:
	# A league-wide redraft cannot fairly carry cap structures negotiated by the
	# original clubs. Give every player a deterministic open-market deal so all
	# 32 teams draft against the same cap rules.
	var projected_depth := 0 if player.overall >= 78 else (1 if player.overall >= 70 else 3)
	var contract := initial_contract(player, season_year, projected_depth)
	contract.contract_type = "Fantasy Draft"
	contract.source_label = SOURCE_GENERATED
	return contract


static func rookie_contract(draft_year: int, round_number: int, pick_in_round: int) -> PlayerContract:
	var round_salaries := [5_600_000, 3_800_000, 2_700_000, 2_000_000, 1_500_000, 1_200_000, 1_000_000]
	var round_index := clampi(round_number - 1, 0, round_salaries.size() - 1)
	var salary := roundi(float(int(round_salaries[round_index])) * (1.0 - float(maxi(pick_in_round - 1, 0)) * 0.025) / 50_000.0) * 50_000
	var years := 4 if round_number <= 3 else 3
	var guarantee_rate := 0.70 if round_number == 1 else (0.50 if round_number <= 3 else (0.30 if round_number <= 5 else 0.15))
	return generated_contract(salary, years, roundi(float(salary * years) * guarantee_rate), draft_year, "Rookie", "Rookie")


static func practice_squad_contract(player: PlayerData, season_year: int) -> PlayerContract:
	var salary := 300_000 if player.experience_years <= 2 else 425_000
	return generated_contract(salary, 1, salary, season_year, "Practice Squad", "Practice Squad")


static func money_label(amount: int) -> String:
	if absi(amount) >= 1_000_000:
		return "$%.1fM" % (float(amount) / 1_000_000.0)
	if absi(amount) >= 1_000:
		return "$%dK" % roundi(float(amount) / 1_000.0)
	return "$%d" % amount


static func _position_multiplier(position_name: String) -> float:
	match position_name:
		"QB":
			return 1.42
		"EDGE", "LT", "CB", "WR":
			return 1.16
		"DT", "LB", "S", "RT":
			return 1.08
		"K", "P", "LS":
			return 0.72
		_:
			return 1.0


static func _normalized_schedule(schedule: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for year in schedule:
		normalized[str(year)] = maxi(int(schedule[year]), 0)
	return normalized


func _fill_missing_schedules() -> void:
	for year in range(current_year(), expires_after_year + 1):
		var key := str(year)
		if not yearly_cap_hits.has(key):
			yearly_cap_hits[key] = annual_salary
		if not yearly_cash.has(key):
			yearly_cash[key] = annual_salary
