# PIS-IEK Small-Signal Model

## Purpose

PIS-IEK is the phase-indexed saltation integral event-kernel model used for event-domain small-signal reasoning around IQCOT trajectories. It supports:

- current-sharing recovery;
- phase-spacing recovery;
- reentry after large-signal protection;
- mismatch sensitivity;
- ripple-cancellation recovery.

PIS-IEK does not replace the large-signal protection branches. It is the local recovery and balance model once the trajectory is within a valid neighborhood.

## State and Event View

The model treats IQCOT as an event sequence with phase-indexed timing. Each event can perturb:

- phase current state;
- output voltage state;
- event interval `Lambda_i`;
- realized on-time `Ton_actual_i`;
- phase index and active-phase membership.

Small-signal updates estimate how differential timing and on-time trim move current imbalance and phase spacing over subsequent events.

## Actuator Separation

Use this preferred separation unless evidence revises it:

```text
Ton_diff    -> DC current-sharing trim
Lambda_diff -> phase-spacing and ripple-cancellation trim
```

`Ton_diff` should not be overused for fast voltage recovery when `a_U` large-signal recovery is active. `Lambda_diff` should not be used to hide persistent DC current imbalance that requires on-time or parameter correction.

## E030 Evidence Update

The first E030 DCR-mismatch controller chunk supports the actuator separation, but revises the strength of the closed-loop claim.

Validated local setup:

```text
experiment: E030 balance recovery
case: fixed 40 A load, fixed 4 phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
summary: experiments/E030_balance_recovery/e030_research_summary.md
metrics: experiments/E030_balance_recovery/e030_metrics.csv
classification: MODEL_REVISED
```

Measured result:

```text
C0 original DCR-mismatch imbalance = 0.853665 A
C1 Ton_diff-only imbalance = 0.313775 A
C2 Lambda_diff-only imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff imbalance = 0.313775 A
C4 projected balancer imbalance = 0.376221 A
```

Interpretation:

- `Ton_diff` is confirmed as the dominant DC current-sharing actuator in this local mismatch case.
- `Lambda_diff` is not a DC current-sharing actuator in this chunk; it is retained as a phase-spacing / ripple-recovery projection variable.
- Serially inserting a sampled MATLAB Function into the narrow REQ trigger path can drop events and is an implementation error for this model. The current E030 Lambda path is therefore side-band projection/logging only, not a direct trigger gate.
- The C4 projected balancer reduces Ton trim usage (`0.53786` vs `0.865969` for C1/C3) and reduces final Vout error magnitude (`23.494 mV` vs `58.156 mV`), but it does not beat the Ton_diff-only current-imbalance value.

The theory is therefore revised:

```text
Ton_diff provides the primary small-signal DC balance lever.
Safety projection must trade current-sharing speed against voltage error and trim usage.
Lambda_diff requires a non-sampling, event-native IQCOT parameter implementation before it can be claimed as an active phase-spacing actuator.
```

## Token Interface

PIS-IEK informs token `a_S`:

```text
K_T
T_trim_max
K_Lambda
Lambda_trim_max
balance_recovery_rate
phase_spacing_weight
current_balance_weight
```

The safety projection clamps differential trims and may slow recovery when voltage protection, current limits, or active-phase transitions are active.

## Validity

PIS-IEK claims are small-signal or recovery claims unless validated against large-signal derived models. Mismatch studies must include L, DCR, Ron, current-sense gain, and driver-delay perturbations before claiming robustness.

After E030, PIS-IEK may be used to motivate the `a_S` controller architecture and to claim local DCR-mismatch balance improvement in the ideal derived model. It may not yet be used to claim robust mismatch recovery across L, DCR, Ron, current-sense gain, and driver-delay families.
