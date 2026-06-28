# E001 Baseline Wiring Audit

Date: 2026-06-28

## Metadata

```text
audit_id: E001_baseline_wiring_audit_20260628
baseline_model: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
init_script: E:/Desktop/codex/output/iqcot_init_ideal_digital_iqcot_params.m
audit_script: E:/Desktop/codex/scripts/matlab/postprocess/e001_audit_baseline_model.m
classification: MODEL_CONFIRMED for steady baseline behavior; NEEDS_DERIVED_LOGGING for E010 readiness
```

The baseline model was inspected read-only. No `save_system` was issued on the baseline.

## Model Identity

```text
topology: four-phase synchronous Buck VRM
control_architecture: closed-loop IQCOT/COT event chain
phase_count: 4
active_phase_modes: fixed 4-phase in the baseline
solver: VariableStepAuto
solver_type: variable-step
max_step: max_step_cont = 2e-9 s
stop_time: 0.5e-3 s
signal_logging: on, logsout, Dataset
update_diagram: PASS
```

The Simulink overview shows:

```text
Vout/e_v -> Ideal_Digital_IQCOT_Request -> REQ_iqcot
REQ_iqcot -> global trigger chain -> PhaseScheduler_4Phase
PhaseScheduler_4Phase -> COT_Cell_1Phase1..4
COT cells -> GateDriver_1Phase1..4 -> QH/QL gates
IQCOT_Ton_Adapter -> Ton_iqcot1..4 -> COT cells
```

This is a closed-loop COT/IQCOT event architecture, not open-loop fixed-frequency PWM.

## Baseline Evidence

Existing E001 validation results:

| Case | Success | tr count | Phase coverage | REQ high fraction | Vout mean | Ripple mVpp | QH mean Hz |
|---|---:|---:|---:|---:|---:|---:|---:|
| `short_50us` | 1 | 101 | 4 | 0.835 | 0.979646 | 37.8138 | 506894 |
| `steady_0p5ms` | 1 | 1002 | 4 | 0.284 | 0.998203 | 0.857848 | 501353 |

Event audit:

```text
events audited: 968
fraction with A_before_tr >= Lambda_i: 1.0
mean accepted-trigger period: 516.112 ns
trigger-period jitter: 95.814 ns
max absolute sampled event error: 1.78387e-08 V*s
```

## Required Signal Audit

CSV: `experiments/E001_baseline_audit/e001_required_signal_audit.csv`

| Required signal | Status | Interpretation |
|---|---|---|
| `Vout` | PRESENT_LOGGED | ready |
| `Iload` | MISSING | must be added in load-step derived models |
| `IL1..IL4` | PRESENT_LOGGED | ready |
| `QH1..QH4` | PRESENT_LOGGED | ready |
| `QL1..QL4` | PRESENT_LOGGED | ready |
| `REQ1..REQ4` | MAPPED_PROXY | use `REQ_iqcot` plus accepted triggers `tr1..tr4`; add explicit per-phase request only if needed |
| `phase_idx` | PRESENT_LOGGED | ready |
| `Ton_cmd_i` | MAPPED_PROXY | current command proxy is `Ton_iqcot1..4` |
| `Ton_actual_i` | MISSING | should be added in derived models or computed from QH pulse widths |
| `Lambda_i` | PRESENT_LOGGED | ready |
| `area_int_i` | MAPPED_PROXY | current area proxy is `A_iqcot` |
| `active_phase_set` | MISSING | fixed 4-phase baseline; add explicit log in derived models |

## Parameter Audit

CSV files:

```text
experiments/E001_baseline_audit/e001_parameter_snapshot.csv
experiments/E001_baseline_audit/e001_init_workspace_snapshot.csv
```

| Parameter | Actual model value | Resolved/init value | Decision |
|---|---:|---:|---|
| `Ron_HS` | `Ron_HS` | `0.001` | variable reference OK |
| `Ron_LS` | `Ron_LS` | `0.001` | variable reference OK |
| `DCR_L1..4` | `DCR_L1..4` | `0.01` each | variable reference OK |
| `L` | `L` | `2e-07` | variable reference OK |
| `Cout` | `Cout` | `0.00726` | variable reference OK |
| `ESR_C` | `ESR_C` | `9e-05` | variable reference OK |
| `Rload` | `Rload` | `0.025` | fixed-load baseline; derived load-step model must replace or schedule it |
| `Ton_cmd` | `Ton_cmd` | `1.965e-07` | command path for `Ton_iqcot1..4` |
| `Toff_min` | `Toff_min` | `8e-08` | COT cell off-time guard |
| `Tdead` | `Tdead` | `1e-08` | gate-driver timing |
| `Tblank` | `Tblank` | `4.8e-07` | global trigger spacing |
| `Ts_ctrl` | `Ts_ctrl` | `4e-08` | IQCOT sampling |
| `Lambda0_iqcot` | `Lambda0_iqcot` | `3e-10` | IQCOT threshold |

The `.slx` XML was also extracted under:

```text
experiments/E001_baseline_audit/slx_extract_20260628/
```

Cross-check: the main MOSFET `Ron` fields are `Ron_HS` and `Ron_LS`, not hard-coded `0.1` ohm. Inductor and output capacitor fields are variable references (`L`, `DCR_L1..4`, `Cout`, `ESR_C`).

## Structural Check Notes

The Simulink structural check reported unconnected legacy blocks and diagnostic outputs:

```text
7 errors, 33 warnings
```

Key items:

- top-level `Add` / `Add1` / `Add2` / `Add3` / `Add4` have unconnected inputs;
- top-level `OnDelay` is unconnected;
- `COT_Cell_1Phase*` diagnostic outputs `Ton_done_i`, `NQmin_i`, `CurrentLimit_i` are unconnected;
- some physical measurement block conserving ports are reported as unconnected by the generic checker.

Because `update diagram` and the existing E001 simulations pass, these are treated as baseline wiring hygiene issues, not proof of failed IQCOT behavior. They should not be fixed in the baseline. If they matter to an experiment, fix or remove them only in a derived copy.

## Wiring Decision

```text
audit_result: NEEDS_DERIVED_LOGGING
baseline_behavior: MODEL_CONFIRMED
missing_signals: Iload, Ton_actual_i, active_phase_set
mapped_proxies: REQ_iqcot/tr1..4 for REQ1..4; Ton_iqcot1..4 for Ton_cmd_i; A_iqcot for area_int_i
required_derived_edits: add external load-current profile/logging; add active_phase_set log; add Ton_actual pulse-width measurement or postprocess equivalent
```

## Next Hypothesis Block

```text
experiment_id: E010
variant: A0 original ideal IQCOT with added observability only
load_profile: 40A -> 10A external load-current step
expected_branch: load-drop overshoot / excess-current branch
expected_metric_direction: A0 establishes baseline overshoot and reentry behavior
safety_projection_expected_action: none; A0 has no AI/table action
claim_under_test: baseline ideal IQCOT response is measurable with required E010 metrics
```
