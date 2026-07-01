# Manuscript Claim Strategy

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

## Final Thesis

This work preserves the deterministic variable-frequency IQCOT inner loop and introduces a safety-projected supervisory layer for guarded action-token selection. The proposed supervisor does not command power-stage gates or external load-current slew. Instead, it selects bounded supervisory actions for load-rise enhancement, load-drop protection, sensing-aware current sharing, and active-phase event management.

## Allowed Contribution List

1. Safety-projected supervisory action-token framework around IQCOT.
2. Local `a_U` confirmation for early load-rise peak-undershoot reduction and current-rise acceleration.
3. Local `a_O` support for medium load-drop and explicit severe-drop boundary.
4. Local calibration-aware `a_S` current-sharing guard.
5. Local `a_N` add/shed event-integrity confirmation.
6. Claim-boundary-driven validation methodology.

## Forbidden Wording

- IQCOT cannot regulate load transients.
- AI replaces IQCOT.
- AI directly controls MOSFET gates.
- The method solves all load-rise/load-drop problems.
- A5 solves severe `40A -> 1A` load drop.
- E020 solves full `120A` recovery.
- Active Lambda is validated.
- Active-phase control proves efficiency improvement.
- Hardware/HIL/silicon validation is shown.

## Safe Abstract-Level Claim

The paper may claim a local derived-Simulink validation of a safety-projected supervisor around IQCOT, showing early load-rise improvement, medium load-drop protection, sensing-aware current-sharing guard behavior, and local active-phase event integrity. It must also report unresolved severe-drop and settling boundaries.

## Figure/Table Strategy

- Figure 1: architecture with IQCOT inner loop and projected supervisor outside the gate-command path.
- Figure 2: bidirectional large-signal charge/energy branches.
- Figure 3: E020 B0/B3/R1-U1 early load-rise comparison.
- Figure 4: E030-R3 real-vs-sensed current-sharing guard.
- Figure 5: E040 add/shed state-machine integrity.
- Table 1: action-token definitions and projection guards.
- Table 2: evidence index and claim boundary.
