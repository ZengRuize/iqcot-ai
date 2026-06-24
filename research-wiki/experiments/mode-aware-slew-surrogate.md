---
type: experiment
node_id: exp:mode-aware-slew-surrogate
title: "四相 IQCOT R025 mode-aware T_slew score surrogate 与安全投影"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "Post-processing of dense+long+fine derived Simulink reference-slew results"
duration: "207 objective-level rows; 9 target/objective contexts"
provenance: "output/iqcot_mode_aware_slew_dataset.csv; output/iqcot_mode_aware_slew_policy_summary.csv; output/iqcot_mode_aware_slew_surrogate_report.md"
added: 2026-06-20T11:45:00Z
tags: ["mode-aware", "continuous-action", "safety-projection", "reference-slew"]
---

# 四相 IQCOT R025 mode-aware T_slew score surrogate 与安全投影

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Dataset: `207` objective-level rows from dense+long+fine derived Simulink results.
- Smooth model in-sample RMSE: `0.855`.
- Mode-aware model in-sample RMSE: `0.101`.
- Leave-one-target RMSE remains large: `10.192` smooth, `5.940` mode-aware.
- Policy mean regret:
  - combined grid oracle: `0.000`
  - mode-aware safety projection: `0.064`
  - near-optimal band clipping: `0.101`
  - dense_long table: `0.163`
  - naked quadratic continuous: `0.654`

## Reasoning

The experiment tests whether continuous `T_slew` should be optimized as a
smooth scalar action.  The answer is no: a naked quadratic continuous fit can
select skip-transition bad points.  Adding near-optimal bands and mode-aware
constraints reduces regret on the completed simulation grid.

## Boundary

Mode-aware metrics are post-processed switching metrics.  Real deployment must
predict or estimate them before action selection.  This is not neural-network
AI-in-loop, not hardware validation, and not proof of a global optimum.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
