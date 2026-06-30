# E010-A5-T4-R1 Protocol

Date: 2026-06-30

## Baseline and Derived-Model Rule

All R1 models are derived from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline model is not modified. Derived copies are created through MATLAB/Simulink APIs by:

```text
scripts/matlab/build/e010_a5_build_candidate_model.m
```

R1 is executed by:

```text
scripts/matlab/run/e010_a5_t4_r1_run_controlled_reentry.m
```

## Fixed Test Case

```text
load step: 40A -> 1A
active phases: fixed four-phase
DCR mismatch: disabled
current-sense mismatch: disabled
active Lambda: disabled
active-phase add/shed: disabled
```

No broad sweep is part of this protocol.

## Compared Rows

Carry-forward references:

```text
R1-C0: A5-C0 original ideal IQCOT reference
R1-C4: A5-C4 previous A4 no-harm selector
R1-T4proxy: previous A5-T4 proxy result
```

Executed R1 candidates:

```text
R1-T4a: burst limiter + inter-pulse spacing
R1-T4b: R1-T4a + area-int reentry clamp
R1-T4c: R1-T4b + recovery Ton ramp
```

## Required Observability

The waveform audit requires Vout, Iload, IL/IL_sense, QH/QL, REQ/REQ_accept, phase index, active high-side phase, Ton command/actual, area integrator, reentry state, burst limiter state, fallback state, current-limit flag, phase-order diagnostics, and inter-pulse spacing diagnostics.

Unavailable signals must be reported as unavailable rather than fabricated.

## Pass Gate

Improvement requires at least one positive metric improvement versus A5-C0/A5-C4:

```text
peak_overshoot_mV < 4.06085
or recovery_peak_2_12us_mV < 3.61172
or recovery_peak_12_40us_mV < 3.59863
```

Guard pass additionally requires:

```text
peak_undershoot_mV <= 2.0
dropped_REQ_count == 0
phase_order_error_rate == 0
current_limit_hit == false
burst_pulse_count_after_reentry <= 2
late_settling_guard_violation == false
fallback_count does not indicate looping
area_int remains bounded
final_Vout_error_mV remains bounded
```

Both improvement and guard pass are required before any local A5 severe-drop improvement claim.

## Outputs

```text
e010_a5_t4_r1_metrics.csv
e010_a5_t4_r1_signal_availability.csv
e010_a5_t4_r1_scheduler_audit.csv
e010_a5_t4_r1_comparison.md
e010_a5_t4_r1_waveform_audit.md
e010_a5_t4_r1_research_summary.md
```

## Executed Outcome

The final R1 execution produced:

```text
classification: MODEL_REVISED
best partial reference before R1 revision: R1-T4proxy
R1-T4a/b/c guard_pass: false
R1-T4a/b/c peak_undershoot_mV: 971.618
R1-T4a/b/c burst count / limit: 5 / 2
```

Interpretation:

```text
A5 severe-drop recovery remains MODEL_REVISED.
The next revision must reconsider reentry energy shaping rather than only counting pulses.
```
