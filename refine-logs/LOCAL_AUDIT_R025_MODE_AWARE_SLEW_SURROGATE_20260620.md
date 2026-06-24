# LOCAL AUDIT R025 MODE-AWARE SLEW SURROGATE 2026-06-20

## Scope

R025 post-processing for four-phase digital IQCOT / PIS-IEK research:
mode-aware continuous `T_slew` score surrogate and safety projection design.

## Inputs

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_report.md`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv`

## New Artifacts

- `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate.py`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_dataset.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate_coefficients.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate_eval.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_context_bands.csv`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate_report.md`
- `E:/Desktop/codex/output/iqcot_mode_aware_slew_paper_section.md`
- `E:/Desktop/codex/output/figures/fig32_mode_aware_slew_surrogate.svg`
- `E:/Desktop/codex/research-wiki/experiments/mode-aware-slew-surrogate.md`

## Result Summary

- Plant-level rows: `69`.
- Objective-expanded rows: `207`.
- Policy-eval rows: `45` (`9` target/objective contexts x `5` policies).
- Policy-summary rows: `5`.

### Surrogate Metrics

- Smooth quadratic context model in-sample RMSE: `0.855`.
- Mode-aware score surrogate in-sample RMSE: `0.101`.
- Leave-one-target RMSE remains high:
  - smooth: `10.192`
  - mode-aware: `5.940`

Interpretation: mode-aware post-processing explains current data much better,
but target extrapolation is not solved.

### Policy Metrics

- Combined-grid oracle mean regret: `0.000`.
- Mode-aware safety projection mean regret: `0.064`.
- Near-optimal band clipping mean regret: `0.101`.
- Dense+long table baseline mean regret: `0.163`.
- Naked quadratic continuous mean regret: `0.654`, max regret `2.429`.

Interpretation: naked smooth continuous minimization is vulnerable to
skip/reentry non-smoothness.  Mode-aware clipping is a stronger design rule on
the completed grid, but it is still offline post-processing.

## Local Checks

- Python compile check for `iqcot_mode_aware_slew_surrogate.py`: passed.
- Required output artifacts exist.
- Row-count check: `207` dataset rows, `45` policy rows, `5` policy summary rows.
- Claim-boundary grep found only boundary/forbidden-claim wording around
  global optimum, hardware validation, and AI-in-loop; no unsupported positive
  claim was introduced.

## Boundary

- R025 does not run Simulink.
- R025 is not neural-network AI-in-loop.
- R025 is not hardware validation.
- `skip_count_est`, phase std, and settling time are post-processed metrics in
  R025; a deployable AI supervisor would need to estimate or predict them.
- The supported claim is: mode-aware safety projection is a better continuous
  `T_slew` design direction than naked smooth minimization.

