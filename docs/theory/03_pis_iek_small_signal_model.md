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
