# Narrative Report for Paper Draft

Date: 2026-06-25

## Research Narrative

The project studies AI-assisted control-oriented model refinement for
multiphase constant-on-time (COT) VRM cut-load transients.  The current research
thread focuses on request-path protection and controlled reentry after a
`40A -> 20A` load drop.  The goal is to reduce recovery overshoot without
creating a secondary undershoot or late settling penalty.

Early fixed-window request inhibit variants reduced some peaks but introduced
large recovery undershoot.  R049K showed that a shorter request-path
soft-reentry proxy reduced, but did not eliminate, this trade-off.  R049L then
attempted a one-shot controlled reentry but initially used downstream `qh1` as
the release trigger.  The repaired R049L result showed that this was a causal
mistake: `qh1` is downstream of the same gated request path and therefore does
not rise while the gate suppresses scheduler pulses.

R049M performed a structural audit and showed that the current scheduler state
is also downstream of `Allow -> Detect Rise Positive -> PhaseScheduler_4Phase`.
This motivated an upstream independent release clock.  R049N implemented that
interface and successfully fired `release_clock` and `one_shot_done`, proving
the causal deadlock was fixable.  However, a hard release at `1.685 us` improved
recovery peak while producing significant recovery undershoot penalties.

R049O, R049P, R049Q, and R049R then narrowed the binary release timing.  Early
binary releases at `1.250 us` and `1.450 us` were transparent.  A `1.600 us`
release was active only for the `0.105 us` offset.  A later `1.630 us` release
increased recovery-peak improvement but worsened undershoot.  The between-point
R049R run at `1.615 us` matched R049P exactly, revealing that the binary release
delay was not a smooth timing knob.

R049S validated the sampled-event signal model.  With `Ts_ctrl=40 ns`, the
active-row boundary is between `1.615 us` and `1.616 us`: `1.615 us` maps to a
`1.655 us` one-shot event, while `1.616-1.630 us` map to a `1.695 us` one-shot
event.  The sampled-event prediction matched simulation with effectively zero
timing error.  This result should become a central paper claim: controller
reentry timing must be modeled as a sampled event selector, not as a continuous
scalar delay.

R049T then audited where a true soft/staged restore could enter.  The existing
`Allow` route feeds a `Detect Rise Positive` subsystem and the R049N restore
logic is boolean.  Therefore, an analog ramp at `Allow` would be immediately
converted into an event, and any AI action at this boundary must specify which
edge it intends to create or pass.

R049U tested a naive event-budget restore window.  It failed in an informative
way: opening the `stage1_window` at `1.615 us` immediately raised
`allow_budgeted`, creating a downstream edge `40 ns` before the intended
`1.655 us` sampled event.  This shows that a time window at `Allow` is not a
soft restore token by itself; the edge source must be part of the signal model.

R049V repaired that model by defining
`stage_event = stage1_window AND rising_edge(existing_allow)`.  No stage event
fired inside `1.615-1.665 us`, which means the useful hard-release event is more
likely a gate-opening edge while pre-gate `Allow` is already high, not a future
pre-gate `Allow` rising edge in that window.  Full-restore delay still changed
the waveform, so it is a real action dimension, but all tested candidates
improved recovery positive peak at the cost of worse recovery-window
undershoot.  Thus R049V strengthens the signal-model contribution without
claiming controller confirmation.

## Current Strongest Quantitative Result

```text
Ts_ctrl = 40 ns
1.615 us release delay -> one_shot_done 1.655 us
1.616 us release delay -> one_shot_done 1.695 us
prediction error ≈ 0 ns
```

The waveform consequences are plateaued:

```text
1.655 us event: recovery peak +0.1244 mV, recovery undershoot -0.7873 mV
1.695 us event: recovery peak +0.1365 mV, recovery undershoot -1.1109 mV
```

The newest edge-source result is:

```text
R049U naive stage window: allow_budgeted first high 1.615 us
R049V edge-aligned stage token: no stage_event in 1.615-1.665 us
R049V full_restore_delay changes waveform but still worsens recovery-window undershoot
```

## Current Interpretation

The hard binary release architecture is not yet a confirmed controller.  Its
main value is that it exposed the correct signal model.  Further scalar timing
sweeps are low value unless they target predicted sample-event boundaries or
explicit restore-cooldown buckets.  The next controller design should move
upstream of `Allow` into request/threshold shaping, or treat full-restore delay
as a gate-opening event bucket with an undershoot-aware objective.

## Evidence Pointers

- `docs/pr_ecb_release_event_boundary_r049s.md`
- `docs/pr_ecb_soft_restore_path_audit_r049t.md`
- `docs/pr_ecb_event_budget_restore_r049u.md`
- `docs/pr_ecb_edge_aligned_event_budget_r049v.md`
- `docs/pr_ecb_release_between_point_r049r.md`
- `docs/pr_ecb_release_later_point_r049q.md`
- `docs/pr_ecb_release_midpoint_r049p.md`
- `docs/pr_ecb_release_timing_r049o.md`
- `docs/pr_ecb_independent_clock_reentry_r049n.md`
- `docs/pr_ecb_reentry_upstream_boundary_audit_r049m.md`
- `docs/pr_ecb_controlled_reentry_r049l_repair.md`
- `output/iqcot_claims_evidence_matrix.md`
- `research-wiki/log.md`
- `research-wiki/query_pack.md`
