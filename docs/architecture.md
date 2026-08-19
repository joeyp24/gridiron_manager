# Architecture

Gridiron Manager uses a layered architecture so the game can grow without coupling career rules, match simulation, persistence, and interface code.

## Dependency direction

```text
UI screens -> application sessions -> simulation services -> domain models
                         |                    ^
                         `-> persistence      |
data providers ------------------------------'
```

Dependencies point inward. Domain models never import UI scripts or scenes, and simulation services never read controls. The fictional sample league is a replaceable content provider rather than a source of game rules.

## Layers

### Domain

`scripts/domain` contains lightweight runtime models with stable IDs:

- `PlayerData` stores ratings, position, energy, active status, and injury state.
- `TeamData` owns roster order, depth charts, colors, conference identity, and tactics.
- `MatchupData` describes a scheduled or completed game.
- `StandingData` tracks regular-season records and tiebreak metrics.
- `LeagueState` owns the calendar, standings, news, phase, and championship state.
- `GameStateData` and `PlayResult` describe a live match.

Stable IDs are the boundary between runtime objects, schedules, depth charts, and save files. New systems should preserve that rule instead of relying on node paths or object identity.

### Simulation

The simulation layer contains focused, UI-independent services:

- `FootballSimulator` resolves seeded plays, drives, regulation, and overtime.
- `ScheduleGenerator` builds the seven-week round robin.
- `LeagueSimulator` coordinates AI games, weekly recovery, fatigue, and injuries.

As match detail grows, play calling, penalties, injuries, clock rules, and special teams can move into narrower collaborators while the existing public commands remain stable.

### Application

- `GameSession` coordinates quick exhibitions.
- `CareerSession` coordinates the managed club, weekly flow, user match, AI results, news, and phase advancement.

Application sessions are the composition point between content, simulation, saves, and presentation. UI screens request actions from these sessions rather than calculating outcomes themselves.

### Persistence

`SaveRepository` writes a versioned JSON envelope around serialized career state. The current schema is version 1 and has a migration boundary ready for future save formats. Persistence is isolated so storage can later move behind platform services without changing career logic.

### Data

`SampleLeague` generates the eight fictional clubs and their 41-player rosters. It can later be replaced by resource-backed or JSON-backed repositories without changing the career or simulation callers:

```text
TeamRepository
|-- ResourceTeamRepository
|-- JsonTeamRepository
`-- GeneratedLeagueRepository
```

Static definitions and mutable career state should remain separate. A club archetype is content; its record, active roster, injuries, energy, and strategy belong to the career save.

### Presentation

`scripts/ui` contains the centralized theme, reusable controls, responsive route screens, and shell navigation. Screens render application/domain state and emit user intent. Wide layouts use multiple columns; narrower layouts reflow into scrollable single-column views instead of relying on a fixed resolution.

## Intended expansion path

The season, standings, depth-chart, fatigue, injury, tactical, and persistence foundations are now implemented. The next milestones should build outward in this order:

1. Contracts, salary rules, transactions, and free agency.
2. Offseason flow, draft classes, and a playable draft.
3. Scouting knowledge, uncertainty, and player development.
4. Staff, facilities, finances, objectives, and job security.
5. More detailed player and season statistics, records, awards, and history.
6. Focused match services for penalties, play calling, special teams, and richer tactical interaction.

Each milestone should add checks at the lowest applicable layer. League simulations must remain runnable headlessly so balancing can use thousands of seasons instead of manual playthroughs.
