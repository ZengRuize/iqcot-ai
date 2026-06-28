# IQCOT Inner Loop

## Role

The IQCOT inner loop is the deterministic real-time control layer. It is responsible for voltage-event detection, pulse request generation, phase selection, on-time realization, skip behavior, reentry, and gate command timing.

The AI/table supervisor is outside this fast loop. It may schedule bounded parameters, but it does not replace IQCOT event logic.

## Non-Negotiable Boundaries

- AI does not directly command `QH1..QH4` or `QL1..QL4`.
- AI does not directly insert pulses, delete pulses, or choose individual gate edges.
- AI does not command external load-current slew rate.
- AI may observe `Iload`, load-step direction, load-step magnitude, and estimated slew as disturbance descriptors.
- AI only proposes low-dimensional action tokens.
- Safety projection is mandatory before any token affects IQCOT parameters.

## Inner-Loop Signals

Required logged signals for validation:

```text
Vout
Iload
IL1..IL4
QH1..QH4
QL1..QL4
REQ1..REQ4
phase_idx
Ton_cmd_i
Ton_actual_i
Lambda_i
area_int_i
active_phase_set
```

If a signal is not present, the model wiring audit must either add logging to a derived copy or mark the experiment as blocked. Missing observability is an implementation issue, not evidence against the theory.

## Supervisory Parameters

The inner loop may accept projected supervisory parameters such as:

- global or per-branch protection level;
- on-time truncation or boost limits;
- pulse inhibit count and inhibit time;
- reentry band and release policy;
- common-mode `Lambda` reduction;
- differential `Ton` and `Lambda` trim;
- active-phase candidate and ramp policy.

The inner loop must treat these as bounded parameter updates, not as gate commands.

## Derived Model Rule

The baseline `.slx` file is the source reference for ideal IQCOT behavior. Any wiring change, logging change, parameter experiment, or controller variant must be implemented in a derived copy using MATLAB APIs such as `load_system`, `save_system`, `set_param`, `add_block`, `add_line`, and logging configuration commands. Raw `.slx` XML editing is forbidden.
