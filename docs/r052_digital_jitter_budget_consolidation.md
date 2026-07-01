# R052 Digital Jitter Budget Consolidation

Date: 2026-07-01

## 1. Purpose

R052 is a consolidation round, not a new simulation round. It reorganizes existing digital implementation budget evidence into a paper-ready evidence package for the studied four-phase digital IQCOT implementation.

The hypothesis audited here is:

```text
Area threshold quantization, detection clock, Ton resolution, comparator/detection delay, and supervisor latency can be mapped through PIS-IEK into event wait jitter, phase-spacing jitter, and current-sharing quantization.
```

No new Simulink simulation, AI training, full matrix, or original `.slx` modification was performed.

## 2. Literature and Research Boundary

The R050 deep-research integration sets the literature boundary for this document:

- Digital COT, DICOT, and digital VRM literature already studies ADC delay, calculation delay, DPWM or on-time resolution, and current-balance implementation effects.
- This project must not claim to be the first study of digital COT quantization or digital current balance.
- The defensible contribution is narrower: mapping the studied four-phase digital IQCOT nonidealities - area threshold quantization, detection clock, on-time resolution, comparator/detection delay, and supervisor latency - into a unified PIS-IEK event-domain budget.

Therefore the budget language below is limited to a model-level and derived-Simulink-supported design guideline. It is not hardware/HIL validation and does not eliminate the need for switching-level or hardware validation.

## 3. Evidence Sources

Files inspected and used for this consolidation:

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

Generated R052 tables:

- `output/tables/r052_digital_budget_evidence_map.csv`
- `output/tables/r052_digital_budget_claim_boundary_table.csv`

No new figure was generated. Existing evidence figures include `output/figures/fig10_jitter_budget.png` and `output/figures/fig19_pis_iek_monte_carlo_budget.png`.

## 4. Area Threshold Quantization Evidence

Area threshold quantization affects the event threshold used by the IQCOT area comparator. In PIS-IEK, threshold perturbations enter the event surface and therefore map naturally to event wait jitter and Lambda-related phase/event rhythm budget.

Key evidence:

- `output/iqcot_digital_area_bit_budget.csv`: with the conservative full-scale assumption `2*Lambda_nominal`, `12 bit` area threshold quantization gives `q_lambda=3.0976284074115916e-13 V*s`.
- The same row gives `q_lambda/Lambda_nominal=0.00048828125`, common wait jitter `0.032354876 ns rms`, m2 phase-spacing jitter `0.118252895 ns`, and m2 event wait jitter `0.059129036 ns`.
- `output/iqcot_digital_jitter_gain_summary.csv` records `lambda_phase_gain=1.3224311976095063e12 ns/(V*s)` for the m2 Lambda channel.

Evidence strength is strong for model-level budget mapping. It is not hardware validation because the result is derived from PIS-IEK local sensitivity and deterministic budget rows.

Safe wording:

```text
Within the studied four-phase digital IQCOT implementation, area-threshold quantization can be budgeted as an event-threshold perturbation that maps to wait jitter and phase/event rhythm jitter.
```

## 5. Detection Clock Evidence

Detection clock quantization affects when an event is observed and committed. This maps most directly to event timing quantization and phase-spacing jitter.

Key evidence:

- `output/iqcot_digital_detection_clock_budget.csv`: `detect_clock_ns=1.0` gives single-event delay rms `0.288675135 ns`.
- The same row gives adjacent spacing direct jitter `0.408248290 ns`, m2 phase-spacing model jitter `0.891310980 ns`, and current m2 model perturbation `0.067116320 mA`.
- The deterministic combined budget row for `12 bit / 1 ns clock / 10 ps Ton` gives common wait jitter `0.290482652 ns rms`, phase-spacing jitter `2.480147589 ns rms`, and current quantization `22.085792730 mA`.

Evidence strength is strong for digital event timing budget. It remains model-level evidence, not a measurement of a real FPGA clocking path.

Safe wording:

```text
Detection-clock granularity should be treated as event-timing quantization that contributes to wait jitter and phase-spacing jitter in the PIS-IEK budget.
```

## 6. Ton Resolution Evidence

Ton resolution determines how finely the strong `Ton_diff` current-sharing actuator can be commanded. R051 confirmed that `Ton_diff` is the primary DC current-sharing actuator, so Ton resolution directly sets current-sharing quantization and also contributes to phase-spacing cost.

Key evidence:

- `output/iqcot_digital_ton_resolution_budget.csv`: `ton_resolution_ps=10` gives `sigma_ton_quant=0.002886751 ns`.
- The same row gives m2 current quantization scale `22.085690750 mA` and m2 phase-spacing scale `2.443456906 ns`.
- `output/iqcot_digital_jitter_gain_summary.csv`: `ton_current_gain=7650.707700 mA/ns` and `ton_phase_gain=846.438301 ns/ns`.
- R051 evidence: `Ton_diff` current gain is `765.070770 mA/(0.1 ns)`, matching the normalized `7650.707700 mA/ns` budget gain.

Evidence strength is strong for design granularity. It does not prove hardware current-sharing performance by itself because controller guards, sensing confidence, and switching-level behavior still matter.

Safe wording:

```text
Because Ton_diff is the dominant DC current-sharing channel in the studied model, Ton resolution sets a first-order lower bound on the achievable current-sharing trim granularity.
```

## 7. Comparator / Detection Delay Evidence

Comparator and detection delay primarily perturb event timing. R051 already classified `delay_diff` as a jitter/detection timing disturbance rather than a main DC current-sharing actuator, and R052 turns that separation into a digital implementation budget.

Key evidence:

- `output/iqcot_digital_jitter_gain_summary.csv`: `delay_phase_gain=3.087591804 ns/ns` and `delay_current_gain=0.232497752 mA/ns`.
- `output/iqcot_pis_iek_monte_carlo_summary.csv`: for `12 bit / 1 ns clock / 10 ps Ton / 0.5 ns comparator-delay sigma`, wait jitter rms mean is `0.646621660 ns`, phase-spacing std mean is `0.646605297 ns`, and current-share rms mean is `0.505914535 mA`.
- `output/iqcot_pis_iek_monte_carlo_budget_report.md` summarizes the same representative point as `0.6466 ns`, `0.6466 ns`, and `0.5059 mA`.

Evidence strength is strong for disturbance/budget interpretation and medium-strong for combined stochastic budget. It is not comparator silicon characterization.

Safe wording:

```text
Comparator and detection delay are best treated as timing-jitter budget terms that mostly affect wait jitter and phase spacing, with only weak direct DC current-sharing authority.
```

## 8. Supervisor / AI Delay Evidence

Supervisor latency maps to an event-indexed delayed action. In PIS-IEK notation, the applied supervisory command should be modeled as `u_{k-d}`, where `d=ceil(tau_AI/T_event)`.

Key evidence:

- `output/iqcot_ai_delay_event_surrogate_report.md`: event period is `0.5 us`, so `tau_AI=5 us` spans `10` IQCOT events.
- In the representative severe `40A->near-0A`, `T_update=5us` slice, zero-delay-trained mean violations are `147.875`, while delay-aware projected mean violations are `24.297`.
- The same report states that at `tau_AI=1us`, zero-delay-trained remains competitive in the same slice: zero-delay reward `-637.369` versus delay-aware reward `-772.161`.
- `output/iqcot_table_supervisor_delay_sensitivity_report.md` provides derived-Simulink delayed-reference evidence at `tau_AI=0.5/1/2/5 us`, showing objective-sensitive ordering under delay.

Evidence strength is medium for AI/supervisor latency design. The surrogate and table-driven delayed-reference evidence support delayed-coordinate modeling, not neural AI-in-loop superiority and not gate-level AI control.

Safe wording:

```text
Supervisor latency should be represented as event-indexed delay in the supervisory action path; multi-event latency motivates delay-aware training or projection, while small-delay cases may still be adequately handled by zero-delay-trained policies.
```

## 9. Combined Budget Matrix

| Nonideality | Example value | Event-domain effect | Main affected metric | Evidence strength | Design implication |
|---|---:|---|---|---|---|
| Area threshold quantization | `12 bit`, `q_lambda=3.0976e-13 V*s` | Event threshold perturbation | `0.0324 ns` common wait rms, `0.1183 ns` m2 phase-spacing | Strong model budget | Set area DAC/threshold bits from allowed wait and phase jitter |
| Detection clock | `1 ns` | Event observation quantization | `0.2887 ns` single-event rms, `0.8913 ns` m2 phase jitter | Strong model budget | Clock granularity belongs in phase-spacing budget |
| Ton resolution | `10 ps` | On-time command quantization | `22.0857 mA` m2 current scale, `2.4435 ns` phase-spacing scale | Strong model budget | Ton resolution is a current-sharing trim granularity constraint |
| Comparator delay | `0.5 ns sigma` in Monte Carlo point | Random event timing delay | representative combined wait/phase `0.6466 ns` | Medium-strong stochastic budget | Treat comparator delay as jitter uncertainty, not as a main actuator |
| Supervisor delay | `5 us = 10 events` | Delayed low-dimensional action `u_{k-d}` | violations `147.875 -> 24.297` in a severe surrogate slice | Medium latency-design evidence | Train/evaluate supervisor in delayed event coordinates |
| Combined Monte Carlo budget | `12 bit / 1 ns / 10 ps / 0.5 ns` | Joint digital nonidealities | wait `0.6466 ns`, phase `0.6466 ns`, current-share `0.5059 mA`; 4096 detail rows, 256 aggregate rows | Medium-strong model/surrogate budget | Use as design guideline and supplement table, not hardware proof |

## 10. Relationship to R051 Actuator Separation

R052 follows directly from R051:

- `Ton_diff` is the primary DC sharing actuator, so Ton resolution determines the granularity of DC current-sharing trim.
- `Lambda_diff` is a phase/event actuator, so area-threshold quantization primarily affects event threshold, wait jitter, phase rhythm, and ripple-cancellation neighborhood behavior.
- `delay_diff` is a jitter disturbance, so comparator, detection, and supervisor delays should be carried as timing budget terms rather than main control actions.
- This relationship is why digital budget is the next paper-ready pillar after actuator separation.

## 11. AI / Supervisor Design Implication

AI should not directly control gates, per-cycle pulses, or raw delay. The safe framing is a low-dimensional supervisory parameter proposer whose output is bounded and projected before entering the IQCOT event interface.

Supervisor latency must be represented as an event-indexed delay. Delay-aware training or projection can matter when the delay spans multiple events, but the repository evidence also shows that a zero-delay-trained policy may remain competitive at small delay. Therefore action projection should include timing and quantization bounds rather than only voltage/current objectives.

## 12. Claim Status After R052

| Claim | R051 status | R052 status | Reason | Next evidence gap |
|---|---|---|---|---|
| PIS-IEK event interface | unchanged / supported | supported | R052 shows PIS-IEK also carries quantization, clock, Ton, and delay budget terms | Prepare final related-work/contribution wording |
| Actuator separation | MODEL_CONFIRMED | unchanged / supported | Ton/Lambda/delay roles explain which nonideality maps to which budget channel | No new actuator claim needed |
| Digital implementation budget | pending R052 consolidation | MODEL_CONFIRMED within studied scope | deterministic budget rows plus Monte Carlo and supervisor-delay evidence support safe wording | R053 can proceed to PR-ECB minimal chunk |
| AI/supervisor delay | clarified only | clarified / medium evidence | `tau_AI=5 us` equals `10` events and supports `u_{k-d}` delayed-coordinate framing | Rule/table supervisor validation before neural claims |
| PR-ECB | not touched | unchanged | R052 did not audit PR-ECB control performance | R053 controlled reentry minimal chunk |
| active-set model | not touched | unchanged | No active-set validation in R052 | Later add/shed minimal chunk |

## 13. Paper-ready Wording

Chinese:

```text
在所研究的四相数字 IQCOT 实现中，PIS-IEK 不仅可用于区分 Ton_diff、Lambda_diff 与 delay_diff 的执行量作用，还可将面积阈值量化、检测时钟、Ton 分辨率、比较器/检测延迟和 supervisor 提交延迟统一映射到 event wait jitter、phase-spacing jitter 与 current-sharing quantization。当前证据支持该框架作为数字实现预算和设计 guideline，但尚未构成硬件/HIL 验证，也不能替代开关级验证。
```

English:

```text
For the studied four-phase digital IQCOT implementation, PIS-IEK provides a unified budget view that maps area-threshold quantization, detection-clock granularity, on-time resolution, comparator/detection delay, and supervisor latency to event wait jitter, phase-spacing jitter, and current-sharing quantization. The current evidence supports this framework as a digital implementation budget and design guideline, but not as hardware/HIL validation or a replacement for switching-level validation.
```

## 14. Forbidden Wording

- Digital budget is hardware validated.
- Quantization analysis proves real FPGA performance.
- AI delay-aware policy is always better.
- Supervisor can replace per-cycle IQCOT event generation.
- Delay_diff should be the main AI action.
- The budget applies to all COT/IQCOT converters without revalidation.
- This eliminates the need for switching-level validation.

## 15. Recommended Next Minimal Task

Recommended next task:

```text
R053_PR_ECB_CONTROLLED_REENTRY_MINIMAL_CHUNK
```

Why:

R052 found enough existing evidence to support the digital budget safe wording within the studied scope. The next smallest useful step in the R050 workflow is to return to the PR-ECB exploratory line with one controlled reentry minimal chunk, while preserving the R051/R052 paper-ready core.
