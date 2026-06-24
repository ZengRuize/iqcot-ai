# v4 审稿式自查报告

对象：`iqcot_multiphase_iek_paper_v4_iek_area_validated.md`

## 总体判断

v4 相比 v3 的实质进步是：不再只用原模型验证 `Ton_diff`，而是在模型副本 `four_phase_iek_area.slx` 中实现了面积积分 `REQ`。这使论文首次具备了 Simulink 层面的 `Λ_cm/Λ_m2` 证据。新增结果支持核心创新判断：`Λ_cm` 可以作为闭环事件间隔参数，`Λ_m2` 主要改变 phase spacing，不是强 DC 均流执行量。

## 新增证据强度

1. 面积触发副本能闭环：`Λ_area=3e-10 V*s` 时，`Vout_mean=0.999396 V`，`Vout_ripple=0.650821 mVpp`，平均相频率 `501.707 kHz`，相序错误率为 0。
2. `Λ_cm` 具有事件间隔整形能力：`Λ_area` 从 `1e-12` 扫到 `3e-9 V*s` 时，相频率从约 `502.8 kHz` 降到 `498.7 kHz`，phase-spacing 标准差从 `34.5 ns` 降到 `1.31 ns`。
3. `Λ_m2` 缺少 DC 均流权威性：`Λ_m2/Λ_area=0.4` 时，m2 电流投影仅 `0.00397 A`，相电流不均衡仍约 `0.07177 A`。
4. `Λ_m2` 明显影响 phase spacing：同一最大比值下，phase-spacing 标准差从基线 `2.876 ns` 增至约 `17.03 ns`。

## 主要风险

1. 面积触发公式仍是工程近似：当前副本用 `integral(max(e_v,0))`，还不是 Bari IQCOT 原式中的逐相 `integral(v_c - R_i i_L)`。
2. `phase_idx` 阈值选择仍需要校准：当前用 `Lambda_area + Lambda_m2*cos(pi*phase_idx)`，并通过 `Memory` 打断代数环；这足以做方向性验证，但不能当作最终数字控制器结构。
3. 扫描窗口偏短：为了迭代速度，面积触发验证用 `0.45 ms` 和快速软启动；最终论文若进入正式答辩稿，建议增加 `1.3 ms/MaxStep=2 ns` 的精选复核点。
4. 仍缺负载阶跃：目前所有新增验证都是稳态或准稳态小扰动，没有证明 IEK 面积触发在负载跃迁中的瞬态优势。

## 建议

下一步最值得做的是“逐相真实 IEK 子系统”：

```text
for next phase q:
  integrate v_c - Ri * i_Lq during off-time/window
  compare with Lambda_q
  generate REQ
  reset area on accepted trigger
```

如果能再加入 `1.3 ms/2 ns` 高分辨率复核和一组 `40 A -> 60 A -> 40 A` 负载阶跃，论文证据链会从“较强毕业设计创新”进一步接近可投稿短文的完整度。
