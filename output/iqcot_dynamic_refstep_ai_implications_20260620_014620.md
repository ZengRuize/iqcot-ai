# AI-Control Implications of Dynamic Reference-Step Validation

## Core Observation

The controlled dynamic-load simulations reveal a trade-off that is directly relevant to AI parameter scheduling:

- `dynamic_hold` is conservative during cut-load transients, with smaller undershoot, but leaves a positive final voltage error because the controller reference still reflects `40A/4`.
- `dynamic_instant` reduces final voltage error by synchronously stepping `Iph` to the target-load reference, but it strongly amplifies undershoot and can increase skipped-event activity.

For example:

| Case | Mode | Undershoot | Final Vout error | Skip |
|---|---|---:|---:|---:|
| `40A -> 20A` | `hold` | `0.992 mV` | `+2.058 mV` | `1` |
| `40A -> 20A` | `instant` | `13.466 mV` | `-0.435 mV` | `1` |
| `40A -> 10A` | `hold` | `4.292 mV` | `+3.199 mV` | `1` |
| `40A -> 10A` | `instant` | `23.830 mV` | `-0.563 mV` | `2` |
| `40A -> near-0A` | `hold` | `9.451 mV` | `+4.413 mV` | `2` |
| `40A -> near-0A` | `instant` | `35.750 mV` | `-0.566 mV` | `2` |

## Why This Helps the AI Argument

This result makes the AI-control motivation more concrete. The problem is not simply to choose between a slow fixed reference and an instant reference step. The real control problem is to schedule the reference and IQCOT parameters with awareness of:

1. cut-load severity,
2. event-mode transition risk,
3. FPGA inference/update delay,
4. allowed undershoot/overshoot envelope,
5. final regulation and current-sharing recovery.

This is exactly the kind of constrained, low-dimensional scheduling problem where PIS-IEK can help AI training. It provides:

- an event-domain delayed state,
- separated actuator channels such as `Lambda_diff`, `Ton_diff`, and `Iph_ref`,
- mode labels such as `normal/skip/reentry`,
- safety constraints for projection or reward shaping.

## Recommended AI Action Space Extension

The previous AI surrogate used

```math
u_k=[\Delta\Lambda_{\mathrm{diff}},\Delta T_{\mathrm{on,diff}}]^T.
```

After the dynamic reference-step validation, the action space should be extended to include a rate-limited reference scheduling channel:

```math
u_k=
\begin{bmatrix}
\Delta\Lambda_{\mathrm{diff}} &
\Delta T_{\mathrm{on,diff}} &
\Delta I_{\mathrm{ph,ref}} &
r_{I,\max}
\end{bmatrix}^{T}.
```

Here `Delta Iph_ref` controls the reference target, while `r_I,max` or an equivalent slew parameter prevents the unsafe instant-step behavior observed in Simulink.

## Paper Claim

A defensible paper-level claim is:

> Dynamic Simulink validation shows that synchronous reference updates reduce steady-state error but can severely worsen cut-load undershoot and skipped-event activity. This creates a physically grounded scheduling problem for AI: learn when and how fast to update IQCOT reference and event parameters under PIS-IEK delay and safety constraints.

This is stronger and more precise than the generic claim "AI can tune IQCOT better," because it identifies the exact failure of naive fast reference adaptation and the exact model feature needed to avoid it.
