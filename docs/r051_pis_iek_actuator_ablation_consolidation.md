# R051 PIS-IEK Actuator Ablation Consolidation

Date: 2026-07-01

## 1. Purpose

R051 is a consolidation round, not a new simulation round. It reorganizes existing repository evidence into a paper-ready actuator-separation package for the studied four-phase digital IQCOT implementation.

The hypothesis audited here is:

```text
Ton_diff is the primary DC current-sharing actuator.
Lambda_diff mainly shapes phase-spacing / event rhythm.
delay_diff is a phase-jitter / detection-timing disturbance.
```

No new Simulink simulation, AI training, full matrix, or original `.slx` modification was performed.

## 2. Literature and Research Boundary

The R050 deep-research integration sets the boundary for this document:

- IQCOT already has foundational literature and must be cited.
- Multiphase COT small-signal and phase-overlap modeling literature already exists.
- Current-balance loop literature already exists.
- This project should not claim to invent IQCOT, to be the first multiphase COT small-signal model, or to prove a hardware/HIL controller.
- The defensible novelty is the IQCOT-specific four-phase digital event interface: PIS-IEK, actuator separation, and digital implementation budget.

Therefore the actuator language below is limited to the studied four-phase digital IQCOT model and its existing event-domain / derived-Simulink evidence.

## 3. Evidence Sources

Files inspected and used for this consolidation:

- `.codex/skills/iqcot-research/SKILL.md`
- `docs/CODEX_RESEARCH_WORKFLOW.md`
- `docs/CODEX_OUTPUT_PROTOCOL.md`
- `docs/deep_research_external_literature_review_summary.md`
- `refine-logs/LOCAL_AUDIT_R050_RESEARCH_STATE_ALIGNMENT.md`
- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`
- `research-wiki/log.md`
- `research-wiki/query_pack.md`
- `output/iqcot_claims_evidence_matrix.md`
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

Generated R051 tables:

- `output/tables/r051_actuator_evidence_map.csv`
- `output/tables/r051_actuator_claim_boundary_table.csv`

## 4. Lambda_diff Evidence

`Lambda_diff` affects event timing, phase-spacing, and ripple-cancellation neighborhood behavior. It is not safely writable as a strong DC current-sharing actuator.

Key evidence:

- Analytic actuator matrix: `lambda_diff,m2_alt` has current gain `0.009957935 mA/(1e-13 V*s)`, phase wait gain `0.132243120 ns/(1e-13 V*s)`, and event wait rms gain `0.066124454 ns/(1e-13 V*s)`.
- Per-phase IEK derived-Simulink report: at `Lambda_m2/Lambda_area=0.4`, m2 current projection is only `0.001163 A`, while phase-spacing std is reported at `24.839189 ns`.
- Static load sweep: across 20/30/40/50 A with `Lambda_m2/Lambda_area=0.4`, max m2 current projection is `0.009382 A`.
- E030 C2 Lambda-only ablation: max current imbalance remains `0.853665 A`, matching C0, while Lambda usage reaches `0.75` and clamp count is `78`.

Answer to the DC current-sharing question:

`Lambda_diff` is not a strong DC current-sharing actuator in the current evidence. It can have small current effects and should not be described as "no effect," but the safe role is phase-spacing / event-rhythm trim.

Safe wording:

```text
Within the studied four-phase digital IQCOT implementation, Lambda_diff mainly acts through event timing and phase-spacing channels, and the available evidence does not support treating it as a strong DC current-sharing actuator.
```

## 5. Ton_diff Evidence

`Ton_diff` directly changes per-phase injected on-time energy. That is why it is the main DC current-sharing actuator in the current model, with an important phase/ripple/voltage cost.

Key evidence:

- Analytic actuator matrix: `ton_diff,m2_alt` has current gain `765.070770 mA/(0.1 ns)`, phase wait gain `84.643830 ns/(0.1 ns)`, and event wait rms gain `42.409492 ns/(0.1 ns)`.
- Simulink modal cross-validation: `[+4,-4,+4,-4] ns` gives m2 current projection `1.943019973 A` and phase-current imbalance `3.927571685 A`.
- E030 C1 Ton-only ablation: max imbalance improves from C0 `0.853665 A` to `0.313775 A`, but ripple rises to `15.2173 mV` and final Vout error reaches `-58.1561 mV`.
- E030 C4/R1/R3 guarded variants show that projection and sensing/calibration guards are necessary before Ton-based current sharing is treated as a controller claim.

Answer to the phase-cost question:

`Ton_diff` is strong because it changes volt-second injection. The same mechanism perturbs wait time and phase spacing, so Ton cannot be presented as a free or universal fix.

Safe wording:

```text
Within the studied four-phase digital IQCOT implementation, Ton_diff is the primary DC current-sharing actuator, but it must be constrained by phase-spacing, ripple, voltage-error, and sensing-confidence guards.
```

## 6. delay_diff Evidence

`delay_diff` affects detection timing and event placement. It is better treated as a disturbance and implementation-budget term than as a supervisory control actuator.

Key evidence:

- Analytic actuator matrix: `delay_diff,m2_alt` has current gain `0.023249775 mA/(0.1 ns)`, phase wait gain `0.308759180 ns/(0.1 ns)`, and event wait rms gain `0.154386352 ns/(0.1 ns)`.
- Digital jitter gain summary: normalized delay phase gain is `3.087591804 ns/ns`, while current gain is only `0.232497752 mA/ns`.
- Monte Carlo digital budget: a representative `12 bit`, `1 ns` clock, `10 ps` Ton resolution, `0.5 ns` comparator-delay case gives wait jitter rms mean `0.6466 ns`, phase-spacing std mean `0.6466 ns`, and current-share rms mean `0.5059 mA`.

Answer to the AI-action question:

`delay_diff` should not be a main AI action. If delay can be calibrated, it belongs in calibration, timing budget, or uncertainty compensation. AI/table supervision should operate through bounded low-dimensional parameters and projection, not direct delay or gate manipulation.

## 7. Actuator Separation Matrix

| Actuator | Main role | Secondary effect | Best use | Not suitable for | Evidence strength |
|---|---|---|---|---|---|
| `Lambda_diff` | Phase-spacing / event rhythm trim | Small current perturbation | Phase/event boundary variable, ripple-cancellation neighborhood trim | Strong DC current-sharing actuator | Strong for role separation; active Lambda control still not validated |
| `Ton_diff` | Primary DC current-sharing actuator | Phase-spacing, ripple, and final-error cost | Guarded current-sharing trim with `K_T`, `T_trim_max`, and sensing confidence | Universal transient fix or unconstrained Ton action | Strong for actuator role; controller performance remains guarded/conditional |
| `delay_diff` | Detection timing / phase jitter disturbance | Very weak current perturbation | Digital jitter budget, calibration term, uncertainty model | Primary AI or current-sharing action | Strong for disturbance/budget interpretation |
| Combined projected action | Ton-primary guarded `a_S` with Lambda boundary | Trade-off among current balance, phase, ripple, voltage, sensing | Safe action-space design and projection interface | Claiming C4 globally beats Ton-only or validates active Lambda | Medium-strong for design boundary |

## 8. AI Action Implication

The next AI/table supervisor action space should prioritize:

- `K_T`
- `T_trim_max`
- `balance_recovery_rate`

Secondary or boundary controls:

- `K_Lambda`
- `Lambda_trim_max`

Not recommended as a main action:

- `delay_diff`

Reasoning:

- `Ton_diff` has the dominant DC current-sharing channel.
- `Lambda_diff` is better used for phase/event rhythm micro-adjustment or kept as a projected boundary until an event-native Lambda path is validated.
- `delay_diff` is a disturbance / implementation budget channel.
- AI must not directly control gates or per-cycle pulses.

## 9. Claim Status After R051

| Claim | R050 status | R051 status | Reason | Next evidence gap |
|---|---|---|---|---|
| PIS-IEK event interface | strongest paper-ready line | unchanged / supported | Actuator separation remains consistent with PIS-IEK event-domain evidence | R052 digital budget consolidation |
| `Ton_diff` as DC current-sharing actuator | strongest paper-ready line | MODEL_CONFIRMED within studied scope | Analytic matrix, Simulink m2 cross-validation, and E030 ablations agree | Convert Ton resolution/phase cost into budget table |
| `Lambda_diff` as phase/event actuator | strongest paper-ready line | MODEL_CONFIRMED for safe wording | Analytic, per-phase IEK, load sweep, and C2 evidence all reject strong DC-sharing role | Event-native active Lambda micro-audit only if active Lambda control is claimed |
| `delay_diff` as jitter disturbance | strongest paper-ready line | MODEL_CONFIRMED for safe wording | Delay current gain is weak while phase/wait gain is direct | R052 digital jitter budget consolidation |
| Combined projected `a_S` controller | controlled / guarded | conditional, not globally confirmed | E030/R1 require projection and R3 requires sensing/calibration guard | Freeze guarded selector before broader controller claims |
| PR-ECB | controlled exploratory extension | not touched | R051 did not audit PR-ECB control performance | R053 after R052 |
| AI supervisor | controlled exploratory extension | clarified only | R051 only maps safe action implications | Rule/table supervisor validation before neural claims |
| active-set model | future controlled extension | not touched | No active-set validation in R051 | Later E040/R055-style minimal add/shed chunk |

## 10. Paper-ready Wording

Chinese:

```text
在所研究的四相数字 IQCOT 实现中，现有事件域和 derived-Simulink 证据支持将 Ton_diff 写作主要 DC 均流执行量；Lambda_diff 更适合写作相位间隔、事件节奏与纹波抵消附近的微调执行量；delay_diff 更适合作为检测时序扰动和数字预算项，而不是主要控制动作。
```

English:

```text
For the studied four-phase digital IQCOT implementation, the available event-domain and derived-Simulink evidence supports interpreting Ton_diff as the primary DC current-sharing actuator, while Lambda_diff mainly affects phase spacing and event rhythm. The delay-related channel is better treated as a jitter disturbance and digital implementation budget term rather than a primary supervisory action.
```

## 11. Forbidden Wording

- Lambda_diff is the main current-sharing actuator.
- Ton_diff solves all transient problems.
- delay_diff should be actively controlled by AI as a main action.
- AI directly controls per-cycle Ton_i.
- The actuator separation is proven for all COT/IQCOT converters.
- Hardware has validated the actuator matrix.

## 12. Recommended Next Minimal Task

Recommended next task:

```text
R052_DIGITAL_JITTER_BUDGET_CONSOLIDATION
```

Why:

R051 found enough evidence to support the actuator-separation safe wording. The next smallest useful step is to consolidate the digital budget pillar: area quantization, detection clock, Ton resolution, comparator/supervisor delay, event jitter, phase-spacing jitter, and current-sharing quantization. No full matrix is needed before that consolidation.
