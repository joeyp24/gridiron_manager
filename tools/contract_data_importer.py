"""Refresh the packaged league with current OTC contract and cap schedules.

The nflverse historical contract export is retained as an identity bridge, but
its active-contract flag can lag extensions. This importer therefore joins the
game's stable GSIS IDs to OTC IDs and overlays current public contract totals
plus year-by-year team cap tables. The generated game data remains fully
offline at runtime.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
import unicodedata
import urllib.request
from collections import defaultdict
from datetime import date
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


OTC_CONTRACTS_URL = "https://overthecap.com/contracts"
OTC_PLAYER_URL = "https://overthecap.com/player/{slug}/{otc_id}"
NFLVERSE_PLAYERS_URL = "https://github.com/nflverse/nflverse-data/releases/download/players/players.csv"
NFL_SALARY_CAP_URL = "https://operations.nfl.com/calendar-events/nfl-free-agency/nfl-salary-cap"
SALARY_CAP_2026 = 301_200_000
# A live cap table and the packaged Madden roster are different snapshots. If
# their combination is already over the live adjusted cap, preserve enough
# current-year room for a legal 16-player practice squad and routine claims.
ROSTER_SNAPSHOT_OPERATING_RESERVE = 7_000_000
TEAM_SLUGS = {
    "ARI": "arizona-cardinals", "ATL": "atlanta-falcons",
    "BAL": "baltimore-ravens", "BUF": "buffalo-bills",
    "CAR": "carolina-panthers", "CHI": "chicago-bears",
    "CIN": "cincinnati-bengals", "CLE": "cleveland-browns",
    "DAL": "dallas-cowboys", "DEN": "denver-broncos",
    "DET": "detroit-lions", "GB": "green-bay-packers",
    "HOU": "houston-texans", "IND": "indianapolis-colts",
    "JAX": "jacksonville-jaguars", "KC": "kansas-city-chiefs",
    "LV": "las-vegas-raiders", "LAC": "los-angeles-chargers",
    "LAR": "los-angeles-rams", "MIA": "miami-dolphins",
    "MIN": "minnesota-vikings", "NE": "new-england-patriots",
    "NO": "new-orleans-saints", "NYG": "new-york-giants",
    "NYJ": "new-york-jets", "PHI": "philadelphia-eagles",
    "PIT": "pittsburgh-steelers", "SF": "san-francisco-49ers",
    "SEA": "seattle-seahawks", "TB": "tampa-bay-buccaneers",
    "TEN": "tennessee-titans", "WAS": "washington-commanders",
}


def _attrs(values: list[tuple[str, str | None]]) -> dict[str, str]:
    return {key: value or "" for key, value in values}


def _clean_text(parts: list[str]) -> str:
    return " ".join(" ".join(parts).split())


def _money(value: str) -> int:
    cleaned = value.replace("$", "").replace(",", "").strip()
    if not cleaned or cleaned in {"--", "Void"}:
        return 0
    negative = cleaned.startswith("(") and cleaned.endswith(")")
    cleaned = cleaned.strip("()")
    try:
        amount = int(round(float(cleaned)))
    except ValueError:
        return 0
    return -amount if negative else amount


def _normalize_name(value: str) -> str:
    folded = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    return re.sub(r"[^a-z0-9]", "", folded.lower())


def _player_link(href: str) -> tuple[str, str] | None:
    match = re.search(r"/player/([^/]+)/([0-9]+)/?", href)
    return (match.group(1), match.group(2)) if match else None


class ContractsTableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.records: dict[str, dict[str, Any]] = {}
        self._row: dict[str, Any] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = _attrs(attrs)
        if tag == "tr" and values.get("data-team"):
            self._row = {
                "team": values["data-team"],
                "position": values.get("data-position", ""),
                "cells": [],
                "otc_id": "",
                "slug": "",
            }
        elif self._row is not None and tag == "td":
            self._cell = []
        elif self._row is not None and tag == "a":
            parsed = _player_link(values.get("href", ""))
            if parsed:
                self._row["slug"], self._row["otc_id"] = parsed

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "td" and self._row is not None and self._cell is not None:
            self._row["cells"].append(_clean_text(self._cell))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            cells = self._row["cells"]
            otc_id = self._row["otc_id"]
            if otc_id and len(cells) >= 6:
                total_value = _money(cells[3])
                apy = _money(cells[4])
                self.records[otc_id] = {
                    "otc_id": otc_id,
                    "slug": self._row["slug"],
                    "player": cells[0],
                    "position": cells[1],
                    "team": self._row["team"],
                    "total_value": total_value,
                    "apy": apy,
                    "total_guaranteed": _money(cells[5]),
                    "term_years": max(1, round(total_value / apy)) if apy > 0 else 1,
                }
            self._row = None
            self._cell = None


class TeamCapParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.records: dict[str, dict[int, dict[str, int]]] = defaultdict(dict)
        self._div_year_stack: list[int | None] = []
        self._row: dict[str, Any] | None = None
        self._cell: dict[str, Any] | None = None
        self._detail: str = ""

    @property
    def _year(self) -> int | None:
        for value in reversed(self._div_year_stack):
            if value is not None:
                return value
        return None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = _attrs(attrs)
        if tag == "div":
            match = re.fullmatch(r"y(20[0-9]{2})", values.get("id", ""))
            self._div_year_stack.append(int(match.group(1)) if match else None)
            detail_class = values.get("class", "")
            if self._cell is not None and detail_class in {"cut", "trade"}:
                self._detail = detail_class
                self._cell[detail_class] = []
            return
        if tag == "tr" and self._year is not None:
            self._row = {"year": self._year, "cells": [], "otc_id": ""}
        elif self._row is not None and tag == "td":
            self._cell = {"text": [], "class": values.get("class", ""), "cut": [], "trade": []}
        elif self._row is not None and tag == "a":
            parsed = _player_link(values.get("href", ""))
            if parsed:
                self._row["otc_id"] = parsed[1]

    def handle_data(self, data: str) -> None:
        if self._cell is None:
            return
        self._cell["text"].append(data)
        if self._detail:
            self._cell[self._detail].append(data)

    def handle_endtag(self, tag: str) -> None:
        if tag == "div":
            if self._detail:
                self._detail = ""
            if self._div_year_stack:
                self._div_year_stack.pop()
            return
        if tag == "td" and self._row is not None and self._cell is not None:
            self._row["cells"].append({
                "text": _clean_text(self._cell["text"]),
                "class": self._cell["class"],
                "cut": _clean_text(self._cell["cut"]),
                "trade": _clean_text(self._cell["trade"]),
            })
            self._cell = None
        elif tag == "tr" and self._row is not None:
            self._finish_row()
            self._row = None
            self._cell = None

    def _finish_row(self) -> None:
        otc_id = str(self._row.get("otc_id", ""))
        cells = self._row.get("cells", [])
        if not otc_id or len(cells) < 3:
            return
        transaction_index = next(
            (index for index, cell in enumerate(cells) if "player-transactions" in cell["class"]),
            len(cells),
        )
        cap_hit = 0
        for cell in reversed(cells[1:transaction_index]):
            if "spacer" in cell["class"]:
                continue
            cap_hit = _money(cell["text"])
            if cap_hit:
                break
        base_text = cells[1]["text"]
        base_salary = _money(base_text)
        penalty_cell = cells[transaction_index] if transaction_index < len(cells) else {}
        record = {
            "base_salary": max(base_salary, 0),
            "cap_hit": max(cap_hit, 0),
            "release_penalty": max(_money(str(penalty_cell.get("cut", ""))), 0),
            "trade_penalty": max(_money(str(penalty_cell.get("trade", ""))), 0),
            "active_salary": base_salary > 0 and "Void" not in base_text,
        }
        year = int(self._row["year"])
        existing = self.records[otc_id].get(year)
        if existing is None or record["cap_hit"] > existing["cap_hit"]:
            self.records[otc_id][year] = record


def parse_contracts_html(text: str) -> dict[str, dict[str, Any]]:
    parser = ContractsTableParser()
    parser.feed(text)
    return parser.records


def parse_cap_html(text: str) -> dict[str, dict[int, dict[str, int]]]:
    parser = TeamCapParser()
    parser.feed(text)
    return parser.records


def parse_adjusted_caps_html(text: str) -> dict[int, int]:
    caps: dict[int, int] = {}
    pattern = re.compile(
        r'<div class="salary-cap-container" id="y(20[0-9]{2})">(.*?)'
        r'(?=<div class="salary-cap-container" id="y20[0-9]{2}">|$)',
        re.DOTALL,
    )
    for year_text, body in pattern.findall(text):
        liabilities = re.search(r'Total Cap Liabilities: \$([0-9,]+)', body)
        space = re.search(r'Team Cap Space: \$([0-9,]+)', body)
        if liabilities and space:
            caps[int(year_text)] = _money(liabilities.group(1)) + _money(space.group(1))
    return caps


def _download(url: str, path: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": "GridironManagerDataImporter/1.0"})
    path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(request, timeout=60) as response:
        path.write_bytes(response.read())


def download_sources(cache_dir: Path) -> None:
    _download(OTC_CONTRACTS_URL, cache_dir / "contracts.html")
    for abbreviation, slug in TEAM_SLUGS.items():
        _download(f"https://overthecap.com/salary-cap/{slug}", cache_dir / f"{abbreviation}.html")


def _load_player_otc_ids(path: Path) -> dict[str, str]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return {
            row["gsis_id"].strip(): row["otc_id"].strip()
            for row in csv.DictReader(handle)
            if row.get("gsis_id", "").strip() and row.get("otc_id", "").strip()
        }


def _fallback_contract(contract: dict[str, Any], season: int) -> dict[str, Any]:
    annual = int(contract.get("annual_salary", 0))
    years = max(int(contract.get("years_remaining", 1)), 1)
    expiration = int(contract.get("expires_after_year", season + years - 1))
    contract.update({
        "total_contract_value": int(contract.get("total_contract_value", annual * years)),
        "total_guaranteed": int(contract.get("total_guaranteed", contract.get("guaranteed_money", 0))),
        "yearly_cap_hits": {
            str(year): int(contract.get("yearly_cap_hits", {}).get(str(year), annual))
            for year in range(season, expiration + 1)
        },
        "yearly_cash": {
            str(year): int(contract.get("yearly_cash", {}).get(str(year), annual))
            for year in range(season, expiration + 1)
        },
        "yearly_release_penalties": dict(contract.get("yearly_release_penalties", {})),
        "yearly_trade_penalties": dict(contract.get("yearly_trade_penalties", {})),
        "contract_type": str(contract.get("contract_type", "Historical estimate")),
        "source_label": str(contract.get("source_label", "nflverse historical contract estimate")),
        "source_url": str(contract.get("source_url", "")),
        "source_snapshot": str(contract.get("source_snapshot", "")),
    })
    return contract


def _roster_snapshot_estimate(player: dict[str, Any], existing: dict[str, Any], season: int) -> dict[str, Any]:
    overall = int(player.get("overall", 60))
    age = int(player.get("age", 25))
    position = str(player.get("position", ""))
    multiplier = {
        "QB": 1.42, "EDGE": 1.16, "LT": 1.16, "CB": 1.16, "WR": 1.16,
        "DT": 1.08, "LB": 1.08, "S": 1.08, "RT": 1.08,
        "K": 0.72, "P": 0.72, "LS": 0.72,
    }.get(position, 1.0)
    annual = round((850_000 + max(overall - 60, 0) ** 2 * 12_000) * multiplier / 100_000) * 100_000
    years = 4 if age <= 24 else 3 if age <= 28 else 2 if age <= 31 else 1
    role = str(existing.get("role", "Depth"))
    guarantee_rate = 0.52 if role == "Franchise" else 0.38 if role == "Starter" else 0.22
    guaranteed = round(annual * years * guarantee_rate / 50_000) * 50_000
    estimated = {
        "annual_salary": annual,
        "years_remaining": years,
        "guaranteed_money": guaranteed,
        "signed_year": season,
        "role": role,
        "expires_after_year": season + years - 1,
        "total_contract_value": annual * years,
        "total_guaranteed": guaranteed,
        "yearly_cap_hits": {str(year): annual for year in range(season, season + years)},
        "yearly_cash": {str(year): annual for year in range(season, season + years)},
        "yearly_release_penalties": {},
        "yearly_trade_penalties": {},
        "contract_type": "Roster snapshot estimate",
        "source_label": "Gridiron estimate; roster and current OTC club did not match",
        "source_url": "",
        "source_snapshot": "",
    }
    return estimated


def _current_contract(
    existing: dict[str, Any],
    source: dict[str, Any],
    schedule: dict[int, dict[str, int]],
    season: int,
    snapshot: str,
) -> dict[str, Any]:
    active_years = sorted(
        year for year, row in schedule.items()
        if year >= season and bool(row.get("active_salary", False))
    )
    term = max(int(source.get("term_years", 1)), 1)
    expiration = active_years[-1] if active_years else season + term - 1
    years_remaining = max(expiration - season + 1, 1)
    cap_hits: dict[str, int] = {}
    release_penalties: dict[str, int] = {}
    trade_penalties: dict[str, int] = {}
    for year in range(season, expiration + 1):
        row = schedule.get(year, {})
        cap_hits[str(year)] = int(row.get("cap_hit", source["apy"]))
        if int(row.get("release_penalty", 0)) > 0:
            release_penalties[str(year)] = int(row["release_penalty"])
        if int(row.get("trade_penalty", 0)) > 0:
            trade_penalties[str(year)] = int(row["trade_penalty"])
    return {
        "annual_salary": int(source["apy"]),
        "years_remaining": years_remaining,
        "guaranteed_money": int(source["total_guaranteed"]),
        "signed_year": max(expiration - term + 1, season - 1),
        "role": str(existing.get("role", "Depth")),
        "expires_after_year": expiration,
        "total_contract_value": int(source["total_value"]),
        "total_guaranteed": int(source["total_guaranteed"]),
        "yearly_cap_hits": cap_hits,
        "yearly_cash": {str(year): int(source["apy"]) for year in range(season, expiration + 1)},
        "yearly_release_penalties": release_penalties,
        "yearly_trade_penalties": trade_penalties,
        "contract_type": "Current OTC contract",
        "source_label": "Over The Cap current contracts and team cap tables",
        "source_url": "",
        "source_snapshot": snapshot,
    }


def refresh_pack(
    pack: dict[str, Any],
    player_otc_ids: dict[str, str],
    contracts: dict[str, dict[str, Any]],
    cap_schedules: dict[str, dict[int, dict[str, int]]],
    team_adjusted_caps: dict[str, int],
    season: int,
    snapshot: str,
) -> dict[str, Any]:
    matched = 0
    fallback = 0
    unmatched: list[dict[str, str]] = []
    team_payrolls: dict[str, int] = {}
    team_caps: dict[str, dict[str, int | bool]] = {}
    contracts_by_name_team = {
        (_normalize_name(record["player"]), record["team"]): otc_id
        for otc_id, record in contracts.items()
    }
    for team in pack.get("teams", []):
        abbreviation = str(team.get("abbreviation", ""))
        cap_abbreviation = "LAR" if abbreviation == "LA" else abbreviation
        adjusted_cap = max(SALARY_CAP_2026, int(team_adjusted_caps.get(cap_abbreviation, SALARY_CAP_2026)))
        team["base_salary_cap"] = SALARY_CAP_2026
        team["salary_cap_adjustment"] = adjusted_cap - SALARY_CAP_2026
        team["salary_cap"] = adjusted_cap
        team["salary_cap_year"] = season
        payroll = 0
        for player in team.get("players", []):
            existing = player.get("contract")
            if not isinstance(existing, dict):
                continue
            otc_id = player_otc_ids.get(str(player.get("id", "")), "")
            if not otc_id:
                otc_id = contracts_by_name_team.get(
                    (_normalize_name(str(player.get("full_name", ""))), abbreviation), ""
                )
            source = contracts.get(otc_id)
            # Do not apply a newly signed contract to a stale roster assignment.
            # The roster and contract snapshots must agree on the player's club.
            if source is not None and source.get("team") == cap_abbreviation:
                player["contract"] = _current_contract(
                    existing, source, cap_schedules.get(otc_id, {}), season, snapshot
                )
                matched += 1
            else:
                if source is not None and str(existing.get("source_label", "")).startswith("Over The Cap"):
                    player["contract"] = _roster_snapshot_estimate(player, existing, season)
                else:
                    player["contract"] = _fallback_contract(existing, season)
                fallback += 1
                unmatched.append({
                    "player_id": str(player.get("id", "")),
                    "full_name": str(player.get("full_name", "")),
                    "team": abbreviation,
                })
            payroll += int(player["contract"]["yearly_cap_hits"].get(str(season), 0))
        # The Madden roster snapshot and live OTC transaction snapshot can
        # differ. Preserve every sourced player amount and reconcile the club's
        # one-season adjusted cap instead of scaling individual contracts.
        used_reconciliation = payroll > int(team["salary_cap"])
        if used_reconciliation:
            team["salary_cap"] = payroll + ROSTER_SNAPSHOT_OPERATING_RESERVE
            team["salary_cap_adjustment"] = team["salary_cap"] - SALARY_CAP_2026
        team_payrolls[abbreviation] = payroll
        team_caps[abbreviation] = {
            "base_cap": SALARY_CAP_2026,
            "effective_cap": int(team["salary_cap"]),
            "adjustment": int(team["salary_cap_adjustment"]),
            "payroll": payroll,
            "roster_snapshot_reconciliation": used_reconciliation,
        }
    source_metadata = pack.setdefault("source", {})
    source_metadata["contract_source"] = "Over The Cap current contracts and team cap tables"
    source_metadata["contract_source_url"] = OTC_CONTRACTS_URL
    source_metadata["contract_snapshot"] = snapshot
    source_metadata["contract_match_count"] = matched
    source_metadata["contract_fallback_count"] = fallback
    source_metadata["salary_cap"] = SALARY_CAP_2026
    source_metadata["salary_cap_source"] = "NFL Football Operations"
    source_metadata["salary_cap_source_url"] = NFL_SALARY_CAP_URL
    source_metadata["salary_cap_adjustment_note"] = (
        "Team caps include OTC carryover/adjustments and, where required, a one-season "
        "roster-snapshot reconciliation with a $7M roster-operations reserve. Player "
        "contract values are never scaled."
    )
    return {
        "snapshot_date": snapshot,
        "contract_source_url": OTC_CONTRACTS_URL,
        "player_identity_source_url": NFLVERSE_PLAYERS_URL,
        "salary_cap_source_url": NFL_SALARY_CAP_URL,
        "matched_contract_count": matched,
        "fallback_contract_count": fallback,
        "unmatched": unmatched,
        "team_payrolls": team_payrolls,
        "team_caps": team_caps,
    }


def validate_pack(pack: dict[str, Any], season: int) -> list[str]:
    errors: list[str] = []
    chase: dict[str, Any] | None = None
    for team in pack.get("teams", []):
        if int(team.get("base_salary_cap", 0)) != SALARY_CAP_2026:
            errors.append(f"{team.get('abbreviation')}: incorrect {season} base salary cap")
        for player in team.get("players", []):
            contract = player.get("contract")
            if not isinstance(contract, dict):
                errors.append(f"{player.get('id')}: missing contract")
                continue
            if int(contract.get("annual_salary", 0)) <= 0:
                errors.append(f"{player.get('id')}: invalid APY")
            if str(season) not in contract.get("yearly_cap_hits", {}):
                errors.append(f"{player.get('id')}: missing {season} cap hit")
            if str(player.get("full_name", "")) == "Ja'Marr Chase":
                chase = contract
    if chase is None:
        errors.append("Ja'Marr Chase was not found")
    else:
        if int(chase.get("annual_salary", 0)) != 40_250_000:
            errors.append("Ja'Marr Chase APY is not $40.25M")
        if int(chase.get("yearly_cap_hits", {}).get(str(season), 0)) != 26_171_176:
            errors.append("Ja'Marr Chase cap hit is not $26,171,176")
        if int(chase.get("expires_after_year", 0)) != 2029:
            errors.append("Ja'Marr Chase contract does not run through 2029")
    return errors


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--league-pack", type=Path, default=Path("data/leagues/nflverse_2026_full.json"))
    parser.add_argument("--players", type=Path, default=Path("tools/.cache/contracts_refresh/players.csv"))
    parser.add_argument("--cache-dir", type=Path, default=Path("tools/.cache/contracts_refresh/otc"))
    parser.add_argument("--output", type=Path, default=Path("data/leagues/nflverse_2026_full.json"))
    parser.add_argument("--report", type=Path, default=Path("data/leagues/contract_refresh_report.json"))
    parser.add_argument("--season", type=int, default=2026)
    parser.add_argument("--snapshot-date", default=date.today().isoformat())
    parser.add_argument("--download", action="store_true")
    parser.add_argument("--validate-only", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    if args.validate_only:
        errors = validate_pack(json.loads(args.validate_only.read_text(encoding="utf-8")), args.season)
        if errors:
            print("\n".join(f"ERROR: {error}" for error in errors), file=sys.stderr)
            return 1
        print(f"Validated current contract data in {args.validate_only}")
        return 0
    if args.download:
        _download(NFLVERSE_PLAYERS_URL, args.players)
        download_sources(args.cache_dir)
    contracts_path = args.cache_dir / "contracts.html"
    contracts = parse_contracts_html(contracts_path.read_text(encoding="utf-8"))
    schedules: dict[str, dict[int, dict[str, int]]] = defaultdict(dict)
    adjusted_caps: dict[str, int] = {}
    for abbreviation in TEAM_SLUGS:
        team_path = args.cache_dir / f"{abbreviation}.html"
        team_html = team_path.read_text(encoding="utf-8")
        adjusted_caps[abbreviation] = parse_adjusted_caps_html(team_html).get(args.season, SALARY_CAP_2026)
        for otc_id, years in parse_cap_html(team_html).items():
            schedules[otc_id].update(years)
    pack = json.loads(args.league_pack.read_text(encoding="utf-8"))
    report = refresh_pack(
        pack, _load_player_otc_ids(args.players), contracts, schedules, adjusted_caps,
        args.season, args.snapshot_date,
    )
    errors = validate_pack(pack, args.season)
    if errors:
        raise ValueError("\n".join(errors[:50]))
    args.output.write_text(json.dumps(pack, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"Refreshed {report['matched_contract_count']} current contracts; "
        f"{report['fallback_contract_count']} players retain labeled historical estimates."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
