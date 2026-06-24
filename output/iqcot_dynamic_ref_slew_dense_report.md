Actual slew grid used by this run: `20, 30, 40, 50, 60, 80 us`.
Best summary CSV: `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_best_summary.csv`.

# PIS-IEK 动态参考斜率扫描

该实验在 `four_phase_iek_dynamic_load_refslew.slx` 中使用受控电流源施加连续切载，并用 `From Workspace` 给 `IEK_PerPhase_Request/Iph1..4` 和 `IQCOT_Ton_Adapter/Iref_Phase` 输入分段线性参考。扫描 `Iph_ref` 从 `40A/4` 过渡到目标负载/4 的时间：`0, 5, 10, 20, 40 us`。

- Summary CSV: `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_summary.csv`
- Wave sample CSV: `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_wave_samples.csv`

## 最优折中点

- `40A -> 20A`: best slew `80.000 us`, undershoot `1.094 mV`, final error `-0.436 mV`, skip `0`, score `2.273`.
- `40A -> 10A`: best slew `80.000 us`, undershoot `4.631 mV`, final error `-0.551 mV`, skip `1`, score `8.825`.
- `40A -> 0.001A`: best slew `60.000 us`, undershoot `10.452 mV`, final error `-0.543 mV`, skip `2`, score `16.801`.

## 关键解释

参考斜率扫描把 `dynamic_hold` 和 `dynamic_instant` 之间的离散选择变成连续调度问题。若某个中间斜率同时显著降低 final Vout error 且避免 instant 的大欠压，则说明 AI 可以把 `Iph_ref` 斜率作为低维动作；若所有中间斜率都呈单调折中，则仍可用 PIS-IEK 给 AI 提供安全投影边界和 reward shaping。
