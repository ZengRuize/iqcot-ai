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
next E010 expansion target: severe-drop a_O token for 40A -> 1A
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

First chunk: E040-A add-phase validation only. Do not run E040-S or a broad active-phase grid until E040-A is classified.

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
E040-A-R1 only
retune request remap / phase insertion / dwell-ramp / post-add Ton recovery
require phase_order_error_rate = 0 before E040-S
keep active Lambda disabled
```
