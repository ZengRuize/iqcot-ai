# E010-A5 Revision Synthesis

Date: 2026-07-01

## Purpose

E010-A5 targeted the unresolved severe load-drop case:

```text
external load-current drop: 40A -> 1A
active phases: fixed four-phase
DCR/sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
```

The goal was to test whether projected IQCOT scheduling could safely reduce the severe-drop overshoot / recovery-peak behavior without violating undershoot, burst, phase-order, REQ, final-error, queue, or current-limit guards.

## Baseline Boundary

A5-C0 and A5-C4 established the local severe-drop baseline:

```text
A5-C0/A5-C4 peak overshoot = 4.06085 mV
A5-C0/A5-C4 recovery peak 2-12us = 3.61172 mV
A5-C0/A5-C4 recovery peak 12-40us = 3.59863 mV
A5-C0/A5-C4 final Vout error = 2.97793 mV
A5-C0/A5-C4 REQ/accepted/dropped = 149/149/0
```

A5-C4 reproduced the known A4 boundary: no-harm but non-improving for `40A -> 1A`. This confirmed the need for a severe-drop mechanism; it did not validate A5.

## Candidate Proxy Result

A5-T3/T4 introduced severe-drop proxy actions with area-hold / reentry bookkeeping:

```text
A5-T4proxy peak overshoot = 4.06085 mV
A5-T4proxy peak undershoot = 0.697797 mV
A5-T4proxy recovery peak 2-12us = 3.55696 mV
A5-T4proxy recovery peak 12-40us = 3.53370 mV
A5-T4proxy burst count / limit = 5 / 2
```

This was a real but small local recovery-peak reduction. It still failed the post-reentry burst guard, so it could not support a severe-drop improvement claim.

## R1 Pulse-Count Burst Limiting

R1 tested explicit burst limiting, optional area-integrator clamp, and Ton ramp:

```text
R1-T4a/b/c peak overshoot = 0 mV
R1-T4a/b/c recovery peaks = 0 mV
R1-T4a/b/c peak undershoot = 971.618 mV
R1-T4a/b/c final Vout error = -919.625 mV
R1-T4a/b/c REQ/accepted/dropped = 187/187/0
R1-T4a/b/c REQ reject count = 170
R1-T4a/b/c burst count / limit = 5 / 2
```

The zero positive peaks were not useful improvement. Pulse-count limiting suppressed positive peaks only by starving recovery energy and causing severe undershoot / final-error collapse.

## R2 Energy Shaping

R2 tested reentry Ton budget, Ton ramp, area-int soft preload, scheduler release ramp, and voltage-window release:

```text
R2-E1/E2 peak overshoot = 3.51629 mV
R2-E1/E2 recovery peak 2-12us = 1.75366 mV
R2-E1/E2 recovery peak 12-40us = 3.51629 mV
R2-E1/E2 peak undershoot = 7.63188 mV
R2-E1/E2 final Vout error = 2.89307 mV
R2-E1/E2 burst count / limit = 5 / 2
```

Energy budget plus Ton ramp reduced positive recovery peaks, but the result remained unsafe because the undershoot and burst guards failed.

```text
R2-E3/E4 peak overshoot = 0 mV
R2-E3/E4 recovery peaks = 0 mV
R2-E3/E4 peak undershoot = 971.618 mV
R2-E3/E4 final Vout error = -919.625 mV
R2-E3/E4 REQ reject count = 170
R2-E3/E4 burst count / limit = 5 / 2
```

Scheduler release gating at the tested insertion point starved recovery energy. The voltage-window flag did not fix that insertion semantics.

## R3 Event Queue

R3 tested event-queue / per-event Ton allocation:

```text
R3-E1/E2/E3 peak overshoot = 0 mV
R3-E1/E2/E3 recovery peaks = 0 mV
R3-E1/E2/E3 peak undershoot = 971.618 mV
R3-E1/E2/E3 final Vout error = -919.625 mV
R3-E1/E2/E3 burst count / limit = 5 / 2
R3-E1/E2/E3 phase_order_error_rate = 1
R3-E1/E2/E3 dropped_REQ_count = 0
R3-E1/E2/E3 queue_depth_final = 0
```

The queue and Ton accounting were observable, but the current insertion still suppressed positive peaks by starving the recovery trajectory. No R3 candidate is carried forward as a validated partial selector.

## Claim Boundary

E010-A5 is frozen as `MODEL_REVISED` evidence:

```text
Projected IQCOT scheduling tokens can provide useful medium load-drop protection,
but the severe 40A -> 1A branch remains unresolved.
```

For `40A -> 1A`, A5 projected scheduling variants repeatedly showed one of three outcomes:

```text
no improvement;
partial recovery-peak reduction with burst / undershoot guard failure;
positive-peak suppression caused by recovery starvation and final-error collapse.
```

Allowed claim:

```text
E010-A5 establishes a negative / revision boundary for projected supervisory scheduling
in the local ideal IQCOT severe 40A -> 1A load-drop case.
```

Forbidden claim:

```text
A5 improves or solves severe 40A -> 1A.
```

## Future Structural Direction

A future A6 concept would need to be structurally different from projected IQCOT scheduling. Candidate directions include:

```text
large-signal energy dump / clamp path
controlled synchronous recirculation mode
adaptive valley-current / zero-current enforcement
output-capacitor energy-aware protection
hybrid analog/digital fast overvoltage clamp
```

These are future-work concepts only. They are not implemented, not simulated, not validated, and outside the current projected-IQCOT scheduling claim.
