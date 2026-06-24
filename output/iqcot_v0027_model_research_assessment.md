# v0027 四相 IQCOT/COT 模型对 RSE-PETS-IQCOT 研究的作用评估

模型目录：

    E:/Desktop/4cot/versions/v0027_20260611_135822_iqcot_optimized_final_cn_docs

当前模型：

    four_phase.slx

## 1. 总体判断

这个模型能帮助研究，但不能不加区分地当作 Bari 文献中严格 IQCOT 面积事件模型。

它目前更准确地说是：

    四相交错同步 Buck
    + 闭环 COT 触发
    + 数字采样/量化链
    + 每相电流误差泄放积分
    + 通过 Ton_iqcot 修正每相 on-time 的工程型 IQCOT adapter

它适合验证：

1. 多相 Buck 功率级和 COT 闭环行为；
2. 数字采样、量化、Transport Delay 对触发和均流的影响；
3. Kiqcot/Tiqcot_leak/Ton_trim_limit 类 AI 调参变量；
4. 多相共模电压动态和差模均流问题；
5. RSE-PETS-IQCOT 中数字噪声、量化、delay、参数调节的工程验证部分。

它暂时不适合直接验证：

    integral_{a_k}^{t_{k+1}} [vc(t)-Ri*iL(t)] dt = CT*VTH/gm

这一严格 IQCOT 积分面积事件方程，因为当前 IQCOT_Ton_Adapter 并不是用 vc - Ri*iL 面积达到阈值来触发下一次导通，而是对每相电流误差做泄放积分后修正 Ton_iqcot。

## 2. 已确认的模型事实

### 2.1 当前初始化参数

通过 MATLAB 加载 init_four_phase_cot_sync.m 得到：

| 参数 | 当前值 |
|---|---:|
| Vin | 12 V |
| Vo_ref | 1 V |
| Iout | 40 A |
| N | 4 |
| fsw_ph | 500 kHz |
| L | 200 nH |
| DCR_L | 10 mOhm |
| Cout | 7.26 mF |
| ESR_C | 90 uOhm |
| Ron_HS | 1 mOhm |
| Ron_LS | 1 mOhm |
| Ton | 186.5 ns |
| Ton_cmd | 196.5 ns |
| Tblank | 480 ns |
| Vhys | 0.45 mV |
| Ts_ctrl | 40 ns |
| Kiqcot | 0 |

注意：该参数组与目录中较早 FOUR_PHASE_COT_HANDOFF.md 里的 L=210 nH、DCR=0.3 mOhm、Tblank=125 ns 不一致。因此以后研究必须以当前 init 和当前 slx 为准，而不是以早期交接文档为准。

### 2.2 模型真实绑定

从 slx XML 检查：

1. 高侧 MOSFET 的 Ron 绑定到 Ron_HS。
2. 低侧 MOSFET 的 Ron 绑定到 Ron_LS。
3. 电感电阻绑定到 DCR_L1...DCR_L4。
4. 输出电容绑定到 Cout 和 ESR_C。
5. Relay 滞环绑定到 Vhys/2 与 -Vhys/2。
6. blanking/trigger 间隔使用 Tblank。

这说明模型作为功率级与 COT 控制平台是可信的。

### 2.3 数字采样与量化链

已确认：

| 项目 | 当前值 |
|---|---:|
| Ts_ctrl | 40 ns |
| ZOH sample time | 1/25000000 = 40 ns |
| Transport Delay | 5/25000000 = 200 ns |
| Quantizer interval | 1 count |
| IL_adc_counts_per_A | 205 count/A |
| 电流量化步长 | 4.878 mA/count |

这对 RSE-PETS-IQCOT 很有价值，因为它提供了真实的数字采样、量化和延迟路径，可用于验证：

    quantization -> current error -> Ton_iqcot -> duty jitter/current sharing

### 2.4 当前 IQCOT adapter 结构

four_phase/IQCOT_Ton_Adapter 路径为：

    IL_sample_i
    -> Abs
    -> ADC_Double
    -> ADC_to_A
    -> Ierr_i = Iph - IL_i
    -> Iq_Filter_i = 1/(s + 1/Tiqcot_leak)
    -> Kiqcot
    -> Ton_cmd + correction
    -> saturation [Ton_iq_min, Ton_iq_max]
    -> COT Cell Ton comparator

COT Cell 中关断条件为：

    on_timer >= Ton_iqcot_i

因此当前 IQCOT 作用是通过电流误差积分修正每相导通时间，不是积分 vc-Ri*iL 面积达到 Lambda 后触发下一次导通。

## 3. 为什么它仍然很有研究价值

虽然它不是严格理论 IQCOT 面积事件模型，但它非常适合你的毕业设计后半部分。

### 3.1 验证 AI 参数调节的工程收益

已有扫参显示：

| 工况 | 输出纹波 | 均流差 | 频率误差 | 综合评分 |
|---|---:|---:|---:|---:|
| Kiqcot=0 基准 | 0.7355 mVpp | 0.0523 A | 1.065 kHz | 0.5280 |
| Kiqcot=3e-5, leak=20us | 0.7304 mVpp | 0.0392 A | 1.330 kHz | 0.5422 |

非零 IQCOT 改善了纹波和均流，但牺牲了频率误差和综合评分。这正适合引出 AI 约束优化：

    AI 不能只追求均流或纹波，
    必须同时约束频率偏差、峰值电流、jitter 和稳定性。

### 3.2 验证多相差模调参

当前模型已经有完整电感电流 il1..4 日志，可用于计算：

    il_phase_imbalance
    differential-mode current ripple
    current sharing recovery

这能支撑 RSE-PETS 中的多相差模模型：

    Kcb / Kiqcot 过大可能改善均流，
    但也可能带来频率漂移、Ton 抖动或差模振荡。

### 3.3 验证数字量化和 delay

模型已有：

    40 ns 采样
    200 ns transport delay
    1 count quantizer
    4.878 mA/count 电流分辨率

可以直接扫描：

    Ts_ctrl
    Transport Delay
    Quantizer interval
    IL_adc_counts_per_A

观察：

    qh period jitter
    trigger period jitter
    il imbalance
    vout ripple
    frequency error

这正好对应 RSE-PETS-IQCOT 中的随机事件核验证。

## 4. 它不能直接验证什么

不能直接验证以下理论式：

    F_k = integral_{a_k}^{t_{k+1}} [vc(t)-Ri*iL(t)]dt - Lambda = 0
    Lambda = CT*VTH/gm

原因：

1. 当前模型没有显式 vc-Ri*iL 积分核。
2. 当前模型没有 CT/VTH/gm/Ri 这组 IQCOT 面积阈值参数。
3. 当前模型的事件触发仍是电压 Relay + blanking + phase scheduler。
4. IQCOT adapter 只修正 on-time，而不是用积分面积决定下一次 turn-on。

因此若论文要严谨验证 PETS/RSE-PETS 的核心事件方程，需要另建或改造一个理想面积事件 IQCOT 验证模型。

## 5. 推荐研究路线

### 路线 A：直接使用当前 v0027 模型

不改模型结构，只用 SimulationInput 覆盖变量。

研究内容：

1. 扫描 Kiqcot 和 Tiqcot_leak；
2. 扫描 Ts_ctrl、Transport Delay、Quantizer interval；
3. 提取 trigger/qh 边沿 jitter；
4. 计算 il1..4 差模均流指标；
5. 对比固定 COT、非零 IQCOT、AI constrained tuning。

论文中定位：

    工程型数字 IQCOT 多相调参验证平台。

### 路线 B：在副本中最小改造

复制一份模型，例如：

    four_phase_rse_pets.slx

加入：

1. 可控负载阶跃；
2. Ton_iqcot_i 日志；
3. Iq_Filter_i 状态日志；
4. 可控 ADC 噪声源；
5. 可控 quantizer interval；
6. trigger/qh 边沿时间提取脚本。

论文中定位：

    验证 RSE-PETS 的随机/量化/延迟/差模调参部分。

### 路线 C：另搭理想 IQCOT 面积事件模型

新建一个简化模型：

    Buck power stage
    + h(t)=vc-Ri*iL
    + accumulator integral h(t)dt
    + Lambda=CT*VTH/gm
    + event comparator
    + reset
    + COT on-time pulse

用于验证：

1. rho = delta ln(CT*VTH/gm)；
2. kappa = delta ln Ri；
3. tau_{k+1} 事件时刻递推；
4. w_A -> tau jitter -> duty jitter；
5. Lambda_eff 与 detection delay。

论文中定位：

    理论 PETS/RSE-PETS-IQCOT 核心事件模型验证。

## 6. 最佳组合建议

建议不要二选一，而是组合：

1. 用当前 v0027 模型证明真实四相数字 COT/IQCOT 平台中确实存在多目标调参矛盾；
2. 用新建理想面积事件模型证明 PETS/RSE-PETS 公式是对严格 IQCOT 的理论验证；
3. 再把二者连接起来，说明 AI 调参变量为什么选 rho/psi/kappa/Kiqcot/Ton_trim_limit，而不是直接输出 PWM。

## 7. 可直接开展的下一步

### Step 1：边沿 jitter 分析脚本

基于现有 analyze_four_phase_cot.m，新增指标：

    qh_period_std
    trigger_period_std
    req_period_std
    duty_jitter_proxy

### Step 2：数字链扫参

扫描：

    Quantizer interval = 1, 2, 4, 8 counts
    Transport Delay = 0, 40 ns, 80 ns, 160 ns, 200 ns
    Ts_ctrl = 20 ns, 40 ns, 80 ns

观察：

    vout_ripple
    qh jitter
    trigger jitter
    il imbalance
    frequency error

### Step 3：AI 约束调参

优化变量：

    Kiqcot
    Tiqcot_leak
    Ton_iq_min
    Ton_iq_max

约束：

    vout_ripple <= baseline
    il_imbalance <= baseline
    frequency_error <= limit
    qh_jitter <= limit
    il_peak <= limit

### Step 4：理想 IQCOT 面积事件模型

单独搭建一个小模型，专门验证：

    Lambda
    rho
    kappa
    sigma_A -> sigma_tau -> sigma_d

## 8. 结论

这个 v0027 模型可以成为毕业设计中非常有用的工程验证平台，但不能直接替代严格 IQCOT 面积事件理论模型。

最准确的使用方式是：

    v0027 模型：验证多相数字 COT/IQCOT、量化、延迟、均流和 AI 调参矛盾；
    新建理想模型：验证 PETS/RSE-PETS-IQCOT 的核心积分事件小信号推导。

这样既不浪费已有模型，又能保证论文理论创新的严谨性。
