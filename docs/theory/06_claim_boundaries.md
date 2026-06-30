# Claim Boundaries

## Allowed Claims

The current project may claim, after corresponding validation:

- Simulink-derived ideal IQCOT baseline behavior;
- bidirectional load-step regulation improvements in derived ideal models;
- event-domain PIS-IEK explanation of current sharing and phase recovery;
- safety-projected supervisory scheduling of low-dimensional IQCOT parameters;
- active-phase add/shed behavior in derived Simulink validation.

## Forbidden Claims

Do not claim:

- AI directly controls gate commands;
- AI controls external load-current slew rate;
- load-current profile is an actuator;
- Simulink-only evidence is hardware, silicon, board-level, or HIL validation;
- a result from a derived model is baseline behavior unless A0/B0/C0/D0 confirms it;
- current sharing, efficiency, or active-phase robustness without mismatch evidence.

## Evidence Labels

Every experiment report must classify the result as one of:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

Use `MODEL_CONFIRMED` only when the metric movement supports the written model and the wiring audit is clean.

Use `MODEL_REVISED` when the simulation is valid but the theory needs an update.

Use `IMPLEMENTATION_ISSUE` when missing logging, incorrect wiring, solver setup, copied-model errors, or projection bugs prevent theoretical interpretation.

Use `CLAIM_DOWNGRADED` when evidence is valid but weaker than the intended claim.

## Update Rule

After each simulation chunk, update evidence before expanding the grid. Theory documents may be revised only with explicit reference to the experiment, derived model, metrics CSV, and report path.

## Current E010 Evidence Boundary

Validated so far:

```text
experiment: E010 load-drop overshoot
cases: 40A -> 20A, 40A -> 10A, 40A -> 1A external load-current steps
operating-boundary check: 120A -> 10A
variants: A0-A4 where available
summary: experiments/E010_load_drop_overshoot/e010_research_summary.md
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, the table-selected load-drop a_O token
acts as a magnitude selector plus safety projection: it preserves no-op behavior
for the mild 40A -> 20A case, selects Ton truncation plus one early pulse inhibit
for the medium 40A -> 10A case and reduces the 2-12us recovery peak by about
22.2% versus A0 with a bounded 0.863951 mV undershoot penalty, and remains
no-harm but non-improving for the severe 40A -> 1A case under the present guard.
```

Not yet allowed:

- generalization to all E010 load-drop cases;
- claims at 120A initial load until the high-load operating boundary is resolved;
- severe `40A -> 1A` improvement claim until E010-A5 is implemented and validated;
- load-rise undershoot recovery claims;
- current-sharing or phase-recovery claims under mismatch;
- active-phase add/shed claims;
- hardware, HIL, or board-level claims.

## E010-A5 Severe-Drop Design Boundary

The severe `40A -> 1A` load-drop case remains unresolved:

```text
current status: A4 no-harm but non-improving
new design target: E010-A5 severe-drop a_O token
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/
status: DESIGN_ONLY until a future derived-model run produces metrics
```

Allowed at this stage:

- define the severe-drop token, state machine, metrics, waveform audit, and future pass/fail criteria;
- describe why severe load-drop is a large-signal excess-current / excess-energy branch;
- state that PIS-IEK may only be used after protection/reentry for conservative balance recovery.

Forbidden at this stage:

- claiming A5 improves peak overshoot or recovery peak;
- claiming A5 solves severe `40A -> 1A` until CSV metrics and a Markdown report exist;
- mixing severe-drop A5 with active-phase shedding;
- using Simulink-only future evidence as hardware/HIL/board/silicon validation.

## Current E020 Evidence Boundary

Validated so far:

```text
experiment: E020 load-rise undershoot
case: 40A -> 120A external load-current step
variants: B0, B1, B2, B3
summary: experiments/E020_load_rise_undershoot/e020_research_summary.md
metrics: experiments/E020_load_rise_undershoot/e020_metrics.csv
classification: MODEL_CONFIRMED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, the projected load-rise a_U branch can
reduce peak undershoot and accelerate current rise for the severe 40A -> 120A
external load-current rise. Fast request is the dominant first lever; Ton boost
is weak alone but improves the result when combined with fast request.
```

Quantitative local evidence:

```text
B0 peak undershoot = 397.42 mV
B1 fast request only peak undershoot = 343.79 mV
B2 Ton boost only peak undershoot = 382.41 mV
B3 fast request + Ton boost peak undershoot = 319.08 mV

B0 90% current-rise time = 37.996 us
B3 90% current-rise time = 1.212 us
B3 phase-current peak = 34.09 A/phase
current-limit guard = not hit
```

Not yet allowed from E020:

- full `40A -> 120A` recovery or final-regulation claim;
- settling-time claim, because no tested variant settled within the `1 mV` band in the `90 us` post-step window;
- 120A operating-boundary claim, because B3 final error remained about `-297.93 mV` at `75-90 us`;
- phase-add benefit claim, because B4/B5 were not run;
- global load-rise generalization beyond this first derived-Simulink chunk.

## Current E030 Evidence Boundary

Validated so far:

```text
experiment: E030 balance recovery
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: C0, C1, C2, C3, C4
summary: experiments/E030_balance_recovery/e030_research_summary.md
metrics: experiments/E030_balance_recovery/e030_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, zero-mean Ton_diff is the dominant
small-signal DC current-sharing actuator for the tested DCR-mismatch case.
The C4 PIS-IEK projected balancer improves max current imbalance versus C0
while using less Ton trim and producing a smaller final Vout error magnitude
than the aggressive Ton_diff-only C1/C3 variants.
```

Quantitative local evidence:

```text
C0 max current imbalance = 0.853665 A
C1 Ton_diff-only max current imbalance = 0.313775 A
C2 Lambda_diff-only max current imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff max current imbalance = 0.313775 A
C4 projected balancer max current imbalance = 0.376221 A

C1/C3 Ton trim usage = 0.865969
C4 Ton trim usage = 0.53786

C1/C3 final Vout error = -58.156 mV
C4 final Vout error = -23.494 mV
```

Not yet allowed from E030:

- robust current-sharing claims across all mismatch families;
- claim that C4 is globally better than Ton_diff-only, because C1/C3 give the lowest current imbalance in this first chunk;
- claim that Lambda_diff is an active DC current-sharing actuator;
- claim that sampled serial REQ-path Lambda control is valid, because that implementation dropped narrow pulses and was revised to side-band projection/logging;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R1 Evidence Boundary

Validated so far:

```text
experiment: E030-R1 projection retune
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: R1-C0, R1-C1, R1-C4a, R1-C4b, R1-C4c, R1-C4d
summary: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md
metrics: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model and one specified +/-10% DCR mismatch
pattern, retuned safety-projected a_S control can trade current-sharing strength
against lower Ton trim usage, smaller final Vout error, and bounded ripple/event
cost. R1-C4a is the best scored Pareto candidate in this chunk; R1-C4c is a
stronger balance candidate with higher trim and final-error cost than R1-C4a.
```

Quantitative local evidence:

```text
R1-C0 max current imbalance = 0.853665 A
R1-C1 Ton_diff reference max current imbalance = 0.313749 A
R1-C4a reduced-KT projection max current imbalance = 0.416996 A
R1-C4c voltage-aware projection max current imbalance = 0.319450 A

R1-C1 Ton trim usage = 0.866649, final Vout error = -58.188 mV, ripple = 15.311 mV
R1-C4a Ton trim usage = 0.404392, final Vout error = -3.604 mV, ripple = 8.128 mV
R1-C4c Ton trim usage = 0.676533, final Vout error = -29.407 mV, ripple = 7.121 mV

REQ dropped vs C0 = 0 for all R1 variants
phase order error rate = 0 for all R1 variants
```

Not yet allowed from E030-R1:

- broad mismatch robustness beyond the specified DCR pattern;
- claim that C4a or C4c globally outperforms Ton_diff-only on current sharing;
- active Lambda_diff closed-loop claims, because R1 keeps Lambda side-band/logging only;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R2 Evidence Boundary

Validated so far:

```text
experiment: E030-R2 current-sense gain mismatch
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R2-C0, R2-C1, R2-C4a, R2-C4c
summary: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md
metrics: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, current-sense gain mismatch can create
a real-vs-sensed current-sharing divergence. Ton_diff and projected a_S actions
can reduce controller-observed sensed imbalance while increasing real phase-current
imbalance. Therefore a_S must include a current-sense-confidence or
calibration-aware guard before active-phase validation.
```

Quantitative local evidence:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C1 real max imbalance = 0.475724 A
R2-C1 sensed max imbalance = 0.141896 A
R2-C1 Ton usage = 0.871935

R2-C4a real max imbalance = 0.317534 A
R2-C4a sensed max imbalance = 0.195376 A
R2-C4a Ton usage = 0.401338
R2-C4a final Vout error = -7.459 mV

R2-C4c real max imbalance = 0.432627 A
R2-C4c sensed max imbalance = 0.126599 A
R2-C4c Ton usage = 0.681135
R2-C4c final Vout error = -29.616 mV

REQ dropped vs C0 = 0 for all R2 variants
phase order error rate = 0 for all R2 variants
```

Not yet allowed from E030-R2:

- claim that R1-C4a/R1-C4c are robust under current-sense gain mismatch;
- proceed-to-E040 claim before adding a sensing-confidence or calibration-aware guard;
- broad mismatch robustness;
- active Lambda_diff closed-loop claims;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R3 Evidence Boundary

Validated so far:

```text
experiment: E030-R3 calibration-aware a_S guard
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R3-C0, R3-C1low, R3-C4a_conf, R3-C4a_cal, R3-C4c_cal
summary: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
metrics: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
classification: MODEL_CONFIRMED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model and one specified current-sense
gain mismatch pattern, a confidence-gated or ideal-calibrated a_S projection
can prevent sensed-current optimization from harming real phase-current balance.
This supports requiring a sensing-aware safety projection before active-phase
scheduling.
```

Quantitative local evidence:

```text
R3-C0 real max imbalance = 0.036272 A
R3-C0 sensed max imbalance = 0.538006 A
real_no_harm threshold = 0.056272 A

R3-C1low real max imbalance = 0.030506 A
R3-C1low sensed max imbalance = 0.522300 A
R3-C1low real_no_harm = true

R3-C4a_conf real max imbalance = 0.036272 A
R3-C4a_conf sensed max imbalance = 0.538006 A
R3-C4a_conf real_no_harm = true

R3-C4a_cal real max imbalance = 0.020618 A
R3-C4a_cal sensed max imbalance = 0.523013 A
R3-C4a_cal real_no_harm = true

R3-C4c_cal real max imbalance = 0.025784 A
R3-C4c_cal sensed max imbalance = 0.527296 A
R3-C4c_cal real_no_harm = true

REQ dropped vs C0 = 0 for all R3 variants
phase order error rate = 0 for all R3 variants
```

Boundary details:

- `R3-C4a_cal` and `R3-C4c_cal` use ideal calibration with `g_hat_i = g_i`; this is not evidence of practical online calibration accuracy.
- `R3-C4a_conf` validates the low-confidence no-op guard behavior, not a current-sharing improvement.
- `R3-C1low` validates a conservative fallback under the tested mismatch pattern.

Not yet allowed from E030-R3:

- broad current-sense robustness beyond the tested gain pattern;
- imperfect calibration robustness;
- active Lambda_diff closed-loop claims;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims;
- global superiority over Ton_diff-only.

## Frozen Local Guarded a_S Selector After E030-R3

The only `a_S` selector frozen for follow-on validation is:

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

Interpretation:

- `C4a_cal` is the preferred voltage-safe calibrated mode.
- `C4c_cal` is the stronger current-sharing calibrated mode, but only under voltage/ripple/event guards.
- `C1low` is the low-confidence fallback mode.
- `C4a_conf` is the no-harm confidence-gated mode when sensing confidence is low.
- Active Lambda remains disabled.

Additional forbidden claims from R3:

- E030-R3 does not prove broad robustness.
- E030-R3 does not prove imperfect calibration robustness.
- E030-R3 does not validate active Lambda control.
- E030-R3 does not validate active-phase add/shed.
- E030-R3 is derived-Simulink evidence only.

## Current E040 Boundary

E040 active-phase validation has local add and shed integrity evidence after E040-A-R1 and E040-S1, but it is not broad active-phase robustness. The local guarded `a_S` selector remains frozen and active Lambda remains disabled. Do not expand E040 until a new smallest-useful protocol is written for the next specific question.

## Local Active-Phase Evidence After E040-A-R1 and E040-S1

The current paper may claim only local add/shed integrity mechanisms in the derived ideal IQCOT Simulink model.

Allowed:

- E040-A-R1 supports a local `2 -> 4` add-phase transition claim under `20A -> 40A`;
- E040-S1 supports a local `4 -> 2` shed-phase handoff claim under `40A -> 20A`;
- both claims are derived-Simulink local evidence only.

Add-phase and shed-phase are not symmetric:

- for add, the main issue was active-phase remap, phase insertion, and post-add order relock;
- for shed, the main issue was load-share handoff and disabled-phase current management;
- E040-S0 remains important negative evidence because shed cannot be treated as the inverse of add;
- immediate or dwell-only shed can cause severe undershoot/current-limit failure even when `N_active_final = 2`;
- E040-S1 confirms that staged load-share transfer, disabled-phase drain, atomic commit, and two-phase relock are required for the tested mild shed case.

Forbidden:

- broad active-phase robustness;
- arbitrary 1/2/4 scheduling;
- active Lambda control;
- active-phase robustness under DCR/current-sense mismatch;
- severe load-rise/drop active-phase performance;
- global efficiency improvement;
- hardware, HIL, board-level, or silicon validation.

First E040-A result:

```text
experiment: experiments/E040_active_phase_add_shed/
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: D0/D1/D2/D3
metrics: experiments/E040_active_phase_add_shed/e040_metrics.csv
summary: experiments/E040_active_phase_add_shed/e040_research_summary.md
classification: MODEL_REVISED
```

Allowed local claim from E040-A:

```text
In the local ideal IQCOT derived model, a request-remapped active-phase add proxy
can change the active set from two phases to four phases without REQ drop or
current-limit hit in the moderate 20A -> 40A case, but the tested D1/D2/D3
variants still violate phase-order integrity and exhibit large undershoot/final
voltage error. The active-phase theory must therefore be revised before any
active-phase benefit or shed-phase claim is allowed.
```

Quantitative local evidence:

```text
D1: N_active_final = 4, dropped_REQ_count = 0, phase_order_error_rate = 0.120482,
    peak undershoot = 802.746 mV, final Vout error = -269.941 mV
D2/D3: N_active_final = 4, dropped_REQ_count = 0, phase_order_error_rate = 0.170732,
       peak undershoot = 810.494 mV, final Vout error = -319.350 mV
```

Not yet allowed from E040-A:

- active-phase add benefit claim;
- active-phase shed validation or E040-S claim;
- broad 1/2/4 phase scheduling robustness;
- phase-order-safe insertion claim;
- voltage-recovery improvement claim;
- active Lambda control claim;
- hardware, HIL, board-level, or silicon claim.

These restrictions are standing:

- AI/table may observe load-step features but must not control external load-current slew.
- AI/table must not command gates.
- Current Simulink evidence is not hardware, HIL, board-level, or silicon evidence.

## Current E040-A-R1 Evidence Boundary

Validated so far:

```text
experiment: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/
case: 20A -> 40A external load-current rise
transition: 2 active phases -> 4 active phases
variants: R1-D0, R1-D1, R1-D2, R1-D3
metrics: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
summary: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
classification: MODEL_CONFIRMED
```

Allowed local claim from E040-A-R1:

```text
In the local ideal IQCOT derived model, corrected active-phase remap plus a
guarded insertion/relock sequence enables the moderate 20A -> 40A, 2 -> 4
add-phase transition while preserving accepted-REQ integrity, avoiding inactive
phase requests, maintaining zero post-add phase-order error, and avoiding the
current-limit guard.
```

Quantitative local evidence:

```text
R1-D1:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  peak undershoot = 801.960 mV
  final Vout error = -270.375 mV

R1-D2:
  dwell_time = 1 us
  new_phase_ramp_time = 1.998 us measured
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  peak undershoot = 807.856 mV
  final Vout error = -334.944 mV

R1-D3:
  a_S_enable_time = 5.5 us
  Ton_trim_usage = 0.204702
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  peak undershoot = 807.856 mV
  final Vout error = -340.265 mV
```

Interpretation:

- E040-A-R1 upgrades only the local active-phase add insertion integrity claim.
- The best voltage recovery among the add variants is still R1-D1; R1-D2/R1-D3 trade voltage recovery for guarded insertion and post-relock a_S timing.
- R1-D3 verifies that frozen guarded `a_S` can be delayed until after dwell, ramp, order relock, and reentry delay in this local add case.

Still not allowed from E040-A-R1:

- broad active-phase robustness;
- 4 -> 2 shed behavior;
- arbitrary 1/2/4 active-phase scheduling;
- active Lambda control;
- severe 40A -> 120A add-phase recovery;
- severe load-drop shed behavior;
- switching-efficiency improvement;
- hardware, HIL, board-level, or silicon validation.

## Current E040-S0 Evidence Boundary

Validated so far:

```text
experiment: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/
case: 40A -> 20A external load-current drop
transition target: 4 active phases -> 2 active phases [1,3]
variants: S0, S1, S2, S3
summary: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_research_summary.md
metrics: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_metrics.csv
classification: MODEL_REVISED
```

Allowed local claim from E040-S0:

```text
In the local ideal IQCOT derived model, the first minimal 4 -> 2 shed attempt
shows that a simple immediate, dwell-only, or residual-threshold-only shed
projection is insufficient. Immediate and dwell-only shed can hold two phases
but produce large undershoot and current-limit violations. The residual/relock
S3 guard prevents the worst voltage/current-limit failure only by failing to
hold a stable two-phase active set.
```

Quantitative local evidence:

```text
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

Interpretation:

- E040-S0 is valid negative evidence for the simple shed model, not an implementation-only failure.
- Stable shed requires a staged load-share transfer, disabled-phase current drain, and a commit/relock state that is separate from the instantaneous residual-current predicate.
- Residual-current thresholding remains necessary but is not sufficient by itself.
- Delayed `a_S` after shed is still unproven, because S3 did not maintain a stable two-phase post-shed interval.

Still not allowed from E040-S0:

- active-phase shed validation;
- S4 AI/table selected `a_N` shed claim;
- broad 1/2/4 active-phase scheduling robustness;
- severe load-drop shed behavior;
- switching-efficiency improvement from phase shedding;
- active Lambda control;
- hardware, HIL, board-level, or silicon validation.

## Current E040-S1 Evidence Boundary

Validated so far:

```text
experiment: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/
case: 40A -> 20A external load-current drop
transition target: 4 active phases -> 2 active phases [1,3]
variants: S1-R0, S1-R2, S1-R3
metrics: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
summary: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
classification: MODEL_CONFIRMED
```

Allowed local claim from E040-S1:

```text
In the local ideal IQCOT derived model, a staged load-share transfer,
per-phase disabled-current drain, zero-current phase gate-enable mask, atomic
active-set commit, and two-phase relock can perform the tested mild `40A -> 20A`,
`4 -> [1,3]` shed handoff while preserving REQ integrity, avoiding inactive
accepted events, avoiding the current-limit guard, and satisfying the residual
current qualification.
```

Quantitative local evidence:

```text
S1-R0 fixed four-phase:
  N_active_final = 4
  peak undershoot = 0.45125 mV
  final Vout error = 0.698733 mV

S1-R2 transfer/drain no commit:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  fallback_4ph_count = 0
  residual_current_check = pass

S1-R3 commit/relock:
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

Interpretation:

- E040-S1 upgrades only the local mild shed-handoff integrity claim.
- The key revision versus E040-S0 is that disabled phases require per-phase zero-current qualification and deterministic gate-enable masking to prevent synchronous low-side reverse-current sink.
- The gate-enable mask is generated by the model-based active-phase event manager after residual-current qualification. It is not an AI/table gate command.
- The successful commit rule separates pre-commit residual qualification from post-commit active-set holding; otherwise `N_active` can drift back toward four-phase behavior.
- Active Lambda remains disabled and post-shed `a_S` was not enabled in S1-R3.

Still not allowed from E040-S1:

- general E040-S shed success beyond the fixed S1-R3 local case;
- S4 AI/table selected `a_N` shed success;
- broad active-phase robustness;
- arbitrary 1/2/4 scheduling;
- severe `40A -> 1A` or `120A -> 10A` shed behavior;
- DCR mismatch or current-sense mismatch with active-phase scheduling;
- active Lambda control;
- efficiency improvement;
- hardware, HIL, board-level, or silicon validation.

`S1-R4` remains unrun despite the S1-R3 pass. It needs a new hypothesis and run protocol because it would add conservative post-shed `a_S` recovery to the already-confirmed handoff.

The confirmed S1-R3 local gate was:

```text
N_active_final == 2
actual_active_phase_set_final == [1,3]
shed_commit_count == 1
fallback_4ph_count == 0
dropped_REQ_count == 0
inactive_phase_REQ_count == 0
phase_order_error_rate_post_shed == 0
current_limit_hit == false
residual_current_check == pass
active Lambda == disabled
post_shed_aS_mode == 0
```
