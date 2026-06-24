# IEK 面积触发 Simulink 副本验证

模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_area.slx`。
原始模型未修改。副本将 `Relay` 请求替换为面积积分请求：`REQ = integral(max(e_v,0)) >= Lambda_area + Lambda_m2*cos(pi*phase_idx)`。

## Lambda_cm 调谐

最佳候选 `Lambda_area = 3e-10 V*s`。

该点结果：`Vout_mean=0.999395652 V`，`Vout_ripple=0.650821 mVpp`，平均相频率 `501.707 kHz`，相电流不均衡 `0.068008 A`。

## Lambda_m2 初探

最大扫描比值 `Lambda_m2/Lambda_area=0.400` 时，相电流不均衡 `0.071770 A`，m2 电流投影 `0.003973 A`。

## 解释边界

这是首次把严格面积触发 REQ 放进用户四相 Simulink 副本的验证。当前版本的 `phase_idx` 阈值选择仍是探索实现，适合证明 `Lambda_cm` 可闭环工作，并初步观察 `Lambda_m2` 对相电流的影响；后续应进一步校准 phase index 与 next-phase threshold 的对应关系。
