# Bidirectional Large-Signal Model

## Disturbance Model

The load current trajectory is an external disturbance:

```text
Iload(t) = external test profile
```

The supervisor may estimate and observe:

```text
direction, magnitude, initial current, final current, estimated slew
```

The supervisor must not command these quantities. Test profiles are validation inputs, not AI actions.

## Load-Drop Branch: Overshoot / Excess Current

For a load decrease such as `40A -> 10A`, the inductor current initially exceeds the new load demand. The large-signal hazard is excess energy delivery to the output capacitor and resulting voltage overshoot.

Primary controls after safety projection:

- truncate or disable high-side on-time during the protection window;
- inhibit selected future pulses;
- hold or reset integrator states according to a reentry policy;
- define a reentry band and release condition;
- avoid reentry actions that cause a second overshoot peak.

The load-drop branch uses token `a_O`.

### Load-Drop Energy and Charge Estimate

At the instant of a load drop, the inductor-current sum cannot change discontinuously:

```text
I_Lsum(t0+) = I_Lsum(t0-)
I_ex(t0+) = I_Lsum(t0+) - Iload_new
```

For a `40A -> 10A` drop near balanced four-phase operation, the initial excess-current estimate is approximately:

```text
I_ex0 ~= 40A - 10A = 30A
```

The output-capacitor voltage rise is dominated by surplus charge:

```text
Delta Vout ~= (1 / Cout) * integral(max(I_Lsum(t) - Iload_new, 0) dt)
```

and the stored excess magnetic energy provides a companion bound:

```text
Delta E_L ~= 0.5 * L * sum_i(i_Li(t0)^2 - i_Li,new^2)
Delta Vout_energy <= sqrt(Vref^2 + 2 * Delta E_L / Cout) - Vref
```

These estimates are intentionally conservative because real IQCOT pulse skipping, diode/synchronous paths, ESR, and control reentry reshape the waveform.

For a high-side pulse that remains enabled after the load drop, the phase-current increment is approximately:

```text
Delta i_pulse ~= ((Vin - Vout) / L) * Ton_actual
```

Ton truncation reduces the incremental current by:

```text
Delta i_saved ~= ((Vin - Vout) / L) * max(Ton_nom - Tton_trunc_min, 0)
```

and reduces the near-term surplus charge by:

```text
Delta Q_saved ~= sum_pulse integral(Delta i_saved(t) dt)
```

Therefore A1 `Ton truncation only` should mainly reduce early/recovery overshoot when the load drop occurs before or during high-side energy injection. It may not improve late settling if the remaining error is dominated by reentry, skip timing, or the fixed load profile. It can also increase undershoot if `Tton_trunc_min` or `Tton_trunc_window` is too aggressive.

### E010 First-Chunk Revision

The first validated E010 chunk used a derived-copy `40A -> 10A` external load-current step:

```text
A0 original ideal IQCOT
A1 Ton truncation only
A2 Ton truncation + one early pulse inhibit
A3 guarded reentry
A4 table-selected a_O
```

Observed metrics revise the load-drop model:

```text
A0 recovery peak 2-12us: 2.36936 mV
A1 recovery peak 2-12us: 2.14559 mV
A2 recovery peak 2-12us: 1.84342 mV
A4 recovery peak 2-12us: 1.84342 mV
```

Thus Ton truncation alone is a partial energy-injection correction, not a complete load-drop protection mechanism. It reduced the recovery peak by about `9.44%` but did not reduce the global peak in the first chunk.

One early event-domain pulse inhibit reduced the recovery peak by about `22.2%` versus A0 and slightly reduced the global peak, but introduced a bounded undershoot penalty:

```text
A2/A4 undershoot penalty: 0.863951 mV
```

The revised load-drop model is therefore:

```text
Delta Vout_peak
  = f(excess inductor current already stored at t0,
      residual high-side Ton energy,
      first accepted reentry trigger,
      safety-projected release condition)
```

where:

- `Ton truncation` reduces residual high-side energy after the disturbance;
- `pulse inhibit` changes the first accepted reentry trigger and can lower the recovery peak;
- `reentry_band_down` is a safety projection variable that trades overshoot reduction against undershoot penalty;
- a binding reentry guard may reject pulse inhibit, returning the behavior toward A1.

## Load-Rise Branch: Undershoot / Deficit Current

For a load increase such as `40A -> 120A`, the inductor current initially lags the new load demand. The large-signal hazard is energy deficit and resulting voltage undershoot.

Primary controls after safety projection:

- enable fast request handling;
- reduce common-mode `Lambda` when safe;
- boost on-time within a bounded window;
- override minimum off-time only within current and timing guards;
- add a phase quickly when load-rise add-phase protection is active;
- preload or hold integrator states to prevent recovery overshoot.

The load-rise branch uses token `a_U`.

## Branch Selection

Branch selection is event driven:

```text
if dIload_est < 0 -> load-drop branch
if dIload_est > 0 -> load-rise branch
otherwise -> small-signal / balance branch
```

The branch selector uses the observed disturbance estimate. It is not an actuator on the disturbance.

## Required Metrics

Load-drop validation measures peak overshoot, early local peak, recovery peak, late settling, undershoot penalty, reentry time, skip count, and final error.

Load-rise validation measures peak undershoot, current rise time, recovery overshoot, phase current peak, current-limit hit, settling time, and final error.
