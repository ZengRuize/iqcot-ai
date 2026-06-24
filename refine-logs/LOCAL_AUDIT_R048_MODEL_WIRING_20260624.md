# LOCAL AUDIT R048 Model Wiring

Date: 2026-06-24

## Scope

R048 performed a read-only wiring, parameter, solver, and logging preflight for
`output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`.  No switching
matrix was run.  No original `.slx` was modified.  No raw `.slx` XML was edited.

## Method

- Loaded the derived `.slx` with MATLAB `load_system`.
- Queried block structure and parameters with `find_system` and `get_param`.
- Queried line/port connectivity for the request path, scheduler, COT cells,
  gate drivers, dynamic load, voltage measurement, and inductor-current taps.
- Checked solver/logging model settings and confirmed the current runners
  inject variables and mark logged signals at run time.
- Used the global `power-electronics-simulink-design` skill and its COT
  optimization reference, because the task concerns a four-phase IQCOT/COT Buck
  VRM Simulink model.

## Key Findings

- The active `REQ` path is `IEK_PerPhase_Request -> Goto14(tag=REQ)`, not the
  original Relay.  The Relay remains `commented=through`.
- `PhaseScheduler_4Phase` output port 5 provides `phase_idx` back to
  `IEK_PerPhase_Request`.
- `IQCOT_Ton_Adapter` outputs `Ton_iqcot1..4` into the four COT cells, and
  `Ton_trim1..4` are already variable-driven constants.
- `Mosfet..3` high-side `Ron` is bound to `Ron_HS`; `Mosfet4..7` low-side `Ron`
  is bound to `Ron_LS`.  No hard-coded `0.1 ohm` Ron was found.
- Inductors are bound to `L` and `DCR_L1..4`; output capacitor branch is bound
  to `Cout`, `ESR_C`, and `Vo_ref`.
- COT/driver timing uses variable references: `Tblank`, `Toff_min`, and
  `Tdead`.
- The model solver config is `VariableStepAuto`, `MaxStep=max_step_cont`,
  `RelTol=1e-3`; R039/R040 runners override `MaxStep=5e-9` and inject `Tss`.
- The model has `SignalLogging=on` but no saved logged lines.  R039/R040
  runners stream `vout`, `qh1..4`, and `il1..4` at run time.

## Decision

```text
MODEL_CONFIRMED
```

The current derived model exposes the necessary source paths for planning the
next PR-ECB/PIS-IEK derived-control copy.  The result does not validate the new
controller actions; it only confirms that the model wiring is sufficiently
understood to proceed to a derived-copy construction step.

## Required Follow-up Before Simulation Expansion

1. Keep using MATLAB APIs to build or modify only derived copies.
2. Add explicit runner/init coverage for every required variable; standalone
   model load does not populate base variables.
3. Add logging taps for `REQ`, `phase_idx`, `QL1..4`, `Ton_done_i` or measured
   high-side pulse width, and future `protect_state`.
4. Run only the smallest PR-ECB cut-load chunk after the derived-control copy
   passes the same preflight.

## Claim Boundary

No claim is upgraded by R048.  PR-ECB remains derived-Simulink/offline evidence
only; PIS-IEK is not claimed to predict all large-signal first peaks; AI does
not replace the IQCOT inner loop; `E_HS,rem` is not a global additive law.
