#!/usr/bin/env python3
"""Enrich the offline nflverse league pack with Madden player ratings metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import defaultdict
from copy import deepcopy
from pathlib import Path
from typing import Any


POSITION_MAP = {
    "HB": "RB",
    "FB": "RB",
    "LEDG": "EDGE",
    "REDG": "EDGE",
    "MIKE": "LB",
    "SAM": "LB",
    "WILL": "LB",
    "FS": "S",
    "SS": "S",
}
POSITION_GROUPS = {
    "QB": "QB",
    "RB": "BACK",
    "WR": "RECEIVER",
    "TE": "RECEIVER",
    "LT": "OL",
    "LG": "OL",
    "C": "OL",
    "RG": "OL",
    "RT": "OL",
    "EDGE": "FRONT",
    "DT": "FRONT",
    "LB": "FRONT",
    "CB": "SECONDARY",
    "S": "SECONDARY",
    "K": "SPECIAL",
    "P": "SPECIAL",
    "LS": "SPECIAL",
}
ROSTER_TARGETS = {
    "QB": 3, "RB": 4, "WR": 6, "TE": 3,
    "LT": 2, "LG": 2, "C": 2, "RG": 2, "RT": 2,
    "EDGE": 4, "DT": 4, "LB": 6, "CB": 6, "S": 4,
    "K": 1, "P": 1, "LS": 1,
}
POSITION_ORDER = tuple(ROSTER_TARGETS)
PERSONALITIES = ("Driven", "Professional", "Team Leader", "Reserved", "Independent", "Competitive")
POSITION_VALUE = {
    "QB": 1.75, "EDGE": 1.30, "LT": 1.22, "RT": 1.16, "CB": 1.18,
    "WR": 1.14, "DT": 1.06, "S": 1.02, "LB": 0.98, "TE": 0.94,
    "LG": 0.90, "RG": 0.90, "C": 0.90, "RB": 0.84, "K": 0.64,
    "P": 0.58, "LS": 0.48,
}
TEAM_ALIASES = {
    "nygiants": "newyorkgiants",
    "nyjets": "newyorkjets",
}


def normalize_name(value: str) -> str:
    without_suffix = re.sub(r"\b(jr|sr|ii|iii|iv)\b", "", value.lower())
    return re.sub(r"[^a-z0-9]", "", without_suffix)


def normalize_team(value: str) -> str:
    normalized = re.sub(r"[^a-z0-9]", "", value.lower())
    return TEAM_ALIASES.get(normalized, normalized)


def normalize_position(value: str) -> str:
    position = value.upper().strip()
    return POSITION_MAP.get(position, position)


def position_group(value: str) -> str:
    return POSITION_GROUPS.get(normalize_position(value), normalize_position(value))


def _number(stat: Any, default: int = 50) -> int:
    value = stat.get("value", default) if isinstance(stat, dict) else stat
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return default


def _rating(record: dict[str, Any], name: str, default: int = 50) -> int:
    return _number(record.get("stats", {}).get(name), default)


def _mean(values: list[int], default: int = 50) -> int:
    return int(round(sum(values) / len(values))) if values else default


def _summary_attributes(record: dict[str, Any], position: str) -> dict[str, int]:
    stats = record.get("stats", {})
    speed = _rating(record, "speed")
    awareness = _rating(record, "awareness")
    durability = _mean([
        _rating(record, "injury"),
        _rating(record, "stamina"),
        _rating(record, "toughness"),
    ])
    if position == "QB":
        power = _mean([_rating(record, "throwPower"), _rating(record, "strength")])
        technique = _mean([
            _rating(record, "throwAccuracyShort"),
            _rating(record, "throwAccuracyMid"),
            _rating(record, "throwAccuracyDeep"),
            _rating(record, "throwUnderPressure"),
            _rating(record, "playAction"),
        ])
    elif position == "RB":
        power = _mean([_rating(record, "strength"), _rating(record, "trucking"), _rating(record, "breakTackle")])
        technique = _mean([_rating(record, "bCVision"), _rating(record, "carrying"), _rating(record, "jukeMove"), _rating(record, "changeOfDirection")])
    elif position in ("WR", "TE"):
        power = _mean([_rating(record, "strength"), _rating(record, "breakTackle"), _rating(record, "stiffArm")])
        technique = _mean([
            _rating(record, "catching"),
            _rating(record, "catchInTraffic"),
            _rating(record, "shortRouteRunning"),
            _rating(record, "mediumRouteRunning"),
            _rating(record, "deepRouteRunning"),
            _rating(record, "release"),
        ])
    elif position in ("LT", "LG", "C", "RG", "RT", "LS"):
        power = _mean([_rating(record, "strength"), _rating(record, "impactBlocking"), _rating(record, "leadBlock")])
        technique = _mean([
            _rating(record, "passBlock"),
            _rating(record, "passBlockFinesse"),
            _rating(record, "passBlockPower"),
            _rating(record, "runBlock"),
            _rating(record, "runBlockFinesse"),
            _rating(record, "runBlockPower"),
        ])
    elif position in ("EDGE", "DT"):
        power = _mean([_rating(record, "strength"), _rating(record, "hitPower"), _rating(record, "blockShedding")])
        technique = _mean([_rating(record, "finesseMoves"), _rating(record, "powerMoves"), _rating(record, "playRecognition"), _rating(record, "tackle")])
    elif position == "LB":
        power = _mean([_rating(record, "strength"), _rating(record, "hitPower"), _rating(record, "blockShedding")])
        technique = _mean([_rating(record, "tackle"), _rating(record, "pursuit"), _rating(record, "playRecognition"), _rating(record, "zoneCoverage")])
    elif position in ("CB", "S"):
        power = _mean([_rating(record, "hitPower"), _rating(record, "tackle"), _rating(record, "strength")])
        technique = _mean([_rating(record, "manCoverage"), _rating(record, "zoneCoverage"), _rating(record, "press"), _rating(record, "playRecognition")])
    elif position in ("K", "P"):
        power = _rating(record, "kickPower")
        technique = _rating(record, "kickAccuracy")
    else:
        power = _rating(record, "strength")
        technique = _rating(record, "overall", _number(record.get("overallRating"), 50))
    return {
        "speed": speed,
        "power": power,
        "technique": technique,
        "awareness": awareness,
        "durability": durability,
    }


def _compact_ratings(record: dict[str, Any]) -> dict[str, Any]:
    attributes: dict[str, int] = {}
    running_style = ""
    for name, stat in sorted(record.get("stats", {}).items()):
        value = stat.get("value") if isinstance(stat, dict) else stat
        if name == "runningStyle":
            running_style = str(value or "")
            continue
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            attributes[name] = int(round(value))
    abilities = []
    for ability in record.get("playerAbilities", []):
        ability_type = ability.get("type") or {}
        abilities.append({
            "id": str(ability.get("id", "")),
            "label": str(ability.get("label", "")),
            "description": str(ability.get("description", "")),
            "type": str(ability_type.get("label", "Ability")),
        })
    return {
        "source": "Madden NFL 26",
        "source_player_id": str(record.get("id", "")),
        "source_overall": int(record.get("overallRating", _rating(record, "overall"))),
        "iteration": str((record.get("iteration") or {}).get("label", "")),
        "archetype": str((record.get("archetype") or {}).get("label", "")),
        "portrait_url": str(record.get("avatarUrl") or ""),
        "source_team_name": str((record.get("team") or {}).get("label", "")),
        "source_team_logo_url": str((record.get("team") or {}).get("imageUrl") or ""),
        "running_style": running_style,
        "attributes": attributes,
        "abilities": abilities,
    }


def _candidate_score(
    player: dict[str, Any],
    team_name: str,
    candidate: dict[str, Any],
) -> tuple[int, int, str]:
    game_position = normalize_position(str(player.get("position", "")))
    candidate_position = normalize_position(str((candidate.get("position") or {}).get("id", "")))
    score = 0
    if candidate_position == game_position:
        score += 80
    elif position_group(candidate_position) == position_group(game_position):
        score += 36
    if team_name and normalize_team(str((candidate.get("team") or {}).get("label", ""))) == normalize_team(team_name):
        score += 54
    age_delta = abs(int(candidate.get("age", 0)) - int(player.get("age", 0)))
    score += 26 if age_delta == 0 else 15 if age_delta == 1 else 0
    experience_delta = abs(int(candidate.get("yearsPro", 0)) - int(player.get("experience_years", 0)))
    score += 12 if experience_delta == 0 else 7 if experience_delta == 1 else 0
    # Stable tie breakers prefer the closest age, then the source player ID.
    return score, -age_delta, str(candidate.get("id", ""))


def _team_name_map(pack: dict[str, Any]) -> dict[str, str]:
    return {
        str(team.get("id", "")): f"{team.get('city', '')} {team.get('nickname', '')}".strip()
        for team in pack.get("teams", [])
    }


def _current_team_name(player: dict[str, Any], team_name: str, team_names: dict[str, str]) -> str:
    if team_name:
        return team_name
    history = player.get("team_history", [])
    if history:
        return team_names.get(str(history[-1]), "")
    return team_names.get(str(player.get("original_team_id", "")), "")


def _enrich_player(player: dict[str, Any], candidate: dict[str, Any]) -> None:
    details = _compact_ratings(candidate)
    overall = int(candidate.get("overallRating", details["source_overall"]))
    summary = _summary_attributes(candidate, normalize_position(str(player.get("position", ""))))
    player["overall"] = overall
    player.update(summary)
    player["potential"] = min(99, max(overall, int(player.get("potential", overall))))
    player["career_peak_overall"] = max(overall, int(player.get("career_peak_overall", overall)))
    player["archetype"] = details["archetype"] or str(player.get("archetype", "Balanced"))
    player["jersey_number"] = int(candidate.get("jerseyNum", 0) or 0)
    player["madden_ratings"] = details


def _stable_int(*parts: Any) -> int:
    digest = hashlib.sha256(":".join(str(part) for part in parts).encode("utf-8")).digest()
    return int.from_bytes(digest[:8], "big", signed=False)


def _generated_contract(record: dict[str, Any], position: str, season: int = 2026) -> dict[str, Any]:
    overall = int(record.get("overallRating", 60))
    age = int(record.get("age", 25))
    premium = max(overall - 58, 0)
    annual = int(round((800_000 + premium * premium * 27_500) * POSITION_VALUE.get(position, 0.80) / 50_000) * 50_000)
    annual = max(800_000, min(annual, 48_000_000))
    years = 4 if age <= 25 else 3 if age <= 29 else 2 if age <= 33 else 1
    role = "Franchise" if overall >= 88 else "Starter" if overall >= 78 else "Rotation" if overall >= 69 else "Depth"
    guarantee_rate = 0.58 if role == "Franchise" else 0.44 if role == "Starter" else 0.24
    return {
        "annual_salary": annual,
        "guaranteed_money": int(round(annual * years * guarantee_rate / 50_000) * 50_000),
        "years_remaining": years,
        "signed_year": season,
        "expires_after_year": season + years - 1,
        "role": role,
    }


def _select_team_roster(records: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    ordered = sorted(records, key=lambda item: (int(item.get("overallRating", 0)), str(item.get("id", ""))), reverse=True)
    selected: list[dict[str, Any]] = []
    selected_ids: set[str] = set()
    for position in POSITION_ORDER:
        eligible = [
            record for record in ordered
            if str(record.get("id", "")) not in selected_ids
            and normalize_position(str((record.get("position") or {}).get("id", ""))) == position
        ]
        if not eligible:
            raise ValueError(f"Madden roster is missing required {position} representation")
        for record in eligible[:ROSTER_TARGETS[position]]:
            selected.append(record)
            selected_ids.add(str(record.get("id", "")))
    for record in ordered:
        if len(selected) >= 53:
            break
        if str(record.get("id", "")) not in selected_ids:
            selected.append(record)
            selected_ids.add(str(record.get("id", "")))
    if len(selected) != 53:
        raise ValueError(f"Madden team pool produced {len(selected)} players instead of 53")
    unused = [record for record in ordered if str(record.get("id", "")) not in selected_ids]
    return selected, unused


def _existing_player_index(pack: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    index: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for team in pack.get("teams", []):
        team_name = f"{team.get('city', '')} {team.get('nickname', '')}".strip()
        for player in team.get("players", []):
            if not str(player.get("id", "")).startswith("00-"):
                continue
            copy = deepcopy(player)
            copy["_roster_team_name"] = team_name
            index[normalize_name(str(player.get("full_name", "")))].append(copy)
    for player in pack.get("free_agents", []):
        if not str(player.get("id", "")).startswith("00-"):
            continue
        copy = deepcopy(player)
        copy["_roster_team_name"] = ""
        index[normalize_name(str(player.get("full_name", "")))].append(copy)
    return index


def _existing_match_score(record: dict[str, Any], candidate: dict[str, Any]) -> tuple[int, int, str]:
    ratings_position = normalize_position(str((record.get("position") or {}).get("id", "")))
    game_position = normalize_position(str(candidate.get("position", "")))
    score = 0
    if ratings_position == game_position:
        score += 80
    elif position_group(ratings_position) == position_group(game_position):
        score += 36
    ratings_team = normalize_team(str((record.get("team") or {}).get("label", "")))
    if ratings_team and ratings_team == normalize_team(str(candidate.get("_roster_team_name", ""))):
        score += 54
    age_delta = abs(int(record.get("age", 0)) - int(candidate.get("age", 0)))
    score += 26 if age_delta == 0 else 15 if age_delta == 1 else 0
    return score, -age_delta, str(candidate.get("id", ""))


def _build_player_from_rating(
    record: dict[str, Any],
    team_id: str,
    existing: dict[str, Any] | None,
    free_agent: bool,
    season: int,
) -> dict[str, Any]:
    position = normalize_position(str((record.get("position") or {}).get("id", "")))
    source_id = str(record.get("id", ""))
    player = deepcopy(existing) if existing is not None else {}
    player.pop("_roster_team_name", None)
    player["id"] = str(player.get("id", "")) or f"madden_26_{source_id}"
    player["full_name"] = f"{record.get('firstName', '')} {record.get('lastName', '')}".strip()
    player["position"] = position
    player["age"] = int(player.get("age", record.get("age", 24)))
    player["height_inches"] = int(player.get("height_inches", record.get("height", 72)))
    player["weight_lbs"] = int(player.get("weight_lbs", record.get("weight", 220)))
    player["college"] = str(player.get("college") or record.get("college") or "Independent")
    experience = int(player.get("experience_years", record.get("yearsPro", max(player["age"] - 22, 0))))
    player["experience_years"] = experience
    player["entry_year"] = int(player.get("entry_year", season - experience))
    player["draft_round"] = int(player.get("draft_round", 0))
    player["draft_pick"] = int(player.get("draft_pick", 0))
    player["personality"] = str(player.get("personality") or PERSONALITIES[_stable_int(source_id, "personality") % len(PERSONALITIES)])
    player["generation_source"] = "NFLverse + Madden NFL 26" if existing is not None else "Madden NFL 26"
    player["energy"] = int(player.get("energy", 100))
    player["is_active"] = bool(player.get("is_active", True))
    player["injury_type"] = str(player.get("injury_type", ""))
    player["injury_weeks"] = int(player.get("injury_weeks", 0))
    player["seasons_as_free_agent"] = int(player.get("seasons_as_free_agent", 0)) if free_agent else 0
    player["original_team_id"] = str(player.get("original_team_id", team_id))
    history = [str(item) for item in player.get("team_history", []) if str(item)]
    if team_id and (not history or history[-1] != team_id):
        history.append(team_id)
    player["team_history"] = history
    player["contract"] = None if free_agent else (player.get("contract") or _generated_contract(record, position, season))
    _enrich_player(player, record)
    return player


def _scale_payroll(players: list[dict[str, Any]], target: int = 266_000_000) -> None:
    payroll = sum(int(player["contract"]["annual_salary"]) for player in players if player.get("contract"))
    if payroll <= target:
        return
    scale = target / payroll
    for player in players:
        contract = player.get("contract")
        if not contract:
            continue
        contract["annual_salary"] = max(800_000, round(int(contract["annual_salary"]) * scale / 50_000) * 50_000)
        contract["guaranteed_money"] = round(int(contract.get("guaranteed_money", 0)) * scale / 50_000) * 50_000


def _rebuild_from_madden_rosters(pack: dict[str, Any], ratings: list[dict[str, Any]]) -> tuple[int, list[dict[str, Any]], list[dict[str, Any]]]:
    existing_index = _existing_player_index(pack)
    used_existing_ids: set[str] = set()
    nflverse_matches = 0
    unmatched_ratings: list[dict[str, Any]] = []
    ambiguous: list[dict[str, Any]] = []
    season = int(pack.get("source", {}).get("season", 2026))
    ratings_by_team: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in ratings:
        ratings_by_team[normalize_team(str((record.get("team") or {}).get("label", "")))].append(record)

    free_agent_records: list[dict[str, Any]] = []
    for team in pack.get("teams", []):
        team_name = f"{team.get('city', '')} {team.get('nickname', '')}".strip()
        records = ratings_by_team.get(normalize_team(team_name), [])
        selected, unused = _select_team_roster(records)
        free_agent_records.extend(unused)
        built_players = []
        for record in selected:
            key = normalize_name(f"{record.get('firstName', '')} {record.get('lastName', '')}")
            candidates = [item for item in existing_index.get(key, []) if str(item.get("id", "")) not in used_existing_ids]
            ranked = sorted(candidates, key=lambda item: _existing_match_score(record, item), reverse=True)
            existing = ranked[0] if ranked else None
            if existing is not None:
                used_existing_ids.add(str(existing.get("id", "")))
                nflverse_matches += 1
                if len(candidates) > 1:
                    ambiguous.append({
                        "ratings_player_id": str(record.get("id", "")),
                        "full_name": f"{record.get('firstName', '')} {record.get('lastName', '')}".strip(),
                        "selected_player_id": str(existing.get("id", "")),
                        "candidate_player_ids": [str(item.get("id", "")) for item in ranked],
                    })
            else:
                unmatched_ratings.append({
                    "ratings_player_id": str(record.get("id", "")),
                    "full_name": f"{record.get('firstName', '')} {record.get('lastName', '')}".strip(),
                    "position": normalize_position(str((record.get("position") or {}).get("id", ""))),
                    "team": team_name,
                })
            built_players.append(_build_player_from_rating(record, str(team.get("id", "")), existing, False, season))
        _scale_payroll(built_players)
        team["players"] = built_players
        team.pop("depth_chart", None)

    free_agents = []
    for record in sorted(free_agent_records, key=lambda item: (int(item.get("overallRating", 0)), str(item.get("id", ""))), reverse=True):
        key = normalize_name(f"{record.get('firstName', '')} {record.get('lastName', '')}")
        candidates = [item for item in existing_index.get(key, []) if str(item.get("id", "")) not in used_existing_ids]
        ranked = sorted(candidates, key=lambda item: _existing_match_score(record, item), reverse=True)
        existing = ranked[0] if ranked else None
        if existing is not None:
            used_existing_ids.add(str(existing.get("id", "")))
            nflverse_matches += 1
        else:
            unmatched_ratings.append({
                "ratings_player_id": str(record.get("id", "")),
                "full_name": f"{record.get('firstName', '')} {record.get('lastName', '')}".strip(),
                "position": normalize_position(str((record.get("position") or {}).get("id", ""))),
                "team": str((record.get("team") or {}).get("label", "")),
            })
        free_agents.append(_build_player_from_rating(record, "", existing, True, season))
    pack["free_agents"] = free_agents
    return nflverse_matches, unmatched_ratings, ambiguous


def build_hybrid_pack(
    pack: dict[str, Any],
    ratings: list[dict[str, Any]],
    rebuild_rosters: bool = True,
) -> tuple[dict[str, Any], dict[str, Any]]:
    hybrid = deepcopy(pack)
    if rebuild_rosters:
        matched, unmatched, resolutions = _rebuild_from_madden_rosters(hybrid, ratings)
        total_players = len(ratings)
        for team in hybrid.get("teams", []):
            team_name = f"{team.get('city', '')} {team.get('nickname', '')}".strip()
            matching_records = [record for record in ratings if normalize_team(str((record.get("team") or {}).get("label", ""))) == normalize_team(team_name)]
            team["logo_url"] = str((matching_records[0].get("team") or {}).get("imageUrl", "")) if matching_records else ""
        source = hybrid.setdefault("source", {})
        source["label"] = "NFLVERSE + MADDEN RATINGS"
        source["description"] = "NFLverse league, contract, schedule, and statistics data joined to the complete Madden NFL 26 ratings player pool."
        source["ratings_source"] = "Madden NFL 26"
        source["ratings_iteration"] = str((ratings[0].get("iteration") or {}).get("label", "")) if ratings else ""
        source["ratings_player_count"] = len(ratings)
        source["hybrid_player_count"] = total_players
        source["hybrid_match_count"] = matched
        source["hybrid_match_rate"] = round(matched / max(total_players, 1), 6)
        source["limitations"] = "Not an official NFL product. The Madden snapshot may represent a different roster date than the nflverse league snapshot; unmatched rated players use generated contract terms. Remote headshots and team marks require an internet connection."
        source["attribution"] = "Player, roster, team, statistics, and contract source data provided by nflverse. Contract summaries originate from OverTheCap via nflverse. Player identities and attributes are joined to the Madden NFL 26 ratings snapshot."
        return hybrid, {
            "game_player_count": total_players,
            "ratings_player_count": len(ratings),
            "matched_player_count": matched,
            "unmatched_player_count": len(unmatched),
            "ambiguous_resolution_count": len(resolutions),
            "unmatched": unmatched,
            "ambiguous_resolutions": resolutions,
        }

    ratings_by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in ratings:
        ratings_by_name[normalize_name(f"{record.get('firstName', '')} {record.get('lastName', '')}")].append(record)

    team_names = _team_name_map(hybrid)
    used_ratings_ids: set[str] = set()
    unmatched: list[dict[str, Any]] = []
    resolutions: list[dict[str, Any]] = []
    matched = 0

    player_entries: list[tuple[dict[str, Any], str]] = []
    for team in hybrid.get("teams", []):
        team_name = team_names.get(str(team.get("id", "")), "")
        player_entries.extend((player, team_name) for player in team.get("players", []))
    player_entries.extend((player, "") for player in hybrid.get("free_agents", []))

    for player, roster_team_name in player_entries:
        key = normalize_name(str(player.get("full_name", "")))
        candidates = [record for record in ratings_by_name.get(key, []) if str(record.get("id", "")) not in used_ratings_ids]
        team_name = _current_team_name(player, roster_team_name, team_names)
        if not candidates:
            unmatched.append({
                "player_id": str(player.get("id", "")),
                "full_name": str(player.get("full_name", "")),
                "position": str(player.get("position", "")),
                "team": team_name,
            })
            continue
        ranked = sorted(candidates, key=lambda item: _candidate_score(player, team_name, item), reverse=True)
        selected = ranked[0]
        used_ratings_ids.add(str(selected.get("id", "")))
        _enrich_player(player, selected)
        matched += 1
        if len(candidates) > 1:
            resolutions.append({
                "player_id": str(player.get("id", "")),
                "full_name": str(player.get("full_name", "")),
                "selected_ratings_id": str(selected.get("id", "")),
                "candidate_ratings_ids": [str(item.get("id", "")) for item in ranked],
            })

    logos_by_team = {}
    for record in ratings:
        source_team = record.get("team") or {}
        name = normalize_team(str(source_team.get("label", "")))
        logo_url = str(source_team.get("imageUrl", ""))
        if name and logo_url:
            logos_by_team[name] = logo_url
    for team in hybrid.get("teams", []):
        team_name = team_names.get(str(team.get("id", "")), "")
        team["logo_url"] = logos_by_team.get(normalize_team(team_name), "")

    total_players = len(player_entries)
    source = hybrid.setdefault("source", {})
    source["label"] = "NFLVERSE + MADDEN RATINGS"
    source["description"] = "NFLverse league, contract, schedule, and statistics data joined to the complete Madden NFL 26 ratings player pool."
    source["ratings_source"] = "Madden NFL 26"
    source["ratings_iteration"] = str((ratings[0].get("iteration") or {}).get("label", "")) if ratings else ""
    source["ratings_player_count"] = len(ratings)
    source["hybrid_player_count"] = total_players
    source["hybrid_match_count"] = matched
    source["hybrid_match_rate"] = round(matched / max(total_players, 1), 6)
    source["limitations"] = "Not an official NFL product. The Madden snapshot may represent a different roster date than the nflverse league snapshot; unmatched rated players use generated contract terms. Remote headshots and team marks require an internet connection."
    source["attribution"] = "Player, roster, team, statistics, and contract source data provided by nflverse. Contract summaries originate from OverTheCap via nflverse. Player identities and attributes are joined to the Madden NFL 26 ratings snapshot."

    report = {
        "game_player_count": total_players,
        "ratings_player_count": len(ratings),
        "matched_player_count": matched,
        "unmatched_player_count": len(unmatched),
        "ambiguous_resolution_count": len(resolutions),
        "unmatched": unmatched,
        "ambiguous_resolutions": resolutions,
    }
    return hybrid, report


def validate_hybrid_pack(pack: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    players = [player for team in pack.get("teams", []) for player in team.get("players", [])]
    players.extend(pack.get("free_agents", []))
    for player in players:
        ratings = player.get("madden_ratings")
        if not isinstance(ratings, dict):
            errors.append(f"{player.get('id')}: missing madden_ratings")
            continue
        attributes = ratings.get("attributes")
        if not isinstance(attributes, dict) or len(attributes) < 50:
            errors.append(f"{player.get('id')}: incomplete Madden attributes")
        if int(ratings.get("source_overall", 0)) != int(player.get("overall", -1)):
            errors.append(f"{player.get('id')}: overall does not match ratings source")
        if not str(ratings.get("source_player_id", "")):
            errors.append(f"{player.get('id')}: missing ratings source ID")
    for team in pack.get("teams", []):
        if not str(team.get("logo_url", "")):
            errors.append(f"{team.get('id')}: missing team logo URL")
    return errors


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--league-pack", type=Path, default=Path("data/leagues/nflverse_2026_full.json"))
    parser.add_argument("--ratings", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("data/leagues/nflverse_2026_full.json"))
    parser.add_argument("--report", type=Path, default=Path("data/leagues/hybrid_ratings_report.json"))
    parser.add_argument("--validate-only", type=Path)
    args = parser.parse_args()

    if args.validate_only:
        with args.validate_only.open("r", encoding="utf-8") as handle:
            errors = validate_hybrid_pack(json.load(handle))
        if errors:
            for error in errors:
                print(f"ERROR: {error}", file=__import__("sys").stderr)
            return 1
        print(f"Validated hybrid player ratings in {args.validate_only}")
        return 0

    with args.league_pack.open("r", encoding="utf-8") as handle:
        pack = json.load(handle)
    with args.ratings.open("r", encoding="utf-8") as handle:
        ratings = json.load(handle)
    if not isinstance(ratings, list):
        raise ValueError("Ratings input must be a JSON array")

    hybrid, report = build_hybrid_pack(pack, ratings)
    hybrid["source"]["ratings_file_sha256"] = _sha256(args.ratings)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    errors = validate_hybrid_pack(hybrid)
    if errors:
        raise ValueError(
            f"Hybrid pack validation failed with {len(errors)} errors; "
            f"see {args.report}.\n" + "\n".join(errors[:25])
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(hybrid, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Built {report['game_player_count']}-player Madden-rated database; retained NFLverse "
        f"identity/contract data for {report['matched_player_count']} players and resolved "
        f"{report['ambiguous_resolution_count']} ambiguous names."
    )
    print(f"Wrote {args.output} and {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
