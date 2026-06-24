# 四相数字 IQCOT 小信号创新建模研究简报

## 研究方向

面向四相交错 Buck/VRM 的数字 IQCOT 控制，研究一种带相位调度、事件积分核与切载混合事件约束的 PIS-IEK 小信号模型，并用 Simulink 开关级模型验证其对切载瞬态、相间均流、参考斜率调度和 FPGA 微秒级 AI 参数调节的指导价值。

## 当前核心假设

1. IQCOT 的相位轮转、blanking、skip/reentry 和数字参考调节使传统平均模型难以解释切载瞬态与相位偏差。
2. 在四相模型中，将事件触发、相位调度和积分核显式进入小信号模型，可比单纯平均模型更适合生成 AI 控制训练特征与安全约束。
3. AI 不替代 IQCOT 内环，而作为监督层调节参数，例如参考斜率、blanking、阈值、补偿项和轻载策略。
4. 当前最新进展是 R031：已基于 R030 dense-anchor challenge 的负样本构造 tightened `B_epsilon^sw` / short-horizon risk predictor 原型。R031 不运行新的 `.slx`，而是把 `15` 个 dense/proxy 成对上下文整理为 pair-level risk features，比较 direct proxy、dense-anchor、small-delta rule、R031 tightened projection 和 pair oracle 上界。R031 tightened projection 在校准集上的 mean regret 为 `0.132`，低于 dense-anchor `0.186` 和 direct proxy `0.574`，且不选择已标记 unsafe 的 proxy；但该结果仍是校准集候选，不是独立泛化、硬件验证或最终部署策略证明。

## 已有证据

- 开关级 Simulink sweep 已覆盖参考斜率 `T_slew = 0, 5, 10, 20, 30, 40, 50, 60, 80, 100, 120 us` 的多切载工况。
- dense + long sweep 表明参考斜率最优点随目标函数变化，适合作为 objective-sensitive scheduling variable。
- 基础目标函数与 settling-aware 目标函数下的推荐 `T_slew` 不一致，因此论文主张应强调“调度变量”，避免宣称存在固定全局最优值。
- 已完成 `tau_AI=0.5/1/2/5 us` 表驱动监督层 delayed-reference 开关级验证，共 `60` 个正延迟派生 Simulink 工况。结果表明最佳表策略同时依赖目标函数和参数提交延迟：base 目标在 `0.5/1 us` 下偏向 base-score table，在 `2/5 us` 下偏向 `alpha=0.05` table；强恢复时间惩罚在 `0.5/1/5 us` 下偏向 `alpha=0.10` table，在 `2 us` 下偏向 `alpha=0.05` table。这支持目标敏感表驱动调度，但仍不是神经网络 AI-in-loop 或硬件验证。
- 已完成 R022 可解释 score 监督层前置验证：将 `60` 个正延迟开关级 delayed-reference 工况展开为 `180` 行候选策略打分样本和 `36` 个上下文标签。leave-one-tau-out 中延迟最近邻目标表 mean regret 为 `0.304`，比固定 `40 us` 低约 `73.2%`，但仅比零延迟目标表低 `0.013`；leave-one-target-out 中零延迟目标表仍最强。这支持“可解释监督层可近似策略排序并优于固定斜率”，但不支持“AI 全面优于查表”。
- 已完成 R023 连续 `T_slew` 景观后处理：基于 dense+long sweep 的 `20-120 us` 采样区间，局部二次插值最大估计收益仅 `0.239` 分；4 个目标/目标函数组合离散网格足够，2 个适合细扫，3 个需要新开关级验证确认。这支持连续动作作为 near-optimal 区间内的平滑/安全调度变量，但不支持“连续回归大幅优于离散表”。
- 已完成 R024 局部 `T_slew` 细扫：在派生 `four_phase_iek_dynamic_load_refslew.slx` 中运行 `45` 个工况。结果支持“更细网格/连续动作有小幅价值”，但同时修正 R023 点最优假设：`20A` 的 `35 us` 最近候选因 `skip_count=1` 变差，局部更好点在 `38 us`，全细扫 settling-aware best 出现在 `66 us`；near-0A 强恢复时间惩罚目标在 `38 us` 相对旧 `30 us` 改善约 `0.235` 分。结论应写成 mode-aware near-optimal band，而不是 `34-35 us` 点最优。
- 已完成 R025 mode-aware 连续 `T_slew` 后处理：dense+long+fine 展开为 `207` 行 objective-level 样本。平滑二次模型 in-sample RMSE `0.855`，mode-aware 模型降至 `0.101`；策略比较中裸连续平均 regret `0.654`，near-optimal band clipping `0.101`，mode-aware safety projection `0.064`，dense_long 表基线 `0.163`。这支持安全投影设计，但仍不是神经网络 AI-in-loop 或硬件验证。
- 已完成 R026 可部署 risk proxy 离线重放：将 R025 的后验 `skip_count_est/phase_std/settle_time` 降级为离线校准或短时预测接口 `r_hat(z,T_slew)`。纯参数 proxy mean regret `0.857`，说明光滑 `target/load/T_slew` 回归不足；校准风险表 proxy mean regret `0.119`，低于 dense_long 表 `0.163` 和裸连续 `0.654`，但弱于后验 mode-aware projection `0.064`。这支持“可部署安全投影接口”，不支持硬件或神经网络 AI-in-loop 已完成。
- 已完成 R027 proxy table-in-loop 优先矩阵：`iqcot_r027_proxy_table_in_loop_validation.m` 分段运行全部 `48` 个派生 Simulink 工况，并由 `iqcot_r027_proxy_table_in_loop_postprocess.py` 合并后处理。优先矩阵中 dense-long table 与 posterior 上界 mean switching regret 均为 `0.025`，near-opt band 为 `0.257`，calibrated proxy 为 `0.283`；proxy 相对 dense-long 在 `0/8` 个上下文更优、`4/8` 个上下文并列、`4/8` 个上下文更差。结论应写成“proxy 接口可执行但需重标定”，不能写成“proxy 已开关级优于查表”。
- 已完成 R028 switching-calibrated proxy 重标定：`iqcot_r028_switching_calibrated_proxy.py` 重用 R027 priority switching 结果，构造 `r028_dense_anchor_proxy` 与 `r028_switching_guarded_proxy`。保守 dense-anchor 规则修复 `10A/score_settle005` 下旧 proxy 选择 `62us` 的失败，priority mean switching regret 为 `0.025`；guarded 候选加入 `10A/score_settle005/tau_AI>=2us -> 34us` 和 `near0A/score_settle010/tau_AI=0 -> 35us` 两个压力拟合 guard，在同一压力集上为 `0.000`，但需 held-out 派生 Simulink 验证。
- 已完成 R029 held-out guarded-proxy 验证：`iqcot_r029_heldout_guard_validation.m` 执行 `21` 个派生 Simulink 工况并由 `iqcot_r029_heldout_guard_postprocess.py` 合并。10A `score_settle005` 中 `tau=2.5/3us` 最优为 `34us`，支持 R028 的短斜率 delay guard；`tau=1.5us` 最优为 `40us`，说明 guard 不应外推到 2us 以下。near0A `score_settle010` 中 `tau=0/0.25us` 最优为 `38us`，`tau=0.5us` 最优为 `30us`，因此 near0A 应写成 `30-38us` 局部安全带而非固定 `35us` guard。旧 `62us` proxy failure probe 的 mean regret 为 `0.806`。
- 已完成 R030 refined-band policy 合成：`iqcot_r030_refined_band_policy.py` 后处理 R027/R028/R029，不运行新 `.slx`。离线 consistency replay 中 R030 mean regret 为 `0.104`，R028 guarded 为 `0.106`，dense-anchor 为 `0.099`；已知 guard-context 切换证据合成中 R030 选中行 mean switching regret 为 `0.000`，dense-anchor 为 `0.128`。R030 还从 R027 完整 `315` 行计划中筛出 `24` 个 dense/proxy 非优先分歧上下文，其中 `20` 个离线 proxy 更优，并生成 `30` 行 dense/proxy 成对挑战计划。
- 已完成 R030 dense-anchor challenge 派生 Simulink 回放：`30` 行 dense/proxy 成对工况全部成功，并由 `iqcot_r030_dense_anchor_challenge_postprocess.py` 合并重算完整上下文 regret。结果不支持“dense-anchor 普遍过保守”的强结论：在 `15` 个成对上下文中 proxy 胜 `7` 个、dense-anchor 胜 `8` 个；dense-anchor mean switching regret 为 `0.186`，proxy 为 `0.574`。`10A/score_settle010` 近似为局部 near-tie band，`20A/base` 不支持替换 dense-anchor，`20A/score_settle005` 是 proxy 的强负例，`66us` 在 `tau=0.5/2/5us` 下引入额外 skip 或更长 settling。该轮结果应写成“proxy 需要切换级重校准，安全投影应收紧”，而不是“proxy/AI 已优于 dense-anchor”。
- 已完成 R031 tightened `B_epsilon^sw` 后处理：`iqcot_r031_tightened_bepsilon_sw.py` 基于 R030 challenge 输出 `15` 行 pair risk features、`75` 行策略评估、`3` 条投影规则和 `22` 行最小 held-out 验证计划。R031 将 `20A/score_settle005` 的 `66us` 标为 large-jump settling-sensitive 负样本，暂阻止 `20A/base` 的 `86us` 直接 override，并只在 `10A/score_settle010` 已观测 near-tie 子带中保留 proxy 候选。该结果支持“候选 score/risk 生成 + `B_epsilon^sw` 安全投影”的接口，不支持 proxy 直接替代 dense-anchor。
- 已完成 R031 最小验证 runner dry-run：新增 `iqcot_r031_minimal_validation.m`，并在 R027 delayed-reference runner 中加入 `planMode="r031_minimal"` 适配器。dry-run 成功把 `22` 行 R031 验证计划转换为 MATLAB 执行计划 `iqcot_r027_proxy_table_in_loop_matlab_plan_r031_minimal.csv`；这只验证接口，不是开关级性能证据。
- 已完成 R031 最小 held-out 派生 Simulink 验证：按 `8/8/6` 分块运行全部 `22` 行并后处理。合并 R030 dense baseline 与原 proxy 后，R031 best intermediate candidates 在 `3/9` 个上下文优于 dense，在 `8/9` 个上下文优于原 proxy；best-family counts 为 dense `6`、R031 intermediate `3`。关键结论是 `B_epsilon^sw` 应写成延迟敏感局部带：`10A/score_settle010` 在 `tau=1us` 保持 `30us`，`tau=5us` 可支持 `33us`；`20A/base` 的 `82/84us` 不足以替代 `80us` dense；`20A/score_settle005` 的 `38/50/58us` 中间带有局部价值，但不能直接放行 `66us` proxy。

## 下一步任务

1. 基于 R031 最小 held-out 结果，更新 `B_epsilon^sw` 规则：保留 dense `30/80us` 作为强基线，对 `20A/score_settle005` 允许 `38-58us` 延迟敏感候选，但仍阻止 `66us` 直接 override。
2. 将 tightened `B_epsilon^sw` 从规则表升级为短时事件 predictor 或轻量 score/risk 回归器，重点预测 skip/settling 风险和延迟敏感模式边界；输出必须经过 mode-aware safety projection，不能直接覆盖 IQCOT 内环。
3. 继续设计真实 AI/table-in-loop Simulink 接入实验，比较零延迟目标表、延迟特征监督层、连续 `T_slew` 回归、near-optimal clipping、dense-anchor 和 proxy safety projection，但仍保持 AI 只做监督层参数调度。
4. 使用审稿人视角检查：连续插值是否过拟合、目标函数是否偏置、回归器是否只是在记忆查表、是否存在把 surrogate、table-in-loop、R030/R031 后处理或 R030 challenge 派生仿真当硬件结果的过度表述。

## 约束

- 只研究四相 Buck。
- `.slx` 模型是事实源；不直接修改原始模型，不编辑 `.slx` XML。
- 原始模型只读；派生模型、脚本和结果保存在 `E:/Desktop/codex/output` 与 `E:/Desktop/codex/refine-logs`。
- PIS-IEK 不应声称精确预测大切载第一峰；event-domain surrogate 不等同于硬件验证。
## R032 最新进展：delay-aware `B_epsilon^sw` band projection

R032 已基于 R031 的 22 行最小 held-out 派生 Simulink 结果，生成短时风险预测接口原型 `iqcot_r032_delay_aware_band_predictor.py`。该步骤不运行或修改 `.slx`，只把 R031 结果整理为候选风险特征、延迟感知安全带规则、known-context 策略重放和下一轮 31 行派生 Simulink 验证矩阵。

关键结果应谨慎表述：R032 fitted band projection 在 R031 已知 9 个上下文上 mean regret 为 `0.000`，dense fallback 为 `0.337`，direct proxy override 为 `1.107`；但这是校准一致性结果，不是独立泛化、硬件验证或 `T_slew` 全局最优证明。leave-one-tau nearest-neighbor stress policy 的 mean regret 为 `0.589`，反而说明仅按 `tau_AI` 做简单近邻插值会在非光滑 skip/reentry 边界失败。

当前最稳妥的 R032 结论是：AI/表驱动监督层只能作为 `q_phi/r_hat` 候选 score/risk 生成器，最终 `T_slew,plant` 必须经过 delay-aware `B_epsilon^sw` 投影；`10A/score_settle010` 保留 `30/33us` 延迟敏感近似并列带，`20A/base` 保留 `80us` dense fallback 并继续阻止 `86us` override，`20A/score_settle005` 将 `38/50/58us` 作为中间候选带但继续阻止 `66us` 直接覆盖。
## R033 派生 Simulink 验证：delay-aware `B_epsilon^sw` 的边界修正

在 R032 将 R031 结果整理为 `q_phi/r_hat/B_epsilon^sw` 接口之后，本文进一步执行了 `31` 行派生 Simulink delayed-reference 验证。验证仍只使用 `output/simulink_iek` 下的派生模型，不修改原始 `.slx`，也不构成硬件验证。该轮实验的价值在于把 R032 的已知上下文拟合规则放到新的延迟边界点上检查，从而修正可部署安全投影的局部边界。

结果显示，非 dense 候选在 `4/7` 个上下文中成为当前候选集最优，但这种优势具有明显的目标函数和延迟依赖性。`10A/score_settle010` 形成 `30-34 us` 的 near-tie 候选带：`tau_AI=2 us` 时 `32 us` 最优，`tau_AI=3 us` 时 `33 us` 最优，但各候选差距较小且均出现一次 skip，因此不能写成尖锐点最优。`20A/base` 中，`86 us` 在 `tau_AI=1 us` 的 base score 下略优于 `80 us`，但在 `tau_AI=3 us` 下变差，且 settling 更长；因此它只能作为 objective-dependent probe，而不是被全局解除阻断。最关键的是 `20A/score_settle005`：`tau_AI=0.75 us` 时 `30 us` 最优且 `66 us` 触发 skip，`tau_AI=1.5 us` 时 `50 us` 最优且 `30 us` 触发 skip，`tau_AI=3 us` 时又回到 `30 us` 最优。这说明安全投影需要一个窄的延迟过渡口袋，而不是简单的 `tau_AI` 近邻插值或 proxy 直接覆盖。

因此，R033 对论文主张的强化不是“AI/proxy 已优于查表”，而是更谨慎地说明：PIS-IEK 可以把短时 skip、settling 与相位风险转化为监督层安全投影边界；AI 或表驱动监督层只产生候选 score/risk，最终提交给 IQCOT 内环的 `T_slew` 必须经过 delay-aware `B_epsilon^sw` 投影。`66 us` 负控在当前派生模型中仍不能作为直接覆盖动作，除非后续短时风险预测器或 HIL/硬件验证证明其风险可控。
## R034 可部署短时风险接口：由 R033 边界修正到 `q_phi/r_hat/B_epsilon^sw`

基于 R033 的 `31` 行派生 Simulink 边界验证，本文进一步将局部结论整理为可部署风格的短时风险接口。该接口由三部分组成：候选评分 `q_phi(z_k,T_slew,tau_AI)`、风险估计 `r_hat(z_k,T_slew,tau_AI)`，以及最终安全投影 `B_epsilon^sw`。需要强调的是，R034 不是新的硬件实验，也不是神经网络闭环控制；它是把已有派生模型证据转成监督层参数调度接口和下一轮验证矩阵。

R034 的核心修正是：`T_slew` 的可提交集合不能只随 `tau_AI` 平滑移动，而必须识别 skip/settling 模式边界。对于 `10A/score_settle010`，接口保留 `30-34 us` near-tie candidate band；对于 `20A/base`，`86 us` 只保留为 base objective 下的候选探针，plant 侧默认仍回到 `80 us` fallback；对于 `20A/score_settle005`，接口在 `tau_AI≈1.5 us` 附近形成 `50 us` transition pocket，但在口袋外回到 `30 us` fallback，并继续阻止 `66 us` 直接覆盖。

为了检验该 transition pocket 是否只是单点偶然，R034 生成了 `20` 行下一轮派生 Simulink 细扫计划，覆盖 `tau_AI=1.0/1.25/1.75/2.0 us` 与 `T_slew=38/46/50/54/58 us`。因此，R034 对论文主张的贡献是把 PIS-IEK 的事件域小信号思想落成“候选生成 + 风险预测 + 安全投影 + 最小验证矩阵”的闭环研究流程，而不是宣称 AI/proxy 已经全局优于查表或完成硬件验证。
## R034 部分派生验证：从固定 `50us` 口袋到移动 transition ridge

R034 原先基于 R033 的 `tau_AI=1.5us` 结果，将 `20A/score_settle005` 写成 `50us` transition pocket。为了检查该口袋是否只是单点现象，本文追加运行了两个最小派生 Simulink 边界块：`tau_AI=1.25us` 与 `tau_AI=1.75us`，每个延迟下比较 `38/46/50/54/58us`。结果显示固定 `50us` 假设需要修正：`tau_AI=1.25us` 时 `46us` 最优，而 `50us` 触发 skip 且 regret 达 `2.568`；`tau_AI=1.75us` 时 `54us` 最优，`46us` 反而触发 skip。结合 R033 的 `tau_AI=1.5us -> 50us` 锚点，局部最优候选更像一条随延迟移动的 transition ridge，而不是固定口袋。

因此，R034 对监督层接口的修正是：`q_phi` 可用局部斜脊近似生成候选，例如 `T_ridge(tau_AI)≈26+16 tau_AI us`，但 `r_hat` 必须继续检查 skip 与 settling 风险，最终仍经 `B_epsilon^sw` 投影和 dense fallback 提交。该公式目前只由三个派生模型点支撑，剩余 `tau_AI=1.0us` 与 `2.0us` 的细扫仍需完成；不能把它写成全局最优规律或硬件验证结论。
## R034 完整派生验证：`20A/score_settle005` 的 folded transition band

在 R034 的完整细扫中，本文完成了 `20A/score_settle005` 过渡口袋的全部 `20` 行派生 Simulink delayed-reference 验证，并与 R033 的 `tau_AI=1.5us` 锚点合并分析。结果否定了“固定 `50us` 口袋”作为一般局部规则：当前候选集中最优动作序列为 `tau_AI=1.0us -> 38us`、`1.25us -> 46us`、`1.5us -> 50us`、`1.75us -> 54us`、`2.0us -> 46us`。其中 `tau_AI=1.0us` 时 `46us` 以上候选均触发 skip；而 `tau_AI=2.0us` 时 `46us` 最优、`50us` 近似并列，但 `54/58us` 因 settling 变长而退化。

这说明过渡集合不是简单随 `tau_AI` 单调移动的 ridge，而是由 skip/reentry 与 settling 边界共同折叠出的局部安全带。对 AI 监督层而言，这个结果比单点最优更有价值：它要求 `q_phi` 输出候选带，`r_hat` 显式预测 skip/settling 风险，最终由 `B_epsilon^sw` 投影提交到 IQCOT 参数通道。该结论仍然只来自派生 Simulink，不应写成硬件验证或 `T_slew` 全局最优证明；它支持的是“PIS-IEK 能把非光滑事件风险转化为可验证的安全投影边界”。
