# Paper Plan: Event-Quantized Controlled Reentry for Multiphase COT VRM Transients

Date: 2026-06-25

## Working Title

Event-Quantized Controlled Reentry for AI-Assisted Cut-Load Transient Control in Multiphase COT VRMs

## One-Sentence Contribution

This paper develops and validates a control-oriented signal model for cut-load
reentry in a four-phase COT VRM, showing that request restoration is governed
by sampled gate-opening events and edge sources rather than a continuous timing
knob.  The resulting AI action space is structured around event bucket,
eligibility window, edge source, and restore cooldown.

## Target Venue

Working target: IEEE conference or IEEE journal short paper.

Rationale: the work is power-electronics/control oriented, model-derived, and
centers on switching-simulation evidence rather than ML benchmark culture.

## Current Claim Boundary

- Evidence is derived-Simulink switching simulation only.
- No hardware, HIL, or silicon validation is claimed.
- Current controller variants are not yet a confirmed PR-ECB controller.
- The strongest claim is a signal-model refinement: binary reentry timing is
  sampled-event quantized, plain `Allow` eligibility windows can create
  unintended gate-opening edges, and edge-aligned tokens require explicit edge
  source modeling.

## Core Claims and Evidence

| Claim | Evidence | Strength | Safe wording |
|---|---|---|---|
| Downstream gate outputs are invalid causal release triggers during request inhibition. | R049L repair and R049M structural audit showed `qh_i`, scheduler state, and `Allow/tr` are downstream of the gated request path. | Medium structural evidence | Controlled reentry release signals must be upstream-causal or independently clocked. |
| An upstream independent release clock fixes the causal deadlock but does not confirm controller performance. | R049N: release clock and one-shot fired; recovery peak improved but recovery undershoot worsened. | Medium switching evidence | Upstream release is implementable but fixed hard release is too coarse. |
| Earlier binary releases are transparent. | R049O: `1.250/1.450 us` fired but produced zero R049H window deltas. | Medium-low micro-audit | Too-early binary release removes both benefit and penalty. |
| Midpoint binary release is offset-selective. | R049P: `1.600 us` active at `0.105 us`, transparent at `0.050 us`. | Medium-low | Useful timing is phase/offset selective, not global. |
| Later binary release strengthens recovery but worsens undershoot. | R049Q: `1.630 us` increased recovery peak benefit but worsened undershoot and late peak. | Medium-low | Moving later heads back toward hard-release failure mode. |
| Binary release delay is event-quantized. | R049R: `1.615 us` matched R049P because both mapped to the same `1.655 us` one-shot event. | Medium-low | Delay selects the next eligible release event. |
| The event boundary is sampled by `Ts_ctrl=40 ns`. | R049S: `1.615 us -> 1.655 us`, `1.616-1.630 us -> 1.695 us`, prediction error ≈ `0 ns`. | Medium | A sampled-event signal model explains the plateau transition. |

| A continuous or windowed action at `Allow` can create an unintended edge. | R049T: `Allow` feeds `Detect Rise Positive`; R049U: opening `stage1_window` at `1.615 us` immediately raised `allow_budgeted`, `40 ns` earlier than the intended sampled event. | Medium | Restore actions at `Allow` must explicitly model the edge source. |
| Waiting for a future pre-gate `Allow` edge is not equivalent to hard release. | R049V: `stage_event = stage1_window AND rising_edge(existing_allow)` did not fire inside `1.615-1.665 us`. | Medium-low | The useful hard-release event can be a gate-opening edge while pre-gate `Allow` is already high. |
| `full_restore_delay` is a real action dimension but not yet a solved controller. | R049V: full-restore candidates changed waveform metrics, but all worsened the R049H recovery-window minimum while improving recovery positive peak. | Medium-low | Restore cooldown/full-restore timing is AI-controllable but needs an undershoot-aware objective. |

## Proposed Paper Structure

### Abstract

Emphasize the problem: cut-load protection in multiphase COT VRMs can reduce
overshoot but create recovery undershoot if reentry is modeled as a continuous
timing action. State the method: an iterative simulation-guided audit of
request-path reentry signals. Include the strongest quantitative result:
R049S predicts the `1.615/1.616 us` event boundary with effectively `0 ns`
timing error and explains two distinct waveform plateaus.  Add the R049U/R049V
finding that an `Allow`-side restore must distinguish gate-opening edges from
future pre-gate `Allow` edges.

### 1. Introduction

- Motivate fast cut-load transients in multiphase VRMs.
- Explain why request-path inhibit/reentry is attractive but fragile.
- State the gap: existing scalar timing sweeps obscure event causality and
  sampling effects.
- Contributions:
  1. a causal audit methodology for reentry signals;
  2. an upstream-causal release interface;
  3. sampled-event quantization model for binary release;
  4. edge-source audit showing why naive soft/staged `Allow` windows are
     misleading;
  5. derived-Simulink validation across R049N-R049V.

### 2. System and Problem Setup

- Four-phase synchronous COT buck / VRM model.
- `40A -> 20A` cut-load transient.
- Request generation, `Allow`, scheduler trigger, phase high-side pulses.
- R049H three-window metric: early local peak, recovery peak, late settling.
- Claim boundary: derived simulation only.

### 3. Reentry Signal-Model Refinement

- Show why downstream `qh_i` and triggered scheduler state are invalid causal
  release sources.
- Define upstream release clock and `one_shot_done`.
- Derive sampled-event model:

```text
release_clock(t) = 1[t >= t_load_step + Tphase_release_delay]
one_shot_done = sampled latch(release_clock AND inhibit_raw, Ts_ctrl)
allow = existing_allow AND (NOT inhibit_raw OR one_shot_done)
```

- Discuss why binary delay is a plateau selector, not a continuous action.

### 4. Experiments

Experiments should be presented as a refinement sequence:

1. R049L/M: causal invalidity of downstream release.
2. R049N: upstream release works but has undershoot penalty.
3. R049O/P/Q/R: timing bracket and plateau behavior.
4. R049S: sampled boundary validation.
5. R049T/U/V: edge-source and restore-cooldown refinement.

Primary tables:

- Table 1: release variants and decisions.
- Table 2: R049P/R/Q/S one-shot event map and recovery-window metrics.
- Table 3: claim boundary and non-claims.

Primary figures:

- Figure 1: signal path diagram from request to `Allow` to scheduler, showing
  downstream invalid triggers and upstream release clock.
- Figure 2: event-quantization timeline for R049S (`1.615 us` vs `1.616 us`).
- Figure 3: recovery peak/undershoot trade-off by one-shot event plateau.
- Figure 4: R049U/R049V edge-source refinement: naive gate-opening edge versus
  edge-aligned stage token and full-restore cooldown.

### 5. Discussion

- Why scalar timing sweeps are misleading when event quantization dominates.
- Why true soft/ramped restore must change the restore action, not merely shift
  the hard release crossing time.
- Implications for AI-assisted controller design loops: refine signal model
  before expanding the experiment matrix.
- Recommended AI action variables: sampled release bucket, eligibility window,
  edge source class, full-restore delay/cooldown, and upstream request/threshold
  shaping.

### 6. Limitations and Future Work

- No hardware/HIL evidence.
- Only one main load transition and two offsets so far.
- Future: upstream request/threshold shaping, multi-load validation,
  hardware/HIL.

### 7. Conclusion

Summarize: the main result is a sampled-event signal model that explains why
hard binary reentry timing produces plateaus and sharp undershoot transitions.

## Next Experiments Before Full Draft

1. R049W: move upstream to request generation / threshold shaping, or sweep
   `full_restore_delay` explicitly as a gate-opening event bucket with an
   undershoot-aware objective.
2. Optional validation: repeat event-boundary audit on another load or offset.
3. Then generate the first full LaTeX draft once R049W clarifies the next
   controller-side action.

## Drafting Risks

- Avoid claiming complete controller improvement.
- Avoid claiming AI autonomy replaces controller design.
- Do not cite unsupported hardware behavior.
- Keep all R049 result names traceable to evidence files.
