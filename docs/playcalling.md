# Playcalling

Gridiron Manager's coach mode is an optional input layer over the existing seeded match simulator. A user-selected call and an automatic call enter the same `FootballSimulator.simulate_next_play` boundary, produce the same structured `PlayResult`, and flow through the same player/team statistics accumulator. The Match Center's Next Play, Simulate Drive, and Finish Game actions therefore remain valid alternatives to calling every offensive snap.

```text
JSON playbook -> PlaybookCatalog -> PlayDefinitionData
                                          |
Match Center -> PlayCallData --------------+
                                          v
                                PlayCallerService
                         recommendation / AI defense / matchup
                                          |
                                          v
                                  FootballSimulator
                                          |
                                          v
                           PlayResult -> statistics pipeline
```

## Initial call sheet

The pro-style offense contains 26 stable-ID concepts: eight runs, fourteen passes, punt and field goal units, quarterback kneel, and spike. Calls carry formation, personnel, concept, risk, tactical tags, eligible ball-carrier or target positions, outcome modifiers, variance, and clock profile. The Match Center groups them into Recommended, Run, Pass, and Special/Clock sections and supports Normal, Hurry Up, and Chew Clock tempo.

Recommendations are deterministic evaluations of down, distance, field position, quarter, clock, score, club tendencies, and recent calls. They are guidance rather than an outcome preview. Automatic offense uses the same legal play pool with seeded variation, while automatic defense chooses among base, nickel, dime, pressure, run-commit, prevent, and goal-line calls.

## Resolution rules

Calls adjust probabilities; they do not force outcomes. Player ratings, depth-chart availability, team tactics, and the game seed remain authoritative. Examples include quick concepts reducing pressure exposure, screens punishing aggressive calls, play action exploiting run commitment, power runs attacking light boxes, prevent defense limiting deep concepts, and repeated calls receiving an anticipation penalty.

Every result retains the offensive call ID, formation, personnel, concept, tempo, whether it was user selected, and the AI defensive response. That metadata appears in play-by-play and is available for future opponent scouting and coordinator analysis.

## Extension rules

Add a new offensive concept to `data/playbooks/pro_style_offense.json` rather than branching inside the Match Center. New outcome behavior belongs in `PlayCallerService` matchup tags or a focused resolver, while participant and statistic attribution remains in the existing accumulator boundary. Team-specific playbooks can later compose or filter the same stable definitions.

The first pass intentionally leaves the user's defense with its coordinator. User defensive calls, audibles, timeouts, substitutions, formation familiarity, and team-specific playbook installation can extend the same call objects without changing automatic simulation.
