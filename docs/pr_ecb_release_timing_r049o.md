# R049O PR-ECB Release-Timing Micro-Audit

Date: 2026-06-25

## Scope

R049O reuses the R049N upstream-causal independent release-clock interface and
tests whether earlier binary release reduces the R049N recovery undershoot
penalty.

No new controller structure was added.  The same R049N derived model was used:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

The only swept variable was:

```text
Tphase_release_delay = 1.250 us or 1.450 us
```

The run stayed intentionally small:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- one A0 baseline per offset
- two A2 release-timing probes per offset
- Ton truncation disabled

## Quality gates

The repaired A0 baseline remained valid:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

Both earlier release delays fired:

| Offset | Delay | release_clock | one_shot_done | effective inhibit |
|---:|---:|---:|---:|---:|
| `0.050 us` | `1.250 us` | `1.250 us` | `1.310 us` | `1.240 us` |
| `0.050 us` | `1.450 us` | `1.450 us` | `1.510 us` | `1.440 us` |
| `0.105 us` | `1.250 us` | `1.251 us` | `1.295 us` | `1.224 us` |
| `0.105 us` | `1.450 us` | `1.451 us` | `1.495 us` | `1.424 us` |

Ton truncation remained disabled.

## Windowed result

R049O produced no measurable waveform delta from A0 in the R049H windows:

| Offset | Delay | early peak improvement | recovery peak improvement | late peak improvement | undershoot improvement |
|---:|---:|---:|---:|---:|---:|
| `0.050 us` | `1.250 us` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| `0.050 us` | `1.450 us` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| `0.105 us` | `1.250 us` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| `0.105 us` | `1.450 us` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |

## Decision

```text
CLAIM_DOWNGRADED
```

Earlier binary releases at `1.250 us` and `1.450 us` do remove the R049N
recovery-undershoot penalty, but only by removing the controlled-reentry effect
entirely: A2 becomes indistinguishable from A0 in the tested windows.

This does not invalidate the R049N upstream release interface.  It narrows the
timing problem: useful binary release, if it exists, must lie later than
`1.450 us` and before or near the R049N `1.685 us` setting, or the release must
be softened rather than a binary full restore.

## Evidence files

- `output/iqcot_r049o_pr_ecb_release_timing_micro_audit.m`
- `output/iqcot_r049o_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049o_release_timing_plan.csv`
- `output/cutload_pr_ecb_control/r049o_release_timing_results_full.csv`
- `output/cutload_pr_ecb_control/r049o_release_timing_report_full.md`
- `output/cutload_pr_ecb_control/r049o_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049o_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049o_waveform_metric_summary.md`
- `output/data/*_r049o_release_timing_wave.csv`

## Next step

Do not continue sweeping broadly.  The next minimal step should either:

1. test one narrow intermediate binary release near `1.55-1.62 us`, or
2. replace binary release with a soft request-restoration ramp / duty-limited
   release while preserving the R049N upstream-causal trigger.

The objective is to keep some of R049N's recovery-peak benefit without the
large undershoot penalty.

## Claim boundary

R049O is derived-Simulink switching evidence only.  It does not validate
hardware/HIL behavior, and it does not confirm PR-ECB controlled reentry.
