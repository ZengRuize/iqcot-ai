# E020-R1 a_U Window Tuning Protocol

Date: 2026-07-01

## Baseline And Model Handling

- Baseline model: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`
- The baseline is read-only and must not be saved or modified.
- Each tested R1 variant is created as a derived copy under `models/derived/` by MATLAB/Simulink APIs.
- Raw `.slx` XML is never edited by hand.

## Fixed Validation Case

```text
load step: 40A -> 120A at 450 us
active phases: fixed four-phase
DCR/current-sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
simulation window: 90 us post-step
```

The load-current rise is an external disturbance. The AI/table supervisor may observe the step but must not command the load slew or gate signals.

## Variants

Carry-forward references:

- `R1-B0`: previous E020 B0 original ideal IQCOT evidence.
- `R1-B3`: previous E020 B3 fast request + Ton boost evidence.

New simulated variants:

- `R1-U1`: shorter Ton-boost window, B3 boost maximum, B3 fast request.
- `R1-U2`: shorter Ton-boost window, reduced boost maximum, B3 fast request.
- `R1-U3`: B3 window with stronger exponential Ton decay, fast request active only during the first deficit window.
- `R1-U4`: R1-U3 plus late-recovery guard and fallback to nominal Ton.

No Cartesian sweep is allowed in R1.

## Required Metrics

`e020_r1_metrics.csv` must include:

```text
variant
success
peak_undershoot_mV
delta_peak_undershoot_vs_B0_mV
delta_peak_undershoot_vs_B3_mV
recovery_peak_2_12us_mV
recovery_peak_12_40us_mV
recovery_overshoot_mV
current_rise_50pct_us
current_rise_90pct_us
delta_current_rise_90pct_vs_B0_us
delta_current_rise_90pct_vs_B3_us
settling_time_1mV_us
settled_within_90us
final_Vout_error_mV
delta_final_error_vs_B3_mV
phase_current_peak_A
phase_current_peak_limit_A
current_limit_hit
events_0_2us
events_2_12us
events_12_40us
Ton_boost_count
Ton_boost_usage
Ton_boost_gain
Ton_boost_window_us
Ton_boost_decay_policy
Ton_boost_decay_done_time_us
fast_req_count
fast_req_window_us
fast_req_reject_count
fast_req_reject_reason
fallback_to_nominal_time_us
late_recovery_guard_enable
late_recovery_guard_trigger_count
late_recovery_guard_trigger_reason
REQ_count
accepted_REQ_count
dropped_REQ_count
phase_order_error_rate
Vout_ripple_pp_mV
real_max_current_imbalance_A
real_rms_current_imbalance_A
guard_pass
classification_hint
```

## Waveform Audit

`e020_r1_waveform_audit.md` must state whether these signals are logged or derived:

```text
Vout, Iload, IL1..IL4, IL_sense1..IL_sense4
REQ1..REQ4, REQ_accept1..4, REQ_reject_reason
QH1..QH4, QL1..QL4
phase_idx, phase_order_error
Ton_nom, Ton_cmd1..4, Ton_actual1..4
Ton_boost_state, Ton_boost_gain, Ton_boost_window
Ton_boost_decay_state, fallback_to_nominal_state
fast_req_state, fast_req_count, fast_req_reject_reason
current_limit_hit, phase_current_peak, current_rise_target_state
late_recovery_guard_state, Vout_error, Vout_error_slope, settling_band_state
```

Unavailable signals must be documented and must not be fabricated.

## Pass / Fail Criteria

Early improvement versus B0:

```text
peak_undershoot_mV < 397.42
current_rise_90pct_us < 37.996
```

Late recovery improvement versus B3 requires at least one:

```text
final Vout error closer to 0 than -297.93 mV
or settled_within_90us == true
or reduced computable settling time
```

All guards must pass:

```text
current_limit_hit == false
dropped_REQ_count == 0
phase_order_error_rate == 0
phase_current_peak_A <= 55 A
Ton boost returns to nominal after the intended window/decay
late guard does not starve recovery
```

## Classification

- `MODEL_CONFIRMED`: early benefit is preserved and late recovery/final-error improves without guard violations.
- `MODEL_REVISED`: early benefit remains but late recovery is not improved, or the trade-off requires new decay/fallback timing.
- `IMPLEMENTATION_ISSUE`: model wiring, logging, or postprocess is unreliable.
- `CLAIM_DOWNGRADED`: tuning cannot preserve early benefit while improving late recovery in this fixed case.
