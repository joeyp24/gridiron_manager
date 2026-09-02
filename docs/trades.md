# Trade Center

The Trade Center is a career-only personnel system. It supports multi-asset offers between the managed club and any of the other 31 clubs, including contracted players and draft picks from the next three drafts.

## Trade window

For the 18-week league, in-season trading is available through Week 9. Trading reopens during season review, re-signing, player development, and retirement review. It closes during the playoffs, draft preparation, the live draft, and final roster decisions so draft ownership and roster rollover cannot change midway through those workflows. Legacy short-season saves use the midpoint of their regular-season calendar as the deadline.

An active user-controlled game must be completed before an offer can be submitted or a counteroffer accepted.

## Assets and draft ownership

Every career reserves seven picks per club for each of the next three draft years. A pick retains both its original club and its current owner. When the incoming class and pick order are created, standings determine the original pick slots while Trade Center ownership determines which club actually selects at each slot.

Advancing the league year removes the completed draft's reservations and adds one new future draft year. Pick IDs and ownership are serialized, so reopening a save or revisiting draft preparation cannot regenerate an original owner over a completed trade.

## Valuation and partner decisions

Player value combines overall rating, potential, age curve, positional value, receiving-club need, contract cost and control, and current injury status. Pick value uses a round-based chart with a discount for additional future years. Each AI front office has a deterministic acceptance threshold derived from the career seed and club identity.

Offers above that threshold are accepted. Near-value offers generate a deterministic counteroffer by requesting the smallest additional legal asset that closes the gap, or by reducing the return package. Offers materially below the threshold are rejected. The same career state and package always produce the same decision.

## Validation and execution

Before submission, both clubs are projected after every outgoing and incoming asset. The deal is rejected if an asset is no longer owned, a player lacks a contract, a roster would exceed its active or offseason limit, a required position would be emptied, the minimum roster would be breached, or either projected payroll would exceed the salary cap.

Execution occurs only after the entire package passes validation. Both outgoing groups are removed before either incoming group is added, preventing a full-roster swap from failing halfway through. Player team history, depth charts, pick owners, cap ledgers, transaction feeds, news, and permanent trade history are then updated together.

The current contract model transfers annual salary, remaining term, and the unamortized portion of the contract. The sending team absorbs the modeled trade penalty as dead cap, while that amount is removed from the guarantees carried by the acquiring club. This is a deliberate first-pass approximation; signing-bonus schedules, option bonuses, retained salary, conditional picks, cash considerations, and no-trade clauses are not yet represented.
