# LOCAL AUDIT R049L Repair PR-ECB Phase-Boundary Controlled Reentry

Date: 2026-06-25

## Decision

```text
IMPLEMENTATION_ISSUE
```

## What was repaired

The earlier external R049L result used a non-comparable baseline.  This repair
restored the R049K-compatible scenario:

- `t_load_step = 0.45 ms + offset`
- `40A -> 20A` at offsets `0.050 us` and `0.105 us`
- `Lambda_area = 6e-10`
- `Varea_bias = 2e-3`
- `Ri_area = 0.5e-3`
- `tau_ai = 1.25 us`
- `selected_ref_slew = 60 us`
- Ton truncation disabled with `Tton_trunc_window = -0.001 us`

The A0 baseline now matches R049K:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0.0 ns
```

## What failed

The attempted phase-boundary one-shot release used `qh1` rising during the
inhibit window:

```text
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
one_shot_done = first qh1 rising edge while inhibit_raw is true
```

This creates a circular dependency.  The request-path gate blocks the scheduler
pulse needed to create `qh1`, so no one-shot edge is observed:

```text
0.050 us A2: one_shot_edge_count=0, one_shot_time_us=NaN
0.105 us A2: one_shot_edge_count=0, one_shot_time_us=NaN
```

A2 therefore behaved like the R049K fixed `0.070-1.760 us` inhibit window, not
like an explicit controlled-reentry state machine.

## Metrics

The windowed metrics reproduce the R049K trade-off:

| Offset | Recovery peak improvement | Recovery undershoot change | Late positive peak change |
|---:|---:|---:|---:|
| `0.050 us` | `+0.1796 mV` | `-0.6388 mV` | `-0.1318 mV` |
| `0.105 us` | `+0.1954 mV` | `-1.6588 mV` | `-0.0223 mV` |

## Evidence

- `docs/pr_ecb_controlled_reentry_r049l_repair.md`
- `output/iqcot_r049l_repair_build_controlled_reentry_model.m`
- `output/iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk.m`
- `output/iqcot_r049l_repair_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx`
- `output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049l_repair_waveform_metric_summary.md`
- `output/data/*r049l_repair*controlled_reentry*wave.csv`

## Claim boundary

R049L repair is derived-Simulink switching evidence only.  It does not confirm
controlled reentry, does not validate PR-ECB in hardware/HIL, and does not
complete the PR-ECB controller.

## Next step

The next step should not use downstream `qh1` as the release trigger.  Identify
or expose an upstream phase-boundary signal that remains observable while
requests are inhibited, or implement an independent phase-clock / scheduler-slot
proxy before rerunning a one-shot controlled-reentry chunk.
