# Coach progression and skill trees

Every career club has a persistent coach build. The user chooses purchases; AI clubs use reproducible, seed-dependent backgrounds, path preferences, and weighted spending. Exhibition teams remain neutral unless a caller explicitly provides a coach.

## Building an identity

The JSON catalog defines 40 skills across four branches and five tiers, with two paths per branch:

| Branch | Path A | Path B |
| --- | --- | --- |
| Offensive Architect | Ground Control → Play-Action Teacher → Closer | Vertical Identity → Protection Architect → Air Raid |
| Defensive Strategist | Pressure Identity → Strip Specialists → Red Wall | Shell Identity → Ball Hawks → No Fly Zone |
| Player Developer | Youth Academy → Trench School → Next Generation | Longevity Program → Workload Science → Durable Dynasty |
| Game Manager | Aggressive Identity → Halftime Adjustments → Comeback Engineer | Ball Security Identity → Special Teams School → Film Room |

Each branch begins with foundational skills that can be mixed across both paths. Tiers 2–5 require 2, 5, 8, and 12 points already invested in that branch, plus the preceding node on the path. Tier 3 identities are mutually exclusive within a branch, so their descendants remain exclusive too. Foundational nodes have three ranks, tier 2–3 nodes two, and tier 4–5 nodes one. Signature nodes cost two points; other ranks cost one. At most two signatures can be learned.

A complete specialization with all foundational ranks costs 15 points. The lifetime budget is 38, so a coach can combine two deep specializations and supporting skills but cannot acquire every branch. This creates differing play preferences, situational strengths, development approaches, and preparation options.

## XP, backgrounds, and objectives

Coaches start at level 1 with three unspent points. Each level adds one point through level 30. Cumulative XP for level L is `120 × (L − 1) + 15 × (L − 1)²`, so early levels arrive quickly and later mastery takes multiple seasons.

Game XP is awarded at the completed-game boundary in both managed and simulated games:

- Completed game: 45 XP.
- Win: 35 additional XP.
- Postseason game: 45 additional XP.
- Championship win: 150 additional XP.
- Background bonus: Offense earns 20 for scoring at least 28; Defense earns 20 for allowing at most 17; Management earns 20 for a turnover-free game.
- Offseason development: 80 XP plus 4 per improved contracted player, capped at 20 players. The Development background doubles the per-player portion.

Background choice leaves every branch available and becomes permanent after the first skill purchase. Existing careers begin with an unselected background, three points, and no invented historical XP.

Each club receives a seeded objective each season: eight wins, six games scoring 28+, six games allowing 17 or fewer, or eight turnover-free games. Completing it grants 250 XP once. Different career seeds change AI builds and objectives; future seasons refresh objectives.

Six lifetime milestones each grant one point: 10, 25, 50, and 100 wins, a postseason win, and a championship. These combine with the 32 starting/level points for the 38-point maximum. The journal retains the latest 20 rewards; separate persistent reward keys prevent replaying a recorded game or development cycle for duplicate XP.

## Gameplay effects

`CoachEffectService` compiles learned effects and applies them through existing simulation, recommendation, recovery, development, kicking, and planning paths. Effects are transient calculations and do not permanently inflate player attributes.

The interface displays exact per-rank values and learned totals. Completion, sack, interception, fumble, explosive-pass, and field-goal modifiers are additive probability points; yardage modifiers add yards to the underlying distribution. Some identities include costs: Ground Control slightly reduces pass completion, Vertical Identity increases interception risk, Pressure Identity allows more explosives, and Ball Security gives up some yardage.

Situations are explicit:

- Opening script: first four combined game drives.
- Long yardage: at least seven yards to gain.
- Red zone: offense at or beyond the opponent's 20.
- Two minute: final 120 seconds of quarters 2 and 4.
- Second half: quarter 3 or later.
- Late lead/comeback: quarter 4 or overtime with the relevant score advantage/disadvantage.
- Third/fourth down skills use the current down.

Both coaches contribute to a snap, and combined modifiers are clamped to ±1.6 yards, ±6 completion points, ±3.5 sack/explosive points, ±1.2 interception points, and ±0.6 fumble points. The applied coaching contribution is retained in the play's matchup context.

Development skills add a seeded chance of one extra growth point, or prevent one decline point. Combined chance is capped at 65%; positive growth respects player potential and age eligibility. This calculation uses its own RNG so it does not consume the original development stream. Recovery grants up to five extra energy points per weekly recovery; injury-risk reductions are bounded.

Film Room increases the weekly preparation budget from six to seven, while retaining the four-point maximum per unit. The plan service, AI allocation, validation, saved budget, and UI all use the same budget. If retraining removes the skill, a current saved plan is reduced to the valid budget. Completed historical plans retain their recorded budgets.

## Lifecycle and extension boundaries

`CoachProgressData` stores XP, background, ranks, achievements, season objective, reward keys, retraining year, and journal under `TeamData.coach`. Team cloning deep-copies it. Save schema 16 adds the field, and career loading initializes only missing coaches. Valid purchases are replayed in catalog order during load to reject unknown skills, illegal ranks, unmet prerequisites, conflicting choices, and overspending.

CareerSession is the mutation boundary for purchases, backgrounds, and retraining. Active games, active week-processing tasks, and unfinished fantasy drafts lock these mutations. Retraining refunds the build once per offseason; a confirmation explains that learned effects are removed while XP, milestones, and background remain.

The Coach Skills route shows the four branches, connected prerequisites on wide layouts, per-rank details, a build summary, point/XP progress, objectives, and reward history. Opponent coach views are read-only. The career hub exposes unspent points. Primary routing also remains accessible in the compact, scrollable sidebar.

New skills belong in `data/coaching/skill_tree.json`. Existing effect keys, scopes, filters, and situations can be composed without changing the UI. A new gameplay capability requires a matching consumer and behavioral test; do not add display-only effects.

## Verification

Run:

```powershell
godot --headless --path . --script res://tests/run_coach_skill_tests.gd
```

Coverage includes every skill path, rank/point rules, specialization conflicts, seeded AI variety, actual deterministic game differences, counter-build effects, growth limits, Film Room validation, respec cache invalidation, XP idempotence across reloads, migration, repository save/load, and responsive user/opponent UI.

For rendered previews with the normal graphics driver, run `godot --path . --script res://tools/render_coach_preview.gd`. It creates wide and compact screenshots in the ignored `test-results` directory using a fictional test club. Do not add `--headless` to that command.
