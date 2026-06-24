# R049F PR-ECB Early Ton-Truncation Trigger-Timing Diagnostic

Date: 2026-06-24

## Scope

R049F diagnoses the R049E failure mode.  R049E showed that the existing
over-voltage-triggered command-path Ton truncation was too late for the mild
`40A -> 20A` active-HS row.  R049F therefore uses the same two-offset chunk but
changes the trigger timing:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 load-step-synchronous early Ton truncation
```

The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx
```

It is generated through MATLAB APIs in:

```text
output/iqcot_r049f_build_early_tontrunc_model.m
```

No original `.slx`, no R048 source model, and no completed
R049A/R049B/R049C/R049D/R049E model were intentionally modified.  No raw `.slx`
XML was edited.

## Implemented diagnostic action

The completed R049E model already had the R049C Ton-command switch path.  R049F
copies that model and reconfigures the existing `R049C_TonTrunc_Global` logic:

```text
R049C/R049D/R049E:
    after_load_step AND before_window_end AND over_voltage

R049F:
    after_load_step AND before_window_end
```

For A2 rows:

| Parameter | Value |
|---|---:|
| `Tton_trunc_min` | `5 ns` |
| `Tton_trunc_window` | `80 ns` |

For A0 rows, the same model is used but `Tton_trunc_window = -1 ns`, so the
time window is impossible and the inserted path remains inactive.

## Validation chunk

The chunk is intentionally limited to four true-run rows:

| Dimension | Value |
|---|---|
| Load transition | `40A -> 20A` |
| Phase offsets | `0.05 us`, `0.105 us` |
| Controller cases | A0 same-model no-trunc, A2 early Ton truncation |
| Total true-run rows | `4` |

Outputs:

- `output/cutload_pr_ecb_control/r049f_early_tontrunc_plan.csv`
- `output/cutload_pr_ecb_control/r049f_early_tontrunc_results_full.csv`
- `output/cutload_pr_ecb_control/r049f_early_tontrunc_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049f_early_tontrunc_report_full.md`
- `output/data/*_r049f_early_tontrunc_wave.csv`

## Results

| Offset | A0 peak | A2 peak metric | A0 rem Ton4 | A2 rem Ton4 | A2 trunc | A2 final error | Interpretation |
|---:|---:|---:|---:|---:|---:|---:|---|
| `0.05 us` | `2.1103 mV` | `-184.1030 mV` | `52 ns` | `0 ns` | `80 ns` | `-239.1723 mV` | early global truncation removes active Ton but creates severe undervoltage |
| `0.105 us` | `2.0936 mV` | `-189.3089 mV` | `0 ns` | `0 ns` | `80 ns` | `-241.9473 mV` | same global action is unsafe even without phase-4 remaining Ton |

The A2 "peak metric" is negative because the waveform never returns above
`Vo_ref` in the measurement window.  This is not a successful overshoot
reduction.  It is a severe undershoot / brownout-like response.

## Diagnosis

R049F separates two questions:

1. **Can early command-path truncation affect the mild-load active high-side
   pulse?**  Yes.  At the `0.05 us` row, phase-4 remaining Ton changes from
   about `52 ns` to `0 ns`.
2. **Is the current early global all-phase action acceptable?**  No.  The same
   A2 action creates a large negative voltage excursion and final error in both
   offsets.

Therefore R049E's negative result was not because the Ton command path is
incapable.  It was because the over-voltage trigger arrived too late for the
mild-load active pulse.  However, R049F also shows that a load-step-synchronous
global Ton-min window is too aggressive and should not be used as the PR-ECB
first-peak action.

Revised action model:

```text
R049C/R049D:
    OV-triggered Ton truncation works for larger drops where the trigger
    intersects useful active-HS remaining energy.

R049E:
    the same OV trigger is too late for mild 40A -> 20A.

R049F:
    early timing can remove active-HS remaining Ton, but global all-phase early
    Ton-min truncation is unsafe / over-aggressive.
```

The next controller design should be phase-selective and state-gated rather
than global.

## Decision

```text
MODEL_REVISED
```

## Revised next validation

Do not expand to the full A matrix.  The next smallest useful step is R049G:
build a new derived-copy diagnostic that applies the early Ton-min action only
to the actively high-side phase, for example:

```text
ton_truncate_i = early_window AND qh_i
```

or a similarly phase-selective active-HS-only guard.  Reuse the same
`40A -> 20A` two-offset chunk and compare A0 against the phase-selective A2
variant.  The goal is to determine whether the severe R049F undervoltage came
from global all-phase truncation rather than early timing itself.

## Claim boundary

R049F remains derived-Simulink evidence only.  It does not prove hardware/HIL
safety, complete PR-ECB control, global calibration, or a universal additive
`E_HS,rem` law.
