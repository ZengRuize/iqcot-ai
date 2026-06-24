# Research Wiki Query Pack

_Manually refreshed after R035 because the helper hit mixed-encoding wiki files._

## Project Direction

四相数字 IQCOT Buck / VRM 的 PIS-IEK 事件域小信号模型。核心目标是把面积触发、相位索引、积分 reset、skip/reentry、参考斜率 `T_slew` 与 FPGA 微秒级 AI 参数提交延迟统一到事件坐标中，用于监督层参数调度；AI 不替代 IQCOT 内环，不直接输出 gate command。

## Current Safe Claims

- PIS-IEK 的创新在于把四相 `phase_idx/reset`、`Lambda_i/Ton_i` 执行量、skip/reentry 模式和 `u_{k-d}` AI 延迟写入 event-to-event 小信号/混合事件框架。
- `T_slew` 是 objective-sensitive scheduling variable，不存在当前证据可支持的全局最优常数。
- `q_phi/r_hat/B_epsilon^sw` 是目前最稳妥的 AI 监督层接口：候选生成、短时风险预测、安全投影、dense fallback。
- 派生 Simulink、event-domain surrogate、table-in-loop 和后处理均不是硬件验证；PIS-IEK 不声称精确预测大切载第一峰。

## Latest Evidence Chain

- R030 dense-anchor challenge：30 行派生 Simulink 成对回放显示 proxy 未稳定优于 dense-anchor；dense-anchor mean switching regret `0.186`，proxy `0.574`；`20A/score_settle005` 的 `66us` 是负样本。
- R031 minimal held-out：22 行派生验证表明 intermediate candidates 在 `3/9` 上下文优于 dense、`8/9` 优于原 proxy；结论是 delay-aware local band with dense fallback。
- R032：把 R031 整理为 `q_phi/r_hat/B_epsilon^sw` 接口；known-context replay 不是泛化证明，nearest-tau LOTO mean regret `0.589` 说明不能只靠延迟近邻插值。
- R033：31 行派生边界验证修正规则：`10A/score_settle010` 是 `30-34us` near-tie band；`20A/base` 的 `86us` 只是 objective-dependent probe；`20A/score_settle005` 有 `50us` transition pocket，`66us` 继续 blocked。
- R034 full：20 行 transition-pocket 细扫完成。过渡候选集内最佳序列为 `38/46/50/54/46us` for `tau_AI=1.0/1.25/1.5/1.75/2.0us`，说明固定 `50us` 口袋和单调 ridge 都不成立。
- R035：审稿式收束显示 R034 序列是 transition-candidate best，不是完整 deployable commit。`tau_AI=2us` 下 R034 transition probe 为 `46us`，但 R031 dense-inclusive 证据使 plant commit 回到 `30us` fallback；`1.25/1.75us` 暂列 candidate-only pending dense-paired validation。

## Current Rules

- `10A / score_settle010`: `30-34us` near-tie candidate band；dense `30us` 仍可接受，非 dense 需低 skip/phase risk。
- `20A / base`: `80us` plant fallback；`82/84/86us` 只作为 ranking probes，`86us` 不做通用 commit。
- `20A / score_settle005`: folded probes `38/46/50/54/46us` over `tau=1.0-2.0us`，但最终提交必须通过 dense-inclusive `B_epsilon^sw`；`66us` direct override blocked。

## Key Files

- `output/iqcot_integrated_research_paper.md`
- `output/iqcot_claims_evidence_matrix.md`
- `output/iqcot_pis_iek_derivation_package.md`
- `output/iqcot_ai_supervisor_validation_design.md`
- `output/iqcot_r035_folded_band_projection_report.md`
- `output/iqcot_r035_folded_band_policy_surface.csv`
- `output/iqcot_r035_reviewer_claim_audit.csv`
- `output/figures/fig48_r035_folded_band_projection.svg`
- `refine-logs/LOCAL_AUDIT_R035_FOLDED_BAND_PROJECTION_20260621.md`

## Next Work

1. 若继续仿真，优先做 dense-paired boundary validation：在 `tau_AI=1.25/1.75us` 补 `30us` fallback 对照，确认 folded probes 是否能超过 dense fallback。
2. 将 `r_hat` 从规则表升级为短时 predictor：输入 recent event/phase/skip state，输出 skip/settling/phase risk。
3. 继续保持 claim 边界：不写硬件验证、不写全局最优、不写 AI 替代内环。
<!-- R036_DENSE_PAIR_BOUNDARY -->

## R036 Latest Update

R036完成`20A/score_settle005`在`tau_AI=1.25/1.75us`的dense-paired边界验证。
新增两行`30us` fallback派生Simulink均成功；与R034 folded probes合并后，
`46us`在`1.25us`、`54us`在`1.75us`均优于`30us` fallback，fallback两行都出现
`skip_count=1`。结论只能写成局部dense-paired候选升级，不是硬件验证或全局最优；
`66us`继续blocked，`tau_AI=2us`仍保持`30us` fallback。
<!-- R037_SHORT_HORIZON_RHAT -->

## R037 Latest Update

**Final R037 sync.** R037 completed a short-horizon `r_hat` risk-prediction
interface prototype for the local `20A/score_settle005` evidence.  It merges
R031/R033/R034/R036 derived-Simulink rows into
`iqcot_r037_rhat_training_dataset.csv`, leave-one-delay risk evaluation,
`B_epsilon^sw` projection rules, and a 9-row minimal extrapolation validation
plan.

Current replay metrics: dense fallback mean regret `1.116`, folded `q_phi`
prior `0.020`, final R037 representative projection `0.000`, posterior safe
upper-bound with the same risk gate `0.054`; the risk gate rejects the observed
oracle in `1` context.  The `0.000` result is only known local evidence
consistency after applying the dense-inclusive foldback guard at `tau_AI≈2us`.
It is not hardware validation, global `T_slew` optimality, or proof of a neural
network AI-in-loop controller.
<!-- R038_MINIMAL_EXTRAPOLATION_DRYRUN -->

## R038 Prepared Next Step

R038 has an executable dry-run path for the R037 minimal extrapolation matrix:
`output/iqcot_r037_minimal_extrapolation_validation.m` calls the common R027
runner with `planMode="r037_minimal_extrapolation"`.  The dry run loaded `9`
rows and generated
`output/iqcot_r027_proxy_table_in_loop_matlab_plan_r037_minimal_extrapolation.csv`.
It did not execute switching Simulink.  The next useful action is to run the
9 derived-model cases, preferably in 3-row chunks: `(1-3)`, `(4-6)`, `(7-9)`.
<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

## R038 Latest Update

R038 completed all `9` derived-Simulink delayed-reference minimal extrapolation
cases.  Outputs include `output/iqcot_r038_minimal_extrapolation_report.md`,
`output/iqcot_r038_minimal_extrapolation_context_summary.csv`,
`output/iqcot_r038_foldback_rule_update.csv`, and
`output/figures/fig51_r038_minimal_extrapolation.svg`.

Key result: `46us@1.25us`, `50us@1.5us`, and `54us@1.75us` remain the local
anchors.  At `tau_AI=2us`, `48us` beats the previous dense `30us` fallback by
only about `0.020` score, while `44us` is near-tied.  Write this as a local
`30/44/48us` foldback near-tie band with dense fallback retained; do not claim a
new global optimum or hardware validation.

R037完成短时`r_hat`风险预测接口原型：合并R031/R033/R034/R036的`20A/score_settle005`
派生行，生成`iqcot_r037_rhat_training_dataset.csv`、leave-one-delay风险评估、
`B_epsilon^sw`投影规则和9行最小外推验证计划。结论边界保持：这是后处理和下一轮验证设计，
不是硬件验证、全局最优或神经网络AI-in-loop证明。

<!-- R039_PR_ECB_LARGE_SIGNAL -->

## R039 Latest Update

R039 starts the large-signal PR-ECB branch. It added output/iqcot_r039_pr_ecb_large_signal_probe.m and ran 5/5 derived-Simulink delayed-reference first-peak exports for the 40A->20A score_settle005 cases. The results are invariant across 46/50/54/30/48us delayed T_slew candidates because the first peak occurs at about 0.534us after the load step, before tau_AI>=1.25us reference actions affect the plant. Current PR-ECB estimates: energy boundary 4.350 mV, charge+ESR boundary 3.903 mV, actual derived-Simulink first peak 2.235 mV, r_E=0.435 with a 10 mV allowance.

Next useful action: R040 should vary load-step phase and load-drop magnitude to calibrate PR-ECB conservatism. Keep the claim boundary: PR-ECB is a first-peak risk feature and safety bound, not hardware validation and not a replacement for PIS-IEK/r_hat/B_epsilon post-peak recovery logic.

<!-- R040_PR_ECB_PHASE_LOAD_CALIBRATION -->

## R040 Latest Update

R040 added output/iqcot_r040_pr_ecb_phase_load_calibration.m and output/iqcot_r040_pr_ecb_postprocess.py. The full R040 matrix completed 8/8 derived-Simulink cases: four 40A->20A load-step phase offsets, two 40A->10A offsets, and two 40A->near0 offsets. For 20A, r_E changes from 0.409 to 0.565 as load_step_offset_us moves from 0 to 0.375us. For 10A, r_E spans 0.587-0.678. For near0, r_E spans 0.858-0.993 and charge+ESR is dominant. The near0 offset-0 case shows energy-only can under-estimate actual peak, so R040 supports keeping max(energy, charge+ESR) and testing an E_HS,rem remaining-on-time correction. This supports phase/load-sensitive PR-ECB calibration, but it is still derived-Simulink/offline evidence only.

Next useful action: R041 should add and test a remaining high-side on-time correction E_HS,rem, then compare energy-only, charge+ESR, max-bound, and corrected-energy variants on the 8 R040 rows. Keep claim boundary: no hardware/HIL validation, no global T_slew optimum, and no replacement of PIS-IEK/r_hat/B_epsilon post-peak recovery logic.

<!-- R041_PR_ECB_HSREM_CORRECTION -->

## R041 Latest Update

R041 added `output/iqcot_r041_pr_ecb_hsrem_correction.py` and reprocessed the completed 8-row R040 matrix without rerunning or modifying any `.slx` model. It inferred `L=0.2 uH` and `Cout=7.26 mF` from the R040 energy equations, then applied `E_HS,rem` only to rows where a phase was still high-side-on at the load step. Nonzero correction appears only in the three offset-0 rows, all with phase 4 carrying about `102 ns` remaining high-side on-time.

Key result: the correction fixes the only energy-only under-estimation, `r040_near0_off0p000`, where energy/actual changes from `0.876x` to corrected-energy/actual `1.169x`. However, the original `max(energy, charge+ESR)` bound was already conservative for all eight rows because charge+ESR covered near0. Directly adding `E_HS,rem` to the max-bound increases conservatism for active-HS 20A and 10A rows, so R041 supports treating remaining on-time as a phase-state feature for segmented PR-ECB calibration, not as a globally validated additive law.

Next useful action: R042 should design a small phase-dense validation around high-side-on boundaries, especially offsets just before/after phase-4 turn-off and additional near0/5A/10A cut-load points. The goal is to separate charge+ESR dominance from corrected-energy dominance and fit segmented PR-ECB calibration rules with explicit claim boundaries.

<!-- R042_PR_ECB_PHASE_DENSE_PARTIAL -->

## R042 Latest Update

R042 added `output/iqcot_r042_pr_ecb_phase_dense_calibration.m` and `output/iqcot_r042_pr_ecb_phase_dense_postprocess.py`. The dry-run generated `output/iqcot_r042_pr_ecb_phase_dense_plan.csv` with 20 cases: `near0/5A/10A/20A` crossed with offsets `0.05/0.09/0.105/0.125/0.20 us`.

Completed true-run chunks: rows `1-4` for near0 and rows `6-9` for 5A. Both targets localize phase-4 turn-off between `0.09 us` and `0.105 us`: remaining high-side on-time is `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` at `0.105/0.125 us`. `E_HS,rem` decays from about `7.885 uJ` to `1.961 uJ` before vanishing.

Current partial result: near0 `r_E(max corrected)` spans `0.952-0.983`; 5A spans `0.812-0.839`. charge+ESR remains dominant for all completed near0/5A rows, so `E_HS,rem` is currently best treated as a phase-state segmentation/diagnostic feature rather than a globally additive correction law.

Next useful action: continue R042 with 10A rows `11-14` and 20A rows `16-19`, then rerun `output/iqcot_r042_pr_ecb_phase_dense_postprocess.py`. Rows `5/10/15/20` at `0.20 us` can be run afterward as lower-priority post-turnoff references.

## R042 Full-Matrix Update

R042 completed all `20/20` derived-Simulink phase-dense rows. The phase-4 high-side remaining-on-time boundary is consistent across near0/5A/10A/20A: `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` from `0.105 us` onward. `E_HS,rem` appears in `8/20` rows and decays from about `7.885 uJ` to `1.961 uJ` before vanishing.

Final load-segmented result: near0 `r_E(max corrected)` spans `0.895-0.983`, 5A spans `0.760-0.839`, 10A spans `0.619-0.705`, and 20A spans `0.516-0.602`. charge+ESR remains dominant for near0/5A, while corrected-energy/raw energy dominates most 10A/20A rows. This supports segmented PR-ECB calibration using active-HS phase state and load magnitude, not a global additive `E_HS,rem` law.

Next useful action: R043 should fit and document a segmented PR-ECB calibration surface from R040/R041/R042, including a compact rule table for dominant-bound selection and conservative ratio bands. Keep all claims limited to derived-Simulink/offline evidence.

<!-- R043_PR_ECB_SEGMENTED_CALIBRATION -->

## R043 Latest Update

R043 completed an offline segmented PR-ECB calibration surface from the R041-corrected R040 rows and the full R042 phase-dense matrix. It generated `output/iqcot_r043_pr_ecb_segmented_rows.csv`, `output/iqcot_r043_pr_ecb_segmented_rules.csv`, `output/iqcot_r043_pr_ecb_segmented_report.md`, and `output/iqcot_r043_pr_ecb_segmented_paper_section.md`. No new Simulink cases were run and no original `.slx` model was modified.

Rule summary: near0/5A-like large cut-loads are charge+ESR dominated with r_E about `0.760-0.993` and conservative bound/actual bands around `1.50-1.75x`; 10A-like transition rows use corrected energy when active-HS is present and raw energy after turn-off, with r_E `0.587-0.729` and bands `1.70-1.90x`; 20A-like smaller cut-loads use energy/corrected-energy, with r_E `0.409-0.626` and higher conservatism bands `1.80-2.90x`.

Current claim boundary: `E_HS,rem` is an active-HS segmentation feature, not a globally validated additive law. PR-ECB is a first-peak risk feature/safety boundary from derived-Simulink offline evidence only; it is not hardware/HIL validation, not a global calibration proof, and not a replacement for PIS-IEK/r_hat/B_epsilon post-peak recovery logic.

Next useful action: R044 can convert the R043 segmented rules into a compact paper figure/table and, if needed, design a small hold-out calibration check around new load-drop magnitudes. Keep all claims bounded to derived-Simulink/offline evidence until hardware/HIL data exists.

<!-- R046_DIRECTION_REVISION_AFTER_USER_FEEDBACK -->

## R046 Direction Revision

User feedback on 2026-06-24 corrected the project direction. The external
load-current transition rate is not controlled by the VRM, so `T_slew` must not
remain the main control variable. Existing `T_slew` and AI-delay work should be
kept as historical/future-extension evidence, but the active research line is
now:

`PR-ECB cut-load voltage stabilization + PIS-IEK steady-state current sharing + variable-phase add/shed hybrid event management`.

Main implications:

- PR-ECB should move from offline first-peak risk calibration toward derived
  cut-load protection actions: Ton truncation, pulse inhibit, integrator
  hold/reset, skip hold, and controlled reentry.
- PIS-IEK should move from model validation toward steady-state current-sharing
  control: `Ton_diff` as the main DC current-sharing actuator and
  `Lambda_diff` as phase-spacing/ripple-cancellation trim.
- Phase add/shed should be introduced as a variable active phase set
  `A subset {1,2,3,4}` with hysteresis, dwell time, and shedding disabled during
  cut-load protection.
- Current validation should ignore AI delay unless a later stage explicitly
  reintroduces supervisory scheduling. The next comparison matrix should be:
  original IQCOT, empirical no-model control, PIS-IEK-only, PR-ECB-only, and
  PR-ECB+PIS-IEK coordinated control.

New direction files:

- `docs/research_direction_after_user_feedback_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`

Next useful action: specify the derived control state machine and model-wiring
table before running any new Simulink cases. Do not edit original `.slx` files
or rerun R042/R043 post-processing unless an audit finds a concrete issue.

<!-- R047_AI_READY_MODEL_INNOVATION -->

## R047 AI-Ready Model Innovation

R047 continues the corrected direction by turning the large/small-signal
framework into an AI-control-oriented model interface, named GAE-IQCOT
(`Guarded AI-ready Event model for IQCOT`). The point is not to make AI the
inner-loop controller. The point is to expose compact event features, risk
scores, feasible action sets, and projection guards that an AI/table/MPC
supervisor can use safely.

Core structure:

- PR-ECB provides a normalized large-signal first-peak risk coordinate
  `r_p = DeltaV_bound / DeltaV_allow` and selects protection action classes.
- PIS-IEK provides the small-signal balance/reentry map: `Ton_diff` for DC
  current sharing and `Lambda_diff` for phase-spacing/ripple-cancellation trim.
- Active phase set `A subset {1,2,3,4}` extends PIS-IEK to `1/2/4` phase
  add/shed hybrid events.
- AI proposes only low-dimensional tokens: protection token `a_P`, balance
  token `a_S`, and phase-management token `a_N`.
- The applied action is `a_safe = Project_G(a_AI)`, not raw AI output.

New documents:

- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md`
- `refine-logs/LOCAL_AUDIT_R047_AI_READY_MODEL_INNOVATION_20260624.md`

Next useful action: inspect the derived `.slx` model blocks and signal names,
then build a derived copy through MATLAB APIs if needed. Do not edit raw `.slx`
XML, and do not run the PR-ECB/PIS-IEK/phase-shed ablations until the wiring
table is confirmed.

<!-- R047B_ADAPTIVE_VALIDATION_AUTOMATION -->

## R047B Adaptive Validation Automation

User instruction on 2026-06-24: adjust automation and remember to modify the
model innovation in real time during validation. The project automation is now
an adaptive loop:

`validate -> diagnose -> revise model innovation -> revise next validation`.

Each validation chunk must end with one decision:

- `MODEL_CONFIRMED`
- `MODEL_REVISED`
- `IMPLEMENTATION_ISSUE`
- `CLAIM_DOWNGRADED`

If a chunk contradicts the current GAE-IQCOT/PR-ECB/PIS-IEK/active-phase
assumption, automation must update the model innovation document and evidence
matrix before expanding the simulation grid. New document:
`docs/adaptive_validation_automation_20260624.md`.

Next useful action remains model wiring inspection first; after that, run only
the smallest PR-ECB validation chunk and apply the adaptive decision gate.

<!-- R048_MODEL_WIRING_AUDIT -->

## R048 Latest Update

R048 completed the read-only preflight wiring audit for
`output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` and wrote
`docs/model_wiring_audit_after_r047.md` plus
`refine-logs/LOCAL_AUDIT_R048_MODEL_WIRING_20260624.md`.  No switching matrix
was run, no original `.slx` file was modified, and no raw `.slx` XML was edited.

Decision: `MODEL_CONFIRMED`.

Key wiring facts: active `REQ` is `IEK_PerPhase_Request -> Goto14(tag=REQ)`;
the original Relay is `commented=through`; `PhaseScheduler_4Phase` exposes
`phase_idx`; `IQCOT_Ton_Adapter` sends `Ton_iqcot1..4` into the four COT cells;
`IL_Measurement1..4`, `Voltage Measurement`, and `GateDriver_1Phase1..4` are
the current `il1..4`, `vout`, and `qh1..4` logging tap points.  MOSFET `Ron`,
`L/DCR`, `Cout/ESR`, `Ton`, `Tblank`, `Toff_min`, and `Tdead` are variable
references rather than hard-coded literals.

Implementation notes: standalone model load does not populate required base
variables, and saved line logging count is zero; existing runners inject
variables and mark `vout/qh1..4/il1..4` at run time.  Before the next PR-ECB
chunk, build or modify only a derived copy through MATLAB APIs and add explicit
logging for `REQ`, `phase_idx`, `QL1..4`, `Ton_done_i` or measured high-side
pulse width, and future `protect_state`.
