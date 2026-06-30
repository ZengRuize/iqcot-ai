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
7. E040-S1 staged shed-handoff design package is complete; next step is only a smallest implementation/preflight, not S4 or broad E040 grids.
8. Add or design a severe-drop `a_O` token for `40A -> 1A`.
9. Tune the E020 `a_U` window only after recording that the first B0/B1/B2/B3 chunk does not prove full 120A settling.
10. Update manuscript direction with E030-R3, E040-A-R1, and E040-S0 evidence before broad grids.

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

Next smallest useful E040-S step:

```text
E040-S1 staged shed-handoff design only:
  keep 40A -> 20A
  keep initial 4 phases and target [1,3]
  no S4, no severe cases, no broad grids
  add explicit load-share transfer / disabled-phase drain / shed commit state
  keep active Lambda disabled
```

Completed design package:

```text
folder: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/
status: DESIGN_ONLY
no simulation results claimed

artifacts:
  e040_s1_hypothesis.md
  e040_s1_protocol.md
  e040_s1_state_machine.md
  e040_s1_scheduler_audit.md
  e040_s1_metrics_template.csv
  e040_s1_research_summary.md
```

E040-S1 design freezes the required shed state machine:

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

Future E040-S1 implementation must prove atomic commit to `[1,0,1,0]`, exact `N_active == 2`, no dropped/inactive accepted REQ, zero post-shed order error, no current-limit hit, and residual-current pass before enabling conservative post-shed `a_S`. `S1-R4` remains blocked until `S1-R3` passes.

Do not run broad active-phase grids, active Lambda, current-sense mismatch with active-phase, or severe load-rise/drop active-phase cases yet.

## Standing Guardrails

- AI does not control external load slew.
- AI does not command high-side or low-side gates.
- IQCOT remains the deterministic fast pulse/event generator.
- Baseline `.slx` is never modified directly.
- Derived models must be created through MATLAB/Simulink APIs.
- Every derived model must have a hypothesis, metrics CSV, Markdown report, and classification.
- Simulink-only evidence must not be described as hardware, HIL, board-level, or silicon validation.
