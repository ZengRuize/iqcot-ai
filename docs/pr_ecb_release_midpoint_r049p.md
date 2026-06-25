# R049P PR-ECB Release-Midpoint Audit

Date: 2026-06-25

## Scope

R049P tests one narrow intermediate binary release point after R049O bracketed
the timing space:

```text
Tphase_release_delay = 1.600 us
```

The model and interface are unchanged from R049N/R049O:

```text
release_clock = t_load_step + Tphase_release_delay
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

No `.slx` structure was changed; R049P reuses:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

The run stayed minimal:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- A0 same-model baseline
- A2 `1.600 us` release midpoint
- Ton truncation disabled

## Quality gates

A0 baseline passed:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

A2 one-shot release fired:

| Offset | release_clock | one_shot_done | effective inhibit |
|---:|---:|---:|---:|
| `0.050 us` | `1.600 us` | `1.670 us` | `1.600 us` |
| `0.105 us` | `1.601 us` | `1.655 us` | `1.584 us` |

Ton truncation remained disabled.

## Results

The result is offset-selective:

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
| `0.105 us` | early local peak | `0.0000 mV` | `-0.2929 mV` | early undershoot penalty |
| `0.105 us` | recovery peak | `+0.1244 mV` | `-0.7873 mV` | useful but still penalized |
| `0.105 us` | late settling | `+0.0354 mV` | `+0.0492 mV` | late window improves |

Compared with R049N at `0.105 us`, R049P keeps a similar recovery peak
improvement (`+0.1244 mV` versus `+0.1205 mV`) while reducing the recovery
undershoot penalty (`-0.7873 mV` versus `-1.4429 mV`) and improving late
settling.  But it does nothing at `0.050 us`.

## Decision

```text
MODEL_REVISED
```

R049P is the first midpoint showing that binary release timing can reduce the
R049N penalty without becoming fully transparent, but the benefit is
offset-selective.  It supports another very narrow timing refinement or a
soft/ramped release, not a broad sweep or a confirmed controller claim.

## Evidence files

- `output/iqcot_r049p_pr_ecb_release_midpoint_audit.m`
- `output/iqcot_r049p_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049p_release_midpoint_plan.csv`
- `output/cutload_pr_ecb_control/r049p_release_midpoint_results_full.csv`
- `output/cutload_pr_ecb_control/r049p_release_midpoint_report_full.md`
- `output/cutload_pr_ecb_control/r049p_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049p_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049p_waveform_metric_summary.md`
- `output/data/*_r049p_release_midpoint_wave.csv`

## Next step

The next minimal step should not broaden the timing sweep.  Two reasonable
options remain:

1. test one slightly later point, e.g. `1.62-1.64 us`, to see whether the
   `0.050 us` row becomes active before the `0.105 us` undershoot worsens; or
2. implement a soft/ramped request restoration after the upstream release event.

## Claim boundary

R049P is derived-Simulink switching evidence only.  It is not hardware/HIL
validation and does not confirm PR-ECB controlled reentry.
