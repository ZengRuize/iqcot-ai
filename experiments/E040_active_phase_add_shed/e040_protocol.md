# E040-A Active-Phase Add Protocol

Date: 2026-06-29

## Baseline Rule

Use the local ideal IQCOT baseline only as the source copy:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Never modify this baseline directly. Build derived copies under `models/derived/` through MATLAB/Simulink APIs.

## First Chunk

```text
case: 20A -> 40A external load-current rise
initial active phases: 2
target active phases: 4
variants: D0, D1, D2, D3
nominal DCR: enabled
nominal current-sense gains: enabled
active Lambda: disabled
E040-S shed validation: blocked until E040-A is classified
```

## Variants

```text
D0:
  fixed two-phase operation, no phase add

D1:
  immediate 2 -> 4 phase add without dwell/ramp guard

D2:
  guarded 2 -> 4 phase add with dwell, new_phase_ramp_rate, and frozen a_S recovery

D3:
  guarded 2 -> 4 phase add with frozen a_S selector and current-sense confidence check
```

## Add Guard

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
new_phase_ramp_time = 4 us
current_limit_guard = 55 A/phase
severe_overshoot_band = 20 mV
```

## Required Signals

Log:

```text
Vout, Iload
IL1..IL4, IL_sense1..IL_sense4
QH1..QH4, QL1..QL4, REQ1..REQ4
phase_idx, Ton_cmd_i, Ton_actual_i, Lambda_i, area_int_i
active_phase_set, N_active
phase_add_request, phase_add_accept
phase_shed_request, phase_shed_accept
new_phase_ramp_state, residual_current_i, dwell_timer
protect_state, reentry_state, balance_recovery_state
sense_confidence, calibration_enable, a_S_mode
fallback_count, guard_clamp_count
```

If any required signal is unavailable, document it in `e040_waveform_audit.md` and do not fake metrics.

## Metrics

Metrics are written to:

```text
experiments/E040_active_phase_add_shed/e040_metrics.csv
```

The postprocess script must report voltage excursion, settling, active-phase transition timing, add/reject counts, new-phase current ramp, real/sensed current imbalance, REQ integrity, phase-order error, trim usage, fallback/clamp counts, and a per-variant classification hint.

## Classification

Use:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

`MODEL_CONFIRMED` requires no REQ loss, no phase-order error, no current-limit hit, bounded voltage excursion, bounded post-add current imbalance, and successful guarded add/recovery behavior.
