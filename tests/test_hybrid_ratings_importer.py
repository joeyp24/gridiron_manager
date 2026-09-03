import copy
import importlib.util
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("hybrid_ratings_importer", ROOT / "tools" / "hybrid_ratings_importer.py")
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def rating_player(player_id: int, first: str, last: str, position: str, team: str, age: int = 25) -> dict:
    stat_names = {
        "acceleration", "agility", "awareness", "bCVision", "blockShedding", "breakSack", "breakTackle",
        "carrying", "catching", "catchInTraffic", "changeOfDirection", "deepRouteRunning", "finesseMoves",
        "hitPower", "impactBlocking", "injury", "jukeMove", "jumping", "kickAccuracy", "kickPower",
        "kickReturn", "leadBlock", "manCoverage", "mediumRouteRunning", "overall", "passBlock",
        "passBlockFinesse", "passBlockPower", "playAction", "playRecognition", "powerMoves", "press",
        "pursuit", "release", "runBlock", "runBlockFinesse", "runBlockPower", "shortRouteRunning",
        "spectacularCatch", "speed", "spinMove", "stamina", "stiffArm", "strength", "tackle",
        "throwAccuracyDeep", "throwAccuracyMid", "throwAccuracyShort", "throwOnTheRun", "throwPower",
        "throwUnderPressure", "toughness", "trucking", "zoneCoverage",
    }
    stats = {name: {"value": 80, "diff": 0} for name in stat_names}
    stats["speed"]["value"] = 93
    stats["awareness"]["value"] = 87
    stats["runningStyle"] = {"value": "Default", "diff": 0}
    return {
        "id": player_id,
        "firstName": first,
        "lastName": last,
        "age": age,
        "yearsPro": 3,
        "overallRating": 88,
        "jerseyNum": 11,
        "avatarUrl": f"https://example.test/players/{player_id}.png",
        "position": {"id": position},
        "team": {"label": team, "imageUrl": f"https://example.test/teams/{team}.png"},
        "iteration": {"label": "Test Ratings"},
        "archetype": {"label": "Test Archetype"},
        "playerAbilities": [{"id": "one", "label": "Ability", "description": "Test", "type": {"label": "Superstar"}}],
        "stats": stats,
    }


def game_player(player_id: str, name: str, position: str, age: int = 25) -> dict:
    return {
        "id": player_id,
        "full_name": name,
        "position": position,
        "age": age,
        "experience_years": 3,
        "overall": 72,
        "potential": 78,
        "career_peak_overall": 72,
        "team_history": ["nfl_test"],
    }


class HybridRatingsImporterTests(unittest.TestCase):
    def setUp(self) -> None:
        self.pack = {
            "teams": [{
                "id": "nfl_test",
                "city": "Test",
                "nickname": "Team",
                "players": [game_player("gsis-one", "Alex Player", "WR")],
            }],
            "free_agents": [],
            "source": {"attribution": "NFLverse data."},
        }
        self.ratings = [rating_player(101, "Alex", "Player", "WR", "Test Team")]

    def test_normalizes_madden_positions(self) -> None:
        self.assertEqual("RB", MODULE.normalize_position("HB"))
        self.assertEqual("EDGE", MODULE.normalize_position("REDG"))
        self.assertEqual("LB", MODULE.normalize_position("MIKE"))
        self.assertEqual("S", MODULE.normalize_position("FS"))

    def test_enriches_every_player_and_preserves_identity(self) -> None:
        hybrid, report = MODULE.build_hybrid_pack(copy.deepcopy(self.pack), copy.deepcopy(self.ratings), False)
        player = hybrid["teams"][0]["players"][0]
        self.assertEqual("gsis-one", player["id"])
        self.assertEqual(88, player["overall"])
        self.assertEqual(93, player["speed"])
        self.assertEqual("101", player["madden_ratings"]["source_player_id"])
        self.assertGreaterEqual(len(player["madden_ratings"]["attributes"]), 50)
        self.assertEqual("https://example.test/teams/Test Team.png", hybrid["teams"][0]["logo_url"])
        self.assertEqual(1, report["matched_player_count"])
        self.assertEqual([], MODULE.validate_hybrid_pack(hybrid))

    def test_ambiguous_names_resolve_by_position_and_team(self) -> None:
        self.pack["teams"][0]["players"][0] = game_player("gsis-two", "Byron Young", "EDGE")
        self.pack["teams"][0]["city"] = "Los Angeles"
        self.pack["teams"][0]["nickname"] = "Rams"
        self.ratings = [
            rating_player(201, "Byron", "Young", "DT", "Philadelphia Eagles"),
            rating_player(202, "Byron", "Young", "REDG", "Los Angeles Rams"),
        ]
        hybrid, report = MODULE.build_hybrid_pack(self.pack, self.ratings, False)
        player = hybrid["teams"][0]["players"][0]
        self.assertEqual("202", player["madden_ratings"]["source_player_id"])
        self.assertEqual(1, report["ambiguous_resolution_count"])

    def test_output_is_deterministic(self) -> None:
        first, first_report = MODULE.build_hybrid_pack(self.pack, self.ratings, False)
        second, second_report = MODULE.build_hybrid_pack(self.pack, self.ratings, False)
        self.assertEqual(json.dumps(first, sort_keys=True), json.dumps(second, sort_keys=True))
        self.assertEqual(first_report, second_report)

    def test_validation_reports_missing_ratings(self) -> None:
        errors = MODULE.validate_hybrid_pack(self.pack)
        self.assertTrue(any("missing madden_ratings" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
