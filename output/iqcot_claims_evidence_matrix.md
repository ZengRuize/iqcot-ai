# IQCOT / PIS-IEK 核心论断与证据矩阵

## 总体结论

当前研究可以支持一个中高强度、边界清晰的创新主张：

> 对四相数字 IQCOT Buck，PIS-IEK 将面积触发、相序索引、积分复位、执行量通道、切载 skip/reentry 和 FPGA AI 延迟组织为统一的事件域小信号/混合事件框架；该框架能指导参考斜率和低维 AI 参数调度，但不能单独替代开关级仿真或精确预测大切载第一峰值。

## Claim-Evidence Matrix

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C1 | IEK 必须包含动态事件核 `K(z)`，He-only 是退化近似 | 单相动态 IEK 逐周期误差 `<0.00018%`；四相密集扫频中 He-only 最坏误差 `7969.65%` | 强 | “He-only 在某些频点可用，但不能作为唯一数字预算依据。” | “He-only 完全错误。” |
| C2 | PIS-IEK 可把四相 `phase_idx/reset` 写入小信号结构 | `x_{k+1}=F_{p_k}(x_k,u_k,T_k)`、`g_{q_k}=0`；32 行局部灵敏度；77 个幅值扫描；80 个 lifted frequency 工况 | 强 | “PIS-IEK 将相索引工程变量提升为事件面索引。” | “本文首次提出 saltation matrix。” |
| C3 | `Lambda_diff` 主要是相位/事件节奏执行量，不是强 DC 均流执行量 | 解析 m2 `Lambda_diff` 电流增益约 `0.0100 mA/(1e-13 V*s)`；逐相 IEK 副本 `Lambda_m2/Lambda_area=0.4` 时 m2 电流投影仅 `0.001163 A` | 强 | “`Lambda_diff` 更适合 phase-spacing/ripple-cancellation 微调。” | “`Lambda_diff` 对电流完全没有影响。” |
| C4 | `Ton_diff` 是主要 DC current-sharing 执行量，但伴随相位代价 | 解析 m2 `Ton_diff` 电流增益约 `765.07 mA/(0.1 ns)`；Simulink `[+4,-4,+4,-4] ns` 产生约 `1.943 A` m2 投影 | 强 | “`Ton_diff` 是强均流通道，但需要限制相位代价。” | “只调 `Ton_diff` 即可解决所有瞬态问题。” |
| C5 | 大切载需要混合事件建模，不能用单一小信号 Jacobian 覆盖 | 动态负载 `40A->near-0A` 出现 estimated skip `2`，phase std `103.595 ns` 到 `108.304 ns`；切载深度越大 skip/reentry 越明显 | 中强 | “PIS-IEK 应扩展为 normal/skip/reentry/saturation 模式。” | “PIS-IEK 单独精确预测大切载第一峰。” |
| C6 | `dynamic_hold` 与 `dynamic_instant` 暴露参考调度 trade-off | `near-0A`：hold 欠压 `9.451 mV`、最终误差 `+4.413 mV`；instant 欠压 `35.750 mV`、最终误差 `-0.566 mV` | 强 | “瞬时参考改善最终静差但放大欠压。” | “瞬时参考总是更差/更好。” |
| C7 | `Iph_ref` 参考斜率是有实际价值的低维调度变量 | 五点扫描 15 个工况 + 密集扫描 18 个工况 + 长斜率扫描 9 个工况；基础 score 下 `40A->20A/10A` 最佳折中为 `80 us`，`40A->near-0A` 为 `60 us`；near-0A 欠压从 instant 的 `35.750 mV` 降至 `10.452 mV` | 强 | “当前扫描网格中，较慢参考斜率给出更好欠压/稳态折中。” | “`60 us` 或 `80 us` 是全局最优。” |
| C7b | 最佳参考斜率依赖目标权重，适合 AI 调度 | 加入恢复时间惩罚后，`score+0.05*t_s` 的最佳斜率为 `30/50/60 us`，`score+0.10*t_s` 的最佳斜率为 `30/30/30 us`；离线策略评估中 base-score oracle 为 `80/80/60 us`，`score+0.05T_settle` scheduler 为 `30/50/60 us` | 强 | “参考斜率是 objective-sensitive scheduling variable，AI 应学习目标相关调度策略。” | “慢斜率总是更好。” |
| C8 | FPGA AI 微秒级延迟应写成 IQCOT 事件域滞后 | 四相 `500 kHz`，`T_e≈0.5 us`；`tau_AI=5 us` 对应 `10` 个事件 | 强 | “AI 延迟不能忽略，应使用 `u_{k-d}` 训练。” | “AI 可以逐脉冲替代 COT 内环。” |
| C9 | 延迟感知 AI 在大延迟严苛切载下减少 train-test mismatch | `40A->near-0A, T_update=5us, tau_AI=5us`：zero-delay violation `147.875`，delay-aware projected `24.297` | 中强 | “当延迟跨越多个事件时，延迟感知训练明显有价值。” | “delay-aware AI 在所有延迟下都更优。” |
| C10 | `tau_AI=1us` 时 zero-delay-trained 仍有竞争力 | 同一严苛切片：zero-delay reward `-637.369`，delay-aware reward `-772.161` | 强边界 | “小延迟下零延迟训练仍可能有效。” | “零延迟训练总是失效。” |
| C11 | 参考斜率可作为 AI 动作扩展 | `u=[Delta Lambda_diff, Delta Ton_diff, Delta Iph_ref, ref_slew_time]`；ref-slew 扫描已证明该动作影响欠压、final error 和 skip | 中强 | “AI 可以学习 `ref_slew_time` 这类低维参数。” | “AI 已完成真实硬件闭环控制。” |
| C12 | 当前证据尚未完成硬件级验证 | 新增动态证据来自派生 Simulink 副本、表驱动 delayed-reference 验证或 event-domain surrogate | 强边界 | “下一步需要 FPGA/HIL 或硬件验证。” | “实验已证明实物硬件性能提升。” |
| C13 | 可形成延迟感知 AI 监督层训练接口 | `iqcot_ai_supervisor_training_targets.csv`：3 个切载目标 × 3 个目标权重 × 5 个 FPGA 延迟上下文，共 45 行标签；动作限定为 `T_slew` 等低维参数 | 中 | “已形成可用于下一步 AI-in-loop 验证的监督标签和验证矩阵。” | “训练标签已经证明 AI 策略优于基线。” |
| C14 | 表驱动监督层可在 `0.5/1/2/5 us` 参数提交延迟下进入派生开关级模型，并呈现目标-延迟敏感排序 | `iqcot_table_supervisor_validation_results*.csv` 与 `iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv`：`tau>0` 共 60 个派生 Simulink delayed-reference 工况；base 目标在 `0.5/1 us` 下最佳为 base-score table，在 `2/5 us` 下最佳为 `alpha=0.05` table；强恢复时间惩罚在 `0.5/1/5 us` 下偏向 `alpha=0.10` table，在 `2 us` 下偏向 `alpha=0.05` table | 中强 | “表驱动监督层延迟验证支持 `T_slew` 作为目标和延迟共同敏感的 AI 参数调度量。” | “神经网络 AI 已经在硬件或完整 AI-in-loop 中验证。” |
| C15 | 可解释 score 监督层可近似已有 delayed-reference 策略排序，但尚未稳定优于强查表基线 | `iqcot_ai_supervisor_regressor_dataset.csv`：60 个正延迟开关级工况展开为 180 行候选策略打分样本；`iqcot_ai_supervisor_regressor_summary.csv`：leave-one-tau 最佳 mean regret `0.304`，比固定 `40 us` 低约 `73.2%`，但仅比零延迟目标表低 `0.013`；leave-one-target 最佳仍为零延迟目标表 `0.316` | 中 | “可解释监督层把表驱动验证推进为 score-prediction 训练接口，并显著优于固定斜率基线。” | “AI/回归器已全面优于查表策略或完成神经网络闭环验证。” |
| C16 | 连续 `T_slew` 更适合做 near-optimal 区间内平滑调度，而不是宣称大幅超越离散表 | `iqcot_ref_slew_continuous_landscape_summary.csv`：9 个目标/目标函数组合的局部二次插值最大估计收益 `0.239` 分；4 个组合低于 `0.05`，2 个适合小范围细扫，3 个需新开关级验证确认；near-optimal/safe band 多为区间或分段区间 | 中 | “连续动作分析给出下一轮细扫候选和安全区间，用于训练连续监督层。” | “局部二次插值已经证明连续 `T_slew` 全局最优或显著优于离散表。” |
| C17 | R024 局部细扫支持“连续/更细网格有价值”，但同时证明局部二次候选不能被当成点最优 | `iqcot_dynamic_ref_slew_fine_summary.csv`：45 个派生 Simulink 局部细扫工况全部成功；`iqcot_ref_slew_fine_candidate_comparison.csv`：20A 的 35us 最近候选在 settling-aware 目标下劣于旧 30us，但 38us 改善约 `0.076` 分；near0A `score+0.10T_settle` 在 38us 改善约 `0.235` 分；`iqcot_ref_slew_fine_best_by_objective.csv`：20A settling-aware 在 66us 进一步小幅改善，显示 skip/reentry 非光滑跳变 | 中强 | “细扫验证支持 mode-aware near-optimal band 和安全投影，局部候选需开关级确认。” | “34-35us 已被证明是最优点；连续回归已经优于离散表或硬件验证。” |
| C18 | mode-aware 连续 `T_slew` 后处理优于裸平滑连续最小化，但仍只是离线安全投影设计证据 | `iqcot_mode_aware_slew_dataset.csv`：dense+long+fine 展开为 `207` 行 objective-level 样本；`iqcot_mode_aware_slew_surrogate_eval.csv`：mode-aware in-sample RMSE `0.101` vs smooth `0.855`，leave-one-target 仍较大 `5.940`；`iqcot_mode_aware_slew_policy_summary.csv`：裸二次连续平均 regret `0.654`，near-opt band `0.101`，mode-aware safety projection `0.064`，dense_long table `0.163` | 中 | “mode-aware 特征和安全投影可减少裸连续动作的模式跳变风险。” | “mode-aware surrogate 已完成 AI-in-loop，或证明连续控制全局优于查表/硬件。” |
| C19 | R026 将后验 mode-aware 指标转化为可部署 risk proxy 接口，但仍不是硬件或神经网络 AI-in-loop 验证 | `iqcot_deployable_risk_proxy.py`：只用已完成 R025 数据离线重放；`iqcot_deployable_proxy_policy_summary.csv`：校准风险表 proxy mean regret `0.119`，低于 dense_long table `0.163` 和裸连续 `0.654`，但弱于后验 mode-aware projection `0.064`；纯参数 proxy mean regret `0.857`，说明光滑 proxy 不足 | 中 | “PIS-IEK 支持把后验模式指标降级为离线校准 `r_hat(z,T_slew)` 或短时预测接口，用于监督层安全投影。” | “risk proxy 已证明跨负载泛化、硬件安全或神经网络 AI 闭环优于查表。” |
| C20 | R027 已把 R026 risk proxy 转成派生 Simulink table-in-loop 压力验证，并暴露当前 proxy 需重标定 | `iqcot_r027_proxy_table_in_loop_validation.m` 分段完成全部 `48` 个优先派生 Simulink 工况；`iqcot_r027_proxy_table_in_loop_policy_eval_priority_combined.csv`：dense-long table 与 posterior 上界 mean switching regret 均为 `0.025`，near-opt band `0.257`，calibrated proxy `0.283`；proxy 对 dense-long 为 `0/8` 更优、`4/8` 并列、`4/8` 更差 | 中强边界 | “R027 证明 proxy 接口可以进入派生开关级参考通道，但当前校准在压力上下文中没有稳定超过 dense-long table，需要重标定安全投影。” | “R027 已证明 calibrated proxy 开关级优于 dense-long table，或已完成硬件/神经网络 AI-in-loop。” |
| C21 | R028 可将 R027 负面压力样本转化为开关级校准的安全投影，但 guarded 规则仍需 held-out 验证 | `iqcot_r028_switching_calibrated_proxy.py` 基于 R027 priority switching 结果重放；`iqcot_r028_switching_calibrated_policy_summary_priority.csv`：旧 proxy mean switching regret `0.283`，dense-long `0.025`，`r028_dense_anchor_proxy` `0.025`，`r028_switching_guarded_proxy` `0.000`；`iqcot_r028_offline_replay_all_contexts.csv`：dense-anchor 离线 mean regret `0.099` | 中强边界 | “R028 将 `B_epsilon(z,r_hat,tau_AI)` 重标定为 dense-anchor safety projection，修复已知 `62us` proxy 失败；guarded 规则是下一轮验证候选。” | “R028 已证明 proxy/AI 泛化优于 dense-long table，或 guarded 规则已经是硬件安全策略。” |
| C22 | R029 held-out 验证支持 10A delay guard 的局部边界，但修正 near0A 固定 `35us` guard | `iqcot_r029_heldout_guard_validation.m` 执行 `21` 个 held-out 派生 Simulink 工况；`iqcot_r029_heldout_guard_context_summary_combined.csv`：10A `score_settle005` 中 `tau_AI=1.5us` 最优为 `40us`，`2.5/3us` 最优为 `34us`；near0A `score_settle010` 中 `tau_AI=0/0.25us` 最优为 `38us`，`0.5us` 最优为 `30us`; old `62us` proxy family mean regret `0.806` | 中强边界 | “R029 给出 R028 guard 的 held-out 局部修正：10A 短斜率 guard 适用于 `tau_AI>=2us` 附近，near0A 应改为 `30-38us` 安全带。” | “R029 证明了全局最优斜率、硬件安全策略或 AI/proxy 全面优于查表。” |
| C23 | R030 将 R029 局部修正整理成 refined-band policy，并给出 dense-anchor 是否过保守的下一轮挑战计划 | `iqcot_r030_refined_band_policy.py` 后处理 R027/R028/R029；`iqcot_r030_refined_band_switching_evidence.csv`：已知 guard-context 上 R030 选中行 mean switching regret `0.000`，对应 dense-anchor `0.128`；`iqcot_r030_refined_band_policy_summary.csv`：离线 mean regret R030 `0.104`、R028 guarded `0.106`、dense-anchor `0.099`；`iqcot_r030_dense_anchor_challenge_plan.csv`：`30` 行 dense/proxy 成对挑战计划 | 中边界 | “R030 把 guard 点改写成局部安全带，并筛出下一轮派生 Simulink 应检验的 dense/proxy 分歧上下文。” | “R030 已经证明 refined-band 策略独立泛化、硬件安全，或 dense-anchor 一定过保守。” |
| C24 | R030 dense-anchor challenge 未支持 proxy 稳定 override，反而给出收紧 `B_epsilon^sw` 的负校准样本 | `iqcot_r030_dense_anchor_challenge_validation.m` + `iqcot_r027_proxy_table_in_loop_validation.m planMode="r030_challenge"` 完成 `30` 行派生 Simulink delayed-reference 成对回放；`iqcot_r030_dense_anchor_challenge_policy_summary.csv`：dense-anchor mean switching regret `0.186`，proxy `0.574`；`iqcot_r030_dense_anchor_challenge_motif_summary.csv`：proxy 胜 `7/15`、dense-anchor 胜 `8/15`，`20A/score_settle005` proxy 平均劣化 `1.073` | 中强边界 | “R030 challenge 表明当前 proxy 可作为候选生成器，但不能在未验证局部带外直接覆盖 dense-anchor；负样本应反向用于收紧安全投影。” | “R030 challenge 证明 dense-anchor 全局最优、proxy 永远失败、或 AI/proxy 已完成硬件/开关级全面优越性验证。” |
| C25 | R031 将 R030 负样本转成 tightened `B_epsilon^sw`，并用 22 行最小 held-out 派生验证修正为延迟敏感局部带 | `iqcot_r031_tightened_bepsilon_sw.py` 后处理 R030 challenge；`iqcot_r031_tightened_bepsilon_policy_summary.csv`：R031 tightened projection 校准集 mean regret `0.132`；`iqcot_r031_minimal_validation.m` 分块完成 `22` 行派生 Simulink；`iqcot_r031_minimal_validation_context_summary.csv`：R031 best intermediate 优于 dense `3/9`、优于原 proxy `8/9`，best-family counts dense `6`、R031 intermediate `3` | 中强边界 | “R031 支持把 `B_epsilon^sw` 写成 delay-aware local band with dense fallback；AI/proxy 应输出候选 score/risk，不能直接覆盖 dense-anchor。” | “R031 已证明 tightened projection 全局优于 dense-anchor、硬件安全，或 proxy 可以直接替代 IQCOT 内环。” |

## 数值核对清单

| 数字 | 来源文件 | 备注 |
|---:|---|---|
| `35.750 mV` near-0A instant 欠压 | `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv` | `dynamic_instant`, `40A->0.001A` |
| `10.452 mV` near-0A `60 us` 欠压 | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv` | 当前密集扫描网格最佳 |
| `-0.543 mV` near-0A `60 us` final error | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv` | 不能写成零误差 |
| `147.875` zero-delay mean violations | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_report.md` | surrogate，非开关级仿真 |
| `24.297` delay-aware projected mean violations | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_report.md` | surrogate，非硬件 |
| `15360` episodes | `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_report.md` | 3 cases × 5 delays × 4 update periods × 4 policies × 64 seeds |
| `80/80/60 us` best scanned slew | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv` | 只能说当前密集网格 |
| `30/50/60 us` and `30/30/30 us` settling-aware best slew | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_settle_penalty_best.csv` | 说明最佳斜率依赖目标权重 |
| `80/80/60 us` base-score oracle scheduler | `E:/Desktop/codex/output/iqcot_ref_slew_scheduler_policy_eval.csv` | 平均 base score `9.299`，优于固定 `80 us` 的 `9.435` |
| `30/50/60 us` `score+0.05T_settle` scheduler | `E:/Desktop/codex/output/iqcot_ref_slew_scheduler_policy_eval.csv` | 平均 score `10.356`，优于固定 `30 us` 的 `10.683` 和固定 `80 us` 的 `11.043` |
| `45` AI supervisor training labels | `E:/Desktop/codex/output/iqcot_ai_supervisor_training_targets.csv` | 训练接口，不是 AI-in-loop 结果 |
| `75` planned table-supervisor validation rows | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_plan.csv` | 3 个切载目标 × 5 个策略 × 5 个延迟上下文 |
| `15` delayed switching validation cases | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results.csv` | 仅 `tau_AI=5 us` 的派生 Simulink delayed-reference 验证 |
| `45` delayed switching validation cases | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_results_tau0p5_1_2us.csv` | `tau_AI=0.5/1/2 us` 的派生 Simulink delayed-reference 验证 |
| `60` total tau>0 delayed switching cases | `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_by_tau.csv` | 3 个切载目标 × 5 个策略 × 4 个正延迟上下文 |
| `8.383` / `9.657` table `alpha=0.05` scores | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval.csv` | 分别为 mean base score 和 mean `score+0.05T_settle` |
| `10.785` table `alpha=0.10` score | `E:/Desktop/codex/output/iqcot_table_supervisor_validation_policy_eval.csv` | mean `score+0.10T_settle`，强调目标敏感性 |
| base objective best policy shift | `E:/Desktop/codex/output/iqcot_table_supervisor_delay_sensitivity_best_by_tau.csv` | `0.5/1 us`: base-score table；`2/5 us`: `alpha=0.05` table |
| `180` candidate-score rows / `36` labels | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_dataset.csv`; `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_context_labels.csv` | 60 个正延迟开关级工况 × 3 个目标函数；4 个延迟 × 3 个切载目标 × 3 个目标函数 |
| `0.304` leave-one-tau mean regret | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_summary.csv` | `trained_objective_nearest_tau_table`，比固定 `40 us` 基线 `1.131` 低约 `73.2%`，但相对零延迟目标表 `0.316` 仅改善 `0.013` |
| `0.316` leave-one-target best mean regret | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_summary.csv` | 最佳仍为 `zero_delay_objective_table`；ridge score supervisor 为 `0.620`，优于固定斜率但未超过强查表基线 |
| `11` tie contexts / `23` near-tie contexts | `E:/Desktop/codex/output/iqcot_ai_supervisor_regressor_report.md` | 36 个监督上下文中 11 个 oracle 并列，23 个一二名差距不超过 `0.25`，因此主指标应看 regret 而不是纯 policy accuracy |
| `0.239` max continuous estimated gain | `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv` | 局部二次插值最大收益，来自 near-0A `score+0.10T_settle`；只是下一轮仿真候选，不是开关级验证 |
| `34.744 us` / `34.633 us` local candidates | `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv` | `20A` settling-aware 两个目标给出约 `34.744 us`，near-0A `score+0.10` 给出约 `34.633 us`；均需新 Simulink 验证 |
| `4/2/3` continuous decision split | `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_report.md` | 4 个组合离散网格足够，2 个建议细扫，3 个需要新开关级验证确认 |
| `45` R024 fine-sweep cases | `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv` | 3 个切载目标 × 15 个细扫斜率，全部成功；派生 Simulink 模型，不是硬件 |
| `35 us` not point-optimal for 20A | `E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv`; `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv` | 20A settling-aware 最近候选 `35 us` score 为 `4.291/4.338`，因 `skip_count=1` 劣于旧 `30 us` |
| `38 us` local fine improvement | `E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv` | 20A `score+0.05/0.10` 在 `38 us` 改善约 `0.076`；near0A `score+0.10` 在 `38 us` 改善约 `0.235` |
| `66 us` / `86 us` / `92 us` fine-grid best examples | `E:/Desktop/codex/output/iqcot_ref_slew_fine_best_by_objective.csv` | 20A settling-aware 全细扫网格 best 为 `66 us`，20A base best 为 `86 us`，near0A base best 为 `92 us`；均只能说当前网格 best |
| `207` R025 objective-level rows | `E:/Desktop/codex/output/iqcot_mode_aware_slew_dataset.csv` | 69 个 plant rows × 3 个 objective；dense+long+fine 后处理，不新增 `.slx` |
| `0.101` vs `0.855` surrogate RMSE | `E:/Desktop/codex/output/iqcot_mode_aware_slew_surrogate_eval.csv` | mode-aware in-sample score RMSE 明显低于 smooth，但 mode 特征来自后处理指标 |
| `0.064` mode-aware mean regret | `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_summary.csv` | mode-aware safety projection 平均 regret；低于 dense_long table `0.163` 和裸二次 `0.654`，但只是离线策略后处理 |
| `2.429` naked continuous max regret | `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_summary.csv`; `E:/Desktop/codex/output/iqcot_mode_aware_slew_policy_eval.csv` | 裸二次连续最大 regret，来自忽略模式跳变的风险；不是硬件结果 |
| `0.119` calibrated risk proxy mean regret | `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv` | R026 可部署校准风险表 proxy；低于 dense_long table `0.163`，但弱于后验 mode-aware projection `0.064` |
| `0.857` parametric proxy mean regret | `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv` | 纯光滑部署特征 proxy 的负面对照，说明 target/load/T_slew 平滑回归不足以处理 skip/reentry 非光滑边界 |
| `69` calibrated risk table rows / `45` replay cases | `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_table.csv`; `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_eval.csv` | 69 个 target/ref_slew 校准点；9 个目标/目标函数上下文 × 5 个 tau 设置的离线重放，不是新增开关级仿真 |
| `315` / `48` R027 plan rows | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_plan.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_priority_plan.csv` | 完整 proxy table-in-loop 计划和优先派生仿真矩阵；计划本身不是开关级结果 |
| `48` R027 priority switching cases | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_results_priority_combined.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_combined_report.md` | 优先矩阵全部完成且成功；派生 Simulink 开关级压力验证，不是硬件验证 |
| `0.025` vs `0.283` priority mean regret | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_policy_eval_priority_combined.csv` | dense-long table/posterior 上界 mean switching regret `0.025`，calibrated proxy `0.283`；R026 离线 proxy 优势未在压力矩阵保持 |
| `0/4/4` proxy vs dense contexts | `E:/Desktop/codex/output/iqcot_r027_proxy_vs_dense_priority_combined.csv` | proxy 相对 dense-long 为 0 个上下文更优、4 个并列、4 个更差 |
| `0.025` R028 dense-anchor priority mean regret | `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv` | 保守 `r028_dense_anchor_proxy` 修复旧 proxy 已知失败并追平 dense-long table；不是硬件验证 |
| `0.000` R028 guarded priority mean regret | `E:/Desktop/codex/output/iqcot_r028_switching_calibrated_policy_summary_priority.csv` | 由 R027 priority 压力点校准得到，只能作为 R029 held-out 验证候选 |
| `0.099` R028 dense-anchor offline mean regret | `E:/Desktop/codex/output/iqcot_r028_offline_replay_all_contexts.csv` | R026 45 个上下文离线一致性检查，低于旧 proxy `0.119` 和 dense-long `0.163`，但不能替代开关级验证 |
| `21` R029 held-out switching cases | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_results_combined.csv`; `E:/Desktop/codex/output/iqcot_r029_heldout_guard_combined_report.md` | 全部成功；派生 Simulink 验证，不是硬件 |
| `34us` best at `tau_AI=2.5/3us` for 10A | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv` | 支持 R028 10A delay guard 的局部 held-out 边界；`tau=1.5us` 最优是 `40us` |
| `38us` best at near0A `tau_AI=0/0.25us` | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_context_summary_combined.csv` | 修正 R028 near0A 固定 `35us` guard，应写成 `30-38us` 局部安全带 |
| `0.806` old proxy failure-probe mean regret | `E:/Desktop/codex/output/iqcot_r029_heldout_guard_policy_summary_combined.csv` | old `62us` proxy 在 10A held-out 仍差，支持 dense-anchor 投影排除它 |
| `0.104` R030 offline mean regret | `E:/Desktop/codex/output/iqcot_r030_refined_band_policy_summary.csv` | 离线一致性检查；略低于 R028 guarded `0.106`，略高于 dense-anchor `0.099`，不能替代切换验证 |
| `0.000` vs `0.128` R030 known guard-context switching regret | `E:/Desktop/codex/output/iqcot_r030_refined_band_switching_evidence.csv` | R030 选中行与 dense-anchor 在 R027/R029 已知 guard-context 上的合成对比；不是独立泛化证明 |
| `30` R030 dense-anchor challenge rows | `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv`; `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_results_combined.csv` | 3 组 motif × 5 个 tau × dense/proxy 两行；派生 Simulink 回放已全部成功 |
| `0.186` vs `0.574` R030 challenge mean switching regret | `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_policy_summary.csv` | dense-anchor 低于 proxy；说明当前 proxy 不应直接 override dense-anchor |
| `7/15` proxy wins, `8/15` dense wins | `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_context_summary.csv` | 成对上下文胜负；不支持 dense-anchor 普遍过保守 |
| `1.073` `20A/score_settle005` proxy-minus-dense mean score | `E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_motif_summary.csv` | `66us` proxy 的主要负样本；多个延迟下引入 skip 或更长 settling |
| `0.132` R031 tightened projection mean regret | `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv` | 校准集候选，低于 dense-anchor `0.186`，但使用 R030 已观测子带，不能当作 held-out 泛化 |
| `0.189` small-delta-only mean regret | `E:/Desktop/codex/output/iqcot_r031_tightened_bepsilon_policy_summary.csv` | 简单 `<=2us` near-tie 规则不优于 dense-anchor，说明延迟非单调需要风险分类 |
| `22` R031 minimal validation rows | `E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv` | `10A/score_settle010` 的 `31/33us`、`20A/base` 的 `82/84us`、`20A/score_settle005` 的 `38/50/58us`；下一轮派生 Simulink 计划 |
| `22` R031 MATLAB dry-run rows | `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv`; `E:/Desktop/codex/output/iqcot_r027_proxy_table_in_loop_matlab_dryrun_r031_minimal.md` | 只验证计划加载和 delayed-reference schema 转换，不是开关级性能结果 |
| `3/9` R031 intermediate beats dense | `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv` | 支持局部中间带，但不支持 R031 全面优于 dense fallback |
| `8/9` R031 intermediate beats original proxy | `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv` | 说明 `38/50/58us` 等中间候选比原 `66us` proxy 更适合进入 risk predictor 候选集 |
| `dense 6` vs `R031 intermediate 3` best-family counts | `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv` | `B_epsilon^sw` 应保留 dense fallback，而不是直接采用中间候选 |

## 审稿式自查

### 可能被问的问题 1：这个创新是不是只是把 saltation matrix 用到了 IQCOT？

回答：不能把贡献写成“发明 saltation matrix”。更稳妥的贡献是将 saltation/移动边界线性化具体落到四相数字 IQCOT 面积积分事件中，并把 `phase_idx/reset/Lambda_i/Ton_i` 执行量统一成可验证的事件域 Jacobian。创新在应用对象、执行量分类和仿真证据链，而不是数学工具本身。

### 可能被问的问题 2：为什么不直接用已有 IQCOT 高频小信号模型？

回答：已有模型主要服务于环路传函和稳定性分析。本文的问题是多相数字实现中的执行量分类、相位扰动、参考斜率和 AI 延迟。PIS-IEK 补充的是事件索引和执行量通道层面的设计信息。

### 可能被问的问题 3：切载第一峰 PIS-IEK 预测准吗？

回答：本文不把第一峰作为 PIS-IEK 的强 claim。第一峰应由电感能量和输出电容大信号模型解释；PIS-IEK 用于后续事件恢复、skip/reentry、phase-spacing 和均流恢复。

### 可能被问的问题 4：AI 结果是不是过度？

回答：当前 AI 证据分五层。训练标签表证明可以把 sweep 转成监督层目标；`0.5/1/2/5 us` 表驱动 delayed-reference 结果证明低维表调度可以进入派生开关级模型；可解释 score 回归器证明已有策略排序可被监督层近似学习，但尚未稳定优于强查表基线；连续景观后处理给出细扫候选和 near-optimal/safe band，但不是新仿真；event-domain surrogate 证明延迟坐标和安全投影有价值。这些仍不等同于神经网络 AI-in-the-loop 或硬件验证。因此论文应写“PIS-IEK 支撑 AI 参数调度”，不写“AI 已全面优于 IQCOT”。

### 可能被问的问题 5：实验量是否足够？

回答：对“参考斜率”这一局部结论，已有 15 个五点扫描工况、18 个密集扫描工况、9 个长斜率扫描工况和 45 个 R024 局部细扫工况，并补充了恢复时间惩罚敏感性与 9 个目标/目标函数组合的连续景观后处理；对“表驱动延迟调度”，已有 60 个 `tau_AI>0` 派生开关级 delayed-reference 工况；对“可解释监督层”，已有 180 行候选策略打分样本、36 个上下文标签和两类 leave-one-out 交叉验证；对“延迟建模必要性”，已有 15360 episode surrogate；对基础 PIS-IEK，小信号层已有 77+80 个结构化工况。仍需补充的是连续动作 AI-in-the-loop、真实神经网络接入和硬件/HIL 验证。

### 可能被问的问题 6：R023 说 34-35us，R024 为什么出现 38us 或 66us？

回答：这不是矛盾，而是 R024 的核心价值。R023 是基于 `20/30/40/50/60/80/100/120 us` 的局部二次插值，只能生成下一步候选；R024 显示 `T_slew` 分数景观受 `skip_count` 和相位间隔标准差影响，可能出现非光滑跳变。20A 的 `35 us` 因 `skip_count=1` 变差，而 `38 us` 或 `66 us` 进入不同事件模式后更好。因此论文应强调 mode-aware fine sweep 和安全投影，不能把插值候选当成已验证最优点。

### 可能被问的问题 7：R025 的 mode-aware safety projection 是不是已经证明 AI 更优？

回答：不是。R025 使用的是已完成 dense+long+fine 派生 Simulink 结果的离线后处理。`skip_count_est`、phase std 和 settling time 在这里是后验指标；真实 AI 部署必须先预测或估计这些风险。R025 能支持的结论是：裸平滑连续最小化会被非光滑模式跳变误导，而 mode-aware band clipping 是合理的监督层设计方向。它不能证明神经网络 AI-in-loop 或硬件闭环优于查表。

### 可能被问的问题 8：R026 的可部署 risk proxy 是否已经解决了 AI 控制问题？

回答：也没有。R026 解决的是 R025 的一个表述风险：后验模式指标不能直接作为在线输入。它把这些指标降级为离线校准 `r_hat(z,T_slew)` 或短时预测接口，并显示校准风险表 proxy 在当前离线重放中优于 dense-long 表和裸连续策略。但该 proxy 使用当前仿真网格校准，leave-one-target 和纯参数 proxy 结果都说明跨负载泛化仍不足。因此 R026 支持“下一步可接入派生 Simulink 做 table-in-loop 验证”，不支持“AI 已完成硬件闭环控制”。

### 可能被问的问题 9：R027 是否已经证明 proxy 可部署并优于查表？

回答：不能。R027 现在已经完成 `48` 行优先派生 Simulink 压力矩阵，最强贡献是证明 `r_hat` proxy 能以 table-in-loop 形式进入延迟参考通道，并且暴露当前校准的边界。结果并不支持 proxy 优于查表：dense-long table 与 posterior 上界 mean switching regret 均为 `0.025`，calibrated proxy 为 `0.283`；proxy 相对 dense-long 为 `0/8` 更优、`4/8` 并列、`4/8` 更差。因此论文应把 R027 写成“开关级压力检验发现 proxy 需要重标定”，不是“proxy 已经胜过 dense-long table”。

### 可能被问的问题 10：R028 的 guarded proxy 为零 regret，是否说明创新已经够强？

回答：不能这样写。`r028_switching_guarded_proxy` 的 `0.000` mean switching regret 来自 R027 priority 压力点本身，是压力集校准结果，不是 held-out 泛化结果。R028 真正稳健的贡献是保守 `r028_dense_anchor_proxy`：它把旧 proxy 的 `62us` 失败投影回 dense-long 基线，使 priority mean switching regret 从 `0.283` 降至 `0.025`，追平强查表基线。guarded 规则的价值是形成 R029 的少量派生 Simulink 验证点，而不是作为最终性能 claim。

### 可能被问的问题 11：R029 是否证明 guarded proxy 已经泛化？

回答：仍然不能。R029 比 R028 更强，因为它确实执行了 `21` 个 held-out 派生 Simulink 工况，证明 `10A/score_settle005` 的 `34us` delay guard 在 `tau_AI=2.5/3us` 附近有局部支持，并证明旧 `62us` proxy 仍应排除。但 R029 同时推翻了 near0A 固定 `35us` guard：加入 `38us` 细扫候选后，`tau_AI=0/0.25us` 的最佳点变成 `38us`，`0.5us` 又回到 `30us`。因此 R029 的结论应写成“guarded proxy 需要上下文安全带和继续迭代”，不是“guarded proxy 已经泛化优于查表”。

### 可能被问的问题 12：R030 的 `0.000` mean switching regret 是不是最终策略证明？

回答：不是。R030 的 `0.000` 来自把 R027 priority replay 与 R029 held-out 结果合成后，选择每个已知 guard-context 中已经被验证过的局部动作；它证明的是 refined-band 规则与当前局部证据一致，而不是独立泛化。R030 更有价值的新增产物是 `30` 行 dense/proxy 成对挑战计划：它指出 `10A/score_settle010`、`20A/base` 和 `20A/score_settle005` 中可能存在 dense-anchor 过保守的非优先上下文，但这些还必须通过派生 Simulink delayed-reference 回放确认。

### 可能被问的问题 13：R030 challenge 运行后，是不是说明 dense-anchor 其实最优、proxy 不该研究了？

回答：也不能这样写。R030 challenge 只比较了 `15` 个 dense/proxy 成对上下文，不覆盖全局 `T_slew` 空间，也不是硬件验证。它能支持的结论是：当前 proxy 排序在这些非优先分歧点上不稳定，dense-anchor 的 mean switching regret `0.186` 低于 proxy 的 `0.574`，尤其 `20A/score_settle005` 的 `66us` proxy 是需要收紧的负样本。因此后续研究不是放弃 proxy/AI，而是把 proxy 从“直接 override”降级为“候选生成 + mode-aware safety projection”，并用 `B_epsilon^sw` 与短时事件风险预测限制未验证动作。

### 可能被问的问题 14：R031 tightened projection 的 `0.132` 是否已经证明新策略更优？

回答：不能。R031 的 `0.132` 是基于 R030 challenge 已观测上下文做出的校准集重放，不是新 held-out 派生仿真，更不是硬件验证。后续 `22` 行最小 held-out 派生验证已经完成，结论也不是“R031 全胜”：R031 intermediate 只在 `3/9` 个上下文优于 dense，但在 `8/9` 个上下文优于原 proxy。最稳妥的 claim 是：R031 把 `B_epsilon^sw` 修正为延迟敏感局部带，并证明 `38/50/58us` 等中间候选比原 `66us` proxy 更有研究价值；它仍需要 dense fallback，也不能替代硬件/HIL 验证。
### C26 / R032：delay-aware `B_epsilon^sw` band projection

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C26 | R032 将 R031 的延迟敏感局部带整理为短时风险预测接口：`q_phi` 生成候选 score/ranking，`r_hat` 估计 skip/settling/phase 风险，最终 `T_slew` 经 `B_epsilon^sw` 投影后提交 | `iqcot_r032_delay_aware_band_predictor.py`；`iqcot_r032_candidate_risk_features.csv` 共 `40` 行候选；`iqcot_r032_policy_summary.csv` 中 fitted band known-context mean regret `0.000`、dense fallback `0.337`、direct proxy `1.107`、nearest-tau LOTO stress `0.589`；`iqcot_r032_next_validation_plan.csv` 生成 `31` 行下一轮验证矩阵 | 中等，边界强 | “R032 支持 delay-aware local band with dense fallback，并说明简单延迟近邻插值不足；AI/表驱动应输出候选 score/risk，再经过投影。” | “R032 已证明 AI/proxy 泛化优于 dense table、已完成硬件验证、或 `T_slew` 存在全局最优。” |

R032 的 `0.000` 是 R031 已知上下文上的拟合一致性，不是独立验证。最重要的负面证据是 `nearest_tau_loto_predictor` 的 mean regret `0.589`，它提示非光滑 skip/reentry 边界不能用简单 `tau_AI` 插值解决。
### C27 / R033：R032 delay-band 的派生 Simulink 边界验证

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C27 | R033 用 `31` 行派生 Simulink delayed-reference 验证修正 R032 的 delay-aware `B_epsilon^sw` 边界：监督层可产生局部候选带，但最终 plant commit 仍需安全投影和 dense fallback。 | `iqcot_r032_delay_band_validation.m` 复用 R027 runner；`iqcot_r033_delay_band_validation_results_combined.csv` 共 `31` 行且全部成功；`iqcot_r033_delay_band_validation_context_summary.csv` 显示非 dense 候选在 `4/7` 个上下文最优；`66us` 负控平均 regret `1.186`。 | 中等，边界强 | “R033 支持 delay-aware local band with dense fallback，并把 R032 规则修正为 near-tie 带、objective-dependent probe 与 50us transition pocket。” | “R033 证明 AI/proxy 全局优于查表、完成硬件验证、或找到 `T_slew` 全局最优。” |
### C28 / R034：可部署短时风险接口与 transition-pocket 细扫计划

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C28 | R034 将 R033 的边界修正整理为可部署风格的 `q_phi/r_hat/B_epsilon^sw` 接口，并生成 `20A/score_settle005` 过渡口袋的最小细扫矩阵。 | `iqcot_r034_deployable_risk_predictor.py`；`iqcot_r034_deployable_risk_grid.csv` 共 `87` 行；`iqcot_r034_policy_surface.csv` 共 `15` 行；`iqcot_r034_transition_pocket_validation_plan.csv` 共 `20` 行。 | 中等偏弱，设计/计划证据 | “R034 把 PIS-IEK 的事件风险信息转成监督层候选评分、风险估计和安全投影接口，并提出下一轮最小验证矩阵。” | “R034 已证明 AI/proxy 泛化优于查表、完成硬件验证、或证明 `50us` transition pocket 全局最优。” |
### C29 / R034 partial：`20A/score_settle005` transition ridge

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C29 | R034 部分派生验证表明 `20A/score_settle005` 的过渡动作更像随 `tau_AI` 移动的局部 ridge，而非固定 `50us` 口袋。 | `iqcot_r027_proxy_table_in_loop_results_r034_transition_pocket_rows006_010.csv` 与 `rows011_015.csv` 共 `10` 行成功；`iqcot_r034_transition_pocket_context_partial_summary.csv` 显示 `tau=1.25us -> 46us`、`tau=1.75us -> 54us`，结合 R033 `tau=1.5us -> 50us`。 | 中等，仍是局部派生模型证据 | “R034 partial 支持移动 transition ridge 假设，并提示下一轮应验证 `tau=1.0/2.0us` 外推点。” | “R034 已证明 ridge 公式全局成立、硬件有效、或 `T_slew` 存在全局最优。” |
### C30 / R034 full：`20A/score_settle005` folded transition band

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C30 | R034 完整派生验证显示 `20A/score_settle005` 的安全候选集合是 folded transition band，而不是固定 `50us` 口袋或单调 ridge。 | `iqcot_r034_transition_pocket_results_full_combined.csv` 合并 `20` 行 R034 与 R033 锚点；`iqcot_r034_transition_pocket_context_full_summary.csv` 显示最佳序列 `38/46/50/54/46us`；`iqcot_r034_folded_band_policy.csv` 给出投影规则。 | 中等，派生模型证据较完整但非硬件 | “R034 支持将 `20A/score_settle005` 写成由 skip 与 settling 风险共同限制的 folded transition band。” | “R034 证明 `T_slew` 全局最优、硬件有效、或 AI/proxy 全面优于查表。” |

### C31 / R035：folded-band 可部署投影与 claim 收束

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C31 | R035 将 R034 的 folded transition band 收束为“候选生成 + 风险预测 + dense-inclusive `B_epsilon^sw` 投影”接口，明确候选带不等于最终 plant commit 序列。 | `iqcot_r035_folded_band_projection.py`；`iqcot_r035_folded_band_policy_surface.csv` 显示 `tau_AI=2us` 下 R034 transition probe 为 `46us`，但 dense-inclusive deployable commit 回到 `30us`；`iqcot_r035_reviewer_claim_audit.csv` 明确修正 R030-R034 可能过强 claim；`fig48_r035_folded_band_projection.svg` 区分过渡候选、可部署提交和 blocked `66us`。 | 中等，主要是证据整合和审稿式收束 | “R035 支持把 folded band 写成监督层候选带，并要求最终 `T_slew` 经过 `r_hat` 与 `B_epsilon^sw` 投影后提交。” | “R035 证明 `38/46/50/54/46us` 是完整可部署最优序列、硬件安全策略或全局最优规律。” |

R035 最关键的收束是修正 R034 的表述边界：`38/46/50/54/46us` 是 transition-candidate set 内的最佳序列，不是替代 dense fallback 的完整部署策略。特别是 `tau_AI=2us`，R034 transition-only 结果支持 `46us/50us` 近似候选，但 R031 dense-inclusive 证据仍使 `30us` 成为更稳妥 plant fallback。这一修正使论文主张更接近“PIS-IEK 支持可验证安全投影边界”，而不是“AI/proxy 直接给出最终最优斜率”。
<!-- R036_DENSE_PAIR_BOUNDARY -->

### C32 / R036：dense-paired boundary validation

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R036补齐`20A/score_settle005`在`tau_AI=1.25/1.75us`的dense fallback成对验证，并支持将`46/54us` folded probes升级为局部dense-paired候选 | `iqcot_r036_dense_pair_postprocess.py`; `iqcot_r027_proxy_table_in_loop_results_r036_dense_pair.csv`两行全部成功；`iqcot_r036_dense_pair_context_summary.csv`显示`46us`相对`30us`改善约`2.843`分，`54us`相对`30us`改善约`2.175`分，且dense fallback均出现`skip_count=1` | 中等，局部派生Simulink证据 | “R036支持在当前四相派生模型和当前目标函数下，将`tau_AI=1.25/1.75us`的folded probes作为经过dense成对校准的局部候选。” | “R036证明folded band全局最优、硬件安全，或AI/proxy可直接替代dense fallback和IQCOT内环。” |
<!-- R037_SHORT_HORIZON_RHAT -->

### C33 / R037: short-horizon `r_hat` predictor prototype -- final sync

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R037 organizes the local R031/R033/R034/R036 derived-Simulink evidence into a deployable-style `r_hat(skip,settling,phase)` risk interface and a next-round minimal boundary validation matrix. | `iqcot_r037_short_horizon_rhat_predictor.py`; `iqcot_r037_rhat_training_dataset.csv`; `iqcot_r037_rhat_loto_eval.csv`; `iqcot_r037_rhat_policy_context_eval.csv`; `iqcot_r037_minimal_extrapolation_validation_plan.csv`; `fig50_r037_short_horizon_rhat.svg`. Current local replay: dense fallback mean regret `1.116`, folded `q_phi` prior `0.020`, final R037 projection `0.000`, posterior safe upper-bound `0.054`, with `1` oracle rejected by the leave-one-delay gate. | Medium-low; mainly post-processing, interface design, and local consistency evidence. | "R037 supports converting PIS-IEK event risks into a `q_phi/r_hat/B_epsilon^sw` supervisory interface and identifies a 9-row minimal extrapolation validation plan." | "R037 has trained a generalizable AI controller, proven hardware safety, proven a global folded-band optimum, or shown that AI replaces the IQCOT inner loop." |

### C33 / R037：short-horizon `r_hat` predictor prototype

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R037把R031/R033/R034/R036的局部派生Simulink结果整理为短时`r_hat(skip,settling,phase)`风险预测接口，并生成下一轮最小边界验证矩阵 | `iqcot_r037_short_horizon_rhat_predictor.py`; `iqcot_r037_rhat_training_dataset.csv`; `iqcot_r037_rhat_loto_eval.csv`; `iqcot_r037_rhat_policy_context_eval.csv`; `iqcot_r037_minimal_extrapolation_validation_plan.csv`; `fig50_r037_short_horizon_rhat.svg` | 中等偏弱，主要是后处理/接口设计证据 | “R037支持将PIS-IEK事件风险降级为可部署风格的`q_phi/r_hat/B_epsilon^sw`监督层接口，并指出需要继续做最小外推验证。” | “R037已经训练出可泛化AI控制器、证明硬件安全、或证明folded band全局最优。” |

<!-- R038_MINIMAL_EXTRAPOLATION_VALIDATION -->

### C34 / R038: minimal extrapolation derived-Simulink validation

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R038 validates the local robustness of the R037 folded-band anchors and revises the `tau_AI=2us` foldback rule into a near-tie band. | `iqcot_r037_minimal_extrapolation_validation.m` executed 9/9 derived-Simulink delayed-reference cases; `iqcot_r038_minimal_extrapolation_context_summary.csv`; `iqcot_r038_foldback_rule_update.csv`; `fig51_r038_minimal_extrapolation.svg`. Results: `42/44us` do not beat `46us@1.25us`; `46/54us` do not beat `50us@1.5us`; `52/56us` do not beat `54us@1.75us`; `48us@2.0us` beats `30us` by only about `0.020` score. | Medium; all 9 planned derived-Simulink cases completed, but the evidence is still local and model-derived. | "R038 supports keeping `46/50/54us` as local folded anchors and rewriting `tau_AI=2us` as a `30/44/48us` near-tie foldback band with dense fallback retained." | "R038 proves hardware safety, global `T_slew` optimality, or that `48us` should replace dense fallback in all contexts." |

<!-- R039_PR_ECB_LARGE_SIGNAL -->

### C35 / R039: PR-ECB 大信号第一峰风险边界

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R039 建立了 PR-ECB 大信号第一峰风险特征 r_E 的第一版派生 Simulink 验证接口，并说明它与 PIS-IEK 小信号恢复模型职责不同。 | output/iqcot_r039_pr_ecb_large_signal_probe.m；5/5 行 derived-Simulink delayed-reference 验证成功；output/iqcot_r039_pr_ecb_large_signal_results_combined.csv；output/iqcot_r039_pr_ecb_large_signal_summary.csv；5 个 output/data/*_r039_pr_ecb_wave.csv 波形快照。当前 40A->20A 结果：能量边界 4.350 mV，电荷+ESR 边界 3.903 mV，实际派生 Simulink 第一峰 2.235 mV，10 mV allowance 下 r_E=0.435。 | 中等偏弱；脚本和 5 行派生模型证据已完成，但仍是单一负载步进、单一切载相位附近的离线后处理验证。 | “R039 支持把 PR-ECB 写成第一峰风险特征和安全边界，用来补充 PIS-IEK 的 post-peak 事件恢复建模。” | “R039 证明硬件第一峰、HIL 安全、PIS-IEK 可精确预测大切载第一峰，或 PR-ECB 可替代 T_slew/r_hat/B_epsilon 的恢复阶段策略。” |

<!-- R042_PR_ECB_PHASE_DENSE_FULL -->

### C39 / R042 full: segmented PR-ECB high-side boundary calibration

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| The completed R042 phase-dense matrix supports a segmented PR-ECB calibration feature: phase-4 remaining high-side on-time has a consistent boundary across load magnitudes, while the dominant bound changes with load-drop magnitude. | `output/iqcot_r042_pr_ecb_phase_dense_calibration.m`; `output/iqcot_r042_pr_ecb_phase_dense_postprocess.py`; `output/iqcot_r042_pr_ecb_phase_dense_results_combined.csv`; `output/iqcot_r042_pr_ecb_phase_dense_summary.csv`; `output/iqcot_r042_pr_ecb_phase_dense_report.md`; 20/20 derived-Simulink rows completed. Remaining high-side on-time is `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` from `0.105 us` onward for near0/5A/10A/20A. Final `r_E(max corrected)` ranges: near0 `0.895-0.983`, 5A `0.760-0.839`, 10A `0.619-0.705`, 20A `0.516-0.602`. | Medium; full planned derived-Simulink matrix completed, but still one derived model and offline PR-ECB post-processing only. | "R042 supports a phase-state and load-magnitude segmented PR-ECB calibration rule: use active-HS remaining-on-time as a segmentation feature, with charge+ESR dominant for near0/5A and energy/corrected-energy dominant for most 10A/20A rows." | "R042 proves hardware/HIL safety, global PR-ECB calibration, or a universal additive `E_HS,rem` law." |

<!-- R043_PR_ECB_SEGMENTED_CALIBRATION -->

### C40 / R043: segmented PR-ECB calibration surface

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R043 converts the completed R040/R041/R042 first-peak evidence into a segmented PR-ECB calibration surface over load-drop magnitude, active high-side remaining-on-time, and dominant bound class. | `output/iqcot_r043_pr_ecb_segmented_calibration.py`; `output/iqcot_r043_pr_ecb_segmented_rows.csv`; `output/iqcot_r043_pr_ecb_segmented_rules.csv`; `output/iqcot_r043_pr_ecb_segmented_report.md`; `output/iqcot_r043_pr_ecb_segmented_paper_section.md`. The merged dataset has 28 rows and 6 rule segments. near0/5A charge+ESR bands: r_E `0.760-0.993`, bound/actual `1.522-1.701`. 10A transition bands: r_E `0.587-0.729`, bound/actual `1.737-1.853`. 20A energy/corrected-energy bands: r_E `0.409-0.626`, bound/actual `1.820-2.870`. | Medium; it integrates completed derived-Simulink evidence, but remains offline post-processing on one derived model. | "R043 supports writing PR-ECB as a segmented supervisory first-peak risk feature: charge+ESR for near0/5A, active-HS corrected energy versus post-turnoff raw energy for 10A transition rows, and energy/corrected-energy for 20A with explicit conservatism." | "R043 proves hardware/HIL safety, global PR-ECB calibration, a universal additive `E_HS,rem` law, global `T_slew` optimality, or that AI replaces the IQCOT inner loop." |

<!-- R046_DIRECTION_REVISION_AFTER_USER_FEEDBACK -->

### C41 / R046: revised control-centered research direction

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| The active research direction should shift from AI/`T_slew`-centered scheduling to control-centered IQCOT research: PR-ECB cut-load voltage stabilization, PIS-IEK steady-state current sharing, and variable-phase add/shed hybrid event management. | User feedback on 2026-06-24; `C:/Users/zengruize/Downloads/iqcot_research_direction_guidance_after_repo_review.md`; `docs/research_direction_after_user_feedback_20260624.md`; `docs/auto_research_plan_after_feedback_20260624.md`; existing R039-R043 PR-ECB evidence; existing IEK/PIS-IEK actuator-classification evidence. | High as project-direction correction; future validation still required for the new control actions. | "The next stage uses PR-ECB to guide cut-load protection actions, PIS-IEK to guide steady-state balance and phase recovery, and active phase set modeling to support add/shed phase logic." | "`T_slew` controls the external load-current slew rate; AI is the present main control contribution; PIS-IEK precisely predicts all large-signal first peaks; PR-ECB or the revised framework is already hardware/HIL validated." |

<!-- R047_AI_READY_MODEL_INNOVATION -->

### C42 / R047: AI-ready guarded large/small-signal model interface

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R047 proposes GAE-IQCOT, a guarded AI-ready event model that exposes PR-ECB large-signal peak-risk guards, PIS-IEK small-signal balance/reentry maps, active-phase hybrid event maps, and a safety projection interface for AI/table/MPC supervision. | `docs/ai_control_oriented_model_innovation_20260624.md`; `docs/control_state_machine_after_feedback.md`; `refine-logs/LOCAL_AUDIT_R047_AI_READY_MODEL_INNOVATION_20260624.md`; R046 direction correction; R039-R043 PR-ECB evidence; existing PIS-IEK actuator-classification evidence. | Medium as a research-design contribution; controller implementation and ablation simulations are still required. | "R047 reframes AI as a constrained supervisory layer: AI proposes low-dimensional protection, balance, and active-phase tokens, and the model projects them into a safe action set before they affect the IQCOT inner loop." | "R047 proves an AI controller, hardware/HIL safety, global PR-ECB calibration, direct neural gate control, or control over the external load-current slew rate." |

<!-- R047B_ADAPTIVE_VALIDATION_AUTOMATION -->

### C43 / R047B: adaptive validation must revise the model innovation

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| Future automated validation should be run as an adaptive loop that can revise GAE-IQCOT, PR-ECB, PIS-IEK, active-phase guards, and claim boundaries after each validation chunk. | User instruction on 2026-06-24; `docs/adaptive_validation_automation_20260624.md`; updates to `docs/auto_research_plan_after_feedback_20260624.md`, `docs/ai_control_oriented_model_innovation_20260624.md`, and `docs/control_state_machine_after_feedback.md`; `refine-logs/LOCAL_AUDIT_R047B_ADAPTIVE_VALIDATION_AUTOMATION_20260624.md`. | High as automation/process rule; not itself a converter-performance validation. | "Each validation chunk should end in `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`, and any contradiction must update the model innovation and evidence matrix before the next chunk." | "The automation has already validated the revised controller, proven hardware/HIL performance, or should continue full-grid simulation even when early chunks contradict the model." |

<!-- R048_MODEL_WIRING_AUDIT -->

### C44 / R048: derived model wiring preflight

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R048 confirms the existing derived `four_phase_iek_dynamic_load_refslew.slx` wiring is sufficiently understood to plan the next derived-control copy: active `REQ` comes from `IEK_PerPhase_Request`, the scheduler exposes `phase_idx`, the Ton adapter feeds COT cells, and the main plant/gate/current tap points are identifiable. | `docs/model_wiring_audit_after_r047.md`; `refine-logs/LOCAL_AUDIT_R048_MODEL_WIRING_20260624.md`; read-only MATLAB `load_system/find_system/get_param` preflight. Actual paths include `IEK_PerPhase_Request -> Goto14(tag=REQ)`, `PhaseScheduler_4Phase`, `IQCOT_Ton_Adapter/Ton_Base`, `Ton_Limit1..4`, `Ton_trim1..4`, `IL_Measurement1..4`, `Voltage Measurement`, `GateDriver_1Phase1..4`, `LoadCurrentStep`, and `Dynamic Load Current Source`. Parameter bindings for MOSFET `Ron`, `L/DCR`, `Cout/ESR`, `Ton`, `Tblank`, `Toff_min`, and `Tdead` are variable references rather than hard-coded literals. | Medium as implementation preflight; no new switching validation and no hardware/HIL evidence. | "R048 supports proceeding to a MATLAB-API-built derived-control copy with explicit variable injection and expanded logging for PR-ECB/PIS-IEK validation." | "R048 proves PR-ECB protection performance, hardware/HIL safety, complete controller implementation, global PR-ECB calibration, a universal `E_HS,rem` law, or that AI replaces the IQCOT inner loop." |

<!-- R049A_PR_ECB_SCAFFOLD -->

### C45 / R049A: PR-ECB derived-control scaffold

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049A confirms that a PR-ECB derived-control scaffold can be built through MATLAB APIs from the R048-audited model, with expanded logging and no-op protection-token placeholders, while leaving original and source derived `.slx` files untouched. | `output/iqcot_r049_build_pr_ecb_control_model.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx`; `docs/pr_ecb_control_derived_model_plan_r049.md`; `refine-logs/LOCAL_AUDIT_R049A_PR_ECB_SCAFFOLD_20260624.md`. Logged signals include `vout`, `req_global`, `phase_idx`, `il1..4`, `qh1..4`, `ql1..4`, `ton_iqcot1..4`, `ton_done1..4`, `nqmin1..4`, `current_limit1..4`, and placeholders `protect_state`, `r_p`, `ton_truncate1..4`, `pulse_inhibit1..4`, `hold_int1..4`, `reset_int1..4`. Non-simulation update-diagram preflight passed: `UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control`. | Medium as implementation scaffolding; no protection action or switching-performance validation yet. | "R049A supports moving to the smallest derived-copy PR-ECB protection chunk because the observability and action-token scaffold now exists and updates with explicit variable injection." | "R049A proves overshoot reduction, hardware/HIL safety, complete PR-ECB control, global calibration, a universal `E_HS,rem` law, or that AI replaces IQCOT inner-loop pulse generation." |

<!-- R049B_PR_ECB_MINIMAL_OVSKIP -->

### C46 / R049B: simple over-voltage skip minimal chunk

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049B shows that simple over-voltage request skip can be inserted in a new derived copy and can inhibit post-threshold IQCOT requests, but in the tested near0 two-offset chunk it does not reduce the large-signal first peak. | `output/iqcot_r049b_build_ovskip_model.m`; `output/iqcot_r049b_pr_ecb_minimal_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx`; `output/cutload_pr_ecb_control/r049b_ovskip_minimal_results_full.csv`; `output/cutload_pr_ecb_control/r049b_ovskip_minimal_comparison_full.csv`; `docs/pr_ecb_control_minimal_chunk_r049b.md`; `refine-logs/LOCAL_AUDIT_R049B_PR_ECB_MINIMAL_20260624.md`. For `40A -> 1A near0`, offsets `0.05 us` and `0.105 us`, A1 inhibited new requests for `18.8800 us` / `19.8160 us` and blocked `19` / `20` REQ edges, but A0 and A1 peaks were identical: `6.2586 mV` and `5.9603 mV`. Decision: `CLAIM_DOWNGRADED`. | Medium-low; real derived-Simulink switching chunk with a single action and two offsets, but intentionally not a full matrix and not hardware/HIL. | "R049B supports treating simple OV skip as a post-threshold request-inhibit / `SKIP_HOLD` mechanism. First-peak suppression should be tested next with Ton truncation or active-HS remaining-on-time truncation." | "R049B proves PR-ECB overshoot reduction, validates simple OV skip as first-peak protection, proves hardware/HIL safety, completes PR-ECB control, establishes global calibration, or validates a universal additive `E_HS,rem` law." |

<!-- R049C_PR_ECB_MINIMAL_TONTRUNC -->

### C47 / R049C: command-path Ton truncation minimal chunk

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049C shows that command-path Ton truncation can reduce first peak in an active-HS near0 cut-load offset while leaving a post-turnoff offset unchanged, supporting the PR-ECB phase-state action hierarchy. | `output/iqcot_r049c_build_tontrunc_model.m`; `output/iqcot_r049c_pr_ecb_tontrunc_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049c_tontrunc.slx`; `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_results_full.csv`; `output/cutload_pr_ecb_control/r049c_tontrunc_minimal_comparison_full.csv`; `docs/pr_ecb_control_tontrunc_chunk_r049c.md`; `refine-logs/LOCAL_AUDIT_R049C_PR_ECB_TONTRUNC_20260624.md`. For `40A -> 1A near0`, at `0.05 us` A2 reduced peak from `6.2586 mV` to `5.4926 mV` and reduced phase-4 remaining Ton from about `52 ns` to about `2 ns`; at `0.105 us`, remaining Ton was `0 ns` and peak stayed `5.9603 mV`. Decision: `MODEL_CONFIRMED`. | Medium-low to medium; real derived-Simulink switching chunk with one action and two offsets, still not a full matrix and not hardware/HIL. | "R049C supports treating Ton truncation as the first confirmed active-HS first-peak energy-reduction action, while keeping OV skip as skip-hold/reentry logic. The effect is phase-state selective and should be hold-out validated before full-grid claims." | "R049C proves hardware/HIL safety, complete PR-ECB control, global calibration, improvement at all phase offsets/load drops, or a universal additive `E_HS,rem` law." |

<!-- R049D_PR_ECB_TONTRUNC_HOLDOUT -->

### C48 / R049D: command-path Ton truncation hold-out chunk

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049D hold-out confirms that the R049C command-path Ton-truncation mechanism also reduces first peak for a `40A -> 10A` active-HS offset while leaving the post-turnoff offset unchanged. | `output/iqcot_r049d_build_tontrunc_holdout_model.m`; `output/iqcot_r049d_pr_ecb_tontrunc_holdout_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout.slx`; `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_results_full.csv`; `output/cutload_pr_ecb_control/r049d_tontrunc_holdout_comparison_full.csv`; `docs/pr_ecb_control_tontrunc_holdout_r049d.md`; `refine-logs/LOCAL_AUDIT_R049D_PR_ECB_TONTRUNC_HOLDOUT_20260624.md`. For `40A -> 10A`, at `0.05 us` A2 reduced peak from `3.9908 mV` to `3.3873 mV`, shortened phase-4 remaining Ton from about `52 ns` to about `2 ns`, and improved secondary undershoot by `2.0279 mV`; at `0.105 us`, remaining Ton was `0 ns` and peak stayed `3.7607 mV`. Decision: `MODEL_CONFIRMED`. | Medium; a second real derived-Simulink switching chunk confirms the same phase-state-selective action on a hold-out load magnitude, but still not a full A matrix and not hardware/HIL. | "R049D supports saying that Ton truncation is confirmed as an active-HS first-peak energy-reduction action in two small chunks: near0 and 10A targets at the same active-HS/post-turnoff offset pair. Keep the effect phase-state bounded." | "R049D proves hardware/HIL safety, complete PR-ECB control, global calibration, improvement at all phase offsets/load drops, safe reentry behavior, or a universal additive `E_HS,rem` law." |

<!-- R049E_PR_ECB_TONTRUNC_MILD_HOLDOUT -->

### C49 / R049E: command-path Ton truncation mild hold-out

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049E shows that the current over-voltage-triggered command-path Ton-truncation mechanism does not generalize to the mild `40A -> 20A` active-HS hold-out; trigger timing, not only phase state, is required for first-peak action claims. | `output/iqcot_r049e_build_tontrunc_holdout_model.m`; `output/iqcot_r049e_pr_ecb_tontrunc_holdout_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout.slx`; `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_results_full.csv`; `output/cutload_pr_ecb_control/r049e_tontrunc_holdout_comparison_full.csv`; `docs/pr_ecb_control_tontrunc_mild_holdout_r049e.md`; `refine-logs/LOCAL_AUDIT_R049E_PR_ECB_TONTRUNC_MILD_HOLDOUT_20260624.md`. For `40A -> 20A`, at `0.05 us` A0 and A2 peaks were both `2.1103 mV`; phase-4 remaining Ton stayed about `52 ns`. The A2 trunc flag asserted for `0.5180 us`, but first asserted around `0.228 us` after the load step when `qh4=0`. At `0.105 us`, A0/A2 peaks were both `2.0936 mV`. Decision: `CLAIM_DOWNGRADED`. | Medium; real derived-Simulink switching chunk and waveform audit, but still one mild hold-out and no hardware/HIL. | "R049E narrows the Ton-truncation claim: R049C/R049D support larger-drop active-HS benefit, but the present over-voltage trigger can be too late for mild `40A -> 20A`. Future claims need both phase-state and trigger-timing guards." | "R049E proves Ton truncation is ineffective in all mild drops, invalidates R049C/R049D, proves hardware/HIL safety, completes PR-ECB control, or validates a universal additive `E_HS,rem` law." |

<!-- R049F_PR_ECB_EARLY_TONTRUNC -->

### C50 / R049F: early Ton truncation trigger-timing diagnostic

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049F shows that early load-step-synchronous Ton truncation can remove the mild-load active high-side remaining on-time, but a global all-phase early Ton-min action is over-aggressive and causes severe undervoltage; the PR-ECB action must become phase-selective / active-HS-only. | `output/iqcot_r049f_build_early_tontrunc_model.m`; `output/iqcot_r049f_pr_ecb_early_tontrunc_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx`; `output/cutload_pr_ecb_control/r049f_early_tontrunc_results_full.csv`; `output/cutload_pr_ecb_control/r049f_early_tontrunc_comparison_full.csv`; `docs/pr_ecb_control_early_trigger_r049f.md`; `refine-logs/LOCAL_AUDIT_R049F_PR_ECB_EARLY_TONTRUNC_20260624.md`. For `40A -> 20A` at `0.05 us`, A2 reduced phase-4 remaining Ton from about `52 ns` to `0 ns`, but produced `-184.1030 mV` peak metric and `-239.1723 mV` final error. At `0.105 us`, global early truncation produced `-189.3089 mV` peak metric and `-241.9473 mV` final error. Decision: `MODEL_REVISED`. | Medium; real derived-Simulink trigger-timing diagnostic with structural model change and waveform evidence, but still not hardware/HIL or a usable controller. | "R049F supports revising PR-ECB from global early Ton-min truncation to phase-selective active-HS-only truncation. It confirms R049E's trigger-lateness diagnosis while rejecting global all-phase early action." | "R049F proves a safe controller, validates global early Ton truncation, proves hardware/HIL safety, completes PR-ECB control, or establishes a universal additive `E_HS,rem` law." |

R049G erratum for C50: R049G later found `R049C_After_LoadStep/2` unconnected in the inherited model, so the R049F over-voltage-free early window started at simulation time zero. Treat the severe R049F undervoltage as an implementation-timing artifact; use C51/R049G for the repaired phase-selective interpretation.

<!-- R049G_PR_ECB_PHASE_SELECTIVE_TONTRUNC -->

### C51 / R049G: repaired phase-selective Ton truncation diagnostic

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049G shows that repairing the early-window lower bound and applying phase-selective active-HS Ton-min truncation structurally removes remaining phase-4 Ton in the mild `40A -> 20A` active-HS row, but does not improve the first-peak metric; hard active-HS Ton-min truncation remains a revised, unconfirmed PR-ECB action. | `output/iqcot_r049g_build_phase_selective_tontrunc_model.m`; `output/iqcot_r049g_pr_ecb_phase_selective_tontrunc_chunk.m`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx`; `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_results_full.csv`; `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_comparison_full.csv`; `output/cutload_pr_ecb_control/r049g_phase_selective_tontrunc_report_full.md`; `docs/pr_ecb_control_phase_selective_tontrunc_r049g.md`; `refine-logs/LOCAL_AUDIT_R049G_PR_ECB_PHASE_SELECTIVE_TONTRUNC_20260624.md`. R049G connected `R049G_LoadStep_Time = t_load_step` to `R049C_After_LoadStep/2`, correcting the R049F/R049G pre-repair artifact where the early window started at simulation time zero. In the repaired `40A -> 20A` chunk, at `0.05 us` A2 reduced phase-4 remaining Ton from about `52 ns` to about `2 ns` but worsened first peak from `2.1103 mV` to `2.3879 mV`; at `0.105 us` A2 matched A0 at `2.0936 mV`. Decision: `MODEL_REVISED`. | Medium; real derived-Simulink switching chunk with a repaired structural timing issue and four true-run rows, but still one mild load chunk and no hardware/HIL. | "R049G supports saying that phase-state gating is necessary but insufficient: hard active-HS Ton-min truncation can remove remaining Ton, yet it must be evaluated against early local spike and recovery-peak metrics before being used as a PR-ECB action." | "R049G proves phase-selective Ton truncation is safe, proves a complete PR-ECB controller, validates hardware/HIL behavior, establishes global calibration, or validates a universal additive `E_HS,rem` law." |

<!-- R049H_PR_ECB_WAVEFORM_METRIC -->

### C52 / R049H: offline waveform-metric audit for PR-ECB action acceptance

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049H shows that PR-ECB Ton-truncation evidence must be segmented into early local peak, recovery peak, and late settling/undershoot windows; this narrows R049D's claim and rejects hard phase-selective Ton-min as a confirmed mild-load action. | `output/iqcot_r049h_waveform_metric_audit.py`; `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`; `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`; `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`; `docs/pr_ecb_waveform_metric_audit_r049h.md`; `refine-logs/LOCAL_AUDIT_R049H_PR_ECB_WAVEFORM_METRIC_20260624.md`. R049H reused existing R049C/R049D/R049E/R049F/R049G wave CSV exports and ran no new switching simulation. Active-HS results: R049C near0 improves early/recovery peaks by `0.7660/1.0047 mV`; R049D 10A improves early peak by `0.6036 mV` but recovery/late positive peaks are `-0.0323/-0.0045 mV`; R049E 20A OV-triggered action has no window-level effect; R049G repaired phase-selective hard Ton-min worsens early/recovery peaks by `0.2902/0.0476 mV`. Decision: `MODEL_REVISED`. | Medium as offline waveform post-processing over completed derived-Simulink chunks; no new model or hardware/HIL evidence. | "R049H supports making PR-ECB action acceptance windowed: preserve `J_early_peak`, `J_recovery_peak`, and late undershoot metrics separately. Ton truncation remains useful for R049C near0 and partly for R049D early peak, but hard phase-selective Ton-min is not confirmed for mild 20A." | "R049H proves hardware/HIL safety, complete PR-ECB control, global calibration, that hard Ton-min is safe, or that `E_HS,rem` is a universal additive law." |

<!-- R049I_PR_ECB_GENTLE_TONTRIM -->

### C53 / R049I: gentle phase-selective Ton-trim diagnostic

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049I shows that a gentler `120 ns` phase-selective Ton floor still fails the R049H early-local-peak gate for the mild `40A -> 20A` active-HS row because the active phase has already been on for about `144.5 ns`; Ton-min/Ton-floor variants should stop and the next PR-ECB action should move to deferred post-active pulse inhibit or controlled reentry. | `output/iqcot_r049i_build_gentle_tontrim_model.m`; `output/iqcot_r049i_pr_ecb_gentle_tontrim_chunk.m`; `output/iqcot_r049i_waveform_metric_audit.py`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049i_gentle_tontrim.slx`; `output/cutload_pr_ecb_control/r049i_gentle_tontrim_results_full.csv`; `output/cutload_pr_ecb_control/r049i_gentle_tontrim_comparison_full.csv`; `output/cutload_pr_ecb_control/r049i_waveform_metric_pair_delta.csv`; `output/cutload_pr_ecb_control/r049i_waveform_metric_summary.md`; `docs/pr_ecb_gentle_tontrim_r049i.md`; `refine-logs/LOCAL_AUDIT_R049I_PR_ECB_GENTLE_TONTRIM_20260624.md`. R049I inspected the R049G baseline Ton trace before choosing the floor: `Ton_cmd4=196.5 ns`, remaining Ton4 about `52 ns`, elapsed on-time about `144.5 ns`. At `0.05 us`, A2 reduced remaining Ton4 to about `2 ns` but worsened early/recovery/late peaks by `0.2902/0.0476/0.0866 mV`; at `0.105 us`, A2 matched A0. Decision: `MODEL_REVISED`. | Medium; real derived-Simulink switching chunk with four true-run rows and explicit windowed audit, but still one mild load case and no hardware/HIL. | "R049I supports saying that whole-pulse Ton floors are the wrong action family once elapsed active on-time already exceeds the proposed floor. Stop scanning Ton floors and test deferred inhibit/reentry actions under the R049H windowed metric gate." | "R049I proves Ton trim is universally unsafe, proves hardware/HIL behavior, validates a complete PR-ECB controller, establishes global calibration, or validates a universal additive `E_HS,rem` law." |

<!-- R049J_PR_ECB_POST_ACTIVE_INHIBIT -->

### C54 / R049J: deferred post-active pulse inhibit diagnostic

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049J shows that request-path post-active inhibit can avoid truncating the current active-HS pulse, but a hard `0.070-2.000 us` inhibit window creates recovery undershoot penalties; the next PR-ECB action needs controlled reentry / soft request restoration. | `output/iqcot_r049j_build_post_active_inhibit_model.m`; `output/iqcot_r049j_pr_ecb_post_active_inhibit_chunk.m`; `output/iqcot_r049j_waveform_metric_audit.py`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049j_post_active_inhibit.slx`; `output/cutload_pr_ecb_control/r049j_post_active_inhibit_results_full.csv`; `output/cutload_pr_ecb_control/r049j_post_active_inhibit_comparison_full.csv`; `output/cutload_pr_ecb_control/r049j_waveform_metric_pair_delta.csv`; `output/cutload_pr_ecb_control/r049j_waveform_metric_summary.md`; `docs/pr_ecb_post_active_inhibit_r049j.md`; `refine-logs/LOCAL_AUDIT_R049J_PR_ECB_POST_ACTIVE_INHIBIT_20260625.md`. At `0.05 us`, remaining Ton4 stayed `52 ns -> 52 ns` and Ton-trunc duration was `0 us`, confirming no current-pulse truncation. A2 blocked one future request and improved positive recovery peaks, but recovery undershoot worsened by `-2.9901 mV` at `0.05 us` and `-4.1571 mV` at `0.105 us`. Decision: `MODEL_REVISED`. | Medium; real derived-Simulink switching chunk with four true-run rows and windowed audit, but still one mild load case and no hardware/HIL. | "R049J supports moving PR-ECB from active-pulse Ton floors to request-path/reentry actions, but says fixed hard post-active inhibit is too aggressive. Next claims should focus on controlled reentry with explicit recovery-undershoot penalty." | "R049J proves fixed post-active inhibit is safe, proves hardware/HIL behavior, validates a complete PR-ECB controller, establishes global calibration, or validates a universal additive `E_HS,rem` law." |

<!-- R049K_PR_ECB_SOFT_REENTRY -->

### C55 / R049K: short soft-reentry proxy diagnostic

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R049K shows that shortening request-path restoration from R049J's hard `0.070-2.000 us` inhibit to a `0.070-1.760 us` soft-reentry proxy reduces recovery undershoot penalties while preserving no-current-pulse-truncation, but a fixed scalar window still trades off recovery peak, undershoot, and late peak metrics. | `output/iqcot_r049k_build_soft_reentry_model.m`; `output/iqcot_r049k_pr_ecb_soft_reentry_chunk.m`; `output/iqcot_r049k_waveform_metric_audit.py`; `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049k_soft_reentry.slx`; `output/cutload_pr_ecb_control/r049k_soft_reentry_results_full.csv`; `output/cutload_pr_ecb_control/r049k_soft_reentry_comparison_full.csv`; `output/cutload_pr_ecb_control/r049k_waveform_metric_pair_delta.csv`; `output/cutload_pr_ecb_control/r049k_waveform_metric_summary.md`; `docs/pr_ecb_soft_reentry_r049k.md`; `refine-logs/LOCAL_AUDIT_R049K_PR_ECB_SOFT_REENTRY_20260625.md`. At `0.05 us`, remaining Ton4 stayed `52 ns -> 52 ns`. Recovery positive-peak improvements were `+0.1796/+0.1954 mV`; recovery undershoot penalties were reduced versus R049J but remained `-0.6388/-1.6588 mV`; late positive peaks slightly worsened. Decision: `MODEL_REVISED`. | Medium; real derived-Simulink switching chunk with four true-run rows and windowed audit, but still one mild load case and no hardware/HIL. | "R049K supports saying that soft reentry should become an explicit state-machine action rather than a fixed scalar inhibit window. The useful direction is edge-aligned or phase-aware request restoration with an explicit recovery-undershoot penalty." | "R049K proves short soft reentry is safe, proves hardware/HIL behavior, validates a complete PR-ECB controller, establishes global calibration, or validates a universal additive `E_HS,rem` law." |

<!-- R042_PR_ECB_PHASE_DENSE_PARTIAL -->

### C38 / R042: PR-ECB phase-dense high-side boundary validation

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R042 partial validation localizes the phase-4 high-side turn-off boundary and supports using `E_HS,rem` as a phase-state segmentation feature, while charge+ESR remains the dominant near0/5A first-peak bound. | `output/iqcot_r042_pr_ecb_phase_dense_calibration.m`; `output/iqcot_r042_pr_ecb_phase_dense_postprocess.py`; `output/iqcot_r042_pr_ecb_phase_dense_plan.csv` with 20 planned rows; completed true-runs `rows001_004` and `rows006_009`; `output/iqcot_r042_pr_ecb_phase_dense_results_combined.csv`; `output/iqcot_r042_pr_ecb_phase_dense_summary.csv`; `output/iqcot_r042_pr_ecb_phase_dense_report.md`. Remaining on-time is `52 ns` at `0.05 us`, `12 ns` at `0.09 us`, and `0 ns` at `0.105/0.125 us` for near0 and 5A. near0 `r_E(max corrected)` spans `0.952-0.983`; 5A spans `0.812-0.839`. | Medium-low; 8/20 planned derived-Simulink rows completed, still partial and model-derived. | "R042 partial supports a discrete phase-state feature around high-side turn-off and motivates continuing 10A/20A rows before fitting segmented PR-ECB calibration." | "R042 proves global calibration, hardware/HIL safety, or that `E_HS,rem` should be added universally to the PR-ECB max-bound." |

<!-- R041_PR_ECB_HSREM_CORRECTION -->

### C37 / R041: PR-ECB remaining high-side on-time correction

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R041 shows that `E_HS,rem` is useful as a phase-state diagnostic and segmented energy-bound feature, but not yet as a globally validated additive correction law. | `output/iqcot_r041_pr_ecb_hsrem_correction.py`; `output/iqcot_r041_pr_ecb_hsrem_results.csv`; `output/iqcot_r041_pr_ecb_hsrem_summary.csv`; `output/iqcot_r041_pr_ecb_hsrem_report.md`. It reuses the completed 8 R040 rows, infers `L=0.2 uH` and `Cout=7.26 mF`, and finds nonzero `E_HS,rem` only in the three offset-0 rows where phase 4 has about `102 ns` remaining high-side on-time. The correction changes the near0 offset-0 energy-only ratio from `0.876x` to `1.169x`, while original `max(energy, charge+ESR)` was already conservative for all 8 rows. | Medium-low; offline post-processing of derived-Simulink R040 rows, no new switching run and no hardware/HIL evidence. | "R041 supports including remaining high-side on-time in the PR-ECB phase-state feature set and using it for segmented calibration, especially to avoid energy-only under-estimation in active-HS large cut-load cases." | "R041 proves a global PR-ECB correction law, hardware safety, HIL validity, or that the corrected max-bound should replace all previous charge+ESR safeguards." |

<!-- R040_PR_ECB_PHASE_LOAD_CALIBRATION -->

### C36 / R040: PR-ECB phase/load calibration

| Claim | Evidence | Strength | Safe wording | Do not claim |
|---|---|---|---|---|
| R040 初步校准表明 PR-ECB 第一峰风险对切载相位和负载幅度敏感，R039 的保守系数不能直接视为常数。 | output/iqcot_r040_pr_ecb_phase_load_calibration.m；8/8 行 derived-Simulink true-run 成功；output/iqcot_r040_pr_ecb_phase_load_results_combined.csv；output/iqcot_r040_pr_ecb_phase_load_summary.csv；output/iqcot_r040_pr_ecb_phase_load_report.md；8 个 output/data/*_r040_pr_ecb_wave.csv。20A 相位偏移 sweep 中 r_E 从 0.409 到 0.565；10A 中 r_E 从 0.587 到 0.678；near0 中 r_E 从 0.858 到 0.993，且 charge+ESR 成为 dominant bound。near0 offset-0 显示 energy-only 低于实际峰值，说明不能只用能量边界。 | 中等；8 行派生模型已覆盖 20A/10A/near0 和 0/0.25us 相位点，但仍是单一模型、少量相位、离线后处理证据。 | “R040 支持 PR-ECB 必须包含 phase-resolved state 和 load-drop magnitude，并提示保守系数需要按相位/幅度分段校准；当前应保留 max(energy, charge+ESR) 边界。” | “R040 证明 PR-ECB 已完成全局校准、硬件安全、HIL 验证，或可以替代 PIS-IEK/r_hat/B_epsilon 的峰后恢复逻辑。” |
