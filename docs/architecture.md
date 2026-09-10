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

- `PlayerData` stores ratings, potential, age, position, energy, explicit roster status, game-day activation, injury/return state, archetype, personality, measurements, college, draft origin, experience, team history, and career peak.
- `PlayerContract` stores salary, remaining term, fixed expiration year, guarantees, signing year, and projected role.
- `TeamData` owns its 53-man, injured-reserve, and practice-squad lists; depth charts; game-day activation; cap accounting; configurable limits; colors; conference/division identity; and tactics.
- `WaiverEntryData` owns one temporarily league-controlled player, release/deadline metadata, and the stable IDs of claiming clubs.
- `TransactionData` records signings, releases, extensions, expirations, and completed club trade ledgers for history, news, and saves.
- `SeasonHistoryData` stores immutable championship, standings, and managed-club snapshots.
- `RetiredPlayerData` stores immutable career snapshots for retired players and other permanent league departures.
- `DevelopmentReportData` records annual age, overall, potential, and attribute movement.
- `ProspectData` stores the complete incoming-player profile, including hidden true ratings and public combine/production data.
- `ScoutingReportData` stores a club-specific, progressively narrowed view of a prospect without mutating the prospect's true talent.
- `DraftPickData` keeps original and current ownership separate across three future draft years and the live draft.
- `DraftStateData` owns the class, reports, board favorites, pick clock, selection history, and undrafted conversion for one draft year.
- `FantasyDraftStateData` and `FantasyDraftPickData` store the new-career draft order, 53-round snake pick clock, completed selections, and exact resume point independently of the annual rookie draft.
- `TradeProposalData` stores immutable completed-deal packages, values, asset labels, clubs, timing, and summary history.
- `StatLineData` is the sparse, extensible stat-value boundary shared by player game, season, career, and team records.
- `GameBookData` stores an immutable completed-game snapshot; `SeasonStatisticsData` and `LeagueStatisticsData` own idempotent season and career aggregation.
- `LeagueFormatData` stores roster limits, regular/postseason length, playoff size, schedule strategy, and template season without hard-coding one league shape into career rules.
- `MatchupData` describes a scheduled or completed game.
- `StandingData` tracks regular-season records and tiebreak metrics.
- `LeagueState` owns the calendar, division/conference standings, playoff seeds and rounds, news, waiver wire and priority context, future-pick ownership, trade history, phase, and championship state.
- `GameStateData` and `PlayResult` describe a live match.
- `PlayDefinitionData`, `PlaybookData`, `PlayCallData`, and `DefensiveCallData` define stable, serializable coaching intent separately from the outcome of a snap.

Stable IDs are the boundary between runtime objects, schedules, depth charts, and save files. New systems should preserve that rule instead of relying on node paths or object identity.

### Simulation

The simulation layer contains focused, UI-independent services:

- `FootballSimulator` resolves seeded selected or automatic plays, drives, regulation, and overtime through one statistics-compatible snap boundary.
- `PlayCallerService` validates calls, ranks situational recommendations, chooses AI offense and defense calls, and calculates concept-versus-coverage and repetition modifiers.
- `PersonnelPackageService` turns offensive and defensive personnel labels into the actual eleven available depth-chart players used on a snap.
- `AttributeMatchupService` builds deterministic run, pass, coverage, tackle, catching, kicking, and punting grades directly from detailed player attributes and fatigue.
- `SimulationTuning` loads versioned coefficients from JSON so balancing does not require rewriting the snap resolver.
- `GameStatAccumulator` consumes structured play participants and outcomes, then reconciles player credits with the live team box score.
- `ScheduleGenerator` clones the published 2026 schedule and rotates its division-preserving template for deterministic future 17-game seasons. The round-robin path remains for legacy saves.
- `LeagueSimulator` coordinates AI games, weekly recovery, fatigue, and injuries.

Every manual or automatic path uses the same Attribute Simulation v2 boundary. Its transient matchup context supports richer play-by-play and future scouting without changing the immutable game-book format. As match detail grows, user defensive calls, penalties, injuries, clock rules, and return teams can move into narrower collaborators while the existing public commands remain stable.

### Application

- `GameSession` coordinates quick exhibitions.
- `CareerSession` coordinates the managed club, weekly flow, user match, AI results, news, and phase advancement.
- `WeekSimulationTask` exposes preparation, individual matchups, league operations, and calendar finalization as bounded progress units while preserving synchronous simulation wrappers.
- `TransactionService` prices offers and extensions, evaluates player expectations, performs transactions, and runs basic AI roster improvement.
- `RosterTransactionService` owns game-day activation, IR placement and return, practice-squad contracts/promotions/releases/poaching, waiver claims and resolution, reserve-list initialization, and weekly AI management.
- `OffseasonService` owns stage transitions, AI retention, contract rollover, replacement depth, development, cap growth, roster readiness, and new-season setup.
- `RetirementService` owns deterministic career-exit decisions, retirement dead money, archival history, announcements, and free-agent population balance.
- `DraftService` owns class creation, scouting actions, pick order, user and AI selections, rookie signings, draft completion, and recap grades.
- `FantasyDraftService` owns the league-wide launch pool, randomized snake order, manual and AI selections, positional-scarcity protection, salary-cap reserves, 53-player roster construction, and Week 1 finalization.
- `TradeService` owns the trade window, future draft capital, package valuation, partner evaluation, counteroffers, projected roster/cap validation, dead-cap transfer rules, atomic execution, and history.
- `StatisticsService` provides UI-ready league leaders, team rankings, derived rates, player game logs and club splits, completed-game lookup, and reusable sorting/filtering without mutating stored totals.
- `RosterValidator` enforces cap, 53-man and practice-squad limits, veteran allowances, game-day size and positional coverage, required-position, duplicate-ID, and contract rules.

Application sessions are the composition point between content, simulation, saves, and presentation. UI screens request actions from these sessions rather than calculating outcomes themselves.

### Persistence

`SaveRepository` writes a versioned JSON envelope around serialized career state. The current schema is version 12. Earlier migrations add contracts and free agency, fixed expirations and potential, history and development reports, rookie draft state, enriched player/career metadata, retirement archives, source provenance, league format, future-season schedule templates, playoff seeds, future draft-pick ownership, trade history, game books, season/career statistics, hybrid Madden ratings, and Fantasy Draft state. Version twelve adds explicit player roster states, team IR/practice-squad lists, configurable reserve limits, and pending waiver claims. Existing careers receive compatible defaults while eight-team saves retain their smaller legacy format.

### Data

`LeagueCatalog` is the composition boundary for career databases. New careers and exhibitions use the complete versioned nflverse JSON snapshot through `LeagueDataPackProvider`; `SampleLeague` remains an internal legacy fixture for save migration and focused tests. Providers return fresh mutable domain objects, league-format rules, schedule templates, and source metadata. `PlaybookCatalog` loads versioned play definitions from JSON so new formations and concepts do not require Match Center changes. `PlayerGenerator` remains the seeded source for future draft prospects, veteran free agents, and emergency replacements. Importers remain build-time tooling and never become a runtime network dependency.

```text
LeagueCatalog
|-- LeagueDataPackProvider -> versioned 32-team JSON snapshot
`-- SampleLeague -> legacy compatibility only
```

Static definitions and mutable career state remain separate. Loading a source always constructs a new object graph. A club archetype is content; its record, active roster, contracts, cap charges, transactions, injuries, energy, and strategy belong to the career save. Stable source IDs, snapshot dates, attribution, conference names, and divisions are serialized so later providers can be added without another structural rewrite.

### Presentation

`scripts/ui` contains the centralized theme, reusable controls, responsive route screens, and shell navigation. Screens render application/domain state and emit user intent. Career creation selects standard rosters or Fantasy Draft mode; active Fantasy Draft saves route back into the war room until finalization, while other career sections remain locked against incomplete rosters. The Match Center adds an optional responsive offensive call sheet without replacing its automatic snap, drive, or full-game controls. The Statistics Center uses the application query boundary for sortable leaders, team rankings, player dossiers, game logs, and game books. The shell-owned `SimulationLoadingOverlay` presents actual task progress and blocks navigation while staged league state is incomplete. Wide layouts use multiple columns; narrower layouts reflow into scrollable single-column views instead of relying on a fixed resolution.

## Intended expansion path

The multi-season loop, standings, roster transactions, depth-chart, health, tactics, contracts, cap, free-agency, development, player generation, retirement, scouting, drafting, multi-asset trades, future-pick ownership, player/team statistics, history, AI transaction, and persistence foundations are now implemented. The next milestones should build outward in this order:

1. AI-initiated trade offers, trade-block discovery, trade deadlines, and richer personnel planning around injuries and roster weaknesses.
2. Staff, coaching schemes, facilities, finances, objectives, and job security.
3. League/franchise records, awards, and richer modeled categories such as penalties and returns, extending the responsive Statistics Center.
4. User defensive playcalling, audibles, timeouts, penalties, return attribution, special-teams decisions, and richer tactical interaction.

Each milestone should add checks at the lowest applicable layer. League simulations must remain runnable headlessly so balancing can use thousands of seasons instead of manual playthroughs.
