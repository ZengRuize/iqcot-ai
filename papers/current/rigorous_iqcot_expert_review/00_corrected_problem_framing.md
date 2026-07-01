# Corrected Problem Framing

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

This project does not frame IQCOT as lacking fundamental voltage regulation. IQCOT is retained as the deterministic fast variable-frequency inner loop.

The research problem is that, in a four-phase digital IQCOT system with supervisory enhancement actions, additional decisions are required:

- when to apply fast request / Ton boost;
- when to apply Ton truncation / pulse inhibit;
- when to apply current-sharing trim under sensing uncertainty;
- when and how to add or shed active phases;
- how to prevent these supervisory actions from violating voltage, current, REQ, phase-order, sensing, or residual-current guards.

The central contribution is safety-projected supervisory action-token selection, not replacement of IQCOT.

## Correct Supervisor Boundary

The deterministic IQCOT inner loop already provides fast variable-frequency voltage regulation. The proposed work does not replace the IQCOT inner loop and does not claim that IQCOT cannot respond to load transients. The contribution is a safety-projected supervisory layer for bounded action-token selection around IQCOT.

The AI/table supervisor does not command MOSFET gates and does not command the external load-current slew rate. Load current is an external disturbance. The supervisor may observe estimated load-step direction, magnitude, and slew, then propose bounded tokens that are projected before they can affect IQCOT parameters.

## Load-Rise / Load-Drop Separation

Load-rise and load-drop are separated at the supervisory-action level because external enhancement actions have opposite energy effects. The IQCOT inner loop naturally responds through variable-frequency pulse generation, while the supervisor selects bounded actions such as fast request, Ton boost, Ton truncation, pulse inhibit, current-sharing trim, and active-phase add/shed under safety guards.

This is a claim about safe event-domain augmentation around IQCOT, not a claim that baseline IQCOT lacks transient response.

## Evidence Status

The current evidence is local derived-Simulink evidence. It supports a set of guarded mechanisms and boundaries:

- `a_U`: local early load-rise dynamic regulation under the tested `40A -> 120A` case.
- `a_O`: local medium load-drop projected protection, with severe `40A -> 1A` unresolved.
- `a_S`: local calibration-aware current-sharing guard under one current-sense mismatch pattern.
- `a_N`: local add/shed event-integrity mechanisms under one add and one shed case.

No hardware, HIL, board-level, or silicon validation is claimed.
