# R049A PR-ECB Derived-Control Model Scaffold

Date: 2026-06-24

## Scope

This step continues after the R048 model-wiring audit.  It builds the first
PR-ECB cut-load-control scaffold as a derived `.slx` copy and performs a
non-simulation update-diagram preflight.

No full switching matrix was run.  No original `.slx` file was modified.  No
raw `.slx` XML was edited.

Decision for this chunk:

```text
MODEL_CONFIRMED
```

The decision means the R049A derived-control scaffold can be created and
updated with explicit variable injection.  It does not mean that PR-ECB
protection performance has been validated.

## Files

| Role | Path |
|---|---|
| Build script | `output/iqcot_r049_build_pr_ecb_control_model.m` |
| Source derived model | `output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` |
| New derived scaffold | `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx` |
| This plan/report | `docs/pr_ecb_control_derived_model_plan_r049.md` |
| Refine log | `refine-logs/LOCAL_AUDIT_R049A_PR_ECB_SCAFFOLD_20260624.md` |

## What changed in the derived copy

The build script copies the R048-audited source model and saves a new derived
model under `output/cutload_pr_ecb_control/`.  The copy persists the logging
surface required for the next smallest PR-ECB validation chunk:

| Signal | Derived model source |
|---|---|
| `vout` | `Voltage Measurement` output |
| `req_global` | incoming line to `Goto14(tag=REQ)` |
| `phase_idx` | `PhaseScheduler_4Phase` output port 5 |
| `il1..il4` | `IL_Measurement1..4` output port 1 |
| `qh1..qh4` | `GateDriver_1Phase1..4` output port 1 |
| `ql1..ql4` | `GateDriver_1Phase1..4` output port 2 |
| `ton_iqcot1..4` | `IQCOT_Ton_Adapter` output ports 1..4 |
| `ton_done1..4` | `COT_Cell_1Phase1..4` diagnostic output port 2, exposed through terminators |
| `nqmin1..4` | `COT_Cell_1Phase1..4` diagnostic output port 3, exposed through terminators |
| `current_limit1..4` | `COT_Cell_1Phase1..4` diagnostic output port 4, exposed through terminators |

It also adds no-op logged placeholders for the future protection interface:

```text
protect_state
r_p
ton_truncate1..4
pulse_inhibit1..4
hold_int1..4
reset_int1..4
```

These placeholders are constants connected only to terminators.  They do not
alter the plant, request path, Ton adapter, area integrators, scheduler, COT
cells, or gate drivers.

## Preflight checks performed

1. Built the derived model by running:

   ```matlab
   addpath('E:/Desktop/codex/output');
   iqcot_r049_build_pr_ecb_control_model();
   ```

2. Confirmed the source `output/simulink_iek/*.slx` files had no git diff.
3. Loaded `four_phase_iek_pr_ecb_control.slx` and confirmed:
   - `SignalLogging=on`
   - `SignalLoggingName=logsout`
   - `MaxStep=max_step_cont`
   - R049 placeholder blocks exist.
   - key line names match expected logging names.
4. Ran a non-simulation update-diagram check after explicit variable injection
   using `E:/Desktop/4cot/init_four_phase_cot_sync.m` plus R049 runtime
   variables:

   ```text
   UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control
   ```

## Current model hypothesis for the next chunk

| Field | Required content |
|---|---|
| Model version | GAE-IQCOT R047 + R048 wiring + R049A scaffold |
| Hypothesis | PR-ECB cut-load protection can be inserted as a derived-copy layer that logs risk/protection tokens without replacing the IQCOT inner loop. |
| Expected improvement | After real protection actions are implemented, A1/A2/A3 should reduce first overshoot or shorten unsafe high-side energy injection relative to A0 in selected cut-load contexts. |
| Expected failure mode | Too much inhibit or truncation may delay reentry or cause secondary undershoot; implementation mistakes may show up first as missing logs or broken Ton/scheduler paths. |
| Metrics | peak overshoot, first-peak time, active-HS state, high-side pulse width, `ton_done`, truncated Ton count, inhibit duration, skip estimate, reentry time, secondary oscillation, final error. |
| Claim boundary if successful | Only supports derived-Simulink PR-ECB control evidence for the tested small chunk. |
| Claim boundary if unsuccessful | Revise protection thresholds, inhibit/reentry logic, or model wiring before expanding the grid. |

## Next validation step

Do not run a full A matrix.  The next safe step is R049B:

1. replace no-op placeholders with the simplest derived-copy protection action;
2. first implement A1 simple over-voltage skip or A2 Ton truncation alone;
3. run only one load-drop magnitude crossed with two phase offsets;
4. end the chunk with exactly one status:
   `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or
   `CLAIM_DOWNGRADED`.

The current R049A result does not upgrade any claim.  PR-ECB is not hardware/HIL
validated, PIS-IEK does not predict all large-signal first peaks, AI does not
replace the IQCOT inner loop, and `E_HS,rem` is not a global additive law.
