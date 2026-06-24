# Controlled Dynamic-Load Validation of the Hybrid PIS-IEK Model

## Model Construction

To move beyond the two-stage state-carry surrogate, the static load branch in the four-phase PIS-IEK Simulink copy was replaced by a Specialized Power Systems controlled current source. The model was constructed only from the derived validation copy:

```text
four_phase_iek_perphase_trim.slx
    -> four_phase_iek_dynamic_load.slx
```

The original user model was not modified. The load command is

```math
I_{\mathrm{load}}(t)=
\begin{cases}
40\ \mathrm{A}, & t<t_{\mathrm{step}},\\
I_{\mathrm{target}}, & t\ge t_{\mathrm{step}}.
\end{cases}
```

The current-source sign was verified by a 40 A smoke test: positive `+40 A` input keeps `Vout` near `0.9995 V`, so positive current command corresponds to load absorption.

## Results

| Case | Overshoot | Undershoot | Estimated skip | Final phase std | Final current imbalance |
|---|---:|---:|---:|---:|---:|
| `40A -> 20A` | `2.475 mV` | `0.992 mV` | `1` | `40.094 ns` | `0.166 A` |
| `40A -> 10A` | `4.196 mV` | `4.292 mV` | `1` | `79.875 ns` | `0.184 A` |
| `40A -> near-0A` | `6.817 mV` | `9.451 mV` | `2` | `103.595 ns` | `0.569 A` |

Compared with the state-carry hold experiment, the controlled dynamic-load model preserves the same qualitative progression but reveals stronger undershoot and more skipped events in the near-zero-load case. This matters because the main PIS-IEK claim is about event-mode transitions, not merely about fitting a small perturbation around one operating point.

## Interpretation

The continuous dynamic-load validation strengthens the hybrid PIS-IEK argument:

1. The event stream enters skip/reentry behavior as cut-load severity increases.
2. A single fixed small-signal Jacobian cannot represent the full recovery process after large cut-load steps.
3. The dynamic-load result is stricter than state-carry because the converter sees the current step inside the same switching simulation rather than restarting from a modified operating point.

This section should be used as the stronger simulation evidence in the paper. The earlier state-carry result remains useful as a surrogate and cross-check, but it should not be the primary validation once the dynamic-load model is available.

