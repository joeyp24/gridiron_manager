# Weekly opponent scouting and game planning

## Player flow

Every in-season matchup has a saved plan for each participating club. The managed club can open **Weekly Game Plan** from the Career Hub or the wide-screen navigation bar before kickoff. Bye weeks intentionally have no editable plan.

The screen separates observation from decisions:

- the opponent briefing identifies film confidence, run/pass tendency, primary personnel, pressure rate, preferred coverage, and most-called concepts;
- performance cards show recent points and yards for and against;
- key threats and the current injury report come from the opponent's live roster;
- matchup notes compare the managed roster's offense, defense, receivers, and protection with the relevant opponent units;
- the preparation board selects one offensive priority, one defensive priority, and allocates up to six points between them.

Each unit must receive at least one point and can receive no more than four. Four points represent intensive work, so the player cannot maximize offense and defense in the same week. Unused points are allowed but give no benefit. A plan locks once the managed matchup starts.

## Film model

`GamePlanningService.build_report()` analyzes up to the opponent's four most recent games from the current season, excluding the week being prepared. The immutable game-book ledger retains offensive personnel, concept tags, play type, defensive rush count, pressure tags, front, coverage, and shell. These fields support:

- run/pass, quick-pass, and deep-pass rates;
- primary personnel and favorite offensive call;
- blitz rate, preferred coverage, and favorite defensive call;
- per-game scoring and yardage production.

Week-one reports have no current-season film. They begin with lower confidence and use the club's established tactical tendencies and current roster ratings. Confidence rises as observed games enter the sample.

## Priorities and effects

Offensive choices are Balanced Offense, Ground Control, Quick Game, Attack Deep, and Extra Protection. Defensive choices are Balanced Defense, Stop the Run, Limit Explosives, Pressure the QB, and Quarterback Spy.

Preparation affects two existing simulation boundaries:

1. Play recommendations and automatic coordinators receive a weight toward calls that fit the weekly priority.
2. Snap resolution receives a small, points-scaled adjustment to the relevant yardage, completion, sack, turnover, fumble, or explosive-play probability.

Effects are intentionally smaller than player-attribute matchups and normal variance. Specialized plans also retain football tradeoffs: vertical offense carries efficiency and turnover risk, pressure defense can concede explosives, and a spy commits a defender who is no longer adding to the rush.

The resolved play exposes both applied priorities in `matchup_context.game_plan`, making the effect inspectable without changing the immutable play definition.

## AI and persistence

Every AI club uses the same `WeeklyGamePlanData` contract and six-point budget. AI allocation is deterministic and considers relative unit strength, opponent run rate, deep-pass usage, pressure rate, front/secondary balance, and quarterback mobility.

Plans use a stable `season:week:matchup:team` key in `LeagueState.weekly_game_plans`. Schema version 13 persists current and historical plans; migration from version 12 creates an empty collection and plans are regenerated safely when first needed. Exhibition games remain unchanged because weekly preparation belongs to the career calendar.

## Verification

Run the focused coverage with:

```text
godot --headless --path . --script res://tests/run_game_planning_tests.gd
```

The suite covers preparation-budget validation, deterministic AI behavior, film-derived tendencies, ledger metadata, recommendation and snap modifiers, save round trips, migration, and narrow/wide responsive layouts.
