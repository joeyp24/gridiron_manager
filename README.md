# Gridiron Manager

Gridiron Manager is an extensible American football management simulation built with Godot 4.7. The current prototype supports a complete fictional season: choose a club, manage its depth chart and tactical identity, play or simulate each week, and pursue a league championship.

## Prototype features

- Eight fictional clubs split between the Atlantic and Frontier conferences
- Full 41-player prototype rosters with offensive, defensive, and specialist position groups
- Editable depth charts with active/inactive status, player energy, and injuries
- Persistent offensive and defensive strategy covering run balance, tempo, passing depth, fourth-down aggression, blitz frequency, and coverage preference
- Seven-week round-robin regular season followed by a conference-winner championship
- Weekly schedule, results, standings, club record, league leaders, injury report, and news feed
- User-played matchups alongside deterministic AI-versus-AI simulation
- Downs, distance, field position, possession, clock management, overtime, punts, field goals, touchdowns, and turnovers
- Live play-by-play, field visualization, and team statistics
- Versioned JSON career saves with automatic saving after management actions and completed weeks
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

The checks cover deterministic matches, legal game state, stat invariants, complete rosters and depth charts, injury substitutions, the round-robin schedule, full-season advancement, championship completion, serialization, and save/load behavior.

## Architecture

```text
scripts/
|-- application/  # Career and exhibition workflows
|-- data/         # Fictional league content
|-- domain/       # Player, team, matchup, standings, league, and game models
|-- persistence/  # Versioned career saves
|-- simulation/   # UI-independent game, schedule, season, fatigue, and injury logic
`-- ui/           # Theme, reusable components, responsive screens, and routing
```

The simulation and career layers do not depend on scenes or controls. Future systems such as contracts, drafting, scouting, progression, staff, and finances can build on stable IDs and serialized domain state without replacing the current interface or match engine.

See [`docs/architecture.md`](docs/architecture.md) for dependency rules and extension points.

## Current limitations

This is a career foundation, not a complete front-office simulation. Contracts, transactions, free agency, drafting, scouting uncertainty, staff, finances, penalties, detailed player statistics, and animated 11-on-11 presentation are intentionally deferred.

All clubs and players are fictional. No league, club, or athlete trademarks are included.
