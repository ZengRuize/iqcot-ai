# E040-A Hypothesis

Date: 2026-06-29

## Scope

E040-A is the first minimal active-phase add validation chunk. It tests one conservative add-phase transition only:

```text
external load-current step: 20A -> 40A
initial active phases: 2
target active phases: 4
power-stage DCR: nominal
current-sense gains: nominal
active Lambda: disabled
baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` is not modified. Each E040-A model is a derived copy created through MATLAB/Simulink APIs.

## Hypothesis

A guarded active-phase add transition can increase the active set from two phases to four phases under a moderate load-rise case without introducing voltage disruption, REQ loss, phase-order error, current-limit hit, or post-add current-sharing instability.

## Frozen a_S Recovery

After add/reentry, balance recovery must use the frozen local guarded `a_S` selector from E030-R3:

```text
if sense_confidence == LOW:
    use no-op or low-gain Ton_diff fallback
elif calibration_enable == true and voltage/ripple risk is high:
    use calibrated C4a
elif calibration_enable == true and current imbalance dominates:
    allow calibrated C4c under voltage/ripple guards
else:
    fallback
```

For E040-A nominal sensing, active Lambda remains disabled and the first guarded recovery mode is a Ton-difference-only, confidence-checked mode.

## Expected Interpretation

`MODEL_CONFIRMED` requires the active-phase transition to be supported by voltage, current, REQ integrity, phase-order, and post-add balance metrics. A change in `active_phase_set` alone is not sufficient evidence.

## Forbidden Claims

E040-A cannot claim broad active-phase robustness, shed-phase behavior, arbitrary 1/2/4 phase scheduling, hardware/HIL/silicon validation, active Lambda control, global efficiency improvement, or full severe load-rise recovery.
