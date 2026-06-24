### R029 held-out 验证设计：检验 R028 guarded proxy 是否过拟合

R028 的 `r028_switching_guarded_proxy` 在 R027 priority 压力集上取得零 regret，但该策略由同一压力集校准得到，因此不能作为泛化证据。R029 设计了一个小规模 held-out 派生 Simulink 矩阵：对 `10A/score_settle005` 扫描 `tau_AI=1.5/2.5/3us` 和 `T_slew=34/40/50/62us`，对 near0A 强恢复目标扫描 `tau_AI=0/0.25/0.5us` 和 `T_slew=30/35/38us`。该矩阵用于检查 delay guard 的局部边界，而不是寻找全局最优斜率。
