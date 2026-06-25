# R049S PR-ECB Release-Event Boundary Audit

Date: 2026-06-25

## Scope

R049S validates the signal-model update implied by R049R: binary release delay
does not act as a smooth waveform-control knob.  It is quantized by the
controller update event that drives `one_shot_done`.

The targeted micro-audit uses only the active `40A -> 20A`, `0.105 us` offset:

```text
Tphase_release_delay = 1.615, 1.616, 1.620, 1.625, 1.630 us
```

The model and causal interface are unchanged from R049N/R049O/R049P/R049Q/R049R:

```text
release_clock = t_load_step + Tphase_release_delay
one_shot_done = first sampled release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

No new `.slx` structure was intended for R049S.  The run reuses:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

## Source-model and timing check

MATLAB initialization gives:

```text
Ts_ctrl = 40 ns
```

The R049N derived `.slx` release constant remains:

```text
t_load_step + Tphase_release_delay
```

R049S therefore tests the signal model:

```text
one_shot_done_time ≈ next UnitDelay output event after release_clock is sampled high
```

For the active `0.105 us` offset, the predicted one-shot events are:

| Release delay | Simulated one-shot | Predicted one-shot | Error |
|---:|---:|---:|---:|
| `1.615 us` | `1.655 us` | `1.655 us` | `0.00 ns` |
| `1.616 us` | `1.695 us` | `1.695 us` | `0.00 ns` |
| `1.620 us` | `1.695 us` | `1.695 us` | `0.00 ns` |
| `1.625 us` | `1.695 us` | `1.695 us` | `0.00 ns` |
| `1.630 us` | `1.695 us` | `1.695 us` | `0.00 ns` |

The boundary is between `1.615 us` and `1.616 us`.  A `1 ns` change in the
release-delay input causes a `40 ns` jump in the actual one-shot event.

## Waveform gate

A0 baseline passed:

```text
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

R049H three-window metrics show exactly two event plateaus:

| Release delay | one-shot | Recovery peak improvement | Recovery undershoot improvement | Late peak improvement |
|---:|---:|---:|---:|---:|
| `1.615 us` | `1.655 us` | `+0.1244 mV` | `-0.7873 mV` | `+0.0354 mV` |
| `1.616 us` | `1.695 us` | `+0.1365 mV` | `-1.1109 mV` | `-0.0666 mV` |
| `1.620 us` | `1.695 us` | `+0.1365 mV` | `-1.1109 mV` | `-0.0666 mV` |
| `1.625 us` | `1.695 us` | `+0.1365 mV` | `-1.1109 mV` | `-0.0666 mV` |
| `1.630 us` | `1.695 us` | `+0.1365 mV` | `-1.1109 mV` | `-0.0666 mV` |

## Decision

```text
MODEL_REVISED
```

R049S confirms the improved signal model: binary release timing is sampled and
event-quantized.  Further scalar binary-delay sweeps are low value unless they
target a predicted event boundary.  The next useful controller revision should
change the restore action itself, for example by introducing soft/ramped
request restoration instead of a hard latch.

## Evidence files

- `output/iqcot_r049s_release_event_boundary_audit.m`
- `output/iqcot_r049s_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049s_release_event_boundary_plan.csv`
- `output/cutload_pr_ecb_control/r049s_release_event_boundary_results_full.csv`
- `output/cutload_pr_ecb_control/r049s_release_event_boundary_report_full.md`
- `output/cutload_pr_ecb_control/r049s_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049s_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049s_waveform_metric_summary.md`
- `output/data/*_r049s_release_event_boundary_wave.csv`

## Next step

Implement the first true soft/ramped restore token.  The design should avoid
pretending that a hard binary release delay can continuously tune the waveform.
Candidate next test:

```text
R049T: upstream-causal release plus one-cycle or ramped request restoration
```

## Claim boundary

R049S is derived-Simulink switching evidence only.  It is not hardware/HIL
validation and does not confirm PR-ECB controlled reentry.
