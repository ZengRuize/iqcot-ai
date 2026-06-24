# R049J PR-ECB Deferred Post-Active Pulse Inhibit

Date: 2026-06-25

## Scope

R049J runs one minimal repaired-model action chunk.  It does not expand the A
matrix and does not continue Ton-floor scanning.  It copies the completed R049I
model into:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx
```

The builder and runner are:

```text
output/iqcot_r049j_build_post_active_inhibit_model.m
output/iqcot_r049j_pr_ecb_post_active_inhibit_chunk.m
```

The offline three-window audit is:

```text
output/iqcot_r049j_waveform_metric_audit.py
```

R049J compares:

```text
A0: same-model no inhibit; Ton truncation disabled
A2: request-path post_active_inhibit from 0.07 us to 2.00 us after load step
```

on the same `40A -> 20A` offsets used by R049G/R049I: `0.05 us` and
`0.105 us`.

## Boundary selection

R049I/R049G baseline traces show that at the `0.05 us` active-HS offset:

```text
qh4 natural falling edge: about 0.052 us after load step
next qh1 rising edge: about 1.690 us after load step
```

R049J therefore chooses:

```text
Tpost_inhibit_delay  = 0.070 us
Tpost_inhibit_window = 1.930 us
```

This starts after the active pulse's natural end and lasts until the end of the
R049H early-local-peak window (`2 us`).  The intended semantic is to inhibit
future requests only, not to change the already-active high-side pulse.

## Outputs

- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_results_full.csv`
- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_report_full.md`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_summary.md`
- `output/data/*_r049j_post_active_inhibit_wave.csv`

## Simulation result

| Offset | Controller | Peak | Peak time | remaining Ton4 | inhibit duration | skipped REQ | final error |
|---:|---|---:|---:|---:|---:|---:|---:|
| `0.050 us` | A0 no inhibit | `2.1103 mV` | `9.454 us` | `52 ns` | `0 us` | `0` | `-0.4397 mV` |
| `0.050 us` | A2 post-active inhibit | `2.0977 mV` | `0.484 us` | `52 ns` | `1.93 us` | `1` | `-0.4363 mV` |
| `0.105 us` | A0 no inhibit | `2.0936 mV` | `8.389 us` | `0 ns` | `0 us` | `0` | `-0.4344 mV` |
| `0.105 us` | A2 post-active inhibit | `1.9439 mV` | `0.429 us` | `0 ns` | `1.93 us` | `1` | `-0.4417 mV` |

The state-machine intent was satisfied: R049J did not reduce current-pulse
remaining Ton and did not assert Ton truncation.  The action only gated future
requests.

## R049H three-window audit

| Offset | Window | Peak improvement | A2-A0 max | Undershoot change |
|---:|---|---:|---:|---:|
| `0.050 us` | early local peak `0-2 us` | `0.0000 mV` | `0.0000 mV` | `-1.2128 mV` |
| `0.050 us` | recovery peak `2-12 us` | `+0.6262 mV` | `-0.6262 mV` | `-2.9901 mV` |
| `0.050 us` | late settling `12-80 us` | `+0.0903 mV` | `-0.0903 mV` | `+0.0532 mV` |
| `0.105 us` | early local peak `0-2 us` | `0.0000 mV` | `0.0000 mV` | `-1.6300 mV` |
| `0.105 us` | recovery peak `2-12 us` | `+0.5813 mV` | `-0.5813 mV` | `-4.1571 mV` |
| `0.105 us` | late settling `12-80 us` | `+0.2034 mV` | `-0.2034 mV` | `-0.0067 mV` |

## Decision

```text
MODEL_REVISED
```

R049J validates the direction away from current-pulse truncation, but revises
the inhibit/reentry model: a hard request inhibit from `0.07 us` to `2.00 us`
is too aggressive.  It reduces positive recovery peaks, but creates recovery
undershoot penalties.

## Next step

Do not promote fixed post-active inhibit as the PR-ECB action.  The next
minimal step should be controlled reentry or a softened/shortened inhibit:

```text
controlled reentry with gradual request restoration
```

or:

```text
shorter/phase-selective post-active inhibit validated against undershoot
```

The R049H three-window gate must remain active, now including an explicit
recovery-window undershoot penalty.

## Claim boundary

R049J is derived-Simulink switching evidence only.  It is not hardware/HIL
validation, not complete PR-ECB control, not global calibration, not proof that
AI replaces IQCOT, and not a universal additive `E_HS,rem` law.
