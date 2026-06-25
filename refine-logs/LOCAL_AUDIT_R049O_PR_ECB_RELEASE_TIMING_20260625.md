# LOCAL AUDIT R049O PR-ECB Release Timing

Date: 2026-06-25

## Decision

```text
CLAIM_DOWNGRADED
```

## Scope

R049O reused the R049N upstream-causal release interface and tested two earlier
binary release delays:

```text
Tphase_release_delay = 1.250 us
Tphase_release_delay = 1.450 us
```

The run had six rows: two A0 baselines and four A2 release probes for the
`40A -> 20A` offsets `0.050 us` and `0.105 us`.

## Result

Both release delays triggered successfully:

```text
0.050 us / 1.250 us: one_shot_done=1.310 us
0.050 us / 1.450 us: one_shot_done=1.510 us
0.105 us / 1.250 us: one_shot_done=1.295 us
0.105 us / 1.450 us: one_shot_done=1.495 us
```

But the R049H three-window deltas were all `0.0000 mV` relative to A0.  Earlier
binary release makes A2 effectively transparent: it avoids the R049N undershoot
penalty by also removing the recovery-peak benefit.

## Evidence

- `docs/pr_ecb_release_timing_r049o.md`
- `output/iqcot_r049o_pr_ecb_release_timing_micro_audit.m`
- `output/iqcot_r049o_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/r049o_release_timing_results_full.csv`
- `output/cutload_pr_ecb_control/r049o_waveform_metric_summary.md`

## Next step

The binary-release timing interval is now bracketed:

- `1.250-1.450 us`: too early, no effect versus A0.
- `1.685 us`: measurable effect, but recovery undershoot penalty.

Next do one narrow intermediate delay or move to soft request restoration.

## Claim boundary

R049O is a derived-Simulink micro-audit, not hardware/HIL validation and not a
confirmed PR-ECB controller result.
