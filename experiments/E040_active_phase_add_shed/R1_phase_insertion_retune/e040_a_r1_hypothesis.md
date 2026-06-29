# E040-A-R1 Hypothesis

Date: 2026-06-29

## Scope

E040-A-R1 reruns only the first active-phase add case:

```text
external load-current step: 20A -> 40A
initial active phases: 2
target active phases: 4
power-stage DCR: nominal
current-sense gains: nominal
active Lambda: disabled
baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` is not modified. All models are derived copies created through MATLAB/Simulink APIs.

## R1 Hypothesis

The E040-A first chunk failed because active-phase insertion was not yet scheduler-order safe. A corrected active-phase remap plus insertion/relock gating should allow the local `2 -> 4` add transition to complete with:

```text
N_active_final = 4
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_add = 0
current_limit_hit = 0
```

Voltage recovery is expected to improve relative to the fixed two-phase reference, but R1 does not claim severe load-rise recovery or global active-phase benefit.

## Selected Two-Phase Mapping

R1 uses the two-phase physical set:

```text
active_phase_set = [1, 3]
physical phase sequence = [1, 3]
```

The four-phase scheduler slots are remapped before add:

```text
raw slot 1 -> physical phase 1
raw slot 2 -> physical phase 3
raw slot 3 -> physical phase 1
raw slot 4 -> physical phase 3
```

After add/relock, accepted events return to:

```text
physical phase sequence = [1, 2, 3, 4]
```

Each accepted scheduler event maps to exactly one active physical phase.

## Frozen a_S Boundary

The E030-R3 guarded `a_S` selector remains frozen. In R1, `a_S` is disabled until:

```text
N_active == 4
new_phase_ramp_state == COMPLETE
order_relock_window_done == true
phase_order_error_rate_post_add == 0
dropped_REQ_count_window == 0
```

Active Lambda remains disabled.

## Forbidden Claims

R1 cannot claim broad active-phase robustness, 4->2 shed behavior, arbitrary 1/2/4 scheduling, active Lambda control, severe `40A -> 120A` recovery, efficiency gain, hardware, HIL, board-level, or silicon validation.
