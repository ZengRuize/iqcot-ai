---
type: experiment
node_id: exp:folded-band-projection-r035
title: "R035 folded-band deployable projection"
idea_id: "idea:iqcot-pis-iek-four-phase"
verdict: partial
confidence: medium
date: "2026-06-21"
hardware: "derived-Simulink post-processing only"
duration: ""
provenance: "output/iqcot_r035_folded_band_projection_report.md; output/iqcot_r035_folded_band_policy_surface.csv"
added: 2026-06-21T04:35:00Z
tags: ["iqcot", "pis-iek", "ref-slew", "folded-band", "safety-projection"]
---

# R035 folded-band deployable projection

**verdict:** `partial`  --  **confidence:** `medium`  --  tests `idea:iqcot-pis-iek-four-phase`

## Metrics
R035 separates the R034 transition-candidate sequence 38/46/50/54/46us from dense-inclusive plant commit; tau_AI=2us falls back to 30us despite the 46us transition probe; 66us remains blocked.

## Reasoning
The folded band is useful as q_phi candidate generation, but plant commit still requires r_hat risk checks, B_epsilon^sw projection, and dense-paired switching evidence.

## Connections
_Edges are recorded in `graph/edges.jsonl`; summarize here for human readers._

- `idea:iqcot-pis-iek-four-phase --tested_by--> exp:folded-band-projection-r035`
- `exp:folded-band-projection-r035 --refines--> exp:transition-pocket-full-r034`

