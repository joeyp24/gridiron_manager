# Attribute Simulation v2

Attribute Simulation v2 resolves every scrimmage snap as a set of player matchups instead of comparing only team or summary overalls. It is shared by manually called plays, Next Play, Simulate Drive, Finish Game, and AI-versus-AI games, so coach mode remains optional.

## Snap pipeline

```text
PlayDefinitionData + DefensiveCallData
                 |
                 v
       PersonnelPackageService
      actual offensive/defensive 11
                 |
                 v
       AttributeMatchupService
 blocking/front, rush/protection,
 accuracy/coverage/catch, tackle,
 ball security, kick and punt grades
                 |
                 v
          FootballSimulator
 seeded probability + play modifiers
                 |
                 v
 PlayResult.matchup_context + statistics
```

`PersonnelPackageService` maps the call sheet's 10, 11, 12, 21, and 22 labels to real depth-chart personnel. The defensive call selects Base, Nickel, Dime, or Goal Line. Standard rosters field exactly eleven available players; depleted custom rosters use the best available substitutes. Starter IDs remain stable for games-started attribution while participant IDs now represent the package that actually played the snap.

## Direct attributes

The matchup service uses the complete hybrid player profile and applies the player's current fatigue penalty before producing a grade. The principal inputs are:

- Runs: run-block technique and style, impact/lead blocking, strength, block shedding, recognition, pursuit, vision, acceleration, agility, change of direction, break tackle, power moves, tackling, carrying, and hit power.
- Passes: pass-block styles, rush moves, pocket movement, pressure response, depth-specific accuracy, throw power, play action, depth-specific route running, release, man/zone coverage, press, catching traits, athletic separation, and tackling after the catch.
- Special teams: kick accuracy and power directly control field-goal, extra-point, punt-distance, and directional-placement probabilities.

Power, zone, outside, quick, screen, intermediate, deep, play-action, max-protect, and coverage tags change which skills matter or continue to contribute their existing concept modifiers. A heavy offensive package creates more run blockers; lighter defensive packages exchange front players for defensive backs. The engine keeps a small team-quality term on rushing outcomes while the actual players dominate matchup resolution.

Every `PlayResult` includes a transient `matchup_context` dictionary with the component grades, chosen participants, calculated chances, personnel, and model ID. The Match Center continues to use the result description, now naming the players and the pocket, lane, or coverage condition that shaped the outcome. Completed-game persistence remains based on stable box-score data, so no career-save migration is required.

## Balancing

Probability and yardage coefficients live in `data/simulation/attribute_tuning.json`, separate from the resolver code. Changes to that file must preserve seeded determinism and pass the calibration checks. Those checks hold summary overall values constant, change only the detailed attributes, and verify meaningful rushing, completion, and field-goal separation across repeated identical seeds. The broader regression suites still verify legal games, statistical reconciliation, full-league seasons, saves, UI flows, and long-running career behavior.

New modeled traits should be combined into a named matchup grade in `AttributeMatchupService`; new constants belong in the tuning file. The UI and statistics accumulator should consume the structured result rather than recalculate football outcomes.
