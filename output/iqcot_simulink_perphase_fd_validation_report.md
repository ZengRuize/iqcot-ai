# Simulink per-phase IEK finite-difference validation

Model copy: `E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase_trim.slx`.

Raw simulation samples: `27`; central-difference Jacobian rows: `12`.

## Key observations

- Lambda m2 median `|G_m2_current|` = `0.00397031 mA/(1e-13 V*s)`, median `|G_spacing_std|` = `0.00149489 ns/(1e-13 V*s)`.
- Ton m2 median `|G_m2_current|` = `49.3951 mA/(0.1 ns)`, median `|G_spacing_std|` = `0.0217058 ns/(0.1 ns)`.
- The comparison is not an exact equality test against the analytical PIS-IEK model. It is a circuit-level direction and scale check using the strict area-trigger Simulink copy with direct per-phase variables.

## Interpretation

The finite-difference data are intended to close the evidence gap noted by the reviewer: PIS-IEK should not be supported only by an analytical event script. If the Simulink copy keeps showing that Lambda-differential perturbations have weak DC current gain while Ton-differential perturbations have much stronger current gain, the actuator-classification claim is supported at the switching-circuit level.
