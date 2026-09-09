# Gridiron Manager

Gridiron Manager is an extensible American football management simulation built with Godot 4.7. The current prototype supports a persistent multi-season career: choose a club, manage contracts, cap space, personnel, depth charts, and tactics, then play or simulate every campaign while building a lasting club history.

## Prototype features

- One deterministic hybrid 2026 database: nflverse league structure, schedules, identities, and contracts joined to Madden NFL 26 ratings
- Full 53-player rosters with offensive, defensive, kicking, punting, and long-snapping position groups
- All 2,035 rated players with complete 54-field Madden attribute records, stable source IDs, archetypes, jersey numbers, and cached remote headshot/team-mark references
- The published 272-game 2026 regular-season schedule, including each club's bye week
- A responsive five-tab Roster Management workspace for depth charts, the 53-man roster, game-day activation, injured reserve, practice squads, and the waiver wire
- Configurable 48-player game-day lists with positional readiness checks, explicit inactive status, player energy, and injuries
- Four-week injured-reserve stays, contract-preserving return eligibility, 16-player practice squads with veteran allowances, cross-club poaching, and priority-based in-season waivers
- Player contracts with annual salary, term, guarantees, role, and expiration year
- Contract extensions, annual contract rollover, expirations, and dead-cap relief
- A $280 million team salary cap, 53-player rosters, 90-player offseason capacity, reserve-list cap accounting, and release dead money
- An expanded 339-player launch free-agent market containing every rated player outside the active 53-player rosters
- A new-career Fantasy Draft mode that randomizes all 32 clubs, places all 2,035 players into one pool, and builds complete 53-player rosters through a resumable 53-round snake draft
- Manual Fantasy Draft selections plus cap-aware AI drafting that weighs overall, potential, age, scheme, position value, roster needs, contract cost, and league-wide positional scarcity
- Free-agent negotiation shaped by quality, age, position value, projected role, market demand, term, and offer strength
- A responsive Trade Center with multi-player and multi-pick offers, live cap and roster validation, AI acceptance, deterministic counteroffers, and a Week 9 deadline
- Three complete years of tradable seven-round draft capital whose ownership carries into the live draft
- AI-controlled IR decisions, reserve promotions, waiver claims, practice-squad building, in-season upgrades, re-signing decisions, seven-round draft selections, and legal offseason cutdowns
- A staged offseason with season review, re-signing, player development, retirement decisions, draft preparation, a live draft, roster decisions, and new-league-year readiness
- Player potential, deterministic age curves, attribute growth/regression, and squad development reports
- A unified seeded player generator for original rosters, draft prospects, veteran free agents, and emergency replacements
- A dedicated responsive Player Database with a compact searchable player dropdown, club/position filters, and a full-width profile covering Madden attributes, overall, contract terms, status, archetype, abilities, measurements, career context, headshots, and team marks
- Direct full-profile navigation from league-stat dossiers and the free-agent market, plus return links into each player's statistics
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
- Optional offensive coach mode with 26 data-driven calls, situational recommendations, tempo control, AI defensive responses, and preserved play/drive/full-game simulation
- Attribute Simulation v2 with real 11-player personnel packages, direct Madden blocking/rushing/passing/coverage/catching/tackling/kicking matchups, fatigue-aware grades, and richer player-specific play-by-play
- Player-attributed passing, rushing, receiving, defensive, kicking, and punting game books with depth-chart participation and snap counts
- Automatic weekly player/team totals, regular-season/postseason splits, traded-player club splits, and permanent career statistics
- A responsive Statistics Center with sortable league leaders, team rankings, season/postseason filters, player profiles, weekly game logs, club splits, career history, and completed-game box scores
- Live play-by-play, field visualization, and team box-score statistics
- Versioned JSON career saves with automatic migrations through schema version twelve, persistent roster/IR/practice-squad/waiver state, resumable Fantasy Draft state, hybrid player ratings, statistics history, trade history, future-pick ownership, and data provenance
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
godot --headless --path . --script res://tests/run_fantasy_draft_tests.gd
godot --headless --path . --script res://tests/run_roster_transaction_tests.gd
godot --headless --path . --script res://tests/run_ui_tests.gd
```

The checks cover deterministic automatic and manually called matches; real offensive and defensive personnel packages; direct-attribute matchup calibration; playcalling and clock management; player/team stat reconciliation; statistics filtering and sorting; 53-man and 48-player game-day legality; injured reserve, practice squads, waiver priority and claims, AI reserve management, and roster-state persistence; contracts and the salary cap; trades and future-pick ownership; Fantasy Draft completion and save/resume; development, retirement, scouting, and the rookie draft; free-agent population balance; the complete 2,035-player league; schedules and playoffs; multi-season advancement; responsive career screens; serialization; and save migration.

The committed nflverse snapshot is also validated in Python:

```powershell
python -m unittest tests/test_nflverse_importer.py tests/test_hybrid_ratings_importer.py
```

To rebuild it from cached source files—or download the published nflverse assets when network access is available—run:

```powershell
python tools/nflverse_importer.py
```

See [`docs/nflverse.md`](docs/nflverse.md) for the source manifest, rating model, refresh workflow, licensing, and full-league scope.
See [`docs/hybrid_player_database.md`](docs/hybrid_player_database.md) for the cross-source join, roster selection, attribute schema, media cache, save migration, and rebuild workflow.

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

The simulation and career layers do not depend on scenes or controls. The Statistics Center and future systems such as records, awards, waivers, practice squads, staff, and finances build on stable IDs and serialized domain state without replacing the current interface or match engine.

See [`docs/architecture.md`](docs/architecture.md) for dependency rules and extension points.
See [`docs/statistics.md`](docs/statistics.md) for the game-book schema, aggregation lifecycle, reconciliation rules, and UI extension points.
See [`docs/playcalling.md`](docs/playcalling.md) for the call-sheet data model, simulation flow, matchup modifiers, and extension path.
See [`docs/simulation_v2.md`](docs/simulation_v2.md) for personnel packages, direct-attribute matchups, tuning, and calibration.
See [`docs/fantasy_draft.md`](docs/fantasy_draft.md) for the career-mode flow, AI board, roster safeguards, persistence, and extension points.
See [`docs/roster_management.md`](docs/roster_management.md) for roster states, transaction rules, weekly processing, cap behavior, AI decisions, and UI extension points.

## Current limitations

This is a career and front-office foundation, not a complete franchise simulation. User-selected defensive calls, audibles, timeouts, official records and awards, AI-initiated trade offers, conditional picks, staff, facilities, broader finances, penalties, return-play attribution, detailed reserve-list exceptions, and animated 11-on-11 presentation are intentionally deferred.

The nflverse and Madden snapshots represent different dates, so players without a cross-source identity match receive deterministic generated contract terms. Headshots and team marks are remote references: the game uses a local cache after a successful download and shows branded placeholders while offline. The original eight-team league remains only as an internal compatibility fixture for older saves and tests; it is not offered for new careers. Gridiron Manager is not affiliated with or endorsed by the NFL, its clubs, the NFLPA, nflverse, EA, Madden, or OverTheCap.
