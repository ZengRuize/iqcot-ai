# Metrics Definition

## Shared Definitions

All voltage metrics are measured against the nominal reference `Vref` unless a report states a different reference. Current metrics use phase-current logs `IL1..IL4` and load-current log `Iload`.

Settling time is the first time after the event when `Vout` remains within the declared settling band until the end of the evaluation window.

Final error is:

```text
Vout(t_end) - Vref
```

## E010 Load-Drop Overshoot Metrics

Use for load decrease tests.

```text
peak overshoot        = max(Vout - Vref) after event
early local peak 0-2us = max(Vout - Vref) in [0us, 2us]
recovery peak 2-12us  = max(Vout - Vref) in (2us, 12us]
late settling 12-80us = max abs(Vout - Vref) in (12us, 80us]
undershoot penalty    = max(Vref - Vout, 0) after event
reentry time          = first release time from protection/reentry state
skip count            = count of inhibited or skipped pulses during protection
final error           = Vout(t_end) - Vref
```

## E020 Load-Rise Undershoot Metrics

Use for load increase tests.

```text
peak undershoot      = max(Vref - Vout) after event
current rise time    = time for sum(IL1..IL4) to reach target load-current band
recovery overshoot   = max(Vout - Vref) after the undershoot minimum
phase current peak   = max over phases and time of IL_i
current limit hit    = boolean or count when current_limit_guard is active
settling time        = first sustained return to voltage band
final error          = Vout(t_end) - Vref
```

## E030 Balance Recovery Metrics

Use for mismatch and phase-recovery tests.

```text
max current imbalance       = max_t(max_i(IL_i) - min_i(IL_i))
RMS current imbalance       = rms_t(IL_i - mean_phase(IL))
phase spacing std           = std of realized inter-phase event spacing
output ripple               = peak-to-peak Vout in steady evaluation window
effective switching frequency = event count / active phase / evaluation time
trim usage                  = max and RMS of Ton_diff and Lambda_diff trims
```

## E040 Active-Phase Metrics

Use for 1/2/4 active-phase management tests.

```text
active phase timeline          = active_phase_set over time
add-phase time                 = event-to-new-phase-enabled delay
shed-phase time                = event-to-phase-disabled delay
new phase current ramp         = dIL/dt and settling of inserted phase
disabled phase residual current = current remaining after shed
phase spacing recovery time    = time to return to spacing band
overshoot/undershoot during add/shed = voltage extrema around transition
switching count / efficiency proxy = total switching events by phase
```
