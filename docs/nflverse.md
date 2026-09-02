# nflverse full-league data pack

Gridiron Manager ships an offline 32-team league generated from public nflverse data. The game does not call nflverse at runtime. A deterministic build tool converts published CSV assets into a compact, versioned JSON pack committed with the project, so career creation and simulation work without a connection and cannot change underneath an existing build.

## Full-league scope

The data pack uses an August 26, 2026 preseason roster snapshot and weighted regular-season performance from 2023 through 2025. It contains all 32 current clubs, eight four-team divisions, 53 selected players per club, and the published 272-game 2026 schedule. The game uses seven playoff qualifiers per conference: four division winners and three wild cards.

The committed pack includes:

- stable GSIS player IDs, names, positions, age, measurements, college, experience, and draft origin;
- deterministic overall, potential, archetype, personality, and simulation attributes;
- active-contract summaries joined through nflverse player and OverTheCap IDs, then normalized to the prototype salary cap;
- team colors, conference/division identity, and stat-derived tactical tendencies;
- 134 simulation-market players with up to eight at each internal position, drawn from source-roster depth outside the active squads and imported without contracts;
- 272 regular-season matchups across 18 weeks, with 17 games and one bye for every club;
- a serialized league-format manifest covering roster size, offseason limit, calendar, playoff field, schedule strategy, and template season;
- source filenames, SHA-256 hashes, snapshot date, performance seasons, rating-model version, license, attribution, and limitations.

Logos, wordmarks, headshots, portrait URLs, and every other external media URL are intentionally excluded.

## Refreshing the snapshot

From the repository root, run:

```powershell
python tools/nflverse_importer.py
```

The importer downloads missing assets into `tools/.cache/nflverse`, then writes `data/leagues/nflverse_2026_full.json`. Cache files are ignored by Git. For a controlled or disconnected rebuild, populate the cache and use:

```powershell
python tools/nflverse_importer.py --offline
```

Validate a pack without rebuilding it:

```powershell
python tools/nflverse_importer.py --validate-only data/leagues/nflverse_2026_full.json
python -m unittest tests/test_nflverse_importer.py
```

The importer rejects schema mismatches, duplicate IDs, missing positional depth, illegal rating bounds, roster-count drift, over-cap clubs, contracted free agents, player records containing external URLs, incomplete schedules, duplicate weekly appearances, and any club not playing exactly 17 games. Inputs are processed deterministically; identical source files and arguments produce identical ratings, rosters, market, and schedule.

## Rating model v1

The model weights 2023, 2024, and 2025 production at 20%, 30%, and 50%. Position-specific production and efficiency create a score within each rating group. Percentile placement produces the base overall, while stable ID-derived variation and position profiles produce speed, power, technique, awareness, durability, potential, archetype, and personality.

This is a simulation translation, not an assertion of objective player value. Offensive skill positions have richer public box-score signals than offensive line and some defensive roles, and roster statuses can change after the snapshot. The balanced 53-player squads are selected from a preseason pool, not claimed to reproduce official Week 1 transactions exactly. Ratings and roster selection remain a transparent first-pass model that can be recalibrated without changing the runtime provider interface.

## Sources and attribution

The importer records exact hashes for the assets used from the [nflverse-data releases](https://github.com/nflverse/nflverse-data): player identities, the 2026 roster, 2023–2025 regular-season player stats, team metadata, and historical contracts. The schedule comes from the nflverse [nfldata games dataset](https://github.com/nflverse/nfldata/blob/master/data/games.csv). Contract summaries originate from [OverTheCap](https://overthecap.com/) through nflverse.

The data pack declares the nflverse distribution license as [CC BY 4.0](https://github.com/nflverse/nflverse-data/blob/main/LICENSE.md) and carries attribution in the pack and every resulting career save. Review upstream dataset documentation and license notices before redistribution or commercial release, since individual upstream sources and trademark/publicity rights may impose additional obligations.

Gridiron Manager is not an official NFL product and is not affiliated with or endorsed by the NFL, its clubs, the NFLPA, nflverse, or OverTheCap. Team and player names are used only as simulation data; official visual identities are not shipped.
