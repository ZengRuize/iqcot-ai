---
type: experiment
node_id: exp:ref-slew-fine-sweep
title: "四相 IQCOT R024 局部 T_slew 细扫验证"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium-high
date: "2026-06-20"
hardware: "Derived Simulink reference-slew switching model"
duration: "45 cases; 3 target loads x 15 local fine-sweep T_slew values"
provenance: "output/iqcot_dynamic_ref_slew_fine_summary.csv; output/iqcot_ref_slew_fine_candidate_comparison.csv; output/iqcot_ref_slew_fine_sweep_report.md"
added: 2026-06-20T11:10:00Z
tags: ["fine-sweep", "reference-slew", "mode-aware", "IQCOT"]
---

# 四相 IQCOT R024 局部 T_slew 细扫验证

**verdict:** `partial`  ·  **confidence:** `medium-high`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Switching cases: `45`, all successful in the derived Simulink model.
- Primary local grid: `32/34/35/36/38 us`.
- Secondary grids: `62/64/66/68/70 us` and `84/86/88/90/92 us`.
- `20A` settling-aware local result: `35 us` is worse than old `30 us`, but `38 us` improves by about `0.076` score.
- `near0A`, `score+0.10T_settle`: `38 us` improves over old `30 us` by about `0.235` score.
- Wider fine grid discovers additional small improvements, including `20A` settling-aware around `66 us`.

## Reasoning

R024 checks whether R023's local quadratic candidates around `34-35 us` survive
switching-level validation.  The result is deliberately mixed: the fine grid
supports using continuous or finer `T_slew` scheduling, but it also shows that
the score landscape is not a smooth quadratic curve.  Skip/reentry and phase
spacing can move the better point away from the interpolated candidate.

## Boundary

This is derived Simulink evidence, not hardware or neural-network AI-in-loop.
It does not prove `34-35 us`, `38 us`, `66 us`, `86 us`, or `92 us` are global
optima.  It supports mode-aware near-optimal bands and safety projection.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
