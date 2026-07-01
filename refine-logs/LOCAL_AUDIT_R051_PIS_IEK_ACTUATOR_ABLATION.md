# R051 PIS-IEK Actuator Ablation Audit

Date: 2026-07-01

## 1. Objective

Consolidate the existing evidence for PIS-IEK actuator separation without running new Simulink simulations, training AI, modifying original `.slx` files, or expanding any matrix. The round audits whether the current paper-ready line can safely state that `Ton_diff` is the primary DC current-sharing actuator, `Lambda_diff` mainly shapes phase-spacing/event rhythm, and `delay_diff` is a phase-jitter / detection-timing disturbance.

## 2. Hypothesis

Hypothesis:

```text
Ton_diff is the primary DC current-sharing actuator; Lambda_diff mainly shapes phase-spacing/event rhythm; delay_diff is a phase-jitter disturbance.
```

Expected failure mode:

```text
The numeric evidence cannot be located, Lambda_diff has strong DC current-sharing evidence, Ton_diff is not separable from phase cost, or delay_diff appears as a recommended primary control actuator.
```

## 3. Files inspected

Required protocol and boundary files:

- `.codex/skills/iqcot-research/SKILL.md`
- `C:/Users/zengruize/.agents/skills/power-electronics-simulink-design/SKILL.md`
- `C:/Users/zengruize/.agents/skills/power-electronics-simulink-design/references/cot-optimization.md`
- `docs/CODEX_RESEARCH_WORKFLOW.md`
- `docs/CODEX_OUTPUT_PROTOCOL.md`
- `docs/deep_research_external_literature_review_summary.md`
- `refine-logs/LOCAL_AUDIT_R050_RESEARCH_STATE_ALIGNMENT.md`
- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`
- `research-wiki/log.md`
- `research-wiki/query_pack.md`
- `output/iqcot_claims_evidence_matrix.md`

Evidence files:

- `output/iqcot_four_phase_actuator_matrix.csv`
- `output/iqcot_four_phase_actuator_sweep.csv`
- `output/iqcot_pis_iek_sensitivity_matrix.csv`
- `output/iqcot_pis_iek_modal_projection_matrix.csv`
- `output/iqcot_digital_jitter_gain_summary.csv`
- `output/iqcot_digital_combined_jitter_budget.csv`
- `output/iqcot_pis_iek_monte_carlo_budget_report.md`
- `output/iqcot_pis_iek_derivation_package.md`
- `output/iqcot_multiphase_iek_paper_latest.md`
- `output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md`
- `output/iqcot_integrated_research_paper.md`
- `output/iqcot_iek_perphase_model_validation_report.md`
- `output/iqcot_iek_perphase_load_sweep_report.md`
- `output/iqcot_simulink_modal_cross_validation_summary.csv`
- `output/iqcot_simulink_modal_cross_validation_highres_summary.csv`
- `output/iqcot_simulink_perphase_fd_validation_report.md`
- `output/iqcot_ai_delay_event_surrogate_report.md`
- `output/iqcot_table_supervisor_delay_sensitivity_report.md`
- `experiments/E030_balance_recovery/e030_hypothesis.md`
- `experiments/E030_balance_recovery/e030_metrics.csv`
- `experiments/E030_balance_recovery/e030_c1_ton_diff_report.md`
- `experiments/E030_balance_recovery/e030_c2_lambda_diff_report.md`
- `experiments/E030_balance_recovery/e030_c3_ton_lambda_diff_report.md`
- `experiments/E030_balance_recovery/e030_c4_pis_iek_projected_report.md`
- `experiments/E030_balance_recovery/e030_research_summary.md`
- `experiments/E030_balance_recovery/e030_waveform_audit.md`
- `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md`
- `experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md`
- `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md`

Keyword search was performed for:

```text
Ton_diff, Lambda_diff, delay_diff, actuator, current-sharing, current sharing,
phase-spacing, phase spacing, event rhythm, m2, modal, 765.07, 0.0100,
0.00996, 1.943, wait gain, delay-aware, jitter, PIS-IEK, He-only, K(z),
phase_idx, reset, lifted frequency, local sensitivity, amplitude scan,
derived-Simulink.
```

## 4. Evidence found

### Lambda_diff

Source files:

- `output/iqcot_four_phase_actuator_matrix.csv`
- `output/iqcot_four_phase_actuator_sweep.csv`
- `output/iqcot_pis_iek_modal_projection_matrix.csv`
- `output/iqcot_iek_perphase_model_validation_report.md`
- `output/iqcot_iek_perphase_load_sweep_report.md`
- `experiments/E030_balance_recovery/e030_c2_lambda_diff_report.md`
- `experiments/E030_balance_recovery/e030_metrics.csv`
- `output/iqcot_multiphase_iek_paper_latest.md`
- `output/iqcot_claims_evidence_matrix.md`

Numeric evidence:

- Analytic m2 `Lambda_diff` current gain: `0.009957935 mA/(1e-13 V*s)`.
- Analytic m2 phase wait gain: `0.132243120 ns/(1e-13 V*s)`.
- Per-phase IEK derived-Simulink evidence: `Lambda_m2/Lambda_area=0.4` gives m2 current projection `0.001163 A`.
- Per-phase load sweep: 20/30/40/50 A sweep with `Lambda_m2/Lambda_area=0.4` has max m2 current projection `0.009382 A`.
- E030 C2 Lambda-only: max current imbalance `0.853665 A`, same as C0; phase-spacing std `42.7227 ns`; Lambda usage `0.75`.

Interpretation:

`Lambda_diff` is a phase-spacing/event-rhythm actuator. It has a small current channel and therefore should not be described as "no current effect," but current evidence does not support writing it as a strong DC current-sharing actuator.

Evidence strength:

Strong for safe actuator separation. Medium for active Lambda closed-loop control, because E030/R1 kept active Lambda claims disabled or side-band/logging only.

Missing evidence:

No event-native active Lambda micro-audit has validated a closed-loop Lambda control path without REQ pulse loss.

### Ton_diff

Source files:

- `output/iqcot_four_phase_actuator_matrix.csv`
- `output/iqcot_four_phase_actuator_sweep.csv`
- `output/iqcot_simulink_modal_cross_validation_summary.csv`
- `output/iqcot_simulink_modal_cross_validation_highres_summary.csv`
- `experiments/E030_balance_recovery/e030_c1_ton_diff_report.md`
- `experiments/E030_balance_recovery/e030_c3_ton_lambda_diff_report.md`
- `experiments/E030_balance_recovery/e030_c4_pis_iek_projected_report.md`
- `experiments/E030_balance_recovery/e030_research_summary.md`
- `experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md`
- `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md`

Numeric evidence:

- Analytic m2 `Ton_diff` current gain: `765.070770 mA/(0.1 ns)`.
- Analytic m2 phase wait gain: `84.643830 ns/(0.1 ns)`.
- Simulink m2 `[+4,-4,+4,-4] ns` current projection: `1.943019973 A`.
- E030 C1 Ton-only improves max imbalance from C0 `0.853665 A` to `0.313775 A`.
- E030 C1 also carries costs: ripple `15.2173 mV` and final Vout error `-58.1561 mV`.
- E030 C4 projected balancer: max imbalance `0.376221 A`, Ton usage `0.537860`, final error `-23.4942 mV`.
- R1-C4a: max imbalance `0.416996 A`, Ton usage `0.404392`, final error `-3.60374 mV`.
- R3-C4a_cal under calibration-aware guard: real max imbalance `0.020618 A` versus R3-C0 `0.036272 A`, with no-harm guard satisfied.

Interpretation:

`Ton_diff` is the primary DC current-sharing actuator, but not a free knob. It must be guarded for phase spacing, ripple, voltage error, trim usage, and current-sense confidence.

Evidence strength:

Strong for actuator role. Medium-strong for guarded controller design. Not sufficient for broad mismatch robustness or hardware claims.

Missing evidence:

No hardware/HIL validation. Broad mismatch robustness is not established. Guarded selector should be frozen before any broader controller-performance claim.

### delay_diff

Source files:

- `output/iqcot_four_phase_actuator_matrix.csv`
- `output/iqcot_four_phase_actuator_sweep.csv`
- `output/iqcot_digital_jitter_gain_summary.csv`
- `output/iqcot_digital_combined_jitter_budget.csv`
- `output/iqcot_pis_iek_monte_carlo_budget_report.md`
- `output/iqcot_pis_iek_delay_cutload_extension.md`
- `output/iqcot_ai_delay_event_surrogate_report.md`

Numeric evidence:

- Analytic m2 `delay_diff` current gain: `0.023249775 mA/(0.1 ns)`.
- Analytic m2 phase wait gain: `0.308759180 ns/(0.1 ns)`.
- Analytic m2 event wait rms gain: `0.154386352 ns/(0.1 ns)`.
- Digital jitter gain summary: `delay_phase_gain=3.087591804 ns/ns`, `delay_current_gain=0.232497752 mA/ns`.
- Monte Carlo budget example: wait jitter rms mean `0.6466 ns`, phase-spacing std mean `0.6466 ns`, current-share rms mean `0.5059 mA`.
- AI delay surrogate: `tau_AI=5 us` equals `10` IQCOT events; this supports event-indexed latency budgeting, not direct gate-level control.

Interpretation:

`delay_diff` is primarily timing jitter / detection delay. It is a calibration and digital-budget term, not the recommended primary AI action.

Evidence strength:

Strong for disturbance/budget interpretation. R052 should consolidate budget tables before final manuscript wording.

Missing evidence:

No hardware timing measurement. R052 still needs a compact budget table and final safe wording.

## 5. Actuator separation decision

- Ton_diff: `MODEL_CONFIRMED`
- Lambda_diff: `MODEL_CONFIRMED`
- delay_diff: `MODEL_CONFIRMED`

Rationale:

The available evidence is sufficient for the safe wording selected in R050:

```text
Ton_diff is the main DC current-sharing actuator; Lambda_diff mainly trims phase-spacing/event rhythm; delay_diff is a jitter disturbance.
```

The result does not confirm broad controller superiority, active Lambda control, hardware/HIL behavior, PR-ECB, active-set add/shed, or neural AI control.

## 6. Claim matrix update decision

`output/iqcot_claims_evidence_matrix.md` was not modified in R051.

Reason:

- The current claim matrix already contains an R050 overlay and C3/C4 source locator lines for `Lambda_diff`, `Ton_diff`, and `delay_diff`.
- The working tree also contained pre-existing uncommitted R049T/R049U/R049V edits in `output/iqcot_claims_evidence_matrix.md`; R051 avoids mixing unrelated hunks.
- R051 instead creates structured tables:
  - `output/tables/r051_actuator_evidence_map.csv`
  - `output/tables/r051_actuator_claim_boundary_table.csv`

## 7. Limitations

- No new simulation.
- No hardware/HIL validation.
- Based on existing repository evidence.
- Not generalized to all COT/IQCOT converters.
- No active-set validation.
- No PR-ECB validation.
- No AI training.
- Active Lambda closed-loop control remains unvalidated.
- Combined projected controller claims remain guarded/conditional.

## 8. Recommended next task

Recommended next task:

```text
R052_DIGITAL_JITTER_BUDGET_CONSOLIDATION
```

Why this is the smallest useful next step:

R051 confirms the safe actuator-separation wording. The next paper-ready pillar is the digital implementation budget that maps area quantization, detection clocks, Ton resolution, comparator delay, and supervisor delay to event jitter, phase-spacing jitter, and current-sharing quantization.

## 9. Exact next prompt draft

```text
R052_DIGITAL_JITTER_BUDGET_CONSOLIDATION

请先读取 .codex/skills/iqcot-research/SKILL.md、docs/CODEX_RESEARCH_WORKFLOW.md、docs/CODEX_OUTPUT_PROTOCOL.md、docs/deep_research_external_literature_review_summary.md、refine-logs/LOCAL_AUDIT_R051_PIS_IEK_ACTUATOR_ABLATION.md、docs/r051_pis_iek_actuator_ablation_consolidation.md、output/tables/r051_actuator_evidence_map.csv、output/tables/r051_actuator_claim_boundary_table.csv、output/iqcot_claims_evidence_matrix.md、research-wiki/log.md 和 research-wiki/query_pack.md。

本轮目标是巩固当前强论文主线中的 digital implementation budget。请只整理和审计现有证据，不运行新的 Simulink 仿真，不训练 AI，不修改原始 .slx，不运行 full matrix。

必须检索并整理：area_bits、detect_clock_ns、ton_resolution_ps、comp_delay_sigma_ns、wait jitter、phase-spacing std、current-sharing rms、delay_diff、Ton resolution、area quantization、supervisor delay、tau_AI、event delay、digital budget、fig10_jitter_budget、fig19_pis_iek_monte_carlo_budget。

请生成：
1. refine-logs/LOCAL_AUDIT_R052_DIGITAL_JITTER_BUDGET.md
2. output/tables/r052_digital_budget_evidence_map.csv
3. output/tables/r052_digital_budget_claim_boundary_table.csv
4. docs/r052_digital_jitter_budget_consolidation.md

如果现有证据足够，请分类为 MODEL_CONFIRMED 并推荐 R053_PR_ECB_CONTROLLED_REENTRY_MINIMAL_CHUNK；如果证据不足，请分类为 CLAIM_DOWNGRADED 或 MODEL_REVISED，并提出一个最小补证任务。最后按 docs/CODEX_OUTPUT_PROTOCOL.md 输出并 git commit / push。
```

## 10. Result classification

`MODEL_CONFIRMED`

R051 confirms that the existing repository evidence is sufficient for a paper-ready actuator-separation wording inside the studied four-phase digital IQCOT implementation. The classification is not a controller-performance upgrade and not a hardware/HIL claim.
