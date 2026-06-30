# E010-A5 Severe-Drop a_O Research Summary

Date: 2026-06-30

Status: CANDIDATE_COMPARISON_MODEL_REVISED

## Scope

This folder defines and tests the severe-drop `a_O` token for the unresolved `40A -> 1A` load-drop case. The A5-C0/A5-C4 baseline audit is confirmed, and the smallest A5-T1/T2/T3/T4 candidate comparison has now been run.

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

## Candidate Comparison Artifacts

```text
e010_a5_candidate_metrics.csv
e010_a5_candidate_comparison.md
e010_a5_candidate_waveform_audit.md
e010_a5_candidate_research_summary.md
e010_a5_candidate_signal_availability.csv
e010_a5_candidate_scheduler_audit.csv
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

## Candidate Comparison Result

Classification: `MODEL_REVISED`

```text
A5-T1:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0
  result = no improvement

A5-T2:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.61172 mV
  REQ/accepted/dropped = 149/149/0
  result = no improvement

A5-T3:
  peak overshoot = 4.06085 mV
  recovery peak 2-12us = 3.55696 mV
  recovery peak 12-40us = 3.53370 mV
  peak undershoot = 0.697797 mV
  REQ/accepted/dropped = 149/149/0
  burst count / limit = 5 / 2
  result = partial improvement, guard fail

A5-T4:
  same implemented conservative proxy setting and metrics as A5-T3
  result = partial improvement, burst guard fail
```

Interpretation: area-hold/reentry projection can reduce recovery peaks in the local derived model, but the post-reentry burst guard fails. A5 is not validated. The current T4 run is a state-machine proxy with reentry/burst audit, not a complete full-token fallback/burst-limiter implementation. The next revision must focus on controlled reentry and burst limiting rather than broad sweeps.

## Current Claim Boundary

Allowed:

- A5 is a proposed severe-drop token design.
- The token targets large-signal excess-current / excess-energy behavior.
- A5-C0/A5-C4 baseline reproduction and logging/postprocess audit passed.
- Future A5-T validation must compare A5 against A5-C0 and A5-C4 before claiming improvement.

Forbidden:

- A5 is validated for `40A -> 1A`.
- T3/T4 partial recovery improvement is a passing A5 claim.
- T4 is a complete full-token validation.
- A5 can be mixed with active-phase shedding.
- PIS-IEK predicts the severe-drop first peak.
- Any hardware/HIL/board/silicon claim.

## Revised Claim Boundary

Current allowed local claim:

```text
In the local ideal IQCOT derived Simulink model, the tested A5-T3/T4
area-hold/reentry projection reduces the severe 40A -> 1A recovery peaks
versus A5-C0/A5-C4 while preserving REQ accounting, accepted-event phase order,
current-limit, undershoot, and late-settling guards, but it violates the
post-reentry burst guard. Therefore A5 remains MODEL_REVISED, not
MODEL_CONFIRMED.
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

Do not expand the grid yet. Next smallest useful step:

```text
revise controlled reentry / burst limiter for A5-T4-R1
keep fixed 40A -> 1A
keep fixed four phases
keep active Lambda disabled
keep active-phase add/shed disabled
do not add mismatch cases
```

Do not claim A5 improvement unless the burst guard also passes.
