---
type: idea
node_id: idea:iqcot-pis-iek-four-phase
title: "四相数字 IQCOT 的 PIS-IEK 事件核小信号模型"
stage: active
outcome: mixed
added: 2026-06-20T03:32:02Z
based_on: []
target_gaps: []
tags: ["IQCOT", "four-phase-buck", "small-signal", "PIS-IEK", "Simulink", "AI-supervisory-control"]
---

# 四相数字 IQCOT 的 PIS-IEK 事件核小信号模型

**stage:** `active`  ·  **outcome:** `mixed`

显式建模相位调度、事件积分核与切载 skip/reentry 的四相 IQCOT 小信号框架。

## Thesis
PIS-IEK 可作为 AI 监督层参数调度的可解释中间模型，但仍需通过更密集的开关级仿真和审稿审查限定适用范围。

## Key risks
不能声称精确预测大切载第一峰；当前证据主要来自 Simulink 开关级仿真，尚无硬件验证。

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

