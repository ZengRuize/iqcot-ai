# E030 C4 PIS-IEK Projected Balancer

Date: 2026-06-29

## Hypothesis

This run evaluates fixed-four-phase current sharing under one external DCR mismatch pattern at `40A`. The mismatch is a plant perturbation, not an AI action. No neural AI and no direct gate command are used.

## Model Copy Path

`E:/Desktop/codex/models/derived/E030_C4_pisiek_proj_iqcot_20260629.slx`

## Baseline Path

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

## Modified Blocks/Signals

- Replaced static load with `E030_Load_Current_Source` driven as a constant external `40A` current sink.
- DCR mismatch is injected through `SimulationInput` variables `DCR_L1..4`.
- Added zero-mean `Ton_diff` controller between `IQCOT_Ton_Adapter` and COT-cell Ton inputs.
- Added bounded `Lambda_diff` event-spacing proxy before COT-cell trigger inputs.

## External Load Profile

Constant `40A`; no AI-controlled load slew.

## Controller Variant

`C4_pis_iek_projected_balancer`

## Metrics

| Variant | Success | Max imbalance A | RMS imbalance A | Phase spacing std ns | Ripple mV | Eff. fsw Hz | Ton usage | Lambda usage | Settling us | Final Vout err mV | Clamp | Fallback | Order error |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| C4 | 1 | 0.376221 | 0.333885 | 4.12679e-10 | 16.0747 | 519118 | 0.53786 | 0 | NaN | -23.4942 | 10 | 10 | 0 |

Phase trigger CSV: `E:/Desktop/codex/experiments/E030_balance_recovery/e030_c4_pis_iek_projected_phase_triggers.csv`

## Classification

Per-run status only. Final E030 classification is assigned in `e030_research_summary.md` after C0-C4 are compared.
