# Latest Summary

Date: 2026-06-30

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
| PIS-IEK | E030/E030-R1 DCR chunks `MODEL_REVISED`; E030-R2 `MODEL_REVISED`; E030-R3 guard `MODEL_CONFIRMED`; local guarded `a_S` selector frozen | use frozen selector only after add/reentry in E040-A |
| Load-drop `a_O` | partially validated; `40A -> 1A` remains no-harm but non-improving under A4 | design E010-A5 severe-drop token before new simulation |
| Load-rise `a_U` | first E020 chunk `MODEL_CONFIRMED` for peak undershoot/current rise only | tune a_U window; do not claim full 120A recovery |
| `a_S` balance | guarded/calibrated selector validated locally in R3 and frozen for E040-A | do not claim active Lambda |
| `a_N` active phase | E040-A first chunk `MODEL_REVISED`; E040-A-R1 local add insertion `MODEL_CONFIRMED`; E040-S0 minimal shed `MODEL_REVISED`; E040-S1 staged shed handoff `MODEL_CONFIRMED` for one local 4 -> 2 point | frozen as local add/shed integrity evidence; do not run S1-R4 or broad grids without a new protocol |
| Manuscript | Markdown draft synced through E040-S1 local shed-handoff confirmation | convert current Markdown draft into LaTeX plan/figures after claim and citation scaffolding |

## Current Phase

```text
theory reconstruction + minimal validation
```

PIS-IEK small-signal evidence now has local DCR-mismatch support, a current-sense mismatch warning, and a first confirmed sensing-aware guard. Bidirectional large-signal theory has initial validation on both load-drop and load-rise branches. E010 remains `MODEL_REVISED`; E020 is `MODEL_CONFIRMED` for the limited peak-undershoot/current-rise mechanism; E030/E030-R1/E030-R2 remain `MODEL_REVISED`; E030-R3 is `MODEL_CONFIRMED` for one local confidence/calibration guard pattern. E040-A first add-phase validation was `MODEL_REVISED`, E040-A-R1 is `MODEL_CONFIRMED` for one local phase-insertion/relock integrity point, E040-S0 is `MODEL_REVISED` for the first minimal 4 -> 2 shed attempt, and E040-S1 is `MODEL_CONFIRMED` for one local staged 4 -> [1,3] shed-handoff integrity point.

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

Frozen local guarded `a_S` selector after E030-R3:

```text
if sense_confidence == LOW:
    use no-op or low-gain Ton_diff fallback
elif calibration_enable == true and voltage/ripple risk is high:
    use calibrated C4a
elif calibration_enable == true and current imbalance dominates:
    allow calibrated C4c under voltage/ripple guards
else:
    fallback
```

`C4a_cal` is the preferred voltage-safe calibrated mode. `C4c_cal` is the stronger current-sharing calibrated mode under voltage/ripple guards. `C1low` is the low-confidence fallback. `C4a_conf` is the no-harm confidence-gated mode when sensing confidence is low. Active Lambda remains disabled.

E040-A active-phase add first chunk is complete:

```text
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: D0/D1/D2/D3
metrics: experiments/E040_active_phase_add_shed/e040_metrics.csv
summary: experiments/E040_active_phase_add_shed/e040_research_summary.md
classification: MODEL_REVISED

D1:
  N_active_final = 4
  dropped_REQ_count = 0
  phase_order_error_rate = 0.120482
  peak undershoot = 802.746 mV
  final Vout error = -269.941 mV

D2/D3:
  N_active_final = 4
  dropped_REQ_count = 0
  phase_order_error_rate = 0.170732
  peak undershoot = 810.494 mV
  final Vout error = -319.350 mV
  Ton_trim_usage = 0.216193
```

E040-A revised the active-phase theory. The add transition can be represented without REQ drop after request remapping, but the tested insertion/ramp/a_S recovery still violates phase-order integrity and leaves large voltage error. Do not claim active-phase benefit, and do not start E040-S until E040-A is retuned.

E040-A-R1 phase-insertion retune is complete:

```text
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: R1-D0/R1-D1/R1-D2/R1-D3
metrics: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
summary: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
classification: MODEL_CONFIRMED

R1-D1/R1-D2/R1-D3:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false

R1-D3:
  a_S_enable_time = 5.5 us
  Ton_trim_usage = 0.204702
```

Boundary: R1 confirms only the local corrected-remap/insertion/relock add-phase integrity point in the ideal derived Simulink model. It does not validate E040-S shed, broad 1/2/4 active-phase scheduling, active Lambda, severe 40A -> 120A recovery, efficiency gain, hardware, HIL, board-level, or silicon behavior.

E040-S0 minimal shed-phase validation is complete:

```text
case: 40A -> 20A external load-current drop
transition: 4 active phases -> 2 active phases
variants: S0/S1/S2/S3
metrics: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_metrics.csv
summary: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_research_summary.md
classification: MODEL_REVISED

S0 fixed four-phase:
  N_active_final = 4
  peak overshoot = 1.132 mV
  peak undershoot = 0.451 mV
  final Vout error = 0.699 mV

S1 immediate shed:
  N_active_final = 2
  peak undershoot = 663.614 mV
  final Vout error = -624.357 mV
  current_limit_hit = true

S2 dwell/lockout shed:
  N_active_final = 2
  peak undershoot = 543.833 mV
  final Vout error = -500.714 mV
  current_limit_hit = true
  phase_order_error_rate_post_shed = 0.265152

S3 residual/relock/a_S guarded shed:
  N_active_final = 3.79065
  peak undershoot = 19.133 mV
  final Vout error = -3.371 mV
  current_limit_hit = false
  phase_order_error_rate_post_shed = 0.992308
```

Boundary: E040-S0 rejects the simple shed model. Immediate or dwell-only 4 -> 2 shed creates unacceptable undershoot/current-limit behavior, while the residual-qualified S3 guard avoids the worst voltage/current-limit failure only by failing to hold a stable two-phase state. Shed-phase theory now needs a staged load-share handoff and disabled-phase drain model before S4, broad 1/2/4 scheduling, or any shed benefit claim.

E040-S1 staged shed-handoff validation is complete:

```text
folder: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/
case: 40A -> 20A external load-current drop
transition: 4 active phases -> 2 active phases [1,3]
variants: S1-R0/S1-R2/S1-R3
metrics: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
summary: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
classification: MODEL_CONFIRMED

state machine:
  NORMAL_4PH
  SHED_REQUESTED
  LOAD_SHARE_TRANSFER
  DISABLED_PHASE_DRAIN
  SHED_COMMIT_ARMED
  SHED_COMMIT
  ORDER_RELOCK_2PH
  POST_SHED_RECOVERY
  NORMAL_2PH
  FALLBACK_4PH
```

Key S1-R3 result:

```text
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

The S1 implementation confirms that shed handoff needs staged load-share transfer away from phases `[2,4]`, disabled-phase drain, per-phase zero-current gate-enable masking, atomic commit to `[1,0,1,0]`, exact post-commit `N_active == 2`, and post-commit relock to physical sequence `[1,3]`. Active Lambda remained disabled and post-shed `a_S` was not enabled in S1-R3.

Boundary: this is one local ideal-derived Simulink shed-handoff integrity point, not broad active-phase robustness. Do not run S1-R4, severe shed cases, active Lambda, current-sense/DCR mismatch with active-phase, or broad active-phase grids without a new smallest-useful protocol.

## Local Active-Phase Evidence Freeze

After E040-A-R1 and E040-S1, active-phase add and shed are frozen as local integrity mechanisms only:

```text
2 -> 4 add:
  E040-A first failed on phase-order integrity
  E040-A-R1 confirmed local add remap/insertion/relock under 20A -> 40A

4 -> 2 shed:
  E040-S0 showed immediate/dwell-only shed can be unsafe
  E040-S1 confirmed staged load-share transfer, disabled-phase drain,
  atomic commit, and two-phase relock under 40A -> 20A
```

The current paper may claim local add/shed integrity in the derived ideal IQCOT Simulink model only. It must not claim broad active-phase robustness, arbitrary `1/2/4` scheduling, active Lambda control, efficiency improvement, severe active-phase load-rise/drop performance, or hardware/HIL/board/silicon validation.

## E010-A5 Severe-Drop Token Design Status

E010-A5 is now the next design target:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/
case: 40A -> 1A external load-current drop
active phases: fixed four-phase
DCR/sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
status: DESIGN_ONLY until future metrics exist
```

The severe-drop token should not be mixed with active-phase shedding. The first severe-drop peak is a large-signal excess-current / excess-energy effect; PIS-IEK may only be used after protection/reentry for conservative balance recovery.
