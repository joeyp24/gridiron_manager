# Fantasy Draft Mode

Fantasy Draft is an optional new-career path that rebuilds the entire league before Week 1. It is deliberately separate from the annual rookie draft: the launch draft operates on active NFL players and existing free agents, while `DraftService` continues to own future rookie classes and offseason picks.

## Career flow

1. The career screen records either `Standard` or `Fantasy Draft` as the career mode.
2. `LeagueSimulator` creates the normal 32-team league, 272-game schedule, standings, statistics state, contracts, and future draft capital.
3. `FantasyDraftService.initialize` moves all 2,035 unique active-database players into one pool, empties club rosters, randomizes the 32-team order from the career seed, and creates 1,696 pick records.
4. The war room can begin a live draft, accept a user selection, auto-pick for the user, or simulate the remainder. AI picks automatically advance until the managed club is back on the clock.
5. After pick 1,696, each team rebuilds its depth chart and ratings, the remaining 339 players become unrestricted free agents, and the unchanged season opens at Week 1.

The top-level career navigation stays locked during an incomplete launch draft so match, roster, and transaction systems never receive partial rosters. Save & Exit remains available at every stage.

## Snake order and determinism

The first-round order is a seeded Fisher-Yates shuffle of stable team IDs. Odd rounds follow that order and even rounds reverse it. The saved state stores the seed, fixed order, full pick list, selected-player snapshots, and current pick index. Rebuilding a career with the same seed produces the same order; loading a save resumes the exact clock and pool rather than regenerating either.

AI variation is deterministic. Its small per-player noise component derives from the draft seed, overall pick, team ID, and player ID, so draft outcomes can be reproduced in automated checks.

## AI selection board

AI clubs rank legal available players using:

- overall and remaining potential;
- age and expected career runway;
- positional value and current depth shortage;
- offensive run/pass tendency and defensive coverage preference;
- existing contract cost;
- a small deterministic club-and-pick preference adjustment.

The same base board is exposed to the user, with search and position filters. The dossier shows overall, potential, contract, archetype, measurements, top detailed Madden attributes, and whether the selected player fits the managed club's current roster/cap plan. Full player profiles remain available from the war room.

## Roster and cap safeguards

`TARGET_DEPTH` describes the intended 53-player shape, while `MAXIMUM_DEPTH` prevents one club from consuming unreasonable quantities at a position. Selection validation also:

- preserves one player at every required position for each club that still lacks one;
- forces missing positions when the remaining roster slots require it;
- blocks selections after a position maximum or 53-player limit;
- carries existing contracts with drafted players;
- creates a normal initial contract when an unsigned free agent is drafted;
- reserves $1 million for every remaining roster slot so early star contracts cannot make the roster impossible to complete.

Finalization uses the existing `RosterValidator` as the authoritative check boundary. Undrafted players have contracts cleared before entering the normal free-agent market.

## Persistence and tests

Save schema version 11 adds `career_mode` and optional `fantasy_draft` fields. Version-ten and earlier careers migrate to standard mode with no fabricated draft progress. Player ownership remains represented by team rosters and the shared available pool, avoiding a second source of truth.

`tests/run_fantasy_draft_tests.gd` verifies seeded order, snake reversal, manual selection, AI advancement, JSON save/resume, all 1,696 selections, 32 legal 53-player rosters, cap/depth-chart validity, the 339-player free-agent result, player identity preservation, schedule continuity, and standard-career compatibility. Responsive war-room coverage lives in `tests/run_ui_tests.gd`.

## Extension points

The persisted pick ledger can support draft recap, roster-grade, and historical draft views without changing player ownership. Future improvements can add a user queue, favorites, board export, tradeable launch picks, position-run alerts, AI strategy profiles, draft speed controls, and an optional post-draft contract normalization rule behind the existing service boundary.
