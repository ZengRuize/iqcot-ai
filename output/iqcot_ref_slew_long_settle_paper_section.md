# Long Reference-Slew and Settling-Aware Objective Sensitivity

The dense `20-80 us` sweep showed that the best scanned points for the `20 A` and `10 A` targets were still located at the upper grid boundary. We therefore extended the scan to `80,100,120 us` and then evaluated whether adding an explicit settling-time penalty changes the preferred reference slew.

The long-slew scan confirms that slower reference updates can continue to reduce undershoot, but not without cost. For the near-zero-load case, `120 us` gives the lowest undershoot among the long-grid points (`9.892 mV`), but its settling time increases to `71.408 us` and its phase-spacing standard deviation is `118.430 ns`. When the dense and long grids are combined under the original score, the best scanned points are still `80 us`, `80 us`, and `60 us` for the `20 A`, `10 A`, and near-zero-load targets, respectively.

To expose the objective sensitivity, we evaluated two additional scores:

```text
score_0.05 = score + 0.05 * settle_time_us
score_0.10 = score + 0.10 * settle_time_us
```

| Target load | Base-score best | `score_0.05` best | `score_0.10` best |
|---:|---:|---:|---:|
| `20 A` | `80 us` | `30 us` | `30 us` |
| `10 A` | `80 us` | `50 us` | `30 us` |
| `near-0 A` | `60 us` | `60 us` | `30 us` |

This result changes the narrative from "find the best fixed slew" to "learn an objective-dependent schedule." The preferred `T_slew` depends on whether the system prioritizes undershoot, settling time, phase-spacing regularity, or final regulation. This is precisely the kind of low-dimensional, safety-constrained decision that should be assigned to an AI scheduler, while the IQCOT event generator remains the fast inner loop. PIS-IEK supplies the event-domain state, actuator separation, and constraint metrics needed to train that scheduler without turning the AI into a gate-level controller.

