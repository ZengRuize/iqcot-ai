# R049I PR-ECB Gentle Phase-Selective Ton-Trim Chunk

Date: 2026-06-24

## Scope

R049I runs one minimal repaired-model action chunk.  It does not expand the A
matrix.  It copies the completed R049G repaired phase-selective model into:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx
```

The runner is:

```text
output/iqcot_r049i_pr_ecb_gentle_tontrim_chunk.m
```

The offline three-window audit is:

```text
output/iqcot_r049i_waveform_metric_audit.py
```

R049I compares:

```text
A0: same-model no trim, disabled negative window
A2: early_window AND qh_i with Tton_trunc_min = 120 ns
```

at the same `40A -> 20A` offsets used by R049G: `0.05 us` and `0.105 us`.

## Ton floor selection

R049I first audited the R049G baseline Ton traces:

| Offset | Ton command | qh4 at step | remaining Ton4 | elapsed on-time before step |
|---:|---:|---:|---:|---:|
| `0.050 us` | `196.5 ns` | `1` | `52.0 ns` | `144.5 ns` |
| `0.105 us` | `196.5 ns` | `0` | `0 ns` | not active |

The candidate `120 ns` floor is the gentlest end of the suggested
`80-120 ns` first-candidate band.  However, because the active phase has
already been on for about `144.5 ns` at the `0.05 us` load-step offset, a
`120 ns` whole-pulse Ton floor is already expired when the protection action
starts.  R049I therefore treats this candidate as a deliberate semantic test:
it is gentler than hard `5 ns`, but may still terminate the current active-HS
pulse quickly.

Model inspection confirmed this interpretation: `R049C_Ton_Switch4` directly
replaces the Ton input of `COT_Cell_1Phase4`; the floor is a whole-pulse Ton
command, not a remaining-on-time floor.

## Outputs

- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_results_full.csv`
- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_report_full.md`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_summary.md`
- `output/data/*_r049i_gentle_tontrim_wave.csv`

## Simulation result

| Offset | Controller | Peak | Peak time | remaining Ton4 | phase-4 trim duration | Final error |
|---:|---|---:|---:|---:|---:|---:|
| `0.050 us` | A0 no trim | `2.1103 mV` | `9.454 us` | `52.0 ns` | `0 us` | `-0.4397 mV` |
| `0.050 us` | A2 gentle trim | `2.3879 mV` | `0.898 us` | `2.0 ns` | `0.004 us` | `-0.4351 mV` |
| `0.105 us` | A0 no trim | `2.0936 mV` | `8.389 us` | `0 ns` | `0 us` | `-0.4344 mV` |
| `0.105 us` | A2 gentle trim | `2.0936 mV` | `8.389 us` | `0 ns` | `0 us` | `-0.4344 mV` |

The `120 ns` floor behaves like the hard R049G truncation at the active-HS
offset because it is already below the elapsed on-time of the active phase.

## R049H three-window audit

| Offset | Window | Peak improvement | A2-A0 max | A0 max time | A2 max time |
|---:|---|---:|---:|---:|---:|
| `0.050 us` | early local peak `0-2 us` | `-0.2902 mV` | `+0.2902 mV` | `0.484 us` | `0.898 us` |
| `0.050 us` | recovery peak `2-12 us` | `-0.0476 mV` | `+0.0476 mV` | `9.454 us` | `7.602 us` |
| `0.050 us` | late settling `12-80 us` | `-0.0866 mV` | `+0.0866 mV` | `12.716 us` | `12.042 us` |
| `0.105 us` | all windows | `0.0000 mV` | `0.0000 mV` | unchanged | unchanged |

## Decision

```text
MODEL_REVISED
```

R049I confirms the R049G/R049H model revision: hard or already-expired
phase-selective Ton floors can remove remaining active-HS Ton, but they worsen
the early local peak for this mild `40A -> 20A` active-HS offset.

## Next step

Per the R049I stopping rule, do not continue scanning Ton-min/Ton-floor
variants.  The next PR-ECB action should switch to either:

```text
deferred post-active pulse inhibit
```

or:

```text
controlled reentry
```

The smallest next chunk should avoid changing the current active-HS pulse after
it has already been on for most of its scheduled Ton, and should still use the
R049H three-window acceptance gate.

## Claim boundary

R049I is derived-Simulink switching evidence only.  It is not hardware/HIL
validation, not complete PR-ECB control, not global calibration, not proof that
AI replaces IQCOT, and not a universal additive `E_HS,rem` law.
