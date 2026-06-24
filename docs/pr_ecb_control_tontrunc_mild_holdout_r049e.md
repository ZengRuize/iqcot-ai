# R049E PR-ECB Ton-Truncation Mild Hold-Out Chunk

Date: 2026-06-24

## Scope

R049E tests whether the R049C/R049D command-path Ton-truncation mechanism also
transfers to a milder cut-load:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The new model is a copy of the completed R049D hold-out model:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx
```

It is generated through MATLAB APIs in:

```text
output/iqcot_r049e_build_tontrunc_holdout_model.m
```

No original `.slx`, no R048 source model, and no completed R049A/R049B/R049C/R049D
model were intentionally modified.  No raw `.slx` XML was edited.

## Validation chunk

The chunk is intentionally limited to four true-run rows:

| Dimension | Value |
|---|---|
| Load transition | `40A -> 20A` |
| Phase offsets | `0.05 us`, `0.105 us` |
| Controller cases | A0 same-model no-trunc, A2 Ton truncation |
| Total true-run rows | `4` |

Outputs:

- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_plan.csv`
- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_results_full.csv`
- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_report_full.md`
- `output/data/*_r049e_tontrunc_holdout_wave.csv`

## Results

| Offset | Phase state | A0 peak | A2 peak | Peak improvement | A2 trunc duration | A2 remaining Ton4 | Secondary undershoot change |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.05 us` | phase-4 active-HS boundary | `2.1103 mV` | `2.1103 mV` | `0.0000 mV` | `0.5180 us` | `52.0000 ns` | `0.0000 mV` |
| `0.105 us` | post-turnoff reference | `2.0936 mV` | `2.0936 mV` | `0.0000 mV` | `0.0000 us` | `0.0000 ns` | `0.0000 mV` |

## Diagnosis

R049E downgrades the broad generalization from R049C/R049D.  The same
over-voltage-triggered command-path Ton truncation that helped near0 and 10A
does not reduce the mild `40A -> 20A` first peak.

The active-HS row is especially diagnostic.  The A2 truncation flag did trigger,
but only from about `0.228 us` to `0.744 us` after the load step.  At the first
truncation sample, `qh4=0`, while the row still reports about `52 ns` of phase-4
remaining high-side on-time at the load-step instant.  Therefore the present
trigger is too late to remove that active high-side pulse in this mild-load
case.  The first peak occurs much later, at about `9.454 us`, and remains
unchanged.

Revised interpretation:

```text
Ton truncation helped when the over-voltage trigger intersected useful
remaining high-side energy in R049C/R049D.

For mild 40A -> 20A, over-voltage-triggered command-path truncation is too late
to be claimed as a general active-HS first-peak action.
```

This does not invalidate R049C/R049D.  It narrows the mechanism: the action is
phase-state and trigger-timing selective, not only phase-state selective.

## Decision

```text
CLAIM_DOWNGRADED
```

## Revised next validation

Do not expand to the full A matrix and do not keep repeating the same
over-voltage-triggered Ton-truncation hold-outs.  The next smallest useful step
is R049F: a trigger-timing diagnostic on the same `40A -> 20A` two-offset
chunk, for example a pre-threshold / load-step-synchronous active-HS truncation
variant.  Its goal should be to separate:

1. whether Ton-command truncation can reduce the mild-load active-HS pulse if it
   is asserted early enough;
2. from whether the current `Vout > Vo_ref + Vton_trunc_ov` trigger is too late
   for mild drops.

## Claim boundary

R049E remains derived-Simulink evidence only.  It does not prove hardware/HIL
safety, complete PR-ECB control, global calibration, or a universal additive
`E_HS,rem` law.
