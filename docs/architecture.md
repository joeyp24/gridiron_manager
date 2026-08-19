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

- `PlayerData` stores ratings, potential, age, position, energy, active status, and injury state.
- `PlayerContract` stores salary, remaining term, fixed expiration year, guarantees, signing year, and projected role.
- `TeamData` owns roster order, depth charts, cap accounting, roster limits, colors, conference identity, and tactics.
- `TransactionData` records signings, releases, extensions, and expirations for history, news, and saves.
- `SeasonHistoryData` stores immutable championship, standings, and managed-club snapshots.
- `DevelopmentReportData` records annual age, overall, potential, and attribute movement.
- `MatchupData` describes a scheduled or completed game.
- `StandingData` tracks regular-season records and tiebreak metrics.
- `LeagueState` owns the calendar, standings, news, phase, and championship state.
- `GameStateData` and `PlayResult` describe a live match.

Stable IDs are the boundary between runtime objects, schedules, depth charts, and save files. New systems should preserve that rule instead of relying on node paths or object identity.

### Simulation

The simulation layer contains focused, UI-independent services:

- `FootballSimulator` resolves seeded plays, drives, regulation, and overtime.
- `ScheduleGenerator` builds seeded, year-specific seven-week round robins.
- `LeagueSimulator` coordinates AI games, weekly recovery, fatigue, and injuries.

As match detail grows, play calling, penalties, injuries, clock rules, and special teams can move into narrower collaborators while the existing public commands remain stable.

### Application

- `GameSession` coordinates quick exhibitions.
- `CareerSession` coordinates the managed club, weekly flow, user match, AI results, news, and phase advancement.
- `TransactionService` prices offers and extensions, evaluates player expectations, performs transactions, and runs basic AI roster improvement.
- `OffseasonService` owns stage transitions, AI retention, contract rollover, replacement depth, development, cap growth, roster readiness, and new-season setup.
- `RosterValidator` enforces cap, roster-size, required-position, duplicate-ID, and contract rules.

Application sessions are the composition point between content, simulation, saves, and presentation. UI screens request actions from these sessions rather than calculating outcomes themselves.

### Persistence

`SaveRepository` writes a versioned JSON envelope around serialized career state. The current schema is version 3. Version-one careers receive the contract and free-agency model; version-two careers receive fixed contract expirations, deterministic potential, season history, and development-report storage. Persistence is isolated so storage can later move behind platform services without changing career logic.

### Data

`SampleLeague` generates the eight fictional clubs and their 41-player rosters. It can later be replaced by resource-backed or JSON-backed repositories without changing the career or simulation callers:

```text
TeamRepository
|-- ResourceTeamRepository
|-- JsonTeamRepository
`-- GeneratedLeagueRepository
```

Static definitions and mutable career state should remain separate. A club archetype is content; its record, active roster, contracts, cap charges, transactions, injuries, energy, and strategy belong to the career save.

### Presentation

`scripts/ui` contains the centralized theme, reusable controls, responsive route screens, and shell navigation. Screens render application/domain state and emit user intent. Wide layouts use multiple columns; narrower layouts reflow into scrollable single-column views instead of relying on a fixed resolution.

## Intended expansion path

The multi-season loop, standings, depth-chart, health, tactics, contracts, cap, free-agency, development, history, AI transaction, and persistence foundations are now implemented. The next milestones should build outward in this order:

1. Draft classes, scouting uncertainty, player evaluation, and a playable draft.
2. Retirements and rookie replacement integrated into the existing offseason stages.
3. Trades, draft-pick assets, and deeper AI roster valuation.
4. Staff, facilities, finances, objectives, and job security.
5. More detailed player and season statistics, records, and awards.
6. Focused match services for penalties, play calling, special teams, and richer tactical interaction.

Each milestone should add checks at the lowest applicable layer. League simulations must remain runnable headlessly so balancing can use thousands of seasons instead of manual playthroughs.
