# LOCAL AUDIT R049C PR-ECB Ton Truncation

Date: 2026-06-24

## Scope

R049C implements one new derived-copy PR-ECB protection action: command-path Ton
truncation during the first cut-load window.  The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049c_tontrunc.slx
```

Construction used MATLAB APIs in:

```text
output/iqcot_r049c_build_tontrunc_model.m
```

No original `.slx`, no R048 source model, and no R049A/R049B completed model
were intentionally modified.

## Validation

Ran the smallest chunk only:

```text
40A -> 1A near0
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

Key outputs:

- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_results_full.csv`
- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_report_full.md`
- `output/data/*_r049c_tontrunc_wave.csv`

## Results

| Offset | A0 peak | A2 peak | Improvement | A2 trunc | A2 remaining Ton4 |
|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `6.2586 mV` | `5.4926 mV` | `0.7660 mV` | `2.0000 us` | `2.0000 ns` |
| `0.105 us` | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` | `2.0000 us` | `0.0000 ns` |

## Diagnosis

The R049C command-path Ton truncation mechanism reduces first peak only when an
active-HS remaining-on-time feature exists.  It shortened the phase-4 remaining
high-side on-time from about `52 ns` to about `2 ns` at the `0.05 us` offset.
At `0.105 us`, where remaining Ton was already zero, the peak was unchanged.

This confirms the R049B revision: simple OV skip is a skip-hold action, while
Ton truncation is the first-peak active-HS energy-reduction action.

## Decision

```text
MODEL_CONFIRMED
```

## Next Step

Do not expand to the full A matrix yet.  R049D should run one hold-out load
magnitude, preferably `40A -> 10A`, crossed with the same two offsets
(`0.05 us`, `0.105 us`) using the same R049C Ton-truncation mechanism and
A0/A2 comparison.

## Claim Boundary

R049C is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not a global PR-ECB calibration result, and not a
universal additive `E_HS,rem` law.
