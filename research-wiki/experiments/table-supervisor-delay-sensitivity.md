---
type: experiment
node_id: exp:table-supervisor-delay-sensitivity
title: "四相 IQCOT 表驱动监督层 0.5/1/2/5us 延迟敏感性验证"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium-high
date: "2026-06-20"
hardware: "Derived Simulink switching model with delayed Iph_ref timeseries"
duration: "60 positive-delay cases plus zero-delay reference ordering"
provenance: "output/iqcot_table_supervisor_delay_sensitivity_by_tau.csv; output/iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv; output/iqcot_table_supervisor_delay_sensitivity_report.md"
added: 2026-06-20T07:05:00Z
tags: ["table-in-loop", "delay-sensitivity", "reference-slew", "Simulink", "IQCOT"]
---

# 四相 IQCOT 表驱动监督层 0.5/1/2/5us 延迟敏感性验证

**verdict:** `partial`  ·  **confidence:** `medium-high`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Positive-delay derived Simulink cases: `60`.
- Delay contexts: `0.5/1/2/5 us`.
- Best base policy:
  - `0.5/1 us`: base-score table.
  - `2/5 us`: `alpha=0.05` table.
- Best `score+0.10T_settle`:
  - `0.5/1/5 us`: `alpha=0.10` table.
  - `2 us`: `alpha=0.05` table.

## Reasoning

The result supports a stronger and more nuanced claim than R020: table-driven
supervisory scheduling is not just objective-sensitive; it is jointly sensitive
to objective weights and parameter-commit delay.  The best policy does not vary
monotonically with delay, so a learned supervisor should condition on both
`alpha_settle` and `tau_AI/delay_events`.

## Boundary

This remains table-in-loop delayed-reference validation in a derived Simulink
model, not neural-network AI-in-loop and not hardware/HIL.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
