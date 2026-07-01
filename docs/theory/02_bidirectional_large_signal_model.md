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

For severe load drop:

```text
I_excess(t0+) = I_Lsum(t0+) - Iload_after
```

For `40A -> 1A`, the initial excess-current estimate is approximately `39A`. This first voltage peak is dominated by large-signal excess-current / excess-charge / excess-energy behavior. It must not be treated as a PIS-IEK small-signal first-peak prediction problem. PIS-IEK may only be used after protection and reentry for conservative current-sharing and event recovery.

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
A5-C0/A5-C4 baseline audit: MODEL_CONFIRMED
A5-T1/T2/T3/T4 candidate comparison: MODEL_REVISED
A5-T4-R1 controlled-reentry burst-limiter revision: MODEL_REVISED
E010-A5-R2 reentry energy shaping / scheduler release: MODEL_REVISED
E010-A5-R3 event-queue energy allocation: MODEL_REVISED
```

After R3, A5 is frozen as revised boundary evidence rather than a continuing projected-scheduling tuning path. Projected IQCOT scheduling variants repeatedly showed the same severe-branch tradeoff:

```text
too permissive -> no improvement or bursty reentry
moderately shaped -> partial recovery-peak reduction with undershoot / burst guard failure
too restrictive -> recovery starvation, severe undershoot, and final-error collapse
```

The severe-drop token remains a design/revision candidate, not a validated action:

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
  burst_count_window_us,
  reentry_min_inter_pulse_spacing_us,
  first_reentry_Ton_limit_ns,
  recovery_Ton_ramp_rate,
  event_queue_enable,
  queue_max_depth,
  queue_release_min_spacing,
  queue_release_max_per_window,
  per_event_Ton_allocation_policy,
  area_int_queue_coupling_policy,
  area_int_reentry_clamp,
  undershoot_budget_severe,
  late_settling_guard,
  fallback_to_A4_or_noop_guard
]
```

The design combines these mechanisms:

```text
1. active-HS-aware Ton truncation;
2. bounded multi-event pulse inhibit;
3. area-integrator hold / bleed / controlled reset;
4. stricter but undershoot-budgeted reentry;
5. per-event reentry energy/Ton shaping;
6. scheduler-release shaping with voltage-window and burst guards;
7. event-queue / per-event Ton allocation with explicit accounting;
8. fallback-to-A4/no-op if predicted undershoot or reentry risk is too high.
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

### E010-A5-T4-R1 Controlled-Reentry Revision

The T4 proxy reduced the local severe-drop recovery peaks but failed the burst guard:

```text
A5-T4proxy recovery peak 2-12us = 3.55696 mV
A5-T4proxy recovery peak 12-40us = 3.53370 mV
A5-T4proxy burst count / limit = 5 / 2
```

R1 tested explicit count/window burst limiting, optional area-integrator reentry clamp, and optional Ton ramp:

```text
R1-T4a: burst limiter + conservative inter-pulse spacing
R1-T4b: R1-T4a + area-int reentry clamp
R1-T4c: R1-T4b + recovery Ton ramp
```

The R1 outcome is `MODEL_REVISED`, not `MODEL_CONFIRMED`:

```text
R1-T4a/b/c peak overshoot = 0 mV
R1-T4a/b/c recovery peaks = 0 mV
R1-T4a/b/c peak undershoot = 971.618 mV
R1-T4a/b/c final Vout error = -919.625 mV
R1-T4a/b/c burst count / limit = 5 / 2
```

The zero positive peaks are not useful recovery improvement. They occur because the output collapses into a severe undershoot and final-error failure. Therefore the revised large-signal model is:

```text
valid severe-drop reentry
  requires both:
    bounded positive surplus-charge reinjection
    bounded negative deficit-charge created by protection
  and cannot be certified by accepted-pulse count alone
```

In charge form, a count constraint:

```text
n_window <= n_limit
```

is insufficient. The projected reentry must also bound the signed recovery charge:

```text
Q_reentry(t) =
  integral_window(I_Lsum(t) - Iload_new) dt

-Cout * V_undershoot_budget
  <= Q_reentry(t)
  <= Cout * V_recovery_peak_budget
```

and the per-event energy distribution:

```text
E_pulse,k ~= integral_pulse(Vin - Vout) * i_L,phase(k) dt
```

must be shaped by voltage, area-integrator, and phase-scheduler state. The next A5 revision should therefore reconstruct the reentry energy distribution and scheduler release conditions rather than only counting accepted pulses after reentry.

### E010-A5-R2 Reentry Energy-Shaping Revision

R2 tested the fixed severe `40A -> 1A` external load-current drop with fixed four phases, nominal DCR/sense gains, active Lambda disabled, and active-phase add/shed disabled:

```text
experiment: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/
variants: R2-E1, R2-E2, R2-E3, R2-E4
classification: MODEL_REVISED
```

The R2 hypothesis was that R1 failed because scheduler release was treated as pulse counting, while the real variable is signed recovery energy per accepted event. The tested proxy budget was:

```text
E_reentry_budget_proxy = sum(Ton_actual_i over reentry_window)
```

R2-E1 and R2-E2 confirm that per-event Ton shaping is meaningful but incomplete:

```text
R2-E1/E2 peak overshoot = 3.51629 mV
R2-E1/E2 recovery peak 2-12us = 1.75366 mV
R2-E1/E2 recovery peak 12-40us = 3.51629 mV
R2-E1/E2 peak undershoot = 7.63188 mV
R2-E1/E2 burst count / limit = 5 / 2
```

Thus energy budget plus Ton ramp reduces positive recovery peaks, but violates the negative-energy and burst guards. The area-int soft preload in E2 was observable, but did not change the waveform versus E1, so it is not yet a validated actuator path.

R2-E3 and R2-E4 revise the scheduler-release model:

```text
R2-E3/E4 peak overshoot = 0 mV
R2-E3/E4 peak undershoot = 971.618 mV
R2-E3/E4 final Vout error = -919.625 mV
R2-E3/E4 REQ reject count = 170
R2-E3/E4 burst count / limit = 5 / 2
```

Voltage-window release did not rescue E4 because the current release gate still starved the converter of recovery energy. Therefore a valid severe-drop reentry model must release an event queue with a signed energy allocation constraint, not gate the final accepted request path as a scalar fraction:

```text
release_ok(k) =
  phase_order_ok(k)
  and Vout within signed recovery window
  and Q_reentry_min <= Q_reentry_accum + Q_event,k <= Q_reentry_max
  and burst_density_window <= burst_limit
```

The severe-drop claim remained revised after R2. R3 below tested the next structural hypothesis and shows that the current event-queue insertion still does not safely solve the severe branch.

### E010-A5-R3 Event-Queue Energy-Allocation Revision

R3 tested the fixed severe `40A -> 1A` external load-current drop with fixed four phases, nominal DCR/sense gains, active Lambda disabled, and active-phase add/shed disabled:

```text
experiment: experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/
variants: R3-E1, R3-E2, R3-E3
classification: MODEL_REVISED
```

The R3 hypothesis was that reentry should be treated as event-queue energy allocation rather than pulse blocking, count-only burst limiting, or scalar scheduler gating:

```text
each request is served, deferred, resized, or released later
Ton_allocated = min(Ton_requested, Ton_budget_remaining, Ton_ramp_limit)
```

The implemented queue and accounting signals were observable, but the tested insertion still produced recovery starvation:

```text
R3-E1/E2/E3 peak overshoot = 0 mV
R3-E1/E2/E3 recovery peaks = 0 mV
R3-E1/E2/E3 peak undershoot = 971.618 mV
R3-E1/E2/E3 final Vout error = -919.625 mV
R3-E1/E2/E3 burst count / limit = 5 / 2
R3-E1/E2/E3 phase_order_error_rate = 1
```

This revises the event-queue model:

```text
positive-peak suppression is not evidence of safe excess-energy removal
if it is produced by negative-energy collapse.
```

For the severe branch, projected IQCOT scheduling must satisfy the signed energy bounds and event-integrity guards together:

```text
Q_min <= Q_reentry_accum + Q_event,k <= Q_max
Vout_undershoot <= undershoot_budget
burst_density <= burst_limit
phase_order_error_rate == 0
final_error within guard
```

R3-E3 was not close to passing, so the optional voltage-windowed R3-E4 was not run. The current severe-drop evidence supports only a `MODEL_REVISED` boundary statement: projected scheduling has partial/revision evidence, but the local `40A -> 1A` severe-drop improvement remains unvalidated. A future step must either keep this boundary as future work or introduce a structurally different large-signal energy-management mechanism beyond this projected scheduling path.

### Frozen Severe-Drop Boundary After A5

The A5 conclusion is:

```text
Projected pulse scheduling can reduce or delay energy injection,
but if it is too aggressive it starves recovery and creates undershoot/final-error collapse.
If it is too permissive it allows bursty reentry.
The tested A5 variants did not find a guard-passing middle path.
```

This is not a failure of the whole research direction. It defines the boundary of the current projected supervisory scheduling action set. A structurally different future mechanism, such as an energy dump/clamp path or controlled recirculation mode, belongs to A6 future work and is not part of the validated A5 claim.

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

### E020-R1 a_U Window-Tuning Result

E020-R1 tested whether the confirmed early `a_U` benefit can be preserved while improving late recovery by changing only the fast-request / Ton-boost window shape:

```text
experiment: experiments/E020_load_rise_undershoot/R1_aU_window_tuning/
case: 40A -> 120A external load-current rise
active phases: fixed four-phase
active Lambda: disabled
active-phase add/shed: disabled
classification: MODEL_CONFIRMED
```

The projected Ton boost is modeled as a bounded event-energy increment:

```text
Ton_i,R1(t) =
  Ton_i,nom + (Tton_boost_max - Ton_i,nom)
              * exp(-k_boost * (t - t0))
```

only while:

```text
branch == load_rise
Vout <= Vref - undershoot_band
t0 <= t <= t0 + boost_window
|IL_i| <= current_limit_guard
```

Outside the boost window the projection falls back to nominal IQCOT Ton:

```text
Ton_i,R1(t) = Ton_i,nom
```

R1 compared carry-forward `R1-B0/R1-B3` references with four new derived-copy variants:

```text
R1-U1:
  boost_window = 1.5 us
  Tton_boost_max = 260 ns
  decay_rate = 5e5 1/s

R1-U2:
  boost_window = 1.5 us
  Tton_boost_max = 245 ns
  decay_rate = 5e5 1/s

R1-U3:
  boost_window = 3.0 us
  Tton_boost_max = 260 ns
  decay_rate = 1e6 1/s

R1-U4:
  same as R1-U3
  late_recovery_guard = enabled
  fallback when current target, error slope, or recovery band guard triggers
```

Measured result:

```text
B3:
  peak undershoot = 319.081 mV
  90% current-rise time = 1.212 us
  final Vout error = -297.928 mV

R1-U1:
  peak undershoot = 318.801 mV
  90% current-rise time = 1.196 us
  final Vout error = -297.766 mV
  REQ/accepted/dropped = 199/199/0
  phase_order_error_rate = 0
  current_limit_hit = false

R1-U2:
  peak undershoot = 325.954 mV
  final Vout error = -303.170 mV

R1-U3:
  peak undershoot = 346.678 mV
  90% current-rise time = 45.018 us
  final Vout error = -328.811 mV

R1-U4:
  peak undershoot = 344.252 mV
  90% current-rise time = 1.466 us
  final Vout error = -323.979 mV
  late_recovery_guard_trigger_count = 78
```

This revises the load-rise model in a narrow way:

```text
useful early deficit filling
  = fast request event density
    + short bounded Ton energy boost

late recovery improvement
  is not monotonic in lower Ton boost gain, stronger decay, or the tested
  late-recovery guard.
```

The R1-U1 final-error improvement over B3 is only `0.162402 mV`, and no R1 variant settled within `1 mV` in the `90 us` post-step window. Therefore R1 confirms a local window-tuned `a_U` refinement, not complete `40A -> 120A` recovery.

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
