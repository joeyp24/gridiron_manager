# Statistics engine

The statistics engine is a UI-independent event pipeline. A simulated play identifies its participants and outcome, `GameStatAccumulator` credits the live player and team lines, and a completed matchup becomes an immutable `GameBookData` record. `LeagueStatisticsData` then rolls that book into season and career totals exactly once.

```text
PlayResult participants + outcome
              |
              v
     GameStatAccumulator
              |
              v
 player lines + team box score
              |
              v
        immutable game book
              |
              v
 season totals, phase splits, team splits, career totals
```

## Attribution

Scrimmage plays include stable IDs for the passer, target, ball carrier, tackler, sack player, interceptor, fumbler, forced-fumble player, and recovery player as applicable. Kicks and punts identify the kicker, punter, and long snapper. Each result also carries offensive and defensive participants plus starter snapshots, allowing game appearances, starts, and unit snaps to be credited independently of the presentation layer.

Skill-position targets, carries, pass rushers, coverage players, and tacklers are selected deterministically from available depth-chart groups. Repeating a game with the same teams, tactics, health, depth charts, and seed produces the same participants and statistics.

## Aggregation and identity

- A game book is keyed by the matchup ID and cannot be aggregated twice.
- Player totals are keyed by the permanent player ID, so they follow a player through trades, releases, free agency, and retirement.
- Each player season retains club splits and regular-season/postseason phase splits.
- Career totals remain separate from the mutable `PlayerData` ratings and roster object.
- Player game lines are sparse: zero-value categories are omitted to keep long-career saves compact.
- Team game lines retain a fully shaped box score for straightforward rendering and compatibility with the existing Match Center.
- Each game book retains a compact snap-by-snap call ledger with both coordinators' call IDs and names, offensive personnel and tempo, defensive personnel and coverage shell, user-selection flags, and the resulting yards and points. This supports future tendency scouting without storing presentation timelines.

Schema version nine migrates older careers with empty statistic collections. Previously completed scores and the legacy seven-field team summaries remain visible, but the migration does not invent individual production that the old simulator never recorded.

## Reconciliation rules

Automated tests protect the accounting boundaries used by future leaderboards and records:

- player passing attempts and completions equal the team totals;
- gross passing yards equal both credited passer yards and receiving yards;
- net team passing subtracts credited sack yards;
- player carries and rushing yards equal team rushing totals;
- player interceptions plus lost fumbles equal team turnovers;
- sacks taken equal team sacks allowed; and
- credited touchdowns, field goals, and automatic extra points equal the final score.

## Presentation queries

`StatisticsService` is the read-only boundary between stored game books and the Statistics Center. It supplies filterable player and team rows, category-aware sorting, derived rates, current-roster zero rows, player game logs and club splits, and completed-game lookup. The responsive screen owns only view state: season, regular-season/postseason split, club, position, category, selected player, selected game, and sort direction.

The Statistics Center exposes league leaders, team rankings, season and career player dossiers, year and club splits, weekly game logs, and complete player/team box scores. Roster rows and game-book participants link into the same player dossier, while stable player IDs keep those profiles valid through trades and releases.

## Extending the model

New simulated categories should be added at the play-result and accumulator boundary, not calculated inside a screen. Add the stat name to `StatLineData`, attribute it from a structured event, add a reconciliation or deterministic test, and let the existing game-book serialization and rollups carry it into every scope.

Records and awards can build directly on the same query boundary. They should persist immutable winners and record events rather than reconstructing historical outcomes from mutable rosters.
