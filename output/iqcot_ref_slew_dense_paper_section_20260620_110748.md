# Dense Reference-Slew Validation

## Motivation

The first reference-slew experiment established that `Iph_ref` transition time is a meaningful control variable, but its best point occurred at the largest tested value, `40 us`. A best point at the boundary is not strong evidence of an optimum. We therefore extended the sweep to `T_slew = 20, 30, 40, 50, 60, 80 us` for the same three cut-load cases.

## Results

The dense sweep adds `18` switching-level Simulink cases. Under the same tradeoff score,

```text
score = |final_vout_error_mV| + undershoot_mV + 0.02*phase_std_ns + 2*skip_count,
```

the best scanned points move beyond the original `40 us` boundary:

| Target load | Best scanned slew | Undershoot | Final Vout error | Skip | Phase std | Score |
|---:|---:|---:|---:|---:|---:|---:|
| `20 A` | `80 us` | `1.094 mV` | `-0.436 mV` | `0` | `37.140 ns` | `2.273` |
| `10 A` | `80 us` | `4.631 mV` | `-0.551 mV` | `1` | `82.183 ns` | `8.825` |
| `near-0 A` | `60 us` | `10.452 mV` | `-0.543 mV` | `2` | `90.263 ns` | `16.801` |

Compared with the nearly-instant reference update, these best scanned points reduce undershoot by `91.87%`, `80.57%`, and `70.76%` for the `20 A`, `10 A`, and near-zero-load targets, respectively. Compared with the previous `40 us` grid point, the tradeoff score improves by `9.09%`, `5.97%`, and `4.99%`.

## Interpretation

This result strengthens the AI-scheduling argument. The earlier `40 us` result was not merely a lucky isolated point; a broader `20-80 us` sweep confirms that slower reference scheduling continues to improve the safety/regulation trade-off over a range of cut-load severities. However, the optimum is not monotonic in every metric. In the near-zero-load case, `80 us` gives a slightly lower undershoot than `60 us`, but its larger phase-spacing standard deviation and final-error term increase the score. Thus an AI scheduler should not learn a one-dimensional rule such as "slower is always better"; it should optimize a constrained event-domain objective that includes undershoot, final regulation, phase spacing, skipped events, and settling.

## Paper-Level Claim

The refined claim should be:

> Dense reference-slew validation shows that `Iph_ref` transition time is a physically meaningful low-dimensional scheduling variable. In the current `20-80 us` grid, slower slew values improve the cut-load trade-off beyond the original `40 us` boundary, with best scanned points at `80 us`, `80 us`, and `60 us` for the three load targets. This supports using PIS-IEK to expose reference slew as an AI-tunable parameter, while avoiding any claim of global optimality.

