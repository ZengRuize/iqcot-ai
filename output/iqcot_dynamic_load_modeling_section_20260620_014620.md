# Controlled Dynamic-Load Validation of the Hybrid PIS-IEK Model

## Model Construction

To move beyond the two-stage state-carry surrogate, the static load branch in the four-phase PIS-IEK Simulink copy was replaced by a Specialized Power Systems controlled current source. Two derived validation models were generated from the trim-enabled PIS-IEK copy:

```text
four_phase_iek_perphase_trim.slx
    -> four_phase_iek_dynamic_load.slx          (dynamic_hold)
    -> four_phase_iek_dynamic_load_refstep.slx  (dynamic_instant)
```

The original user model was not modified. In both dynamic models, the load command is

```math
I_{\mathrm{load}}(t)=
\begin{cases}
40\ \mathrm{A}, & t<t_{\mathrm{step}},\\
I_{\mathrm{target}}, & t\ge t_{\mathrm{step}}.
\end{cases}
```

The `dynamic_hold` model keeps the controller reference at `Iph=40A/4`. The `dynamic_instant` model replaces `IEK_PerPhase_Request/Iph1..4` and `IQCOT_Ton_Adapter/Iref_Phase` with synchronized Step blocks, so the controller reference also changes to `I_target/4` at the load step.

## Results

| Case | Mode | Overshoot | Undershoot | Skip | Settling | Final Vout error | Phase std | Current imbalance |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `40A -> 20A` | `hold` | `2.475 mV` | `0.992 mV` | `1` | `NaN` | `2.058 mV` | `40.094 ns` | `0.166 A` |
| `40A -> 20A` | `instant` | `2.235 mV` | `13.466 mV` | `1` | `18.256 us` | `-0.435 mV` | `41.954 ns` | `0.252 A` |
| `40A -> 10A` | `hold` | `4.196 mV` | `4.292 mV` | `1` | `NaN` | `3.199 mV` | `79.875 ns` | `0.184 A` |
| `40A -> 10A` | `instant` | `4.196 mV` | `23.830 mV` | `2` | `22.384 us` | `-0.563 mV` | `87.335 ns` | `0.362 A` |
| `40A -> near-0A` | `hold` | `6.817 mV` | `9.451 mV` | `2` | `NaN` | `4.413 mV` | `103.595 ns` | `0.569 A` |
| `40A -> near-0A` | `instant` | `6.817 mV` | `35.750 mV` | `2` | `24.970 us` | `-0.566 mV` | `108.304 ns` | `0.153 A` |

## Interpretation

The continuous dynamic-load validation strengthens the hybrid PIS-IEK argument in two ways. First, cut-load severity still drives the event stream into skip/reentry behavior, confirming that this phenomenon is not an artifact of the earlier state-carry surrogate. Second, the synchronous reference experiment exposes a real control trade-off: `dynamic_instant` improves final voltage regulation but strongly amplifies undershoot and can increase skipped-event activity.

This trade-off is valuable for the AI-control motivation. A naive tuner that always updates the reference immediately may reduce steady-state error while harming cut-load safety. A useful AI scheduler should therefore operate on a PIS-IEK state representation with explicit event delay, mode awareness, and safety projection.

