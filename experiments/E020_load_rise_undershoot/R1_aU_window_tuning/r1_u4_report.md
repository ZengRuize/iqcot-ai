# E020-R1 R1-U4 a_U Window Tuning

Date: 2026-07-01

## Model Copy

`E:/Desktop/codex/models/derived/E020_R1_U4_aU_window_from_ideal_iqcot_20260701_144929.slx`

## Fixed Case

External load-current disturbance: `40A -> 120A`; fixed four phases; active Lambda and active-phase add/shed disabled.

## a_U Settings

- fast request window: `1.5 us`
- Ton boost window: `3 us`
- Ton boost max: `260 ns`
- Ton boost gain label: `1`
- decay policy: `U3_plus_late_recovery_guard`
- late recovery guard enable: `1`

## Metrics

| Variant | Success | Peak undershoot mV | Rise90 us | Final err mV | Peak current A | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---|
| R1-U4 | 1 | 344.252 | 1.466 | -323.979 | 33.9258 | 1 | pending |

## Interpretation

This per-variant report is local to the fixed R1 case. Final classification is assigned in `e020_r1_research_summary.md` after comparing U1/U2/U3/U4 against carry-forward B0/B3.
