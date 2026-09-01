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
        cls.pack_path = ROOT / "data" / "leagues" / "nflverse_2026_preview.json"
        cls.pack = json.loads(cls.pack_path.read_text(encoding="utf-8"))

    def test_committed_pack_passes_schema_validation(self):
        IMPORTER.validate_pack(self.pack)
        self.assertEqual(1, self.pack["schema_version"])
        self.assertEqual(8, len(self.pack["teams"]))
        self.assertEqual(32, len(self.pack["free_agents"]))

    def test_position_mapping_matches_internal_roster_model(self):
        cases = [
            ({"position": "OL", "depth_chart_position": "T"}, ("LT", "RT")),
            ({"position": "DL", "depth_chart_position": "DE"}, ("EDGE",)),
            ({"position": "LB", "depth_chart_position": "ILB"}, ("LB",)),
            ({"position": "DB", "depth_chart_position": "FS"}, ("S",)),
            ({"position": "K", "depth_chart_position": "K"}, ("K",)),
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

    def test_pack_retains_provenance_but_excludes_media_urls(self):
        source = self.pack["source"]
        self.assertEqual("CC-BY-4.0", source["license"])
        self.assertEqual([2023, 2024, 2025], source["performance_seasons"])
        self.assertTrue(all(len(item["sha256"]) == 64 for item in source["files"]))
        for team in self.pack["teams"]:
            for player in team["players"]:
                self.assertNotIn("http", json.dumps(player).lower())


if __name__ == "__main__":
    unittest.main()
