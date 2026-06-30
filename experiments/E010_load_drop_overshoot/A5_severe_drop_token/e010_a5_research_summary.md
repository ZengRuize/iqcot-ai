# E010-A5 Severe-Drop a_O Research Summary

Date: 2026-06-30

Status: DESIGN_ONLY

## Scope

This folder defines the missing severe-drop `a_O` token for the unresolved `40A -> 1A` load-drop case. No E010-A5 simulation has been run in this package.

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

## Current Claim Boundary

Allowed:

- A5 is a proposed severe-drop token design.
- The token targets large-signal excess-current / excess-energy behavior.
- Future validation must compare A5 against A5-C0 and A5-C4 before claiming improvement.

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

Future execution should run only:

```text
A5-C0
A5-C4
```

first, then stop if baseline severe-drop logging is unreliable. A5-T1..T4 should run only after logging and postprocess are confirmed.
