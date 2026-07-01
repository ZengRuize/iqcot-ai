# Unresolved Gaps and Risks

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

## 1. E020 Late Recovery / Final Error

`a_U` improves early transient behavior but does not demonstrate `1 mV` settling. The R1-U1 final-error improvement over B3 is only `0.162402 mV` toward zero, and no R1 variant settled within `1 mV` by `90 us`.

Recommended next experiment: E020 settling audit, not E020-R2 tuning.

The audit should distinguish:

- transient-not-yet-settled;
- steady-state bias;
- model or measurement issue;
- control limitation.

## 2. Severe Load-Drop

A5 projected scheduling does not safely solve `40A -> 1A`. Tested A5 paths either fail to improve, reduce positive peaks with burst/undershoot guard failure, or starve recovery energy and collapse final error.

Recommended next step: keep A6 as structural future-work concept. Do not run A5-R4 projected-scheduling tweaks without a new structural hypothesis.

## 3. Calibration Realism

E030-R3 uses ideal calibration `g_hat_i = g_i` for the calibrated modes. That is useful to validate the projection architecture, but not practical calibration availability.

Recommended next experiment: imperfect-calibration mini-test with residual calibration error of `1%`, `2%`, and `5%`.

## 4. Active-Phase Generality

E040-A-R1 and E040-S1 are one-point confirmations. They validate local event integrity, not broad active-phase scheduling or efficiency improvement.

Recommended next experiment: minimal cross-check with one nearby add case and one nearby shed case, not a broad grid.

## 5. Simulink-Only Evidence

All current validation is derived Simulink evidence. It is not hardware, HIL, board-level, or silicon validation.

This limitation must remain explicit in every paper, figure caption, and claim boundary.
