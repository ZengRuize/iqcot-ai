# R049R PR-ECB Release-Between-Point Audit

Date: 2026-06-25

## Scope

R049R tests one point between R049P and R049Q:

```text
Tphase_release_delay = 1.615 us
```

The objective is to locate whether the undershoot penalty worsens smoothly
between R049P `1.600 us` and R049Q `1.630 us`, or whether the binary release is
quantized by the next available scheduler/request event.

The model and causal interface are unchanged from R049N/R049O/R049P/R049Q:

```text
release_clock = t_load_step + Tphase_release_delay
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

No new `.slx` structure was intended for R049R.  The run reuses:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

The run stayed minimal:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- A0 same-model baseline
- A2 `1.615 us` release-between-point probe
- Ton truncation disabled

## Source-model check before running

The R049N derived `.slx` remained the source of truth.  MATLAB API inspection
showed the release and inhibit parameters are variable references, not hard
coded timing literals.

| Item | Actual `.slx` value | Init-script value | R049R simulation value | Reason |
|---|---|---|---|---|
| Release constant | `t_load_step + Tphase_release_delay` | not fixed by init script | `Tphase_release_delay=1.615e-6` | one between-point after R049P and before R049Q |
| Inhibit start | `t_load_step + Tpost_inhibit_delay` | injected per run | `0.070 us` | keep R049N/P/Q window |
| Inhibit end | `t_load_step + Tpost_inhibit_delay + Tpost_inhibit_window` | injected per run | `1.690 us` A2, disabled A0 | keep comparable gate |
| Release detector | relational `>=` | n/a | unchanged | upstream-causal release clock |
| Gate logic | `AND(existing_allow, NOT(inhibit_raw) OR one_shot_done)` | n/a | unchanged | keep R049N interface |
| Solver step for run | model `MaxStep=max_step_cont` | init dependent | `MaxStep=5e-9`, `Tss=5e-9` | match R049P/Q switching audit |

The controller class remains closed-loop COT-style request generation with
fixed-on-time pulse scheduling and an added upstream-causal reentry gate.  R049R
does not alter the power stage, MOSFET, inductor, capacitor, or base controller
parameters.

## Quality gates

A0 baseline passed:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

A2 one-shot release fired:

| Offset | release_clock | one_shot_done | effective inhibit |
|---:|---:|---:|---:|
| `0.050 us` | `1.616 us` | `1.670 us` | `1.600 us` |
| `0.105 us` | `1.615 us` | `1.655 us` | `1.584 us` |

Ton truncation remained disabled.

## Results

R049R is numerically identical to R049P in the R049H three-window metrics.  The
important observation is event quantization: although the release clock moved
from `1.600 us` to `1.615 us`, the actual `one_shot_done` event stayed at the
same scheduler/request event (`1.655 us` for the active `0.105 us` row).

| Offset | Global A0 peak | Global A2 peak | Global undershoot change |
|---:|---:|---:|---:|
| `0.050 us` | `2.1103 mV` | `2.1103 mV` | `0.0000 mV` |
| `0.105 us` | `2.0936 mV` | `1.9739 mV` | `+0.0492 mV` |

R049H three-window metrics:

| Offset | Window | Peak improvement | Undershoot improvement | Interpretation |
|---:|---|---:|---:|---|
| `0.050 us` | early local peak | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.050 us` | recovery peak | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.050 us` | late settling | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.105 us` | early local peak | `0.0000 mV` | `-0.2929 mV` | same as R049P |
| `0.105 us` | recovery peak | `+0.1244 mV` | `-0.7873 mV` | same as R049P |
| `0.105 us` | late settling | `+0.0354 mV` | `+0.0492 mV` | same as R049P |

Event comparison at `0.105 us`:

| Run | Release delay | one_shot_done | Recovery peak improvement | Recovery undershoot improvement |
|---|---:|---:|---:|---:|
| R049P | `1.600 us` | `1.655 us` | `+0.1244 mV` | `-0.7873 mV` |
| R049R | `1.615 us` | `1.655 us` | `+0.1244 mV` | `-0.7873 mV` |
| R049Q | `1.630 us` | `1.695 us` | `+0.1365 mV` | `-1.1109 mV` |
| R049N | `1.685 us` | `1.735 us` | `+0.1205 mV` | `-1.4429 mV` |

## Decision

```text
MODEL_REVISED
```

R049R is not a controller confirmation.  It shows that the binary release
timing is quantized by the next actual one-shot event.  The interval from
`1.600 us` to `1.615 us` is on the same event plateau as R049P, while R049Q
crosses to a later `1.695 us` event with a larger undershoot penalty.

## Evidence files

- `output/iqcot_r049r_pr_ecb_release_between_point_audit.m`
- `output/iqcot_r049r_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049r_release_between_point_plan.csv`
- `output/cutload_pr_ecb_control/r049r_release_between_point_results_full.csv`
- `output/cutload_pr_ecb_control/r049r_release_between_point_report_full.md`
- `output/cutload_pr_ecb_control/r049r_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049r_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049r_waveform_metric_summary.md`
- `output/data/*_r049r_release_between_point_wave.csv`

## Next step

Do not keep adding binary-delay points within the same plateau.  The next
minimal useful step should be one of:

1. identify the event boundary between the `1.655 us` and `1.695 us` one-shot
   plateaus with a structural/event audit rather than another full waveform
   matrix; or
2. implement soft/ramped request restoration so the release is no longer a
   hard binary step tied to the next scheduler/request event.

## Claim boundary

R049R is derived-Simulink switching evidence only.  It is not hardware/HIL
validation and does not confirm PR-ECB controlled reentry.
