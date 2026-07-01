# E020-R1 Waveform Audit

Date: 2026-07-01

## Scope

Fixed external `40A -> 120A` load-current rise. `R1-B0` and `R1-B3` are carry-forward references; `R1-U1/U2/U3/U4` are newly simulated derived models.

## Signal Availability

- Direct or baseline logged: `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`, `Lambda_i`, `area_int_i`, `active_phase_set`.
- R1 added logs: `IL_sense1..4`, `REQ_accept1..4`, `REQ_reject_reason`, `current_limit_hit`, `phase_current_peak`, `current_rise_target_state`, `late_recovery_guard_state`, `Vout_error`, `Vout_error_slope`, `settling_band_state`, `phase_order_error`.
- Ton boost logs: `ton_boost_active1..4`, `Ton_cmd_boost1..4`, `Ton_boost_state`, `Ton_boost_gain`, `Ton_boost_window`, `Ton_boost_decay_state`, `fallback_to_nominal_state`.
- Fast request logs: `fast_request_active`, `fast_request_count`, `fast_req_state`, `fast_req_reject_reason`.
- Derived in postprocess: `Ton_nom` from `Ton_cmd1..4`, `phase_order_error_rate` from accepted-event sequence, `fast_req_count` from fast-request active edges, and current-imbalance metrics from `IL1..IL4`.

## Unavailable Or Proxy Signals

- Exact signal name `fast_req_count` is reported as a metric derived from logged `fast_request_count` and `fast_request_active`.
- `REQ_count` and `accepted_REQ_count` are equal in this fixed four-phase R1 model because no add/shed supervisor rejects scheduler outputs; `dropped_REQ_count` is therefore an integrity check, not a separate rejection mechanism.
- The pass/fail phase-order guard uses event-sequence postprocess. The sampled `phase_order_error` signal is retained only as a model diagnostic.

## Derived Models

- `R1-B0`: `E:/Desktop/codex/models/derived/E020_B0_load_rise_observable_from_ideal_iqcot_20260629.slx`
- `R1-B3`: `E:/Desktop/codex/models/derived/E020_B3_fast_request_ton_boost_from_ideal_iqcot_20260629.slx`
- `R1-U1`: `E:/Desktop/codex/models/derived/E020_R1_U1_aU_window_from_ideal_iqcot_20260701_144658.slx`
- `R1-U2`: `E:/Desktop/codex/models/derived/E020_R1_U2_aU_window_from_ideal_iqcot_20260701_144800.slx`
- `R1-U3`: `E:/Desktop/codex/models/derived/E020_R1_U3_aU_window_from_ideal_iqcot_20260701_144845.slx`
- `R1-U4`: `E:/Desktop/codex/models/derived/E020_R1_U4_aU_window_from_ideal_iqcot_20260701_144929.slx`
