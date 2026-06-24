### R029 held-out 验证：R028 guard 的局部支持与修正

为避免把 R028 的 `0.000` priority regret 误写成泛化证明，本文进一步执行了 `21` 个 held-out 派生 Simulink 工况。对 `10A/score_settle005`，验证矩阵在 `tau_AI=1.5/2.5/3us` 下比较 `34/40/50/62us`。结果显示，`tau_AI=1.5us` 时 `40us` 最优，说明 `34us` guard 不应外推到 `2us` 以下；而 `tau_AI=2.5/3us` 时 `34us` 最优，支持 R028 中 `tau_AI>=2us` 的短斜率 delay guard。旧 proxy 的 `62us` 在 held-out 10A 场景中仍然偏差较大，支持 dense-anchor 投影将其排除。

near0A 强恢复目标的结果则修正了 R028：当加入 `38us` 细扫候选后，`tau_AI=0` 与 `0.25us` 下 `38us` 最优或近似最优，`tau_AI=0.5us` 下 `30us` 最优。因此 near0A 不应写成固定 `35us` guard，而应写成 `30-38us` 局部安全带，后续由 score 或风险 proxy 在带内选择。R029 仍是派生模型证据，不等同于硬件验证或神经网络 AI-in-loop。
