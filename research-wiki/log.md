# Research Wiki Log

_Append-only timeline._
- `2026-06-20T03:31:50Z` Wiki initialized
- `2026-06-20T03:32:02Z` upsert_idea: added idea:iqcot-pis-iek-four-phase [stage=active outcome=mixed]
- `2026-06-20T03:32:14Z` add_experiment: added exp:ref-slew-dense-long-sweep [verdict=partial confidence=high]
- `2026-06-20T03:32:25Z` add_claim: added claim:objective-sensitive-ref-slew [status=drafted] prov=output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv; output/iqcot_dynamic_ref_slew_settle_penalty_best.csv
- `2026-06-20T03:38:10Z` add_experiment: added exp:ref-slew-scheduler-policy-eval [verdict=partial confidence=high]
- `2026-06-20T05:37:20Z` add_experiment: added exp:ai-supervisor-training-interface [verdict=partial confidence=medium]
- `2026-06-20T06:42:00Z` add_experiment: added exp:table-supervisor-delayed-switching [verdict=partial confidence=medium-high]
- `2026-06-20T07:05:00Z` add_experiment: added exp:table-supervisor-delay-sensitivity [verdict=partial confidence=medium-high]
- `2026-06-20T07:15:00Z` add_experiment: added exp:ai-supervisor-regressor-baseline [verdict=partial confidence=medium]
- `2026-06-20T07:42:00Z` add_experiment: added exp:ref-slew-continuous-landscape [verdict=partial confidence=medium]
- `2026-06-20T11:10:00Z` add_experiment: added exp:ref-slew-fine-sweep [verdict=partial confidence=medium-high]
- `2026-06-20T11:45:00Z` add_experiment: added exp:mode-aware-slew-surrogate [verdict=partial confidence=medium]
- `2026-06-20T12:30:27Z` add_experiment: updated exp:deployable-risk-proxy [verdict=partial confidence=medium]
- `2026-06-20T12:50:00Z` add_experiment: added exp:proxy-table-in-loop-plan [verdict=partial confidence=medium]
- `2026-06-20T13:50:00Z` update_experiment: exp:proxy-table-in-loop-plan completed 48/48 priority switching cases; calibrated proxy did not beat dense-long table in stress replay
- `2026-06-20T14:20:00Z` add_experiment: added exp:switching-calibrated-proxy [verdict=partial confidence=medium]; dense-anchor projection fixes known proxy stress failure, guarded rule requires held-out validation
- `2026-06-20T14:45:00Z` add_experiment: added exp:heldout-guard-validation [verdict=partial confidence=medium-high]; 21/21 held-out derived Simulink cases completed, supporting 10A delay guard and revising near0A guard to a 30-38us band
- `2026-06-21T02:30:00Z` add_experiment: added exp:refined-band-policy [verdict=partial confidence=medium]; R030 synthesizes R029 local guard evidence into a refined band policy and creates a 30-row dense/proxy challenge plan
- `2026-06-21T04:10:00Z` add_experiment: added exp:tightened-bepsilon-sw [verdict=partial confidence=medium]; R031 converts R030 challenge negative samples into tightened B_epsilon^sw calibration and a 22-row minimal held-out validation plan
- `2026-06-21T07:40:00Z` update_experiment: exp:tightened-bepsilon-sw completed 22/22 minimal held-out derived Simulink cases; result supports delay-aware local band with dense fallback rather than proxy direct override
- `2026-06-21T08:20:00Z` add_experiment: added exp:delay-aware-band-r032 [verdict=partial confidence=medium]; R032 converts R031 held-out evidence into short-horizon risk interface and 31-row next validation plan
- `2026-06-21T00:35:00Z` add_experiment: completed exp:delay-band-validation-r033 [verdict=partial confidence=medium]; 31 derived-Simulink delayed-reference cases refine R032 band projection
- `2026-06-21T01:00:00Z` add_experiment: added exp:deployable-risk-predictor-r034 [verdict=planned confidence=medium]; created risk predictor prototype and 20-row transition-pocket plan
- `2026-06-21T01:20:00Z` add_experiment: completed partial exp:transition-pocket-partial-r034 [verdict=partial confidence=medium]; 10 cases revise fixed 50us pocket into moving ridge hypothesis
- `2026-06-21T01:35:00Z` add_experiment: completed exp:transition-pocket-full-r034 [verdict=partial confidence=medium]; 20 cases support folded transition band, not fixed 50us pocket
- `2026-06-21T04:35:00Z` add_experiment: added exp:folded-band-projection-r035 [verdict=partial confidence=medium]; R035 separates R034 folded transition candidate band from dense-inclusive plant commit and keeps `tau_AI=2us` on `30us` fallback.
<!-- R036_DENSE_PAIR_BOUNDARY -->

## 2026-06-21 R036 dense-paired boundary

- Added two derived-Simulink dense fallback rows for `20A/score_settle005`.
- `46us@1.25us` and `54us@1.75us` beat `30us` fallback locally.
- Updated paper, evidence matrix, derivation package, AI validation design, query pack, and wiki experiment note.
<!-- R037_SHORT_HORIZON_RHAT -->

## 2026-06-21 R037 short-horizon r_hat

- Built local risk dataset for `20A/score_settle005`.
- Added leave-one-delay risk check, representative projection replay, SVG figure, report and minimal extrapolation plan.
- Kept claims bounded to derived-Simulink/post-processing evidence.
<!-- R038_MINIMAL_EXTRAPOLATION_DRYRUN -->

## 2026-06-21 R038 minimal extrapolation dry run

- Added `r037_minimal_extrapolation` support to the common R027 delayed-reference runner.
- Added wrapper `output/iqcot_r037_minimal_extrapolation_validation.m`.
- Dry-run loaded 9 rows and generated `output/iqcot_r027_proxy_table_in_loop_matlab_plan_r037_minimal_extrapolation.csv`.
- No new Simulink switching cases were executed; this is only executable-plan validation.
<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

## 2026-06-21 R038 minimal extrapolation validation

- Ran all 9 derived-Simulink delayed-reference cases in three chunks.
- Confirmed `46/50/54us` anchors at `tau_AI=1.25/1.5/1.75us`.
- Revised `tau_AI=2us` from hard `30us` fallback to a local `30/44/48us` near-tie foldback band.
- Kept boundary claims: derived model only, not hardware validation or global optimum.
<!-- R039_PR_ECB_LARGE_SIGNAL -->

## 2026-06-21 R039 PR-ECB large-signal boundary probe

- Added output/iqcot_r039_pr_ecb_large_signal_probe.m for derived-model first-peak wave export and PR-ECB post-processing.
- Ran 5/5 derived-Simulink delayed-reference cases for 40A->20A score_settle005 anchors and tau_AI=2us near-tie probes.
- Generated combined results, summary, report, paper section, and five waveform CSV files under output/data.
- Key result: energy bound 4.350 mV, charge+ESR bound 3.903 mV, actual first peak 2.235 mV, r_E=0.435 for a 10 mV allowance.
- Interpretation boundary: PR-ECB is a first-peak risk feature, not hardware validation and not a replacement for PIS-IEK/r_hat/B_epsilon post-peak recovery logic.
<!-- R041_PR_ECB_HSREM_CORRECTION -->

## 2026-06-22 R041 PR-ECB remaining high-side on-time correction

- Added `output/iqcot_r041_pr_ecb_hsrem_correction.py` and reprocessed the completed 8-row R040 matrix without new `.slx` runs.
- Nonzero `E_HS,rem` appears only in the three offset-0 rows where phase 4 has about `102 ns` remaining high-side on-time.
- Corrected-energy fixes the near0 offset-0 energy-only under-estimation (`0.876x` to `1.169x` actual), while original `max(energy, charge+ESR)` was already conservative across all rows.
- Kept boundary claims: `E_HS,rem` is a phase-state/segmented-calibration feature, not a global correction law or hardware/HIL validation.
<!-- R042_PR_ECB_PHASE_DENSE_PARTIAL -->

## 2026-06-22 R042 PR-ECB phase-dense partial validation

- Added R042 phase-dense MATLAB runner and Python postprocess.
- Generated a 20-row plan over `near0/5A/10A/20A` and offsets `0.05/0.09/0.105/0.125/0.20us`.
- Ran 8/20 derived-Simulink rows: near0 rows `1-4` and 5A rows `6-9`.
- Localized phase-4 high-side turn-off between `0.09us` and `0.105us`; remaining on-time drops from `52ns` at `0.05us` to `12ns` at `0.09us` and `0ns` at `0.105us`.
- Current conclusion: charge+ESR remains dominant for near0/5A, while `E_HS,rem` is a useful segmentation feature, not a global correction law.

## 2026-06-22 R042 PR-ECB phase-dense full completion

- Completed all 20/20 planned derived-Simulink rows, adding 10A, 20A, and `0.20us` reference cases.
- Confirmed phase-4 remaining-on-time boundary across all target loads: `52ns` at `0.05us`, `12ns` at `0.09us`, and `0ns` from `0.105us` onward.
- Final load segmentation: charge+ESR dominates near0/5A; corrected-energy/raw energy dominates most 10A/20A rows.
- Next step is R043 segmented PR-ECB calibration surface and conservative ratio bands, still derived-Simulink/offline only.
<!-- R043_PR_ECB_SEGMENTED_CALIBRATION -->

## 2026-06-22 R043 segmented PR-ECB calibration surface

- Reprocessed the completed R040/R041/R042 evidence offline; no new Simulink run and no original `.slx` edit.
- Generated `output/iqcot_r043_pr_ecb_segmented_rows.csv`, `output/iqcot_r043_pr_ecb_segmented_rules.csv`, `output/iqcot_r043_pr_ecb_segmented_report.md`, and `output/iqcot_r043_pr_ecb_segmented_paper_section.md`.
- Fitted six segment rules over load-drop magnitude, active high-side remaining-on-time, and recommended bound class.
- Key rule: near0/5A use charge+ESR; 10A uses corrected energy only for active-HS rows and raw energy after turn-off; 20A uses energy/corrected-energy with higher conservatism.
- Kept claim boundary: `E_HS,rem` is a segmentation feature, not a global additive law; evidence is derived-Simulink/offline only, not hardware/HIL validation.
<!-- R044_V8_PR_ECB_INTEGRATED_PAPER -->

## 2026-06-22 R044 v8 PR-ECB integrated paper draft

- Updated automation `iqcot` from R043 post-processing to manuscript drafting and audit continuation.
- Generated `output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md` and copied it to `output/iqcot_multiphase_iek_paper_latest.md`.
- Added v8 Sections 20-25 covering PR-ECB first-peak boundary, R043 segmented calibration surface, claim/evidence matrix, reviewer-style risks, data/script supplement, and conclusion supplement.
- Kept boundary: this is a rigorous manuscript draft, not a submission-complete PDF; claim/citation/format audits remain required before submission-ready status.
<!-- R045_V8_FIGURE_TABLE_AUDIT_PLAN -->

## 2026-06-22 R045 v8 figure/table/audit plan

- Added `output/iqcot_v8_pr_ecb_figure_table_audit_plan.md`.
- Planned required v8 figures: two-layer supervisory architecture, R042 active-HS boundary, R043 conservative ratio bands, R043 dominant-bound family, and existing PIS-IEK validation panel.
- Listed blocking submission audits: numeric claim audit, citation audit, structure audit, figure audit, and formatting/compile audit.
- No new Simulink run and no R042/R043 post-processing repeat.
<!-- R046_DIRECTION_REVISION_AFTER_USER_FEEDBACK -->

## 2026-06-24 R046 direction revision after user feedback

- Read user reference file `C:/Users/zengruize/Downloads/iqcot_research_direction_guidance_after_repo_review.md`.
- Revised the active research direction away from AI/`T_slew` as the main claim.
- New main line: PR-ECB cut-load voltage stabilization, PIS-IEK steady-state current sharing, and variable-phase add/shed hybrid event management.
- Added `docs/research_direction_after_user_feedback_20260624.md` and `docs/auto_research_plan_after_feedback_20260624.md`.
- Updated the automation plan so the next work specifies the derived control state machine and model-wiring table before any new Simulink runs.

<!-- R047_AI_READY_MODEL_INNOVATION -->

## 2026-06-24 R047 AI-ready large/small-signal model innovation

- Added `docs/ai_control_oriented_model_innovation_20260624.md`.
- Added `docs/control_state_machine_after_feedback.md`.
- Added `refine-logs/LOCAL_AUDIT_R047_AI_READY_MODEL_INNOVATION_20260624.md`.
- Reframed the next innovation as GAE-IQCOT: PR-ECB peak-risk guard + PIS-IEK
  balance/reentry model + active-phase hybrid event map + AI action projection.
- Kept the claim boundary: AI outputs low-dimensional supervisory tokens only;
  the original IQCOT inner loop remains responsible for fast pulse generation.

<!-- R047B_ADAPTIVE_VALIDATION_AUTOMATION -->

## 2026-06-24 R047B adaptive validation automation

- Added `docs/adaptive_validation_automation_20260624.md`.
- Added `refine-logs/LOCAL_AUDIT_R047B_ADAPTIVE_VALIDATION_AUTOMATION_20260624.md`.
- Updated automation so every validation chunk must classify its outcome as
  `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or
  `CLAIM_DOWNGRADED`.
- Added the rule that model innovation documents and claim boundaries must be
  updated before expanding the next simulation grid whenever validation
  contradicts the current model.

<!-- R048_MODEL_WIRING_AUDIT -->

## 2026-06-24 R048 model wiring audit

- Performed a read-only `.slx` preflight for
  `output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`.
- Added `docs/model_wiring_audit_after_r047.md` and
  `refine-logs/LOCAL_AUDIT_R048_MODEL_WIRING_20260624.md`.
- Filled the actual wiring table: `IEK_PerPhase_Request -> Goto14(tag=REQ)`,
  `PhaseScheduler_4Phase` phase index, `IQCOT_Ton_Adapter` Ton outputs,
  `IL_Measurement1..4`, `Voltage Measurement`, and `GateDriver_1Phase1..4`.
- Confirmed parameter bindings are variable references for MOSFET `Ron`,
  `L/DCR`, `Cout/ESR`, `Ton`, `Tblank`, `Toff_min`, and `Tdead`; no hard-coded
  `0.1 ohm` MOSFET issue was found.
- Decision: `MODEL_CONFIRMED`.  No simulation matrix was run, no original
  `.slx` was modified, and no `.slx` XML was edited.

<!-- R049A_PR_ECB_SCAFFOLD -->

## 2026-06-24 R049A PR-ECB derived-control scaffold

- Added `output/iqcot_r049_build_pr_ecb_control_model.m`.
- Built derived model
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx` from the
  R048-audited `four_phase_iek_dynamic_load_refslew.slx`.
- Persisted logging taps for `vout`, `req_global`, `phase_idx`, `il1..4`,
  `qh1..4`, `ql1..4`, `ton_iqcot1..4`, `ton_done1..4`, `nqmin1..4`, and
  `current_limit1..4`.
- Added logged no-op placeholders for `protect_state`, `r_p`,
  `ton_truncate1..4`, `pulse_inhibit1..4`, `hold_int1..4`, and `reset_int1..4`.
- Non-simulation update-diagram preflight passed after explicit variable
  injection: `UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control`.
- Decision: `MODEL_CONFIRMED`.  This is a scaffold/observability result only,
  not PR-ECB protection-performance validation.

<!-- R049B_PR_ECB_MINIMAL_OVSKIP -->

## 2026-06-24 R049B PR-ECB minimal OV-skip chunk

- Added `output/iqcot_r049b_build_ovskip_model.m` and
  `output/iqcot_r049b_pr_ecb_minimal_chunk.m`.
- Built the new derived copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx`
  through MATLAB APIs.
- Implemented only simple over-voltage request skip:
  `Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip)`.
- Ran the minimal chunk only: `40A -> 1A near0` at offsets `0.05us` and
  `0.105us`, with A0 same-model no-skip and A1 OV-skip rows.
- A1 inhibited later requests for `18.880us` / `19.816us` and blocked `19` /
  `20` REQ edges, but first peaks were unchanged from A0:
  `6.2586mV` and `5.9603mV`.
- Decision: `CLAIM_DOWNGRADED`.  Simple OV skip is now bounded as a
  post-threshold request-inhibit / skip-hold mechanism, not a validated
  first-peak suppression action.

<!-- R049C_PR_ECB_MINIMAL_TONTRUNC -->

## 2026-06-24 R049C PR-ECB minimal Ton-truncation chunk

- Added `output/iqcot_r049c_build_tontrunc_model.m` and
  `output/iqcot_r049c_pr_ecb_tontrunc_chunk.m`.
- Built the new derived copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049c_tontrunc.slx`
  through MATLAB APIs.
- Implemented only command-path Ton truncation in the first cut-load window:
  `Ton_iqcot_i -> Tton_trunc_min` when over-voltage is detected.
- Ran the minimal chunk only: `40A -> 1A near0` at offsets `0.05us` and
  `0.105us`, with A0 same-model no-trunc and A2 Ton-trunc rows.
- At `0.05us`, A2 reduced first peak from `6.2586mV` to `5.4926mV` and
  shortened phase-4 remaining Ton from about `52ns` to about `2ns`.
- At `0.105us`, remaining Ton was `0ns` and peak stayed `5.9603mV`.
- Decision: `MODEL_CONFIRMED`.  Ton truncation is the first confirmed
  active-HS first-peak action in the derived model; still no hardware/HIL or
  full-matrix claim.

<!-- R049D_PR_ECB_TONTRUNC_HOLDOUT -->

## 2026-06-24 R049D PR-ECB Ton-truncation hold-out chunk

- Added `output/iqcot_r049d_build_tontrunc_holdout_model.m` and
  `output/iqcot_r049d_pr_ecb_tontrunc_holdout_chunk.m`.
- Built the new hold-out copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx`
  from the completed R049C Ton-truncation model through MATLAB APIs.
- Ran only `40A -> 10A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-trunc and A2 Ton-trunc rows.
- At `0.05us`, A2 reduced first peak from `3.9908mV` to `3.3873mV`, shortened
  phase-4 remaining Ton from about `52ns` to about `2ns`, and improved
  secondary undershoot by `2.0279mV`.
- At `0.105us`, remaining Ton was `0ns` and peak stayed `3.7607mV`.
- Decision: `MODEL_CONFIRMED`.  This is hold-out confirmation of the R049C
  active-HS mechanism, not full-matrix, hardware/HIL, or global PR-ECB
  calibration evidence.

<!-- R049E_PR_ECB_TONTRUNC_MILD_HOLDOUT -->

## 2026-06-24 R049E PR-ECB Ton-truncation mild hold-out chunk

- Added `output/iqcot_r049e_build_tontrunc_holdout_model.m` and
  `output/iqcot_r049e_pr_ecb_tontrunc_holdout_chunk.m`.
- Built the new mild hold-out copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx`
  from the completed R049D model through MATLAB APIs.
- Ran only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-trunc and A2 Ton-trunc rows.
- At `0.05us`, A0 and A2 first peaks were identical: `2.1103mV`; phase-4
  remaining Ton stayed about `52ns`.
- The A2 truncation flag did trigger for about `0.518us`, but waveform audit
  showed first assertion around `0.228us` after the load step with `qh4=0`, too
  late to remove the active high-side pulse.
- At `0.105us`, A0/A2 first peaks were identical: `2.0936mV`.
- Decision: `CLAIM_DOWNGRADED`.  Ton truncation remains supported for larger
  near0/10A chunks, but the current over-voltage trigger is not a general
  active-HS first-peak action for mild `40A -> 20A`.

<!-- R049F_PR_ECB_EARLY_TONTRUNC -->

## 2026-06-24 R049F PR-ECB early Ton-truncation trigger-timing diagnostic

- Added `output/iqcot_r049f_build_early_tontrunc_model.m` and
  `output/iqcot_r049f_pr_ecb_early_tontrunc_chunk.m`.
- Built the new trigger-timing copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx`
  from the completed R049E model through MATLAB APIs.
- Reconfigured `R049C_TonTrunc_Global` from a three-input
  after/before/over-voltage AND to a two-input load-step-synchronous time-window
  AND.
- Ran only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-trunc and A2 early Ton-trunc rows.
- At `0.05us`, A2 reduced phase-4 remaining Ton from about `52ns` to `0ns`,
  but produced a severe undervoltage response: `-184.1030mV` peak metric and
  `-239.1723mV` final error.
- At `0.105us`, global early truncation also produced severe undervoltage:
  `-189.3089mV` peak metric and `-241.9473mV` final error.
- Decision: `MODEL_REVISED`.  Early timing can affect active Ton, but global
  all-phase early Ton-min truncation is over-aggressive; the next action should
  be phase-selective / active-HS-only.

<!-- R049G_PR_ECB_PHASE_SELECTIVE_TONTRUNC -->

## 2026-06-24 R049G PR-ECB repaired phase-selective Ton-truncation diagnostic

- Added `output/iqcot_r049g_build_phase_selective_tontrunc_model.m` and
  `output/iqcot_r049g_pr_ecb_phase_selective_tontrunc_chunk.m`.
- Built the new phase-selective copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx`
  from the completed R049F model through MATLAB APIs.
- Repaired the inherited early-window lower-bound issue by connecting
  `R049G_LoadStep_Time = t_load_step` to `R049C_After_LoadStep/2`; this
  reclassifies the severe R049F undervoltage as an implementation-timing
  artifact of the over-voltage-free early window starting at simulation time
  zero.
- Ran only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-trunc and A2 repaired phase-selective early Ton-trunc rows.
- At `0.05us`, A2 reduced phase-4 remaining Ton from about `52ns` to about
  `2ns`, but worsened first peak from `2.1103mV` to `2.3879mV`.
- At `0.105us`, A2 matched A0 at `2.0936mV`, consistent with no remaining
  active high-side Ton.
- Decision: `MODEL_REVISED`.  Phase-state guarding is necessary but
  insufficient; hard active-HS Ton-min truncation is not yet a confirmed safe
  PR-ECB action for mild `40A -> 20A` cuts.  Next step: R049H offline
  waveform-metric audit splitting early local, recovery, and late windows.

<!-- R049H_PR_ECB_WAVEFORM_METRIC -->

## 2026-06-24 R049H PR-ECB offline waveform metric audit

- Added `output/iqcot_r049h_waveform_metric_audit.py`.
- Reused existing R049C/R049D/R049E/R049F/R049G wave CSV exports; no new
  Simulink switching simulation and no `.slx` modification.
- Generated `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`,
  `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`, and
  `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`.
- Split metrics into `0-2us` early local peak, `2-12us` recovery peak, and
  `12-80us` late settling/undershoot.
- Active-HS summary: R049C near0 improves early/recovery peaks by
  `0.7660/1.0047mV`; R049D 10A improves early peak by `0.6036mV` but not
  recovery/late positive peaks; R049E 20A OV-triggered action has no
  window-level effect; R049G repaired phase-selective hard Ton-min worsens
  early/recovery peaks by `0.2902/0.0476mV`.
- Decision: `MODEL_REVISED`.  Next step: R049I one minimal repaired-model
  gentle phase-selective Ton-trim chunk using R049H three-window metrics; no
  full A matrix.

<!-- R049I_PR_ECB_GENTLE_TONTRIM -->

## 2026-06-24 R049I PR-ECB gentle phase-selective Ton-trim chunk

- Added `output/iqcot_r049i_build_gentle_tontrim_model.m`,
  `output/iqcot_r049i_pr_ecb_gentle_tontrim_chunk.m`, and
  `output/iqcot_r049i_waveform_metric_audit.py`.
- Built the new gentle Ton-trim copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx`
  from the completed R049G repaired model through MATLAB APIs.
- Inspected the R049G baseline Ton trace before choosing the floor:
  `Ton_cmd4=196.5ns`, remaining Ton4 about `52ns`, elapsed active on-time about
  `144.5ns` at the `0.05us` active-HS offset.
- Selected `Tton_trunc_min=120ns`, the gentlest end of the suggested
  `80-120ns` first-candidate band, while documenting that this whole-pulse Ton
  floor is already expired at the active-HS instant.
- Ran only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-trim and A2 gentle phase-selective Ton trim.
- At `0.05us`, A2 reduced remaining Ton4 from about `52ns` to about `2ns` but
  worsened early/recovery/late positive peaks by `0.2902/0.0476/0.0866mV`.
- At `0.105us`, A2 matched A0 in all three windows.
- Decision: `MODEL_REVISED`.  Stop Ton-min/Ton-floor variants; next action
  should be deferred post-active pulse inhibit or controlled reentry.

<!-- R049J_PR_ECB_POST_ACTIVE_INHIBIT -->

## 2026-06-25 R049J PR-ECB deferred post-active pulse inhibit

- Added `output/iqcot_r049j_build_post_active_inhibit_model.m`,
  `output/iqcot_r049j_pr_ecb_post_active_inhibit_chunk.m`, and
  `output/iqcot_r049j_waveform_metric_audit.py`.
- Built the new post-active inhibit copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx`
  from the completed R049I model through MATLAB APIs.
- Inserted a request-path gate:
  `allow_to_scheduler = existing_allow AND NOT(post_active_inhibit)`.
- Selected `post_active_inhibit = 0.070-2.000us` from baseline timing:
  qh4 naturally falls at about `0.052us`, and the next qh1 rise is about
  `1.690us`.
- Ran only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-inhibit and A2 deferred post-active request inhibit.
- At `0.05us`, remaining Ton4 stayed `52ns -> 52ns` and Ton-trunc duration was
  `0us`, so the current active pulse was not truncated.
- A2 blocked one future request and reduced positive recovery peaks, but caused
  recovery undershoot penalties of `-2.9901mV` and `-4.1571mV`.
- Decision: `MODEL_REVISED`.  Fixed post-active inhibit is too hard; next step
  should be controlled reentry / soft request restoration.

<!-- R049K_PR_ECB_SOFT_REENTRY -->

## 2026-06-25 R049K PR-ECB short soft-reentry proxy

- Added `output/iqcot_r049k_build_soft_reentry_model.m`,
  `output/iqcot_r049k_pr_ecb_soft_reentry_chunk.m`, and
  `output/iqcot_r049k_waveform_metric_audit.py`.
- Built the new short soft-reentry copy
  `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`
  from the completed R049I model through MATLAB APIs.
- Tested only `40A -> 20A` at offsets `0.05us` and `0.105us`, with A0
  same-model no-inhibit and A2 shortened request-path soft reentry.
- A2 used `soft_reentry = 0.070-1.760us`, selected from first future request /
  qh1 timing around `1.678-1.690us`.
- At `0.05us`, active-HS remaining Ton4 stayed `52ns -> 52ns`, so the current
  active pulse was not truncated.
- R049K reduced R049J's recovery undershoot penalties from
  `-2.9901/-4.1571mV` to `-0.6388/-1.6588mV`, but recovery positive-peak
  benefit narrowed to `+0.1796/+0.1954mV` and late positive peaks slightly
  worsened.
- Decision: `MODEL_REVISED`.  Stop fixed scalar inhibit-window scans; next step
  should be explicit controlled reentry such as one-shot request restoration or
  phase-aware release.
