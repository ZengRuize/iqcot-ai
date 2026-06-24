---
type: experiment
node_id: exp:ref-slew-continuous-landscape
title: "四相 IQCOT 连续 T_slew 分数景观与安全区间后处理"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "Post-processing of dense+long derived Simulink reference-slew sweep"
duration: "9 target/objective combinations; 909 interpolated grid rows"
provenance: "output/iqcot_ref_slew_continuous_landscape_summary.csv; output/iqcot_ref_slew_continuous_landscape_report.md"
added: 2026-06-20T07:42:00Z
tags: ["continuous-action", "reference-slew", "safe-band", "IQCOT"]
---

# 四相 IQCOT 连续 T_slew 分数景观与安全区间后处理

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Input samples: dense+long sweep, `T_slew=20/30/40/50/60/80/100/120 us`.
- Target/objective combinations: `9`.
- Interpolated grid rows: `909`.
- Maximum local quadratic estimated gain: `0.239`.
- Decision split:
  - `4` combinations: discrete grid sufficient.
  - `2` combinations: fine sweep candidate.
  - `3` combinations: requires new switching validation.

## Reasoning

The analysis tests whether continuous `T_slew` control has enough estimated
benefit to justify moving beyond the discrete table.  The answer is mixed and
bounded.  Continuous action may be useful for smoothing and safe projection
inside near-optimal bands, but the estimated gain is small and several score
landscapes are nonmonotone/noisy.

## Boundary

This is interpolation and local quadratic fitting, not new Simulink evidence.
The local candidates around `34-35 us` are next-sweep suggestions, not verified
optimal points.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
