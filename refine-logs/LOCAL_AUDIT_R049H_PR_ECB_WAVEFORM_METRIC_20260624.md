# LOCAL AUDIT R049H PR-ECB Waveform Metric Audit

Date: 2026-06-24

## Scope

R049H performs an offline waveform-metric audit over existing R049C/R049D/
R049E/R049F/R049G wave CSV exports.  It does not run new Simulink switching
simulation and does not modify any `.slx` model.

Script:

```text
output/iqcot_r049h_waveform_metric_audit.py
```

Outputs:

- `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`

## Method

Each waveform is split into:

```text
0-2 us    early local peak / immediate switching interaction
2-12 us   recovery peak
12-80 us  late settling and undershoot
```

For each window, R049H computes max positive error, min error, peak-to-peak
range, max/min times, and A2-A0 deltas.

## Results

Active-HS rows:

| Chunk | Early peak improvement | Recovery peak improvement | Late peak improvement | Early undershoot change | Late undershoot change |
|---|---:|---:|---:|---:|---:|
| R049C near0 | `+0.7660 mV` | `+1.0047 mV` | `-0.4480 mV` | `+0.0000 mV` | `+2.7395 mV` |
| R049D 10A | `+0.6036 mV` | `-0.0323 mV` | `-0.0045 mV` | `-0.7576 mV` | `-0.0901 mV` |
| R049E 20A OV-triggered | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| R049G 20A repaired phase-selective | `-0.2902 mV` | `-0.0476 mV` | `-0.0866 mV` | `+0.4725 mV` | `+0.0348 mV` |

R049F artifact check:

| Offset | A0 initial error | A2 initial error | Interpretation |
|---:|---:|---:|---|
| `0.050 us` | `+1.4853 mV` | `-1117.3670 mV` | timing artifact |
| `0.105 us` | `+1.6802 mV` | `-1117.3659 mV` | timing artifact |

## Diagnosis

R049H confirms that the PR-ECB response metric must be segmented.  R049C
supports broad near0 active-HS Ton-truncation benefit.  R049D confirms mainly
early-local-peak benefit for the `10A` hold-out, not broad recovery-window
improvement.  R049E remains a trigger-lateness result.  R049G shows that
repaired phase-selective hard Ton-min truncation removes remaining Ton but
worsens early/recovery positive peak metrics for mild `40A -> 20A`.

## Decision

```text
MODEL_REVISED
```

## Next Step

R049I should run one minimal repaired-model action chunk on the same
`40A -> 20A` two-offset setup.  It should test a gentler phase-selective Ton
trim rather than hard `5 ns` Ton-min, after inspecting and documenting baseline
Ton traces.  Use the R049H three-window metrics as the acceptance criterion.

If early local peak still worsens, stop Ton-min variants and switch to deferred
post-active pulse inhibit or controlled reentry.

## Claim Boundary

R049H is offline derived-Simulink evidence only.  It is not hardware/HIL
validation, not complete PR-ECB control, not global calibration, and not a
universal additive `E_HS,rem` law.
