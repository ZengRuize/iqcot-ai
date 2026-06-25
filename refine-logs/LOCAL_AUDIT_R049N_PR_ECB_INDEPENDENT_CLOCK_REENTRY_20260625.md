# LOCAL AUDIT R049N PR-ECB Independent-Clock Reentry

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## What was tested

R049N used the repaired R049L derived model as its source and replaced the
downstream `qh1` release trigger with an upstream independent timer:

```text
release_clock = t_load_step + 1.685 us
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

The four-row scope stayed the same:

- `40A -> 20A`
- offsets `0.050 us` and `0.105 us`
- A0 same-model no-inhibit baseline
- A2 independent-clock one-shot reentry
- Ton truncation disabled

## Quality gates

A0 baseline passed:

```text
0.050 us: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

A2 implementation gate passed:

```text
0.050 us: release_clock=1.686 us, one_shot_done=1.750 us
0.105 us: release_clock=1.685 us, one_shot_done=1.735 us
```

This fixes the R049L implementation issue: release is no longer causally
downstream of the gated scheduler / `qh1`.

## Metric result

R049N is not confirmed.  Three-window metrics show recovery peak improvement
with undershoot penalties:

| Offset | Recovery peak improvement | Recovery undershoot change | Late positive peak change |
|---:|---:|---:|---:|
| `0.050 us` | `+0.1127 mV` | `-0.5597 mV` | `-0.0696 mV` |
| `0.105 us` | `+0.1205 mV` | `-1.4429 mV` | `-0.0148 mV` |

## Evidence

- `docs/pr_ecb_independent_clock_reentry_r049n.md`
- `output/iqcot_r049n_build_independent_clock_reentry_model.m`
- `output/iqcot_r049n_pr_ecb_independent_clock_reentry_chunk.m`
- `output/iqcot_r049n_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx`
- `output/cutload_pr_ecb_control/r049n_independent_clock_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049n_waveform_metric_summary.md`

## Next step

Keep the R049N upstream release interface, but do not keep the fixed
`1.685 us` release as a confirmed controller.  The next useful micro-step is a
small release-timing or soft-reentry revision that targets the recovery
undershoot penalty while preserving the no-active-Ton-truncation gate.

## Claim boundary

R049N is derived-Simulink switching evidence only.  It does not prove
hardware/HIL behavior and does not complete PR-ECB.
