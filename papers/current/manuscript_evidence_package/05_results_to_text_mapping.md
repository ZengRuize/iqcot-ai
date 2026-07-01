# Results-To-Text Mapping

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

## E020 B0 vs B3 Peak Undershoot

Numerical result:

```text
B0 peak undershoot = 397.42 mV
B3 peak undershoot = 319.08 mV
```

Allowed manuscript sentence:

```text
In the local derived ideal IQCOT model, fast request plus bounded Ton boost reduces the tested `40A -> 120A` peak undershoot relative to the original IQCOT reference.
```

Forbidden manuscript sentence:

```text
IQCOT cannot respond to load-rise transients without AI.
```

Source:

```text
experiments/E020_load_rise_undershoot/e020_metrics.csv
experiments/E020_load_rise_undershoot/e020_research_summary.md
```

## E020 B0 vs B3 Rise90

Numerical result:

```text
B0 rise90 = 37.996 us
B3 rise90 = 1.212 us
```

Allowed manuscript sentence:

```text
The B3 supervisory token accelerates the local 90% current-rise metric while keeping current-limit and event-integrity guards clean.
```

Forbidden manuscript sentence:

```text
B3 proves complete `120A` recovery.
```

Source:

```text
experiments/E020_load_rise_undershoot/e020_metrics.csv
```

## E020-R1 R1-U1 Peak Undershoot

Numerical result:

```text
R1-U1 peak undershoot = 318.801 mV
```

Allowed manuscript sentence:

```text
The window-tuned `a_U` candidate R1-U1 slightly refines the B3 early load-rise result while preserving guard compliance.
```

Forbidden manuscript sentence:

```text
R1-U1 solves full `120A` recovery.
```

Source:

```text
experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv
experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_research_summary.md
```

## E020-R1 R1-U1 Final Error

Numerical result:

```text
R1-U1 final Vout error = -297.766 mV
B3 final Vout error = -297.928 mV
```

Allowed manuscript sentence:

```text
R1-U1 gives only a small late final-error improvement relative to B3, so the late `120A` recovery mechanism remains unresolved.
```

Forbidden manuscript sentence:

```text
R1-U1 demonstrates `1 mV` settling.
```

Source:

```text
experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv
```

## E010-A5 Severe-Drop Boundary

Numerical result:

```text
E010-A5 classification = MODEL_REVISED
no safe A5 candidate carried forward
```

Allowed manuscript sentence:

```text
The severe `40A -> 1A` branch is retained as boundary evidence showing that the tested projected scheduling tokens do not safely solve this excess-energy case.
```

Forbidden manuscript sentence:

```text
A5 solves severe `40A -> 1A` load-drop overshoot.
```

Source:

```text
experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_revision_synthesis.md
```

## E030-R3 C4a_cal / C4c_cal Real Imbalance

Numerical result:

```text
R3-C4a_cal real max current imbalance = 0.020618 A
R3-C4c_cal real max current imbalance = 0.025784 A
REQ dropped = 0
phase order error = 0
```

Allowed manuscript sentence:

```text
Under one current-sense gain mismatch pattern with ideal calibration, the calibration-aware `a_S` projection improves real phase-current balance without REQ or phase-order failures.
```

Forbidden manuscript sentence:

```text
The method proves broad mismatch robustness or validates active Lambda control.
```

Source:

```text
experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
```

## E040-A-R1 Phase-Order Integrity

Numerical result:

```text
R1-D1/R1-D2/R1-D3:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false
```

Allowed manuscript sentence:

```text
The corrected add-phase remap/insertion/relock sequence preserves local add-event integrity for the tested `20A -> 40A`, `2 -> 4` case.
```

Forbidden manuscript sentence:

```text
Add-phase scheduling proves severe load-rise recovery or efficiency improvement.
```

Source:

```text
experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
```

## E040-S1 Staged Shed Handoff Result

Numerical result:

```text
S1-R3:
  N_active_final = 2
  actual_active_phase_set_final = 1010
  shed_commit_count = 1
  fallback_4ph_count = 0
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_shed = 0
  current_limit_hit = false
  residual_current_check = pass
  peak undershoot = 0.641487 mV
  final Vout error = 1.65264 mV
```

Allowed manuscript sentence:

```text
The staged shed-handoff state machine locally confirms `4 -> [1,3]` event integrity for the tested mild `40A -> 20A` load-drop case.
```

Forbidden manuscript sentence:

```text
The active-phase supervisor proves arbitrary `1/2/4` scheduling or efficiency gain.
```

Source:

```text
experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
```
