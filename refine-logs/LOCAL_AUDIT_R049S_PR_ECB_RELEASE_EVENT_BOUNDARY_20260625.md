# LOCAL AUDIT R049S PR-ECB Release Event Boundary

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## Scope

R049S tested the active `0.105 us` offset with five binary release delays:

```text
1.615, 1.616, 1.620, 1.625, 1.630 us
```

It reused the R049N upstream-causal release interface and did not change the
`.slx` structure.

## Result

The one-shot event is quantized by `Ts_ctrl=40 ns`:

```text
1.615 us -> one_shot_done 1.655 us
1.616 us -> one_shot_done 1.695 us
1.620 us -> one_shot_done 1.695 us
1.625 us -> one_shot_done 1.695 us
1.630 us -> one_shot_done 1.695 us
```

The predicted sampled one-shot time matched simulation with effectively
`0 ns` error.

Waveform metrics formed two plateaus:

- `1.655 us` event: recovery peak `+0.1244 mV`, recovery undershoot
  `-0.7873 mV`, late peak `+0.0354 mV`.
- `1.695 us` event: recovery peak `+0.1365 mV`, recovery undershoot
  `-1.1109 mV`, late peak `-0.0666 mV`.

## Evidence

- `docs/pr_ecb_release_event_boundary_r049s.md`
- `output/iqcot_r049s_release_event_boundary_audit.m`
- `output/iqcot_r049s_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049s_release_event_boundary_results_full.csv`
- `output/cutload_pr_ecb_control/r049s_waveform_metric_summary.md`

## Next step

Stop scalar binary-delay refinement.  Implement a true soft/ramped restore
token or a one-cycle staged restore that changes the release action rather than
the sampled release time.

## Claim boundary

R049S is derived-Simulink switching evidence only, not hardware/HIL validation
or a confirmed PR-ECB controller result.
