# Simulation Loading Flow

Week simulation and postgame league processing use the same incremental application workflow. The presentation layer advances one bounded unit of work per rendered frame, allowing Godot to redraw the interface and report real progress instead of showing a frozen window or an artificial timer.

## Workflow

`CareerSession.start_week_simulation()` creates a transient `WeekSimulationTask` for a fully simulated week. `start_postgame_simulation()` creates the same task after a managed game, excluding that completed matchup from the remaining league slate. The task advances through:

1. weekly preparation or managed-game recording;
2. one unplayed matchup at a time;
3. news and AI roster operations;
4. standings, playoff, and calendar finalization; and
5. career saving in the UI coordinator.

The existing `simulate_current_week()` and `complete_user_game()` commands remain available as synchronous wrappers. Headless tests and future non-visual consumers therefore use the same rules without depending on UI frames.

## Presentation

`SimulationLoadingOverlay` is a reusable, modal shell component. It blocks route changes while in-memory league state is partially advanced and shows the current matchup, detailed stage, actual completed-work percentage, animated activity indicator, and save completion. Its card contracts on narrow windows and remains capped on wide displays.

The Main shell owns the overlay rather than any individual route, so changing from the Career Hub to future simulation-heavy screens does not require rebuilding the component. New long operations can use `begin_operation()`, `update_progress()`, and `finish_operation()` while keeping their domain work outside the UI layer.

Career data is saved only after the task reaches its finalized state. Closing the application during an unfinished operation leaves the previous complete save intact rather than persisting a partially played week.

## Verification

`tests/run_simulation_loading_tests.gd` verifies monotonic progress, one-game-per-step execution, deterministic equivalence with the synchronous API, managed-game completion, transient-state cleanup, modal behavior, and narrow/wide responsive sizing.
