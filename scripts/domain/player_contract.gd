class_name PlayerContract
extends RefCounted

var annual_salary: int
var years_remaining: int
var guaranteed_money: int
var signed_year: int
var role: String


func _init(
	contract_salary: int = 0,
	contract_years: int = 1,
	contract_guarantee: int = 0,
	contract_signed_year: int = 2026,
	contract_role: String = "Depth"
) -> void:
	annual_salary = maxi(contract_salary, 0)
	years_remaining = maxi(contract_years, 1)
	guaranteed_money = maxi(contract_guarantee, 0)
	signed_year = contract_signed_year
	role = contract_role


func total_value() -> int:
	return annual_salary * years_remaining


func expiration_year() -> int:
	return signed_year + years_remaining - 1


func release_penalty() -> int:
	return mini(guaranteed_money / maxi(years_remaining, 1), annual_salary)


func summary_label() -> String:
	return "%s / %d yr" % [money_label(annual_salary), years_remaining]


func to_dict() -> Dictionary:
	return {
		"annual_salary": annual_salary,
		"years_remaining": years_remaining,
		"guaranteed_money": guaranteed_money,
		"signed_year": signed_year,
		"role": role,
	}


static func from_dict(data: Dictionary) -> PlayerContract:
	return PlayerContract.new(
		int(data.get("annual_salary", 0)),
		int(data.get("years_remaining", 1)),
		int(data.get("guaranteed_money", 0)),
		int(data.get("signed_year", 2026)),
		str(data.get("role", "Depth"))
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
	return PlayerContract.new(salary, years, roundi(float(salary * years) * guarantee_rate), season_year, role_name)


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
		"K", "P":
			return 0.72
		_:
			return 1.0
