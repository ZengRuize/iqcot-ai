# R049G PR-ECB Phase-Selective Ton-Truncation Diagnostic

Date: 2026-06-24

## Scope

R049G continues from the R049F trigger-timing diagnostic on the same mild
cut-load chunk:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 repaired phase-selective early Ton truncation
```

The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx
```

It is generated through MATLAB APIs in:

```text
output/iqcot_r049g_build_phase_selective_tontrunc_model.m
```

No original `.slx`, no R048 source model, and no completed R049A/R049B/R049C/
R049D/R049E/R049F model were intentionally modified.  No raw `.slx` XML was
edited.

## Implementation repair

R049G found and repaired a latent timing-wiring issue exposed by R049F.  The
inherited `R049C_After_LoadStep` block had input 1 connected to `R049C_Clock`,
but input 2 was unconnected.  In R049C/R049D/R049E this was partly masked by
the over-voltage gate.  In R049F, removing the over-voltage gate made the
"early" Ton-truncation window start at simulation time zero instead of at
`t_load_step`.

R049G explicitly adds:

```text
R049G_LoadStep_Time = t_load_step
R049G_LoadStep_Time/1 -> R049C_After_LoadStep/2
```

The repaired model was checked directly:

```text
After_LoadStep in1: .../R049C_Clock
After_LoadStep in2: .../R049G_LoadStep_Time
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc R049G_repaired_phase_selective
```

## Implemented diagnostic action

R049G then changes the Ton switch controls from a global early window to a
per-phase active-HS guard:

```text
ton_truncate_i = early_window AND Memory(qh_i)
```

The one-step memory breaks a direct same-cycle feedback path from the gate
driver back into the Ton command switch.  A2 uses:

| Parameter | Value |
|---|---:|
| `Tton_trunc_min` | `5 ns` |
| `Tton_trunc_window` | `80 ns` |
| `Vton_trunc_ov` | `0 mV` |

A0 uses the same model with a negative time window to disable the action.

## Validation chunk

Outputs:

- `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_results_full.csv`
- `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_report_full.md`
- `output/data/*_r049g_phase_selective_tontrunc_wave.csv`

All four true-run rows completed successfully.

## Results

| Offset | A0 peak | A2 peak | Peak improvement | A0 rem Ton4 | A2 rem Ton4 | A2 phase-4 trunc | A2 final error |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `2.1103 mV` | `2.3879 mV` | `-0.2776 mV` | `52.0000 ns` | `2.0000 ns` | `0.0040 us` | `-0.4351 mV` |
| `0.105 us` | `2.0936 mV` | `2.0936 mV` | `0.0000 mV` | `0.0000 ns` | `0.0000 ns` | `0.0000 us` | `-0.4344 mV` |

At `0.05 us`, the phase-selective action worked structurally: only phase 4 was
truncated, and phase-4 remaining high-side on-time fell from about `52 ns` to
about `2 ns`.  But the first-peak metric worsened by `0.2776 mV`.

At `0.105 us`, where there was no remaining high-side Ton, A2 was identical to
A0.

The R049G wave audit split the active-HS `0.05 us` row into three windows:

| Window after load step | A0 max | A2 max |
|---|---:|---:|
| `0-2 us` | `2.0977 mV @ 0.484 us` | `2.3879 mV @ 0.898 us` |
| `2-12 us` | `2.1103 mV @ 9.454 us` | `2.1580 mV @ 7.602 us` |
| `12-80 us` | `1.9392 mV` | `2.0258 mV` |

## Diagnosis

R049G has two conclusions:

1. The severe R049F/R049G pre-repair undervoltage was an implementation timing
   artifact, not valid evidence against phase-selective control.  The early
   window lacked an explicit `t_load_step` lower bound after the over-voltage
   gate was removed.
2. After repairing the lower bound, phase-selective hard Ton-min truncation is
   still not a confirmed PR-ECB action for the mild `40A -> 20A` active-HS row.
   It can remove active remaining Ton, but it introduces or amplifies an earlier
   local positive spike and does not improve the overall first-peak metric.

The action hierarchy should therefore be revised:

```text
Hard active-HS Ton-min truncation:
  structurally effective at removing remaining Ton
  but not yet safe/useful for mild 20A first-peak reduction.

PR-ECB metric:
  must distinguish immediate local spike risk from later recovery-peak risk.

SKIP_HOLD / reentry:
  remains a separate post-threshold request-inhibit and recovery action.
```

## Decision

```text
MODEL_REVISED
```

## Revised next validation

Do not expand to a full A matrix and do not repeat hard Ton-min truncation
blindly.  The next smallest useful step is R049H: an offline waveform-metric
audit on existing R049C/R049D/R049E/R049F/R049G wave exports that separates:

```text
early local peak window:     0-2 us after load step
recovery peak window:        2-12 us after load step
late settling / undershoot:  12-80 us after load step
```

R049H should update the PR-ECB/state-machine wording before any new action
chunk.  Candidate future actions after R049H include gentler Ton trim, deferred
post-active pulse inhibit, or controlled reentry, but those should not be run
until the segmented metric is documented.

## Claim boundary

R049G is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not global calibration, not proof that
phase-selective Ton truncation is safe, and not a universal additive
`E_HS,rem` law.
