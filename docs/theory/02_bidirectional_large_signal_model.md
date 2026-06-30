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

For the unresolved severe E010-A5 target, the same estimate becomes:

```text
Iload_before = 40A
Iload_after = 1A
DeltaI_drop = 39A
I_excess(t0+) ~= 39A
```

This first peak is a large-signal excess-current / excess-energy behavior. It must not be treated as a PIS-IEK small-signal first-peak prediction problem. PIS-IEK may only be used after protection and reentry for conservative current-sharing and event recovery.

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

### E010-A5 Severe-Drop Design Model

The severe `40A -> 1A` case is not solved by the current A4 selector:

```text
current status: A4 no-harm but non-improving
future folder: experiments/E010_load_drop_overshoot/A5_severe_drop_token/
status: DESIGN_ONLY
```

The proposed severe-drop token is:

```text
a_O_severe = [
  severe_drop_detect_enable,
  DeltaI_drop_threshold_high,
  active_HS_trunc_enable,
  Tton_trunc_min_severe,
  Tton_trunc_window_severe,
  multi_pulse_inhibit_count,
  inhibit_time_severe,
  inhibit_release_condition,
  area_integrator_hold_policy,
  area_integrator_bleed_policy,
  area_integrator_reset_policy,
  reentry_band_down_severe,
  controlled_reentry_Ton_limit,
  burst_pulse_limit_after_reentry,
  undershoot_budget_severe,
  late_settling_guard,
  fallback_to_A4_or_noop_guard
]
```

The design combines five mechanisms:

```text
1. active-HS-aware Ton truncation;
2. bounded multi-event pulse inhibit;
3. area-integrator hold / bleed / controlled reset;
4. stricter but undershoot-budgeted reentry;
5. fallback-to-A4/no-op if predicted undershoot or reentry risk is too high.
```

Severe-drop detection is evidence-local:

```text
DeltaI_drop = Iload_before - Iload_after
DeltaI_drop_threshold_high = 30A candidate

if branch == load_drop
and DeltaI_drop >= DeltaI_drop_threshold_high:
    enter SEVERE_DROP_DETECTED
```

The threshold is not a universal controller constant. It is a local candidate for the current ideal derived model and must be validated before any severe-drop improvement claim.

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

### Load-Rise Deficit-Charge Estimate

At the instant of a load rise, the load current can step faster than the inductor-current sum:

```text
I_Lsum(t0+) = I_Lsum(t0-)
I_def(t0+) = Iload_new - I_Lsum(t0+)
```

The first-order capacitor droop estimate is:

```text
Delta Vout_down ~= (1 / Cout) * integral(max(Iload(t) - I_Lsum(t), 0) dt)
```

This expression is a deficit-charge model. It is not a direct settling-time model because the later waveform also depends on IQCOT event density, minimum off-time, current limits, output-capacitor recharge, and recovery overshoot guards.

For one accepted high-side pulse in phase `i`, the local inductor-current increment is approximated by:

```text
Delta i_i,on ~= ((Vin - Vout) / L_i) * Ton_actual_i
```

Therefore the load-rise branch has two distinct event-domain levers:

```text
fast request / Lambda_cm_reduce:
  increase the number of accepted current-building events in the early window

Ton boost:
  increase the current increment per accepted event, subject to Ton and current guards
```

The two levers should be projected together because Ton boost without enough accepted events may have limited effect, while fast request without Ton boost may improve current slope but remain bounded by nominal pulse energy.

### E020 First-Chunk Result

The first E020 chunk used derived copies of the local ideal IQCOT baseline for the external `40A -> 120A` load-current rise:

```text
B0 original ideal IQCOT with observability
B1 fast request only
B2 Ton boost only
B3 fast request + Ton boost
```

Observed metrics:

```text
B0 peak undershoot: 397.42 mV
B1 peak undershoot: 343.79 mV
B2 peak undershoot: 382.41 mV
B3 peak undershoot: 319.08 mV

B0 90% current-rise time: 37.996 us
B1 90% current-rise time: 2.658 us
B2 90% current-rise time: 39.92 us
B3 90% current-rise time: 1.212 us

B3 phase-current peak: 34.09 A/phase
current-limit guard: not hit
```

This confirms the local mechanism that early event-density increase is the dominant first lever for the tested severe load rise, and bounded Ton boost is useful mainly when combined with fast request.

The same result also adds a boundary:

```text
B3 final error at 75-90us: -297.93 mV
settling time within 1 mV: not reached in the simulated window
```

Thus E020 supports a peak-undershoot and current-rise improvement claim for the first derived-Simulink chunk. It does not yet support a full recovery, final regulation, phase-add, or global 120A operating-boundary claim.

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
