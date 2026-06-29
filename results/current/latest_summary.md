# Latest Summary

Date: 2026-06-29

## Current Direction

The active research direction is:

```text
Bidirectional large-signal voltage regulation
+ PIS-IEK small-signal current-sharing / phase-recovery model
+ active-phase add/shed hybrid event management
+ AI/table supervisor with safety projection
```

External load-current slew is an observed disturbance descriptor, not an AI-controlled action.

## Baseline

All future validation starts from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline exists locally and must not be modified directly.

## Worktree Reorganization

Current theory now lives under `docs/theory/`. Current validation protocol now lives under `docs/validation/`. Codex operating rules now live under `docs/codex/`.

Legacy documents were mirrored under `legacy/2026-06-legacy-docs/`. Untracked R049 temporary outputs were moved under `results/archive/2026-06-r049-untracked-output/`. Old paper drafts were moved under `papers/archive/2026-06-legacy-paper/`.

## Validation Status

E001 baseline wiring audit is complete:

```text
experiments/E001_baseline_audit/e001_baseline_wiring_audit.md
```

Result: the ideal IQCOT baseline behavior is usable as A0/B0/C0/D0 reference evidence, but E010 derived models must add observability for `Iload`, `Ton_actual_i`, and `active_phase_set`.

E010 load-drop evidence has been expanded:

```text
cases: 40A -> 20A, 40A -> 10A, 40A -> 1A
boundary check: 120A -> 10A
summary: experiments/E010_load_drop_overshoot/e010_research_summary.md
table: results/current/e010_research_table.csv
classification: MODEL_REVISED
```

Key metrics:

```text
A0 original:
  peak overshoot = 2.37866 mV
  recovery peak 2-12us = 2.36936 mV

A1 Ton truncation only:
  peak overshoot = 2.41604 mV
  recovery peak 2-12us = 2.14559 mV
  recovery delta vs A0 = -9.44%
  undershoot penalty = 0 mV

A2 Ton truncation + one early pulse inhibit:
  peak overshoot = 2.35886 mV
  recovery peak 2-12us = 1.84342 mV
  recovery delta vs A0 = -22.2%
  undershoot penalty = 0.863951 mV

A3 guarded reentry with reentry_band_down = 1.2 mV:
  pulse inhibit rejected by projection
  recovery peak 2-12us = 2.14559 mV
  undershoot penalty = 0 mV

A4 table-selected a_O under 1 mV undershoot budget:
  selected A2-like action
  recovery peak 2-12us = 1.84342 mV
  undershoot penalty = 0.863951 mV

40A -> 20A:
  fixed protection is too aggressive
  A2 undershoot penalty = 8.51044 mV
  A4 selects no-op
  A4 recovery peak 2-12us = A0 recovery peak 2-12us = 1.09036 mV

40A -> 1A:
  A4 is no-harm but non-improving under the current guard
  A0/A4 recovery peak 2-12us = 3.61172 mV

120A -> 10A:
  treated as operating-boundary evidence, not improvement evidence
```

Theory revision:

```text
Ton truncation is a partial residual-energy correction.
Pulse inhibit changes the first accepted reentry event and gives the main
medium-drop recovery-peak reduction, but it requires a binding voltage/undershoot
safety projection and a load-drop magnitude selector.
```

## Module Status

| Module | Status | Next action |
|---|---|---|
| PIS-IEK | E030/E030-R1 DCR chunks `MODEL_REVISED`; E030-R2 `MODEL_REVISED`; E030-R3 guard `MODEL_CONFIRMED` | freeze guarded `a_S` selector before E040 |
| Load-drop `a_O` | partially validated | add severe-drop token |
| Load-rise `a_U` | first E020 chunk `MODEL_CONFIRMED` for peak undershoot/current rise only | tune a_U window; do not claim full 120A recovery |
| `a_S` balance | guarded/calibrated selector validated locally in R3 | freeze selector; do not claim active Lambda |
| `a_N` active phase | planned but not yet validated | prepare E040 only after selector freeze |
| Manuscript | Markdown draft synced through E020 | convert to LaTeX after E030 evidence |

## Current Phase

```text
theory reconstruction + minimal validation
```

PIS-IEK small-signal evidence now has local DCR-mismatch support, a current-sense mismatch warning, and a first confirmed sensing-aware guard. Bidirectional large-signal theory has initial validation on both load-drop and load-rise branches. E010 remains `MODEL_REVISED`; E020 is `MODEL_CONFIRMED` for the limited peak-undershoot/current-rise mechanism; E030/E030-R1/E030-R2 remain `MODEL_REVISED`; E030-R3 is `MODEL_CONFIRMED` for one local confidence/calibration guard pattern. E040 active-phase validation is still not evidence; it should be prepared only after the local `a_S` selector is frozen.

E020 load-rise first chunk is complete:

```text
case: 40A -> 120A external load-current rise
variants: B0/B1/B2/B3
metrics: experiments/E020_load_rise_undershoot/e020_metrics.csv
summary: experiments/E020_load_rise_undershoot/e020_research_summary.md
classification: MODEL_CONFIRMED

B0 peak undershoot = 397.42 mV
B1 fast request only = 343.79 mV
B2 Ton boost only = 382.41 mV
B3 fast request + Ton boost = 319.08 mV

B0 90% current-rise time = 37.996 us
B3 90% current-rise time = 1.212 us
B3 phase-current peak = 34.09 A/phase, current guard not hit
```

Boundary: this confirms the local `a_U` mechanism for peak-undershoot reduction and current-rise acceleration, not full 120A recovery. None of B0-B3 settled within the 1 mV band in the simulated 90 us post-step window, and B3 final error remained about `-297.93 mV`.

E030 balance-recovery first chunk is complete:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: C0/C1/C2/C3/C4
metrics: experiments/E030_balance_recovery/e030_metrics.csv
summary: experiments/E030_balance_recovery/e030_research_summary.md
classification: MODEL_REVISED

C0 max current imbalance = 0.853665 A
C1 Ton_diff-only max current imbalance = 0.313775 A
C2 Lambda_diff-only max current imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff max current imbalance = 0.313775 A
C4 PIS-IEK projected balancer max current imbalance = 0.376221 A

C1/C3 Ton usage = 0.865969, final Vout error = -58.156 mV
C4 Ton usage = 0.53786, final Vout error = -23.494 mV
```

Boundary: E030 supports `Ton_diff` as the dominant local DC current-sharing actuator and shows that C4 trades some balance improvement for lower trim usage and smaller final voltage error. It does not prove robust mismatch recovery or active Lambda_diff control. The first serial sampled Lambda implementation was rejected because it dropped narrow REQ pulses; the retained Lambda path is side-band projection/logging with fallback.

E030-R1 projection retune is complete:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: R1-C0/R1-C1/R1-C4a/R1-C4b/R1-C4c/R1-C4d
metrics: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv
summary: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md
classification: MODEL_REVISED

R1-C0 max current imbalance = 0.853665 A
R1-C1 Ton_diff reference max current imbalance = 0.313749 A
R1-C1 Ton usage = 0.866649, final Vout error = -58.188 mV, ripple = 15.311 mV

R1-C4a reduced-KT projection:
  max current imbalance = 0.416996 A
  Ton usage = 0.404392
  final Vout error = -3.604 mV
  ripple = 8.128 mV
  Pareto score = 0.362552

R1-C4c voltage-aware projection:
  max current imbalance = 0.319450 A
  Ton usage = 0.676533
  final Vout error = -29.407 mV
  ripple = 7.121 mV
  Pareto score = 0.415946

REQ dropped vs C0 = 0 for all R1 variants
phase order error rate = 0 for all R1 variants
```

Boundary: R1-C4a is the best local Pareto candidate and R1-C4c is the stronger current-sharing candidate, but the result remains `MODEL_REVISED`. It does not prove broad mismatch robustness, active Lambda control, active-phase add/shed, neural AI control, hardware, HIL, board-level, or silicon behavior.

E030-R2 current-sense mismatch confirmation is complete:

```text
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R2-C0/R2-C1/R2-C4a/R2-C4c
metrics: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
summary: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md
classification: MODEL_REVISED

R2-C0 real max current imbalance = 0.036272 A
R2-C0 sensed max current imbalance = 0.538006 A

R2-C1 real max current imbalance = 0.475724 A
R2-C1 sensed max current imbalance = 0.141896 A
R2-C1 Ton usage = 0.871935
R2-C1 final Vout error = -58.868 mV

R2-C4a real max current imbalance = 0.317534 A
R2-C4a sensed max current imbalance = 0.195376 A
R2-C4a Ton usage = 0.401338
R2-C4a final Vout error = -7.459 mV

R2-C4c real max current imbalance = 0.432627 A
R2-C4c sensed max current imbalance = 0.126599 A
R2-C4c Ton usage = 0.681135
R2-C4c final Vout error = -29.616 mV

REQ dropped vs C0 = 0 for all R2 variants
phase order error rate = 0 for all R2 variants
```

Boundary: R2 confirms that current-sense gain mismatch can make the controller-observed sensed-current objective diverge from real phase-current balance. R1-C4a reduces the over-correction cost versus aggressive Ton_diff-only, but still worsens real current imbalance versus R2-C0. R1-C4c improves sensed imbalance most, but also worsens real current imbalance. `a_S` therefore needs a current-sense-confidence or calibration-aware projection guard before E040.

E030-R3 calibration-aware guard is complete:

```text
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R3-C0/R3-C1low/R3-C4a_conf/R3-C4a_cal/R3-C4c_cal
metrics: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
summary: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
classification: MODEL_CONFIRMED

R3-C0 real max current imbalance = 0.036272 A
R3-C0 sensed max current imbalance = 0.538006 A
real_no_harm threshold = 0.056272 A

R3-C1low real max current imbalance = 0.030506 A
R3-C1low sensed max current imbalance = 0.522300 A

R3-C4a_conf real max current imbalance = 0.036272 A
R3-C4a_conf sensed max current imbalance = 0.538006 A

R3-C4a_cal real max current imbalance = 0.020618 A
R3-C4a_cal sensed max current imbalance = 0.523013 A

R3-C4c_cal real max current imbalance = 0.025784 A
R3-C4c_cal sensed max current imbalance = 0.527296 A

REQ dropped vs C0 = 0 for all R3 variants
phase order error rate = 0 for all R3 variants
```

Boundary: R3 confirms the local guard principle under one gain-mismatch pattern. `R3-C4a_cal` and `R3-C4c_cal` use ideal calibration with `g_hat_i = g_i`; this does not prove imperfect calibration robustness or practical online calibration. R3 still does not validate active Lambda, active-phase add/shed, neural AI control, hardware, HIL, board-level, or silicon behavior.

Next task: freeze the local guarded `a_S` selector in the validation protocol, then prepare E040 active-phase add/shed validation with active Lambda still disabled.
