---
type: experiment
node_id: exp:proxy-table-in-loop-plan
title: "R027 proxy table-in-loop priority switching replay"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-20"
hardware: "derived Simulink model plus offline plan"
duration: "315 offline plan rows; 48 priority switching cases completed"
provenance: "E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md"
added: 2026-06-20T12:50:00Z
tags: ["iqcot", "T_slew", "risk-proxy", "table-in-loop", "simulink"]
---

# R027 proxy table-in-loop priority switching replay

**verdict:** `partial`  ·  **confidence:** `medium`  ·  tests `idea:iqcot-pis-iek-four-phase`

## Metrics

Full plan: 315 rows. Priority plan: 48 rows. All 48 priority switching cases completed. Combined mean switching regret: dense-long table 0.025, posterior upper bound 0.025, near-opt band 0.257, calibrated risk proxy 0.283, fixed 40us 0.971, fixed 80us 2.171. Proxy versus dense-long: 0 better / 4 tied / 4 worse contexts.

## Reasoning

R027 converts R026's deployable `r_hat(z,T_slew)` proxy into a derived Simulink table-in-loop validation matrix and MATLAB runner. The completed priority replay verifies the interface but shows that the current calibrated proxy does not stably beat the dense-long table in stress-selected contexts. It supports re-calibrating the safety projection before stronger AI claims.

## Connections

_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._
