# Reference-Slew Scheduling as an AI-Controllable IQCOT Parameter

## Motivation

The previous dynamic-load comparison showed that `dynamic_hold` and `dynamic_instant` represent two extremes. Holding the controller reference reduces cut-load undershoot but leaves a final voltage offset; stepping the reference immediately improves final regulation but can severely increase undershoot. This motivates a third option: treating the `Iph_ref` transition time as a low-dimensional scheduling parameter.

## Simulink Experiment

A new model copy was generated:

```text
four_phase_iek_dynamic_load_refslew.slx
```

The load branch is still a controlled current source. However, the internal controller references `IEK_PerPhase_Request/Iph1..4` and `IQCOT_Ton_Adapter/Iref_Phase` are driven by a piecewise-linear `From Workspace` signal:

```math
I_{\mathrm{ph,ref}}(t)=
\begin{cases}
10\ \mathrm{A}, & t<t_{\mathrm{step}},\\
10+\frac{I_{\mathrm{target}}/4-10}{T_{\mathrm{slew}}}(t-t_{\mathrm{step}}), & t_{\mathrm{step}}\le t<t_{\mathrm{step}}+T_{\mathrm{slew}},\\
I_{\mathrm{target}}/4, & t\ge t_{\mathrm{step}}+T_{\mathrm{slew}}.
\end{cases}
```

The sweep used `T_slew = 0, 5, 10, 20, 40 us` over three cut-load cases.

## Results

| Target load | Best scanned slew | Undershoot | Final Vout error | Estimated skip |
|---:|---:|---:|---:|---:|
| `20 A` | `40 us` | `1.199 mV` | `-0.434 mV` | `0` |
| `10 A` | `40 us` | `5.010 mV` | `-0.549 mV` | `1` |
| `near-0 A` | `40 us` | `10.897 mV` | `-0.569 mV` | `2` |

For the severe near-zero-load step, the nearly-instant reference update produced `35.750 mV` undershoot, whereas the `40 us` reference slew reduced undershoot to `10.897 mV` while preserving sub-mV final voltage error. This is close to the safety behavior of `dynamic_hold` but with much better final regulation.

## Interpretation

This experiment turns the AI-control claim into a concrete scheduling problem. AI does not need to replace the IQCOT event generator; instead, it can choose a physically meaningful low-dimensional parameter, such as `T_slew`, based on cut-load severity, event-mode risk, and FPGA inference delay.

A concise paper-level claim is:

> Reference-slew scanning shows that the unsafe undershoot of instantaneous Iph reference updates can be strongly reduced without giving up final regulation. This supports using PIS-IEK as an event-domain model for AI scheduling of reference slew and IQCOT event parameters.

