# R052 Digital Jitter Budget Audit

Date: 2026-07-01

## 1. Objective

Consolidate existing evidence for the digital implementation budget of the studied four-phase digital IQCOT implementation. The round audits whether area threshold quantization, detection clock, Ton resolution, comparator/detection delay, and supervisor latency can be safely written as PIS-IEK event-domain budget terms without running new Simulink simulation, training AI, modifying original `.slx` files, or running a full matrix.

## 2. Hypothesis

Hypothesis:

```text
Area threshold quantization, detection clock, Ton resolution, comparator/detection delay, and supervisor latency can be mapped through PIS-IEK into event wait jitter, phase-spacing jitter, and current-sharing quantization.
```

Expected failure mode:

```text
Numeric evidence cannot be located, the budget sources cannot be mapped through PIS-IEK, or the evidence only supports a preliminary qualitative discussion rather than paper-ready design-guideline wording.
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
- `refine-logs/LOCAL_AUDIT_R051_PIS_IEK_ACTUATOR_ABLATION.md`
- `docs/r051_pis_iek_actuator_ablation_consolidation.md`
- `output/tables/r051_actuator_evidence_map.csv`
- `output/tables/r051_actuator_claim_boundary_table.csv`
- `output/iqcot_claims_evidence_matrix.md`
- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`
- `research-wiki/log.md`
- `research-wiki/query_pack.md`

Evidence files:

- `output/iqcot_digital_area_bit_budget.csv`
- `output/iqcot_digital_detection_clock_budget.csv`
- `output/iqcot_digital_ton_resolution_budget.csv`
- `output/iqcot_digital_combined_jitter_budget.csv`
- `output/iqcot_digital_jitter_gain_summary.csv`
- `output/iqcot_digital_jitter_budget.py`
- `output/iqcot_pis_iek_monte_carlo_budget.py`
- `output/iqcot_pis_iek_monte_carlo_budget_report.md`
- `output/iqcot_pis_iek_monte_carlo_detail.csv`
- `output/iqcot_pis_iek_monte_carlo_summary.csv`
- `output/iqcot_pis_iek_delay_cutload_extension.md`
- `output/iqcot_ai_delay_event_surrogate.py`
- `output/iqcot_ai_delay_event_surrogate_report.md`
- `output/iqcot_ai_delay_event_surrogate_detail.csv`
- `output/iqcot_ai_delay_event_surrogate_summary.csv`
- `output/iqcot_table_supervisor_delay_sensitivity_report.md`
- `output/iqcot_multiphase_iek_paper_latest.md`
- `output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md`
- `output/iqcot_pis_iek_derivation_package.md`
- `output/iqcot_integrated_research_paper.md`

Keyword search was performed for:

```text
digital budget, jitter budget, area_bits, detect_clock_ns, detection clock,
Ton resolution, ton_resolution_ps, area quantization, Lambda quantization,
threshold quantization, comparator delay, comp_delay_sigma_ns, delay_diff,
delay_phase_gain, delay_current_gain, wait jitter, wait_jitter, event wait rms,
phase-spacing, phase spacing std, current-share rms, current sharing quantization,
Monte Carlo, 12 bit, 1 ns, 10 ps, 0.5 ns, tau_AI, supervisor delay,
event delay, u_{k-d}, 5 us, 10 events, delay-aware, zero-delay, FPGA,
detection delay, quantization, DPWM, fig10_jitter_budget,
fig19_pis_iek_monte_carlo_budget.
```

Files requested but not found:

- none among the explicitly listed R052 evidence files.

## 4. Evidence found

### Area threshold quantization

Source files:

- `output/iqcot_digital_area_bit_budget.csv`
- `output/iqcot_digital_jitter_gain_summary.csv`
- `output/iqcot_multiphase_iek_paper_latest.md`
- `output/iqcot_pis_iek_derivation_package.md`
- `output/tables/r051_actuator_evidence_map.csv`

Numeric evidence:

- `12 bit` area threshold row: `q_lambda=3.0976284074115916e-13 V*s`.
- `q_lambda/Lambda_nominal=0.00048828125`.
- Common wait jitter estimate: `0.032354876 ns rms`.
- m2 phase-spacing estimate: `0.118252895 ns`.
- m2 event wait estimate: `0.059129036 ns`.
- Lambda timing gains: `lambda_phase_gain=1.3224311976095063e12 ns/(V*s)` and `lambda_event_rms_gain=6.612445449297971e11 ns/(V*s)`.

Interpretation:

Area threshold quantization is an event-threshold perturbation. It belongs in the Lambda/event timing budget, not in hardware-validation wording.

Evidence strength:

Strong for model-level budget mapping.

Missing evidence:

No measured area-DAC or FPGA threshold implementation data.

### Detection clock

Source files:

- `output/iqcot_digital_detection_clock_budget.csv`
- `output/iqcot_digital_combined_jitter_budget.csv`
- `output/iqcot_multiphase_iek_paper_latest.md`

Numeric evidence:

- `detect_clock_ns=1.0` row: single-event delay rms `0.288675135 ns`.
- Adjacent spacing direct jitter `0.408248290 ns`.
- m2 phase-spacing model jitter `0.891310980 ns`.
- m2 current model perturbation `0.067116320 mA`.
- Combined deterministic `12 bit / 1 ns / 10 ps` row: common wait rms `0.290482652 ns`, phase-spacing rms `2.480147589 ns`, current rms `22.085792730 mA`.

Interpretation:

Detection clock maps primarily to event timing quantization and phase-spacing jitter.

Evidence strength:

Strong for model-level event timing budget.

Missing evidence:

No real digital capture path or FPGA clock-domain measurement.

### Ton resolution

Source files:

- `output/iqcot_digital_ton_resolution_budget.csv`
- `output/iqcot_digital_jitter_gain_summary.csv`
- `refine-logs/LOCAL_AUDIT_R051_PIS_IEK_ACTUATOR_ABLATION.md`
- `docs/r051_pis_iek_actuator_ablation_consolidation.md`
- `output/tables/r051_actuator_evidence_map.csv`

Numeric evidence:

- `ton_resolution_ps=10` row: `sigma_ton_quant=0.002886751 ns`.
- m2 current quantization scale `22.085690750 mA`.
- m2 phase-spacing scale `2.443456906 ns`.
- Normalized `Ton_diff` current gain `7650.707700 mA/ns`.
- R051 `Ton_diff` current gain `765.070770 mA/(0.1 ns)`.

Interpretation:

R051 confirmed `Ton_diff` as the primary DC current-sharing actuator. Therefore Ton resolution sets the current-sharing trim granularity and must be treated as a key digital implementation constraint.

Evidence strength:

Strong for design granularity. Not sufficient for closed-loop controller performance without guard validation.

Missing evidence:

No selected hardware DPWM/Ton generator measurement.

### Comparator / detection delay

Source files:

- `output/iqcot_digital_jitter_gain_summary.csv`
- `output/iqcot_pis_iek_monte_carlo_budget_report.md`
- `output/iqcot_pis_iek_monte_carlo_summary.csv`
- `output/iqcot_pis_iek_monte_carlo_detail.csv`
- `output/iqcot_pis_iek_delay_cutload_extension.md`
- `output/tables/r051_actuator_evidence_map.csv`

Numeric evidence:

- Delay phase gain `3.087591804 ns/ns`.
- Delay current gain `0.232497752 mA/ns`.
- Representative Monte Carlo point `12 bit / 1 ns / 10 ps / 0.5 ns`: wait jitter rms mean `0.646621660 ns`, phase-spacing std mean `0.646605297 ns`, current-share rms mean `0.505914535 mA`.

Interpretation:

Comparator and detection delay are timing-jitter disturbances. They map into wait and phase jitter more directly than DC current sharing and should not become the main AI action.

Evidence strength:

Strong for delay-as-budget interpretation; medium-strong for combined stochastic budget.

Missing evidence:

No measured comparator delay distribution.

### Supervisor / AI delay

Source files:

- `output/iqcot_ai_delay_event_surrogate.py`
- `output/iqcot_ai_delay_event_surrogate_report.md`
- `output/iqcot_ai_delay_event_surrogate_detail.csv`
- `output/iqcot_ai_delay_event_surrogate_summary.csv`
- `output/iqcot_table_supervisor_delay_sensitivity_report.md`
- `output/iqcot_claims_evidence_matrix.md`

Numeric evidence:

- Event period `0.5 us`.
- `tau_AI=5 us` spans `10` IQCOT events.
- Severe `40A->near-0A`, `T_update=5us` slice: zero-delay-trained violations `147.875`; delay-aware projected violations `24.297`.
- At `tau_AI=1us`, zero-delay-trained remains competitive in the same slice: reward `-637.369` versus delay-aware reward `-772.161`.
- AI delay surrogate detail rows: `15360`; summary rows: `240`.

Interpretation:

Supervisor latency should be written as an event-indexed delayed action `u_{k-d}`, not as gate-level AI control. Delay-aware methods may matter when latency spans multiple events, but zero-delay training can remain competitive in small-delay slices.

Evidence strength:

Medium for supervisor-latency design. Not neural AI-in-loop validation.

Missing evidence:

No real AI inference stack or hardware-in-the-loop timing measurement.

### Combined Monte Carlo budget

Source files:

- `output/iqcot_pis_iek_monte_carlo_budget.py`
- `output/iqcot_pis_iek_monte_carlo_budget_report.md`
- `output/iqcot_pis_iek_monte_carlo_detail.csv`
- `output/iqcot_pis_iek_monte_carlo_summary.csv`
- `output/figures/fig19_pis_iek_monte_carlo_budget.png`
- `output/figures/fig19_pis_iek_monte_carlo_budget.svg`

Numeric evidence:

- Monte Carlo detail rows: `4096`.
- Aggregate rows: `256`.
- Representative point `12 bit / 1 ns / 10 ps / 0.5 ns`: wait jitter rms mean `0.646621660 ns`, phase-spacing std mean `0.646605297 ns`, current-share rms mean `0.505914535 mA`.
- Worst aggregate point: `bits=10`, `clock=5.0 ns`, `Ton=50 ps`, `delay sigma=2.0 ns`, phase-spacing std p95 `2.881823 ns`.
- Best aggregate point: `bits=16`, `clock=0.5 ns`, `Ton=5 ps`, `delay sigma=0.0 ns`, phase-spacing std p95 `0.168400 ns`.

Interpretation:

The combined budget evidence is sufficient for a paper-ready model-level design guideline. It is not hardware/HIL validation and does not replace switching-level validation.

Evidence strength:

Medium-strong model/derived-Simulink-level budget evidence.

Missing evidence:

No measured FPGA/ASIC or HIL timing distribution.

## 5. Digital budget decision

- area threshold quantization: `MODEL_CONFIRMED`
- detection clock: `MODEL_CONFIRMED`
- Ton resolution: `MODEL_CONFIRMED`
- comparator/detection delay: `MODEL_CONFIRMED`
- supervisor/AI delay: `MODEL_CONFIRMED` for delayed-coordinate wording; not an AI performance upgrade
- combined budget: `MODEL_CONFIRMED`

Rationale:

The available evidence supports the R052 safe wording:

```text
PIS-IEK maps area threshold quantization, detection clock, Ton resolution, comparator/detection delay, and supervisor latency into event wait jitter, phase-spacing jitter, and current-sharing quantization as a model-level digital implementation budget.
```

The result does not confirm hardware/HIL behavior, real FPGA/ASIC performance, PR-ECB behavior, active-set add/shed behavior, or neural AI superiority.

## 6. Claim matrix update decision

`output/iqcot_claims_evidence_matrix.md` was not modified in R052.

Reason:

- The matrix already contains an R050 digital budget line and delay-related claim boundaries.
- The working tree contains pre-existing uncommitted edits in `output/iqcot_claims_evidence_matrix.md`; R052 avoids mixing unrelated hunks.
- R052 instead creates structured tables:
  - `output/tables/r052_digital_budget_evidence_map.csv`
  - `output/tables/r052_digital_budget_claim_boundary_table.csv`

## 7. Limitations

- No new simulation.
- No hardware/HIL validation.
- Based on existing repository evidence.
- Not generalized to all COT/IQCOT converters.
- No PR-ECB validation.
- No active-set validation.
- No AI training.
- Digital budget remains model/derived-Simulink-level evidence.
- Supervisor-delay evidence is surrogate/table-driven delayed-reference support, not neural AI-in-loop or hardware execution.

## 8. Recommended next task

Recommended next task:

```text
R053_PR_ECB_CONTROLLED_REENTRY_MINIMAL_CHUNK
```

Why this is the smallest useful next step:

R051 and R052 now consolidate the strongest paper-ready spine: actuator separation plus digital implementation budget. The next task in the R050 workflow is to return to the PR-ECB exploratory line with one controlled reentry minimal chunk, keeping it separate from the paper-ready PIS-IEK budget claims.

## 9. Exact next prompt draft

```text
R053_PR_ECB_CONTROLLED_REENTRY_MINIMAL_CHUNK

请先读取 .codex/skills/iqcot-research/SKILL.md、docs/CODEX_RESEARCH_WORKFLOW.md、docs/CODEX_OUTPUT_PROTOCOL.md、docs/deep_research_external_literature_review_summary.md、refine-logs/LOCAL_AUDIT_R051_PIS_IEK_ACTUATOR_ABLATION.md、refine-logs/LOCAL_AUDIT_R052_DIGITAL_JITTER_BUDGET.md、docs/r051_pis_iek_actuator_ablation_consolidation.md、docs/r052_digital_jitter_budget_consolidation.md、output/tables/r051_actuator_evidence_map.csv、output/tables/r052_digital_budget_evidence_map.csv、output/iqcot_claims_evidence_matrix.md、research-wiki/log.md 和 research-wiki/query_pack.md。

本轮目标是在不扩大 full matrix 的前提下，做 PR-ECB controlled reentry 的一个最小验证块，并保持它作为 exploratory controlled extension，而不是覆盖 R051/R052 的强论文主线。请优先复查 R049/R050/R051/R052 的边界，选择一个 load-drop magnitude x two phase offsets 的最小 chunk；只使用 derived `.slx` 副本，不修改原始 `.slx`，不训练 AI，不声称硬件/HIL。

必须记录 baseline、candidate、first-peak、secondary undershoot、phase/reentry event timing、remaining Ton 或 release timing 相关指标，并明确 PR-ECB 是 risk boundary / safety guard，不是 universal first-peak predictor。

请生成 refine-logs/LOCAL_AUDIT_R053_PR_ECB_CONTROLLED_REENTRY.md、docs/r053_pr_ecb_controlled_reentry_minimal_chunk.md、必要的 output/tables/r053_*.csv，并按 docs/CODEX_OUTPUT_PROTOCOL.md 输出。若最小 chunk 支持当前假设，分类 MODEL_CONFIRMED；若暴露 reentry/edge-source/implementation issue，分类 MODEL_REVISED 或 IMPLEMENTATION_ISSUE；最后 git commit / push。
```

## 10. Result classification

`MODEL_CONFIRMED`

R052 confirms that existing repository evidence is sufficient for a paper-ready digital implementation budget wording inside the studied four-phase digital IQCOT implementation. The classification is not a hardware/HIL claim, not an FPGA/ASIC measurement claim, not an AI performance claim, and not a replacement for switching-level validation.
