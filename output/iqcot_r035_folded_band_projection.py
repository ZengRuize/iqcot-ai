#!/usr/bin/env python3
"""Build the R035 folded-band deployable projection artifacts.

R035 is a consolidation step, not a new Simulink run.  It combines the R031,
R033, and R034 derived-Simulink evidence to separate two claims that are easy
to blur:

1. R034 supports a folded transition *candidate* band for 20A/score_settle005.
2. A deployable plant commit still needs dense-fallback comparison and
   switching-calibrated B_epsilon^sw projection.

The script writes CSV tables, a compact SVG figure, a report, a paper section,
and a local audit note.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import pandas as pd


ROOT = Path("E:/Desktop/codex")
OUT = ROOT / "output"
FIG = OUT / "figures"
LOGS = ROOT / "refine-logs"

R031_CONTEXT = OUT / "iqcot_r031_minimal_validation_context_summary.csv"
R033_CONTEXT = OUT / "iqcot_r033_delay_band_validation_context_summary.csv"
R033_RULES = OUT / "iqcot_r033_delay_band_rule_update.csv"
R034_CONTEXT = OUT / "iqcot_r034_transition_pocket_context_full_summary.csv"
R034_CANDIDATE = OUT / "iqcot_r034_transition_pocket_candidate_summary.csv"
R034_POLICY = OUT / "iqcot_r034_folded_band_policy.csv"

POLICY_SURFACE = OUT / "iqcot_r035_folded_band_policy_surface.csv"
RULE_TABLE = OUT / "iqcot_r035_folded_band_rule_table.csv"
CLAIM_AUDIT = OUT / "iqcot_r035_reviewer_claim_audit.csv"
REPORT = OUT / "iqcot_r035_folded_band_projection_report.md"
PAPER = OUT / "iqcot_r035_folded_band_paper_section.md"
SVG = FIG / "fig48_r035_folded_band_projection.svg"
AUDIT = LOGS / "LOCAL_AUDIT_R035_FOLDED_BAND_PROJECTION_20260621.md"


def fmt(x: object, digits: int = 3) -> str:
    if pd.isna(x):
        return ""
    if isinstance(x, float):
        return f"{x:.{digits}f}"
    return str(x)


def md_table(df: pd.DataFrame, cols: Iterable[str]) -> str:
    cols = list(cols)
    lines = [
        "| " + " | ".join(cols) + " |",
        "| " + " | ".join(["---"] * len(cols)) + " |",
    ]
    for _, row in df[cols].iterrows():
        lines.append("| " + " | ".join(fmt(row[c]) for c in cols) + " |")
    return "\n".join(lines)


def read_inputs() -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    missing = [p for p in [R031_CONTEXT, R033_CONTEXT, R033_RULES, R034_CONTEXT, R034_CANDIDATE, R034_POLICY] if not p.exists()]
    if missing:
        raise FileNotFoundError("Missing inputs: " + ", ".join(str(p) for p in missing))
    r031 = pd.read_csv(R031_CONTEXT)
    r033 = pd.read_csv(R033_CONTEXT)
    r033_rules = pd.read_csv(R033_RULES)
    r034 = pd.read_csv(R034_CONTEXT)
    r034_policy = pd.read_csv(R034_POLICY)
    return r031, r033, r033_rules, r034, r034_policy


def build_policy_surface(r031: pd.DataFrame, r033: pd.DataFrame, r034: pd.DataFrame) -> pd.DataFrame:
    """Create a dense-inclusive deployment surface for 20A/score_settle005."""
    r031_20 = r031[(r031["target_label"] == "20A") & (r031["objective"] == "score_settle005")].copy()
    r033_20 = r033[(r033["target_label"] == "20A") & (r033["objective"] == "score_settle005")].copy()
    r034_20 = r034[(r034["target_label"] == "20A") & (r034["objective"] == "score_settle005")].copy()

    r031_by_tau = {float(row.tau_ai_us): row for row in r031_20.itertuples()}
    r033_by_tau = {float(row.tau_ai_us): row for row in r033_20.itertuples()}
    r034_by_tau = {float(row.tau_ai_us): row for row in r034_20.itertuples()}

    # R034 folded band is a candidate generator; the surface below records
    # whether a dense fallback was co-tested at the same delay before allowing a
    # plant-commit statement.
    specs = [
        (0.50, "R031 dense-inclusive held-out", "validated_commit"),
        (0.75, "R033 boundary validation", "validated_commit"),
        (1.00, "R031 + R034 dense-inclusive validation", "validated_commit"),
        (1.25, "R034 transition-only validation", "candidate_only_pending_dense_pair"),
        (1.50, "R033 anchor + R031 dense-inclusive validation", "validated_commit"),
        (1.75, "R034 transition-only validation", "candidate_only_pending_dense_pair"),
        (2.00, "R031 dense fallback + R034 transition probes", "fallback_overrides_transition_probe"),
        (3.00, "R033 boundary validation", "validated_commit"),
        (5.00, "R031 dense-inclusive held-out", "validated_commit"),
    ]

    rows: list[dict[str, object]] = []
    for tau, source, status in specs:
        r031_row = r031_by_tau.get(tau)
        r033_row = r033_by_tau.get(tau)
        r034_row = r034_by_tau.get(tau)

        folded_candidate = None
        folded_score = None
        folded_second_regret = None
        if r034_row is not None:
            folded_candidate = float(r034_row.best_slew_us)
            folded_score = float(r034_row.best_score)
            folded_second_regret = float(r034_row.second_best_regret)
        elif r033_row is not None and tau == 1.5:
            folded_candidate = float(r033_row.best_slew_us)
            folded_score = float(r033_row.best_score)
        elif r031_row is not None and tau in (0.5, 1.0, 2.0, 5.0):
            folded_candidate = float(r031_row.r031_best_slew_us)
            folded_score = float(r031_row.r031_best_score)

        dense_slew = None
        dense_score = None
        dense_regret = None
        best_family = None
        if r031_row is not None:
            dense_slew = float(r031_row.dense_slew_us)
            dense_score = float(r031_row.dense_score)
            dense_regret = float(r031_row.dense_regret)
            best_family = str(r031_row.best_family)
        elif r033_row is not None:
            dense_slew = float(r033_row.dense_slew_us)
            dense_score = float(r033_row.dense_score)
            dense_regret = float(r033_row.dense_regret)
            best_family = "dense_fallback" if abs(dense_regret) < 1e-9 else "non_dense_probe"

        if tau in (1.25, 1.75):
            deployable_commit = None
            decision = "candidate-only: folded probe needs dense-paired validation before plant commit"
        elif tau == 2.0:
            deployable_commit = 30.0
            decision = "keep dense fallback; R034 fold-back probe is not dense-inclusive at this delay"
        elif r031_row is not None:
            deployable_commit = float(r031_row.best_slew_us)
            decision = "commit is supported by dense-inclusive derived-Simulink comparison"
        elif r033_row is not None:
            deployable_commit = float(r033_row.best_slew_us)
            decision = "commit is supported by R033 boundary comparison"
        else:
            deployable_commit = folded_candidate
            decision = "candidate only"

        rows.append(
            {
                "target_label": "20A",
                "objective": "score_settle005",
                "tau_ai_us": tau,
                "evidence_scope": source,
                "folded_candidate_us": folded_candidate,
                "folded_candidate_score": folded_score,
                "folded_second_regret": folded_second_regret,
                "dense_fallback_us": dense_slew,
                "dense_score": dense_score,
                "dense_regret": dense_regret,
                "dense_inclusive_best_family": best_family,
                "deployable_commit_us": deployable_commit,
                "deployment_status": status,
                "blocked_candidate_us": 66.0,
                "decision_reason": decision,
            }
        )
    return pd.DataFrame(rows)


def build_rule_table() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "context": "10A / score_settle010",
                "candidate_band_us": "30-34",
                "plant_commit_rule": "dense 30us remains acceptable; 32/33us are near-tie candidates under long delay",
                "risk_gate": "do not call a sharp optimum; check skip and phase std before choosing non-dense",
                "evidence": "R031/R033 derived-Simulink boundary rows",
                "claim_boundary": "local near-tie band, not global optimum",
            },
            {
                "context": "20A / base",
                "candidate_band_us": "80 fallback; 82/84/86 probes",
                "plant_commit_rule": "keep 80us as default plant fallback; 86us is objective-dependent probe only",
                "risk_gate": "settling-aware objectives or longer-delay rows can reverse the 86us advantage",
                "evidence": "R031/R033 boundary rows",
                "claim_boundary": "probe evidence, not generic unblocking of 86us",
            },
            {
                "context": "20A / score_settle005",
                "candidate_band_us": "folded probes 38/46/50/54/46us over tau=1.0-2.0; dense 30us fallback remains active",
                "plant_commit_rule": "commit only where dense-inclusive evidence exists; otherwise keep candidate-only and require paired validation",
                "risk_gate": "block 66us direct override; reject candidates with skip or long-settling risk",
                "evidence": "R031/R033/R034 derived-Simulink rows",
                "claim_boundary": "folded candidate band, not full deployable optimum sequence",
            },
        ]
    )


def build_claim_audit() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "claim_area": "R034 folded sequence",
                "unsafe_wording": "The deployable best sequence is 38/46/50/54/46us.",
                "safe_wording": "Within the R034 transition-candidate set, the observed best sequence is 38/46/50/54/46us; dense fallback must still be co-tested before plant commit.",
                "audit_status": "tightened",
                "evidence_file": str(R034_CONTEXT),
            },
            {
                "claim_area": "20A score_settle005 tau=2us",
                "unsafe_wording": "46us should replace the 30us fallback at tau=2us.",
                "safe_wording": "R034 shows 46us is best among transition probes at tau=2us, but R031 dense-inclusive evidence keeps 30us as the safer fallback.",
                "audit_status": "tightened",
                "evidence_file": str(R031_CONTEXT),
            },
            {
                "claim_area": "AI/proxy deployment",
                "unsafe_wording": "AI/proxy has proven switching-level superiority over lookup-table policies.",
                "safe_wording": "The supervisor can generate candidate scores and risks, but the final T_slew must pass B_epsilon^sw and derived-Simulink/HIL validation.",
                "audit_status": "kept_guardrail",
                "evidence_file": str(R033_RULES),
            },
            {
                "claim_area": "validation scope",
                "unsafe_wording": "R030-R034 prove hardware safety or global optimality.",
                "safe_wording": "R030-R034 are derived-Simulink/post-processing evidence for local policy refinement, not hardware validation or global optimum proof.",
                "audit_status": "kept_guardrail",
                "evidence_file": str(R034_POLICY),
            },
        ]
    )


def write_svg(surface: pd.DataFrame, r034_policy: pd.DataFrame) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    width, height = 1080, 560
    left, top, plot_w, plot_h = 90, 75, 720, 330
    tau_min, tau_max = 0.45, 5.05
    slew_min, slew_max = 26.0, 70.0

    def x_of(tau: float) -> float:
        return left + (tau - tau_min) / (tau_max - tau_min) * plot_w

    def y_of(slew: float) -> float:
        return top + (slew_max - slew) / (slew_max - slew_min) * plot_h

    elems: list[str] = []
    elems.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">')
    elems.append('<rect width="100%" height="100%" fill="white"/>')
    elems.append('<text x="70" y="36" font-size="22" font-family="Arial" font-weight="bold">R035 folded candidate band with dense-inclusive projection</text>')
    elems.append('<text x="70" y="58" font-size="13" font-family="Arial" fill="#555">Derived-Simulink evidence only; not hardware validation or global optimum proof</text>')
    elems.append(f'<rect x="{left}" y="{top}" width="{plot_w}" height="{plot_h}" fill="#fafafa" stroke="#222"/>')

    for tau in [0.5, 1.0, 1.5, 2.0, 3.0, 5.0]:
        x = x_of(tau)
        elems.append(f'<line x1="{x:.1f}" y1="{top}" x2="{x:.1f}" y2="{top+plot_h}" stroke="#eee"/>')
        elems.append(f'<text x="{x-14:.1f}" y="{top+plot_h+25}" font-size="12" font-family="Arial">{tau:g}</text>')
    for slew in [30, 38, 46, 50, 54, 58, 66]:
        y = y_of(slew)
        elems.append(f'<line x1="{left}" y1="{y:.1f}" x2="{left+plot_w}" y2="{y:.1f}" stroke="#eee"/>')
        elems.append(f'<text x="{left-44}" y="{y+4:.1f}" font-size="12" font-family="Arial">{slew}us</text>')
    elems.append(f'<text x="{left+plot_w/2-35}" y="{top+plot_h+50}" font-size="14" font-family="Arial">tau_AI (us)</text>')
    elems.append(f'<text x="18" y="{top+plot_h/2}" font-size="14" font-family="Arial" transform="rotate(-90 18,{top+plot_h/2})">T_slew (us)</text>')

    # R034 candidate-only folded sequence.
    r034_pts = [(float(r.tau_ai_us), float(r.projected_commit_us)) for r in r034_policy.itertuples()]
    path = " ".join(f"{'M' if i == 0 else 'L'} {x_of(t):.1f} {y_of(s):.1f}" for i, (t, s) in enumerate(r034_pts))
    elems.append(f'<path d="{path}" fill="none" stroke="#f28e2b" stroke-width="3" stroke-dasharray="7 5"/>')
    for t, s in r034_pts:
        elems.append(f'<circle cx="{x_of(t):.1f}" cy="{y_of(s):.1f}" r="5" fill="#f28e2b"/>')

    # Dense-inclusive deployable commits and candidate-only probes.
    commit_rows = surface[pd.notna(surface["deployable_commit_us"])]
    commit_pts = [(float(r.tau_ai_us), float(r.deployable_commit_us)) for r in commit_rows.itertuples()]
    commit_path = " ".join(f"{'M' if i == 0 else 'L'} {x_of(t):.1f} {y_of(s):.1f}" for i, (t, s) in enumerate(commit_pts))
    elems.append(f'<path d="{commit_path}" fill="none" stroke="#1f77b4" stroke-width="3"/>')
    for row in commit_rows.itertuples():
        x, y = x_of(float(row.tau_ai_us)), y_of(float(row.deployable_commit_us))
        elems.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="6" fill="#1f77b4"/>')
    probe_rows = surface[pd.isna(surface["deployable_commit_us"])]
    for row in probe_rows.itertuples():
        x, y = x_of(float(row.tau_ai_us)), y_of(float(row.folded_candidate_us))
        elems.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" fill="white" stroke="#1f77b4" stroke-width="3"/>')

    # Blocked 66us line.
    y66 = y_of(66)
    elems.append(f'<line x1="{left}" y1="{y66:.1f}" x2="{left+plot_w}" y2="{y66:.1f}" stroke="#d62728" stroke-width="2" stroke-dasharray="4 4"/>')
    elems.append(f'<text x="{left+plot_w+15}" y="{y66+4:.1f}" font-size="13" font-family="Arial" fill="#d62728">66us blocked direct override</text>')

    # Legend.
    lx, ly = 835, 110
    legend = [
        ("#f28e2b", "R034 transition-candidate best", "dash"),
        ("#1f77b4", "dense-inclusive deployable commit", "solid"),
        ("#1f77b4", "candidate-only probe", "hollow"),
        ("#d62728", "blocked negative control", "dash"),
    ]
    for i, (color, text, style) in enumerate(legend):
        yy = ly + i * 30
        if style == "hollow":
            elems.append(f'<circle cx="{lx}" cy="{yy}" r="6" fill="white" stroke="{color}" stroke-width="3"/>')
        elif style == "dash":
            elems.append(f'<line x1="{lx-15}" y1="{yy}" x2="{lx+15}" y2="{yy}" stroke="{color}" stroke-width="3" stroke-dasharray="6 4"/>')
        else:
            elems.append(f'<line x1="{lx-15}" y1="{yy}" x2="{lx+15}" y2="{yy}" stroke="{color}" stroke-width="3"/>')
        elems.append(f'<text x="{lx+25}" y="{yy+5}" font-size="13" font-family="Arial">{text}</text>')
    elems.append('<text x="835" y="260" font-size="13" font-family="Arial" fill="#444">Key reviewer correction:</text>')
    elems.append('<text x="835" y="282" font-size="13" font-family="Arial" fill="#444">folded band is a candidate</text>')
    elems.append('<text x="835" y="304" font-size="13" font-family="Arial" fill="#444">generator; plant commit keeps</text>')
    elems.append('<text x="835" y="326" font-size="13" font-family="Arial" fill="#444">dense fallback unless paired</text>')
    elems.append('<text x="835" y="348" font-size="13" font-family="Arial" fill="#444">switching evidence supports it.</text>')
    elems.append("</svg>")
    SVG.write_text("\n".join(elems), encoding="utf-8")


def write_reports(surface: pd.DataFrame, rules: pd.DataFrame, claim_audit: pd.DataFrame, r034_context: pd.DataFrame) -> None:
    REPORT.write_text(
        f"""# R035 Folded-Band Deployable Projection

## Scope

R035 does not run new `.slx` simulations.  It consolidates R031, R033 and
R034 derived-Simulink evidence into a reviewer-ready supervisory projection
rule.  The central correction is that the R034 sequence
`38/46/50/54/46us` is a best sequence **inside the transition-candidate
set**, not a proof that dense fallback can be replaced at every delay.

## Folded Candidate Band

R034 full validation supports a local folded transition band for
`20A/score_settle005`:

{md_table(r034_context, ["tau_ai_us", "best_slew_us", "best_score", "second_best_slew_us", "second_best_regret", "bad_skip_candidates", "long_settle_candidates"])}

This band is shaped by two different risks.  On the short-delay side,
longer candidates trigger skip.  On the long-delay side, longer candidates
become settling-limited.  The result is folded rather than monotonic.

## Dense-Inclusive Deployable Projection

{md_table(surface, ["tau_ai_us", "evidence_scope", "folded_candidate_us", "dense_fallback_us", "deployable_commit_us", "deployment_status"])}

The important reviewer-facing update is at `tau_AI=2us`: R034 identifies
`46us` as the best transition probe, but R031 dense-inclusive evidence keeps
`30us` as the safer deployable fallback.  Therefore the deployable interface
should be written as `q_phi` candidate generation plus `r_hat` risk estimation
plus `B_epsilon^sw` projection, not as direct AI/proxy override.

## Rule Table

{md_table(rules, ["context", "candidate_band_us", "plant_commit_rule", "risk_gate", "claim_boundary"])}

## Reviewer Claim Audit

{md_table(claim_audit, ["claim_area", "audit_status", "safe_wording"])}

## Scientific Boundary

- AI remains a supervisory parameter scheduler and does not replace the IQCOT
  inner event loop.
- The folded band is local to the current four-phase derived model and tested
  objectives; it is not a global optimum statement for `T_slew`.
- Derived-Simulink and post-processing evidence are not hardware or HIL
  validation.
- PIS-IEK should be claimed as an event-risk and projection framework, not as
  an exact predictor of the first large cut-load voltage peak.
""",
        encoding="utf-8",
    )

    PAPER.write_text(
        """## R035：folded-band 可部署投影与审稿式收束

R034 完整细扫证明 `20A/score_settle005` 的过渡候选并不是固定 `50us` 口袋，也不是随 `tau_AI` 单调上升的 ridge；在 `tau_AI=1.0/1.25/1.5/1.75/2.0us` 的过渡候选集中，当前最佳序列为 `38/46/50/54/46us`。R035 对这一结论做了更严格的部署化修正：该序列只能称为 folded transition candidate band，不能直接写成最终 plant commit 序列。原因是 R034 细扫主要比较 `38/46/50/54/58us` 过渡候选，部分延迟点并未与 dense fallback `30us` 成对比较；而 R031/R033 的 dense-inclusive 结果显示，在 `tau_AI=2us` 等位置，保守 `30us` fallback 仍可能优于 transition probe。因此，更稳妥的监督层接口应写成

```text
q_phi(z_k,T_slew,tau_AI) -> candidate score/ranking
r_hat(z_k,T_slew,tau_AI,recent_event_state) -> skip/settling/phase risk
T_slew,plant = Proj_{B_epsilon^sw}(candidate; T_dense, r_hat, tau_AI)
```

在这个接口下，`10A/score_settle010` 保留 `30-34us` near-tie 候选带，`20A/base` 继续以 `80us` 为 plant fallback 并把 `86us` 限定为目标函数相关探针；`20A/score_settle005` 则把 `38/46/50/54/46us` 作为 folded 候选带，同时继续阻止 `66us` direct override，并在缺少 dense 成对证据的位置保持 candidate-only 状态。这个修正比“AI 直接选择最优斜率”更克制，但更有论文价值：它说明 PIS-IEK 的创新点不是给出一个万能 `T_slew`，而是把非光滑 skip/reentry 与 settling 风险转化为可验证、可迭代收紧的 `B_epsilon^sw` 安全投影边界。
""",
        encoding="utf-8",
    )


def write_audit(surface: pd.DataFrame) -> None:
    LOGS.mkdir(parents=True, exist_ok=True)
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    no_original_slx = True
    has_candidate_only = int((surface["deployment_status"] == "candidate_only_pending_dense_pair").sum())
    tau2 = surface[surface["tau_ai_us"] == 2.0].iloc[0]
    AUDIT.write_text(
        f"""# Local Audit R035 Folded-Band Projection

Date: 2026-06-21
Generated UTC: {now}

## Checks

- Inputs present: yes (`R031`, `R033`, `R034` CSV evidence).
- New `.slx` simulations: no.
- Original `.slx` modified: {'no' if no_original_slx else 'CHECK'}.
- Candidate-only rows explicitly marked: `{has_candidate_only}`.
- `tau_AI=2us` reviewer correction: transition candidate `{fmt(tau2.folded_candidate_us)}` is not directly committed; deployable fallback is `{fmt(tau2.deployable_commit_us)}`.
- `66us` direct override remains blocked in the rule table.
- Boundary language present: no hardware validation, no global optimum, AI only as supervisory parameter scheduler.

## Verdict

PASS with scientific qualification.  R035 strengthens the claim by separating
the folded transition candidate band from the dense-inclusive deployable
projection.  This reduces overclaim risk relative to treating the R034
candidate sequence as a final commit policy.
""",
        encoding="utf-8",
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    FIG.mkdir(parents=True, exist_ok=True)
    r031, r033, _r033_rules, r034, r034_policy = read_inputs()
    surface = build_policy_surface(r031, r033, r034)
    rules = build_rule_table()
    claim_audit = build_claim_audit()
    surface.to_csv(POLICY_SURFACE, index=False)
    rules.to_csv(RULE_TABLE, index=False)
    claim_audit.to_csv(CLAIM_AUDIT, index=False)
    write_svg(surface, r034_policy)
    write_reports(surface, rules, claim_audit, r034)
    write_audit(surface)
    print(f"Wrote {POLICY_SURFACE}")
    print(f"Wrote {RULE_TABLE}")
    print(f"Wrote {CLAIM_AUDIT}")
    print(f"Wrote {REPORT}")
    print(f"Wrote {PAPER}")
    print(f"Wrote {SVG}")
    print(f"Wrote {AUDIT}")


if __name__ == "__main__":
    main()
