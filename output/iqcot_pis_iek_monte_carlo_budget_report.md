# PIS-IEK 数字量化与检测延迟 Monte Carlo 预算

## 数据规模

- 解析事件模型：四相 IQCOT，Lambda=6.343943e-10 V*s。
- 随机样本行数：`4096`。
- 聚合工况行数：`256`。
- 扫描维度：area bits = {10,12,14,16}，检测时钟 = {0.5,1,2,5} ns，Ton 分辨率 = {5,10,20,50} ps，比较器随机延迟 sigma = {0,0.5,1,2} ns。

## 代表性结果

- 12 bit 面积阈值、1 ns 检测时钟、10 ps Ton 分辨率、0.5 ns 比较器延迟 sigma 下：wait jitter rms 均值 `0.6466 ns`，phase-spacing std 均值 `0.6466 ns`，电流均分 rms 均值 `0.5059 mA`。
- 最差聚合工况：bits=10，clock=5.0 ns，Ton=50 ps，delay sigma=2.0 ns，phase-spacing std p95=`2.8818 ns`。
- 最好聚合工况：bits=16，clock=0.5 ns，Ton=5 ps，delay sigma=0.0 ns，phase-spacing std p95=`0.1684 ns`。

## 论文解释

该 Monte Carlo 不是替代 Simulink 开关电路仿真，而是把 PIS-IEK 的局部灵敏度转化为数字实现预算。它回答的问题是：面积阈值位宽、检测时钟、Ton 分辨率和比较器随机延迟共同存在时，事件 wait jitter、相位间隔质量和均流误差处在什么量级。该结果可作为后续 AI/优化调参的约束边界。
