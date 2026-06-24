### R030 refined band policy and dense-anchor challenge design

R029修正了R028的两个硬编码guard之后，本文进一步将guard写成局部安全带而不是单点规则。新的R030代表策略为：`10A/score_settle005`在`tau_AI<=1us`保留dense-anchor，在已测得的`1.5us`过渡区域采用`40us`，在`tau_AI>=2us`采用短斜率边界`34us`；`near0A/score_settle010`不再使用固定`35us`，而写成`30-38us`局部带，当前代表点在`tau_AI<0.5us`取`38us`、从`0.5us`起回到`30us`。该规则在R027 priority replay和R029 held-out已知guard上下文上的合成mean switching regret为`0.000`，对应dense-anchor为`0.128`。这只能说明R030与当前派生Simulink证据一致，不能说明全局最优或硬件安全。

同时，R030从R027完整`315`行计划中筛出dense与proxy不同但未进入priority switching的上下文。离线分数显示，`10A/score_settle010`中proxy的`32us`相对dense的`30us`有约`0.490`分优势，`20A/base`中`86us`相对`80us`有约`0.140`分优势，`20A/score_settle005`中`66us`相对`30us`有约`0.095`分优势。由于R027已经证明离线排序在延迟开关级回放中可能失效，这些点应被写成下一轮派生Simulink挑战计划，而不是当前性能结论。
