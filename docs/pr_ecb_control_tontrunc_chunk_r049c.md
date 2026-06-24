# R049C PR-ECB Minimal Ton-Truncation Chunk

Date: 2026-06-24

## Scope

R049C continues after the R049B simple over-voltage skip downgrade.  It builds a
new derived copy:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049c_tontrunc.slx
```

The model is generated only through MATLAB APIs in:

```text
output/iqcot_r049c_build_tontrunc_model.m
```

No original `.slx`, no R048 source derived model, and no completed R049A/R049B
model were intentionally modified.  No raw `.slx` XML was edited.

## Implemented protection action

R049C implements exactly one new protection action: command-path Ton
truncation.

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

For A0 same-model rows, the threshold is set to `1000 mV` so the inserted
truncation path remains inactive.

This action tests whether the COT-cell Ton command path can terminate or
shorten a currently active high-side pulse.  It does not replace the IQCOT
request generator or gate-driver subsystem.

## Validation chunk

The chunk is intentionally minimal:

| Dimension | Value |
|---|---|
| Load transition | `40A -> near0`, represented by `40A -> 1A` |
| Phase offsets | `0.05 us`, `0.105 us` |
| Controller cases | A0 same-model no-trunc, A2 minimal Ton truncation |
| Total true-run rows | `4` |

Outputs:

- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_plan.csv`
- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_results_full.csv`
- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_report_full.md`
- `output/data/*_r049c_tontrunc_wave.csv`

## Results

| Offset | Active-HS class | A0 peak | A2 peak | Peak improvement | A2 trunc duration | A2 remaining Ton4 |
|---:|---|---:|---:|---:|---:|---:|
| `0.05 us` | phase-4 active-HS boundary | `6.2586 mV` | `5.4926 mV` | `0.7660 mV` | `2.0000 us` | `2.0000 ns` |
| `0.105 us` | post-turnoff reference | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` | `2.0000 us` | `0.0000 ns` |

At the active-HS offset, Ton truncation reduced the first peak and moved the
measured phase-4 remaining high-side on-time from about `52 ns` to about
`2 ns`.  At the post-turnoff offset, first-peak overshoot was unchanged, which
matches the phase-state interpretation: there was no remaining active high-side
on-time to remove.

## Diagnosis

R049C supports the revised PR-ECB action hierarchy introduced after R049B:

```text
simple OV skip:
    post-threshold request inhibit / SKIP_HOLD

Ton truncation:
    first-peak active-HS energy reduction mechanism
```

The result also supports keeping `E_HS,rem` as a segmentation feature rather
than a global additive law.  The useful control effect is tied to active-HS
state; post-turnoff rows should not be expected to improve merely because the
same threshold logic fires.

## Decision

```text
MODEL_CONFIRMED
```

## Revised next validation

Do not expand to the full A matrix yet.  The next useful step is a cautious
hold-out chunk using the same R049C Ton-truncation mechanism on one additional
load-drop magnitude crossed with the same two offsets.  A good R049D candidate
is:

```text
40A -> 10A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The goal is to check whether the active-HS benefit generalizes to a smaller
load drop without creating a new secondary-oscillation or reentry penalty.

## Claim boundary

R049C remains derived-Simulink evidence only.  It does not prove hardware/HIL
safety, complete PR-ECB control, global calibration, or a universal additive
`E_HS,rem` law.
