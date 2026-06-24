from __future__ import annotations

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parent
CHUNK_FILES = [
    ROOT / "iqcot_r027_proxy_table_in_loop_results_r037_minimal_extrapolation_rows001_003.csv",
    ROOT / "iqcot_r027_proxy_table_in_loop_results_r037_minimal_extrapolation_rows004_006.csv",
    ROOT / "iqcot_r027_proxy_table_in_loop_results_r037_minimal_extrapolation_rows007_009.csv",
]
TRAINING_DATASET = ROOT / "iqcot_r037_rhat_training_dataset.csv"
POLICY_EVAL = ROOT / "iqcot_r037_rhat_policy_context_eval.csv"


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        return list(csv.DictReader(f))


def write_csv(path: Path, rows: list[dict[str, object]], fields: list[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fields)
        writer.writeheader()
        for row in rows:
            writer.writerow({field: row.get(field, "") for field in fields})


def f(row: dict[str, object], key: str, default: float = float("nan")) -> float:
    value = row.get(key, "")
    if value in ("", None, "NaN", "nan"):
        return default
    return float(value)


def s(row: dict[str, object], key: str, default: str = "") -> str:
    value = row.get(key, default)
    return default if value is None else str(value)


def normalize(row: dict[str, str], evidence_source: str, source_priority: int) -> dict[str, object]:
    candidate = row.get("candidate_ref_slew_us") or row.get("selected_ref_slew_us")
    phase = row.get("phase_std_ns") or row.get("final_phase_spacing_std_ns")
    return {
        "target_label": row.get("target_label", ""),
        "objective": row.get("objective", ""),
        "tau_ai_us": float(row.get("tau_ai_us", "nan")),
        "candidate_ref_slew_us": float(candidate),
        "selected_objective_score": float(row.get("selected_objective_score", "nan")),
        "undershoot_mV": row.get("undershoot_mV", ""),
        "settle_time_us": row.get("settle_time_us", ""),
        "skip_count_est": row.get("skip_count_est", ""),
        "phase_std_ns": phase,
        "evidence_source": evidence_source,
        "source_priority": source_priority,
    }


def read_r038() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in CHUNK_FILES:
        if not path.exists():
            raise FileNotFoundError(path)
        for row in read_csv(path):
            rows.append(normalize(row, "R038_minimal_extrapolation", 4))
    return rows


def read_prior() -> list[dict[str, object]]:
    keep_tau = {1.25, 1.5, 1.75, 2.0}
    rows: list[dict[str, object]] = []
    for row in read_csv(TRAINING_DATASET):
        tau = float(row["tau_ai_us"])
        if (
            row.get("target_label") == "20A"
            and row.get("objective") == "score_settle005"
            and round(tau, 6) in keep_tau
        ):
            rows.append(normalize(row, row.get("evidence_source", "R037_training_view"), 3))
    return rows


def read_policy() -> dict[float, dict[str, str]]:
    out: dict[float, dict[str, str]] = {}
    for row in read_csv(POLICY_EVAL):
        out[round(float(row["tau_ai_us"]), 6)] = row
    return out


def dedupe_latest(rows: list[dict[str, object]]) -> list[dict[str, object]]:
    latest: dict[tuple[float, float], dict[str, object]] = {}
    for row in rows:
        key = (round(f(row, "tau_ai_us"), 6), round(f(row, "candidate_ref_slew_us"), 6))
        if key not in latest or f(row, "source_priority") > f(latest[key], "source_priority"):
            latest[key] = row
    out = list(latest.values())
    out.sort(key=lambda r: (f(r, "tau_ai_us"), f(r, "candidate_ref_slew_us")))
    return out


def build_summary(latest: list[dict[str, object]], policy: dict[float, dict[str, str]]) -> list[dict[str, object]]:
    grouped: dict[float, list[dict[str, object]]] = {}
    for row in latest:
        grouped.setdefault(round(f(row, "tau_ai_us"), 6), []).append(row)

    interpretations = {
        1.25: "R038 42/44us probes do not beat the R036 46us folded commit.",
        1.5: "R038 46/54us probes do not beat the existing 50us center pocket; 46us shows skip risk.",
        1.75: "R038 52/56us probes do not beat the R036 54us folded commit.",
        2.0: "R038 reveals a near-tie foldback band: 48us is slightly below 30us, but the margin is too small to remove dense fallback.",
    }

    summary: list[dict[str, object]] = []
    for tau in sorted(grouped):
        rows = sorted(grouped[tau], key=lambda r: f(r, "selected_objective_score"))
        best = rows[0]
        dense_rows = [r for r in rows if abs(f(r, "candidate_ref_slew_us") - 30.0) < 1e-9]
        dense_score = f(dense_rows[0], "selected_objective_score") if dense_rows else float("nan")
        pol = policy.get(tau, {})
        old_r037_score = float(pol["r037_score"]) if pol else float("nan")
        context_best = f(best, "selected_objective_score")
        for r in rows:
            r["context_best_score_after_r038"] = context_best
            r["regret_after_r038"] = f(r, "selected_objective_score") - context_best
        summary.append(
            {
                "target_label": "20A",
                "objective": "score_settle005",
                "tau_ai_us": tau,
                "n_candidates_after_r038": len(rows),
                "best_slew_us_after_r038": f(best, "candidate_ref_slew_us"),
                "best_score_after_r038": context_best,
                "best_evidence_source": s(best, "evidence_source"),
                "dense_30_score": dense_score,
                "best_minus_dense_score": context_best - dense_score,
                "old_r037_slew_us": float(pol["r037_slew_us"]) if pol else float("nan"),
                "old_r037_score": old_r037_score,
                "best_minus_old_r037_score": context_best - old_r037_score,
                "old_oracle_slew_us": float(pol["oracle_slew_us"]) if pol else float("nan"),
                "old_oracle_score": float(pol["oracle_score"]) if pol else float("nan"),
                "interpretation": interpretations.get(tau, ""),
            }
        )
    return summary


def markdown_table(rows: list[dict[str, object]], fields: list[str]) -> str:
    lines = [
        "| " + " | ".join(fields) + " |",
        "| " + " | ".join(["---"] * len(fields)) + " |",
    ]
    for row in rows:
        vals = []
        for field in fields:
            value = row.get(field, "")
            if isinstance(value, float):
                vals.append(f"{value:.3f}")
            else:
                vals.append(str(value))
        lines.append("| " + " | ".join(vals) + " |")
    return "\n".join(lines)


def write_report(r038: list[dict[str, object]], summary: list[dict[str, object]]) -> None:
    fields = [
        "tau_ai_us",
        "n_candidates_after_r038",
        "best_slew_us_after_r038",
        "best_score_after_r038",
        "dense_30_score",
        "best_minus_dense_score",
        "old_r037_slew_us",
        "best_minus_old_r037_score",
        "interpretation",
    ]
    text = f"""# R038 Minimal Extrapolation Derived-Simulink Validation

## Scope

R038 executes the 9-row minimal extrapolation matrix created by R037 on the
derived delayed-reference Simulink runner. It checks local robustness around
`46us@1.25us`, `50us@1.5us`, `54us@1.75us`, and the `tau_AI=2us` foldback
boundary. The original `.slx` is not modified.

## Execution

- Rows executed: `{len(r038)}`
- Successful rows: `{sum(1 for r in r038 if str(r.get('success', '')).lower() in ('1', 'true'))}`
- Chunks: `rows001_003`, `rows004_006`, `rows007_009`
- Figure: `figures/fig51_r038_minimal_extrapolation.svg`

## Context Summary

{markdown_table(summary, fields)}

## Interpretation

- `tau_AI=1.25us`: `42/44us` do not beat the already validated `46us` folded commit.
- `tau_AI=1.5us`: `46us` triggers one skip and is much worse; `54us` is also worse than the `50us` anchor.
- `tau_AI=1.75us`: `52/56us` do not beat the already validated `54us` folded commit.
- `tau_AI=2.0us`: `48us` is slightly better than the previous `30us` dense fallback by about `0.020` score, while `44us` is nearly tied. This should be written as a near-tie foldback band, not as proof that `30us` is globally wrong.

## Boundary

These are derived-Simulink delayed-reference results, not hardware/HIL
validation. AI remains a supervisory parameter scheduler. R038 does not prove a
global `T_slew` optimum and does not prove that the current `r_hat` predictor is
independently generalizable.
"""
    (ROOT / "iqcot_r038_minimal_extrapolation_report.md").write_text(text, encoding="utf-8")


def write_rule_update(summary: list[dict[str, object]]) -> None:
    rows = [
        {
            "scope": "20A/score_settle005",
            "tau_ai_us": 1.25,
            "previous_rule": "46us folded commit after R036 dense-paired validation",
            "r038_result": "42/44us do not beat 46us",
            "updated_safe_rule": "keep 46us as local folded candidate",
            "boundary": "derived Simulink only; not hardware validation",
        },
        {
            "scope": "20A/score_settle005",
            "tau_ai_us": 1.5,
            "previous_rule": "50us center pocket anchor",
            "r038_result": "46us skip risk; 54us long-settling/worse score",
            "updated_safe_rule": "keep 50us as local center-pocket candidate",
            "boundary": "derived Simulink only; not hardware validation",
        },
        {
            "scope": "20A/score_settle005",
            "tau_ai_us": 1.75,
            "previous_rule": "54us folded commit after R036 dense-paired validation",
            "r038_result": "52/56us do not beat 54us",
            "updated_safe_rule": "keep 54us as local folded candidate",
            "boundary": "derived Simulink only; not hardware validation",
        },
        {
            "scope": "20A/score_settle005",
            "tau_ai_us": 2.0,
            "previous_rule": "30us dense-inclusive foldback guard",
            "r038_result": "44/48us near-tie with 30us; 48us improves score by about 0.020",
            "updated_safe_rule": "write as 30/44/48us near-tie foldback band; keep dense fallback until broader validation",
            "boundary": "near-tie local evidence, not a new global optimum",
        },
    ]
    fields = ["scope", "tau_ai_us", "previous_rule", "r038_result", "updated_safe_rule", "boundary"]
    write_csv(ROOT / "iqcot_r038_foldback_rule_update.csv", rows, fields)


def write_svg(latest: list[dict[str, object]]) -> None:
    fig_dir = ROOT / "figures"
    fig_dir.mkdir(exist_ok=True)
    path = fig_dir / "fig51_r038_minimal_extrapolation.svg"
    width, height = 920, 520
    left, right, top, bottom = 80, 40, 45, 70
    plot_w = width - left - right
    plot_h = height - top - bottom
    xs = [f(r, "tau_ai_us") for r in latest]
    ys = [f(r, "selected_objective_score") for r in latest]
    x_min, x_max = min(xs), max(xs)
    y_min, y_max = min(ys), max(ys)
    y_pad = (y_max - y_min) * 0.08
    y_min -= y_pad
    y_max += y_pad

    def sx(x: float) -> float:
        return left + (x - x_min) / (x_max - x_min) * plot_w

    def sy(y: float) -> float:
        return top + (y_max - y) / (y_max - y_min) * plot_h

    colors = {
        "R038_minimal_extrapolation": "#d62728",
        "R036_dense_pair": "#1f77b4",
        "R031_minimal_dense_inclusive": "#2ca02c",
        "R034_transition_pocket_full": "#9467bd",
    }
    lines = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2}" y="25" text-anchor="middle" font-family="Arial" font-size="18">R038 minimal extrapolation: score landscape around folded-band boundaries</text>',
        f'<line x1="{left}" y1="{height-bottom}" x2="{width-right}" y2="{height-bottom}" stroke="#333"/>',
        f'<line x1="{left}" y1="{top}" x2="{left}" y2="{height-bottom}" stroke="#333"/>',
        f'<text x="{width/2}" y="{height-22}" text-anchor="middle" font-family="Arial" font-size="14">tau_AI (us)</text>',
        f'<text x="22" y="{height/2}" transform="rotate(-90 22 {height/2})" text-anchor="middle" font-family="Arial" font-size="14">score + 0.05 T_settle</text>',
    ]
    for x in sorted(set(xs)):
        px = sx(x)
        lines.append(f'<line x1="{px:.1f}" y1="{height-bottom}" x2="{px:.1f}" y2="{height-bottom+5}" stroke="#333"/>')
        lines.append(f'<text x="{px:.1f}" y="{height-bottom+22}" text-anchor="middle" font-family="Arial" font-size="12">{x:.2f}</text>')
    for t in range(6):
        y = y_min + (y_max - y_min) * t / 5
        py = sy(y)
        lines.append(f'<line x1="{left-5}" y1="{py:.1f}" x2="{left}" y2="{py:.1f}" stroke="#333"/>')
        lines.append(f'<line x1="{left}" y1="{py:.1f}" x2="{width-right}" y2="{py:.1f}" stroke="#eee"/>')
        lines.append(f'<text x="{left-10}" y="{py+4:.1f}" text-anchor="end" font-family="Arial" font-size="12">{y:.2f}</text>')

    for row in latest:
        x = f(row, "tau_ai_us")
        y = f(row, "selected_objective_score")
        slew = f(row, "candidate_ref_slew_us")
        source = s(row, "evidence_source")
        color = colors.get(source, "#555")
        px, py = sx(x), sy(y)
        radius = 5.5 if source == "R038_minimal_extrapolation" else 4
        lines.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="{radius}" fill="{color}" opacity="0.9"/>')
        lines.append(f'<text x="{px+7:.1f}" y="{py-7:.1f}" font-family="Arial" font-size="11">{slew:.0f}us</text>')

    legend_x, legend_y = width - 315, 60
    legend_items = [
        ("R038 probes", "#d62728"),
        ("prior dense/folded evidence", "#555"),
    ]
    for i, (label, color) in enumerate(legend_items):
        y = legend_y + i * 22
        lines.append(f'<circle cx="{legend_x}" cy="{y}" r="5" fill="{color}"/>')
        lines.append(f'<text x="{legend_x+12}" y="{y+4}" font-family="Arial" font-size="12">{label}</text>')
    lines.append("</svg>")
    path.write_text("\n".join(lines), encoding="utf-8")


def write_paper_section(summary: list[dict[str, object]]) -> None:
    tau2 = next(r for r in summary if abs(f(r, "tau_ai_us") - 2.0) < 1e-9)
    improvement = abs(f(tau2, "best_minus_dense_score"))
    text = f"""### R038 minimal extrapolation validation

To test whether the R037 short-horizon `r_hat` interface overfits the observed
folded-band anchors, R038 executes nine additional derived-Simulink
delayed-reference cases around the local boundaries. Around `tau_AI=1.25us`,
the `42/44us` left-neighbor probes remain worse than the previously validated
`46us` folded commit. Around `tau_AI=1.75us`, the `52/56us` probes remain worse
than `54us`. Around the center pocket, `46us@1.5us` triggers a skip event and
`54us@1.5us` has longer settling, so the existing `50us` anchor remains the
better local candidate.

The only boundary that changes is `tau_AI=2.0us`. The new `44/48us` probes are
near-tied with the old dense-inclusive `30us` fallback; `48us` is lower than
`30us` by approximately `{improvement:.3f}` score in the current objective.
This does not justify replacing the dense fallback globally. The safer wording
is that R038 turns the `tau_AI=2us` rule from a hard `30us` fallback into a
local `30/44/48us` foldback near-tie band that still requires `B_epsilon^sw`
projection and further validation before deployment.
"""
    (ROOT / "iqcot_r038_minimal_extrapolation_paper_section.md").write_text(text, encoding="utf-8")


def main() -> None:
    r038_raw = []
    for path in CHUNK_FILES:
        r038_raw.extend(read_csv(path))
    r038 = read_r038()
    prior = read_prior()
    policy = read_policy()
    latest = dedupe_latest(prior + r038)
    summary = build_summary(latest, policy)

    evidence_fields = [
        "target_label",
        "objective",
        "tau_ai_us",
        "candidate_ref_slew_us",
        "selected_objective_score",
        "undershoot_mV",
        "settle_time_us",
        "skip_count_est",
        "phase_std_ns",
        "evidence_source",
        "source_priority",
        "context_best_score_after_r038",
        "regret_after_r038",
    ]
    summary_fields = [
        "target_label",
        "objective",
        "tau_ai_us",
        "n_candidates_after_r038",
        "best_slew_us_after_r038",
        "best_score_after_r038",
        "best_evidence_source",
        "dense_30_score",
        "best_minus_dense_score",
        "old_r037_slew_us",
        "old_r037_score",
        "best_minus_old_r037_score",
        "old_oracle_slew_us",
        "old_oracle_score",
        "interpretation",
    ]

    write_csv(ROOT / "iqcot_r038_minimal_extrapolation_results_combined.csv", r038, evidence_fields[:11])
    write_csv(ROOT / "iqcot_r038_candidate_evidence_after_update.csv", latest, evidence_fields)
    write_csv(ROOT / "iqcot_r038_minimal_extrapolation_context_summary.csv", summary, summary_fields)
    write_rule_update(summary)
    write_svg(latest)
    write_report(r038_raw, summary)
    write_paper_section(summary)

    print("R038_POSTPROCESS_DONE")
    for row in summary:
        print(
            f"tau={f(row, 'tau_ai_us'):.2f} best={f(row, 'best_slew_us_after_r038'):.0f}us "
            f"score={f(row, 'best_score_after_r038'):.6f} "
            f"delta_dense={f(row, 'best_minus_dense_score'):.6f}"
        )


if __name__ == "__main__":
    main()
