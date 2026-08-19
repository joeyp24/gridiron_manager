# Architecture

Gridiron Manager uses a layered architecture so prototype systems can mature without forcing the interface, simulation, and career state to be rewritten together.

## Dependency direction

```text
UI screens → application session → simulation services → domain models
                         data providers ↗
```

Dependencies point inward. Domain models never import UI scripts or scenes, and the football simulator never reads controls. The current sample league is a replaceable content provider rather than a source of game rules.

## Layers

### Domain

`scripts/domain` contains the data structures that describe football concepts:

- `PlayerData`
- `TeamData`
- `GameStateData`
- `PlayResult`

These are lightweight runtime models with stable IDs. Future save files and league databases should refer to entities by ID rather than by node path or object identity.

### Simulation

`scripts/simulation/football_simulator.gd` owns game rules and seeded outcome resolution. It exposes commands such as `simulate_next_play`, `simulate_drive`, and `simulate_to_end`, all of which operate without a scene tree.

New football detail should generally be introduced through focused collaborators instead of allowing this class to grow indefinitely. Likely additions include:

- `PlayCaller`
- `ClockManager`
- `PenaltyResolver`
- `InjuryResolver`
- `SpecialTeamsResolver`
- `GameRules`

The public commands and `GameStateData` can remain stable while those responsibilities move behind the simulator boundary.

### Application

`GameSession` coordinates the current user selection, game plan, and live simulator. It is the composition point between content and presentation. Career mode can expand this layer with a `CareerSession` that owns the league calendar, active club, and persistence services.

### Data

`SampleLeague` provides the fictional prototype content. It can later be replaced by resource-backed or JSON-backed repositories without changing simulation callers:

```text
TeamRepository
├── ResourceTeamRepository
├── JsonTeamRepository
└── GeneratedLeagueRepository
```

Static definitions and mutable career state should remain separate. A team archetype is content; its active roster, finances, injuries, and record belong to the career save.

### Presentation

`scripts/ui` contains reusable visual components, a centralized theme, and route-level screens. Screens consume application and domain state but do not calculate football outcomes. The top-level `main.gd` currently handles simple route changes; it can later be replaced by a dedicated navigation service without touching the screens' underlying models.

## Intended expansion path

1. Add `LeagueState`, schedules, standings, and week advancement.
2. Add roster slots, depth charts, fatigue, and injuries.
3. Introduce contracts, transactions, free agency, and the draft.
4. Replace perfect ratings with scouting knowledge and uncertainty.
5. Add persistence behind a versioned `SaveRepository` interface.
6. Break detailed play resolution into specialized simulation services.

Each milestone should add tests at the lowest applicable layer. League simulations should remain runnable headlessly so balancing can use thousands of seasons rather than manual playthroughs.
