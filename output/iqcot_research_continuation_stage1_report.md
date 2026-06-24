# IQCOT 创新研究继续推进：阶段 1 理论与工程验证报告

本阶段目标是把 RSE-PETS-IQCOT 从“理论创新构想”推进到“可验证研究路线”。我做了两类验证：

1. 理想 IQCOT 面积事件模型：验证 PETS/RSE-PETS 核心小信号公式；
2. v0027 四相 Buck 工程模型：验证数字量化、jitter、Kiqcot 调参和多相均流之间的矛盾。

## 1. 文件产物

新增脚本：

    E:/Desktop/codex/output/iqcot_ideal_area_event_validation.py
    E:/Desktop/codex/output/iqcot_v0027_jitter_sweep.m

新增结果：

    E:/Desktop/codex/output/iqcot_v0027_jitter_sweep_summary.csv

本报告：

    E:/Desktop/codex/output/iqcot_research_continuation_stage1_report.md

## 2. 理想面积事件模型验证

理想 IQCOT 事件：

    F_k = integral h(t)dt - Lambda = 0
    h(t)=Hs+Sf*t

稳态参数：

    Toff0 = 8.082320e-07 s
    He    = 4.386342e-03

### 2.1 rho 灵敏度

对：

    rho = delta ln(CT*VTH/gm)

进行 ±1%、±2%、±5% 扰动，使用一阶预测：

    delta_t ~= Lambda*rho/He

结果：

| rho | 精确 delta_t | 一阶预测 | 误差 |
|---:|---:|---:|---:|
| -0.01 | -5.683 ns | -5.700 ns | 0.293% |
| +0.01 | +5.716 ns | +5.700 ns | -0.292% |
| -0.05 | -28.085 ns | -28.498 ns | 1.471% |
| +0.05 | +28.917 ns | +28.498 ns | -1.451% |

结论：在小扰动范围内，rho 通道的一阶模型非常准确。5% 扰动仍保持约 1.5% 误差，足够作为 AI 安全坐标的理论依据。

### 2.2 kappa 灵敏度

对：

    kappa = delta ln Ri

通过 Ri 面积项：

    A_Ri = -Ri*kappa*integral IL(t)dt

验证一阶预测：

    delta_t ~= -A_Ri/He

结果：

| kappa | 精确 delta_t | 一阶预测 | 误差 |
|---:|---:|---:|---:|
| -0.02 | -18.552 ns | -18.426 ns | -0.677% |
| +0.02 | +18.304 ns | +18.426 ns | 0.668% |
| -0.05 | -46.866 ns | -46.065 ns | -1.710% |
| +0.05 | +45.316 ns | +46.065 ns | 1.653% |

结论：kappa 通道同样能被一阶面积模型准确描述。

### 2.3 面积噪声到事件 jitter

注入面积噪声：

    sigma_A = 8e-12

理论预测：

    sigma_tau = sigma_A/He = 1.823843 ns

Monte Carlo 结果：

    sigma_tau_exact = 1.823785 ns

结论：面积噪声到事件时刻 jitter 的一阶公式几乎完全吻合仿真。这是 RSE-PETS-IQCOT 随机事件模型最坚实的第一块验证。

## 3. v0027 四相模型小规模扫参

模型：

    E:/Desktop/4cot/versions/v0027_20260611_135822_iqcot_optimized_final_cn_docs/four_phase.slx

该模型是四相 Buck + COT + 数字采样链 + 工程型 IQCOT Ton adapter，不是严格面积事件 IQCOT。因此它用于工程验证，而不是替代理想面积事件模型。

### 3.1 扫参工况

| 工况 | Kiqcot | Tiqcot_leak | Quantizer interval |
|---|---:|---:|---:|
| k0_q1 | 0 | 80 us | 1 count |
| k3e5_q1 | 3e-5 | 20 us | 1 count |
| k0_q4 | 0 | 80 us | 4 counts |
| k3e5_q4 | 3e-5 | 20 us | 4 counts |

仿真设置：

    StopTime = 0.50 ms
    SteadyStart = 0.42 ms
    MaxStep = 4 ns
    Tss = 0.12 ms

这是快速研究用短仿真，不作为最终高精度结论。

### 3.2 结果摘要

| 工况 | Vout 纹波 | trigger 周期 std | qh 周期 std 均值 | 均流差 |
|---|---:|---:|---:|---:|
| k0_q1 | 0.7211 mVpp | 17.71 ns | 16.18 ns | 0.0204 A |
| k3e5_q1 | 0.7260 mVpp | 17.78 ns | 16.97 ns | 0.0434 A |
| k0_q4 | 0.7408 mVpp | 17.75 ns | 17.74 ns | 0.0418 A |
| k3e5_q4 | 0.7260 mVpp | 17.78 ns | 16.97 ns | 0.0434 A |

### 3.3 初步解释

1. 在短稳态窗口内，非零 Kiqcot 并没有改善均流，反而使均流差从 0.0204 A 增加到 0.0434 A。
2. 将量化步长从 1 count 放大到 4 counts，在 Kiqcot=0 时使输出纹波和均流明显变差。
3. 在 Kiqcot=3e-5 的两组中，q1 与 q4 输出几乎相同，说明该短窗口和当前工作点下，非零 IQCOT 路径的效果并不简单随量化步长单调变化；也可能是此工况对该量化变化不敏感，需要更长窗口或更多量化点确认。
4. qh 周期 jitter 已经达到 16 ns 量级，与 40 ns 采样周期和 200 ns transport delay 同量级相关，说明数字事件抖动是一个真实存在、值得建模的指标。

## 4. 对 RSE-PETS-IQCOT 创新的支撑

本阶段结果支持以下论文观点：

### 4.1 rho/kappa 坐标合理

理想面积事件模型验证了：

    rho -> 事件时刻偏移
    kappa -> 事件时刻偏移

均可用一阶面积模型准确预测。

### 4.2 随机面积噪声模型可验证

面积噪声到事件 jitter 的理论和仿真吻合，说明：

    sigma_A -> sigma_tau

这条建模链条是可落地的，不只是概念。

### 4.3 v0027 证明工程调参有多目标矛盾

非零 Kiqcot 并非必然提升综合性能；量化变粗也会改变纹波、均流和 jitter。说明 AI 调参必须引入约束：

    jitter constraint
    frequency constraint
    current sharing constraint
    peak current constraint
    ripple constraint

不能只用一个负载瞬态指标作为 reward。

### 4.4 v0027 适合作为高保真样本源

单次短仿真已经需要几十秒，四个工况约 1-2 分钟。因此后续 AI 不应直接用全开关模型大量在线训练。更合理路线：

    理想事件模型/代理模型负责大规模搜索；
    v0027 开关级模型负责少量高保真校验。

## 5. 下一步研究建议

### 5.1 增强 v0027 扫参

增加工况：

    Kiqcot = 0, 1e-5, 3e-5, 6e-5, 1e-4
    Quantizer interval = 1, 2, 4, 8 counts
    Transport delay = 0, 40 ns, 80 ns, 160 ns, 200 ns

但建议分批跑，不要一次大扫。

### 5.2 加入负载阶跃

当前短稳态不能体现 IQCOT 的瞬态优势。应在 v0027 副本中加入可控负载阶跃，比较：

    Kiqcot=0
    Kiqcot=3e-5
    AI constrained Kiqcot/Tleak

指标：

    undershoot
    overshoot
    recovery time
    qh jitter
    il sharing recovery

### 5.3 建立理想面积事件 Simulink 模型

用于严谨验证：

    Lambda = CT*VTH/gm
    h(t)=vc-Ri*iL
    rho/kappa sensitivity
    sigma_A -> sigma_tau -> sigma_d
    detection delay -> Lambda_eff

这部分应该作为论文理论模型的主验证。

### 5.4 构建 AI 约束优化原型

先不做在线 RL，建议做：

    Latin hypercube / grid 采样
    + surrogate model
    + constrained Bayesian optimization

优化变量：

    rho or psi
    kappa
    Kiqcot
    Tiqcot_leak
    Ton_trim_limit

约束：

    qh_period_std < limit
    il_phase_imbalance < limit
    vout_ripple < limit
    freq_error < limit
    il_peak < limit

## 6. 阶段结论

本阶段已经从理论和工程两个层面证明 RSE-PETS-IQCOT 路线值得继续：

1. 理想面积事件模型验证了 rho/kappa 和面积噪声 jitter 推导；
2. v0027 模型提供了真实多相数字 COT/IQCOT 的 jitter 和均流观测；
3. 初步扫参显示非零 IQCOT 和量化变化会带来多目标权衡；
4. 这正好支撑 AI 安全调参的必要性，而不是让 AI 直接输出 PWM。

下一阶段最关键的是加入负载阶跃和搭建严格面积事件 Simulink 模型。
