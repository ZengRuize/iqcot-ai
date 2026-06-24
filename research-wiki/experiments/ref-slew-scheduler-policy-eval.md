---
type: experiment
node_id: exp:ref-slew-scheduler-policy-eval
title: "四相 IQCOT 参考斜率离线调度器策略评估"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: high
date: "2026-06-20"
hardware: "Offline post-processing of Simulink switching-level sweep"
duration: "No new Simulink run; 7 policies over 3 load-drop targets"
provenance: "output/iqcot_ref_slew_scheduler_policy_eval.csv; output/iqcot_ref_slew_scheduler_policy_eval_detail.csv; output/figures/fig25_ref_slew_scheduler_policy_eval.png; refine-logs/EXPERIMENT_RESULTS_REF_SLEW_SCHEDULER.md"
added: 2026-06-20T03:38:10Z
tags: ["scheduler", "reference-slew", "AI-supervisory-control", "IQCOT", "Simulink"]
---

# 四相 IQCOT 参考斜率离线调度器策略评估

**verdict:** `partial`  ·  **confidence:** `high`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics
fixed_30/40/60/80us, oracle_base_score, scheduler_settle005, scheduler_settle010; oracle_base_score mean base=9.299; scheduler_settle005 mean score=10.356; fixed_30/scheduler_settle010 mean score010=11.115.

## Reasoning
Policy ranking changes with objective, so T_slew should be treated as an objective-sensitive scheduling variable for AI supervisory control.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

