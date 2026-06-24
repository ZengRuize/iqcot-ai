# R039 PR-ECB Large-Signal Boundary Probe

## Scope

R039 starts the large-signal branch after R038. It uses the derived delayed-reference Simulink model to export first-peak wave snapshots and evaluates a phase-resolved energy-charge boundary model.

## Combined Results

| case | role | tau AI us | slew us | energy mV | charge+ESR mV | actual peak mV | r_E |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| r039_20A_tau1p25_slew46 | folded_anchor | 1.250 | 46.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau1p50_slew50 | folded_anchor | 1.500 | 50.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau1p75_slew54 | folded_anchor | 1.750 | 54.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau2p00_slew30 | dense_fallback | 2.000 | 30.000 | 4.350 | 3.903 | 2.235 | 0.435 |
| r039_20A_tau2p00_slew48 | r038_near_tie_probe | 2.000 | 48.000 | 4.350 | 3.903 | 2.235 | 0.435 |

## Main Interpretation

- Successful derived-Simulink cases: 5/5.
- Energy upper-bound estimate: 4.349633 mV.
- Charge+ESR estimate: 3.903338 mV.
- Actual derived-Simulink first peak: 2.235008 mV.
- With a 10 mV allowance, r_E = 0.434963.
- Energy/actual ratio: 1.946138; charge+ESR/actual ratio: 1.746454.

The identical first-peak values across 46/50/54/30/48 us delayed-reference cases are expected: these cases share the same load-drop instant, phase state, and inductor-current state, while the supervisory T_slew action is delayed by at least 1.25 us. The first voltage peak occurs at about 0.534 us after the load step, before the AI reference trajectory materially changes the plant.

## Boundary

This is derived-Simulink plus offline post-processing evidence. It is not hardware validation, HIL validation, or proof of a global T_slew optimum. PR-ECB should be used as a first-peak risk feature r_E and safety-bound generator; PIS-IEK remains the normal/quasi-normal event recovery model.
