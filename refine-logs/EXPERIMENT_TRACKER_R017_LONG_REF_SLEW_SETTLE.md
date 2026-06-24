# Experiment Tracker Supplement: R017 Long Reference Slew + Settling Penalty

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R017 | M6 | Long reference slew and objective sensitivity | Simulink dynamic refslew copy + post-processing | `T_slew=80,100,120us`, `40A->20A/10A/near-0A`; combined with dense `20-80us` | undershoot, final error, skip, phase std, settling, base score, settling-penalty score | MUST | DONE | 9/9 long cases successful. Base score best over combined grid: `80/80/60us`; light settling penalty: `30/50/60us`; medium settling penalty: `30/30/30us`. This supports objective-dependent AI scheduling rather than a fixed universal slew. |

