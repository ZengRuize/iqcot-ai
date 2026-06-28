# Ideal Digital IQCOT Simulink Build Report

Generated: 2026-06-28

## Paths

- Source model: `E:/Desktop/codex/output/simulink_iek/four_phase_iek_area.slx`
- New model: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`
- Validation summary: `E:/Desktop/codex/output/ideal_digital_iqcot_results/ideal_iqcot_validation_summary.csv`
- Event-audit timeseries: `E:/Desktop/codex/output/ideal_digital_iqcot_data/ideal_iqcot_timeseries.csv`

## Preserved Power Stage

The derived model is copied non-destructively from the IEK-area model. The four-phase synchronous Buck power stage, `PhaseScheduler_4Phase`, global blanking chain, COT cells, gate drivers, and `IQCOT_Ton_Adapter` are preserved. `Kiqcot` is held at 0 for first-stage validation.

## Replaced Control Block

`IEK_Area_Request` was replaced by `Ideal_Digital_IQCOT_Request`. The new request block uses sampled `e_v`, `IL1..IL4`, scheduler `phase_idx`, and accepted trigger reset `tr_reset`.

## IQCOT Equation

```text
vc_ctrl = Vc_bias_iqcot + Kvc_iqcot * e_v
IL_sel  = IL(phase_idx)
h_iqcot = vc_ctrl - Ri_iqcot * exp(kappa_cmd) * IL_sel
Lambda_i = Lambda0_iqcot * (1 + rho_cmd) + Lambda_m2 * cos(pi * phase_idx)
A_update = max(A_lower, A_prev + Ts_ctrl * h_iqcot)
REQ_iqcot = A_update >= Lambda_i
A_state resets on accepted tr_reset rising edge or accepted scheduler phase_idx transition
```

## Digital Timing

All controller inputs are sampled with ZOH blocks at `Ts_ctrl=40 ns`. `phase_idx` and `tr_reset` pass through Memory blocks before sampling to avoid the trigger-scheduler algebraic loop. Because the accepted `tr` pulse is only a few ns wide, the controller treats the persistent scheduler `phase_idx` transition as an equivalent accepted-event reset in addition to sampled `tr_reset`. The logged `A_iqcot` is the pre-reset area update at the current sample; state reset is applied after detecting accepted `tr_reset` or accepted phase transition.

## Parameter Table

| Parameter | Value | Reason |
|---|---:|---|
| `Ts_ctrl` | `40e-9` | digital controller sample time |
| `CT_iqcot` | `15e-12` | tuned so `Lambda0_iqcot=3e-10 V*s` |
| `VTH_iqcot` | `20e-3` | IQCOT threshold seed |
| `gm_iqcot` | `1e-3` | transconductance seed |
| `Lambda0_iqcot` | `3e-10` | matches validated IEK area event scale |
| `Ri_iqcot` | `0.5e-3` | current injection gain |
| `Vc_bias_iqcot` | `5.6e-3` | makes steady-state kernel slightly positive |
| `Lambda_m2` | `0` | first validation without differential threshold |
| `Kiqcot` | `0` | Ton adapter neutral during first validation |

## Signal Logging

Logged signals include `Vout`, `e_v`, `vc_ctrl`, `IL1..IL4`, `IL_sel`, `h_iqcot`, `A_iqcot`, `Lambda_i`, `REQ_iqcot`, `tr`, `tr_reset`, `phase_idx`, `tr1..tr4`, `QH1..QH4`, `QL1..QL4`, `SW1..SW4`, and `Ton_iqcot1..4` where available in the copied model.

## Update Diagram

`UPDATE_DIAGRAM_OK`

## Validation Results

| case | success | tr_count | phase coverage | req high frac | Vout mean | ripple mVpp | QH mean Hz | pass short | pass steady |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `short_50us` | 1 | 101 | 4 | 0.835 | 0.979646 | 37.8138 | 506894 | 1 | 1 |
| `steady_0p5ms` | 1 | 1002 | 4 | 0.284 | 0.998203 | 0.857848 | 501353 | 1 | 1 |

## Event Audit

- Audit output: `E:/Desktop/codex/output/ideal_digital_iqcot_results/ideal_iqcot_event_audit.csv`
- Audit report: `E:/Desktop/codex/output/ideal_digital_iqcot_results/ideal_iqcot_event_audit_report.md`
- Events audited: `968`
- Fraction with `A_before_tr >= Lambda_i`: `1.0`
- Mean accepted-trigger period: `516.112 ns`
- Trigger-period jitter: `95.814 ns`
- Max absolute sampled event error: `1.78387e-08 V*s`

The event audit uses the sampled-event row at the accepted `tr` edge. The previous CSV row may be one 40 ns controller sample earlier, before threshold crossing, so the audit intentionally aligns `A_iqcot` with the accepted sampled event.

## Boundaries

This is a derived Simulink switching model only. It does not claim hardware/HIL validation, optimal performance, AI supervision, PR-ECB cut-load protection, or final production controller timing. The first-stage claim is limited to a sampled IQCOT event kernel driving the existing four-phase Buck chain.
