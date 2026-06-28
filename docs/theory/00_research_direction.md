# Research Direction

## Target

The current IQCOT-AI research target is:

```text
Bidirectional large-signal voltage regulation
+ PIS-IEK small-signal current-sharing / phase-recovery model
+ active-phase add/shed hybrid event management
+ AI/table supervisor with safety projection
```

This target replaces earlier work that treated external load-current slew as a scheduled AI variable. Load current is an external disturbance. The supervisor may observe load-step direction, magnitude, estimated slew, and context, but it must not command the load-current trajectory.

## Architecture Boundary

IQCOT remains the fast deterministic pulse/event generator. It owns request detection, pulse timing, per-phase event selection, gate timing, and protection interlocks.

AI does not directly control gate commands. The AI/table supervisor only proposes low-dimensional supervisory action tokens:

```text
a_AI = [a_O, a_U, a_S, a_N]
```

Every proposed token must pass a model-based safety projection before it can affect IQCOT parameters. The projection may clamp, delay, replace, or reject a token when voltage protection, current limit, phase reentry, active-phase dwell, or current-sharing constraints would be violated.

## Regulation Scope

Large-signal voltage regulation is bidirectional:

- Load drop: overshoot / excess-current branch. The objective is to remove or reduce excess high-side energy injection, manage pulse inhibit, and reenter IQCOT without a secondary peak.
- Load rise: undershoot / deficit-current branch. The objective is to increase inductor current quickly enough to reduce undershoot while avoiding current limit, inductor saturation, and post-recovery overshoot.

The two branches are not symmetric. Load-drop protection mainly limits energy injection. Load-rise recovery mainly increases available energy delivery.

## Small-Signal Scope

PIS-IEK is the event-domain small-signal model for current sharing, phase spacing, reentry, and recovery around an operating trajectory. It should guide differential `Ton` trim, differential `Lambda` trim, and phase-spacing recovery after large-signal events.

The intended separation is:

- `Ton_diff`: mainly DC current sharing and slow per-phase current bias correction.
- `Lambda_diff`: mainly phase spacing, ripple cancellation, and event timing recovery.

## Active-Phase Scope

Active-phase add/shed is a hybrid event function for 1/2/4 active-phase operation. It must be coordinated with voltage protection and PIS-IEK balance recovery. It is disabled during protection and reentry unless the branch is load-rise add-phase protection.

## Evidence Standard

All future Simulink validation starts from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline model is not edited directly. Derived copies are created through MATLAB APIs only. Simulink-only evidence must not be described as hardware, silicon, board-level, or HIL validation.
