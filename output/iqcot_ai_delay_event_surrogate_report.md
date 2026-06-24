# AI Delay Event-Domain Surrogate Results

## Experiment Scale

- Cut-load cases: `3`
- AI latency values: `[0.0, 0.5, 1.0, 2.0, 5.0]` us
- Update periods: `[2.0, 5.0, 10.0, 20.0]` us
- Policies: `['no_ai', 'zero_delay_trained', 'delay_aware', 'delay_aware_projected']`
- Seeds per cell: `64`
- Total episodes: `15360`
- Event period: `0.5 us`; `tau_AI=5 us` therefore spans `10` IQCOT events.

## Policy Meaning

- `no_ai`: no parameter adaptation.
- `zero_delay_trained`: controller designed as if the action acted immediately, then deployed with delayed actuation.
- `delay_aware`: predicts the event-domain state at the action arrival event before choosing `Lambda_diff/Ton_diff`.
- `delay_aware_projected`: adds PIS-IEK safety projection on voltage, phase-spacing, and current-sharing bounds.

## Representative Near-Zero Cut-Load Slice

| policy | tau_ai_us | delay_events | reward_mean | violations_mean | max_abs_phase_ns_p95 | max_abs_i_mA_p95 | tail_abs_phase_ns_mean | tail_abs_i_mA_mean | tail_state_cost_mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| delay_aware_projected | 0.000 | 0 | -926.303 | 57.781 | 125.457 | 1274.494 | 21.778 | 630.135 | 2.849 |
| zero_delay_trained | 0.000 | 0 | -766.193 | 25.172 | 125.457 | 1274.696 | 12.450 | 504.458 | 1.894 |
| delay_aware_projected | 0.500 | 1 | -900.127 | 45.391 | 125.457 | 1282.221 | 19.085 | 586.838 | 2.612 |
| zero_delay_trained | 0.500 | 1 | -739.966 | 21.609 | 125.457 | 1105.388 | 11.833 | 491.953 | 1.804 |
| delay_aware_projected | 1.000 | 2 | -948.282 | 58.156 | 125.457 | 1260.404 | 22.432 | 633.176 | 2.894 |
| zero_delay_trained | 1.000 | 2 | -637.369 | 17.219 | 125.457 | 1058.626 | 12.745 | 430.978 | 1.504 |
| delay_aware_projected | 2.000 | 4 | -796.209 | 25.531 | 125.457 | 1150.717 | 12.084 | 509.303 | 1.935 |
| zero_delay_trained | 2.000 | 4 | -804.981 | 29.172 | 125.457 | 1320.198 | 18.871 | 576.952 | 2.299 |
| delay_aware_projected | 5.000 | 10 | -802.252 | 24.297 | 125.457 | 1069.722 | 13.360 | 513.768 | 1.883 |
| zero_delay_trained | 5.000 | 10 | -2411.740 | 147.875 | 146.933 | 2316.900 | 60.276 | 1095.563 | 9.022 |

## Best Policy by Case / Delay / Update

| case | tau_ai_us | update_us | policy | reward_mean | violations_mean | max_abs_phase_ns_p95 | max_abs_i_mA_p95 | tail_abs_phase_ns_mean | tail_abs_i_mA_mean | tail_state_cost_mean |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 40A_to_10A | 0.000 | 5.000 | delay_aware | -694.070 | 27.766 | 112.457 | 1358.662 | 10.560 | 507.949 | 1.746 |
| 40A_to_10A | 0.000 | 10.000 | delay_aware | -2038.660 | 130.234 | 113.824 | 2244.290 | 40.520 | 947.364 | 6.864 |
| 40A_to_10A | 1.000 | 5.000 | zero_delay_trained | -637.803 | 22.750 | 112.457 | 1418.708 | 9.855 | 479.958 | 1.580 |
| 40A_to_10A | 1.000 | 10.000 | zero_delay_trained | -2022.782 | 128.625 | 120.975 | 2276.636 | 41.122 | 938.970 | 6.844 |
| 40A_to_10A | 2.000 | 5.000 | delay_aware | -690.844 | 26.969 | 112.457 | 1426.601 | 10.343 | 503.871 | 1.729 |
| 40A_to_10A | 2.000 | 10.000 | zero_delay_trained | -1939.305 | 126.422 | 129.963 | 2291.712 | 41.084 | 925.672 | 6.555 |
| 40A_to_10A | 5.000 | 5.000 | delay_aware | -671.128 | 25.234 | 112.457 | 1265.772 | 10.267 | 506.739 | 1.735 |
| 40A_to_10A | 5.000 | 10.000 | delay_aware | -1840.100 | 125.953 | 113.804 | 1997.876 | 39.992 | 953.152 | 6.600 |
| 40A_to_20A | 0.000 | 5.000 | delay_aware | -668.049 | 25.453 | 57.457 | 1227.654 | 10.191 | 506.653 | 1.731 |
| 40A_to_20A | 0.000 | 10.000 | delay_aware | -1926.549 | 132.672 | 113.536 | 2060.849 | 39.414 | 965.597 | 6.756 |
| 40A_to_20A | 1.000 | 5.000 | zero_delay_trained | -651.924 | 23.766 | 57.457 | 1252.221 | 10.177 | 500.043 | 1.690 |
| 40A_to_20A | 1.000 | 10.000 | delay_aware | -1872.883 | 130.844 | 98.588 | 1948.241 | 39.252 | 962.170 | 6.658 |
| 40A_to_20A | 2.000 | 5.000 | zero_delay_trained | -640.029 | 29.562 | 57.457 | 1319.342 | 15.798 | 548.014 | 2.024 |
| 40A_to_20A | 2.000 | 10.000 | delay_aware | -1829.237 | 128.484 | 91.757 | 1948.449 | 39.378 | 957.931 | 6.594 |
| 40A_to_20A | 5.000 | 5.000 | delay_aware | -642.146 | 22.922 | 57.457 | 1128.569 | 10.428 | 507.307 | 1.749 |
| 40A_to_20A | 5.000 | 10.000 | delay_aware | -1753.598 | 122.781 | 85.479 | 2007.585 | 39.635 | 956.851 | 6.611 |
| 40A_to_near0A | 0.000 | 5.000 | delay_aware | -766.193 | 25.172 | 125.457 | 1274.696 | 12.450 | 504.458 | 1.894 |
| 40A_to_near0A | 0.000 | 10.000 | delay_aware | -1953.500 | 130.750 | 125.457 | 1965.278 | 40.276 | 962.615 | 6.614 |
| 40A_to_near0A | 1.000 | 5.000 | zero_delay_trained | -637.369 | 17.219 | 125.457 | 1058.626 | 12.745 | 430.978 | 1.504 |
| 40A_to_near0A | 1.000 | 10.000 | zero_delay_trained | -1924.299 | 128.531 | 125.457 | 1878.293 | 40.548 | 954.047 | 6.521 |
| 40A_to_near0A | 2.000 | 5.000 | delay_aware | -784.315 | 23.047 | 125.457 | 1150.717 | 11.427 | 499.766 | 1.864 |
| 40A_to_near0A | 2.000 | 10.000 | zero_delay_trained | -1922.708 | 126.922 | 125.457 | 1915.140 | 40.933 | 948.984 | 6.481 |
| 40A_to_near0A | 5.000 | 5.000 | delay_aware_projected | -802.252 | 24.297 | 125.457 | 1069.722 | 13.360 | 513.768 | 1.883 |
| 40A_to_near0A | 5.000 | 10.000 | delay_aware | -1960.150 | 126.844 | 144.150 | 1946.052 | 43.417 | 943.605 | 6.558 |

## Key Findings

1. In the severe `40A->near-0A`, `T_update=5us` slice, a `5us` AI delay equals `10` event slots. The zero-delay-trained tuner reaches `147.875` mean violations, whereas the delay-aware projected tuner reaches `24.297`. Tail phase error drops from `60.276 ns` to `13.360 ns`, and tail current imbalance drops from `1095.563 mA` to `513.768 mA`.
2. At `tau_AI=1us`, the zero-delay-trained tuner is still competitive in the same slice (`reward=-637.369` versus `-772.161` for delay-aware). Thus the model should not claim that delay-aware AI is universally superior; it identifies the delay range where zero-delay training becomes a train-test mismatch.
3. Slower update periods are dangerous in this surrogate. Across adaptive policies, mean violations are `36.879` at `T_update=5us` but `206.782` at `T_update=20us`. This supports treating FPGA AI as a supervisory parameter tuner with an explicitly budgeted update period.

## Interpretation

The useful role of PIS-IEK is not to make a microsecond-latency AI act like a sub-nanosecond comparator. Instead, it lets the AI train and deploy in the same delayed event coordinates: `u_k` is evaluated as `u_{k-d}` with `d=ceil(tau_AI/T_event)`.  This removes a train-test mismatch that appears when a zero-delay tuner is deployed on FPGA with microsecond inference latency.

The projected policy is deliberately conservative.  Its value should be judged by lower violation rate and bounded phase/current excursions, not only by raw reward.  This matches the thesis that AI should tune low-dimensional IQCOT parameters under physical constraints instead of directly replacing the event generator.

## Boundary

This is a surrogate experiment.  The next stronger validation is to implement a controlled dynamic load in the Simulink copy and compare whether the same delay-aware policy ordering is preserved on switching waveforms.