class_name DraftClassGenerator
extends RefCounted

const POSITION_POOL: Array[String] = [
	"QB", "QB", "QB", "QB", "QB", "QB",
	"RB", "RB", "RB", "RB", "RB", "RB",
	"WR", "WR", "WR", "WR", "WR", "WR", "WR", "WR", "WR",
	"TE", "TE", "TE", "TE", "TE",
	"LT", "LT", "LT", "LT", "LT", "LG", "LG", "LG", "LG",
	"C", "C", "C", "C", "RG", "RG", "RG", "RG", "RT", "RT", "RT", "RT", "RT",
	"EDGE", "EDGE", "EDGE", "EDGE", "EDGE", "EDGE", "EDGE",
	"DT", "DT", "DT", "DT", "DT", "DT",
	"LB", "LB", "LB", "LB", "LB", "LB", "LB",
	"CB", "CB", "CB", "CB", "CB", "CB", "CB", "CB",
	"S", "S", "S", "S", "S", "S", "K", "K", "P", "P", "LS",
]


static func generate(draft_year: int, seed: int, class_size: int = 0, teams_per_round: int = 32) -> Array[ProspectData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + draft_year * 65537
	var prospects: Array[ProspectData] = []
	var target_size := class_size if class_size > 0 else POSITION_POOL.size()
	var shuffled_positions: Array[String] = []
	while shuffled_positions.size() < target_size:
		shuffled_positions.append_array(POSITION_POOL)
	shuffled_positions.resize(target_size)
	for index in range(shuffled_positions.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var current: String = shuffled_positions[index]
		shuffled_positions[index] = shuffled_positions[swap_index]
		shuffled_positions[swap_index] = current
	for index in range(shuffled_positions.size()):
		var position_name: String = shuffled_positions[index]
		prospects.append(PlayerGenerator.generate_prospect(position_name, draft_year, index, seed))
	prospects.sort_custom(func(a: ProspectData, b: ProspectData):
		var a_grade := float(a.true_overall) * 0.62 + float(a.true_potential) * 0.28 + float(a.production_grade) * 0.10
		var b_grade := float(b.true_overall) * 0.62 + float(b.true_potential) * 0.28 + float(b.production_grade) * 0.10
		return a_grade > b_grade
	)
	for index in range(prospects.size()):
		prospects[index].consensus_rank = index + 1
		prospects[index].projected_round = mini(8, floori(float(index) / float(maxi(teams_per_round, 1))) + 1)
	return prospects
