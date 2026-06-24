---
type: claim
node_id: claim:objective-sensitive-ref-slew
name: "参考斜率是 IQCOT 切载瞬态的目标敏感调度变量"
description: "dense+long sweep 显示不同目标函数下推荐 T_slew 不同。"
node_type: claim
status: drafted
provenance: "output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv; output/iqcot_dynamic_ref_slew_settle_penalty_best.csv"
tags: ["IQCOT", "reference-slew", "AI-scheduler", "claim-needs-audit"]
date: 2026-06-20
added: 2026-06-20T03:32:25Z
---

# 参考斜率是 IQCOT 切载瞬态的目标敏感调度变量

**status:** `drafted`

## Statement
在当前四相 IQCOT Simulink 网格内，参考斜率 T_slew 的推荐值随目标函数改变，因此更适合作为 AI 监督层的调度变量，而不是固定为单一全局最优参数。

## Honest scope
仅限当前模型、当前负载阶跃与当前目标函数网格；不声称硬件最优，不声称 PIS-IEK 单独精确预测大切载第一峰。

## Evidence chain
Switching-level sweep completed 27 cases across dense+long grids; best T_slew differs between base and settling-aware objectives.  R024 added 45 local fine-sweep cases.  These support finer/continuous T_slew scheduling but also show non-smooth mode effects: `20A` at `35 us` is not point-optimal, while `38 us` and broader-grid candidates can improve under selected objectives.  R025 adds a 207-row objective-level post-processing dataset showing that mode-aware safety projection has lower offline regret than naked smooth continuous minimization, while still remaining non-hardware, non-AI-in-loop evidence.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

