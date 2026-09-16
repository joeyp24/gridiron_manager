# Trade Center

The Trade Center is a career-only personnel system. It supports multi-asset offers between the managed club and any of the other 31 clubs, including contracted players and draft picks from the next three drafts.

It also contains a living league market. The managed club can list up to eight active contracted players on its trade block. Listing a player immediately alerts interested clubs and the market re-evaluates every listed player after each completed week. Incoming proposals remain in a persistent inbox until accepted, declined, countered, invalidated by another transaction, or expired on their stated week.

## Trade window

For the 18-week league, in-season trading is available through Week 9. Trading reopens during season review, re-signing, player development, and retirement review. It closes during the playoffs, draft preparation, the live draft, and final roster decisions so draft ownership and roster rollover cannot change midway through those workflows. Legacy short-season saves use the midpoint of their regular-season calendar as the deadline.

An active user-controlled game must be completed before an offer can be submitted or a counteroffer accepted.

## AI front offices

Every club derives a current competitive direction from its record and roster strength: contender, playoff hopeful, evaluating, retooling, or rebuilding. That direction feeds a ranked needs board covering starter quality, positional depth, injuries, and age. Contenders prefer immediate upgrades; rebuilding clubs discount older targets and are more willing to shop veterans.

AI trade blocks are rebuilt from surplus depth, age, contract control, salary, and competitive direction. Franchise quarterbacks, elite players, young core talent, and prime-age contender cornerstones are protected from AI-generated movement. User-listed players are exempt from this protection because making the player available is an explicit management decision.

Generated offers pair a contracted player with up to two future picks. Packages target a narrow fair-value band and must pass the same roster, positional, ownership, contract, dead-cap, and salary-cap checks as a manually constructed deal. Pending assets cannot be promised in multiple AI offers at once.

CPU clubs can trade with each other during the same window. Rebuilding and retooling sellers are prioritized, buyers must show a real positional need, recent repeat pairings are blocked, the managed club is never included, and activity rises near the deadline. Completed CPU deals use the normal transaction and news pipeline.

## Managed trade block and offer responses

The Trade Center's market area provides four actions:

- **Add to Block** lists a player and can create up to two immediate legal offers.
- **Accept** executes the displayed proposal without a second AI evaluation because the AI club originated those exact terms.
- **Counter** loads both packages into the existing Deal Room, where any player or pick can be added or removed before the AI evaluates the revision.
- **Decline** closes the offer while retaining its status in the career's recent market history.

Removing a player from the block expires unresolved offers for that player. Completing any trade removes moved players from every block and expires other offers that contain an asset that changed hands.

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

## Persistence and extension boundary

`LeagueState.trade_blocks` stores player IDs by team. `LeagueState.trade_offers` stores `TradeOfferData` records with stable team/asset IDs, display labels, values, creation/expiration weeks, and resolution status. Save schema version fourteen initializes those fields for older careers without inventing historical offers.

`TradeMarketService` owns discovery, team direction, needs, blocks, offers, expiry, and CPU market activity. `TradeService` remains the only transaction executor. Conditional picks, retained salary, trade exceptions, no-trade clauses, and staff-controlled personnel philosophies can therefore extend the market without replacing cap or roster validation.
