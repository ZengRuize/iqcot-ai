---
type: experiment
node_id: exp:ai-supervisor-regressor-baseline
title: "四相 IQCOT 可解释 score 回归监督层基线"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "Post-processing of derived Simulink delayed-reference switching results"
duration: "60 positive-delay cases expanded to 180 candidate-score rows"
provenance: "output/iqcot_ai_supervisor_regressor_dataset.csv; output/iqcot_ai_supervisor_regressor_summary.csv; output/iqcot_ai_supervisor_regressor_report.md"
added: 2026-06-20T07:15:00Z
tags: ["supervisor", "regressor", "delay-awareness", "reference-slew", "IQCOT"]
---

# 四相 IQCOT 可解释 score 回归监督层基线

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

- Raw positive-delay derived Simulink cases: `60`.
- Candidate-score rows: `180`.
- Supervised context labels: `36`.
- Leave-one-tau best model: `trained_objective_nearest_tau_table`, mean regret `0.304`.
- Leave-one-target best model: `zero_delay_objective_table`, mean regret `0.316`.
- Fixed `40 us` mean regret: `1.131`; fixed `80 us` mean regret: `1.646`.
- Tie structure: `11/36` contexts have exact oracle ties; `23/36` contexts have first-second margin `<=0.25`.

## Reasoning

The experiment turns table-supervisor validation into a score-prediction
supervisor: predict the objective score of each candidate policy, then choose
the lowest-scored low-dimensional `T_slew` strategy.  This supports using the
PIS-IEK coordinates `[load_drop, alpha_settle, tau_AI, delay_events]` as a
training interface.

The result is deliberately mixed.  Delay-aware nearest-tau selection is much
better than fixed slopes and slightly better than the zero-delay objective table
under leave-one-tau-out.  Under leave-one-target-out, however, the zero-delay
objective table remains the strongest baseline.  Therefore the evidence should
be used to claim "interpretable supervisor approximates delayed-reference
policy ranking", not "AI outperforms lookup tables".

## Boundary

This is post-processing of switching results, not a neural-network AI-in-loop
simulation and not hardware/HIL.  Candidate actions are still discrete
strategies, not continuous `T_slew` regression.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
