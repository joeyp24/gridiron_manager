#!/usr/bin/env python3
"""Build a deterministic, offline Godot data pack from public nflverse CSV assets."""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import json
import math
import sys
import urllib.request
from collections import defaultdict
from datetime import date
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 2
RATING_MODEL_VERSION = 1
DEFAULT_TEAMS = (
    "ARI", "ATL", "BAL", "BUF", "CAR", "CHI", "CIN", "CLE",
    "DAL", "DEN", "DET", "GB", "HOU", "IND", "JAX", "KC",
    "LV", "LAC", "LA", "MIA", "MIN", "NE", "NO", "NYG",
    "NYJ", "PHI", "PIT", "SF", "SEA", "TB", "TEN", "WAS",
)
CURRENT_TEAM_NAMES = {
    "ARI": ("Arizona", "Cardinals"), "ATL": ("Atlanta", "Falcons"),
    "BAL": ("Baltimore", "Ravens"), "BUF": ("Buffalo", "Bills"),
    "CAR": ("Carolina", "Panthers"), "CHI": ("Chicago", "Bears"),
    "CIN": ("Cincinnati", "Bengals"), "CLE": ("Cleveland", "Browns"),
    "DAL": ("Dallas", "Cowboys"), "DEN": ("Denver", "Broncos"),
    "DET": ("Detroit", "Lions"), "GB": ("Green Bay", "Packers"),
    "HOU": ("Houston", "Texans"), "IND": ("Indianapolis", "Colts"),
    "JAX": ("Jacksonville", "Jaguars"), "KC": ("Kansas City", "Chiefs"),
    "LV": ("Las Vegas", "Raiders"), "LAC": ("Los Angeles", "Chargers"),
    "LA": ("Los Angeles", "Rams"), "MIA": ("Miami", "Dolphins"),
    "MIN": ("Minnesota", "Vikings"), "NE": ("New England", "Patriots"),
    "NO": ("New Orleans", "Saints"), "NYG": ("New York", "Giants"),
    "NYJ": ("New York", "Jets"), "PHI": ("Philadelphia", "Eagles"),
    "PIT": ("Pittsburgh", "Steelers"), "SF": ("San Francisco", "49ers"),
    "SEA": ("Seattle", "Seahawks"), "TB": ("Tampa Bay", "Buccaneers"),
    "TEN": ("Tennessee", "Titans"), "WAS": ("Washington", "Commanders"),
}
TEAM_ALIASES = {"AZ": "ARI", "JAC": "JAX", "STL": "LA", "OAK": "LV", "SD": "LAC"}
ROSTER_COUNTS = {
    "QB": 3, "RB": 4, "WR": 6, "TE": 3,
    "LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
    "EDGE": 4, "DT": 4, "LB": 6, "CB": 6, "S": 4,
    "K": 1, "P": 1, "LS": 1,
}
POSITION_ORDER = ("QB", "K", "P", "LS", "C", "TE", "RB", "WR", "LT", "RT", "LG", "RG", "DT", "EDGE", "LB", "CB", "S")
FREE_AGENT_TARGET_PER_POSITION = 8
PERSONALITIES = ("Driven", "Professional", "Team Leader", "Reserved", "Independent", "Competitive")
STAT_WEIGHTS = {2023: 0.20, 2024: 0.30, 2025: 0.50}
SOURCE_URLS = {
    "players.csv": "https://github.com/nflverse/nflverse-data/releases/download/players/players.csv",
    "roster_{season}.csv": "https://github.com/nflverse/nflverse-data/releases/download/rosters/roster_{season}.csv",
    "stats_{year}.csv.gz": "https://github.com/nflverse/nflverse-data/releases/download/stats_player/stats_player_reg_{year}.csv.gz",
    "teams.csv": "https://github.com/nflverse/nflverse-data/releases/download/teams/teams_colors_logos.csv",
    "contracts.csv.gz": "https://github.com/nflverse/nflverse-data/releases/download/contracts/historical_contracts.csv.gz",
    "games.csv": "https://raw.githubusercontent.com/nflverse/nfldata/master/data/games.csv",
}


def _number(value: Any, default: float = 0.0) -> float:
    try:
        if value is None or str(value).strip() in ("", "NA", "NaN"):
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def _integer(value: Any, default: int = 0) -> int:
    return int(round(_number(value, float(default))))


def _clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def _stable_int(*parts: Any) -> int:
    digest = hashlib.sha256(":".join(str(part) for part in parts).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big", signed=False)


def _jitter(player_id: str, attribute: str, radius: int = 6) -> int:
    return _stable_int(player_id, attribute) % (radius * 2 + 1) - radius


def _normalize_team(abbreviation: str) -> str:
    value = abbreviation.strip().upper()
    return TEAM_ALIASES.get(value, value)


def _read_csv(path: Path) -> list[dict[str, str]]:
    opener = gzip.open if path.suffix == ".gz" else open
    with opener(path, "rt", encoding="utf-8-sig", newline="") as handle:
        return list(csv.DictReader(handle))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "gridiron-manager-nflverse-importer"})
    with urllib.request.urlopen(request, timeout=90) as response, destination.open("wb") as output:
        output.write(response.read())


def _source_paths(cache_dir: Path, season: int, stat_years: Iterable[int], offline: bool) -> dict[str, Path]:
    paths = {
        "players": cache_dir / "players.csv",
        "roster": cache_dir / f"roster_{season}.csv",
        "teams": cache_dir / "teams.csv",
        "contracts": cache_dir / "contracts.csv.gz",
        "games": cache_dir / "games.csv",
    }
    for year in stat_years:
        paths[f"stats_{year}"] = cache_dir / f"stats_{year}.csv.gz"
    urls = {
        "players": SOURCE_URLS["players.csv"],
        "roster": SOURCE_URLS["roster_{season}.csv"].format(season=season),
        "teams": SOURCE_URLS["teams.csv"],
        "contracts": SOURCE_URLS["contracts.csv.gz"],
        "games": SOURCE_URLS["games.csv"],
    }
    for year in stat_years:
        urls[f"stats_{year}"] = SOURCE_URLS["stats_{year}.csv.gz"].format(year=year)
    for key, path in paths.items():
        if path.exists():
            continue
        if offline:
            raise FileNotFoundError(f"Missing offline source file: {path}")
        print(f"Downloading {urls[key]}")
        _download(urls[key], path)
    return paths


def eligible_positions(row: dict[str, Any]) -> tuple[str, ...]:
    position = str(row.get("position", "")).upper().strip()
    depth = str(row.get("depth_chart_position", "")).upper().strip()
    value = depth or position
    if value == "QB":
        return ("QB",)
    if value in ("RB", "FB"):
        return ("RB",)
    if value == "WR":
        return ("WR",)
    if value == "TE":
        return ("TE",)
    if value in ("T", "OT"):
        return ("LT", "RT", "LG", "RG")
    if value in ("G", "OG"):
        return ("LG", "RG", "C")
    if value == "C":
        return ("C", "LG", "RG")
    if position == "OL" or value == "OL":
        return ("LT", "LG", "C", "RG", "RT")
    if value in ("DE", "EDGE"):
        return ("EDGE",)
    if value in ("DT", "NT"):
        return ("DT",)
    if value == "OLB":
        return ("EDGE", "LB")
    if value in ("LB", "ILB", "MLB"):
        return ("LB",)
    if value == "CB":
        return ("CB",)
    if value in ("FS", "SS", "S"):
        return ("S",)
    if position == "DB" or value == "DB":
        return ("CB", "S")
    if value == "K":
        return ("K",)
    if value == "P":
        return ("P",)
    if value == "LS" or position == "LS":
        return ("LS",)
    return ()


def _rating_group(row: dict[str, Any]) -> str:
    eligible = eligible_positions(row)
    if "QB" in eligible:
        return "QB"
    if "RB" in eligible:
        return "RB"
    if "WR" in eligible or "TE" in eligible:
        return "RECEIVER"
    if any(position in eligible for position in ("LT", "LG", "C", "RG", "RT")):
        return "OL"
    if "EDGE" in eligible or "DT" in eligible:
        return "DL"
    if "LB" in eligible:
        return "LB"
    if "CB" in eligible or "S" in eligible:
        return "DB"
    if "K" in eligible:
        return "K"
    if "P" in eligible:
        return "P"
    if "LS" in eligible:
        return "LS"
    return "OTHER"


def _aggregate_stats(paths: dict[str, Path], stat_years: Iterable[int]) -> dict[str, dict[str, float]]:
    aggregated: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    for year in stat_years:
        weight = STAT_WEIGHTS.get(year, 1.0)
        for row in _read_csv(paths[f"stats_{year}"]):
            player_id = row.get("player_id", "").strip()
            if not player_id:
                continue
            for key, value in row.items():
                if key in ("player_id", "player_name", "player_display_name", "position", "position_group", "headshot_url", "season_type", "recent_team"):
                    continue
                aggregated[player_id][key] += _number(value) * weight
            aggregated[player_id]["stat_weight"] += weight
    return {player_id: dict(values) for player_id, values in aggregated.items()}


def _draft_bonus(player: dict[str, Any]) -> float:
    draft_round = _integer(player.get("draft_round"), 0)
    draft_pick = _integer(player.get("draft_pick"), 0)
    if draft_round <= 0:
        return 0.0
    return max(0.0, 11.0 - draft_round * 1.35 - draft_pick / 110.0)


def performance_score(candidate: dict[str, Any]) -> float:
    stats = candidate["stats"]
    group = candidate["rating_group"]
    games = max(stats.get("games", 0.0), 1.0)
    draft = _draft_bonus(candidate["player_info"])
    experience = _number(candidate["roster"].get("years_exp"), 0.0)
    status_bonus = 2.0 if candidate["roster"].get("status") == "ACT" else 0.0
    if group == "QB":
        attempts = max(stats.get("attempts", 0.0), 1.0)
        sacks = stats.get("sacks_suffered", 0.0)
        score = (
            stats.get("passing_epa", 0.0) / attempts * 52.0
            + stats.get("passing_cpoe", 0.0) * 0.55
            + stats.get("passing_yards", 0.0) / attempts * 1.8
            - stats.get("passing_interceptions", 0.0) / attempts * 42.0
            - sacks / max(attempts + sacks, 1.0) * 18.0
            + stats.get("rushing_epa", 0.0) / max(stats.get("carries", 0.0), 20.0) * 10.0
            + math.log1p(attempts) * 2.1
        )
    elif group == "RB":
        carries = max(stats.get("carries", 0.0), 1.0)
        targets = max(stats.get("targets", 0.0), 1.0)
        score = (
            stats.get("rushing_yards", 0.0) / carries * 3.0
            + stats.get("rushing_epa", 0.0) / carries * 32.0
            + stats.get("receiving_yards", 0.0) / targets * 0.8
            + stats.get("rushing_first_downs", 0.0) / carries * 14.0
            - stats.get("fumbles_lost_total", 0.0) / max(carries + targets, 1.0) * 45.0
            + math.log1p(carries + targets) * 1.6
        )
    elif group == "RECEIVER":
        targets = max(stats.get("targets", 0.0), 1.0)
        score = (
            stats.get("receiving_yards", 0.0) / targets * 2.6
            + stats.get("receptions", 0.0) / targets * 13.0
            + stats.get("receiving_epa", 0.0) / targets * 30.0
            + stats.get("receiving_first_downs", 0.0) / targets * 15.0
            + stats.get("target_share", 0.0) * 15.0
            + math.log1p(targets) * 1.7
        )
    elif group in ("DL", "LB", "DB"):
        score = (
            stats.get("def_sacks", 0.0) * 3.2
            + stats.get("def_qb_hits", 0.0) * 0.75
            + stats.get("def_tackles_for_loss", 0.0) * 0.85
            + stats.get("def_interceptions", 0.0) * 3.4
            + stats.get("def_pass_defended", 0.0) * 1.05
            + (stats.get("def_tackles_solo", 0.0) + stats.get("def_tackle_assists", 0.0) * 0.5) * 0.09
        ) / games * 9.0 + math.log1p(games) * 2.0
    elif group == "K":
        attempts = max(stats.get("fg_att", 0.0), 1.0)
        score = stats.get("fg_made", 0.0) / attempts * 42.0 + stats.get("fg_long", 0.0) * 0.24 + math.log1p(attempts) * 2.2
    elif group == "P":
        attempts = max(stats.get("pt_att", 0.0), 1.0)
        score = stats.get("pt_net_yards", 0.0) / attempts + stats.get("pt_inside_20", 0.0) / attempts * 16.0 + math.log1p(attempts)
    else:
        score = games * 0.6
    if group == "OL":
        score = games * 1.25 + experience * 0.45 + draft * 1.25
    age = candidate["age"]
    age_penalty = max(age - {"QB": 34, "K": 35, "P": 35, "LS": 35, "OL": 32}.get(group, 30), 0) * 0.8
    return score + draft + min(experience, 8.0) * 0.20 + status_bonus - age_penalty


def _assign_overalls(candidates: list[dict[str, Any]]) -> None:
    grouped: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for candidate in candidates:
        candidate["score"] = performance_score(candidate)
        grouped[candidate["rating_group"]].append(candidate)
    for group in grouped.values():
        ordered = sorted(group, key=lambda item: (item["score"], item["id"]))
        denominator = max(len(ordered) - 1, 1)
        for index, candidate in enumerate(ordered):
            percentile = index / denominator
            candidate["overall"] = int(_clamp(round(58 + percentile * 35), 56, 94))


def _age(birth_date: str, season: int) -> int:
    try:
        born = date.fromisoformat(birth_date)
        opening = date(season, 9, 1)
        return opening.year - born.year - ((opening.month, opening.day) < (born.month, born.day))
    except (TypeError, ValueError):
        return 24


def _attributes(candidate: dict[str, Any], position: str) -> dict[str, int]:
    overall = candidate["overall"]
    player_id = candidate["id"]
    offsets = {
        "QB": (-3, -3, 6, 6), "RB": (7, 2, 2, -2), "WR": (8, -4, 5, 0), "TE": (1, 6, 4, 1),
        "LT": (-6, 9, 5, 3), "LG": (-7, 10, 4, 2), "C": (-8, 8, 6, 5), "RG": (-7, 10, 4, 2), "RT": (-6, 9, 5, 3),
        "EDGE": (2, 7, 5, 1), "DT": (-5, 10, 4, 2), "LB": (3, 4, 4, 3), "CB": (9, -3, 5, 3), "S": (6, 1, 4, 5),
        "K": (-12, -5, 11, 4), "P": (-10, -3, 10, 4), "LS": (-9, 2, 12, 7),
    }[position]
    speed = int(_clamp(overall + offsets[0] + _jitter(player_id, "speed"), 42, 98))
    power = int(_clamp(overall + offsets[1] + _jitter(player_id, "power"), 42, 98))
    technique = int(_clamp(overall + offsets[2] + _jitter(player_id, "technique"), 42, 98))
    awareness = int(_clamp(overall + offsets[3] + _jitter(player_id, "awareness"), 42, 98))
    durability = int(_clamp(overall + _jitter(player_id, "durability", 10) - max(candidate["age"] - 31, 0), 48, 96))
    return {"speed": speed, "power": power, "technique": technique, "awareness": awareness, "durability": durability}


def _archetype(position: str, attributes: dict[str, int]) -> str:
    if position == "QB":
        return "Field General" if attributes["awareness"] >= attributes["speed"] else "Dual Threat"
    if position == "RB":
        return "Power Back" if attributes["power"] > attributes["speed"] else "Home-Run Threat"
    if position == "WR":
        return "Route Technician" if attributes["technique"] >= attributes["speed"] else "Vertical Threat"
    if position in ("CB", "S"):
        return "Ball Hawk" if attributes["awareness"] >= attributes["power"] else "Press Enforcer"
    if position in ("LT", "LG", "C", "RG", "RT", "DT", "EDGE"):
        return "Power" if attributes["power"] >= attributes["technique"] else "Technical"
    if position in ("K", "P", "LS"):
        return "Precision"
    return "Versatile"


def _role(depth_index: int, overall: int) -> str:
    if depth_index == 0 and overall >= 88:
        return "Franchise"
    if depth_index == 0:
        return "Starter"
    if depth_index <= 2:
        return "Rotation"
    return "Depth"


def _contract(candidate: dict[str, Any], contracts: dict[str, dict[str, str]], season: int, depth_index: int) -> dict[str, Any]:
    overall = candidate["overall"]
    role = _role(depth_index, overall)
    otc_id = str(candidate["player_info"].get("otc_id", "")).strip()
    source = contracts.get(otc_id)
    if source:
        signed_year = _integer(source.get("year_signed"), season)
        total_years = max(_integer(source.get("years"), 1), 1)
        expiration = max(signed_year + total_years - 1, season)
        years_remaining = max(expiration - season + 1, 1)
        annual = int(_clamp(_number(source.get("apy"), 0.0), 795_000, 60_000_000))
        total_guaranteed = max(_integer(source.get("guaranteed"), 0), 0)
        guaranteed = round(total_guaranteed * years_remaining / total_years)
        return {
            "annual_salary": annual,
            "years_remaining": years_remaining,
            "guaranteed_money": guaranteed,
            "signed_year": signed_year,
            "role": role,
            "expires_after_year": expiration,
        }
    premium = max(overall - 60, 0)
    salary = round((850_000 + premium * premium * 12_000) / 100_000) * 100_000
    years = 4 if candidate["age"] <= 24 else 3 if candidate["age"] <= 28 else 2 if candidate["age"] <= 31 else 1
    guarantee_rate = 0.52 if role == "Franchise" else 0.38 if role == "Starter" else 0.22
    return {
        "annual_salary": salary,
        "years_remaining": years,
        "guaranteed_money": round(salary * years * guarantee_rate),
        "signed_year": season,
        "role": role,
        "expires_after_year": season + years - 1,
    }


def _player(candidate: dict[str, Any], position: str, team_id: str, contracts: dict[str, dict[str, str]], season: int, depth_index: int, free_agent: bool = False) -> dict[str, Any]:
    roster = candidate["roster"]
    info = candidate["player_info"]
    attributes = _attributes(candidate, position)
    age = candidate["age"]
    experience = max(_integer(roster.get("years_exp"), _integer(info.get("years_of_experience"), max(age - 22, 0))), 0)
    entry_year = _integer(roster.get("entry_year"), season - experience)
    potential_window = 9 if age <= 22 else 6 if age <= 25 else 3 if age <= 28 else 1
    potential = int(_clamp(candidate["overall"] + (_stable_int(candidate["id"], "potential") % (potential_window + 1)), candidate["overall"], 97))
    draft_team = _normalize_team(str(info.get("draft_team", "") or roster.get("draft_club", "")))
    original_team_id = f"nfl_{draft_team.lower()}" if draft_team else team_id
    contract = None if free_agent else _contract(candidate, contracts, season, depth_index)
    return {
        "id": candidate["id"],
        "full_name": roster.get("full_name") or info.get("display_name") or "Unknown Player",
        "position": position,
        "overall": candidate["overall"],
        **attributes,
        "age": age,
        "potential": potential,
        "archetype": _archetype(position, attributes),
        "personality": PERSONALITIES[_stable_int(candidate["id"], "personality") % len(PERSONALITIES)],
        "height_inches": _integer(roster.get("height"), _integer(info.get("height"), 72)),
        "weight_lbs": _integer(roster.get("weight"), _integer(info.get("weight"), 220)),
        "college": roster.get("college") or info.get("college_name") or "Independent",
        "experience_years": experience,
        "entry_year": entry_year,
        "draft_round": _integer(info.get("draft_round"), 0),
        "draft_pick": _integer(info.get("draft_pick"), _integer(roster.get("draft_number"), 0)),
        "original_team_id": original_team_id,
        "team_history": [team_id] if team_id else [],
        "career_peak_overall": candidate["overall"],
        "seasons_as_free_agent": 0,
        "generation_source": f"nflverse {season}",
        "energy": 100,
        "is_active": True,
        "injury_type": "",
        "injury_weeks": 0,
        "contract": contract,
    }


def _select_team_roster(team_candidates: list[dict[str, Any]]) -> tuple[list[tuple[dict[str, Any], str, int]], list[dict[str, Any]]]:
    selected: list[tuple[dict[str, Any], str, int]] = []
    used: set[str] = set()
    for position in POSITION_ORDER:
        eligible = [candidate for candidate in team_candidates if candidate["id"] not in used and position in candidate["eligible"]]
        eligible.sort(key=lambda item: (item["overall"], item["score"], item["id"]), reverse=True)
        needed = ROSTER_COUNTS[position]
        if len(eligible) < needed:
            raise ValueError(f"Roster is missing {position} depth: needed {needed}, found {len(eligible)}")
        for depth_index, candidate in enumerate(eligible[:needed]):
            used.add(candidate["id"])
            selected.append((candidate, position, depth_index))
    unused = [candidate for candidate in team_candidates if candidate["id"] not in used]
    return selected, unused


def _scale_payroll(players: list[dict[str, Any]], target: int = 266_000_000) -> None:
    payroll = sum(player["contract"]["annual_salary"] for player in players if player["contract"])
    if payroll <= target:
        return
    scale = target / payroll
    for player in players:
        contract = player["contract"]
        if not contract:
            continue
        contract["annual_salary"] = max(795_000, round(contract["annual_salary"] * scale / 50_000) * 50_000)
        contract["guaranteed_money"] = round(contract["guaranteed_money"] * scale / 50_000) * 50_000


def _team_tactics(selected: list[tuple[dict[str, Any], str, int]]) -> dict[str, Any]:
    stats = defaultdict(float)
    for candidate, _, _ in selected:
        for key, value in candidate["stats"].items():
            stats[key] += value
    attempts = stats["attempts"]
    carries = stats["carries"]
    run_tendency = _clamp(carries / max(carries + attempts, 1.0), 0.32, 0.62)
    air_depth = stats["passing_air_yards"] / max(attempts, 1.0)
    pressure = stats["def_sacks"] + stats["def_qb_hits"] * 0.35
    return {
        "run_tendency": round(run_tendency, 3),
        "aggression": round(_clamp(0.43 + stats["passing_20"] / max(attempts, 1.0) * 0.8, 0.38, 0.68), 3),
        "tempo": round(_clamp(0.46 + math.log1p(attempts + carries) / 100.0, 0.44, 0.62), 3),
        "passing_depth": round(_clamp(0.38 + air_depth / 30.0, 0.36, 0.68), 3),
        "blitz_rate": round(_clamp(0.36 + pressure / max(stats["games"], 16.0) / 90.0, 0.34, 0.62), 3),
        "coverage_preference": "Man" if pressure > 75 else "Balanced",
    }


def _team_ratings(players: list[dict[str, Any]]) -> tuple[int, int, int]:
    by_position: dict[str, list[int]] = defaultdict(list)
    for player in players:
        by_position[player["position"]].append(player["overall"])
    for values in by_position.values():
        values.sort(reverse=True)
    offense_positions = ("QB", "RB", "WR", "TE", "LT", "LG", "C", "RG", "RT")
    defense_positions = ("EDGE", "DT", "LB", "CB", "S")
    offense = round(sum(by_position[position][0] for position in offense_positions) / len(offense_positions))
    defense = round(sum(by_position[position][0] for position in defense_positions) / len(defense_positions))
    special = round((by_position["K"][0] + by_position["P"][0]) / 2)
    return offense, defense, special


def _schedule(paths: dict[str, Path], season: int, requested_teams: list[str]) -> list[dict[str, Any]]:
    allowed = set(requested_teams)
    schedule: list[dict[str, Any]] = []
    for row in _read_csv(paths["games"]):
        if _integer(row.get("season")) != season or row.get("game_type") != "REG":
            continue
        away = _normalize_team(row.get("away_team", ""))
        home = _normalize_team(row.get("home_team", ""))
        if away not in allowed or home not in allowed:
            continue
        schedule.append({
            "id": row.get("game_id") or f"{season}_{row.get('week')}_{away}_{home}",
            "week": _integer(row.get("week")),
            "away_team_id": f"nfl_{away.lower()}",
            "home_team_id": f"nfl_{home.lower()}",
            "phase": "Regular Season",
            "played": False,
            "away_score": 0,
            "home_score": 0,
            "away_stats": {},
            "home_stats": {},
        })
    schedule.sort(key=lambda game: (game["week"], game["id"]))
    return schedule


def build_pack(paths: dict[str, Path], season: int, stat_years: list[int], team_abbreviations: list[str], snapshot_date: str) -> dict[str, Any]:
    players_by_id = {row["gsis_id"]: row for row in _read_csv(paths["players"]) if row.get("gsis_id")}
    team_rows = {_normalize_team(row["team_abbr"]): row for row in _read_csv(paths["teams"]) if row.get("team_abbr")}
    contracts: dict[str, dict[str, str]] = {}
    for row in _read_csv(paths["contracts"]):
        otc_id = row.get("otc_id", "").strip()
        if not otc_id or row.get("is_active", "").upper() != "TRUE":
            continue
        if otc_id not in contracts or _integer(row.get("year_signed")) > _integer(contracts[otc_id].get("year_signed")):
            contracts[otc_id] = row
    stats = _aggregate_stats(paths, stat_years)
    requested_teams = [_normalize_team(team) for team in team_abbreviations]
    candidates: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    for row in _read_csv(paths["roster"]):
        team = _normalize_team(row.get("team", ""))
        player_id = row.get("gsis_id", "").strip()
        eligible = eligible_positions(row)
        if not team or not player_id or not eligible or player_id in seen_ids:
            continue
        seen_ids.add(player_id)
        info = players_by_id.get(player_id, {})
        candidate = {
            "id": player_id,
            "team": team,
            "roster": row,
            "player_info": info,
            "eligible": eligible,
            "rating_group": _rating_group(row),
            "stats": stats.get(player_id, {}),
            "age": _age(row.get("birth_date") or info.get("birth_date", ""), season),
        }
        candidates.append(candidate)
    _assign_overalls(candidates)
    candidates_by_team: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for candidate in candidates:
        candidates_by_team[candidate["team"]].append(candidate)

    output_teams: list[dict[str, Any]] = []
    selected_player_ids: set[str] = set()
    for abbreviation in requested_teams:
        team_info = team_rows.get(abbreviation)
        if not team_info:
            raise ValueError(f"No nflverse team metadata found for {abbreviation}")
        selected, _unused = _select_team_roster(candidates_by_team[abbreviation])
        selected_player_ids.update(candidate["id"] for candidate, _position, _depth_index in selected)
        team_id = f"nfl_{abbreviation.lower()}"
        roster = [_player(candidate, position, team_id, contracts, season, depth_index) for candidate, position, depth_index in selected]
        _scale_payroll(roster)
        offense, defense, special = _team_ratings(roster)
        city, nickname = CURRENT_TEAM_NAMES[abbreviation]
        output_teams.append({
            "id": team_id,
            "city": city,
            "nickname": nickname,
            "abbreviation": abbreviation,
            "conference": team_info.get("team_conf", ""),
            "division": team_info.get("team_division", ""),
            "primary_color": team_info.get("team_color", "#FFFFFF").lstrip("#"),
            "secondary_color": team_info.get("team_color2", "#000000").lstrip("#"),
            "offense_rating": offense,
            "defense_rating": defense,
            "special_teams_rating": special,
            "strategy": _team_tactics(selected),
            "players": roster,
            "salary_cap": 280_000_000,
            "roster_limit": 53,
            "dead_cap": 0,
        })

    # The market draws from players outside the balanced 53-player active
    # rosters. It stays entirely offline and keeps club and free-agent IDs
    # mutually exclusive.
    reserve_candidates = [candidate for candidate in candidates if candidate["id"] not in selected_player_ids]
    free_agents: list[dict[str, Any]] = []
    free_agent_ids: set[str] = set()
    for position in ROSTER_COUNTS:
        for market_index in range(FREE_AGENT_TARGET_PER_POSITION):
            target_rating = max(62, 79 - market_index * 2)
            eligible = [candidate for candidate in reserve_candidates if candidate["id"] not in free_agent_ids and position in candidate["eligible"]]
            market_level = [candidate for candidate in eligible if candidate["overall"] <= target_rating]
            pool = market_level if market_level else eligible
            pool.sort(key=lambda item: (item["overall"], item["score"], item["id"]), reverse=True)
            if not pool:
                break
            candidate = pool[0]
            free_agent_ids.add(candidate["id"])
            actual_team_id = f"nfl_{candidate['team'].lower()}"
            free_agents.append(_player(candidate, position, actual_team_id, contracts, season, 3, free_agent=True))
    free_agents.sort(key=lambda player: (-player["overall"], player["id"]))

    schedule = _schedule(paths, season, requested_teams)

    source_files = []
    for name, path in sorted(paths.items()):
        source_files.append({"name": name, "file": path.name, "sha256": _sha256(path)})
    pack = {
        "schema_version": SCHEMA_VERSION,
        "source": {
            "id": f"nflverse_{season}_full",
            "label": f"NFLVERSE {season}",
            "league_name": "PRO FOOTBALL LEAGUE",
            "description": "Complete 32-club league with full active rosters and the published 2026 regular-season schedule.",
            "season": season,
            "snapshot_date": snapshot_date,
            "performance_seasons": stat_years,
            "license": "CC-BY-4.0",
            "attribution": "Player, roster, team, statistics, and contract source data provided by nflverse. Contract summaries originate from OverTheCap via nflverse.",
            "source_url": "https://github.com/nflverse/nflverse-data",
            "schedule_source_url": "https://github.com/nflverse/nfldata/blob/master/data/games.csv",
            "rating_model_version": RATING_MODEL_VERSION,
            "limitations": "Not an official NFL product. Logos, wordmarks, headshots, and portrait URLs are excluded. Roster slots are selected from the August 26 nflverse preseason snapshot.",
            "files": source_files,
        },
        "league_format": {
            "id": "nfl_32",
            "team_count": 32,
            "roster_size": 53,
            "offseason_roster_limit": 90,
            "regular_season_weeks": 18,
            "games_per_team": 17,
            "playoff_teams_per_conference": 7,
            "postseason_weeks": 4,
            "schedule_type": "nflverse_template",
            "template_season": season,
        },
        "teams": output_teams,
        "free_agents": free_agents,
        "schedule": schedule,
    }
    validate_pack(pack)
    return pack


def validate_pack(pack: dict[str, Any]) -> None:
    if pack.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("Unsupported data-pack schema")
    teams = pack.get("teams", [])
    if len(teams) != 32:
        raise ValueError(f"Full data pack must contain 32 teams, found {len(teams)}")
    all_ids: set[str] = set()
    for team in teams:
        players = team.get("players", [])
        if len(players) != sum(ROSTER_COUNTS.values()):
            raise ValueError(f"{team.get('abbreviation')} has {len(players)} players instead of 53")
        counts = defaultdict(int)
        for player in players:
            player_id = player.get("id", "")
            if not player_id or player_id in all_ids:
                raise ValueError(f"Missing or duplicate player ID: {player_id}")
            all_ids.add(player_id)
            counts[player["position"]] += 1
            if not 40 <= int(player["overall"]) <= 99:
                raise ValueError(f"Illegal overall for {player_id}")
            if "http" in json.dumps(player).lower():
                raise ValueError(f"External image or data URL leaked into player {player_id}")
        for position, expected in ROSTER_COUNTS.items():
            if counts[position] != expected:
                raise ValueError(f"{team.get('abbreviation')} has {counts[position]} {position}, expected {expected}")
        payroll = sum(player["contract"]["annual_salary"] for player in players if player.get("contract"))
        if payroll > int(team.get("salary_cap", 0)):
            raise ValueError(f"{team.get('abbreviation')} exceeds its salary cap")
    free_agents = pack.get("free_agents", [])
    if len(free_agents) < 100:
        raise ValueError(f"Expanded market must contain at least 100 players, found {len(free_agents)}")
    for player in free_agents:
        if player["id"] in all_ids:
            raise ValueError(f"Free agent duplicates a roster player: {player['id']}")
        all_ids.add(player["id"])
        if player.get("contract") is not None:
            raise ValueError(f"Free agent has a contract: {player['id']}")

    format_data = pack.get("league_format", {})
    if format_data.get("team_count") != 32 or format_data.get("roster_size") != 53:
        raise ValueError("League format does not describe the 32-team, 53-player competition")
    schedule = pack.get("schedule", [])
    if len(schedule) != 272:
        raise ValueError(f"The 2026 regular season must contain 272 games, found {len(schedule)}")
    games_by_team = defaultdict(int)
    weeks_by_team: dict[str, set[int]] = defaultdict(set)
    valid_team_ids = {team["id"] for team in teams}
    for game in schedule:
        away = game.get("away_team_id", "")
        home = game.get("home_team_id", "")
        week = int(game.get("week", 0))
        if away not in valid_team_ids or home not in valid_team_ids or not 1 <= week <= 18:
            raise ValueError(f"Schedule game references invalid league data: {game.get('id')}")
        for team_id in (away, home):
            if week in weeks_by_team[team_id]:
                raise ValueError(f"{team_id} plays more than once in week {week}")
            weeks_by_team[team_id].add(week)
            games_by_team[team_id] += 1
    if any(games_by_team[team_id] != 17 for team_id in valid_team_ids):
        raise ValueError("Every team must play exactly 17 regular-season games")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--season", type=int, default=2026)
    parser.add_argument("--stat-seasons", type=int, nargs="+", default=[2023, 2024, 2025])
    parser.add_argument("--teams", nargs="+", default=list(DEFAULT_TEAMS))
    parser.add_argument("--snapshot-date", default="2026-08-26")
    parser.add_argument("--cache-dir", type=Path, default=Path("tools/.cache/nflverse"))
    parser.add_argument("--output", type=Path, default=Path("data/leagues/nflverse_2026_full.json"))
    parser.add_argument("--offline", action="store_true", help="Fail instead of downloading a missing source file")
    parser.add_argument("--validate-only", type=Path, help="Validate an existing generated data pack")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.validate_only:
        validate_pack(json.loads(args.validate_only.read_text(encoding="utf-8")))
        print(f"Validated {args.validate_only}")
        return 0
    paths = _source_paths(args.cache_dir, args.season, args.stat_seasons, args.offline)
    pack = build_pack(paths, args.season, args.stat_seasons, args.teams, args.snapshot_date)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="\n") as output:
        output.write(json.dumps(pack, indent=2, sort_keys=True) + "\n")
    print(f"Wrote {len(pack['teams'])} teams and {len(pack['free_agents'])} free agents to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
