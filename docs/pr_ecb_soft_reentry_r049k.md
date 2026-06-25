# R049K PR-ECB Short Soft-Reentry Proxy

Date: 2026-06-25

## Scope

R049K runs one minimal controlled-reentry proxy chunk. It does not expand the A
matrix, does not return to Ton-floor actions, and does not promote the fixed
R049J post-active inhibit window.

The derived model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx
```

The builder and runner are:

```text
output/iqcot_r049k_build_soft_reentry_model.m
output/iqcot_r049k_pr_ecb_soft_reentry_chunk.m
```

The offline three-window audit is:

```text
output/iqcot_r049k_waveform_metric_audit.py
```

R049K compares:

```text
A0: same-model no inhibit; Ton truncation disabled
A2: request-path short soft-reentry proxy from 0.070 us to 1.760 us after load step
```

on the same `40A -> 20A` offsets used by R049G/R049I/R049J: `0.05 us` and
`0.105 us`.

## Boundary selection

R049J showed that the hard `0.070-2.000 us` request inhibit avoided current
pulse truncation but created recovery undershoot penalties. R049K therefore
uses the shortest evidence-based proxy that still starts after the active pulse
natural end and releases near the first future request:

```text
qh4 natural falling edge at active-HS offset: about 0.052 us
first future request / qh1 boundary: about 1.678-1.690 us
R049K inhibit interval: 0.070-1.760 us
```

This is a controlled-reentry proxy, not a final reentry state machine.

## Outputs

- `output/cutload_pr_ecb_control/r049k_soft_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049k_soft_reentry_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049k_soft_reentry_report_full.md`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049k_waveform_metric_summary.md`
- `output/data/*_r049k_soft_reentry_wave.csv`

## Simulation result

| Offset | Controller | Peak | remaining Ton4 | inhibit duration | skipped REQ | secondary undershoot | final error |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050 us` | A0 no inhibit | `2.1103 mV` | `52 ns` | `0 us` | `0` | `-0.8909 mV` | `-0.4397 mV` |
| `0.050 us` | A2 short soft reentry | `2.0977 mV` | `52 ns` | `1.69 us` | `1` | `-1.0414 mV` | `-0.4422 mV` |
| `0.105 us` | A0 no inhibit | `2.0936 mV` | `0 ns` | `0 us` | `0` | `-0.8991 mV` | `-0.4344 mV` |
| `0.105 us` | A2 short soft reentry | `2.0316 mV` | `0 ns` | `1.69 us` | `1` | `-0.8444 mV` | `-0.4306 mV` |

R049K preserves the no-current-pulse-truncation property: at the `0.05 us`
active-HS row, phase-4 remaining Ton stays `52 ns -> 52 ns`.

The A2 timing is also consistent with the intended release boundary:

```text
0.05 us row:
    soft_reentry: 0.070-1.760 us
    req_global first high interval: about 1.678-1.762 us
    qh1 rise after release: about 1.772 us
```

## R049H three-window audit

| Offset | Window | Peak improvement | A2-A0 max | Undershoot change |
|---:|---|---:|---:|---:|
| `0.050 us` | early local peak `0-2 us` | `0.0000 mV` | `0.0000 mV` | `-0.2917 mV` |
| `0.050 us` | recovery peak `2-12 us` | `+0.1796 mV` | `-0.1796 mV` | `-0.6388 mV` |
| `0.050 us` | late settling `12-80 us` | `-0.1318 mV` | `+0.1318 mV` | `-0.0261 mV` |
| `0.105 us` | early local peak `0-2 us` | `0.0000 mV` | `0.0000 mV` | `-0.6663 mV` |
| `0.105 us` | recovery peak `2-12 us` | `+0.1954 mV` | `-0.1954 mV` | `-1.6588 mV` |
| `0.105 us` | late settling `12-80 us` | `-0.0223 mV` | `+0.0223 mV` | `+0.0547 mV` |

Compared with R049J, R049K reduces the recovery-window undershoot penalty from
`-2.9901/-4.1571 mV` to `-0.6388/-1.6588 mV`, but it also narrows the positive
recovery-peak benefit from `+0.6262/+0.5813 mV` to `+0.1796/+0.1954 mV` and
slightly worsens the late positive peak.

## Decision

```text
MODEL_REVISED
```

R049K confirms that shorter request restoration is the right direction, but a
single fixed short inhibit window is still a trade-off rather than a confirmed
PR-ECB action.

## Next step

Do not keep scanning scalar fixed inhibit windows. The next minimal step should
move to an explicit controlled-reentry state-machine proxy, such as an
edge-aligned one-shot request restoration or phase-aware release, still using
the R049H three-window gate and explicit recovery undershoot penalty.

## Claim boundary

R049K is derived-Simulink switching evidence only. It is not hardware/HIL
validation, not complete PR-ECB control, not global calibration, not proof that
AI replaces IQCOT, and not a universal additive `E_HS,rem` law.
