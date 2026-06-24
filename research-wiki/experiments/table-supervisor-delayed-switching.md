---
type: experiment
node_id: exp:table-supervisor-delayed-switching
title: "四相 IQCOT 表驱动监督层 5us 参数提交延迟开关级验证"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium-high
date: "2026-06-20"
hardware: "Derived Simulink switching model with delayed Iph_ref timeseries"
duration: "15 cases: 3 load targets x 5 policies at tau_AI=5us"
provenance: "output/iqcot_table_supervisor_validation_results.csv; output/iqcot_table_supervisor_validation_policy_eval.csv; output/iqcot_table_supervisor_ref_slew_validation.m"
added: 2026-06-20T06:42:00Z
tags: ["table-in-loop", "delay-aware", "reference-slew", "Simulink", "IQCOT"]
---

# 四相 IQCOT 表驱动监督层 5us 参数提交延迟开关级验证

**verdict:** `partial`  ·  **confidence:** `medium-high`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Cases: `15` derived Simulink switching runs at `tau_AI=5us`.
- Fixed `40us`: mean base score `9.856`, mean `score+0.05T_settle` `10.528`.
- Fixed `80us`: mean base score `9.435`, mean `score+0.05T_settle` `11.043`.
- Base-score table `80/80/60us`: mean base score `8.960`.
- `alpha=0.05` table `30/50/60us`: mean base score `8.383`, mean `score+0.05T_settle` `9.657`.
- `alpha=0.10` table `30/30/30us`: mean `score+0.10T_settle` `10.785`.

## Reasoning

This validates the table-driven supervisory layer as a delayed low-dimensional
parameter scheduler in the derived switching model.  It supports objective-
sensitive `T_slew` scheduling under a `5us` equivalent parameter-commit delay.

## Boundary

This is not neural-network AI-in-loop and not hardware/HIL validation.  The AI
role remains a supervisory parameter schedule; IQCOT inner-loop event triggering
is unchanged.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
