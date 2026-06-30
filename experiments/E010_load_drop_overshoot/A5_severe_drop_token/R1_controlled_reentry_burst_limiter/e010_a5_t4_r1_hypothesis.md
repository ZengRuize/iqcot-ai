# E010-A5-T4-R1 Hypothesis

Date: 2026-06-30

## Scope

This is the smallest controlled-reentry revision after the A5-T4 severe-drop proxy failed the post-reentry burst guard.

Fixed case:

```text
external load-current drop: 40A -> 1A
active phases: fixed four-phase
power-stage DCR: nominal
current-sense gains: nominal
active Lambda: disabled
active-phase add/shed: disabled
baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The load-current transition is an external disturbance. The AI/table supervisor may observe its direction and magnitude, but does not command load-current slew and does not command gates.

## Hypothesis

A5-T4 showed a small recovery-peak reduction in the local `40A -> 1A` severe-drop case, but it violated the burst guard:

```text
recovery peak 2-12us: 3.55696 mV versus 3.61172 mV baseline
recovery peak 12-40us: 3.53370 mV versus 3.59863 mV baseline
burst count / limit: 5 / 2
```

R1 tests the hypothesis that explicit burst-limited controlled reentry can preserve the T4 recovery-peak reduction while reducing post-reentry accepted pulses to the guard limit:

```text
burst_pulse_count_after_reentry <= 2
peak_undershoot_mV <= 2.0
dropped_REQ_count == 0
phase_order_error_rate == 0
current_limit_hit == false
late_settling_guard_violation == false
```

## Candidate Mechanism

R1 adds a count/window limiter after the first accepted reentry pulse:

```text
burst_count_window_us = 2
burst_pulse_limit_after_reentry = 2
reentry_min_inter_pulse_spacing_us = 0.4
first_reentry_Ton_limit_ns = 200
area_int_reentry_clamp = optional by variant
recovery_Ton_ramp_rate = optional by variant
```

Variants:

```text
R1-T4a: explicit burst limiter + conservative inter-pulse spacing
R1-T4b: R1-T4a + area-int reentry clamp
R1-T4c: R1-T4b + conservative recovery Ton ramp
```

## Revision Criteria

R1 is useful only if a candidate satisfies improvement and guards together. A reduction of positive recovery peaks is not useful if it is caused by deep Vout collapse or unacceptable final regulation error.

If all R1 variants fail, the theory must be revised from "count-limited reentry is sufficient" to:

```text
A5 severe-drop recovery requires reentry energy shaping and scheduler-level event reconstruction, not only accepted-pulse counting.
```

## Post-Run Outcome

The executed R1 set is classified as `MODEL_REVISED`. All R1-T4a/b/c candidates suppressed positive recovery peaks only by creating severe undershoot:

```text
peak_undershoot_mV = 971.618
final_Vout_error_mV = -919.625
REQ_reject_count = 170
burst count / limit = 5 / 2
guard_pass = false
```

The evidence supports the negative/revision hypothesis: a count-based burst limiter in this insertion path is not enough to make A5 pass the severe-drop guard.
