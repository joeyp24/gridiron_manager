# Gridiron Manager

Gridiron Manager is an extensible American football management simulation built with Godot 4.7. The current prototype supports a persistent multi-season career: choose a club, manage contracts, cap space, personnel, depth charts, and tactics, then play or simulate every campaign while building a lasting club history.

## Prototype features

- One deterministic offline nflverse 2026 league with all 32 current clubs
- Full 53-player rosters with offensive, defensive, kicking, punting, and long-snapping position groups
- The published 272-game 2026 regular-season schedule, including each club's bye week
- Editable depth charts with active/inactive status, player energy, and injuries
- Player contracts with annual salary, term, guarantees, role, and expiration year
- Contract extensions, annual contract rollover, expirations, and dead-cap relief
- A $280 million team salary cap, 53-player active rosters, 90-player offseason capacity, and release dead money
- An expanded 134-player launch free-agent market drawn from source-roster depth
- Free-agent negotiation shaped by quality, age, position value, projected role, market demand, term, and offer strength
- A responsive Trade Center with multi-player and multi-pick offers, live cap and roster validation, AI acceptance, deterministic counteroffers, and a Week 9 deadline
- Three complete years of tradable seven-round draft capital whose ownership carries into the live draft
- AI-controlled in-season moves, re-signing decisions, seven-round draft selections, and legal offseason roster building
- A staged offseason with season review, re-signing, player development, retirement decisions, draft preparation, a live draft, roster decisions, and new-league-year readiness
- Player potential, deterministic age curves, attribute growth/regression, and squad development reports
- A unified seeded player generator for original rosters, draft prospects, veteran free agents, and emergency replacements
- Rich player profiles with position archetypes, personality, measurements, college, experience, draft origin, team history, and career peak rating
- Position-aware career aging, deterministic retirement decisions, retirement dead money, and a permanent career archive
- Free-agent population balancing that preserves positional coverage across long-running careers
- Deterministic fictional draft classes with measurements, production, archetypes, personality, combine results, and hidden true ratings
- Club-specific scouting ranges, confidence levels, targeted assignments, favorites, position filters, team needs, and starter comparisons
- A playable seven-round draft with standings-based order, explicit pick ownership, AI boards, rookie contracts, undrafted free agents, and team-by-team recap grades
- Permanent season history with champions, title-game results, final standings, and managed-club records
- Persistent offensive and defensive strategy covering run balance, tempo, passing depth, fourth-down aggression, blitz frequency, and coverage preference
- An 18-week, 17-game regular season followed by seven-team AFC and NFC playoff brackets and a championship
- Weekly schedule, results, standings, club record, league leaders, injury report, and news feed
- User-played matchups alongside deterministic AI-versus-AI simulation
- Downs, distance, field position, possession, clock management, overtime, punts, field goals, touchdowns, and turnovers
- Player-attributed passing, rushing, receiving, defensive, kicking, and punting game books with depth-chart participation and snap counts
- Automatic weekly player/team totals, regular-season/postseason splits, traded-player club splits, and permanent career statistics
- Live play-by-play, field visualization, and team box-score statistics
- Versioned JSON career saves with automatic migrations through schema version nine, statistics history, trade history, future-pick ownership, and persistent data provenance
- Responsive layouts that reflow and scroll cleanly across desktop window sizes
- Quick exhibition mode for one-off games

## Run the project

1. Install Godot 4.7.1 or a compatible Godot 4.7 maintenance release.
2. Import `project.godot` from the Godot Project Manager.
3. Press **F5** or the **Run Project** button.

The game opens maximized, remains resizable, and adapts its navigation, cards, tables, roster details, and match center to the available space. Career saves are stored under Godot's per-user application data directory at `gridiron_manager/career.json`.

## Run the automated checks

From the repository root:

```powershell
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/run_trade_tests.gd
godot --headless --path . --script res://tests/run_full_league_tests.gd
godot --headless --path . --script res://tests/run_ui_tests.gd
```

The checks cover deterministic matches and player generation; legal game state; player/team stat reconciliation; weekly, season, team-split, and career aggregation; duplicate-game protection; rosters and depth charts; injury substitutions; contracts and the salary cap; trade valuation, counteroffers, deadlines, atomic execution, dead cap, and future-pick ownership; development and retirement decisions; the permanent career archive; scouting uncertainty; draft order; rookie contracts; AI roster building; free-agent population balance; all 32 teams and 1,696 rostered players; 17-game schedules; the complete playoff bracket; future schedule regeneration; multi-season advancement; responsive selection and Trade Center UI; serialization; and save migration.

The committed nflverse snapshot is also validated in Python:

```powershell
python -m unittest tests/test_nflverse_importer.py
```

To rebuild it from cached source files—or download the published nflverse assets when network access is available—run:

```powershell
python tools/nflverse_importer.py
```

See [`docs/nflverse.md`](docs/nflverse.md) for the source manifest, rating model, refresh workflow, licensing, and full-league scope.

## Architecture

```text
scripts/
|-- application/  # Career and exhibition workflows
|-- data/         # League catalog, fictional content, and versioned JSON providers
|-- domain/       # Player, team, matchup, standings, league, and game models
|-- persistence/  # Versioned career saves
|-- simulation/   # UI-independent game, schedule, season, fatigue, and injury logic
`-- ui/           # Theme, reusable components, responsive screens, and routing
```

The simulation and career layers do not depend on scenes or controls. Future systems such as the Statistics Center, records, awards, waivers, practice squads, staff, and finances can build on stable IDs and serialized domain state without replacing the current interface or match engine.

See [`docs/architecture.md`](docs/architecture.md) for dependency rules and extension points.
See [`docs/statistics.md`](docs/statistics.md) for the game-book schema, aggregation lifecycle, reconciliation rules, and UI extension points.

## Current limitations

This is a career and front-office foundation, not a complete franchise simulation. A browsable Statistics Center, official records and awards, practice squads, waivers, injured-reserve designations, AI-initiated trade offers, conditional picks, staff, facilities, broader finances, penalties, return-play attribution, and animated 11-on-11 presentation are intentionally deferred.

The shipped league uses publicly distributed names and football data but excludes logos, wordmarks, headshots, and portrait URLs. The original eight-team league remains only as an internal compatibility fixture for older saves and tests; it is not offered for new careers. Gridiron Manager is not affiliated with or endorsed by the NFL, its clubs, the NFLPA, nflverse, or OverTheCap.
