# LOCAL AUDIT R049B PR-ECB Minimal OV-Skip

Date: 2026-06-24

## Scope

R049B implements one minimal derived-copy PR-ECB protection action: simple
over-voltage request skip.  The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx
```

Construction used MATLAB APIs in:

```text
output/iqcot_r049b_build_ovskip_model.m
```

No original `.slx`, no R049A scaffold `.slx`, and no raw `.slx` XML were
intentionally edited.

## Validation

Ran the smallest chunk only:

```text
40A -> 1A near0
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-skip, A1 simple OV skip
```

Key outputs:

- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_results_full.csv`
- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_report_full.md`
- `output/data/*_r049b_ovskip_wave.csv`

## Results

| Offset | A0 peak | A1 peak | Improvement | A1 inhibit | Skipped REQ |
|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `6.2586 mV` | `6.2586 mV` | `0.0000 mV` | `18.8800 us` | `19` |
| `0.105 us` | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` | `19.8160 us` | `20` |

## Diagnosis

The first attempt showed `ov_skip=0` despite `vout > threshold`, because the
legacy `Vout` GotoTag was not the same diagnostic surface as the logged
`Voltage Measurement` used for metrics.  The model builder was revised to feed
the comparator directly from `Voltage Measurement/1`, and update-diagram passed:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049b_ovskip direct_vout
```

After the fix, the over-voltage skip signal did trigger and inhibited new
requests for about `19 us`, but the first peak remained unchanged.  Therefore
simple OV skip is a post-threshold request-inhibit / skip-hold mechanism in this
chunk, not a validated first-peak suppression mechanism.

## Decision

```text
CLAIM_DOWNGRADED
```

## Next Step

Do not expand the full A matrix from A1.  The next smallest useful step is a
new derived-copy action: minimal Ton truncation or active-HS remaining-on-time
truncation, again on one load-drop magnitude crossed with two phase offsets.

## Claim Boundary

R049B is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not a global PR-ECB calibration result, and not a
universal additive `E_HS,rem` law.
