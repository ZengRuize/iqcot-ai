# E010-A5 Severe-Drop a_O Research Summary

Date: 2026-06-30

Status: DESIGN_PACKAGE_PLUS_BASELINE_AUDIT_CONFIRMED

## Scope

This folder defines the missing severe-drop `a_O` token for the unresolved `40A -> 1A` load-drop case. The first execution gate has now been completed: only A5-C0 and A5-C4 were run to reproduce the baseline and previous A4 boundary and to audit severe-drop logging/postprocess reliability.

No A5-T1/T2/T3/T4 token candidate has been run yet.

## Fixed Case

```text
External load-current drop: 40A -> 1A
Active phases: fixed four-phase
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
Active-phase add/shed: disabled
```

## Design Artifacts

```text
e010_a5_hypothesis.md
e010_a5_protocol.md
e010_a5_token_design.md
e010_a5_state_machine.md
e010_a5_metrics_template.csv
e010_a5_waveform_audit.md
```

## Baseline Audit Artifacts

```text
e010_a5_baseline_audit.md
e010_a5_baseline_metrics.csv
e010_a5_baseline_waveform_audit.md
e010_a5_baseline_reproduction_summary.md
e010_a5_baseline_signal_availability.csv
e010_a5_baseline_scheduler_audit.csv
```

## Baseline Audit Result

Classification: `MODEL_CONFIRMED`

```text
A5-C0 original ideal IQCOT:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0

A5-C4 previous A4 no-harm selector:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0
```

A5-C4 reproduces the known severe-drop boundary: A4 is no-harm but non-improving for `40A -> 1A`. This confirms the need for A5 but does not validate A5.

## Current Claim Boundary

Allowed:

- A5 is a proposed severe-drop token design.
- The token targets large-signal excess-current / excess-energy behavior.
- A5-C0/A5-C4 baseline reproduction and logging/postprocess audit passed.
- Future A5-T validation must compare A5 against A5-C0 and A5-C4 before claiming improvement.

Forbidden:

- A5 improves `40A -> 1A` overshoot or recovery peak.
- A5 is validated in Simulink.
- A5 can be mixed with active-phase shedding.
- PIS-IEK predicts the severe-drop first peak.
- Any hardware/HIL/board/silicon claim.

## Future Claim Boundary

If A5 later succeeds, the allowed claim may be:

```text
In the local ideal IQCOT derived Simulink model, a severe-drop a_O token
using active-HS-aware Ton truncation, bounded pulse inhibit, area-integrator
management, and undershoot-budgeted controlled reentry can improve the tested
40A -> 1A load-drop recovery without violating REQ, phase-order, current-limit,
area-integrator, fallback, or reentry guards.
```

Still forbidden even after a future local success:

```text
broad load-drop robustness
hardware/HIL/board/silicon validation
active Lambda control
active-phase shed during severe 40A -> 1A
PIS-IEK first-peak prediction claim
universal severe_drop_threshold
AI direct gate control
AI control of external load-current slew
```

## Next Execution Gate

Future execution may now run only:

```text
A5-T1
A5-T2
A5-T3
A5-T4
```

Do not run broad sweeps. Do not enable active Lambda, active-phase add/shed, DCR mismatch, or current-sense mismatch. Do not claim A5 improvement unless a candidate improves peak overshoot or recovery versus both A5-C0 and A5-C4 while preserving REQ, phase-order, current-limit, area-integrator, fallback, and reentry guards.
