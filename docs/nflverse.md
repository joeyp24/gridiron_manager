# nflverse data-pack foundation

Gridiron Manager includes an optional offline preview generated from public nflverse data. The game does not call nflverse at runtime. A deterministic build tool converts published CSV assets into a compact, versioned JSON pack committed with the project, so career creation and simulation work without a connection and cannot change underneath an existing build.

## Preview scope

The first data pack uses a 2026 roster snapshot and weighted regular-season performance from 2023 through 2025. It contains eight representative clubs—one from each NFL division—normalized to the prototype's existing 41-player roster and eight-club schedule. AFC and NFC identities drive standings and the championship matchup; source divisions are retained for future 32-club competition formats.

The committed pack includes:

- stable GSIS player IDs, names, positions, age, measurements, college, experience, and draft origin;
- deterministic overall, potential, archetype, personality, and simulation attributes;
- active-contract summaries joined through nflverse player and OverTheCap IDs, then normalized to the prototype salary cap;
- team colors, conference/division identity, and stat-derived tactical tendencies;
- 32 simulation-market players with two at each internal position, drawn from source-roster depth outside the active preview squads and imported without contracts;
- source filenames, SHA-256 hashes, snapshot date, performance seasons, rating-model version, license, attribution, and limitations.

Logos, wordmarks, headshots, portrait URLs, and every other external media URL are intentionally excluded.

## Refreshing the snapshot

From the repository root, run:

```powershell
python tools/nflverse_importer.py
```

The importer downloads missing assets into `tools/.cache/nflverse`, then writes `data/leagues/nflverse_2026_preview.json`. Cache files are ignored by Git. For a controlled or disconnected rebuild, populate the cache and use:

```powershell
python tools/nflverse_importer.py --offline
```

Validate a pack without rebuilding it:

```powershell
python tools/nflverse_importer.py --validate-only data/leagues/nflverse_2026_preview.json
python -m unittest tests/test_nflverse_importer.py
```

The importer rejects schema mismatches, duplicate IDs, missing positional depth, illegal rating bounds, roster-count drift, over-cap clubs, contracted free agents, and player records containing external URLs. Inputs are processed deterministically; identical source files and arguments produce identical player ratings and roster selections.

## Rating model v1

The model weights 2023, 2024, and 2025 production at 20%, 30%, and 50%. Position-specific production and efficiency create a score within each rating group. Percentile placement produces the base overall, while stable ID-derived variation and position profiles produce speed, power, technique, awareness, durability, potential, archetype, and personality.

This is a simulation translation, not an assertion of objective player value. Offensive skill positions have richer public box-score signals than offensive line and some defensive roles, roster statuses can change after the snapshot, and reduced 41-player squads omit practice-squad and reserve depth. All ratings should be treated as a transparent first-pass model that can be recalibrated without changing the runtime provider interface.

## Sources and attribution

The importer records exact hashes for the nflverse assets used from the [nflverse-data releases](https://github.com/nflverse/nflverse-data): player identities, the 2026 roster, 2023–2025 regular-season player stats, team metadata, and historical contracts. Contract summaries originate from [OverTheCap](https://overthecap.com/) through nflverse.

The data pack declares the nflverse distribution license as [CC BY 4.0](https://github.com/nflverse/nflverse-data/blob/main/LICENSE.md) and carries attribution in the pack and every resulting career save. Review upstream dataset documentation and license notices before redistribution or commercial release, since individual upstream sources and trademark/publicity rights may impose additional obligations.

Gridiron Manager is not an official NFL product and is not affiliated with or endorsed by the NFL, its clubs, the NFLPA, nflverse, or OverTheCap. Team and player names are used only as data in this optional prototype preview; official visual identities are not shipped.
