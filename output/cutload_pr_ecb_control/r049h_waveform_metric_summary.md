# R049H PR-ECB Waveform Metric Audit
Date: 2026-06-24
## Scope
R049H is an offline audit only.  It reuses existing wave CSV exports from R049C/R049D/R049E/R049F/R049G and does not run any new Simulink switching simulation.
The response is split into three windows after the load step:
- `0-2 us`: early local peak / immediate switching interaction.
- `2-12 us`: recovery peak.
- `12-80 us`: late settling and undershoot.

## Output files
- `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`

## Active-HS windowed comparison
| Chunk | Early peak improvement | Recovery peak improvement | Late peak improvement | Early undershoot change | Late undershoot change |
|---|---:|---:|---:|---:|---:|
| R049C near0 active-HS | 0.7660 mV | 1.0047 mV | -0.4480 mV | 0.0000 mV | 2.7395 mV |
| R049D 10A active-HS | 0.6036 mV | -0.0323 mV | -0.0045 mV | -0.7576 mV | -0.0901 mV |
| R049E 20A OV-triggered mild | -0.0000 mV | -0.0000 mV | -0.0000 mV | 0.0000 mV | 0.0000 mV |
| R049G 20A repaired phase-selective | -0.2902 mV | -0.0476 mV | -0.0866 mV | 0.4725 mV | 0.0348 mV |

## Key observations
1. R049C supports a broad larger-drop Ton-truncation benefit in the active-HS row: A2 improves both early local and recovery peak windows. R049D supports a narrower `10A` hold-out benefit: the main improvement is in the `0-2 us` early local peak, while the recovery/late positive peak windows are essentially unchanged or slightly worse.
2. R049E confirms the mild-load trigger-lateness issue: the over-voltage triggered action is too late to change the `40A -> 20A` active-HS early or recovery peak windows.
3. R049G is the decisive repaired mild-load diagnostic: phase-selective hard Ton-min truncation removes remaining Ton, but worsens the early local peak and slightly worsens the recovery/late peak windows.
4. R049F remains useful only as a timing-artifact reference.  Its A2 rows begin far below regulation because the inherited early-window lower bound was unconnected before R049G repaired it.

## R049F timing-artifact check
| Offset | A0 initial error | A2 initial error | Interpretation |
|---:|---:|---:|---|
| `0.050 us` | 1.4853 mV | -1117.3670 mV | timing artifact, not controller evidence |
| `0.105 us` | 1.6802 mV | -1117.3659 mV | timing artifact, not controller evidence |

## Decision

```text
MODEL_REVISED
```

## Revised action model
R049H keeps command-path Ton truncation as a valid larger-drop active-HS action only with segmented wording: R049C shows broad near0 benefit, while R049D confirms mainly early-local-peak benefit for the `10A` hold-out.  R049H rejects hard phase-selective Ton-min truncation as a confirmed mild-load action.  The PR-ECB metric must remain segmented by early local peak, recovery peak, and late settling/undershoot windows.

## Next validation
R049I should run one minimal repaired-model action chunk, not a full matrix: use the same `40A -> 20A` two-offset setup but test a gentler phase-selective Ton trim rather than hard `5 ns` Ton-min.  A practical first candidate is to cap only the active phase to a moderate floor (for example `80-120 ns`, to be documented from baseline Ton traces) and evaluate the same three windows.  If the early local peak remains worse, stop and move to deferred post-active pulse inhibit or controlled reentry instead of more Ton-min variants.

## Claim boundary
R049H is offline derived-Simulink waveform evidence only.  It is not hardware/HIL validation, not global calibration, not proof of a complete PR-ECB controller, and not a universal additive `E_HS,rem` law.
