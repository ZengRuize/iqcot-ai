# LOCAL AUDIT R049D PR-ECB Ton-Truncation Hold-Out

Date: 2026-06-24

## Scope

R049D runs one hold-out validation for the R049C command-path Ton-truncation
mechanism:

```text
40A -> 10A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx
```

It was created by copying the completed R049C Ton-truncation model through
`output/iqcot_r049d_build_tontrunc_holdout_model.m`.  No original `.slx`, no
R048 source model, and no completed R049A/R049B/R049C model were intentionally
modified.

## Validation

Key outputs:

- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_results_full.csv`
- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_report_full.md`
- `output/data/*_r049d_tontrunc_holdout_wave.csv`

Non-simulation preflight passed:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout R049D_holdout
```

## Results

| Offset | A0 peak | A2 peak | Improvement | A2 trunc | A2 remaining Ton4 | A2-A0 undershoot |
|---:|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `3.9908 mV` | `3.3873 mV` | `0.6036 mV` | `1.8700 us` | `2.0000 ns` | `+2.0279 mV` |
| `0.105 us` | `3.7607 mV` | `3.7607 mV` | `0.0000 mV` | `2.0000 us` | `0.0000 ns` | `0.0000 mV` |

## Diagnosis

The `40A -> 10A` hold-out matches the R049C phase-state mechanism.  At
`0.05 us`, where phase 4 has about `52 ns` remaining high-side on-time at the
load step, Ton truncation reduces the first peak and shortens remaining Ton to
about `2 ns`.  At `0.105 us`, where remaining Ton is already zero, the same
threshold logic does not change the first peak.

This strengthens the claim that command-path Ton truncation is an active-HS
first-peak energy-reduction action, while keeping the claim bounded to
derived-Simulink evidence and small hold-out chunks.

## Decision

```text
MODEL_CONFIRMED
```

## Next Step

Do not expand directly to the full A matrix.  Prefer one more minimal step:
either `40A -> 20A` with the same offsets, or a single-action reentry /
pulse-inhibit chunk that checks safe recovery after Ton truncation.

## Claim Boundary

R049D is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not a global PR-ECB calibration result, and not a
universal additive `E_HS,rem` law.
