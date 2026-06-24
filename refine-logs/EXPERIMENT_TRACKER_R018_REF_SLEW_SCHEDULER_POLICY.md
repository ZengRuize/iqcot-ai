# Experiment Tracker Supplement: R018 Reference-Slew Scheduler Policy

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R018 | M6b | Offline scheduler policy evaluation for reference slew | Post-processing of dense+long four-phase IQCOT Simulink sweep | Policies: fixed `30/40/60/80 us`, base-score oracle, `score+0.05T_settle` scheduler, `score+0.10T_settle` scheduler; targets: `40A->20A/10A/near-0A` | mean undershoot, final error, skip count, settling time, phase-spacing std, base score, settling-aware scores | MUST | DONE | base-score oracle selects `80/80/60 us` with mean base score `9.299`; `score+0.05T_settle` scheduler selects `30/50/60 us` with mean score `10.356`; strong settling penalty selects `30/30/30 us`. This supports objective-sensitive AI supervisory scheduling, not a fixed global `T_slew`. |

