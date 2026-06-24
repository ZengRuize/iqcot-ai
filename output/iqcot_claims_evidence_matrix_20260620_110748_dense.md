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
| C7 | `Iph_ref` 参考斜率是有实际价值的低维调度变量 | 五点扫描 15 个工况 + 密集扫描 18 个工况；当前密集网格中 `40A->20A/10A` 最佳折中为 `80 us`，`40A->near-0A` 为 `60 us`；near-0A 欠压从 instant 的 `35.750 mV` 降至 `10.452 mV` | 强 | “当前密集扫描网格中，较慢参考斜率给出更好折中。” | “`60 us` 或 `80 us` 是全局最优。” |
| C8 | FPGA AI 微秒级延迟应写成 IQCOT 事件域滞后 | 四相 `500 kHz`，`T_e≈0.5 us`；`tau_AI=5 us` 对应 `10` 个事件 | 强 | “AI 延迟不能忽略，应使用 `u_{k-d}` 训练。” | “AI 可以逐脉冲替代 COT 内环。” |
| C9 | 延迟感知 AI 在大延迟严苛切载下减少 train-test mismatch | `40A->near-0A, T_update=5us, tau_AI=5us`：zero-delay violation `147.875`，delay-aware projected `24.297` | 中强 | “当延迟跨越多个事件时，延迟感知训练明显有价值。” | “delay-aware AI 在所有延迟下都更优。” |
| C10 | `tau_AI=1us` 时 zero-delay-trained 仍有竞争力 | 同一严苛切片：zero-delay reward `-637.369`，delay-aware reward `-772.161` | 强边界 | “小延迟下零延迟训练仍可能有效。” | “零延迟训练总是失效。” |
| C11 | 参考斜率可作为 AI 动作扩展 | `u=[Delta Lambda_diff, Delta Ton_diff, Delta Iph_ref, ref_slew_time]`；ref-slew 扫描已证明该动作影响欠压、final error 和 skip | 中强 | “AI 可以学习 `ref_slew_time` 这类低维参数。” | “AI 已完成真实硬件闭环控制。” |
| C12 | 当前证据尚未完成硬件级验证 | 所有新增动态证据来自 Simulink 副本或 event-domain surrogate | 强边界 | “下一步需要 FPGA/HIL 或硬件验证。” | “实验已证明实物硬件性能提升。” |

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

## 审稿式自查

### 可能被问的问题 1：这个创新是不是只是把 saltation matrix 用到了 IQCOT？

回答：不能把贡献写成“发明 saltation matrix”。更稳妥的贡献是将 saltation/移动边界线性化具体落到四相数字 IQCOT 面积积分事件中，并把 `phase_idx/reset/Lambda_i/Ton_i` 执行量统一成可验证的事件域 Jacobian。创新在应用对象、执行量分类和仿真证据链，而不是数学工具本身。

### 可能被问的问题 2：为什么不直接用已有 IQCOT 高频小信号模型？

回答：已有模型主要服务于环路传函和稳定性分析。本文的问题是多相数字实现中的执行量分类、相位扰动、参考斜率和 AI 延迟。PIS-IEK 补充的是事件索引和执行量通道层面的设计信息。

### 可能被问的问题 3：切载第一峰 PIS-IEK 预测准吗？

回答：本文不把第一峰作为 PIS-IEK 的强 claim。第一峰应由电感能量和输出电容大信号模型解释；PIS-IEK 用于后续事件恢复、skip/reentry、phase-spacing 和均流恢复。

### 可能被问的问题 4：AI 结果是不是过度？

回答：当前 AI 结果是 event-domain surrogate，用于证明延迟建模必要性和安全投影价值。开关级 Simulink 已验证参考斜率有用，但尚未完成真实 AI-in-the-loop 开关级验证。因此论文应写“PIS-IEK 支撑 AI 参数调度”，不写“AI 已全面优于 IQCOT”。

### 可能被问的问题 5：实验量是否足够？

回答：对“参考斜率”这一局部结论，已有 15 个五点扫描工况和 18 个密集扫描工况；对“延迟建模必要性”，已有 15360 episode surrogate；对基础 PIS-IEK，小信号层已有 77+80 个结构化工况。仍需补充的是 `80 us` 以上或连续动作扫描、开关级 AI-in-the-loop 和硬件/HIL 验证。
