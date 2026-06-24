# Experiment Results: AI Delay Event-Domain Surrogate

## 目的

本轮实验回答的问题是：如果 FPGA 上 AI 推理延迟达到 `us` 级，PIS-IEK 小信号模型是否仍然能帮助 AI 控制训练，而不是让 AI 动作因为延迟变成危险的滞后调参。

实验不把 AI 当作逐开关内环，而是把 AI 输出建模为延迟到达、随后保持到下一次更新的低维参数偏置：

```text
u = [Lambda_diff, Ton_diff]
d = ceil(tau_AI / T_event)
```

其中四相 IQCOT 的事件间隔取 `T_event = 0.5 us`，因此 `tau_AI=5 us` 对应 `10` 个 IQCOT 事件。

## 数据规模

- 切载工况：`40A->20A`、`40A->10A`、`40A->near-0A`
- AI 延迟：`0, 0.5, 1, 2, 5 us`
- AI 更新周期：`2, 5, 10, 20 us`
- 策略：`no_ai`、`zero_delay_trained`、`delay_aware`、`delay_aware_projected`
- 每组随机种子：`64`
- 总 episode：`15360`

输出文件：

- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate.py`
- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_detail.csv`
- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_summary.csv`
- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_report.md`
- `E:/Desktop/codex/output/figures/fig21_ai_delay_event_surrogate.svg`

## 关键结果

在最严苛的 `40A->near-0A`、`T_update=5us` 条件下：

| `tau_AI` | Strategy | Mean violations | Tail phase mean | Tail current mean | Reward |
|---:|---|---:|---:|---:|---:|
| `1us` | `zero_delay_trained` | `17.219` | `12.745 ns` | `430.978 mA` | `-637.369` |
| `1us` | `delay_aware` | `24.422` | `13.459 ns` | `491.844 mA` | `-772.161` |
| `5us` | `zero_delay_trained` | `147.875` | `60.276 ns` | `1095.563 mA` | `-2411.740` |
| `5us` | `delay_aware_projected` | `24.297` | `13.360 ns` | `513.768 mA` | `-802.252` |

## 结论

1. `us` 级延迟不是自动致命，但必须转成事件域滞后阶数。`1us` 只跨约 2 个事件时，零延迟训练策略仍可能表现更好；`5us` 跨约 10 个事件时，零延迟训练出现明显 train-test mismatch。
2. PIS-IEK 对 AI 的价值不是让 AI 取代比较器或逐脉冲调度器，而是提供延迟感知状态、动作通道灵敏度和安全投影约束。
3. 更新周期同样关键。实验中 `T_update=20us` 的 mean violation 明显高于 `T_update=5us`，说明 FPGA AI 适合作为受预算约束的监督调参器，而不是任意慢速外环。
4. 对论文写法应保持克制：可以声称 PIS-IEK 帮助 AI 识别何时需要延迟建模和安全投影；不应声称延迟感知策略在所有延迟下都优于零延迟策略。

## 下一步

把同一延迟感知策略迁移到 Simulink 受控动态负载副本中，验证策略排序是否能在开关波形中复现。若复现，则可以把该实验作为“模型辅助 AI 调参”的核心支撑证据。

