# Roster Management

Roster Management adds distinct club and league ownership lists without changing the stable player-ID boundary used by simulation, statistics, trades, and saves.

## Roster states

Every `PlayerData` has one explicit `roster_status`:

- `Active Roster` is one of the 48 game-day players on a club's 53-man roster.
- `Game-Day Inactive` remains on the 53-man roster and under contract but cannot participate in a game.
- `Injured Reserve` remains under contract and owned by its club outside the 53-man count.
- `Practice Squad` remains under a one-year reserve contract and owned by its club outside the 53-man count.
- `Waivers` is temporarily league-owned while existing contract terms and submitted claims are retained.
- `Free Agent` is unowned and has no active contract.

`TeamData.players` intentionally remains the 53-man/offseason roster used by trades, depth charts, and the match engine. `injured_reserve` and `practice_squad` are separate team-owned collections. `LeagueState.waiver_wire` owns pending `WaiverEntryData`; `LeagueState.player_by_id`, `team_for_player`, and `all_players` search every pool.

## Rules and cap behavior

`LeagueFormatData` makes the important values configurable. The full league uses a 53-player regular roster, 48-player game-day list, 16-player practice squad, six veteran practice-squad allowances, a four-week IR minimum, and a one-week waiver period. Legacy eight-team careers retain smaller compatible defaults.

IR contracts continue counting against payroll. Practice-squad contracts also count against payroll. A promotion replaces the reserve contract with an appropriate active contract, and a poaching club must have both an open 53-man spot and enough cap room. In-season releases add contractual dead money immediately but keep the existing player contract attached until the player is claimed or clears. A claim winner inherits that contract; an unclaimed player enters free agency without it.

## Weekly lifecycle

At the end of every completed in-season week, `CareerSession` runs `RosterTransactionService.run_ai_roster_management` before calendar advancement. It advances IR recovery, protects multi-week AI injuries, returns eligible AI players when space exists, promotes reserve depth, submits need-based deterministic AI claims, resolves expired waiver entries in reverse-standings priority, fills AI development squads, and rebuilds legal AI game-day lists. Standard AI free-agent upgrades remain a separate service.

When the offseason opens, unresolved waivers are forced to completion and IR players return to the expanded offseason roster. Post-draft cutdowns may move eligible AI depth players to the practice squad before releasing them. Veteran allowances are rebalanced as player experience changes. Starting a new season resets health and constructs a legal game-day list without changing user depth-chart ownership.

## User interface

The responsive Roster Management screen has five tabs:

1. Depth Chart changes positional priority and links to player profiles.
2. 53-Man Roster controls game-day status, IR placement, offseason practice-squad assignments, and releases/waivers.
3. Injured Reserve shows recovery and return eligibility with activation controls.
4. Practice Squad supports promotion, release, free-agent reserve signings, and poaching from other clubs.
5. Waiver Wire shows former club, inherited salary, deadline, claim count, club priority, and submit/withdraw controls.

Summary cards reflow with window width, row actions wrap, detailed attributes collapse at narrow sizes, and the tab strip remains horizontally scrollable. Every successful action emits the existing roster-save signal.

## Persistence and tests

Save schema version 12 serializes player statuses, status-change and IR-return weeks, both team reserve lists, configurable limits, pending waiver players, claims, and the waiver sequence. The version-11 migration infers active/inactive status from the prior `is_active` field and creates empty reserve lists and waiver state.

`tests/run_roster_transaction_tests.gd` covers initial 53/48 legality, manual activation limits, IR contract and minimum-stay behavior, practice-squad signing and promotion, in-season waivers, claim save/resume and resolution, AI IR/practice-squad management, cap/limit legality, and global ownership uniqueness. Responsive screen coverage lives in `tests/run_ui_tests.gd`.
