# LOCAL AUDIT R049K PR-ECB Short Soft-Reentry Proxy

Date: 2026-06-25

## Scope

R049K ran one minimal controlled-reentry proxy chunk on the same `40A -> 20A`,
two-offset setup as R049G/R049I/R049J. It copied the completed R049I model into
a new derived file and tested A0 same-model no-inhibit versus A2 short
request-path soft reentry.

No original model, R048 source derived model, or completed R049A-J model was
modified in place.

## Boundary selection

R049J used a hard `0.070-2.000 us` post-active request inhibit and caused
multi-mV recovery undershoot penalties. R049K shortened the proxy to:

```text
Tpost_inhibit_delay  = 0.070 us
Tpost_inhibit_window = 1.690 us
end time             = 1.760 us
```

This end point is evidence-based: R049J/R049K waveform inspection places the
first future request / qh1 boundary around `1.678-1.690 us`.

## Outputs

- `output/iqcot_r049k_build_soft_reentry_model.m`
- `output/iqcot_r049k_pr_ecb_soft_reentry_chunk.m`
- `output/iqcot_r049k_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`
- `output/cutload_pr_ecb_control/r049k_soft_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049k_soft_reentry_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049k_soft_reentry_report_full.md`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_summary.md`
- `output/data/*_r049k_soft_reentry_wave.csv`

## Results

No current active-HS pulse truncation:

```text
0.05 us remaining Ton4: 52 ns -> 52 ns
global / phase Ton-trunc duration: 0 us
```

Request-path behavior:

```text
A2 soft-reentry duration: 1.69 us
A2 skipped REQ count: 1
first inhibit time: 0.07 us
0.05 us qh1 rise after release: about 1.772 us
```

Windowed comparison:

| Offset | Window | Peak improvement | Undershoot change |
|---:|---|---:|---:|
| `0.050 us` | early local peak | `0.0000 mV` | `-0.2917 mV` |
| `0.050 us` | recovery peak | `+0.1796 mV` | `-0.6388 mV` |
| `0.050 us` | late settling | `-0.1318 mV` | `-0.0261 mV` |
| `0.105 us` | early local peak | `0.0000 mV` | `-0.6663 mV` |
| `0.105 us` | recovery peak | `+0.1954 mV` | `-1.6588 mV` |
| `0.105 us` | late settling | `-0.0223 mV` | `+0.0547 mV` |

## Decision

```text
MODEL_REVISED
```

## Diagnosis

R049K shows that shortened request restoration is better than R049J's hard
`2 us` inhibit window, but still not sufficient as a fixed scalar gate. It
reduces the recovery undershoot penalty substantially, but also reduces the
positive recovery-peak benefit and introduces slight late positive-peak
penalties.

## Next Step

Stop scanning fixed scalar post-active inhibit windows. The next PR-ECB chunk
should test an explicit controlled-reentry proxy, such as edge-aligned one-shot
request restoration or phase-aware release, with the same R049H three-window
gate and explicit recovery undershoot penalty.

## Claim Boundary

R049K is derived-Simulink evidence only. It is not hardware/HIL validation, not
complete PR-ECB control, not global calibration, and not a universal additive
`E_HS,rem` law.
