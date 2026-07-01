# E020-R1 a_U Window Tuning Hypothesis

Date: 2026-07-01

## Fixed Scope

This experiment uses the local ideal IQCOT baseline only through derived model copies:

`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`

The validation case is fixed:

- external load-current rise: `40A -> 120A`;
- active phases: fixed four-phase;
- nominal DCR and current-sense gains;
- active Lambda disabled;
- active-phase add/shed disabled.

The external load-current slew and step are validation disturbances. They are observed by the supervisor but are not AI-controlled variables.

## Hypothesis

The first E020 chunk confirmed that fast request plus Ton boost improves the early load-rise response.
However, the existing B3 action does not demonstrate full 120A recovery or 1 mV settling.

The likely issue is that the a_U boost window is not shaped for both early energy deficit and late recovery.
A useful R1 tuning should preserve the peak-undershoot and current-rise benefits of B3 while reducing late final-error and avoiding current-limit, phase-order, and REQ-integrity violations.

## a_U Token Under Test

```text
a_U = [
    fast_req_enable,
    fast_req_window_us,
    fast_req_threshold_mV,
    Ton_boost_enable,
    Ton_boost_gain,
    Ton_boost_window_us,
    Ton_boost_decay_policy,
    current_rise_target,
    current_limit_guard,
    late_recovery_guard,
    fallback_to_B0_guard
]
```

R1 tests whether early boost should be strong but short, then decay or hand back to nominal IQCOT before it creates late recovery bias.

## Variants

- `R1-B0`: carry-forward original E020 B0 reference.
- `R1-B3`: carry-forward previous E020 B3 fast request + Ton boost reference.
- `R1-U1`: `0.5 * B3` Ton-boost window, B3 boost gain, B3 fast-request behavior.
- `R1-U2`: `0.5 * B3` Ton-boost window, `0.75 * B3` boost gain, B3 fast-request behavior.
- `R1-U3`: B3 window with stronger exponential decay back to nominal Ton, fast request active only during the first deficit window.
- `R1-U4`: `R1-U3` plus late-recovery guard that forces nominal Ton when the current target is reached, the Vout-error slope changes sign, or Vout enters the recovery band.

All four R1 variants are run as the smallest fixed-case tuning set. No Cartesian sweep or broad load-rise grid is part of R1.

## Claim Boundary Before Running

Do not claim full 120A recovery unless the R1 metrics show meaningful final-error or settling evidence. If R1 only gives a marginal final-error movement, the E020 claim remains limited to local early peak-undershoot reduction, current-rise acceleration, and a narrow window-tuning refinement.
