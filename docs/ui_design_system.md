# UI design system

Gridiron Manager uses a centralized, code-defined Godot theme and a small UI factory so new management systems can inherit the same visual language without copying screen-specific styling. The design is inspired by modern football front-office software: information-dense, calm, dark, club-aware, and usable at a wide range of desktop window sizes.

## Application shell

The shell in `scripts/ui/main.gd` owns navigation and route context. Its left rail groups the product into System, Club, Performance, and Front Office workspaces. The active route is persistent and visually distinct. The top header reports the current section alongside season, week, club, and record context.

The shell has three responsive states:

- At 1,160 pixels and above, the navigation rail is 238 pixels wide and displays complete route and brand labels.
- From 760 through 1,159 pixels, the rail is 78 pixels wide and uses short route labels with full tooltips.
- Below 760 pixels, the rail is 66 pixels wide, outer margins tighten, and lower-priority header context is hidden.

Route content must remain scrollable and may not assume a fixed viewport. Individual screens use their own content breakpoints to turn multi-column boards into one-column flows.

## Visual tokens

`scripts/ui/theme/gridiron_theme.gd` is the single source of truth for the neutral palette, semantic colors, typography, spacing surfaces, buttons, form controls, scrollbars, progress bars, and focus treatment. Club colors can identify a team or data point, but they should not replace semantic colors for success, warning, destructive, or selected states.

The surface hierarchy is:

1. Background and sidebar for the application canvas.
2. Card panels for normal workspace regions.
3. Raised cards for interactive or selected regions.
4. Hero panels for the most important decision or summary on a page.
5. Inset panels for rows, notes, and secondary information.

Primary buttons advance the workflow. Secondary buttons select or open an adjacent workflow. Ghost buttons are low-emphasis navigation. Danger buttons are reserved for releases and other destructive decisions. Every factory-created button participates in keyboard focus navigation.

## Reusable composition

`scripts/ui/components/ui_factory.gd` provides constructors for labels, buttons, cards, layout containers, badges, status pills, page headings, marked section headings, metric cards, empty states, dividers, and stat bars. Prefer these helpers before adding another local component.

A normal route screen should use this order:

1. Page heading with a short functional kicker and one-sentence purpose.
2. Optional hero or metric summary.
3. View navigation and filters.
4. Marked section headings above major data regions.
5. One clear primary action, with adjacent actions at secondary or ghost emphasis.

Keep status in pills, team or position identity in solid badges, and numeric summaries in metric cards. Empty views should explain what is absent and what changes it, rather than leaving a blank card.

## Extending the interface

New screens should emit intent and call application services rather than mutate simulation or domain state directly. Register primary routes in the shell only when they represent a durable workspace; contextual details belong inside the owning screen. Preserve the existing compact and wide checks in `tests/run_ui_tests.gd`, and add assertions for every new responsive grid or navigation state.

The shell uses a short fade-and-slide transition when changing routes. Avoid additional full-screen transitions inside screens. Loading that represents real simulation work belongs in `SimulationLoadingOverlay`, so animation never disguises an incomplete state update.
