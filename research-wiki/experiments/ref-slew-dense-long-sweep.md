---
type: experiment
node_id: exp:ref-slew-dense-long-sweep
title: "四相 IQCOT 参考斜率 dense+long 切载 sweep"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: high
date: "2026-06-20"
hardware: "Local MATLAB/Simulink switching-level simulation"
duration: "dense 18/18 + long 9/9 cases completed"
provenance: "output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv; output/iqcot_dynamic_ref_slew_settle_penalty_best.csv; refine-logs/EXPERIMENT_RESULTS_REF_SLEW_LONG_SETTLE.md"
added: 2026-06-20T03:32:14Z
tags: ["Simulink", "load-step", "reference-slew", "scheduler", "IQCOT"]
---

# 四相 IQCOT 参考斜率 dense+long 切载 sweep

**verdict:** `partial`  ·  **confidence:** `high`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics
T_slew grid: 20,30,40,50,60,80,100,120 us for target loads 20A,10A,near-0A; base best = 80/80/60 us; settling-aware 0.05 best = 30/50/60 us; settling-aware 0.10 best = 30/30/30 us.

## Reasoning
The best reference slew depends on the objective function, supporting reference slew as an objective-sensitive scheduling variable instead of a fixed global optimum.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

