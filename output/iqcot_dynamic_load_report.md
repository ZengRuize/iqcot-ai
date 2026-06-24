# PIS-IEK 受控动态负载切载验证

该脚本把 `four_phase_iek_perphase_trim.slx` 复制为两个派生模型：`four_phase_iek_dynamic_load.slx` 和 `four_phase_iek_dynamic_load_refstep.slx`。两者都用 SPS `Controlled Current Source` 替换静态 `Series RLC Branch8` 负载，并在同一次仿真中施加 `Iload_initial -> Iload_final` 连续电流阶跃。

`dynamic_hold` 保持控制器参考 `Iph=40A/4` 不变；`dynamic_instant` 进一步把 `IEK_PerPhase_Request/Iph1..4` 和 `IQCOT_Ton_Adapter/Iref_Phase` 从 Constant 替换为同步 Step，使控制器参考与物理负载同时从 `40A/4` 切到目标负载/4。

- Summary CSV: `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv`
- Wave sample CSV: `E:/Desktop/codex/output/iqcot_dynamic_load_wave_samples.csv`

## 主要结果

- `40.0 A -> 20 A`, controller `dynamic_hold`: overshoot `2.475 mV`, undershoot `0.992 mV`, estimated skipped events `1`, settle time `NaN us`, final phase-spacing std `40.094 ns`, final current imbalance `0.165507 A`.
- `40.0 A -> 10 A`, controller `dynamic_hold`: overshoot `4.196 mV`, undershoot `4.292 mV`, estimated skipped events `1`, settle time `NaN us`, final phase-spacing std `79.875 ns`, final current imbalance `0.184188 A`.
- `40.0 A -> 0.001 A`, controller `dynamic_hold`: overshoot `6.817 mV`, undershoot `9.451 mV`, estimated skipped events `2`, settle time `NaN us`, final phase-spacing std `103.595 ns`, final current imbalance `0.568707 A`.
- `40.0 A -> 20 A`, controller `dynamic_instant`: overshoot `2.235 mV`, undershoot `13.466 mV`, estimated skipped events `1`, settle time `18.256 us`, final phase-spacing std `41.954 ns`, final current imbalance `0.251584 A`.
- `40.0 A -> 10 A`, controller `dynamic_instant`: overshoot `4.196 mV`, undershoot `23.830 mV`, estimated skipped events `2`, settle time `22.384 us`, final phase-spacing std `87.335 ns`, final current imbalance `0.361974 A`.
- `40.0 A -> 0.001 A`, controller `dynamic_instant`: overshoot `6.817 mV`, undershoot `35.750 mV`, estimated skipped events `2`, settle time `24.970 us`, final phase-spacing std `108.304 ns`, final current imbalance `0.153013 A`.

## 参考模式对照

- `40 A -> 20 A`: instant 相比 hold 的欠压从 `0.992 mV` 增至 `13.466 mV`，final Vout error 从 `2.058 mV` 变为 `-0.435 mV`，skip 均为 `1`。
- `40 A -> 10 A`: instant 相比 hold 的欠压从 `4.292 mV` 增至 `23.830 mV`，final Vout error 从 `3.199 mV` 变为 `-0.563 mV`，skip 从 `1` 增至 `2`。
- `40 A -> near-0 A`: instant 相比 hold 的欠压从 `9.451 mV` 增至 `35.750 mV`，final Vout error 从 `4.413 mV` 变为 `-0.566 mV`，skip 均为 `2`。

## 解释

连续动态负载结果与 state-carry 结果在 skip/reentry、相位间隔扰动和均流恢复趋势上保持一致，因此 PIS-IEK 混合事件建模的证据链更强。同时，`dynamic_instant` 显示参考快速下调会显著放大切载欠压，说明 AI/调参策略不能只追求参考快速跟随，而必须加入延迟、模式和安全约束。
