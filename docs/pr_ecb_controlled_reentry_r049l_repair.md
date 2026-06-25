# R049L Repair PR-ECB Phase-Boundary Controlled-Reentry Audit

Date: 2026-06-25

## Scope

R049L repair revisits the external R049L one-shot controlled-reentry result
after the supervisor review found its A0 baseline non-comparable with R049K.

The repair chunk uses the same minimal scope as R049K:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- A0 same-model no-reentry-control
- A2 phase-boundary one-shot controlled-reentry proxy
- Ton truncation disabled in A0 and A2

All model changes were made through MATLAB / Simulink APIs on a derived copy:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx
```

No original model, R048 source model, or completed R049A-K model was modified.

## Baseline repair

The repair runner restores R049K-compatible timing and operating parameters:

```text
t_load_step = 0.45 ms + offset
Lambda_area = 6e-10
Varea_bias  = 2e-3
Ri_area     = 0.5e-3
tau_ai      = 1.25 us
ref_slew    = 60 us
Tton_trunc_window = -0.001 us
```

A0 baseline now matches R049K within the requested gate:

| Offset | t_load_step | A0 peak | qh4 at step | remaining Ton4 | Baseline gate |
|---:|---:|---:|---:|---:|---|
| `0.050 us` | `450.050 us` | `2.1103 mV` | `1` | `50.5 ns` | pass |
| `0.105 us` | `450.105 us` | `2.0936 mV` | `0` | `0.0 ns` | pass |

## A2 design tested

The repaired A2 design attempted:

```text
inhibit_raw = t_load_step + 0.070 us through 1.690 us
one_shot_done = first qh1 rising edge during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

The intent was to replace R049K's fixed scalar soft-reentry window with a
phase-boundary one-shot release.

## Result

```text
IMPLEMENTATION_ISSUE
```

The A0 baseline is fixed, but the one-shot state did not actually fire:

| Offset | A2 inhibit_raw | A2 effective inhibit | one_shot_edge_count | one_shot_time |
|---:|---:|---:|---:|---:|
| `0.050 us` | `1.690 us` | `1.690 us` | `0` | `NaN` |
| `0.105 us` | `1.690 us` | `1.690 us` | `0` | `NaN` |

The reason is a circular dependency.  The request-path gate suppresses the
scheduler pulse that would have produced the `qh1` rising edge, so `qh1` cannot
serve as the release trigger while it is also downstream of the inhibit gate.

Because `one_shot_done` never asserted, A2 effectively reproduced the fixed
`0.070-1.760 us` inhibit-window behavior already studied in R049K, including
the same recovery undershoot / late-peak trade-off.  This is not evidence that
controlled reentry is ineffective; it is a wiring/trigger-source issue.

## Windowed audit

| Offset | Window | Peak improvement | Undershoot change | Interpretation |
|---:|---|---:|---:|---|
| `0.050 us` | early local peak | `0.0000 mV` | `-0.2917 mV` | no early benefit |
| `0.050 us` | recovery peak | `+0.1796 mV` | `-0.6388 mV` | same R049K trade-off |
| `0.050 us` | late settling | `-0.1318 mV` | `-0.0261 mV` | late positive peak penalty |
| `0.105 us` | early local peak | `0.0000 mV` | `-0.6663 mV` | no early benefit |
| `0.105 us` | recovery peak | `+0.1954 mV` | `-1.6588 mV` | same R049K trade-off |
| `0.105 us` | late settling | `-0.0223 mV` | `+0.0547 mV` | small late peak penalty |

## Evidence files

- `output/iqcot_r049l_repair_build_controlled_reentry_model.m`
- `output/iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk.m`
- `output/iqcot_r049l_repair_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049l_repair_controlled_reentry_report_full.md`
- `output/cutload_pr_ecb_control/r049l_repair_waveform_metric_summary.md`
- `output/data/*r049l_repair*controlled_reentry*wave.csv`

## Next step

Do not continue with qh1-downstream one-shot release.  The next minimal step
should use a release trigger that is not suppressed by the request-path gate:

1. an internal scheduler phase-boundary signal upstream of `allow_to_scheduler`,
2. an independent phase clock / predicted slot boundary derived from the
   scheduler state, or
3. an offline boundary audit that first proves which upstream signal remains
   observable during request inhibition.

Do not promote R049L repair as a confirmed PR-ECB action, do not describe it as
hardware/HIL evidence, and do not treat the fixed-window-like metrics as a new
controlled-reentry result.
