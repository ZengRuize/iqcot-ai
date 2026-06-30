# E010-A5 Candidate Research Summary

Date: 2026-06-30

## Result

`MODEL_REVISED`

The smallest A5-T1/T2/T3/T4 comparison has been executed for the local derived ideal IQCOT model under the fixed external `40A -> 1A` load-current drop.

## Candidate Table

| Variant | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ/Accepted/Dropped | Burst count/limit | Hint |
|---|---:|---:|---:|---:|---|---|---|
| A5-T1 | 4.06085 | 0 | 3.61172 | 3.59863 | 149/149/0 | 4 / Inf | no improvement |
| A5-T2 | 4.06085 | 0 | 3.61172 | 3.59863 | 149/149/0 | 4 / 1 | no improvement |
| A5-T3 | 4.06085 | 0.697797 | 3.55696 | 3.53370 | 149/149/0 | 5 / 2 | partial improvement, guard fail |
| A5-T4 | 4.06085 | 0.697797 | 3.55696 | 3.53370 | 149/149/0 | 5 / 2 | proxy improvement, burst guard fail |

## Interpretation

T1/T2 do not beat the confirmed A5-C0/A5-C4 boundary. T3/T4 reduce the recovery peak while keeping the undershoot budget, REQ accounting, accepted-event phase order, current limit, and late settling guards clean, but they violate the burst-pulse guard after reentry. T4 should be read as a severe-drop state-machine proxy with reentry/burst audit, not as a complete full-token validation. The next theory revision should focus on controlled reentry and burst limiting, not on broader sweeps.

## Claim Boundary

Allowed: A5 area-hold/reentry projection has a local partial recovery benefit in the derived ideal IQCOT model.

Forbidden: A5 severe-drop validation, claiming T4 as a complete full-token pass, broad robustness, active Lambda control, active-phase shed during severe `40A -> 1A`, PIS-IEK first-peak prediction, hardware/HIL/board/silicon claims, AI direct gate control, or AI control of external load-current slew.
