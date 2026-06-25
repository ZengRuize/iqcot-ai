# R049Q PR-ECB Release-Later-Point Audit

Date: 2026-06-25

## Scope

R049Q continues the narrow binary-release timing bracket after R049P.  It tests
exactly one slightly later point:

```text
Tphase_release_delay = 1.630 us
```

The model and causal interface are unchanged from R049N/R049O/R049P:

```text
release_clock = t_load_step + Tphase_release_delay
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

No new `.slx` structure was intended for R049Q.  The run reuses:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

The run stayed minimal:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- A0 same-model baseline
- A2 `1.630 us` release-later-point probe
- Ton truncation disabled

## Source-model check before running

The R049N derived `.slx` remained the source of truth.  MATLAB API inspection
showed the release and inhibit parameters are variable references, not hard
coded timing literals.

| Item | Actual `.slx` value | Init-script value | R049Q simulation value | Reason |
|---|---|---|---|---|
| Release constant | `t_load_step + Tphase_release_delay` | not fixed by init script | `Tphase_release_delay=1.630e-6` | one narrow point after R049P `1.600 us` |
| Inhibit start | `t_load_step + Tpost_inhibit_delay` | injected per run | `0.070 us` | keep R049N/P window |
| Inhibit end | `t_load_step + Tpost_inhibit_delay + Tpost_inhibit_window` | injected per run | `1.690 us` A2, disabled A0 | keep comparable gate |
| Release detector | relational `>=` | n/a | unchanged | upstream-causal release clock |
| Gate logic | `AND(existing_allow, NOT(inhibit_raw) OR one_shot_done)` | n/a | unchanged | keep R049N interface |
| Solver step for run | model `MaxStep=max_step_cont` | init dependent | `MaxStep=5e-9`, `Tss=5e-9` | match R049P switching audit |

The controller class remains closed-loop COT-style request generation with
fixed-on-time pulse scheduling and an added upstream-causal reentry gate.  R049Q
does not alter the power stage, MOSFET, inductor, capacitor, or base controller
parameters.

## Quality gates

A0 baseline passed:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

A2 one-shot release fired:

| Offset | release_clock | one_shot_done | effective inhibit |
|---:|---:|---:|---:|
| `0.050 us` | `1.630 us` | `1.670 us` | `1.600 us` |
| `0.105 us` | `1.631 us` | `1.695 us` | `1.624 us` |

Ton truncation remained disabled.

## Results

The later point preserves the offset-selective behavior and starts to worsen the
same undershoot mode seen in R049N:

| Offset | Global A0 peak | Global A2 peak | Global undershoot change |
|---:|---:|---:|---:|
| `0.050 us` | `2.1103 mV` | `2.1103 mV` | `0.0000 mV` |
| `0.105 us` | `2.0936 mV` | `2.0759 mV` | `+0.0596 mV` |

R049H three-window metrics:

| Offset | Window | Peak improvement | Undershoot improvement | Interpretation |
|---:|---|---:|---:|---|
| `0.050 us` | early local peak | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.050 us` | recovery peak | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.050 us` | late settling | `0.0000 mV` | `0.0000 mV` | transparent |
| `0.105 us` | early local peak | `0.0000 mV` | `-0.4331 mV` | early undershoot penalty |
| `0.105 us` | recovery peak | `+0.1365 mV` | `-1.1109 mV` | stronger peak benefit, worse undershoot |
| `0.105 us` | late settling | `-0.0666 mV` | `+0.0596 mV` | late undershoot improves but late peak worsens |

Compared with R049P at `0.105 us`, R049Q increases recovery peak improvement
from `+0.1244 mV` to `+0.1365 mV`, but worsens recovery undershoot from
`-0.7873 mV` to `-1.1109 mV`.  It also changes late settling from peak
improvement `+0.0354 mV` to peak degradation `-0.0666 mV`.

## Decision

```text
MODEL_REVISED
```

R049Q is not a controller confirmation.  It narrows the binary-release timing
trade-off: moving later than `1.600 us` increases the active recovery effect at
`0.105 us`, but the undershoot penalty moves back toward the too-hard R049N
case.  The `0.050 us` row is still transparent.

## Evidence files

- `output/iqcot_r049q_pr_ecb_release_later_point_audit.m`
- `output/iqcot_r049q_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049q_release_later_point_plan.csv`
- `output/cutload_pr_ecb_control/r049q_release_later_point_results_full.csv`
- `output/cutload_pr_ecb_control/r049q_release_later_point_report_full.md`
- `output/cutload_pr_ecb_control/r049q_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049q_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049q_waveform_metric_summary.md`
- `output/data/*_r049q_release_later_point_wave.csv`

## Next step

Do not continue pushing the binary release later.  The next minimal step should
either:

1. test one point between R049P and R049Q, e.g. `1.610-1.620 us`, to locate the
   knee before the undershoot penalty accelerates; or
2. replace the binary restore with soft/ramped request restoration.

## Claim boundary

R049Q is derived-Simulink switching evidence only.  It is not hardware/HIL
validation and does not confirm PR-ECB controlled reentry.
