---
type: experiment
node_id: exp:deployable-risk-proxy
title: "R026 deployable T_slew risk proxy projection"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "offline post-processing on completed derived Simulink CSVs"
duration: "no new Simulink run"
provenance: "E:/Desktop/codex/output/iqcot_deployable_risk_proxy_report.md"
added: 2026-06-20T12:30:27Z
tags: ["iqcot", "T_slew", "risk-proxy", "ai-supervisor"]
---

# R026 deployable T_slew risk proxy projection

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics
calibrated risk proxy mean regret 0.119; dense_long table 0.163; naked smooth continuous 0.654; parametric proxy only 0.857; posterior mode-aware upper bound 0.064

## Reasoning
R026 converts posterior skip/phase/settle metrics into a deployable offline calibrated r_hat(z,T_slew) interface. It supports proxy safety projection design but does not prove hardware safety or neural-network AI-in-loop control.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

