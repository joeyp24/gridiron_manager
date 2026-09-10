# 2D Play Presentation

The Match Center includes an optional top-down presentation for individual simulated plays. It is a deterministic visual replay of the match engine's completed `PlayResult`; it does not use movement or physics to decide the outcome. Scores, statistics, fatigue, injuries, and playcalling therefore remain identical whether presentation is enabled, skipped, paused, replayed, or disabled.

## Flow

```text
FootballSimulator -> PlayResult -> PlayAnimationComposer -> PlayAnimationData -> FieldVisual
```

`PlayAnimationComposer` reads the actual offensive and defensive participant IDs recorded by Attribute Simulation v2. It combines them with formation, personnel, call concept, starting field position, yardage, target, ball carrier, tacklers, turnovers, and scoring flags. Special-teams calls add the actual kicker or punter and fill the remaining visual unit from available roster players.

The resulting transient `PlayAnimationData` contains:

- stable team and player identities;
- 11 offensive and 11 defensive actor tracks;
- normalized field-space keyframes;
- a football trajectory and visibility window;
- field direction, line of scrimmage, and line to gain;
- duration, result marker, and presentation colors.

No animation state is added to career saves or immutable game books. A completed play can always be reconstructed from its result and participating teams.

## Match Center behavior

`Next Play` and individual coach-mode calls start presentation automatically. `Simulate Drive` and `Finish Game` remain immediate fast-forward paths. While an individual replay is active, actions that could resolve another snap are disabled so the visual cannot become detached from the current result.

The playback strip supports:

- presentation on/off;
- pause and resume;
- replay without resimulation;
- skip to the completed frame; and
- 0.5x, 1x, 1.5x, and 2x playback.

The field camera follows the result area and adjusts its visible yard range for short gains, deep passes, punts, field goals, and goal-line plays. Player markers scale with field height, secondary labels collapse when space is limited, and the wider Match Center legend hides on narrow displays.

## Extension path

The normalized tracks are intentionally independent of the drawing implementation. Future versions can add authored route libraries, motion, blocking engagements, player-specific speed, weather, crowds, sound, celebrations, sprite or skeletal actors, defensive calls, and alternate camera modes without moving outcome calculation into the presentation layer.

`tests/run_play_presentation_tests.gd` covers 22-player composition, player identity, bounded paths, deterministic timelines, special teams, ball trajectories, pause/speed/skip/replay behavior, Match Center locking, presentation opt-out, and responsive layouts.
