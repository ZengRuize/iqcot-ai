---
type: experiment
node_id: exp:ai-supervisor-training-interface
title: "四相 IQCOT 延迟感知 AI 监督层训练接口"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "Offline label generation from Simulink sweep plus event-domain delay context"
duration: "45 labels: 3 load targets x 3 objective weights x 5 latency contexts"
provenance: "output/iqcot_ai_supervisor_training_targets.csv; output/iqcot_ai_supervisor_validation_design.md; output/iqcot_ai_delay_ref_slew_paper_section.md"
added: 2026-06-20T05:37:20Z
tags: ["AI-supervisory-control", "training-labels", "delay-aware", "reference-slew", "IQCOT"]
---

# 四相 IQCOT 延迟感知 AI 监督层训练接口

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics
Labels: alpha=0 -> 80/80/60us; alpha=0.05 -> 30/50/60us; alpha=0.10 -> 30/30/30us; delay_events=ceil(tau_AI/0.5us).

## Reasoning
Converts reference-slew sweep and FPGA delay model into a supervised table for the next AI/table-in-loop Simulink validation.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

