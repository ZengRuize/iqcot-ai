# 四相 IQCOT / PIS-IEK AI 监督层验证设计

## 1. 目标

本设计用于把当前已经完成的两类证据连接起来：

- 开关级 Simulink 参考斜率 sweep 证明 `T_slew` 是切载瞬态中的目标敏感调度变量；
- 事件域 AI 延迟 surrogate 证明 FPGA 微秒级延迟应写成 `u_{k-d}`，否则会出现训练-部署失配。

下一阶段不应让 AI 直接输出开关门极，也不应替代 IQCOT 内环。AI 的角色限定为低速监督层：根据切载幅度、目标权重、相位/均流状态和 FPGA 延迟预算，选择 `T_slew` 或其他低维参数轨迹。

## 2. 控制层级

```text
Fast inner loop:
  Vout / area event -> IQCOT comparator -> phase scheduler -> COT cells -> gates

Slow supervisory layer:
  z_k = [load-drop estimate, objective weights, phase-spacing state,
         skip/reentry flag, current-sharing state, tau_AI budget]
       -> AI / table / constrained optimizer
       -> T_slew, optional Lambda_diff/Ton_diff limits
       -> held and committed through delay-aware buffer
```

其中 IQCOT 内环仍完成亚微秒级事件触发；AI 监督层只更新可解释参数，不直接生成 gate command。

## 3. 训练目标表

已生成 `E:/Desktop/codex/output/iqcot_ai_supervisor_training_targets.csv`。该表由开关级 Simulink dense+long sweep 后处理得到：

| 目标权重 | 训练标签 |
|---:|---|
| `alpha=0` | `40A->20A/10A/near-0A = 80/80/60 us` |
| `alpha=0.05` | `40A->20A/10A/near-0A = 30/50/60 us` |
| `alpha=0.10` | `40A->20A/10A/near-0A = 30/30/30 us` |

表中同时加入 `tau_AI` 与 `delay_events=ceil(tau_AI/0.5us)`，这是为了让训练数据和事件域延迟模型使用同一坐标系。需要注意：`tau_AI` 目前是部署上下文特征，不是 Simulink sweep 的独立延迟维度；真实延迟闭环仍需后续验证。

## 4. 推荐验证矩阵

下一阶段优先使用 `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` 派生副本，不修改原始模型。

| 验证组 | 目的 | 工况 |
|---|---|---|
| V1 固定斜率基线 | 复现当前策略评估 | 固定 `30/40/60/80 us`，三种切载 |
| V2 表驱动监督层 | 验证训练标签可部署 | `alpha=0/0.05/0.10`，按表选择 `T_slew` |
| V3 延迟提交 | 验证 FPGA 延迟影响 | `tau_AI=0.5/1/2/5 us`，提交延迟为 `ceil(tau_AI/T_event)` |
| V4 安全投影 | 检查保守策略价值 | 对 `T_slew` 变化率、skip/reentry、phase std 设置约束 |
| V5 目标敏感性 | 防止过度声称 | 比较 undershoot、settling、phase std、final error 的 Pareto trade-off |

## 5. Simulink 接入方式

在派生模型中，AI 监督层不需要先实现神经网络。第一版可以用表驱动逻辑替代：

```text
load_drop_est, alpha, tau_AI
  -> lookup table / MATLAB Function
  -> selected T_slew
  -> transport-delay or event-index delay buffer
  -> From Workspace reference profile
  -> existing Iph reference inputs
```

这样能先回答最关键的问题：延迟感知的参数调度是否在开关级波形中保留 surrogate 的排序趋势。若表驱动版本不能稳定改善，再训练复杂 AI 没有意义。

## 6. 评价指标

每个工况至少记录：

- `undershoot_mV`
- `final_vout_error_mV`
- `settle_time_us`
- `skip_count_est`
- `final_phase_spacing_std_ns`
- per-phase current imbalance
- objective score：`|final error| + undershoot + 0.02*phase_std + 2*skip + alpha*settle_time`

论文中必须同时报告 base score 和 settling-aware score，不能只挑选有利指标。

## 7. 论文可写结论边界

允许写：

- “PIS-IEK 将 FPGA 微秒级 AI 延迟写成事件域滞后，使训练与部署坐标一致。”
- “参考斜率是目标敏感调度变量，适合作为 AI 监督层动作。”
- “表驱动或 AI 监督层的第一验证目标，是逼近 oracle scheduler 并满足安全边界。”

禁止写：

- “AI 替代 IQCOT 内环。”
- “`30/50/60/80 us` 中任一斜率是全局最优。”
- “事件域 surrogate 已经证明硬件性能提升。”
- “PIS-IEK 单独精确预测大切载第一峰。”

## 8. 已完成的首轮表驱动验证

已使用 `E:/Desktop/codex/output/iqcot_table_supervisor_ref_slew_validation.m` 在派生模型
`E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` 中完成
`tau_AI=0.5/1/2/5 us` 的等效参数提交延迟验证。正延迟实验覆盖 `3` 个切载目标、
`5` 个策略和 `4` 个延迟上下文，共 `60` 个开关级工况。固定斜率被视为预提交基线，
表驱动策略的 `Iph_ref_ts` 从 `t_load_step+tau_AI` 开始过渡。

`tau_AI=5 us` 策略汇总如下：

| 策略 | mean base | mean score 0.05 | mean score 0.10 | mean undershoot | mean settling |
|---|---:|---:|---:|---:|---:|
| fixed `40 us` | `9.856` | `10.528` | `11.199` | `5.702 mV` | `13.431 us` |
| fixed `80 us` | `9.435` | `11.043` | `12.651` | `5.292 mV` | `32.169 us` |
| base-score table | `8.960` | `10.598` | `12.237` | `4.912 mV` | `32.770 us` |
| `alpha=0.05` table | `8.383` | `9.657` | `10.931` | `4.925 mV` | `25.477 us` |
| `alpha=0.10` table | `9.079` | `9.932` | `10.785` | `4.925 mV` | `17.065 us` |

合并 `0/0.5/1/2/5 us` 后，best-by-tau 结果为：

| `tau_AI` | best base | best 0.05 | best 0.10 |
|---:|---|---|---|
| `0 us` | base-score table | `alpha=0.05` table | `alpha=0.10` table |
| `0.5 us` | base-score table | `alpha=0.10` table | `alpha=0.10` table |
| `1 us` | base-score table | `alpha=0.10` table | `alpha=0.10` table |
| `2 us` | `alpha=0.05` table | `alpha=0.05` table | `alpha=0.05` table |
| `5 us` | `alpha=0.05` table | `alpha=0.05` table | `alpha=0.10` table |

该结果支持表驱动监督层作为下一步 AI 训练前的低风险验证接口，但也说明排序并非简单随延迟单调变化。下一步应接入真实 AI/回归器策略，并研究连续 `T_slew` 动作与安全投影。

## 9. 已完成的可解释 score 回归器前置验证

已使用 `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_baseline.py` 将上述 `60` 个正延迟开关级 delayed-reference 工况展开为 `180` 行候选策略打分样本和 `36` 个监督上下文标签。该验证不运行新的 `.slx`，只回答一个前置问题：监督层能否根据 `[load_drop_norm, objective_alpha_settle, tau_AI, delay_events]` 近似选择已有候选策略。

交叉验证结果如下：

| split | best model | mean regret | 关键解释 |
|---|---|---:|---|
| leave-one-tau-out | `trained_objective_nearest_tau_table` | `0.304` | 比固定 `40 us` 低约 `73.2%`，但仅比零延迟目标表低 `0.013` |
| leave-one-target-out | `zero_delay_objective_table` | `0.316` | 强查表基线仍最佳；ridge score supervisor 为 `0.620`，优于固定斜率但未超过查表 |

该结果把 AI 研究推进到 score-prediction supervisor 接口，但结论必须克制：当前只能说“可解释监督层可近似 delayed-reference 策略排序，并显著优于固定斜率基线”；不能说“AI/回归器已经稳定优于查表”，也不能说“已经完成神经网络 AI-in-loop 开关级验证”。后续更有价值的实验是扩大 `T_slew` 网格、训练连续动作回归器，并将预测动作通过同样的参数提交延迟通道接入派生 Simulink 模型。

## 10. 已完成的连续 `T_slew` 景观前置分析

已使用 `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape.py` 对 dense+long sweep 做局部二次插值和 `1 us` 网格重采样。该步骤不运行新的 `.slx`，只用于判断连续动作是否值得进一步仿真。

主要结果：

| 类别 | 数值 |
|---|---:|
| target/objective 组合 | `9` |
| 插值网格行数 | `909` |
| 最大局部二次估计收益 | `0.239` |
| 离散网格足够 | `4` 个组合 |
| 建议小范围细扫 | `2` 个组合 |
| 需新开关级确认 | `3` 个组合 |

优先细扫候选：

- `20A` 的 `score+0.05T_settle` 和 `score+0.10T_settle`：约 `34.744 us`。
- `near-0A` 的 `score+0.10T_settle`：约 `34.633 us`。
- `20A` base 与 near-0A base 可作为次优先细扫，候选约 `87.244 us` 和 `65.710 us`，但收益更小。

已执行的下一轮派生 Simulink 验证矩阵：

| 目标 | 细扫区间 | 建议点 |
|---|---|---|
| `20A`, `alpha=0.05/0.10` | `30-40 us` | `32/34/35/36/38 us` |
| `near-0A`, `alpha=0.10` | `30-40 us` | `32/34/35/36/38 us` |
| `20A`, base | `80-95 us` | `84/86/88/90/92 us` |
| `near-0A`, base | `60-75 us` | `62/64/66/68/70 us` |

这些点在 R024 中已通过 `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_sweep.m` 执行，共 `45` 个派生 Simulink 工况，结果写入 `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv`。

## 11. 已完成的 R024 局部细扫验证

R024 的结果不支持“34-35us 插值候选本身就是最优点”的强说法。更准确的结论是：局部细扫支持连续或更细 `T_slew` 网格有小幅价值，但实际较优点受 skip/reentry 离散模式和相位指标影响。

关键结果：

| 目标 | 旧网格 best | R024 局部/细扫结果 | 解释 |
|---|---:|---:|---|
| `20A`, `score+0.05T_settle` | `30 us`, score `2.493` | `38 us` score `2.417`; 全细扫 `66 us` score `2.398` | `35 us` 最近候选因 `skip_count=1` 变差，说明景观非光滑 |
| `20A`, `score+0.10T_settle` | `30 us`, score `2.540` | `38 us` score `2.464`; 全细扫 `66 us` score `2.445` | 小幅改善，但不是全局最优证明 |
| `near-0A`, `score+0.10T_settle` | `30 us`, score `19.784` | `38 us` score `19.549` | 支持 `34-40 us` 区域继续验证和安全投影 |
| `20A`, base | `80 us`, score `2.273` | `86 us` score `2.133` | 次优先区域细扫有小幅收益 |
| `near-0A`, base | `60 us`, score `16.801` | 全细扫 `92 us` score `16.581` | 长斜率可能降低 base score，但恢复时间代价仍需报告 |

下一步 AI/table-in-loop 设计应把连续动作写成：

```text
T_slew^plant = clip(pi_phi(z), B_epsilon(z, m_k, tau_AI))
```

其中 `m_k` 至少要包含 normal/skip/reentry 相关特征或代理指标，例如 `skip_count_est`、相位间隔标准差、恢复时间权重和参数提交延迟。R024 不是神经网络 AI-in-loop，也不是硬件验证；它的作用是把连续动作 AI 的目标从“找一个最优点”修正为“在模式感知安全区间内调度”。

## 12. 已完成的 R025 mode-aware score surrogate 后处理

R025 使用 dense+long+fine 已完成结果，不新增 `.slx` 仿真，将 `69` 个 plant-level 目标/斜率组合展开为 `207` 行 objective-level 样本。每行包含：

```text
[target_load_A, load_drop_norm, alpha_settle, T_slew,
 skip_count_est, phase_spacing_std_ns, settle_time_us]
 -> objective_score
```

比较两个解释性模型：

| 模型 | 特征 | in-sample RMSE | leave-one-target RMSE | 解释 |
|---|---|---:|---:|---|
| `smooth_quadratic_context` | `target, alpha, T_slew` | `0.855` | `10.192` | 忽略模式跳变，暴露裸连续拟合风险 |
| `mode_aware_score_surrogate` | `target, alpha, T_slew, skip, phase, settle` | `0.101` | `5.940` | 更能解释当前数据，但 mode 特征部署时需预测 |

策略后处理结果：

| 策略 | mean regret | max regret | 说明 |
|---|---:|---:|---|
| `combined_grid_oracle` | `0.000` | `0.000` | 当前已仿真网格下界，不可部署 |
| `mode_aware_safety_projection` | `0.064` | `0.235` | `best+0.50` 带内加入 skip/phase/settle 约束 |
| `near_opt_band_clipping` | `0.101` | `0.209` | 把裸连续候选裁剪到 `best+0.25` 经验近优带 |
| `discrete_dense_long_table` | `0.163` | `0.490` | R024 前强离散表基线 |
| `naked_quadratic_continuous` | `0.654` | `2.429` | 忽略模式变量，容易选到 skip 跳变坏点 |

R025 对下一步 AI/table-in-loop 的设计要求：

1. 不能直接让连续回归器输出裸 `T_slew` 点值，应输出候选 score 或分布，再经 `B_epsilon(z,m_k,tau_AI)` 投影。
2. `skip_count_est`、phase std 和 settle time 在 R025 中是后验指标；真实部署应使用事件状态估计、短时 surrogate 或保守 proxy 预测它们。
3. 下一步若接入神经网络，应先比较 `smooth`、`band-clipped`、`mode-aware clipped` 三类动作提交到派生 Simulink 模型后的排序是否保持。
4. 所有 AI 仍为监督层参数调度，不替代 IQCOT 内环。

## 13. 已完成的 R026 可部署 risk proxy 离线重放

R026 解决 R025 的一个部署性问题：`skip_count_est`、相位间隔标准差和恢复时间在 R025 中是后验评价指标，不能直接作为在线 AI 输入。新的接口把监督层可用信息限定为：

```text
[target_load_A, load_drop_norm, alpha_settle, candidate T_slew, tau_AI, delay_events]
```

模式风险由离线校准表或短时事件预测器给出：

```text
r_hat(z,T_slew) -> [skip-risk, phase-risk, settle-risk]
```

已生成的关键文件：

- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy.py`
- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_report.md`
- `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_table.csv`

离线重放结果：

| 策略 | mean regret | 解释 |
|---|---:|---|
| 后验 mode-aware projection | `0.064` | R025 上界，不可直接部署 |
| 校准 risk proxy projection | `0.119` | 使用离线 `r_hat` 表，当前最佳可部署接口 |
| dense-long table | `0.163` | 强查表基线 |
| 裸平滑连续 | `0.654` | 忽略模式跳变 |
| 纯参数 proxy | `0.857` | 说明 smooth proxy 不足 |

下一步派生 Simulink 验证建议：

1. 使用 `four_phase_iek_dynamic_load_refslew.slx` 派生模型，不修改原始 `.slx`。
2. 固定 `tau_AI = 0/0.5/1/2/5 us`，比较 fixed、dense-long table、calibrated risk proxy projection 和 posterior upper-bound candidate。
3. 不把 posterior upper-bound 写成可部署策略，只用作排序上界。
4. 若排序保持，再把 `r_hat` 表替换为短时事件 predictor 或轻量回归器；若排序不保持，先修正 proxy 安全边界，不急于训练神经网络。

## 14. 已完成的 R027 proxy table-in-loop 优先矩阵验证

R027 将 R026 的 `r_hat(z,T_slew)` 接口转化为可执行的派生 Simulink table-in-loop 验证入口。新增文件包括：

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.py`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_priority_plan.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_combined.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md`

完整离线计划覆盖 `315` 行：`9` 个目标/目标函数上下文、`5` 个 `tau_AI` 设置和 `7` 类策略。优先矩阵保留排序分歧和 proxy regret 较高的 `48` 行。离线预期排序为：posterior mode-aware projection `0.064`、near-opt band `0.101`、calibrated risk proxy `0.119`、dense-long table `0.163`、固定 `40us` `0.434`、裸连续 `0.654`、固定 `80us` `0.949`。其中 posterior 与 near-opt band 不是可部署策略，只能作为上界/离线对照。

现在已分段完成优先矩阵全部 `48` 个派生 Simulink 工况，且全部成功。合并后，dense-long table 与 posterior mode-aware projection 的 mean switching regret 均为 `0.025`，near-opt band 为 `0.257`，calibrated risk proxy 为 `0.283`。proxy 相对 dense-long 在 `0/8` 个压力上下文更优、`4/8` 个上下文并列、`4/8` 个上下文更差；离线最佳策略排序只在 `4/8` 个上下文中保持。

该结果修正了 R026 的离线乐观结论：`r_hat` proxy 可以作为可执行监督层接口进入派生模型，但当前校准方式在压力上下文中没有稳定超过 dense-long table。下一步不应急于训练神经网络，而应先重标定 `B_epsilon(z,r_hat,tau_AI)`，尤其解释 `10A/score_settle005` 下 proxy 选择 `62us` 失败，而 near0A 强恢复时间目标下 `30us` 与 dense-long 并列的原因。所有 R027 结果仍是派生模型开关级证据，不是硬件验证；AI 仍只作为监督层参数调度。

## 15. 已完成的 R028 switching-calibrated proxy 重标定

R028 使用 `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py` 对 R027 已完成的 `48` 行 priority switching 结果做后处理，不运行新的 `.slx`。目标是把 R027 的失败模式转成可部署的安全投影规则，而不是扩大 AI claim。

新增文件包括：

- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy.py`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_eval_priority.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv`
- `E:/Desktop/codex/output/iqcot_r028_context_failure_analysis.csv`
- `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_report.md`
- `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_proxy_paper_section.md`

R028 比较三类关键策略：

| 策略 | mean switching regret | 解释 |
|---|---:|---|
| dense-long table | `0.025` | R027 压力集中的强基线 |
| 旧 calibrated risk proxy | `0.283` | `10A/score_settle005` 选 `62us` 导致失败 |
| `r028_dense_anchor_proxy` | `0.025` | 把 proxy 投影回 dense-long 邻域，修复已知失败 |
| `r028_switching_guarded_proxy` | `0.000` | 由 R027 压力点校准出的下一轮候选，不是泛化证明 |

保守部署规则可写成：

```text
T_slew^anchor =
  T_slew^proxy,  if |T_slew^proxy - T_dense| <= epsilon(z,tau_AI)
  T_dense,       otherwise.
```

对于已知失败的 `10A/score_settle005`，R028 将 `epsilon` 收紧，使旧 proxy 的 `62us` 回退到 dense-long 的 `50us`。这说明 `B_epsilon(z,r_hat,tau_AI)` 应该被开关级压力样本校准，而不是只依赖离线 surrogate 排序。

`r028_switching_guarded_proxy` 还加入两个压力拟合 guard：`10A/score_settle005/tau_AI>=2us` 选择 `34us`，`near0A/score_settle010/tau_AI=0` 选择 `35us`。该策略在当前 8 个压力上下文上为零 regret，但因为它正是从这些上下文拟合出来的，下一步必须做 held-out 派生 Simulink 验证。

建议 R029 held-out 验证矩阵：

| 验证目的 | 推荐点 |
|---|---|
| 检查 `10A/score_settle005` delay guard 是否过拟合 | `tau_AI=1.5/2.5/3 us`，比较 `34/40/50/62 us` |
| 检查 near0A zero-delay guard 是否稳健 | `tau_AI=0/0.25/0.5 us`，比较 `30/35/38 us` |
| 检查 dense-anchor 是否会错杀 proxy 有效动作 | 从完整 R027 315 行计划中抽取 proxy 与 dense 不同但非 R027 priority 的上下文 |
| 检查 AI 监督层接入 | 先用表驱动 `T_slew` 输出替代神经网络，确认 `t_commit=tau_AI` 通道排序，再换轻量回归器 |

R028 的结论应写成：保守 `dense-anchor` safety projection 能修复 R027 已知压力失败，并把旧 proxy 的 priority mean switching regret 从 `0.283` 降到 `0.025`；guarded 规则是下一轮验证候选。不能写成“AI/proxy 已经开关级泛化优于 dense-long table”。

## 16. 已完成的 R029 held-out guarded-proxy 验证

R029 使用派生 `four_phase_iek_dynamic_load_refslew.slx` 执行了 R028 后提出的 held-out 小矩阵，共 `21` 个工况，全部成功。新增文件包括：

- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_plan.py`
- `E:/Desktop/codex/output/iqcot_r029_guarded_heldout_plan.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_validation.m`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv`
- `E:/Desktop/codex/output/iqcot_r029_heldout_guard_combined_report.md`

验证矩阵：

| 上下文 | `tau_AI` | `T_slew` 候选 | 目的 |
|---|---|---|---|
| `10A / score_settle005` | `1.5/2.5/3us` | `34/40/50/62us` | 检查 R028 的 `tau>=2us -> 34us` guard 是否过拟合 |
| `near0A / score_settle010` | `0/0.25/0.5us` | `30/35/38us` | 检查零延迟 `35us` guard 是否稳健 |

R029 结果：

| 上下文 | 最优结果 | 解释 |
|---|---|---|
| `10A`, `tau=1.5us` | `40us` | `34us` guard 不应外推到 `2us` 以下 |
| `10A`, `tau=2.5us` | `34us` | 支持 `tau>=2us` 短斜率 guard |
| `10A`, `tau=3us` | `34us` | 支持 `tau>=2us` 短斜率 guard |
| `near0A`, `tau=0` | `38us` | R028 固定 `35us` guard 过窄 |
| `near0A`, `tau=0.25us` | `38us` | `38us` 与 `30us` 很接近但略优 |
| `near0A`, `tau=0.5us` | `30us` | 一旦有 0.5us 提交延迟，dense/proxy 30us 恢复为最佳 |

策略族统计中，old `62us` proxy failure probe 的 mean regret 为 `0.806`，说明旧 proxy 在 10A held-out 中仍应被排除。`guarded_candidate` 的 mean regret 为 `0.041`，但它只覆盖有 guarded 行的上下文；不能把它和所有上下文上的完整部署策略直接等同。

R029 更新后的下一步建议：

1. R030 不应使用固定 near0A `35us` guard，而应使用 `30-38us` 局部安全带。
2. 10A settling-aware 场景可保留 `tau_AI>=2us -> 34us` 的短斜率 guard，但 `1.5us` 附近应允许 `40us` 或连续带内选择。
3. 如果训练 AI/回归器，输出不应是单点 `T_slew`，而应是候选 score 或分布，再由 `B_epsilon^sw` 投影到当前安全带。
4. R029 仍是派生 Simulink 证据，不是硬件验证或神经网络 AI-in-loop。

## 17. 已完成的 R030 refined-band policy 合成与挑战计划

R030 使用 `E:/Desktop/codex/output/iqcot_r030_refined_band_policy.py` 对 R027/R028/R029 的已完成结果做后处理，不运行新的 `.slx`。它把 R029 的局部修正转成更适合部署描述的 band policy：

| 上下文 | R030 代表动作 | 解释 |
|---|---:|---|
| `10A / score_settle005`, `tau_AI<=1us` | dense-anchor `50us` | R027 priority replay 中旧 `62us` proxy 失败，dense-anchor 更稳 |
| `10A / score_settle005`, `tau_AI≈1.5us` | `40us` | R029 held-out 显示 `1.5us` 下 `40us` 优于 `34/50/62us` |
| `10A / score_settle005`, `tau_AI>=2us` | `34us` | R027 `2us` 和 R029 `2.5/3us` 支持短斜率边界 |
| `near0A / score_settle010`, `tau_AI<0.5us` | `38us` | R029 `0/0.25us` 显示 `38us` 优于固定 `35us` |
| `near0A / score_settle010`, `tau_AI>=0.5us` | `30us` | R029 `0.5us` 和 R027 `1/2us` 支持回到 lower edge |

R030 的离线 consistency replay 覆盖 `45` 个目标/目标函数/延迟上下文：R030 mean regret 为 `0.104`，R028 guarded candidate 为 `0.106`，R028 dense-anchor 为 `0.099`。该结果只是离线一致性检查；更关键的切换证据合成为：在 R027 priority replay 与 R029 held-out 的 `12` 个已知 guard-context 中，R030 选中行 mean switching regret 为 `0.000`，对应 dense-anchor 为 `0.128`。这仍不是独立泛化证明，因为 R030 由这些局部证据合成。

R030 同时给出派生 Simulink 挑战计划，且该计划已经在后续步骤完成：

- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_candidates.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_validation.m`

计划包含 `30` 行，按 dense/proxy 成对比较以下三个 motif：

| motif | dense | proxy | 离线动机 |
|---|---:|---:|---|
| `10A / score_settle010` | `30us` | `32us` | proxy 离线优势约 `0.490` 分 |
| `20A / base` | `80us` | `86us` | proxy 离线优势约 `0.140` 分 |
| `20A / score_settle005` | `30us` | `66us` | proxy 离线优势约 `0.095` 分，但斜率差很大 |

这些挑战点的目的不是证明 proxy 已经更优，而是检查 R028/R030 的 dense-anchor projection 是否在某些非优先上下文过于保守。已完成的回放仍使用派生 `four_phase_iek_dynamic_load_refslew.slx` 和 delayed-reference 通道，并同时报告 base、`score+0.05T_settle`、`score+0.10T_settle`、欠压、恢复时间、skip 和相位标准差；结果见下一节。

可执行入口：

```matlab
iqcot_r030_dense_anchor_challenge_validation(false)      % dry run
iqcot_r030_dense_anchor_challenge_validation(true)       % run all 30 challenge rows
iqcot_r030_dense_anchor_challenge_validation(true,10,11) % chunked run
```

## 18. R030 dense-anchor challenge 已完成后的验证结论

R030 challenge 已在派生 `four_phase_iek_dynamic_load_refslew.slx` 上完成 `30` 行 dense/proxy 成对 delayed-reference 回放，并由 `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_postprocess.py` 合并后处理。新增产物包括：

- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_motif_summary.csv`
- `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_report.md`
- `E:/Desktop/codex/output/figures/fig40_r030_dense_anchor_challenge.svg`

完整上下文重算结果如下：

| 策略 | cases | mean switching regret | max regret | best contexts | mean settling |
|---|---:|---:|---:|---:|---:|
| dense-anchor / dense-long table | `15` | `0.186` | `1.688` | `8` | `10.096 us` |
| calibrated risk proxy | `15` | `0.574` | `2.793` | `7` | `13.926 us` |

分 motif 的解释为：

| motif | dense | proxy | 结论 |
|---|---:|---:|---|
| `10A / score_settle010` | `30us` | `32us` | 近似局部 near-tie；proxy 胜 `3/5`，dense 胜 `2/5`，平均差仅 `0.009` |
| `20A / base` | `80us` | `86us` | 排序随延迟变化，不能稳定替换 dense-anchor |
| `20A / score_settle005` | `30us` | `66us` | proxy 主要负样本；平均劣化 `1.073`，多个延迟下出现 skip/settling 代价 |

因此下一阶段 AI/table-in-loop 设计应改成：

1. `r_hat(z,T_slew)` 或神经网络只输出候选 score/risk，不直接提交最终 `T_slew`。
2. 最终动作必须经过 `B_epsilon^sw` 投影；`20A/score_settle005` 的 `66us` 应列入负样本，除非短时事件 predictor 能提前识别低 skip/低 settling 风险。
3. 下一轮派生 Simulink 验证应比较 `dense-anchor`、`direct proxy override`、`proxy + tightened B_epsilon^sw` 和 `short-horizon predictor + B_epsilon^sw`，同时报告 base、settling-aware、skip、settling、phase std 和 final error。
4. 这些仍是派生 Simulink 监督层验证，不是神经网络硬件闭环，也不替代 IQCOT 内环。

## 19. R031 tightened `B_epsilon^sw` 与最小 held-out 验证计划

R031 已将 R030 challenge 的负样本转化为 tightened `B_epsilon^sw` 原型。该步骤只做离线后处理，不新增 `.slx` 仿真；输入是 R030 的 `15` 个 dense/proxy 成对上下文，输出包括：

- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_sw.py`
- `E:/Desktop/codex/output/iqcot_r031_pair_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_rules.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_report.md`
- `E:/Desktop/codex/output/figures/fig41_r031_tightened_bepsilon.svg`

校准集策略重放结果如下：

| 策略 | mean regret | max regret | proxy selected | unsafe proxy selected | 解释 |
|---|---:|---:|---:|---:|---|
| pair oracle upper bound | `0.000` | `0.000` | `7` | `1` | 非部署上界，只用于估计 pairwise 最好可能性 |
| R031 tightened projection | `0.132` | `1.688` | `3` | `0` | 校准候选，需 held-out 验证 |
| dense-anchor baseline | `0.186` | `1.688` | `0` | `0` | 当前强基线 |
| small-delta only | `0.189` | `1.688` | `5` | `1` | 简单 `<=2us` 规则不足 |
| direct proxy override | `0.574` | `2.793` | `15` | `5` | 负面对照，不能部署为直接 override |

R031 的三条 tightened rule 是：

| 上下文 | R031 规则 | 下一轮验证 |
|---|---|---|
| `10A / score_settle010` | `30-32us` near-tie band；仅已观测 proxy 胜出的延迟子带保留候选 | `tau=1/5us` 下验证 `31/33us` |
| `20A / base` | 暂阻止 `86us` 直接覆盖 dense-anchor | `tau=0.5/2/5us` 下验证 `82/84us` |
| `20A / score_settle005` | 将 `66us` 作为 large-jump settling-sensitive 负样本排除 | `tau=0.5/1/2/5us` 下验证 `38/50/58us` |

因此，下一轮 AI/table-in-loop 监督层不应直接学习“proxy 输出即提交”。更稳妥的接口是：

```text
score/risk candidate generator:
  q_phi(z_k, T_slew, tau_AI) -> candidate score distribution

short-horizon event risk:
  r_hat(z_k, T_slew, tau_AI, recent_phase_state)
    -> [skip risk, settling risk, phase-spacing risk]

plant command:
  T_slew,plant = Proj_{B_epsilon^sw(z_k, r_hat, tau_AI, T_dense)}(T_slew,candidate)
```

R031 的 `0.132` mean regret 不能写成泛化证明，因为它使用了 R030 challenge 已观测胜负来设置 near-tie 子带。它的价值是把 R030 的负面证据转化为可执行的 `22` 行 held-out 验证矩阵，并明确要求短时 predictor 先证明低 skip/settling 风险，才能重新放行 `20A/score_settle005` 的带外大跳变候选。

## 20. R031 最小验证 runner dry-run

已新增 R031 执行入口：

- `E:/Desktop/codex/output/iqcot_r031_minimal_validation.m`

该 wrapper 复用 `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_validation.m` 的 delayed-reference 仿真框架，并新增 `planMode="r031_minimal"` 适配器，把 `iqcot_r031_minimal_validation_plan.csv` 转换为 R027 runner 所需 schema。它仍只使用派生模型：

```text
E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
```

已执行 dry-run：

```matlab
addpath('E:/Desktop/codex/output');
rows = iqcot_r031_minimal_validation(false);
```

dry-run 生成：

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_dryrun_r031_minimal.md`

核对结果：`22` 行全部成功加载为 delayed-reference 工况，前几行示例为 `10A/score_settle010` 的 `31/33us` 与 `tau_AI=1/5us`，`20A/base` 的 `82us` 与 `tau_AI=0.5us`；`delay_events` 由 `ceil(tau_AI/0.5us)` 得到。该 dry-run 只证明接口和计划转换正确，不是开关级或硬件验证。

推荐分块运行方式：

```matlab
iqcot_r031_minimal_validation(true, 8, 1)
iqcot_r031_minimal_validation(true, 8, 9)
iqcot_r031_minimal_validation(true, 6, 17)
```

运行后应由后处理脚本比较 candidate 与 reference baseline，在相同 `(target_label, objective, tau_AI)` 下重算 base、settling-aware score、skip、settling、phase std 和 final error，并特别检查 R031 tightened projection 是否只是记忆 R030 challenge。

## 21. R031 最小 held-out 派生验证结果

已按 `8/8/6` 分块执行全部 `22` 行 R031 最小验证矩阵：

```matlab
iqcot_r031_minimal_validation(true, 8, 1)
iqcot_r031_minimal_validation(true, 8, 9)
iqcot_r031_minimal_validation(true, 6, 17)
```

新增结果文件：

- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows001_008.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows009_016.csv`
- `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_r031_minimal_rows017_022.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_postprocess.py`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_family_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_report.md`
- `E:/Desktop/codex/output/figures/fig42_r031_minimal_validation.svg`

后处理将 R031 intermediate candidates 与 R030 中对应的 dense baseline、原 proxy 行合并。上下文级结论：

| 指标 | 结果 |
|---|---:|
| R031 best intermediate 优于 dense | `3/9` contexts |
| R031 best intermediate 优于原 proxy | `8/9` contexts |
| best-family counts | dense `6`，R031 intermediate `3` |
| R031-best minus dense 平均值 | `-0.194` |

关键模式：

| 上下文 | 结果 | 含义 |
|---|---|---|
| `10A / score_settle010` | `tau=1us` 时 dense `30us` 最好；`tau=5us` 时 `33us` 最好 | near-tie band 需延迟敏感，不可固定 proxy override |
| `20A / base` | dense `80us` 仍为最好或近似最好；`82/84us` 仅显示中间候选内部延迟分歧 | 不支持直接放行 `86us` proxy |
| `20A / score_settle005` | `50us` 在 `0.5/2us` 较好，`38us` 在 `1us` 较好，`58us` 在 `5us` 较好 | `38-58us` 中间带有价值，但仍不等于 `66us` 可部署 |

R031 最小验证把 `B_epsilon^sw` 从静态规则推进为延迟敏感局部带。下一步若训练短时 predictor，应以 `z_k,T_slew,tau_AI,recent_phase_state` 预测 skip/settling/phase risk，再由投影层选择 `30/33/38/50/58/80/82/84us` 等候选；不能让 AI 直接提交未验证的连续点。
## 22. R032 delay-aware `B_epsilon^sw` 监督层接口

R032 已生成 `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`，把 R031 的最小 held-out 结果转成可执行的候选风险表、投影规则和下一轮验证矩阵。该步骤不运行或修改 `.slx`，其角色是设计监督层接口：

```text
q_phi(z_k, T_slew, tau_AI) -> score/ranking candidate
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate)
```

当前策略重放结果为：R032 fitted band projection 在 R031 已知 9 个上下文上 mean regret `0.000`，dense fallback `0.337`，direct proxy override `1.107`；但该 `0.000` 是校准一致性，不是泛化证明。更应该强调的是 nearest-tau LOTO stress policy 的 mean regret `0.589`，它说明只用 `tau_AI` 近邻插值不足以跨越 skip/reentry 非光滑边界。

下一轮派生 Simulink 验证矩阵为 `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`，共 `31` 行，重点验证 `10A/score_settle010` 的 `30/33us` 转换边界、`20A/base` 的 `80/82/84/86us` 边界，以及 `20A/score_settle005` 的 `38/50/58us` 中间带和 `66us` 负控。所有运行仍只允许使用 `E:/Desktop/codex/output/simulink_iek` 下的派生模型。
## 23. R033 delay-band 派生 Simulink 验证

R033 已完成 `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv` 的全部 `31` 行派生 Simulink delayed-reference 验证，并由 `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_postprocess.py` 合并分析。核心输出包括：

- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_rule_update.csv`
- `E:/Desktop/codex/output/iqcot_r033_delay_band_validation_report.md`

验证结论应写成边界修正：`10A/score_settle010` 是 `30-34 us` near-tie 带，`20A/base` 的 `86 us` 只能作为目标函数相关探针，`20A/score_settle005` 存在 `tau_AI≈1.5 us` 的 `50 us` 过渡口袋，但 `66 us` 仍应作为负控阻断。该实验不等同于硬件验证或神经网络 AI-in-loop。
## 24. R034 short-horizon risk predictor / deployable projection

R034 已生成轻量可部署风险接口与下一轮细扫计划：

- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_predictor.py`
- `E:/Desktop/codex/output/iqcot_r034_deployable_risk_grid.csv`
- `E:/Desktop/codex/output/iqcot_r034_policy_surface.csv`
- `E:/Desktop/codex/output/iqcot_r034_transition_pocket_validation_plan.csv`

当前接口只作为监督层候选生成和安全投影原型。下一轮派生 Simulink 计划共 `20` 行，聚焦 `20A/score_settle005` 的 `tau_AI≈1.5us` 过渡口袋，不代表硬件验证或全局最优证明。
## 25. R034 partial transition-pocket validation

已完成 R034 transition-pocket 计划的核心两块：`tau_AI=1.25us` 与 `1.75us`，
共 `10` 行派生 Simulink delayed-reference 工况。结果修正了固定 `50us`
口袋假设：左侧边界最佳为 `46us`，右侧边界最佳为 `54us`。剩余计划位于
`E:/Desktop/codex/output/iqcot_r034_transition_pocket_remaining_plan.csv`，包含
`10` 行，主要用于验证 `tau_AI=1.0us` 和 `2.0us` 的 ridge 外推。
## 26. R034 full transition-pocket validation

R034 已完成 `20A/score_settle005` 过渡口袋的全部 `20` 行派生 Simulink 验证。最优候选序列为
`1.0us->38us`、`1.25us->46us`、`1.5us->50us`、`1.75us->54us`、`2.0us->46us`。
这应写成 folded transition band，而不是固定 `50us` 口袋或单调 ridge。

## 27. R035 folded-band deployable projection

R035 不新增 `.slx` 仿真，而是把 R031、R033 和 R034 的证据合并为可部署投影规则。新的验证设计要求把 R034 的 folded band 当作 candidate generator，而不是最终 commit policy：

```text
AI/table supervisor -> q_phi candidate band
short-horizon risk predictor -> r_hat(skip, settling, phase)
B_epsilon^sw projection + dense fallback -> plant-side T_slew
```

当前规则表为：

| 上下文 | 候选带 | plant 提交规则 |
|---|---|---|
| `10A / score_settle010` | `30-34us` | dense `30us` 可保留，`32/33us` 只在低风险 near-tie 条件下进入 |
| `20A / base` | `80us` fallback，`82/84/86us` probe | 默认 `80us`，`86us` 只作为目标函数相关探针 |
| `20A / score_settle005` | `38/46/50/54/46us` folded probes | 仅在 dense-inclusive 证据支持时提交；`tau_AI=2us` 回到 `30us` fallback；`66us` 继续 blocked |

因此下一轮若继续仿真，最有价值的不是再证明 `50us` 口袋，而是做 dense-paired boundary validation：围绕 `tau_AI=1.25/1.75us` 补充 `30us` fallback 对照，并测试短时 `r_hat` 是否能在 skip 与 long-settling 出现前正确拒绝候选。所有结论仍限定为派生 Simulink 监督层参数调度，不是神经网络闭环或硬件验证。
<!-- R036_DENSE_PAIR_BOUNDARY -->

## R036 dense-paired boundary validation

R036补充了`20A/score_settle005`在`tau_AI=1.25us`与`1.75us`下的`30us`
dense fallback派生Simulink对照。结果显示，`46us`和`54us` folded probes在
同一延迟下分别比`30us` fallback低约`2.843`和`2.175`分，并避免了fallback
中的一次skip。因此这两个点可从R035的candidate-only升级为局部
dense-paired候选。

这仍不是神经网络AI-in-loop或硬件验证。监督层接口应继续写成
`q_phi`候选生成、`r_hat`短时风险预测和`B_epsilon^sw`投影；`66us`直接覆盖仍被阻止。
<!-- R037_SHORT_HORIZON_RHAT -->

## R037 short-horizon `r_hat` predictor prototype

**Final R037 sync.** R037 does not add new `.slx` simulations.  It merges the
local R031/R033/R034/R036 derived-Simulink rows into a training and calibration
view for `r_hat(skip, settling, phase)`.  The supervisor input is limited to
deployable context and candidate features: `target_load_A`, `load_drop_norm`,
`alpha_settle`, `tau_AI`, `delay_events`, candidate `T_slew`,
`candidate_minus_dense_us`, the folded `q_phi` prior, and recent event-state
proxies.  Skip, settling and phase metrics remain labels from switching replay,
not privileged online inputs.

Policy replay over the current local `20A/score_settle005` contexts gives mean
regret `1.116` for dense fallback, `0.020` for the folded `q_phi` prior, and
`0.000` for the final R037 representative projection after the
`tau_AI≈2us` dense-inclusive foldback guard.  The same risk gate has a posterior
safe upper-bound regret of `0.054` and rejects the observed oracle in `1`
context, so this remains a calibration prototype.  The next minimal derived
validation matrix is `iqcot_r037_minimal_extrapolation_validation_plan.csv`,
checking `42/44/48us` near the `tau_AI=2us` foldback boundary and
`42/44/52/56us` around the `1.25/1.75us` folded commits.

R037不新增`.slx`仿真，而是把R031/R033/R034/R036的局部行合并成`r_hat`训练/校准视图。
监督层输入限定为部署可得的上下文和候选特征；skip、settling、phase只作为训练标签。
下一步最小派生验证矩阵为`iqcot_r037_minimal_extrapolation_validation_plan.csv`，重点检查
`tau_AI=2us`附近`42/44/48us`与`30us` fallback的边界，以及`1.25/1.75us`附近
`42/44/52/56us`的局部鲁棒性。

<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

## R038 minimal extrapolation validation

R038 has completed the full `9` row derived-Simulink delayed-reference matrix
from R037.  The validation keeps the existing folded anchors at
`46us@1.25us`, `50us@1.5us`, and `54us@1.75us`: neighboring probes do not beat
these anchors, and `46us@1.5us` shows skip risk.  The only supervisor-rule
change is at `tau_AI=2us`, where `44/48us` are near-tied with the dense
`30us` fallback and `48us` improves the local objective by about `0.020`.

For deployment design this means:

```text
q_phi -> may propose 44/48us around tau_AI=2us
r_hat -> must still check skip/settling/phase risk
B_epsilon^sw -> submit only within a 30/44/48us near-tie foldback band
```

This is a local derived-model correction to the supervisor projection layer,
not hardware validation and not a reason to remove dense fallback globally.

## R039 Large-Signal Risk Feature for the Supervisor

R039 adds r_E as a measurable large-signal feature for the supervisory layer. The feature is computed from derived Simulink wave snapshots exported by output/iqcot_r039_pr_ecb_large_signal_probe.m. For the initial 40A->20A delayed-reference validation, r_E=0.435 under a 10 mV first-peak allowance, and the value is invariant across 46/50/54/30/48us T_slew cases because the first peak occurs before the delayed reference trajectory materially changes the plant.

The supervisor should therefore use r_E as a pre- or early-event safety gate, not as a replacement for q_phi/r_hat ranking. A practical rule for the next stage is:

- If r_E is below the allowed margin, keep the existing R038 folded-band or dense-fallback deployment logic.
- If r_E approaches or exceeds 1, force a conservative projection: avoid aggressive Ton_diff/Lambda_diff relaxation, preserve dense fallback, and optionally insert a short hold window before accepting a faster reference trajectory.
- Continue to state that AI is a supervisory parameter scheduler and does not output gate commands.
