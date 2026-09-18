import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("nflverse_importer", ROOT / "tools" / "nflverse_importer.py")
IMPORTER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(IMPORTER)
CONTRACT_SPEC = importlib.util.spec_from_file_location(
    "contract_data_importer", ROOT / "tools" / "contract_data_importer.py"
)
CONTRACT_IMPORTER = importlib.util.module_from_spec(CONTRACT_SPEC)
assert CONTRACT_SPEC.loader is not None
CONTRACT_SPEC.loader.exec_module(CONTRACT_IMPORTER)


class NflverseImporterTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.pack_path = ROOT / "data" / "leagues" / "nflverse_2026_full.json"
        cls.pack = json.loads(cls.pack_path.read_text(encoding="utf-8"))

    def test_committed_pack_passes_schema_validation(self):
        IMPORTER.validate_pack(self.pack)
        self.assertEqual(2, self.pack["schema_version"])
        self.assertEqual(32, len(self.pack["teams"]))
        self.assertTrue(all(len(team["players"]) == 53 for team in self.pack["teams"]))
        self.assertGreaterEqual(len(self.pack["free_agents"]), 100)
        self.assertEqual(272, len(self.pack["schedule"]))

    def test_position_mapping_matches_internal_roster_model(self):
        cases = [
            ({"position": "OL", "depth_chart_position": "T"}, ("LT", "RT", "LG", "RG")),
            ({"position": "DL", "depth_chart_position": "DE"}, ("EDGE",)),
            ({"position": "LB", "depth_chart_position": "ILB"}, ("LB",)),
            ({"position": "DB", "depth_chart_position": "FS"}, ("S",)),
            ({"position": "K", "depth_chart_position": "K"}, ("K",)),
            ({"position": "LS", "depth_chart_position": "LS"}, ("LS",)),
        ]
        for source, expected in cases:
            with self.subTest(source=source):
                self.assertEqual(expected, IMPORTER.eligible_positions(source))

    def test_generated_attributes_are_deterministic_and_bounded(self):
        candidate = {"id": "00-test", "overall": 81, "age": 25}
        first = IMPORTER._attributes(candidate, "QB")
        second = IMPORTER._attributes(candidate, "QB")
        self.assertEqual(first, second)
        self.assertTrue(all(42 <= value <= 98 for value in first.values()))

    def test_pack_retains_provenance_and_hybrid_media_metadata(self):
        source = self.pack["source"]
        self.assertEqual("CC-BY-4.0", source["license"])
        self.assertEqual([2023, 2024, 2025], source["performance_seasons"])
        self.assertTrue(all(len(item["sha256"]) == 64 for item in source["files"]))
        self.assertEqual("Madden NFL 26", source["ratings_source"])
        self.assertEqual(2035, source["hybrid_player_count"])
        self.assertTrue(all(team["logo_url"].startswith("https://") for team in self.pack["teams"]))
        for team in self.pack["teams"]:
            for player in team["players"]:
                ratings = player["madden_ratings"]
                self.assertGreaterEqual(len(ratings["attributes"]), 50)
                self.assertTrue(not ratings["portrait_url"] or ratings["portrait_url"].startswith("https://"))
                core_player = dict(player)
                core_player.pop("madden_ratings")
                self.assertNotIn("http", json.dumps(core_player).lower())

    def test_schedule_and_current_team_names_are_complete(self):
        teams = {team["abbreviation"]: team for team in self.pack["teams"]}
        self.assertEqual("Las Vegas Raiders", f"{teams['LV']['city']} {teams['LV']['nickname']}")
        self.assertEqual("Los Angeles Chargers", f"{teams['LAC']['city']} {teams['LAC']['nickname']}")
        self.assertEqual("Los Angeles Rams", f"{teams['LA']['city']} {teams['LA']['nickname']}")
        games_by_team = {team_id: 0 for team_id in (team["id"] for team in teams.values())}
        weeks_by_team = {team_id: set() for team_id in games_by_team}
        for game in self.pack["schedule"]:
            for team_id in (game["away_team_id"], game["home_team_id"]):
                games_by_team[team_id] += 1
                self.assertNotIn(game["week"], weeks_by_team[team_id])
                weeks_by_team[team_id].add(game["week"])
        self.assertTrue(all(count == 17 for count in games_by_team.values()))

    def test_current_contract_snapshot_separates_apy_and_cap_hit(self):
        errors = CONTRACT_IMPORTER.validate_pack(self.pack, 2026)
        self.assertEqual([], errors)
        chase = next(
            player
            for team in self.pack["teams"]
            for player in team["players"]
            if player["full_name"] == "Ja'Marr Chase"
        )
        contract = chase["contract"]
        self.assertEqual(40_250_000, contract["annual_salary"])
        self.assertEqual(26_171_176, contract["yearly_cap_hits"]["2026"])
        self.assertEqual(161_000_000, contract["total_contract_value"])
        self.assertEqual(73_900_000, contract["total_guaranteed"])
        self.assertEqual(2029, contract["expires_after_year"])
        self.assertEqual(
            "Over The Cap current contracts and team cap tables",
            contract["source_label"],
        )

    def test_contract_refresh_never_scales_player_values_for_cap_compliance(self):
        for team in self.pack["teams"]:
            self.assertEqual(301_200_000, team["base_salary_cap"])
            cap_year = str(team["salary_cap_year"])
            payroll = sum(
                player["contract"]["yearly_cap_hits"][cap_year]
                for player in team["players"]
            )
            self.assertLessEqual(payroll, team["salary_cap"])
            self.assertEqual(
                team["salary_cap"] - team["base_salary_cap"],
                team["salary_cap_adjustment"],
            )


if __name__ == "__main__":
    unittest.main()
