#!/usr/bin/env python3
"""Append R032 documentation snippets to project research documents.

The existing long-form markdown files contain legacy mojibake sections in this
workspace.  To avoid brittle patch anchors, this helper appends UTF-8 R032
sections without rewriting previous content.
"""

from __future__ import annotations

from pathlib import Path


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
WIKI = ROOT / "research-wiki"
LOGS = ROOT / "refine-logs"


def append_once(path: Path, marker: str, text: str) -> None:
    old = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    if marker in old:
        return
    sep = "" if old.endswith("\n") or not old else "\n"
    path.write_text(old + sep + text.strip() + "\n", encoding="utf-8")


def main() -> None:
    brief = """
## R032 最新进展：delay-aware `B_epsilon^sw` band projection

R032 已基于 R031 的 22 行最小 held-out 派生 Simulink 结果，生成短时风险预测接口原型 `iqcot_r032_delay_aware_band_predictor.py`。该步骤不运行或修改 `.slx`，只把 R031 结果整理为候选风险特征、延迟感知安全带规则、known-context 策略重放和下一轮 31 行派生 Simulink 验证矩阵。

关键结果应谨慎表述：R032 fitted band projection 在 R031 已知 9 个上下文上 mean regret 为 `0.000`，dense fallback 为 `0.337`，direct proxy override 为 `1.107`；但这是校准一致性结果，不是独立泛化、硬件验证或 `T_slew` 全局最优证明。leave-one-tau nearest-neighbor stress policy 的 mean regret 为 `0.589`，反而说明仅按 `tau_AI` 做简单近邻插值会在非光滑 skip/reentry 边界失败。

当前最稳妥的 R032 结论是：AI/表驱动监督层只能作为 `q_phi/r_hat` 候选 score/risk 生成器，最终 `T_slew,plant` 必须经过 delay-aware `B_epsilon^sw` 投影；`10A/score_settle010` 保留 `30/33us` 延迟敏感近似并列带，`20A/base` 保留 `80us` dense fallback 并继续阻止 `86us` override，`20A/score_settle005` 将 `38/50/58us` 作为中间候选带但继续阻止 `66us` 直接覆盖。
"""
    append_once(ROOT / "RESEARCH_BRIEF.md", "## R032 最新进展", brief)

    paper = (OUT / "iqcot_r032_delay_aware_band_paper_section.md").read_text(encoding="utf-8")
    append_once(OUT / "iqcot_integrated_research_paper.md", "## R032：短时风险预测接口", paper)

    evidence = """
### C26 / R032：delay-aware `B_epsilon^sw` band projection

| ID | 论断 | 支撑证据 | 强度 | 允许写法 | 禁止写法 |
|---|---|---|---|---|---|
| C26 | R032 将 R031 的延迟敏感局部带整理为短时风险预测接口：`q_phi` 生成候选 score/ranking，`r_hat` 估计 skip/settling/phase 风险，最终 `T_slew` 经 `B_epsilon^sw` 投影后提交 | `iqcot_r032_delay_aware_band_predictor.py`；`iqcot_r032_candidate_risk_features.csv` 共 `40` 行候选；`iqcot_r032_policy_summary.csv` 中 fitted band known-context mean regret `0.000`、dense fallback `0.337`、direct proxy `1.107`、nearest-tau LOTO stress `0.589`；`iqcot_r032_next_validation_plan.csv` 生成 `31` 行下一轮验证矩阵 | 中等，边界强 | “R032 支持 delay-aware local band with dense fallback，并说明简单延迟近邻插值不足；AI/表驱动应输出候选 score/risk，再经过投影。” | “R032 已证明 AI/proxy 泛化优于 dense table、已完成硬件验证、或 `T_slew` 存在全局最优。” |

R032 的 `0.000` 是 R031 已知上下文上的拟合一致性，不是独立验证。最重要的负面证据是 `nearest_tau_loto_predictor` 的 mean regret `0.589`，它提示非光滑 skip/reentry 边界不能用简单 `tau_AI` 插值解决。
"""
    append_once(OUT / "iqcot_claims_evidence_matrix.md", "### C26 / R032", evidence)

    derivation = """
## R032 Addition: short-horizon risk interface

R032 把 R031 的 delay-aware local band 进一步写成 PIS-IEK 监督层接口，而不是新的内环控制律：

```text
q_phi(z_k, T_slew, tau_AI) -> candidate score/ranking
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate)
```

这里 `z_k` 至少包含 target/load-drop、objective weight、`tau_AI`、候选 `T_slew`、dense fallback identity，以及可部署时能短时估计的 phase-spacing/skip 状态。R032 的后处理表明，已知上下文拟合投影可以把 R031 证据组织成 `30/33us`、`80us fallback`、`38/50/58us` 等局部带，但 leave-one-tau nearest-neighbor stress 的 mean regret 为 `0.589`，说明该接口仍需要真正的短时风险预测或后续派生 Simulink 验证，而不能退化为简单查表插值。
"""
    append_once(OUT / "iqcot_pis_iek_derivation_package.md", "## R032 Addition", derivation)

    validation = """
## 22. R032 delay-aware `B_epsilon^sw` 监督层接口

R032 已生成 `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`，把 R031 的最小 held-out 结果转成可执行的候选风险表、投影规则和下一轮验证矩阵。该步骤不运行或修改 `.slx`，其角色是设计监督层接口：

```text
q_phi(z_k, T_slew, tau_AI) -> score/ranking candidate
r_hat(z_k, T_slew, tau_AI, recent_phase_state)
  -> [skip risk, settling risk, phase-spacing risk]
T_slew,plant = Proj_{B_epsilon^sw}(T_slew,candidate)
```

当前策略重放结果为：R032 fitted band projection 在 R031 已知 9 个上下文上 mean regret `0.000`，dense fallback `0.337`，direct proxy override `1.107`；但该 `0.000` 是校准一致性，不是泛化证明。更应该强调的是 nearest-tau LOTO stress policy 的 mean regret `0.589`，它说明只用 `tau_AI` 近邻插值不足以跨越 skip/reentry 非光滑边界。

下一轮派生 Simulink 验证矩阵为 `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`，共 `31` 行，重点验证 `10A/score_settle010` 的 `30/33us` 转换边界、`20A/base` 的 `80/82/84/86us` 边界，以及 `20A/score_settle005` 的 `38/50/58us` 中间带和 `66us` 负控。所有运行仍只允许使用 `E:/Desktop/codex/output/simulink_iek` 下的派生模型。
"""
    append_once(OUT / "iqcot_ai_supervisor_validation_design.md", "## 22. R032", validation)

    wiki_exp = """
# Experiment: R032 delay-aware B_epsilon^sw band projection

## ID

`exp:delay-aware-band-r032`

## Purpose

将 R031 最小 held-out 派生 Simulink 结果整理为可部署风格的 `q_phi/r_hat/B_epsilon^sw` 接口，并生成下一轮小矩阵验证计划。

## Inputs

- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_results_combined.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_context_summary.csv`
- `E:/Desktop/codex/output/iqcot_r031_minimal_validation_family_summary.csv`

## Outputs

- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`
- `E:/Desktop/codex/output/iqcot_r032_candidate_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_band_rules.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_replay.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_report.md`
- `E:/Desktop/codex/output/figures/fig43_r032_delay_aware_band.svg`

## Result

R032 expands R031 into `40` candidate risk rows.  Band decisions are plant-admissible `12`, candidate-only `20`, blocked `8`.  Known-context replay gives fitted band projection mean regret `0.000`, dense fallback `0.337`, direct proxy override `1.107`, and nearest-tau LOTO stress `0.589`.

## Boundary

The `0.000` fitted replay is not an independent generalization proof.  The stronger scientific point is that nearest-tau interpolation fails on non-smooth boundaries, so the supervisor should use short-horizon event risk prediction and dense fallback, not direct proxy override.
"""
    exp_path = WIKI / "experiments" / "delay-aware-band-r032.md"
    append_once(exp_path, "# Experiment: R032 delay-aware", wiki_exp)

    query = """
## R032 Update

- `exp:delay-aware-band-r032`: R032 uses the completed R031 minimal held-out results to design a short-horizon risk interface and delay-aware `B_epsilon^sw` projection.  Known-context fitted replay is `0.000` mean regret, but this is calibration consistency only; nearest-tau LOTO stress is `0.589`, supporting the need for event-risk prediction rather than simple delay interpolation.
"""
    append_once(WIKI / "query_pack.md", "## R032 Update", query)

    index = """
- `exp:delay-aware-band-r032` - R032 delay-aware `B_epsilon^sw` band projection and short-horizon risk interface
"""
    append_once(WIKI / "index.md", "exp:delay-aware-band-r032", index)

    log = "- `2026-06-21T08:20:00Z` add_experiment: added exp:delay-aware-band-r032 [verdict=partial confidence=medium]; R032 converts R031 held-out evidence into short-horizon risk interface and 31-row next validation plan\n"
    append_once(WIKI / "log.md", "exp:delay-aware-band-r032", log)

    edge_path = WIKI / "graph" / "edges.jsonl"
    edge_text = edge_path.read_text(encoding="utf-8", errors="replace") if edge_path.exists() else ""
    edge1 = '{"from": "idea:iqcot-pis-iek-four-phase", "to": "exp:delay-aware-band-r032", "type": "tested_by", "evidence": "R032 post-processes R031 held-out results into a short-horizon risk interface and delay-aware B_epsilon^sw projection.", "added": "2026-06-21T08:20:00Z"}'
    edge2 = '{"from": "exp:delay-aware-band-r032", "to": "exp:tightened-bepsilon-sw", "type": "refines", "evidence": "R032 upgrades R031 delay-aware local bands into q_phi/r_hat/B_epsilon^sw interface and emits a 31-row next validation plan.", "added": "2026-06-21T08:20:05Z"}'
    additions = []
    for edge in [edge1, edge2]:
        if edge not in edge_text:
            additions.append(edge)
    if additions:
        sep = "" if edge_text.endswith("\n") or not edge_text else "\n"
        edge_path.write_text(edge_text + sep + "\n".join(additions) + "\n", encoding="utf-8")

    print("R032 documentation snippets appended.")


if __name__ == "__main__":
    main()
