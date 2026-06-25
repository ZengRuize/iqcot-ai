# LOCAL AUDIT R049Q PR-ECB Release Later Point

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## Scope

R049Q tested a single slightly later binary release after R049P:

```text
Tphase_release_delay = 1.630 us
```

It reused the R049N upstream-causal release interface and ran the same
`40A -> 20A` offsets `0.050 us` and `0.105 us`.

## Result

The release fired in both A2 rows:

```text
0.050 us: release_clock=1.630 us, one_shot_done=1.670 us
0.105 us: release_clock=1.631 us, one_shot_done=1.695 us
```

Metrics remained offset-selective:

- `0.050 us`: all three-window deltas were `0.0000 mV`; still transparent.
- `0.105 us`: recovery peak improved by `+0.1365 mV`, but recovery undershoot
  worsened by `-1.1109 mV`.
- Compared with R049P, the peak benefit is slightly stronger, but the recovery
  undershoot penalty is substantially worse and late peak becomes worse than
  A0.

## Evidence

- `docs/pr_ecb_release_later_point_r049q.md`
- `output/iqcot_r049q_pr_ecb_release_later_point_audit.m`
- `output/iqcot_r049q_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049q_release_later_point_results_full.csv`
- `output/cutload_pr_ecb_control/r049q_waveform_metric_summary.md`

## Next step

Do not move the binary release later again.  Test one point between R049P and
R049Q (`1.610-1.620 us`) or switch to soft/ramped request restoration.

## Claim boundary

R049Q is derived-Simulink switching evidence only, not hardware/HIL validation
or a confirmed PR-ECB controller result.
