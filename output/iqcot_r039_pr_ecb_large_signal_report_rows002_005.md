# R039 PR-ECB Large-Signal Probe

## Scope

R039 starts the large-signal line requested after R038. It estimates the first load-drop peak using a phase-resolved energy-charge boundary (PR-ECB) interface and compares the estimate with derived-Simulink waveforms.

## Outputs

- Results: E:\Desktop\codex\output\iqcot_r039_pr_ecb_large_signal_results_rows002_005.csv
- Wave snapshots: output/data/*_r039_pr_ecb_wave.csv

## Smoke Results

| case | role | tau AI us | slew us | energy mV | charge+ESR mV | actual peak mV | r_E |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r039_20A_tau1p50_slew50 | folded_anchor | 1.500 | 50.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau1p75_slew54 | folded_anchor | 1.750 | 54.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau2p00_slew30 | dense_fallback | 2.000 | 30.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau2p00_slew48 | r038_near_tie_probe | 2.000 | 48.000 | 4.350 | 3.903 | 2.235 | 0.435 |

## Interpretation Boundary

This is a derived-Simulink and offline post-processing probe, not hardware or HIL validation. PR-ECB is intended as a first-peak risk feature r_E for the supervisory layer. It complements PIS-IEK, which remains the normal/quasi-normal event recovery model; it does not make PIS-IEK a precise predictor of the large load-drop first peak.
