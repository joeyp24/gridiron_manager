# Playcalling

Gridiron Manager's coach mode is an optional input layer over the existing seeded match simulator. User-selected and automatic offensive or defensive calls enter the same `FootballSimulator.simulate_next_play` boundary, produce the same structured `PlayResult`, and flow through the same player/team statistics accumulator. The Match Center's Next Play, Simulate Drive, and Finish Game actions therefore remain valid alternatives to calling every snap.

```text
Offense JSON -> PlaybookCatalog -> PlayDefinitionData ----+
Defensive JSON -> PlaybookCatalog -> DefensiveCallData ---+
Match Center -> selected offense or defense --------------+
                                                           v
                                                PlayCallerService
                                      recommendations / AI calls / matchup
                                                           |
                                                           v
                                                   FootballSimulator
                                                           |
                                                           v
                                     PlayResult -> stats / game book / replay
```

## Initial call sheet

The pro-style offense contains 26 stable-ID concepts: eight runs, fourteen passes, punt and field goal units, quarterback kneel, and spike. Calls carry formation, personnel, concept, risk, tactical tags, eligible ball-carrier or target positions, outcome modifiers, variance, and clock profile. The Match Center groups them into Recommended, Run, Pass, and Special/Clock sections and supports Normal, Hurry Up, and Chew Clock tempo.

Recommendations are deterministic evaluations of down, distance, field position, quarter, clock, score, club tendencies, and recent calls. They are guidance rather than an outcome preview. Automatic offense and defense use the same legal pools exposed to the player with seeded variation.

## Defensive call sheet

When the opponent has possession, the Match Center switches to a defensive call sheet. Its 18 stable-ID calls are loaded from `data/playbooks/multiple_defense.json` and grouped into Base, Nickel, Dime, Goal Line, and Prevent. The initial catalog includes Cover 0, Cover 1, Cover 2, Tampa 2, Cover 3, Quarters, Cover 6, fire-zone pressure, simulated pressure, run commitment, pass commitment, a quarterback spy, and prevent defense.

Every call defines the on-field personnel, front, coverage type, coverage shell, number of rushers, risk, descriptive tags, and focused run, completion, passing-yard, sack, interception, fumble, and explosive-play modifiers. Situational recommendations account for the opponent's run tendency and recent mix, down and distance, field position, score and clock, quarterback mobility, the managed defense's coverage preference and blitz rate, and repeated-call predictability.

Submitting defense lets the opposing AI coordinator select its offensive response, then resolves both choices together. `PlayResult` retains the chosen front, personnel, coverage, shell, and user-selection flag. The compact play-call ledger in `GameBookData` makes those decisions available after the game without coupling season statistics to the Match Center.

## Resolution rules

Calls adjust probabilities; they do not force outcomes. Each call first fields its actual 10, 11, 12, 21, or 22 offensive package against the defense's Base, Nickel, Dime, Goal Line, or Prevent unit. The selected rush count now determines the actual pressure group used by the attribute matchup rather than acting as display-only metadata. Attribute Simulation v2 then compares detailed blockers against the front, rushers against protection, depth-specific quarterback accuracy against coverage, routes and hands against defenders, ball security against contact, and kickers or punters against the requested distance. Fatigue is applied to those detailed grades. Team tactics, concept modifiers, and the game seed remain authoritative alongside those matchups.

Examples include quick concepts reducing pressure exposure, screens punishing aggressive calls, play action exploiting run commitment, quarterback spies containing option runs, power runs and heavy personnel attacking light boxes, prevent defense limiting deep concepts while conceding underneath completions, max protection adding eligible blockers, and either coordinator becoming predictable when repeating calls. Results retain their component matchup grades and calculated probabilities for play-by-play, testing, and future analysis.

Every result retains the offensive call ID, formation, personnel, concept, tempo, whether it was user selected, and the full defensive call context. That metadata appears in play-by-play and drives the presentation's pre-snap alignment, red pressure tracks, blue coverage drops, gold spy path, and pursuit behavior.

## Extension rules

Add a new offensive concept to `data/playbooks/pro_style_offense.json` or a defensive call to `data/playbooks/multiple_defense.json` rather than branching inside the Match Center. New outcome behavior belongs in `PlayCallerService` matchup tags or a focused resolver, while participant and statistic attribution remains in the existing accumulator boundary. Team-specific playbooks can later compose or filter the same stable definitions.

Audibles, timeouts, individual matchup assignments, substitutions, formation familiarity, and team-specific playbook installation can extend the same call objects without changing automatic simulation.

See [`simulation_v2.md`](simulation_v2.md) for the package mappings, direct attribute groups, balancing configuration, and calibration rules.
