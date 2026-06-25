# LOCAL AUDIT R049R PR-ECB Release Between Point

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## Scope

R049R tested a single binary release point between R049P and R049Q:

```text
Tphase_release_delay = 1.615 us
```

It reused the R049N upstream-causal release interface and ran the same
`40A -> 20A` offsets `0.050 us` and `0.105 us`.

## Result

The release fired in both A2 rows:

```text
0.050 us: release_clock=1.616 us, one_shot_done=1.670 us
0.105 us: release_clock=1.615 us, one_shot_done=1.655 us
```

Metrics were identical to R049P:

- `0.050 us`: all three-window deltas were `0.0000 mV`.
- `0.105 us`: recovery peak improved by `+0.1244 mV`; recovery undershoot
  worsened by `-0.7873 mV`; late settling improved.

The important finding is event quantization.  R049P `1.600 us` and R049R
`1.615 us` both release on the same `1.655 us` one-shot event.  R049Q
`1.630 us` crosses to a later `1.695 us` event and pays a much larger
undershoot penalty.

## Evidence

- `docs/pr_ecb_release_between_point_r049r.md`
- `output/iqcot_r049r_pr_ecb_release_between_point_audit.m`
- `output/iqcot_r049r_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049r_release_between_point_results_full.csv`
- `output/cutload_pr_ecb_control/r049r_waveform_metric_summary.md`

## Next step

Do not run more binary-delay points on the same plateau.  Either audit the
event boundary between `1.655 us` and `1.695 us`, or implement soft/ramped
request restoration.

## Claim boundary

R049R is derived-Simulink switching evidence only, not hardware/HIL validation
or a confirmed PR-ECB controller result.
