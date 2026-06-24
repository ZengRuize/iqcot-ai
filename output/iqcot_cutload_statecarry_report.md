# PIS-IEK 切载状态继承仿真首轮验证

该脚本采用两段仿真：先在 40 A 跑到稳态并保存 final state，再把 `Rload/Iout/Iph` 切到轻载并从该状态继续仿真。该方法不修改 `.slx`，适合作为动态负载模型之前的事件恢复验证。

脚本同时比较两种控制器参考处理：`hold` 表示物理负载改变但面积核中的 `Iph` 仍保持 40 A/4；`instant` 表示 `Iph` 也瞬时改为目标负载/4。二者用于区分物理切载与参考调度对 IQCOT 面积事件的影响。

- Summary CSV: `E:/Desktop/codex/output/iqcot_cutload_statecarry_summary.csv`
- Wave sample CSV: `E:/Desktop/codex/output/iqcot_cutload_statecarry_wave_samples.csv`

## 主要结果

- `40.0 A -> 20 A`, controller `hold`: overshoot `2.488 mV`, estimated skipped events `0`, settle time `89.952 us`, final phase-spacing std `49.762 ns`, final current imbalance `0.235222 A`.
- `40.0 A -> 20 A`, controller `instant`: overshoot `1.739 mV`, estimated skipped events `1`, settle time `6.212 us`, final phase-spacing std `43.880 ns`, final current imbalance `0.309613 A`.
- `40.0 A -> 10 A`, controller `hold`: overshoot `3.795 mV`, estimated skipped events `1`, settle time `NaN us`, final phase-spacing std `92.780 ns`, final current imbalance `0.307217 A`.
- `40.0 A -> 10 A`, controller `instant`: overshoot `3.440 mV`, estimated skipped events `1`, settle time `13.626 us`, final phase-spacing std `114.197 ns`, final current imbalance `0.176591 A`.
- `40.0 A -> 0.001 A`, controller `hold`: overshoot `5.810 mV`, estimated skipped events `1`, settle time `NaN us`, final phase-spacing std `108.984 ns`, final current imbalance `0.499764 A`.
- `40.0 A -> 0.001 A`, controller `instant`: overshoot `5.810 mV`, estimated skipped events `2`, settle time `20.036 us`, final phase-spacing std `116.749 ns`, final current imbalance `0.609893 A`.

## 边界说明

这是状态继承切载验证，不是最终的受控动态负载硬件等价模型。若该结果显示明显 skip/reentry，则下一步应在 `.slx` 副本中把静态 `Series RLC Branch8` 替换为受控电流源或受控负载，以验证连续仿真中的同一现象。
