# PIS-IEK 结构化仿真验证报告

## 实验规模

- 模型：四相理想 IQCOT 面积事件模型，`N=4`，`Ton=169.166667 ns`，`Twait=330.833333 ns`。
- 四事件闭合误差：`0.000e+00`。
- 局部 Jacobian 行数：`32`。
- 模态投影行数：`10`。
- 幅值线性扫描：`77` 个工况，其中 Lambda `35`、Ton `24`、Mixed `18`。
- 频率响应扫描：`80` 个工况，其中 Lambda `40`、Ton `30`、Mixed `10`。
- 总运行时间：`90.21 s`。

## 主要结论

- 局部事件面结果显示，当前 wait 只直接受下一触发相 `Lambda_q` 和当前 on-time 相 `Ton_p` 影响；在该理想四相模型中非目标相局部串扰为 0。这为 `phase_idx` 的事件面解释提供了清楚证据。
- Lambda 幅值扫描最大 rms wait 相对误差为 `0.0502%`；Ton 幅值扫描最大 rms wait 相对误差为 `9.1302%`。
- Mixed 幅值扫描最大 rms wait 相对误差为 `1.7186%`，说明线性叠加在小扰动范围内仍成立，但 Ton 通道会先成为误差主导项。
- 四事件提升频率响应中，可观测 wait 幅值工况的最坏幅值误差来自 `mixed_m2_w0.010`，误差为 `-0.0039%`，绝对误差 `-1.04319e-05 ns`；这用于标定 PIS-IEK 在高频事件扰动下的适用边界。低于 `1e-4 ns` 的响应幅值不用于百分比最坏值判定。
- 幅值扫描中最坏 rms wait 误差来自 `ton_m1_cos_0.1000ns`，误差为 `9.1302%`。

## 数据结构

- `sensitivity`: `E:\Desktop\codex\output\iqcot_pis_iek_sensitivity_matrix.csv`
- `modal_projection`: `E:\Desktop\codex\output\iqcot_pis_iek_modal_projection_matrix.csv`
- `amplitude_sweep`: `E:\Desktop\codex\output\iqcot_pis_iek_amplitude_sweep.csv`
- `frequency_response`: `E:\Desktop\codex\output\iqcot_pis_iek_frequency_response.csv`

## 论文写法建议

PIS-IEK 可以作为 v6 的一个模型精进章节：先给盐跃事件映射，再给 Jacobian 数据表，最后用幅值线性和频率响应证明它不是只在单个扰动点成立。表述上要保持边界：saltation/Poincare 是已有数学工具，本文创新在于将其与四相 IQCOT 面积事件、相序调度和执行量分类结合。
