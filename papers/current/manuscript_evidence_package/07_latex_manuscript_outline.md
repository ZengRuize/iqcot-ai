# LaTeX Manuscript Outline

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

Title:

```text
Safety-Projected Supervisory Action Tokens for Four-Phase Digital IQCOT Buck Converters
```

## Abstract

Section goal: State the corrected contribution and the local evidence scope.

Key evidence: E020/R1, E030-R3, E040-A-R1, E040-S1, E010-A5 boundary.

Figure/table: Table 1.

Allowed claim: Safety-projected supervisory action-token framework around deterministic IQCOT.

Forbidden wording: AI replaces IQCOT; IQCOT cannot regulate load transients.

## I. Introduction

Section goal: Motivate supervisory event management around four-phase digital IQCOT without attacking the inner loop.

Key evidence: Expert review framing and claim boundaries.

Figure/table: Figure 1 or Figure 2.

Allowed claim: IQCOT is retained as the fast variable-frequency inner loop.

Forbidden wording: AI fixes a basic IQCOT voltage-regulation defect.

## II. Related Work and Motivation

Section goal: Place the work among COT/IQCOT, multiphase current sharing, active-phase management, and constrained supervision.

Key evidence: Citation scaffold only; do not fabricate citations.

Figure/table: Citation checklist.

Allowed claim: The manuscript requires literature coverage across COT, multiphase, active phase, and safety projection.

Forbidden wording: Unsupported novelty claims before citation audit.

## III. Digital IQCOT Baseline and Four-Phase Implementation

Section goal: Describe baseline model role and validation source.

Key evidence: `models/baseline/baseline_manifest.md`; E001 audit; local ideal baseline path.

Figure/table: System architecture figure.

Allowed claim: All current simulations are derived from the local ideal IQCOT baseline.

Forbidden wording: Baseline `.slx` was modified directly.

## IV. Safety-Projected Supervisory Action Tokens

Section goal: Define `a_AI = [a_O, a_U, a_S, a_N]` and `P_safe`.

Key evidence: `docs/theory/04_ai_action_space_and_projection.md`.

Figure/table: Figure 1; Table 2.

Allowed claim: Supervisor proposes low-dimensional tokens under projection.

Forbidden wording: AI directly commands MOSFET gates or load-current slew.

## V. Load-Transient Actions: `a_U` and `a_O`

Section goal: Present bidirectional large-signal branches and current evidence.

Key evidence: E020/B3/R1-U1; E010 medium; E010-A5 boundary.

Figure/table: Figure 3, Figure 4, Table 3.

Allowed claim: `a_U` is locally confirmed for early load-rise dynamics; `a_O` has medium-drop local support and severe-drop boundary evidence.

Forbidden wording: Full `120A` recovery; severe `40A -> 1A` solved.

## VI. Sensing-Aware Current-Sharing Action: `a_S`

Section goal: Present current-sense mismatch risk and calibrated/confidence-guarded projection.

Key evidence: E030-R2 and E030-R3.

Figure/table: Figure 5; Table 4.

Allowed claim: One local calibration-aware guard pattern is confirmed.

Forbidden wording: Broad mismatch robustness; active Lambda validated.

## VII. Active-Phase Event-Integrity Action: `a_N`

Section goal: Explain add/shed as guarded hybrid event management.

Key evidence: E040-A-R1 and E040-S1.

Figure/table: Figure 6; Table 4.

Allowed claim: One local add and one local shed event-integrity point are confirmed.

Forbidden wording: Arbitrary `1/2/4` scheduling or efficiency improvement.

## VIII. Local Derived-Simulink Validation

Section goal: Consolidate experiment matrix and classification.

Key evidence: Evidence index and all metrics CSV paths.

Figure/table: Table 4.

Allowed claim: Local derived Simulink evidence supports specified mechanisms.

Forbidden wording: Hardware/HIL/board/silicon validation.

## IX. Claim Boundaries and Limitations

Section goal: Make unresolved boundaries reviewer-visible.

Key evidence: Claim boundary table and reviewer risk register.

Figure/table: Claim boundary table.

Allowed claim: The paper is claim-boundary-driven.

Forbidden wording: Broad robustness or global optimality.

## X. Conclusion

Section goal: Summarize contribution and next validation path.

Key evidence: E020 early benefit, E030-R3 guard, E040 local event integrity, E010 severe boundary.

Figure/table: None required.

Allowed claim: The framework organizes safe supervisory action selection around IQCOT and identifies clear next validation steps.

Forbidden wording: Complete solution to all load transients.
