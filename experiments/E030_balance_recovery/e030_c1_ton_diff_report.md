# E030 C1 Ton-Diff Only

Date: 2026-06-29

## Hypothesis

This run evaluates fixed-four-phase current sharing under one external DCR mismatch pattern at `40A`. The mismatch is a plant perturbation, not an AI action. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_C1_tondiff_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Modified Blocks/Signals

- Replaced static load with `E030_Load_Current_Source` driven as a constant external `40A` current sink.
- DCR mismatch is injected through `SimulationInput` variables `DCR_L1..4`.
- Added zero-mean `Ton_diff` controller between `IQCOT_Ton_Adapter` and COT-cell Ton inputs.

## External Load Profile

Constant `40A`; no AI-controlled load slew.

## Controller Variant

`C1_ton_diff_only`

## Metrics

| Variant | Success | Max imbalance A | RMS imbalance A | Phase spacing std ns | Ripple mV | Eff. fsw Hz | Ton usage | Lambda usage | Settling us | Final Vout err mV | Clamp | Fallback | Order error |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C1 | 1 | 0.313775 | 0.265364 | 4.12679e-10 | 15.2173 | 519118 | 0.865969 | 0 | NaN | -58.1561 | 0 | 0 | 0 |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/e030_c1_ton_diff_phase_triggers.csv`

## Classification

Per-run status only. Final E030 classification is assigned in `e030_research_summary.md` after C0-C4 are compared.
