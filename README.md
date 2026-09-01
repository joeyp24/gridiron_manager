# Gridiron Manager

Gridiron Manager is an extensible American football management simulation built with Godot 4.7. The current prototype supports a persistent multi-season career: choose a club, manage contracts, cap space, personnel, depth charts, and tactics, then play or simulate every campaign while building a lasting club history.

## Prototype features

- Two selectable league databases: eight original clubs or an offline nflverse 2026 preview
- Eight representative real-world clubs, one per division, with source roster identities and recent-performance ratings
- Full 41-player prototype rosters with offensive, defensive, and specialist position groups
- Editable depth charts with active/inactive status, player energy, and injuries
- Player contracts with annual salary, term, guarantees, role, and expiration year
- Contract extensions, annual contract rollover, expirations, and dead-cap relief
- A $280 million team salary cap, 35-to-45-player roster rules, and release dead money
- Free-agent negotiation shaped by quality, age, position value, projected role, market demand, term, and offer strength
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
- Seven-week round-robin regular season followed by a conference-winner championship
- Weekly schedule, results, standings, club record, league leaders, injury report, and news feed
- User-played matchups alongside deterministic AI-versus-AI simulation
- Downs, distance, field position, possession, clock management, overtime, punts, field goals, touchdowns, and turnovers
- Live play-by-play, field visualization, and team statistics
- Versioned JSON career saves with automatic migrations through schema version six and persistent data provenance
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
```

The checks cover deterministic matches and player generation; legal game state; stat invariants; rosters and depth charts; injury substitutions; contracts and the salary cap; development and retirement decisions; the permanent career archive; scouting uncertainty; draft order and pick ownership; all 56 draft selections; rookie contracts; AI roster building; free-agent population balance across repeated personnel cycles; schedule regeneration; multi-season advancement; career history; serialization; and save migration.

The committed nflverse snapshot is also validated in Python:

```powershell
python -m unittest tests/test_nflverse_importer.py
```

To rebuild it from cached source files—or download the published nflverse assets when network access is available—run:

```powershell
python tools/nflverse_importer.py
```

See [`docs/nflverse.md`](docs/nflverse.md) for the source manifest, rating model, refresh workflow, licensing, and current preview scope.

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

The simulation and career layers do not depend on scenes or controls. Future systems such as trades, staff, finances, awards, and deeper statistics can build on stable IDs and serialized domain state without replacing the current interface or match engine.

See [`docs/architecture.md`](docs/architecture.md) for dependency rules and extension points.

## Current limitations

This is a career and front-office foundation, not a complete franchise simulation. Trades, staff, facilities, broader finances, penalties, detailed player statistics, awards, and animated 11-on-11 presentation are intentionally deferred. Draft-pick ownership is modeled now, while pick trading remains a future feature.

The original league is fictional. The optional nflverse preview uses publicly distributed names and football data but excludes logos, wordmarks, headshots, and portrait URLs. It is not affiliated with or endorsed by the NFL, its clubs, the NFLPA, nflverse, or OverTheCap.
