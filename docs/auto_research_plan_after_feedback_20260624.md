# R046 Automated Research Plan After Direction Revision

Date: 2026-06-24

## Purpose

This plan replaces the previous automation focus on v8 manuscript polishing and
AI/`T_slew` scheduling. Future automated work should support the revised
converter-control direction:

```text
PR-ECB cut-load voltage stabilization
+ PIS-IEK steady-state current sharing
+ variable-phase add/shed hybrid event management
```

## Automation Rules

1. Do not repeat R042/R043 post-processing unless a new audit identifies a
   concrete error.
2. Do not run new switching simulations until a derived-control model plan has
   been written and checked.
3. Do not treat `T_slew` as a main control variable. It is only a possible
   post-peak recovery parameter.
4. Do not make AI the main claim. AI is future supervisory scheduling only.
5. Preserve original `.slx` files. If a model change is needed, build a derived
   copy through MATLAB APIs.
6. Treat validation as an adaptive loop, not a fixed batch. After each
   validation chunk, classify the result as `MODEL_CONFIRMED`,
   `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`.
7. If validation contradicts the current GAE-IQCOT innovation, update the model
   innovation document and evidence matrix before running the next chunk.
8. Prefer the smallest useful validation chunk first; expand to full grids only
   after model behavior and logging are understood.

## Next Heartbeat Priority Order

### Priority 1: Architecture and State-Machine Specification

Create or update:

- `docs/control_state_machine_after_feedback.md`
- an architecture figure showing:
  - original IQCOT inner loop
  - PR-ECB cut-load protection layer
  - PIS-IEK current-sharing/reentry layer
  - phase add/shed layer

No simulation is required.

Status after R047:

- `docs/ai_control_oriented_model_innovation_20260624.md` defines the
  AI-ready large/small-signal model interface.
- `docs/control_state_machine_after_feedback.md` provides the first control
  state-machine and derived-signal wiring draft.
- `docs/adaptive_validation_automation_20260624.md` defines the validation
  feedback loop: validate, diagnose, revise the model innovation, then continue.
- The next heartbeat should inspect the derived `.slx` model blocks/signals and
  fill the "Existing signal/block" column with actual model paths before any
  model-copy construction.

### Priority 1.5: Adaptive Validation Feedback Gate

Before every validation chunk, write a hypothesis block:

| Field | Required content |
|---|---|
| Model version | current GAE-IQCOT/PR-ECB/PIS-IEK assumption |
| Hypothesis | expected control effect |
| Expected failure mode | what would force model revision |
| Metrics | exact CSV/report metrics |
| Claim boundary | what can and cannot be claimed |

After every validation chunk, update the model using:

| Result | Automation action |
|---|---|
| `MODEL_CONFIRMED` | keep current model and expand validation cautiously |
| `MODEL_REVISED` | update `docs/ai_control_oriented_model_innovation_20260624.md` and relevant state-machine/control rules |
| `IMPLEMENTATION_ISSUE` | stop simulation expansion and inspect `.slx` wiring/parameters |
| `CLAIM_DOWNGRADED` | update `output/iqcot_claims_evidence_matrix.md` and safe wording |

### Priority 2: Derived Simulink Model Plan

Before editing or building any model copy, produce a table:

| Item | Existing signal/block | Proposed derived signal/block | Reason |
|---|---|---|---|
| Ton truncation | TBD from model inspection | `ton_truncate_i` | cut-load over-voltage protection |
| Pulse inhibit | TBD | `inhibit_hs_i` | prevent new high-side energy injection |
| Integrator hold/reset | TBD | `hold_int_i`, `reset_int_i` | safe reentry |
| Active phase set | TBD | `active_phase_set` | phase add/shed |
| Balance trim | TBD | `Ton_trim_i`, `Lambda_trim_i` | steady-state current sharing |

Only after this table exists should automation proceed to MATLAB model-copy
construction.

### Priority 3: PR-ECB Cut-Load Protection Ablation

Run only after model wiring is checked:

| Case | Controller |
|---|---|
| A0 | original IQCOT |
| A1 | simple over-voltage skip |
| A2 | PR-ECB + Ton truncation |
| A3 | PR-ECB + Ton truncation + pulse inhibit + controlled reentry |

Output directory:

```text
output/cutload_pr_ecb_control/
```

Status after R049A:

- `docs/model_wiring_audit_after_r047.md` completed the R048 wiring preflight
  with decision `MODEL_CONFIRMED`.
- `output/iqcot_r049_build_pr_ecb_control_model.m` now builds
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx` as a
  derived-control scaffold.
- The R049A scaffold persists logging for `vout`, `req_global`, `phase_idx`,
  `il1..4`, `qh1..4`, `ql1..4`, `ton_iqcot1..4`, `ton_done1..4`,
  `nqmin1..4`, `current_limit1..4`, and no-op protection tokens
  `protect_state`, `r_p`, `ton_truncate1..4`, `pulse_inhibit1..4`,
  `hold_int1..4`, `reset_int1..4`.
- A non-simulation update-diagram check passed after explicit variable
  injection.  No protection-performance claim is made yet.
- The next chunk should implement only one minimal derived-copy protection
  action first, then test one load-drop magnitude at two phase offsets before
  expanding any A matrix.

Status after R049B:

- `output/iqcot_r049b_build_ovskip_model.m` now builds
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx`
  as a second-level derived copy from the R049A scaffold.
- R049B implemented only simple over-voltage request skip:
  `Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip)`.
- The minimal chunk ran only `40A -> 1A near0` at two offsets
  (`0.05 us`, `0.105 us`) with A0 same-model no-skip and A1 OV-skip rows.
- A1 inhibited new requests for about `18.880 us` / `19.816 us` and blocked
  `19` / `20` raw REQ edges, but first-peak overshoot was unchanged:
  `6.2586 mV` and `5.9603 mV` for A0 and A1 at the two offsets.
- Decision: `CLAIM_DOWNGRADED`.  Simple OV skip should be described as a
  post-threshold request-inhibit / skip-hold mechanism, not as a validated
  first-peak suppression mechanism.
- Do not expand the full A matrix from this result.  The next chunk should use
  a new derived-copy single action: minimal Ton truncation or active-HS
  remaining-on-time truncation, again on one load-drop magnitude crossed with
  two phase offsets.

Status after R049C:

- `output/iqcot_r049c_build_tontrunc_model.m` now builds
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049c_tontrunc.slx`
  from the R049A scaffold as a new derived copy.
- R049C implemented only command-path Ton truncation during the first cut-load
  window:
  `Ton_iqcot_i -> Tton_trunc_min` when
  `t_load_step <= t <= t_load_step + Tton_trunc_window` and
  `Vout > Vo_ref + Vton_trunc_ov`.
- The minimal chunk ran only `40A -> 1A near0` at offsets `0.05 us` and
  `0.105 us`, with A0 same-model no-trunc and A2 Ton-trunc rows.
- At the active-HS boundary offset `0.05 us`, A2 reduced first peak from
  `6.2586 mV` to `5.4926 mV` and reduced phase-4 remaining high-side on-time
  from about `52 ns` to about `2 ns`.
- At the post-turnoff offset `0.105 us`, A2 left the first peak unchanged
  (`5.9603 mV`), consistent with no remaining high-side on-time to remove.
- Decision: `MODEL_CONFIRMED`.
- Do not expand to the full A matrix yet.  The next chunk should be a
  hold-out load-drop validation, preferably `40A -> 10A` crossed with
  `0.05 us` and `0.105 us`, using the same A0/A2 Ton-truncation comparison.

Status after R049D:

- `output/iqcot_r049d_build_tontrunc_holdout_model.m` now copies the completed
  R049C Ton-truncation model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx`
  for a hold-out run, without modifying R049C.
- `output/iqcot_r049d_pr_ecb_tontrunc_holdout_chunk.m` ran only `40A -> 10A`
  at offsets `0.05 us` and `0.105 us`, with A0 same-model no-trunc and A2
  Ton-trunc rows.
- At the active-HS boundary offset `0.05 us`, A2 reduced first peak from
  `3.9908 mV` to `3.3873 mV`, shortened phase-4 remaining Ton from about
  `52 ns` to about `2 ns`, and improved the secondary undershoot by
  `2.0279 mV`.
- At the post-turnoff offset `0.105 us`, A2 left the first peak unchanged at
  `3.7607 mV`, consistent with no remaining high-side on-time to remove.
- Decision: `MODEL_CONFIRMED`.
- Do not jump to the full A matrix solely from R049C/R049D.  The next smallest
  useful step should be either one additional mild hold-out such as
  `40A -> 20A` at the same two offsets, or a separate single-action
  reentry/pulse-inhibit chunk for safe skip-hold recovery.

Status after R049E:

- `output/iqcot_r049e_build_tontrunc_holdout_model.m` copied the completed
  R049D Ton-truncation hold-out model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx`
  for a milder hold-out run.
- `output/iqcot_r049e_pr_ecb_tontrunc_holdout_chunk.m` ran only `40A -> 20A`
  at offsets `0.05 us` and `0.105 us`, with A0 same-model no-trunc and A2
  Ton-trunc rows.
- At the active-HS boundary offset `0.05 us`, A2 did not reduce first peak:
  A0 and A2 both measured `2.1103 mV`; phase-4 remaining Ton stayed about
  `52 ns`.
- The A2 truncation flag did trigger for about `0.518 us`, but waveform audit
  shows it first asserted around `0.228 us` after the load step when `qh4=0`.
  Thus the current over-voltage-triggered command-path action was too late to
  remove the active high-side pulse in this mild-load case.
- At the post-turnoff offset `0.105 us`, A0/A2 both measured `2.0936 mV`.
- Decision: `CLAIM_DOWNGRADED`.
- Do not expand to the full A matrix and do not continue repeating the same
  hold-out.  The next useful step is R049F: a trigger-timing diagnostic on the
  same `40A -> 20A` two-offset chunk, using a pre-threshold /
  load-step-synchronous active-HS truncation variant to separate action
  capability from trigger lateness.

Status after R049F:

- `output/iqcot_r049f_build_early_tontrunc_model.m` copied the completed R049E
  model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx`.
- The builder reconfigured the existing `R049C_TonTrunc_Global` logic from
  `after_load_step AND before_window_end AND over_voltage` to
  `after_load_step AND before_window_end`, creating a load-step-synchronous
  early window.
- `output/iqcot_r049f_pr_ecb_early_tontrunc_chunk.m` ran only `40A -> 20A` at
  offsets `0.05 us` and `0.105 us`, with A0 same-model no-trunc and A2 early
  Ton-trunc rows.
- At the active-HS boundary offset `0.05 us`, early A2 reduced phase-4
  remaining Ton from about `52 ns` to `0 ns`, confirming the R049E issue was
  trigger lateness rather than an incapable Ton command path.
- But the global all-phase early window caused severe undervoltage-like
  response: A2 peak metric was `-184.1030 mV` and final error was
  `-239.1723 mV`.
- At the post-turnoff offset `0.105 us`, A2 also produced severe undervoltage
  (`-189.3089 mV`, final error `-241.9473 mV`).
- Decision: `MODEL_REVISED`.
- Do not expand to the full A matrix.  The next useful step is R049G: reuse the
  `40A -> 20A` two-offset chunk with a phase-selective / active-HS-only early
  truncation guard, such as `early_window AND qh_i`, to test whether the R049F
  failure was caused by global all-phase truncation.

Status after R049G:

- `output/iqcot_r049g_build_phase_selective_tontrunc_model.m` copied the
  completed R049F model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx`.
- R049G repaired the inherited early-window lower-bound wiring by connecting
  `R049G_LoadStep_Time = t_load_step` to `R049C_After_LoadStep/2`.  This
  corrects the R049F/R049G pre-repair artifact where the early window fired
  from simulation time zero after the over-voltage gate was removed.
- `output/iqcot_r049g_pr_ecb_phase_selective_tontrunc_chunk.m` ran only
  `40A -> 20A` at offsets `0.05 us` and `0.105 us`, with A0 same-model
  no-trunc and A2 repaired phase-selective early Ton-trunc rows.
- At `0.05 us`, A2 reduced phase-4 remaining Ton from about `52 ns` to about
  `2 ns`, but worsened the first-peak metric from `2.1103 mV` to
  `2.3879 mV`.
- At `0.105 us`, A2 remained identical to A0 at `2.0936 mV`, consistent with
  no remaining active high-side Ton.
- Decision: `MODEL_REVISED`.
- Do not expand to a full matrix and do not keep testing hard Ton-min
  truncation blindly.  The next useful step is R049H: an offline waveform
  metric audit over existing R049C/R049D/R049E/R049F/R049G exports, splitting
  `0-2 us` early local peak, `2-12 us` recovery peak, and `12-80 us`
  settling/undershoot windows before selecting any next action.

Status after R049H:

- `output/iqcot_r049h_waveform_metric_audit.py` performed an offline-only
  waveform audit over existing R049C/R049D/R049E/R049F/R049G wave CSV exports.
- It generated
  `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`,
  `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`, and
  `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`.
- R049H split response metrics into `0-2 us` early local peak, `2-12 us`
  recovery peak, and `12-80 us` late settling/undershoot.
- Active-HS summary: R049C near0 improves early/recovery peaks by
  `0.7660/1.0047 mV`; R049D 10A improves early peak by `0.6036 mV` but does
  not improve recovery/late positive peaks; R049E 20A OV-triggered action has
  no window-level effect; R049G repaired phase-selective hard Ton-min worsens
  early/recovery peaks by `0.2902/0.0476 mV`.
- Decision: `MODEL_REVISED`.
- The next useful step is R049I: one minimal repaired-model action chunk on the
  same `40A -> 20A` two-offset setup, testing gentler phase-selective Ton trim
  rather than hard `5 ns` Ton-min.  Use R049H's three-window metrics as the
  acceptance gate; do not expand to a full matrix.

Status after R049I:

- `output/iqcot_r049i_build_gentle_tontrim_model.m` copied the completed R049G
  repaired model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx`.
- R049I first audited the R049G baseline Ton trace: `Ton_cmd4=196.5 ns`,
  remaining Ton4 at the `0.05 us` active-HS load-step offset was about
  `52.0 ns`, so the phase had already been on for about `144.5 ns`.
- A2 used the gentlest end of the suggested first-candidate band,
  `Tton_trunc_min=120 ns`, but model inspection confirmed this is a whole-pulse
  Ton command, not a remaining-on-time floor.
- Result: at `0.05 us`, A2 still shortened phase-4 remaining Ton from about
  `52 ns` to about `2 ns` and worsened the early local peak by `0.2902 mV`;
  recovery/late peaks also worsened by `0.0476/0.0866 mV`.  At `0.105 us`,
  A2 remained identical to A0.
- Decision: `MODEL_REVISED`.
- Stop Ton-min/Ton-floor variants.  The next useful step is one minimal chunk
  for deferred post-active pulse inhibit or controlled reentry, still using the
  R049H three-window acceptance gate.

Status after R049J:

- `output/iqcot_r049j_build_post_active_inhibit_model.m` copied the completed
  R049I model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx`.
- R049J selected a request-path inhibit window from baseline timing evidence:
  qh4 naturally falls about `0.052 us` after the active-HS load step, so A2
  starts inhibit at `0.070 us` and holds until `2.000 us`.
- Ton truncation was disabled in both A0 and A2.  At `0.05 us`, remaining Ton4
  stayed `52 ns -> 52 ns`, so the current active-HS pulse was not truncated.
- A2 blocked one future request and reduced positive recovery peaks, but caused
  recovery undershoot penalties: `-2.9901 mV` at `0.05 us` and `-4.1571 mV`
  at `0.105 us`.
- Decision: `MODEL_REVISED`.
- Do not promote fixed post-active inhibit.  The next useful step is controlled
  reentry with softer request restoration, or a shorter/phase-selective inhibit
  explicitly penalized for recovery undershoot.

Status after R049K:

- `output/iqcot_r049k_build_soft_reentry_model.m` copied the completed R049I
  model into
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`.
- R049K kept Ton truncation disabled and tested only a shortened request-path
  soft-reentry proxy: `soft_reentry = 0.070-1.760 us`.
- The end time was selected from R049J/R049K waveform timing: the first future
  request / qh1 boundary is around `1.678-1.690 us`, so this is an
  evidence-based short proxy rather than a parameter sweep.
- At `0.05 us`, A2 preserved active-HS remaining Ton4 at `52 ns -> 52 ns` and
  released the next qh1 pulse at about `1.772 us`.
- Compared with R049J, recovery-window undershoot penalties were reduced from
  `-2.9901/-4.1571 mV` to `-0.6388/-1.6588 mV`, but positive recovery-peak
  benefit narrowed to `+0.1796/+0.1954 mV` and late positive peaks slightly
  worsened.
- Decision: `MODEL_REVISED`.
- Do not keep scanning scalar fixed inhibit windows.  The next useful step is
  an explicit controlled-reentry proxy, such as edge-aligned one-shot request
  restoration or phase-aware release, still using R049H three-window metrics
  and recovery-undershoot penalty.

Status after R049L repair:

- The external R049L result was first rejected as `IMPLEMENTATION_ISSUE`
  because its A0 baseline used `t_load_step = offset` instead of
  `0.45 ms + offset`.
- `output/iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk.m` restored the
  R049K-compatible baseline.  A0 now matches R049K: at `0.050 us`, peak is
  `2.1103 mV`, `qh4_at_step=1`, and remaining Ton4 is `50.5 ns`; at
  `0.105 us`, peak is `2.0936 mV`, `qh4_at_step=0`, and remaining Ton4 is
  `0 ns`.
- The attempted A2 phase-boundary one-shot used downstream `qh1` rising as the
  release trigger.  It did not fire in either A2 row
  (`one_shot_edge_count=0`, `one_shot_time_us=NaN`), so A2 effectively
  reproduced the R049K fixed `0.070-1.760 us` inhibit window.
- Decision: `IMPLEMENTATION_ISSUE`.
- Next step: do not use downstream `qh1` as the release trigger.  First expose
  or identify an upstream scheduler phase-boundary signal that remains
  observable while requests are inhibited, or implement an independent
  phase-clock / scheduler-slot proxy.

Status after R049M:

- `output/iqcot_r049m_reentry_boundary_audit.m` performed a read-only
  structural audit of the R049L repair model.
- The scheduler trigger chain is downstream of the request-path gate:
  `R049L_Gate_And -> Allow -> Detect Rise Positive -> tr ->
  PhaseScheduler_4Phase`.
- `PhaseScheduler_4Phase/phase_state` is a `UnitDelay` inside a triggered
  subsystem. It advances only on `Allow` / `tr` rising edges and freezes during
  request inhibition.
- Therefore existing `phase_state`, `phase_idx`, `phase_en1..4`, `tr1..4`, and
  downstream `qh1` cannot be causal one-shot release triggers.
- Decision: `MODEL_REVISED`.
- Next useful step: build a new derived copy with an independent upstream
  phase-clock / predicted scheduler-slot release trigger, calibrated near the
  R049K observed `1.678-1.690 us` boundary, then run only the same four-row
  `40A -> 20A` A0/A2 chunk.

### Priority 4: PIS-IEK Current-Sharing Ablation

Run only after the cut-load model path is stable:

| Case | Controller |
|---|---|
| B0 | original IQCOT |
| B1 | Lambda_diff only |
| B2 | Ton_diff only |
| B3 | Ton_diff + Lambda_diff |
| B4 | PIS-IEK-guided limited control |

Output directory:

```text
output/pis_iek_balance_control/
```

### Priority 5: Phase Add/Shed Hybrid Event Validation

Implement after PR-ECB and PIS-IEK controller comparisons exist:

- `1/2/4` active phase sets
- add/shed hysteresis
- dwell timer
- shedding disabled during cut-load protection
- reentry before shedding

Output directory:

```text
output/phase_add_shed_control/
```

## Required Updates After Each Heartbeat

Each heartbeat that changes files should update:

- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `refine-logs/LOCAL_AUDIT_R0XX_*.md`
- relevant `docs/*.md`

Then commit and push to GitHub:

```text
git status
git add <changed files>
git commit -m "<concise research-step message>"
git push
```

## Stop Conditions

Pause and notify the user if:

- a proposed simulation requires modifying original `.slx` files;
- a model inspection finds hard-coded parameters that invalidate the assumed
  control path;
- GitHub push fails;
- generated results would require claiming hardware/HIL validation.
