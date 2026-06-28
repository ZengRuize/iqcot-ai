# E010 Research Summary

Date: 2026-06-28

## Scope

This summary aggregates available E010 load-drop validation evidence. All Simulink models are derived copies of the local ideal IQCOT baseline. Load-current profiles are external disturbances, not AI commands.

## A4 vs A0 on Interpretable 40A Initial-Load Cases

| Case | A0 recovery mV | A4 recovery mV | A4 recovery improvement | A4 undershoot penalty mV | A4 pulse inhibit events |
|---|---:|---:|---:|---:|---:|
| 40A_to_10A | 2.36936 | 1.84342 | 22.2% | 0.863951 | 1 |
| 40A_to_1A | 3.61172 | 3.61172 | 0% | 0 | 0 |
| 40A_to_20A | 1.09036 | 1.09036 | 0% | 0.45125 | 0 |

## Key Interpretation

- `40A_to_20A`: fixed Ton truncation and pulse inhibit are too aggressive; A4 selects no-op and preserves baseline behavior.
- `40A_to_10A`: A4 selects Ton truncation plus one early pulse inhibit, reducing the recovery peak from `2.36936 mV` to `1.84342 mV` with `0.863951 mV` undershoot penalty.
- `40A_to_1A`: A4 remains no-harm under the current guard but does not improve recovery, indicating that the trigger-window/reentry policy needs another token level before claiming severe-drop optimality.
- `120A_to_10A`: the A0 run shows a high-load operating-boundary issue in the present derived model setup and must not be used as load-drop improvement evidence yet.

## Evidence Table

CSV: `E:/Desktop/codex/results/current/e010_research_table.csv`

## Classification

`MODEL_REVISED`: the evidence supports a load-drop magnitude selector in `a_O`. Mild load drops should project to no-op or gentler protection; medium drops can use Ton truncation plus one early pulse inhibit under an undershoot budget; severe drops require an additional projected token level before broad claims.
