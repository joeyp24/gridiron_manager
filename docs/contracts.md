# Contracts and salary-cap accounting

Gridiron Manager stores contracts as multi-year financial schedules. A player's displayed APY is a market-value summary; the club's payroll and available cap room use the cap charge assigned to the active league year.

## Contract fields

Each `PlayerContract` carries:

- `annual_salary`: average per year (APY), used for market comparisons and offer evaluation.
- `total_contract_value` and `total_guaranteed`: full deal summaries.
- `yearly_cap_hits`: the amount charged to the club in each league year.
- `yearly_cash`: the amount paid to the player in each league year.
- `yearly_release_penalties` and `yearly_trade_penalties`: year-specific dead-cap outcomes.
- `signed_year`, `expires_after_year`, `years_remaining`, role, contract type, and source provenance.

UI screens show APY and the current cap hit separately. Team payroll, roster validation, trades, waivers, promotions, rookie signings, and free-agent signings all use the applicable year's cap hit.

## Current league data

The committed 2026 league pack combines stable nflverse player identifiers with current public contract totals and club cap tables from Over The Cap. The import preserves sourced player amounts; it never shrinks every contract to force a roster under the cap.

Because the packaged Madden roster and live contract table can represent different transaction dates, unmatched players retain an explicitly labeled historical or roster-snapshot estimate. When that snapshot combination exceeds a live adjusted club cap, the importer creates a one-season reconciliation adjustment plus a small practice-squad/waiver operating reserve. That adjustment is not carried into later league years.

The official 2026 base cap is $301.2 million. Each team separately stores its base cap, current-year adjustment, effective cap, and cap year. `data/leagues/contract_refresh_report.json` records match coverage and payroll totals for audit and review.

Refresh the committed data with:

```powershell
python tools/contract_data_importer.py --download
```

The command downloads the nflverse player identity map and current Over The Cap contract/team pages, rebuilds the schedules, validates core invariants, and writes both the league pack and audit report. To reproduce a previously downloaded snapshot without network access, omit `--download`. Use `--snapshot-date YYYY-MM-DD` when recording a specific source date.

## Generated contracts

AI free-agent offers, user signings, extensions, rookie deals, and practice-squad deals all go through `PlayerContract.generated_contract`. Generated deals use:

- a stable APY rather than treating the first-year cap charge as the whole contract;
- a progressive annual cap schedule whose rounded yearly values reconcile to total contract value;
- guarantees tied to deal quality and role;
- declining release and trade penalties as guaranteed value is earned;
- explicit start and expiration seasons.

Offer validation projects the cap hit for the first season of the proposed deal. Future extension years are evaluated against their actual scheduled charge rather than the player's current-season charge.

## League-year rollover

At the start of a new league year, every contract advances to the new season. Expired deals leave the roster and enter free agency; active deals retain their remaining schedules. The league base cap grows by the configured annual rate, while the prior snapshot-only adjustment is removed. New AI deals therefore continue to use the same schedule-aware accounting in every later season.

## Save compatibility

Save schema version 15 adds the yearly schedules and team cap metadata. Older saves migrate automatically: their flat salary becomes a level cap/cash schedule for the remaining term, existing guarantees are preserved, and their effective team cap is split into base and adjustment fields. This preserves old careers while all newly created contracts use the richer model.
