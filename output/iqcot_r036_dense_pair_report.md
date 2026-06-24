# R036 Dense-Paired Boundary Validation

## Scope

R036 adds the two dense `30us` fallback rows that were missing from the R035
pending points: `20A/score_settle005` at `tau_AI=1.25us` and `1.75us`.
The run uses only the derived delayed-reference Simulink model under
`output/simulink_iek`; it does not modify the original `.slx` and is not
hardware validation.

## Paired Result

| tau_ai_us | dense_slew_us | dense_score | dense_skip_count_est | dense_phase_std_ns | folded_best_slew_us | folded_best_score | folded_skip_count_est | folded_phase_std_ns | dense_minus_folded_score | winner_role |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1.250 | 30.000 | 4.989 | 1.000 | 70.102 | 46.000 | 2.146 | 0.000 | 32.960 | 2.843 | folded_transition_probe |
| 1.750 | 30.000 | 4.317 | 1.000 | 41.923 | 54.000 | 2.142 | 0.000 | 32.624 | 2.175 | folded_transition_probe |

Both newly simulated dense fallback rows lose to the R034 folded probes.  The
loss is not just a score artifact: the `30us` fallback triggers one estimated
skip in both paired rows, while the winning folded probes have zero estimated
skip and lower phase-spacing standard deviation.

## Policy Update

- `tau_AI=1.25us`: upgrade `46us` from candidate-only to local dense-pair
  validated commit inside the current derived-model objective.
- `tau_AI=1.75us`: upgrade `54us` from candidate-only to local dense-pair
  validated commit inside the current derived-model objective.
- `tau_AI=2.0us` remains a separate boundary: R035/R031 dense-inclusive
  evidence still keeps `30us` fallback there, despite R034 transition probes.
- `66us` remains blocked as a direct override.

## Short-Horizon r_hat Interface

The R036 training view keeps only deployable context/candidate inputs
(`target_load_A`, `load_drop_norm`, `alpha_settle`, `tau_AI`,
`delay_events`, `candidate T_slew`, and candidate distance from dense
fallback).  Skip, settling, and phase columns are labels derived from the
switching replay, not online inputs.  This gives a small calibration target for
a future short-horizon predictor:

```text
r_hat(z_k,T_slew,tau_AI,recent_event_state)
  -> [skip_risk, settling_risk, phase_risk]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate; r_hat, T_dense)
```

## Boundary

R036 strengthens the local folded-band evidence at two missing dense-paired
delays, but it still does not prove a global `T_slew` optimum or hardware
safety.  AI remains a supervisory parameter scheduler; IQCOT remains the inner
event loop.
