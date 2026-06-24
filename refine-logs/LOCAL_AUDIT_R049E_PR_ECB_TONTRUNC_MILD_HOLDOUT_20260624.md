# LOCAL AUDIT R049E PR-ECB Ton-Truncation Mild Hold-Out

Date: 2026-06-24

## Scope

R049E runs one milder hold-out validation for the R049C/R049D command-path
Ton-truncation mechanism:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx
```

It was created by copying the completed R049D Ton-truncation hold-out model
through `output/iqcot_r049e_build_tontrunc_holdout_model.m`.  No original
`.slx`, no R048 source model, and no completed R049A/R049B/R049C/R049D model
were intentionally modified.

## Validation

Key outputs:

- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_results_full.csv`
- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_report_full.md`
- `output/data/*_r049e_tontrunc_holdout_wave.csv`

Non-simulation preflight passed:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout R049E_holdout
```

## Results

| Offset | A0 peak | A2 peak | Improvement | A2 trunc | A2 remaining Ton4 | A2-A0 undershoot |
|---:|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `2.1103 mV` | `2.1103 mV` | `0.0000 mV` | `0.5180 us` | `52.0000 ns` | `0.0000 mV` |
| `0.105 us` | `2.0936 mV` | `2.0936 mV` | `0.0000 mV` | `0.0000 us` | `0.0000 ns` | `0.0000 mV` |

## Diagnosis

R049E is a useful negative hold-out.  It shows that the current
over-voltage-triggered command-path Ton-truncation action should not be claimed
as a general active-HS first-peak action across all load-drop magnitudes.

In the `0.05 us` active-HS row, the A2 truncation flag first asserts around
`0.228 us` after the load step and deasserts around `0.744 us`.  At the first
truncation sample, `qh4=0`; the remaining high-side pulse present at the
load-step instant has already ended.  Consequently the measured phase-4
remaining Ton stays at about `52 ns`, and the first peak at about `9.454 us`
does not change.

## Decision

```text
CLAIM_DOWNGRADED
```

## Next Step

Do not expand the full A matrix.  R049F should diagnose trigger timing on the
same `40A -> 20A` two-offset chunk, for example with a pre-threshold /
load-step-synchronous active-HS truncation variant.  The aim is to determine
whether early assertion of the Ton command can affect the mild-load active-HS
pulse, or whether a different protection/reentry action is needed.

## Claim Boundary

R049E is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not a global PR-ECB calibration result, and not a
universal additive `E_HS,rem` law.
