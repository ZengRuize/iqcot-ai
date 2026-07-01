# Derivation Package

## Target

Derive the local load-rise `a_U` mechanism used in E020: why an external `40A -> 120A` load-current rise creates a voltage undershoot, and why fast request plus bounded Ton boost should reduce peak undershoot without being claimed as a full settling guarantee.

## Status

COHERENT AFTER REFRAMING / R1 CLAIM BOUNDARY FROZEN

The coherent target is peak-undershoot reduction and early current-rise acceleration. E020-R1 freezes R1-U1 as a narrow local window-tuned `a_U` candidate. A full recovery or 120A steady-regulation theorem is not supported by the E020/E020-R1 evidence.

## Invariant Object

The invariant object is the positive deficit charge:

```text
Q_def(T) = integral_{t0}^{t0+T} max(Iload(t) - I_Lsum(t), 0) dt
```

Peak undershoot is treated as a capacitor-deficit consequence of `Q_def`, not as a complete settling-time model.

## Assumptions

- The load-current trajectory is an external validation disturbance.
- The AI/table supervisor observes load-step features but does not command load slew.
- IQCOT remains the deterministic event and pulse generator.
- The derived model uses the local ideal four-phase IQCOT baseline.
- Capacitor droop is approximated by deficit charge over the early transient.
- ESR, digital quantization, COT reentry, and recovery overshoot modify the waveform and are measured by simulation rather than proved away.
- Ton boost and fast request are bounded by current and timing guards.

## Notation

- `Iload(t)`: external load-current profile.
- `i_Li(t)`: inductor current of phase `i`.
- `I_Lsum(t) = sum_i i_Li(t)`.
- `I_def(t) = Iload(t) - I_Lsum(t)`.
- `Cout`: output capacitance.
- `Ton_actual_i`: realized high-side on-time for phase `i`.
- `N_ev(T)`: accepted current-building events in the early window.
- `P_U`: safety projection for `a_U`.

## Derivation Strategy

Start from output-capacitor charge balance, isolate the positive deficit current after a load rise, then decompose the control effect into event density and per-event current increment.

## Derivation Map

1. Capacitor charge balance relates `dVout/dt` to `I_Lsum - Iload`.
2. Load rise creates `I_def(t0+) > 0` because inductor current cannot step.
3. Peak undershoot is approximated by the accumulated positive deficit charge.
4. Fast request reduces `Q_def` mainly by increasing accepted event density.
5. Ton boost reduces `Q_def` mainly by increasing per-event current increment.
6. Safety projection clamps both actions by branch, timing, voltage, and current guards.

## Main Derivation

Step 1. Charge balance is the organizing identity:

```text
Cout * dVout/dt ~= I_Lsum(t) - Iload(t)
```

This is an approximation because ESR and switching ripple are not explicitly separated in this scalar expression.

Step 2. At a load-current rise:

```text
I_Lsum(t0+) = I_Lsum(t0-)
I_def(t0+) = Iload_new - I_Lsum(t0+) > 0
```

This is an identity plus the load-rise condition.

Step 3. The early voltage droop is approximated by:

```text
Delta V_under(T) ~= (1 / Cout) * Q_def(T)
Q_def(T) = integral_{t0}^{t0+T} max(I_def(t), 0) dt
```

This is the main local model. It predicts that reducing the area of positive current deficit reduces peak undershoot.

Step 4. A high-side event in phase `i` changes current approximately by:

```text
Delta i_i,on ~= ((Vin - Vout) / L_i) * Ton_actual_i
```

This is a local slope approximation over one on-time interval.

Step 5. Event-domain control reduces `Q_def` through two mechanisms:

```text
fast request:
  increases N_ev(T)

Ton boost:
  increases Delta i_i,on per accepted event
```

Therefore the expected ordering for a severe load rise is:

```text
B3 fast request + Ton boost  <=  B1 fast request only  <=  B0
B2 Ton boost only may be weak if N_ev(T) is unchanged
```

where lower means lower peak undershoot.

Step 6. E020 matches this mechanism in the local derived model:

```text
B0 peak undershoot = 397.42 mV
B1 peak undershoot = 343.79 mV
B2 peak undershoot = 382.41 mV
B3 peak undershoot = 319.08 mV

B0 90% current-rise time = 37.996 us
B3 90% current-rise time = 1.212 us
```

## Remarks and Interpretation

- Fast request is the dominant first action in the tested severe load-rise case.
- Ton boost alone is weak because it does not increase the number of accepted events.
- Ton boost becomes useful when fast request creates enough early events for the larger per-event increment to matter.
- The current guard was not hit in the first E020 chunk.

## R1 Window-Tuning Result

The first E020 chunk showed:

```text
B3 = fast request + Ton boost
peak undershoot = 319.081 mV
90% current-rise time = 1.212 us
final error = -297.928 mV
```

R1-U1 gives:

```text
peak undershoot = 318.801 mV
90% current-rise time = 1.196 us
final error = -297.766 mV
```

This is a narrow improvement:

```text
Delta peak undershoot vs B3 = -0.280 mV
Delta current rise vs B3 = -0.016 us
Delta final error vs B3 = +0.162 mV toward zero
```

Interpretation:

```text
a_U window tuning preserves and marginally refines the early benefit.
It does not establish 1 mV settling or full 120A recovery.
```

U3 shows that an overly decayed or poorly timed boost policy can destroy the early current-rise benefit. U4 shows that the tested late-recovery guard triggers frequently but does not improve late recovery, so scalar guard insertion alone is not the missing late-recovery mechanism.

## Frozen E020-R1 Claim Boundary

`R1-U1` is the frozen local `a_U` candidate for manuscript figures and local mechanism discussion. It is not evidence of global optimality, active Lambda coupling, active-phase interaction, mismatch robustness, or hardware/HIL behavior.

## Boundaries and Non-Claims

- This derivation does not prove complete recovery or final regulation.
- The first E020 run did not settle within `1 mV` in the `90 us` post-step window.
- B3 final error remained about `-297.93 mV` over `75-90 us`.
- E020-R1 did not change that settling boundary; R1-U1 only gives a marginal final-error improvement.
- The result is derived-Simulink evidence, not hardware, HIL, board-level, or silicon evidence.
- The load-current slew is not a controlled action.
- AI/table does not command QH/QL gates.

## Open Risks

- The severe `40A -> 120A` step may be close to or beyond the useful operating boundary of the current ideal baseline within the simulated window.
- The Ton boost window may need retuning after E030 current-sharing constraints are known.
- Phase-add is intentionally excluded from this first E020 chunk and must not be claimed yet.
