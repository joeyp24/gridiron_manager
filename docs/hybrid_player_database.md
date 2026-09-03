# Hybrid player database

Gridiron Manager's committed 2026 league pack combines two data sources behind the existing `LeagueDataPackProvider` boundary. nflverse remains authoritative for the league format, 32 club identities, schedule, stable GSIS identities when a match exists, and available contract records. The Madden NFL 26 snapshot supplies the complete player pool, overall ratings, detailed attributes, archetypes, abilities, jersey numbers, headshot references, and team-mark references.

## Join and roster construction

`tools/hybrid_ratings_importer.py` normalizes names, source positions, and team names before resolving records. Candidate matches are ranked by name, position, current club, and biographical agreement. A matched player keeps the nflverse ID and contract. An unmatched Madden player receives a stable `madden_26_<source id>` game ID and a deterministic generated contract when selected for an active roster.

The importer treats the Madden snapshot as the complete player population. It builds 53 active players for each of the 32 clubs, first satisfying positional coverage and then selecting the strongest remaining players. Everyone outside those 1,696 active slots enters free agency. The current snapshot therefore contains 2,035 players: 1,696 rostered and 339 free agents. The generated `data/leagues/hybrid_ratings_report.json` records match totals and every unmatched or ambiguous resolution for review.

## Runtime model

Each `PlayerData` owns a serializable `PlayerRatingsData` record. It retains the source overall and all 54 numeric source fields, including physical, passing, ball-carrier, receiving, blocking, defensive, and special-teams attributes. The existing simulation-facing speed, power, technique, awareness, and durability values are derived by position so current systems continue to use stable interfaces.

Development and regression apply the same overall delta to the detailed profile. Generated rookies, veterans, and emergency players use the same schema with projected attributes, allowing future classes to appear in the Player Database without special handling. Save schema version 10 persists the detailed record. When an older save contains a player with a matching stable ID, `HybridRatingsCatalog` restores the source profile and then applies that career's accumulated overall delta.

## Player interface and media

The Players tab provides a searchable league directory with club and position filters. Its profile shows overall, source archetype, contract or market estimate, availability, measurements, core simulation ratings, abilities, and every detailed attribute category. League Statistics and Free Agency both link directly to this profile, which can route back to the player's statistical dossier.

Headshots and team marks remain HTTPS references rather than embedded binaries. `CachedRemoteImage` downloads them on demand, writes a persistent cache under the game's user-data directory, and falls back to initials or a club abbreviation when the game is offline or a source image is unavailable. The league itself remains fully playable offline.

## Rebuilding the pack

Keep `raw_ratings.json` outside the repository, then run:

```powershell
python tools/hybrid_ratings_importer.py --league-pack path/to/pristine/nflverse_2026_full.json --ratings path/to/raw_ratings.json
python tools/hybrid_ratings_importer.py --ratings path/to/raw_ratings.json --validate-only data/leagues/nflverse_2026_full.json
python -m unittest tests/test_nflverse_importer.py tests/test_hybrid_ratings_importer.py
```

Use a pristine nflverse pack as the first command's input so its unmatched source player pool remains available for the join audit. The output and report are deterministic for identical inputs. Review the report, player/free-agent counts, source hashes, and Python/Godot checks before committing a refreshed snapshot.
