import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("nflverse_importer", ROOT / "tools" / "nflverse_importer.py")
IMPORTER = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(IMPORTER)


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


if __name__ == "__main__":
    unittest.main()
