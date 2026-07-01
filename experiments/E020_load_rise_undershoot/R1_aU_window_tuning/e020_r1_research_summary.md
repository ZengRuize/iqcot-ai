# E020-R1 a_U Window Tuning Research Summary

Date: 2026-07-01

## Hypothesis

The first E020 chunk confirmed early load-rise benefit from fast request plus Ton boost, but B3 did not demonstrate full `120A` recovery or `1 mV` settling. R1 tests whether a shorter or more strongly decayed Ton-boost window preserves early benefit while improving late final-error behavior.

## Baseline Audit

- baseline: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`
- exists: `1`
- solver: `VariableStepAuto`
- stop time: `0.5e-3`
- max step: `max_step_cont`
- required IQCOT blocks present: `1`
- saved during audit: `0`

## Fixed Case

`40A -> 120A` external load-current rise, fixed four phases, nominal DCR/current sensing, active Lambda disabled, active-phase add/shed disabled.

## Metrics CSV

`E:/Desktop/codex/experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv`

Additional evidence CSVs:

- variant config: `E:/Desktop/codex/experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_variant_config.csv`
- signal availability: `E:/Desktop/codex/experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_signal_availability.csv`
- scheduler audit: `E:/Desktop/codex/experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_scheduler_audit.csv`

## Metrics Table

| Variant | Success | Peak undershoot mV | Rise90 us | Final err mV | Peak current A | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---|
| R1-B0 | 1 | 397.42 | 37.996 | -376.361 | 34.0379 | 1 | carry_forward_reference |
| R1-B3 | 1 | 319.081 | 1.212 | -297.928 | 34.0934 | 1 | carry_forward_reference |
| R1-U1 | 1 | 318.801 | 1.196 | -297.766 | 33.9359 | 1 | candidate_model_confirmed |
| R1-U2 | 1 | 325.954 | 1.33 | -303.17 | 33.9858 | 1 | late_recovery_not_improved |
| R1-U3 | 1 | 346.678 | 45.018 | -328.811 | 34.1755 | 1 | early_benefit_lost |
| R1-U4 | 1 | 344.252 | 1.466 | -323.979 | 33.9258 | 1 | late_recovery_not_improved |

## Classification

`MODEL_CONFIRMED`

An R1 candidate preserved early undershoot/current-rise improvement and improved final-error or settling evidence without guard violations.

Best R1 variant: `R1-U1`.

- peak undershoot: `318.801 mV`
- 90% current-rise time: `1.196 us`
- final Vout error: `-297.766 mV`
- guard pass: `1`

The final-error improvement versus B3 is only `+0.162402 mV` toward zero, and no R1 variant settled within the `1 mV` band in the `90 us` post-step window. The confirmation is therefore a narrow local window-tuning confirmation, not a full `120A` recovery confirmation.

## Claim Boundary

Allowed local claim: in the local ideal IQCOT derived Simulink model, the selected safety-projected `a_U` load-rise token preserves the tested early undershoot/current-rise benefit and improves late final-error or settling evidence without current-limit, REQ, phase-order, or boost-window guard violations.

Forbidden claims remain: broad load-rise robustness, active Lambda validation, active-phase add/shed during this load-rise, DCR/current-sense mismatch robustness, hardware/HIL/board/silicon validation, AI direct gate control, or AI control of external load-current slew.

## Next Smallest Useful Step

Freeze the local `a_U` window-tuned claim boundary and update manuscript figures.
