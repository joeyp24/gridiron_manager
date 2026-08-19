# Gridiron Manager

Gridiron Manager is an extensible American football management simulation built with Godot 4.7. The current prototype is a polished exhibition-game vertical slice: choose a fictional club, inspect its roster, set a high-level game plan, and follow a deterministic play-by-play simulation through a live match center.

## Prototype features

- Four fictional teams with distinct identities, ratings, and key-player rosters
- Team comparison and tactical presets for offense and game-day aggression
- Seeded, deterministic play simulation
- Downs, distance, field position, possession, game clock, punts, field goals, touchdowns, and turnovers
- Live play-by-play, drive history, field visualization, and team statistics
- Modular domain, simulation, application, and presentation layers

## Run the project

1. Install Godot 4.7.1 or a compatible Godot 4.7 maintenance release.
2. Import `project.godot` from the Godot Project Manager.
3. Press **F6** or the **Run Project** button.

The project targets a 1440x900 design canvas, opens at 1280x800, and supports resizing down to 1120x760.

## Run the simulation checks

From the repository root:

```powershell
godot --headless --path . --script res://tests/run_tests.gd
```

The checks verify deterministic seeded results, legal terminal state, basic stat invariants, and repeated simulation stability.

## Architecture

```text
scripts/
├── application/  # Coordinates the current session and selected game plan
├── data/         # Fictional prototype content
├── domain/       # Pure player, team, game-state, and play-result models
├── simulation/   # UI-independent football rules and outcome resolution
└── ui/           # Theme, reusable components, and screens
```

The simulation layer has no dependency on scenes or controls. Future career systems—schedules, standings, contracts, drafting, scouting, progression, and saves—can consume the same domain objects without coupling league rules to the interface.

See [`docs/architecture.md`](docs/architecture.md) for the dependency rules and intended extension points.

## Current limitations

This is an exhibition prototype, not a complete career mode. Penalties, injuries, overtime rules, special-team depth, contracts, seasons, staff, scouting, and animated 11-on-11 presentation are intentionally deferred.

All teams and players are fictional. No league, club, or athlete trademarks are included.
