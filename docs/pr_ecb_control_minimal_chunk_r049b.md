# R049B PR-ECB Minimal Over-Voltage Skip Chunk

Date: 2026-06-24

## Scope

This step continues after the R049A PR-ECB derived-control scaffold.  It builds
a new derived copy:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx
```

The model is generated only through MATLAB APIs in:

```text
output/iqcot_r049b_build_ovskip_model.m
```

No original `.slx` model and no R049A scaffold `.slx` were intentionally
modified.  No raw `.slx` XML was edited.

## Implemented protection action

R049B implements exactly one minimal action: simple over-voltage skip.

```text
Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip)
```

For the A1 rows, `Vov_skip = 2 mV`.  For same-model A0 rows, `Vov_skip =
1000 mV`, making the added gate inactive.

This action inhibits new accepted IQCOT requests after over-voltage is already
detected.  It does not truncate an already-active high-side pulse, does not
modify the IQCOT area-event request generator, and does not replace the
inner-loop COT/IQCOT gate generation.

## Validation chunk

The chunk is intentionally minimal:

| Dimension | Value |
|---|---|
| Load transition | `40A -> near0`, represented by `40A -> 1A` |
| Phase offsets | `0.05 us`, `0.105 us` |
| Controller cases | A0 same-model no-skip, A1 simple OV skip |
| Total true-run rows | `4` |

Outputs:

- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_plan.csv`
- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_results_full.csv`
- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049b_ovskip_minimal_report_full.md`
- `output/data/*_r049b_ovskip_wave.csv`

## Results

| Offset | A0 peak | A1 peak | Peak improvement | A1 inhibit duration | A1 skipped REQ |
|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `6.2586 mV` | `6.2586 mV` | `0.0000 mV` | `18.8800 us` | `19` |
| `0.105 us` | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` | `19.8160 us` | `20` |

The initial logging run exposed an implementation issue in the diagnostic
surface: the legacy `Vout` GotoTag did not match the logged `Voltage
Measurement` signal used for metrics.  The R049B build script was revised to
branch directly from `Voltage Measurement/1`, and a non-simulation update
diagram check passed afterward:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049b_ovskip direct_vout
```

After this fix, `ov_skip_raw` did trigger.  Therefore the final result is a
control-effect limitation, not a missing-comparator implementation issue.

## Diagnosis

The simple over-voltage skip gate successfully inhibits new requests, but it
does not reduce the first peak in the tested near0 cut-load offsets.  The first
peak is set before the post-detection request inhibit can remove the already
stored inductor/high-side energy.  This is consistent with the PR-ECB
large-signal view: active or recently active high-side energy must be handled by
an action that can reduce remaining energy injection, such as Ton truncation or
active-HS-aware pulse termination, not only by suppressing later requests.

The result narrows the A1 claim:

```text
simple OV skip = post-threshold request inhibit / skip-hold mechanism
simple OV skip != validated first-peak reduction mechanism
```

## Decision

```text
CLAIM_DOWNGRADED
```

## Revised next validation

Do not expand the A matrix from this A1 result.  The next useful chunk should be
another single-action derived-copy step:

1. implement minimal Ton truncation or active-HS remaining-on-time truncation;
2. reuse one load-drop magnitude crossed with two phase offsets;
3. compare against the same-model A0 baseline;
4. keep PR-ECB claims limited to derived-Simulink evidence.

## Claim boundary

R049B does not prove PR-ECB protection performance, hardware/HIL safety, global
PR-ECB calibration, or a universal additive `E_HS,rem` law.  It only shows that
simple over-voltage skip can be inserted as a derived-copy request-inhibit
mechanism and that, in this minimal near0 chunk, it does not reduce the
large-signal first peak.
