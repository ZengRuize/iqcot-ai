# E010-A5 Candidate Waveform Audit

Date: 2026-06-30

## Scope

This waveform audit covers only `A5-T1`, `A5-T2`, `A5-T3`, and `A5-T4` for the fixed external `40A -> 1A` load-current drop. Load current remains an external disturbance, not an AI command.

## Logged Signal Families

The derived models log `Vout`, `Iload`, `IL1..IL4`, `IL_sense1..4`, `REQ1..4`, `REQ_accept1..4`, `REQ_reject_reason`, `QH1..QH4`, `QL1..QL4`, `phase_idx`, `active_HS_phase`, `Ton_cmd1..4`, `Ton_actual1..4`, `Ton_trunc_i`, `Ton_saved_i`, `Lambda_i`, `area_int_i`, `a_O_state`, `severe_drop_detected`, `pulse_inhibit_state`, `area_hold_state`, `reentry_state`, `fallback_state`, `current_limit_hit`, `phase_order_error`, and `burst_pulse_count_after_reentry` where available in the candidate log/wave samples. In the scheduler audit, sampled `phase_order_error` is reported as `model_phase_order_error_sample`; the pass/fail phase-order metric is computed from the accepted-REQ event sequence.

## Availability Summary

- `A5-T1`: required candidate audit signals logged and finite.
- `A5-T2`: required candidate audit signals logged and finite.
- `A5-T3`: required candidate audit signals logged and finite.
- `A5-T4`: successful first full candidate run produced the same implemented T3/T4 signal set and wave sample; a later rerun was discarded because MATLAB's temporary DMR database was full.

## Wave Samples

- `A5-T1`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_t1_severe_ton_trunc_40A_to_1A_wave_sample.csv`
- `A5-T2`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_t2_trunc_one_inhibit_40A_to_1A_wave_sample.csv`
- `A5-T3`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_t3_trunc_multi_area_hold_40A_to_1A_wave_sample.csv`
- `A5-T4`: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_t4_full_severe_token_40A_to_1A_wave_sample.csv`

## Interpretation

`MODEL_REVISED`: waveform evidence shows that the conservative area-hold/reentry projection can reduce recovery peaks for T3/T4, but the post-reentry burst count exceeds the configured limit. T4 is a state-machine proxy with reentry/burst audit rather than a passing full fallback/burst-limiter implementation. The A5 claim must remain revised, not confirmed.
