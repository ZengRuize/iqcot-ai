# LOCAL AUDIT R049J PR-ECB Deferred Post-Active Pulse Inhibit

Date: 2026-06-25

## Scope

R049J ran one minimal repaired-model action chunk on the same `40A -> 20A`,
two-offset setup as R049G/R049I.  It copied the completed R049I model into a
new derived file and tested A0 same-model no-inhibit versus A2 request-path
post-active pulse inhibit.

No original model, R048 source derived model, or completed R049A-I model was
modified in place.

## Boundary selection

R049I/R049G baseline traces showed:

```text
qh4 natural falling edge at 0.05 us active-HS offset: about 0.052 us
next qh1 rising edge: about 1.690 us
```

R049J selected:

```text
Tpost_inhibit_delay  = 0.070 us
Tpost_inhibit_window = 1.930 us
```

The action starts after the active high-side pulse's natural end and ends at
the `2 us` early-local-peak window boundary.

## Outputs

- `output/iqcot_r049j_build_post_active_inhibit_model.m`
- `output/iqcot_r049j_pr_ecb_post_active_inhibit_chunk.m`
- `output/iqcot_r049j_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx`
- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_results_full.csv`
- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049j_post_active_inhibit_report_full.md`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049j_waveform_metric_summary.md`
- `output/data/*_r049j_post_active_inhibit_wave.csv`

## Results

R049J does not truncate the current active-HS pulse:

```text
0.05 us remaining Ton4: 52 ns -> 52 ns
global Ton-trunc duration: 0 us
phase-4 Ton-trunc duration: 0 us
```

It does inhibit future requests:

```text
A2 inhibit duration: 1.93 us
A2 skipped REQ count: 1
first inhibit time: 0.07 us
```

Windowed active-HS result:

```text
early peak A2-A0: 0.0000 mV
recovery peak improvement: +0.6262 mV
recovery undershoot penalty: -2.9901 mV
late peak improvement: +0.0903 mV
```

Post-turnoff result:

```text
early peak A2-A0: 0.0000 mV
recovery peak improvement: +0.5813 mV
recovery undershoot penalty: -4.1571 mV
```

## Decision

```text
MODEL_REVISED
```

## Diagnosis

R049J confirms the state-machine direction away from already-active pulse
truncation.  However, a hard request inhibit from `0.07 us` to `2.00 us` is too
aggressive for reentry.  It reduces positive recovery peaks but creates
multi-mV recovery undershoot penalties.

## Next Step

Do not promote fixed post-active inhibit.  Move to controlled reentry with
softer request restoration, or a shorter/phase-selective inhibit explicitly
penalized for recovery undershoot.

## Claim Boundary

R049J is derived-Simulink evidence only.  It is not hardware/HIL validation, not
complete PR-ECB control, not global calibration, and not a universal additive
`E_HS,rem` law.
