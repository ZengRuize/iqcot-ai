# R049D PR-ECB Ton-Truncation Hold-Out Chunk

Date: 2026-06-24

## Scope

R049D follows the R049C command-path Ton-truncation confirmation with one
hold-out load-drop magnitude:

```text
40A -> 10A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The new model is a copy of the completed R049C Ton-truncation model:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx
```

It is generated through MATLAB APIs in:

```text
output/iqcot_r049d_build_tontrunc_holdout_model.m
```

No original `.slx`, no R048 source model, and no completed R049A/R049B/R049C
model were intentionally modified.  No raw `.slx` XML was edited.

## Implemented protection action

R049D reuses the exact R049C command-path Ton-truncation mechanism:

```text
if t_load_step <= t <= t_load_step + Tton_trunc_window
   and Vout > Vo_ref + Vton_trunc_ov
then
   Ton_iqcot_i -> Tton_trunc_min
else
   Ton_iqcot_i unchanged
```

For A2 rows:

| Parameter | Value |
|---|---:|
| `Vton_trunc_ov` | `2 mV` |
| `Tton_trunc_min` | `5 ns` |
| `Tton_trunc_window` | `2 us` |

For A0 same-model rows, the threshold is set to `1000 mV` so the inserted path
remains inactive.

## Validation chunk

The chunk is intentionally limited to four true-run rows:

| Dimension | Value |
|---|---|
| Load transition | `40A -> 10A` |
| Phase offsets | `0.05 us`, `0.105 us` |
| Controller cases | A0 same-model no-trunc, A2 Ton truncation |
| Total true-run rows | `4` |

Outputs:

- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_plan.csv`
- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_results_full.csv`
- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_report_full.md`
- `output/data/*_r049d_tontrunc_holdout_wave.csv`

## Results

| Offset | Phase state | A0 peak | A2 peak | Peak improvement | A2 trunc duration | A2 remaining Ton4 | Secondary undershoot change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.05 us` | phase-4 active-HS boundary | `3.9908 mV` | `3.3873 mV` | `0.6036 mV` | `1.8700 us` | `2.0000 ns` | `+2.0279 mV` |
| `0.105 us` | post-turnoff reference | `3.7607 mV` | `3.7607 mV` | `0.0000 mV` | `2.0000 us` | `0.0000 ns` | `0.0000 mV` |

At the active-HS offset, Ton truncation reduced the first peak and shortened
phase-4 remaining high-side on-time from about `52 ns` to about `2 ns`.  It also
made the post-peak undershoot less negative in this chunk.  At the post-turnoff
offset, the peak and secondary response were unchanged, consistent with no
remaining active high-side on-time to remove.

## Diagnosis

R049D confirms that the R049C action hierarchy transfers to the `40A -> 10A`
hold-out:

```text
Ton truncation = first-peak active-HS energy-reduction action
OV skip        = post-threshold request-inhibit / SKIP_HOLD action
E_HS,rem       = phase-state segmentation feature, not a global additive law
```

This is a hold-out confirmation, not a full A-matrix result.  It supports the
active-HS phase-state mechanism across a second load-drop magnitude, while still
requiring cautious expansion or a separate reentry/pulse-inhibit chunk before
stronger PR-ECB controller claims.

## Decision

```text
MODEL_CONFIRMED
```

## Revised next validation

Do not jump to a full A matrix solely from R049C/R049D.  The next useful
small-step option is either:

1. one additional milder hold-out such as `40A -> 20A` at the same two offsets;
2. or a separate single-action reentry/pulse-inhibit chunk to check whether the
   confirmed Ton-truncation action can be paired with safe skip-hold recovery.

## Claim boundary

R049D remains derived-Simulink evidence only.  It does not prove hardware/HIL
safety, complete PR-ECB control, global calibration, improvement at all phase
offsets/load drops, or a universal additive `E_HS,rem` law.
