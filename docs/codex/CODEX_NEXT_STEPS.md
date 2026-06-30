# Codex Next Steps

Date: 2026-06-30

## Current State

E010 load-drop overshoot validation has already produced a `MODEL_REVISED` result. Do not restart from the old first E010 task or from `A1 Ton truncation only`.

E020 load-rise undershoot validation has produced the first `MODEL_CONFIRMED` chunk for the local peak-undershoot/current-rise mechanism. Do not restart the first `40A -> 120A` B0/B1/B2/B3 run unless the model wiring or postprocess code changes.

Current E010 evidence:

```text
40A -> 20A:
  mild load drop; fixed Ton truncation / pulse inhibit is too aggressive.
  A4 projects to no-op or very gentle protection.

40A -> 10A:
  medium load drop; A4 selected Ton truncation + one early pulse inhibit.
  recovery peak improved by about 22.2% with 0.863951 mV undershoot penalty.

40A -> 1A:
  severe load drop; current A4 is no-harm but non-improving.
  severe-drop a_O token is still missing.

120A -> 10A:
  operating-boundary check only.
  do not use it as improvement evidence yet.
```

E030 balance-recovery validation has now produced a first `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
C0 max current imbalance = 0.853665 A
C1 Ton_diff-only max current imbalance = 0.313775 A
C2 Lambda_diff-only max current imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff max current imbalance = 0.313775 A
C4 projected balancer max current imbalance = 0.376221 A
classification: MODEL_REVISED
```

C4 improves current sharing versus C0 and uses less Ton trim than C1/C3, with smaller final Vout error magnitude, but it does not beat the Ton_diff-only current-imbalance metric.

E030-R1 projection retune has now produced a second `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: R1-C0, R1-C1, R1-C4a, R1-C4b, R1-C4c, R1-C4d
summary: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md
metrics: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv
classification: MODEL_REVISED
```

Best current `a_S` candidates:

```text
R1-C4a reduced-KT projection:
  max imbalance = 0.416996 A
  Ton usage = 0.404392
  final Vout error = -3.604 mV
  ripple = 8.128 mV
  Pareto score = 0.362552

R1-C4c voltage-aware projection:
  max imbalance = 0.319450 A
  Ton usage = 0.676533
  final Vout error = -29.407 mV
  ripple = 7.121 mV
  Pareto score = 0.415946
```

R1-C4a is the best scored trade-off candidate; R1-C4c is the stronger current-sharing candidate. No R1 variant validates active Lambda control.

E030-R2 current-sense mismatch confirmation has now produced a third `MODEL_REVISED` chunk:

```text
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R2-C0, R2-C1, R2-C4a, R2-C4c
summary: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md
metrics: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
classification: MODEL_REVISED
```

Key R2 result:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C4a real max imbalance = 0.317534 A
R2-C4a sensed max imbalance = 0.195376 A
R2-C4a Ton usage = 0.401338
R2-C4a final Vout error = -7.459 mV

R2-C4c real max imbalance = 0.432627 A
R2-C4c sensed max imbalance = 0.126599 A
R2-C4c Ton usage = 0.681135
R2-C4c final Vout error = -29.616 mV
```

R2 confirms that R1-C4a/R1-C4c are not robust under current-sense gain mismatch as-is. The sensed-current objective can improve while real phase-current balance worsens. Add a current-sense-confidence or calibration-aware guard before any E040 active-phase add/shed validation.

E030-R3 calibration-aware guard has now produced a `MODEL_CONFIRMED` chunk:

```text
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R3-C0, R3-C1low, R3-C4a_conf, R3-C4a_cal, R3-C4c_cal
summary: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
metrics: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
classification: MODEL_CONFIRMED
```

Key R3 result:

```text
R3-C0 real max imbalance = 0.036272 A
real_no_harm threshold = 0.056272 A

R3-C1low real max imbalance = 0.030506 A
R3-C4a_conf real max imbalance = 0.036272 A
R3-C4a_cal real max imbalance = 0.020618 A
R3-C4c_cal real max imbalance = 0.025784 A

REQ dropped vs C0 = 0 for all R3 variants
phase order error rate = 0 for all R3 variants
```

R3 confirms the local guard principle. It does not prove broad current-sense robustness, imperfect calibration robustness, active Lambda control, active-phase add/shed benefit, or hardware/HIL/silicon behavior.

## Immediate Order

Proceed in this order:

1. Freeze current E010 and E020 findings in theory and claim boundaries.
2. Freeze E030 findings in theory and claim boundaries.
3. Treat R1-C4a/R1-C4c as local DCR-mismatch candidates, not robust fixed selectors.
4. Freeze the E030-R3 local guarded `a_S` selector.
5. Freeze E040-A-R1 as local add-phase insertion evidence; keep active Lambda disabled.
6. Freeze E040-S0 as a `MODEL_REVISED` shed-phase boundary.
7. Freeze E040-S1 staged shed-handoff as a local `MODEL_CONFIRMED` 4 -> 2 shed integrity point.
8. Do not run S1-R4, severe shed cases, active Lambda, active-phase mismatch cases, or broad 1/2/4 grids without a new protocol.
9. E010-A5-T4-R1 controlled-reentry / burst-limiter revision is complete and remains `MODEL_REVISED`; next smallest useful E010 step is reentry energy shaping, not a broad sweep.
10. Tune the E020 `a_U` window only after recording that the first B0/B1/B2/B3 chunk does not prove full 120A settling.
11. Update manuscript direction with E030-R3, E040-A-R1, E040-S0, and E040-S1 evidence before broad grids.

## E020 First Chunk Result

Completed:

```text
Load step: 40A -> 120A
Compare: B0 original ideal IQCOT, B1 fast request only, B2 Ton boost only, B3 fast request + Ton boost
Classification: MODEL_CONFIRMED

B0 peak undershoot: 397.42 mV
B1 peak undershoot: 343.79 mV
B2 peak undershoot: 382.41 mV
B3 peak undershoot: 319.08 mV

B0 90% current-rise time: 37.996 us
B3 90% current-rise time: 1.212 us
```

Boundary: E020 confirms local peak-undershoot reduction and current-rise acceleration, not full recovery. B0-B3 did not settle within the 1 mV band in the 90 us post-step window.

Do not add phase-add until E020 window tuning and E030 balance evidence are reviewed.

## E030-R2 Confirmation Result

Completed:

```text
Load: fixed 40A
Active phases: fixed 4-phase
Power-stage mismatch: none
Current-sense mismatch: [1.05, 0.95, 1.05, 0.95]
Compare: R2-C0, R2-C1, R2-C4a, R2-C4c
Classification: MODEL_REVISED
```

Boundary: E030-R2 shows a real-vs-sensed current-sharing divergence. Ton_diff and projected `a_S` can reduce the controller-observed sensed imbalance while worsening real phase-current imbalance. R2-C4a reduces trim and voltage-error cost versus aggressive R2-C1, but it still worsens real imbalance versus R2-C0. R2-C4c improves sensed imbalance most, but it also worsens real imbalance. Do not start E040 from this state.

Completed follow-up:

```text
E030-R3 calibration-aware a_S guard:
  keep fixed 40A and fixed four phases
  reuse the R2 current-sense gain pattern
  compare baseline, low-gain fallback, confidence-gated C4a, and calibrated C4a/C4c if calibration is explicitly modeled
  require real-current improvement or a no-harm real-current fallback before unblocking E040
  result: MODEL_CONFIRMED for the local ideal-calibration / confidence-gated guard principle
```

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

Mode names:

```text
C4a_cal: preferred voltage-safe calibrated mode
C4c_cal: stronger current-sharing calibrated mode under voltage/ripple guards
C1low: low-confidence fallback
C4a_conf: no-harm confidence-gated mode when sensing confidence is low
active Lambda: disabled
```

E040-A first add-phase chunk is complete:

```text
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: D0/D1/D2/D3
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
```

E040-A implementation lessons:

```text
sampled serial REQ-path supervisor can miss narrow events: reject this implementation path
two-phase mode must remap four-phase scheduler events onto active phases: do not simply drop inactive requests
active_phase_set transition alone is not evidence: phase order and voltage recovery failed
```

Next smallest useful step:

```text
E040-A-R1 completed:
  case: 20A -> 40A
  transition: 2 -> 4 active phases
  variants: R1-D0/R1-D1/R1-D2/R1-D3
  summary: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
  metrics: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
  classification: MODEL_CONFIRMED

Key R1 pass metrics:
  R1-D1/R1-D2/R1-D3 N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false
  R1-D3 a_S_enable_time = 5.5 us
```

E040-S0 minimal shed-phase run is complete:

```text
case: 40A -> 20A external load-current drop
transition: 4 active phases -> 2 active phases
variants: S0/S1/S2/S3
summary: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_research_summary.md
metrics: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_metrics.csv
classification: MODEL_REVISED
```

Key S0 outcome:

```text
S0 fixed four-phase:
  N_active_final = 4
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

E040-S0 revised the shed model. Immediate and dwell-only shed can hold two phases but produce unacceptable voltage/current-limit behavior. The residual-qualified S3 guard avoids the severe voltage/current-limit failure only by failing to remain in the two-phase state; its active set toggles back toward four-phase behavior. Do not claim shed validation.

E040-S1 staged shed-handoff run is complete:

```text
E040-S1 staged shed-handoff:
  keep 40A -> 20A
  keep initial 4 phases and target [1,3]
  variants: S1-R0/S1-R2/S1-R3
  summary: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
  metrics: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
  classification: MODEL_CONFIRMED
  keep active Lambda disabled
```

Key S1-R3 pass metrics:

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
peak_undershoot = 0.641487 mV
final_Vout_error = 1.65264 mV
```

E040-S1 confirmed the required shed state machine for one local case:

```text
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

Implementation lesson:

```text
staged load-share transfer alone is not enough;
disabled-phase drain must include per-phase zero-current gate-enable masking
to prevent synchronous low-side reverse-current sink;
commit holding must be separated from the instantaneous residual predicate.
```

Allowed local claim: S1-R3 validates only the fixed `40A -> 20A`, `4 -> [1,3]` shed-handoff integrity point in the local ideal IQCOT derived Simulink model. `S1-R4` remains unrun and requires a new protocol despite S1-R3 passing.

Still forbidden: broad active-phase robustness, arbitrary 1/2/4 scheduling, severe shed behavior, current-sense/DCR mismatch with active-phase, active Lambda, efficiency improvement, hardware/HIL/board/silicon validation.

Do not run broad active-phase grids, active Lambda, current-sense mismatch with active-phase, or severe load-rise/drop active-phase cases yet.

## Local Active-Phase Evidence Frozen After E040-A-R1 and E040-S1

Add-phase and shed-phase are not symmetric.

For `2 -> 4` add, the main issue was active-phase remap, phase insertion, and post-add order relock. E040-A first failed on phase-order integrity; E040-A-R1 confirmed the local `20A -> 40A` add integrity point.

For `4 -> 2` shed, the main issue was load-share handoff and disabled-phase current management. E040-S0 showed that immediate or dwell-only shed can be unsafe even when it reaches `N_active_final = 2`. E040-S1 confirmed that staged load-share transfer, disabled-phase drain, atomic commit, and two-phase relock are required in the local mild `40A -> 20A` case.

The current paper may claim local add/shed integrity mechanisms in the derived ideal IQCOT Simulink model only. It must not claim broad active-phase robustness, arbitrary `1/2/4` scheduling, active Lambda control, efficiency improvement, severe load-rise/drop active-phase behavior, or hardware/HIL/board/silicon validation.

## E010-A5 Candidate Comparison Completed

Completed:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/
case: 40A -> 1A external load-current drop
active phases: fixed four-phase
DCR/sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
baseline audit status: A5-C0/A5-C4 MODEL_CONFIRMED
candidate comparison status: A5-T1/T2/T3/T4 MODEL_REVISED
controlled reentry revision status: A5-T4-R1 MODEL_REVISED
```

Baseline audit result:

```text
A5-C0 original ideal IQCOT:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0

A5-C4 previous A4 no-harm selector:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0
```

A5-C4 reproduces the known severe-drop boundary: A4 is no-harm but non-improving for `40A -> 1A`. This confirms the need for A5 but does not validate A5.

Candidate comparison result:

```text
A5-T1:
  same as A5-C0/A5-C4; no improvement

A5-T2:
  same as A5-C0/A5-C4; no improvement

A5-T3:
  recovery peak 2-12us = 3.55696 mV
  recovery peak 12-40us = 3.53370 mV
  peak undershoot = 0.697797 mV
  REQ/accepted/dropped = 149/149/0
  burst count / limit = 5 / 2
  classification hint = MODEL_REVISED

A5-T4:
  same implemented conservative proxy setting and metrics as A5-T3
  classification hint = MODEL_REVISED
```

Interpretation: T3/T4 show a local recovery-peak reduction, but fail the post-reentry burst guard. T4 is a severe-drop state-machine proxy with reentry/burst audit, not a complete full-token fallback/burst-limiter validation. A5 is not confirmed.

Evidence:

```text
e010_a5_baseline_audit.md
e010_a5_baseline_metrics.csv
e010_a5_baseline_waveform_audit.md
e010_a5_baseline_reproduction_summary.md
```

E010-A5-T4-R1 controlled reentry / burst limiter completed:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/
metrics: e010_a5_t4_r1_metrics.csv
summary: e010_a5_t4_r1_research_summary.md
classification: MODEL_REVISED

R1-T4proxy:
  recovery peak 2-12us = 3.55696 mV
  recovery peak 12-40us = 3.53370 mV
  peak undershoot = 0.697797 mV
  burst count / limit = 5 / 2

R1-T4a/b/c:
  peak overshoot = 0 mV
  recovery peaks = 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  REQ/accepted/dropped = 187/187/0
  REQ reject count = 170
  burst count / limit = 5 / 2
  guard_pass = false
```

Interpretation: controlled reentry / burst limiter did not validate A5. R1-T4a/b/c suppressed positive peaks only by producing severe undershoot and final-error collapse, and the burst guard still failed. Do not claim A5 validation.

Next smallest useful step:

```text
revise reentry energy shaping and scheduler release
keep 40A -> 1A fixed four-phase severe drop
keep active Lambda disabled
keep active-phase add/shed disabled
do not add mismatch or broad load-drop grids
do not tune into a pass without a new hypothesis
```

## Standing Guardrails

- AI does not control external load slew.
- AI does not command high-side or low-side gates.
- IQCOT remains the deterministic fast pulse/event generator.
- Baseline `.slx` is never modified directly.
- Derived models must be created through MATLAB/Simulink APIs.
- Every derived model must have a hypothesis, metrics CSV, Markdown report, and classification.
- Simulink-only evidence must not be described as hardware, HIL, board-level, or silicon validation.
