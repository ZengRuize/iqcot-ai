# E010 A0-A4 40A-to-10A Load-Drop Comparison

Date: 2026-06-28

## Scope

This report compares the first E010 load-drop chunk using derived copies of the local ideal IQCOT baseline. The `40A -> 10A` load step is an external disturbance profile, not an AI command.

## Metrics

| Case | Description | Peak mV | Recovery 2-12us mV | Late abs mV | Undershoot penalty mV | Final error mV | Pulse inhibit events |
|---|---|---|---|---|---|---|---|
| A0 | original ideal IQCOT | 2.37866 | 2.36936 | 2.37866 | 0 | 1.83447 | NaN |
| A1 | Ton truncation only | 2.41604 | 2.14559 | 2.41604 | 0 | 1.84941 | NaN |
| A2 | Ton truncation + pulse inhibit | 2.35886 | 1.84342 | 2.33816 | 0.863951 | 1.85155 | 1 |
| A3 | guarded reentry | 2.41604 | 2.14559 | 2.41604 | 0 | 1.84941 | 0 |
| A4 | AI/table selected a_O | 2.35886 | 1.84342 | 2.33816 | 0.863951 | 1.85155 | 1 |

## Delta vs A0

| Case | Delta peak | Delta recovery | Delta late | Delta undershoot | Recovery percent |
|---|---:|---:|---:|---:|---:|
| A1 | 0.0373855 | -0.223772 | 0.0373855 | 0 | -9.44% |
| A2 | -0.0197943 | -0.52594 | -0.0404926 | 0.863951 | -22.2% |
| A3 | 0.0373855 | -0.223772 | 0.0373855 | 0 | -9.44% |
| A4 | -0.0197943 | -0.52594 | -0.0404926 | 0.863951 | -22.2% |

## Classification

`MODEL_REVISED`: A1 confirms that Ton truncation alone reduces the recovery peak but does not reduce the global peak. A2/A4 show that one projected early pulse inhibit further reduces recovery peak and slightly reduces the global peak, but introduces a bounded undershoot penalty. A3 shows the voltage reentry guard can become a binding safety projection and reject pulse inhibit, trading performance for zero undershoot.

## Evidence Paths

- A0 metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a0_40A_to_10A_metrics.csv`
- A1 metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a1_40A_to_10A_metrics.csv`
- A2 metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a2_40A_to_10A_metrics.csv`
- A3 metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a3_40A_to_10A_metrics.csv`
- A4 metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a4_40A_to_10A_metrics.csv`
- Comparison CSV: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/e010_a0_a4_40A_to_10A_comparison.csv`
