# Experiment Tracker Supplement: R016 Dense Reference-Slew Scan

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R016 | M6 | Dense reference slew scan | Simulink dynamic refslew copy | `T_slew=20,30,40,50,60,80us`, `40A->20A/10A/near-0A` | undershoot, final error, skip, phase std, score | MUST | DONE | 18/18 cases successful. Best scanned trade-off: `80us`, `80us`, `60us`; near-0A undershoot reduced from instant `35.750mV` to `10.452mV`. Integrated paper, evidence matrix, and derivation package updated. |

