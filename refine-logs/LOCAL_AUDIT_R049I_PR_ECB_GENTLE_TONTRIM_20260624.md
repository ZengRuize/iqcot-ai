# LOCAL AUDIT R049I PR-ECB Gentle Phase-Selective Ton Trim

Date: 2026-06-24

## Scope

R049I ran one minimal repaired-model action chunk on the same `40A -> 20A`,
two-offset setup as R049G.  It copied the completed R049G model into a new
derived file and tested A0 same-model no-trim versus A2 gentle phase-selective
Ton trim with `Tton_trunc_min = 120 ns`.

No original model, R048 source derived model, or completed R049A-H model was
modified in place.

## Ton floor selection

R049G baseline traces showed:

```text
Ton_cmd4 = 196.5 ns
remaining Ton4 at 0.05 us offset = 52.0 ns
elapsed on-time before load step = 144.5 ns
```

R049I selected `120 ns`, the gentlest end of the suggested `80-120 ns` first
candidate band.  Model inspection showed that `Tton_trunc_min` is a whole-pulse
Ton command into the COT cell, not a remaining-on-time floor.  Therefore `120 ns`
is still already expired at the active-HS load-step instant; this was treated
as a deliberate semantic check rather than a promoted control action.

## Outputs

- `output/iqcot_r049i_build_gentle_tontrim_model.m`
- `output/iqcot_r049i_pr_ecb_gentle_tontrim_chunk.m`
- `output/iqcot_r049i_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx`
- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_results_full.csv`
- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049i_gentle_tontrim_report_full.md`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049i_waveform_metric_summary.md`
- `output/data/*_r049i_gentle_tontrim_wave.csv`

## Results

Active-HS `0.05 us` offset:

```text
A0 peak: 2.1103 mV at 9.454 us
A2 peak: 2.3879 mV at 0.898 us
A2-A0 early local peak: +0.2902 mV
A2-A0 recovery peak: +0.0476 mV
A2-A0 late peak: +0.0866 mV
remaining Ton4: 52.0 ns -> 2.0 ns
```

Post-turnoff `0.105 us` offset:

```text
A2 identical to A0 across all three windows.
```

## Decision

```text
MODEL_REVISED
```

## Diagnosis

Gentler `120 ns` phase-selective Ton trim still fails the R049H early-local-peak
acceptance gate because the active phase has already exceeded `120 ns` at the
load-step instant.  It removes remaining Ton but creates the same early local
spike pattern as R049G hard Ton-min truncation.

## Next Step

Stop Ton-min/Ton-floor variants.  The next minimal PR-ECB chunk should move to
deferred post-active pulse inhibit or controlled reentry, with the same R049H
three-window acceptance gate.

## Claim Boundary

R049I is derived-Simulink evidence only.  It is not hardware/HIL validation, not
complete PR-ECB control, not global calibration, and not a universal additive
`E_HS,rem` law.
