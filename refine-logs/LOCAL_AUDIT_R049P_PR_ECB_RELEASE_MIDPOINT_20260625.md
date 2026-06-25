# LOCAL AUDIT R049P PR-ECB Release Midpoint

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## Scope

R049P tested a single intermediate binary release:

```text
Tphase_release_delay = 1.600 us
```

It reused the R049N upstream-causal release interface and ran the same
`40A -> 20A` offsets `0.050 us` and `0.105 us`.

## Result

The release fired in both A2 rows:

```text
0.050 us: release_clock=1.600 us, one_shot_done=1.670 us
0.105 us: release_clock=1.601 us, one_shot_done=1.655 us
```

Metrics were offset-selective:

- `0.050 us`: all three-window deltas were `0.0000 mV`; still transparent.
- `0.105 us`: recovery peak improved by `+0.1244 mV`; recovery undershoot
  worsened by `-0.7873 mV`, less severe than R049N; late window improved by
  `+0.0354 mV` peak and `+0.0492 mV` undershoot.

## Evidence

- `docs/pr_ecb_release_midpoint_r049p.md`
- `output/iqcot_r049p_pr_ecb_release_midpoint_audit.m`
- `output/iqcot_r049p_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049p_release_midpoint_results_full.csv`
- `output/cutload_pr_ecb_control/r049p_waveform_metric_summary.md`

## Next step

Test one slightly later point (`1.62-1.64 us`) or switch to soft/ramped
request restoration.  Do not broaden to a matrix yet.

## Claim boundary

R049P is derived-Simulink switching evidence only, not hardware/HIL validation
or a confirmed PR-ECB controller result.
