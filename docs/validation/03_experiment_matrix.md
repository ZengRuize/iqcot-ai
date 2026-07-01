# Experiment Matrix

## E001 Baseline Audit

Purpose: confirm the local ideal IQCOT baseline wiring, logged signals, solver settings, and original A0/B0/C0/D0 behavior before any derived-model claims.

Baseline:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Outputs:

- wiring audit report;
- baseline metrics CSV;
- baseline Markdown summary;
- list of missing signals to add only in derived copies.

## E010 Load-Drop Overshoot Validation

Compare:

```text
A0 original ideal IQCOT
A1 Ton truncation only
A2 Ton truncation + pulse inhibit
A3 Ton truncation + pulse inhibit + controlled reentry
A4 AI/table selected a_O
```

Test:

```text
40A -> 20A
40A -> 10A
40A -> 1A
120A -> 40A
120A -> 10A
```

Metrics:

```text
peak overshoot
early local peak 0-2us
recovery peak 2-12us
late settling 12-80us
undershoot penalty
reentry time
skip count
final error
```

Current status:

```text
40A -> 10A completed for A0-A4
40A -> 20A completed for A0-A4
40A -> 1A completed for A0/A4
120A -> 10A A0 completed as operating-boundary check, not improvement evidence
comparison: experiments/E010_load_drop_overshoot/e010_research_summary.md
classification: MODEL_REVISED
latest E010 severe-drop expansion: A5-R3 event-queue energy allocation for 40A -> 1A completed, MODEL_REVISED
```

Frozen E010 branch summary:

```text
E010-A4:
  status: local medium-drop support
  case: 40A -> 10A
  classification: MODEL_REVISED / local useful medium branch

E010-A5 baseline:
  status: A5-C0/A5-C4 baseline audit MODEL_CONFIRMED
  case: 40A -> 1A
  conclusion: A4 no-harm but non-improving

E010-A5 candidate:
  status: MODEL_REVISED
  conclusion: T3/T4 partial recovery improvement but burst guard fail

E010-A5-R1:
  status: MODEL_REVISED
  conclusion: pulse-count burst limiter causes recovery starvation / severe undershoot

E010-A5-R2:
  status: MODEL_REVISED
  conclusion: energy budget + Ton ramp reduces peaks but violates undershoot/burst guards

E010-A5-R3:
  status: MODEL_REVISED
  conclusion: event queue / Ton allocation still causes recovery starvation and phase-order guard failure
```

### E010-A5 Severe-Drop Token Design

Status: baseline reproduction/logging audit confirmed for A5-C0 and A5-C4. The smallest A5-T1/T2/T3/T4 candidate comparison, A5-T4-R1 controlled-reentry revision, A5-R2 reentry energy-shaping/scheduler-release revision, and A5-R3 event-queue energy-allocation revision have run and are `MODEL_REVISED`; do not claim A5 validation.

Fixed case:

```text
External load-current drop: 40A -> 1A
Active phases: fixed four-phase
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
Active-phase add/shed: disabled
```

Variants:

```text
A5-C0: original ideal IQCOT reference for 40A -> 1A, completed
A5-C4: previous A4 no-harm selector, completed
A5-T1: severe Ton truncation only, completed, no improvement
A5-T2: severe Ton truncation + bounded one-pulse inhibit, completed, no improvement
A5-T3: severe Ton truncation + bounded inhibit + area hold, completed, partial recovery improvement but burst guard fail
A5-T4: severe-drop token proxy with controlled reentry/fallback bookkeeping, completed, partial recovery improvement but burst guard fail
```

Completed baseline audit:

```text
metrics: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_metrics.csv
audit: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_audit.md
summary: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_baseline_reproduction_summary.md
classification: MODEL_CONFIRMED

A5-C0 peak overshoot = 4.06085 mV
A5-C0 recovery peak 2-12us = 3.61172 mV
A5-C0 REQ/accepted/dropped = 149/149/0

A5-C4 peak overshoot = 4.06085 mV
A5-C4 recovery peak 2-12us = 3.61172 mV
A5-C4 REQ/accepted/dropped = 149/149/0
```

Completed candidate comparison:

```text
metrics: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_metrics.csv
comparison: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_comparison.md
summary: experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_candidate_research_summary.md
classification: MODEL_REVISED

A5-T1/T2:
  no improvement versus A5-C0/A5-C4

A5-T3/T4:
  recovery peak 2-12us = 3.55696 mV
  recovery peak 12-40us = 3.53370 mV
  peak undershoot = 0.697797 mV
  REQ/accepted/dropped = 149/149/0
  burst count / limit = 5 / 2
  note: T4 is not a passing full-token validation; it is a proxy result that exposes the missing burst limiter
```

Completed A5-T4-R1 controlled-reentry / burst-limiter revision:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R1_controlled_reentry_burst_limiter/
metrics: e010_a5_t4_r1_metrics.csv
summary: e010_a5_t4_r1_research_summary.md
classification: MODEL_REVISED

R1-C0/R1-C4:
  carry-forward baseline references

R1-T4proxy:
  recovery peak 2-12us = 3.55696 mV
  recovery peak 12-40us = 3.53370 mV
  peak undershoot = 0.697797 mV
  burst count / limit = 5 / 2

R1-T4a:
  explicit burst limiter + inter-pulse spacing

R1-T4b:
  R1-T4a + area-int reentry clamp

R1-T4c:
  R1-T4b + recovery Ton ramp

R1-T4a/b/c result:
  peak overshoot = 0 mV
  recovery peaks = 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  REQ/accepted/dropped = 187/187/0
  REQ reject count = 170
  burst count / limit = 5 / 2
  guard_pass = false
```

Interpretation:

```text
The count/window burst limiter did not close the T4 burst failure.
The apparent positive-peak suppression in R1-T4a/b/c is a severe undershoot collapse, not usable recovery improvement.
R2 is the next completed smallest useful step; it revises the token structure again rather than validating A5.
```

Completed A5-R2 reentry energy-shaping / scheduler-release revision:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/
metrics: e010_a5_r2_metrics.csv
summary: e010_a5_r2_research_summary.md
classification: MODEL_REVISED

R2-C0/R2-C4:
  carry-forward severe-drop baseline references

R2-T4proxy:
  carry-forward partial recovery benefit with burst guard fail

R2-R1bad:
  carry-forward severe undershoot/final-error collapse

R2-E1:
  energy budget + Ton ramp

R2-E2:
  energy budget + Ton ramp + area-int soft preload

R2-E3:
  energy budget + Ton ramp + area-int soft preload + scheduler release ramp

R2-E4:
  E3 + voltage-windowed release

R2-E1/E2 result:
  peak overshoot = 3.51629 mV
  recovery peak 2-12us = 1.75366 mV
  recovery peak 12-40us = 3.51629 mV
  peak undershoot = 7.63188 mV
  burst count / limit = 5 / 2
  guard_pass = false

R2-E3/E4 result:
  peak overshoot = 0 mV
  recovery peaks = 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  REQ reject count = 170
  burst count / limit = 5 / 2
  guard_pass = false
```

Interpretation:

```text
E1/E2 prove that per-event Ton/energy shaping can reduce positive recovery peaks, but the resulting recovery trajectory violates the severe undershoot and burst guards.
E2 soft preload is observable but does not alter the waveform versus E1.
E3/E4 prove that the current scheduler-release gate starves recovery energy; voltage-window enable does not rescue the final-REQ gate insertion.
Post-R2 status was still MODEL_REVISED; R3 is the completed follow-up and A5 is now frozen as severe-drop boundary evidence. Do not broad sweep.
```

Completed A5-R3 event-queue energy-allocation revision:

```text
folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/
metrics: e010_a5_r3_metrics.csv
summary: e010_a5_r3_research_summary.md
classification: MODEL_REVISED

R3-C0/R3-C4:
  carry-forward severe-drop baseline references

R3-T4proxy:
  carry-forward partial recovery benefit with burst guard fail

R3-R2E1:
  carry-forward R2 energy/Ton shaping partial benefit with undershoot and burst guard fail

R3-E1:
  event queue + per-event Ton allocation

R3-E2:
  E1 + queue release spacing

R3-E3:
  E2 + area-int queue coupling

R3-E4:
  not run; E3 was not close to passing and did not isolate voltage-window release as the missing guard

R3-E1/E2/E3 result:
  peak overshoot = 0 mV
  recovery peaks = 0 mV
  peak undershoot = 971.618 mV
  final Vout error = -919.625 mV
  burst count / limit = 5 / 2
  phase_order_error_rate = 1
  dropped_REQ_count = 0
  guard_pass = false
```

Interpretation:

```text
The tested event-queue/Ton allocation path suppresses positive peaks only by starving recovery energy.
Queue observability and per-event accounting are necessary but not sufficient.
The severe-drop A5 token remains MODEL_REVISED; do not claim validation.
Next smallest useful step: freeze the severe-drop improvement claim boundary and move to E020 a_U window tuning or manuscript synthesis.
Do not broad sweep.
```

Post-freeze next action:

```text
do not run R4 projected scheduling tweak without a new structural hypothesis
either introduce a structurally different large-signal energy-management mechanism as future work
or move to E020 a_U window tuning / manuscript synthesis
recommended: move to E020 a_U window tuning
```

Metrics:

```text
variant
success
peak_overshoot_mV
peak_undershoot_mV
recovery_peak_2_12us_mV
recovery_peak_12_40us_mV
settling_time_us
final_Vout_error_mV
Vout_ripple_pp_mV
Ton_trunc_count
Ton_trunc_min_ns
Ton_saved_ns
Tton_trunc_window_us
pulse_inhibit_count
inhibit_time_us
REQ_reject_count
REQ_reject_reason
area_hold_count
area_reset_count
area_bleed_count
area_int_max
area_int_at_reentry
first_reentry_time_us
first_reentry_phase
first_reentry_Ton_ns
burst_pulse_count_after_reentry
REQ_count
accepted_REQ_count
dropped_REQ_count
phase_order_error_rate
real_max_current_imbalance_A
real_rms_current_imbalance_A
current_limit_hit
undershoot_budget_violation
late_settling_guard_violation
fallback_count
fallback_reason
classification_hint
```

Pass gate:

```text
improves peak overshoot or recovery peak versus A5-C0 and A5-C4
peak undershoot remains within severe undershoot budget
dropped_REQ_count == 0
phase_order_error_rate == 0
current_limit_hit == false
burst_pulse_count_after_reentry is bounded
final_Vout_error remains bounded
fallback does not loop
```

## E020 Load-Rise Undershoot Validation

Compare:

```text
B0 original ideal IQCOT
B1 fast request only
B2 Ton boost only
B3 fast request + Ton boost
B4 fast request + Ton boost + phase add
B5 AI/table selected a_U
```

Test:

```text
10A -> 40A
40A -> 80A
40A -> 120A
20A -> 120A
1A -> 40A
```

Metrics:

```text
peak undershoot
current rise time
recovery overshoot
phase current peak
current limit hit
settling time
final error
```

Current status:

```text
40A -> 120A completed for B0-B3
summary: experiments/E020_load_rise_undershoot/e020_research_summary.md
metrics: experiments/E020_load_rise_undershoot/e020_metrics.csv
classification: MODEL_CONFIRMED
scope: peak-undershoot reduction and current-rise acceleration only
boundary: no tested variant settled within 1 mV in the 90us post-step window
next E020 expansion target: tune a_U window before any B4 phase-add run
```

## E030 Balance Recovery Validation

Compare:

```text
C0 original ideal IQCOT
C1 Ton_diff only
C2 Lambda_diff only
C3 Ton_diff + Lambda_diff
C4 PIS-IEK projected balancer
C5 AI/table selected a_S
```

Mismatch cases:

```text
L mismatch +/-5%
DCR mismatch +/-5/10%
Ron mismatch +/-5/10%
current-sense gain mismatch +/-2/5%
driver delay mismatch +/-5/10ns
```

Metrics:

```text
max current imbalance
RMS current imbalance
phase spacing std
output ripple
effective switching frequency
trim usage
```

Current status:

```text
E030 DCR mismatch first chunk: MODEL_REVISED
E030-R1 projection retune: MODEL_REVISED
E030-R2 current-sense mismatch: MODEL_REVISED
E030-R3 calibration-aware guard: MODEL_CONFIRMED
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

`C4a_cal` is the preferred voltage-safe calibrated mode. `C4c_cal` is the stronger current-sharing calibrated mode under voltage/ripple guards. `C1low` is the low-confidence fallback. `C4a_conf` is the no-harm confidence-gated mode when sensing confidence is low. Active Lambda remains disabled.

## E040 Active-Phase Validation

Historical first chunk: E040-A add-phase validation. Current frozen local evidence includes E040-A-R1 add integrity and E040-S1 shed-handoff integrity. Do not run S1-R4, severe active-phase cases, mismatch active-phase cases, active Lambda, or a broad active-phase grid without a new smallest-useful protocol.

E040-A compare:

```text
D0 fixed two-phase operation, no phase add
D1 immediate 2 -> 4 phase add without dwell/ramp guard
D2 guarded 2 -> 4 phase add with dwell, new_phase_ramp_rate, and frozen a_S recovery
D3 guarded 2 -> 4 phase add with frozen a_S selector and current-sense confidence check
```

E040-A test:

```text
20A -> 40A external load-current rise
initial active phases: 2
target active phases: 4
nominal DCR
nominal current-sense gains
active Lambda disabled
frozen guarded a_S selector enabled after add/reentry
```

E040-A add guard:

```text
if Iload_est > I_add_high
and Vout is not in severe overshoot
and active_phase_reentry_lockout == false
and dwell_timer_pass == true
and current_limit_guard == pass:
    allow N_active_candidate to increase
else:
    delay or reject add-phase request
```

Initial values:

```text
I_add_high = 30 A
dwell_time = 2 us
new_phase_ramp_rate = bounded and documented by derived script
current_limit_guard = inherited from E020/E030 safety limits
```

Metrics:

```text
active phase timeline
add-phase time
shed-phase time
new phase current ramp
disabled phase residual current
phase spacing recovery time
overshoot/undershoot during add/shed
switching count / efficiency proxy
```

Required CSV columns for E040-A:

```text
variant, success
peak_overshoot_mV, peak_undershoot_mV, settling_time_us
final_Vout_error_mV, Vout_ripple_pp_mV
active_phase_transition_time_us
N_active_initial, N_active_final
phase_add_accept_count, phase_shed_accept_count
phase_add_reject_count, phase_shed_reject_count
new_phase_current_ramp_time_us, new_phase_current_overshoot_A
residual_current_at_shed_A, residual_current_threshold_A
real_max_current_imbalance_A, real_rms_current_imbalance_A
sensed_max_current_imbalance_A, sensed_rms_current_imbalance_A
phase_spacing_std_ns, phase_order_error_rate
REQ_count, dropped_REQ_count
current_limit_hit
Ton_trim_usage, Lambda_trim_usage
fallback_count, guard_clamp_count
classification_hint
```

Current status:

```text
E040-A first chunk completed
summary: experiments/E040_active_phase_add_shed/e040_research_summary.md
metrics: experiments/E040_active_phase_add_shed/e040_metrics.csv
classification: MODEL_REVISED
```

Key evidence:

```text
D1/D2/D3 all reached N_active_final = 4
dropped_REQ_count = 0
current_limit_hit = false
D1 phase_order_error_rate = 0.120482
D2/D3 phase_order_error_rate = 0.170732
D1 peak undershoot = 802.746 mV
D2/D3 peak undershoot = 810.494 mV
```

Next E040 target:

```text
E040-A-R1 completed
summary: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md
metrics: experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
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

E040-A-R1 validated only the local `20A -> 40A`, `2 -> 4` add-phase insertion/relock integrity.

E040-S0 minimal shed-phase validation is complete:

```text
case: 40A -> 20A external load-current drop
initial active phases: 4
target active phases: 2, physical [1,3]
variants: S0/S1/S2/S3
summary: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_research_summary.md
metrics: experiments/E040_active_phase_add_shed/S0_shed_phase_minimal/e040_s0_metrics.csv
classification: MODEL_REVISED
```

Key result:

```text
S0 fixed four-phase:
  peak undershoot = 0.451 mV
  final Vout error = 0.699 mV

S1 immediate shed:
  N_active_final = 2
  peak undershoot = 663.614 mV
  current_limit_hit = true

S2 dwell/lockout shed:
  N_active_final = 2
  peak undershoot = 543.833 mV
  current_limit_hit = true
  phase_order_error_rate_post_shed = 0.265152

S3 residual/relock/a_S guarded shed:
  N_active_final = 3.79065
  peak undershoot = 19.133 mV
  current_limit_hit = false
  phase_order_error_rate_post_shed = 0.992308
```

Interpretation:

```text
E040-S0 is negative/revision evidence for the simple shed projection.
Immediate or dwell-only shed can hold two phases but violates voltage/current guards.
Residual/relock S3 avoids current-limit failure only by failing to hold stable two-phase operation.
```

E040-S1 staged shed handoff is complete:

```text
case: 40A -> 20A external load-current drop
target: 4 -> [1,3]
variants: S1-R0/S1-R2/S1-R3
summary: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md
metrics: experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
classification: MODEL_CONFIRMED
```

Key S1-R3 pass metrics:

```text
N_active_final == 2
actual_active_phase_set_final == 1010
shed_commit_count == 1
fallback_4ph_count == 0
dropped_REQ_count == 0
inactive_phase_REQ_count == 0
phase_order_error_rate_post_shed == 0
current_limit_hit == false
residual_current_check == pass
```

Executed E040-S1 variants:

```text
S1-R0: fixed four-phase reference
S1-R1: immediate shed reference from E040-S0, failure baseline only
S1-R2: staged transfer + disabled-phase drain, no final commit unless all guards pass
S1-R3: staged transfer + drain + atomic shed commit + two-phase order relock
S1-R4: not run; optional conservative post-shed a_S using C1low or C4a_conf only
```

S1 implementation lesson:

```text
disabled-phase drain must include per-phase residual qualification
and deterministic phase_gate_enable masking to prevent reverse-current sink
after IL2/IL4 cross the residual-current band.
```

Do not run S1-R4, broad 1/2/4 grids, active Lambda, current-sense/DCR mismatch with active-phase, or severe load-rise/drop active-phase cases without a new smallest-useful protocol.

### Local Active-Phase Evidence After E040-A-R1 and E040-S1

Current status: frozen local evidence only.

Add-phase and shed-phase are not symmetric:

```text
2 -> 4 add:
  main issue = active-phase remap, phase insertion, post-add order relock
  E040-A failed first
  E040-A-R1 confirmed local add integrity under 20A -> 40A

4 -> 2 shed:
  main issue = load-share handoff and disabled-phase current management
  E040-S0 showed immediate/dwell-only shed is unsafe
  E040-S1 confirmed staged transfer, disabled-phase drain, atomic commit, and two-phase relock
```

Allowed claim:

```text
local add/shed integrity mechanisms in the derived ideal IQCOT Simulink model
```

Forbidden claim:

```text
broad active-phase robustness
arbitrary 1/2/4 scheduling
active Lambda control
efficiency improvement
severe load-rise/drop active-phase behavior
hardware/HIL/board/silicon validation
```
