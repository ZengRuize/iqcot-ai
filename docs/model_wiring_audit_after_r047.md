# R048 Model Wiring Audit After R047

Date: 2026-06-24

Scope: read-only preflight of the existing derived model
`output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`.  This audit did
not run a switching validation matrix, did not modify any original `.slx`, and
did not edit `.slx` XML.  Inspection used MATLAB `load_system`, `find_system`,
`get_param`, line/port queries, and the existing runner scripts as the init/log
reference.

Decision for this preflight chunk:

```text
MODEL_CONFIRMED
```

Meaning: the existing derived model exposes the main plant, request, scheduler,
gate, and logging tap points needed to plan the next PR-ECB/PIS-IEK derived
copy.  Two implementation notes must be handled before expanding validation:
standalone `load_system` does not populate the required workspace variables, and
saved signal logging is not present on the model lines; current runners inject
variables and mark log signals at run time.

## Model under audit

| Item | Finding |
|---|---|
| Model file | `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` |
| Provenance | derived from `four_phase_iek_perphase_trim.slx`, ultimately from the user `four_phase.slx` copy |
| Controller request path | `IEK_PerPhase_Request -> Goto14(tag=REQ) -> From15/From18 -> PhaseScheduler_4Phase -> COT_Cell_1Phase1..4` |
| Original relay | `Relay` remains in the model but is `commented=through`; it is not the active `REQ` source |
| Dynamic load path | `LoadCurrentStep -> Dynamic Load Current Source` |
| Reference path | `Iph_ref_ts` drives `IEK_PerPhase_Request/Iph1..4` and `IQCOT_Ton_Adapter/Iref_Phase` |
| Active phase logic | fixed four-phase scheduler only; no saved `active_phase_set` controller yet |
| Protection logic | no PR-ECB protection block yet; this model is the source/audit target for a future derived-control copy |

## Controller classification

The inspected model is a closed-loop COT/IQCOT-derived switching model, not an
open-loop fixed-frequency PWM model:

```text
Vout / sampled signals
-> IEK_PerPhase_Request
-> global blanking and PhaseScheduler_4Phase
-> COT_Cell_1Phase1..4 with Ton_iqcot_i and Toff_min logic
-> GateDriver_1Phase1..4 with complementary QH/QL and Tdead delay
-> synchronous Buck power stage
```

The current request generator is the per-phase IEK subsystem.  The original
Relay hysteresis block is still available for comparison but is bypassed.

## Actual model-wiring table

| Function | Existing signal/block path found in model | Proposed derived signal/block | Audit result / reason |
|---|---|---|---|
| Output voltage | `Voltage Measurement` output; also `Goto13(tag=Vout)` and `From34(tag=Vout)` | `Vout_log` | Found. Historical runners resolve Simulink ID `model:33` to `Voltage Measurement` and stream it as `vout`. |
| Load estimate | `LoadCurrentStep` with `Time=t_load_step`, `Before=Iload_initial`, `After=Iload_final`; drives `Dynamic Load Current Source` | `Iload_est` | Found as commanded current-source input. No separate measured `Iload` logging line is saved; PR-ECB scripts reconstruct load from case spec. |
| Phase currents | `IL_Measurement1..4`; also `Goto22..25(tags=IL1..IL4)` and `From33/35/36/32` | `IL_vec` | Found. Runners stream `IL_Measurement1..4` as `il1..il4`. |
| Sampled currents | `Goto27/29/30/31(tags=IL_sample1..4)` and `From27..30` into `IQCOT_Ton_Adapter` | `IL_sample_vec` | Found. Used by the IQCOT on-time adapter. |
| High-side gate states | `GateDriver_1Phase1..4` output port 1; `Goto4..7(tags=QH1..QH4)` and `From0..3` | `HS_vec`, `active_HS_class` | Found. Historical runners stream IDs `78/99/120/141` as `qh1..qh4`. |
| Low-side gate states | `GateDriver_1Phase1..4` output port 2; `Goto8..11(tags=QL1..QL4)` and `From4..7` | `LS_vec` | Found. Not currently streamed by R039/R040 runners; add logging in the next derived-control runner if dead-time/LS behavior is a metric. |
| Area request | `IEK_PerPhase_Request/REQ_iek -> Goto14(tag=REQ)` | `REQ_vec` or `REQ_global` | Found. Current model has a global request into scheduler, not per-phase PR-ECB inhibit requests. |
| Phase index | `PhaseScheduler_4Phase` output port 5 `phase_idx`; connected to `IEK_PerPhase_Request` input 3 | `phase_idx` | Found. Use this as the current event-index source. |
| Active phase set | none beyond fixed four-phase scheduler outputs | `active_phase_set` | Not present yet. Must be added only in a derived copy if phase add/shed validation begins. |
| Actual Ton | `COT_Cell_1Phase1..4` have `Ton_done_i` output ports, but these top-level outputs are unconnected | `Ton_actual_i` | Tap exists but is not wired/logged. Next derived copy should log or compute high-side pulse width from `QH_i`. |
| Commanded Ton | `IQCOT_Ton_Adapter/Ton_Base(Value=Ton_cmd)`, `Ton_Sum1..4`, `Ton_Limit1..4`, outputs `Ton_iqcot1..4` to COT cells | `Ton_cmd_i`, `ton_truncate_i` | Found. `Ton_trim1..4` are already variable-driven constants. PR-ECB truncation should be inserted in a derived copy before `Ton_Limit` or immediately before COT cell input. |
| Area threshold | `IEK_PerPhase_Request/Lambda1..4(Value=Lambda1..4)` | `Lambda_i`, `Lambda_trim_i` | Found. Suitable for PIS-IEK `Lambda_diff` experiments. |
| Area integrators | `IEK_PerPhase_Request/Area1..4`, `ExternalReset=rising`, reset input from `From17(tag=tr)` | `area_int_i`, `hold_int_i`, `reset_int_i` | Found. Hold/reset control is not present yet; add only to a derived copy. |
| Skip / inhibit | Existing global blanking path: `Compare To Constant(mask const=Tblank)`, `Goto15(tag=GlobalReady)`, `Goto16(tag=Allow)` | `skip_flag`, `pulse_inhibit_i` | Partial. Existing blanking/allow path can identify skipped events, but PR-ECB inhibit tokens are not implemented. |
| Reentry state | no explicit block | `reentry_flag`, `Reentry_Manager` | Not present. Needs derived-control design. |
| Protection state | no explicit block | `protect_state`, `Cut_Load_Protector` | Not present. Needs derived-control design. |
| Phase spacing | scheduler outputs and `QH_i` edge times | `phase_spacing_i` | Derivable from gate logs. No saved phase-spacing block exists. |

## Parameter and solver preflight

| Parameter group | Actual `.slx` binding | Current runner / report value | Preflight note |
|---|---|---:|---|
| `Vin` | `DC Voltage Source/Amplitude = Vin` | `12 V` | Variable reference; standalone model load does not define it. |
| `Ron_HS`, `Ron_LS` | `Mosfet..3/Ron = Ron_HS`; `Mosfet4..7/Ron = Ron_LS` | `1 mOhm` each | Variable references; no hard-coded `0.1 ohm` Ron found. |
| Body diode / snubber | `Rd_body`, `Vfd_body`, `Rs_snubber`, `Cs_snubber` | runner/report dependent | Variable references; values need explicit injection for new runners. |
| `L`, DCR | `Series RLC Branch..3`: `BranchType=RL`, `Inductance=L`, `Resistance=DCR_L1..4` | `L=200 nH`, `DCR=10 mOhm` | Variable references. |
| `Cout`, `ESR` | `Series RLC Branch4`: `BranchType=RC`, `Capacitance=Cout`, `Resistance=ESR_C`, `Setx0=on`, `InitialVoltage=Vo_ref` | `Cout=7.26 mF`, `ESR_C=90 uOhm`, `Vo_ref=1 V` | Variable references; output capacitor initial voltage is tied to `Vo_ref`. |
| `Ton` | `IQCOT_Ton_Adapter/Ton_Base = Ton_cmd`; COT cell input `Ton_iqcot_i` | `Ton_cmd=196.5 ns`; earlier physical Ton note `186.5 ns` | Variable reference plus closed-loop adapter. Use the adapter output as implemented Ton command. |
| `Ton_trim` | `Ton_trim1..4` constants feed `Ton_Sum1..4` | zero in R039/R040 runners | Already exposed for per-phase trim. |
| `Toff_min` | `COT_Cell_1Phase1/Compare To Constant2(mask const=Toff_min)` and analogous COT cells | not injected by R039/R040 runner snippets | Variable reference; verify default source before using `Toff_min` as a claim. |
| `Tblank` | top-level `Compare To Constant(mask const=Tblank)` | `480 ns` in existing assessment | Variable reference; global request spacing path exists. |
| `Tdead` | top-level `OnDelay` and `GateDriver_1Phase1/OnDelay`, `OnDelay1` masks use `Tdead` | value not restated in R048 docs | Variable reference; include in next runner init block if dead-time metrics are used. |
| `Vhys` | original `Relay` uses `Vhys/2` and `-Vhys/2`, but Relay is `commented=through` | `0.45 mV` in existing assessment | Not active in the current IEK request path. |
| Digital sampling | `Zero-Order Hold = 1/25000000`; `Transport Delay = 5/25000000`; quantizer interval `1`; current ADC gain `±205 count/A` | `Ts_ctrl=40 ns`, delay `200 ns` | Matches existing assessment. |
| Solver | `Solver=VariableStepAuto`, `SolverType=Variable-step`, `MaxStep=max_step_cont`, `RelTol=1e-3`, `StopTime=2e-3` | R039/R040 override `MaxStep=5e-9`, `Tss=5e-9`, custom StopTime | Model-level config is variable-based; validation runners override key timing. |
| Logging | model `SignalLogging=on`, `SignalLoggingName=logsout`; saved logged lines count `0` | R039/R040 mark `vout`, `qh1..4`, `il1..4` at run time | Logging is runner-dependent. Next derived-control runner should also mark `ql1..4`, `REQ`, `phase_idx`, and protection states. |

## Wiring issues and non-issues

- Non-issue: Simscape physical lines appear as source-less in a raw line query;
  this is expected for physical conserving ports and is not treated as a model
  fault.
- Non-issue: COT cell diagnostic outputs `Ton_done_i`, `NQmin_i`, and
  `CurrentLimit_i` are unconnected at top level. This is acceptable for the
  existing evidence but should be logged or wired in a derived protection copy.
- Non-issue: MOSFET measurement outports are unconnected even though mask
  `Measurements=on`; prior wave exports rely on gate and current logs instead.
- Attention: `Add/Add1..4` have one unconnected Simulink input and one connected
  `From` input. Prior R039-R043 runs completed with this structure, so it is not
  a stop condition, but it should be rechecked if these blocks become protection
  features.
- Attention: model workspace and callbacks are empty. A fresh validation runner
  must explicitly set every required variable through `SimulationInput` or a
  documented init script.

## Next validation gate

Do not run a full matrix next.  The smallest safe next chunk is still a derived
copy construction / dry-run plan for PR-ECB cut-load protection:

1. copy `four_phase_iek_dynamic_load_refslew.slx` to a new derived-control model
   through MATLAB APIs;
2. add logging taps for `REQ`, `phase_idx`, `QL1..4`, `Ton_done_i` or measured
   high-side pulse width, and future `protect_state`;
3. insert PR-ECB protection tokens only in the derived copy:
   `ton_truncate_i`, `pulse_inhibit_i`, `hold_int_i`, `reset_int_i`;
4. run one minimal A0/A1/A2/A3 cut-load chunk only after the derived copy passes
   the same wiring and variable-injection checks.

No claim boundary changes are required from this preflight.  PR-ECB remains
derived-Simulink/offline evidence only, PIS-IEK remains a small-signal
balance/reentry model rather than a universal first-peak predictor, AI remains
a low-dimensional supervisory proposal layer, and `E_HS,rem` remains an
active-HS segmentation feature rather than a global additive law.
