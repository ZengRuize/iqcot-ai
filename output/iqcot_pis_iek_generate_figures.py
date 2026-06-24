import csv
import math
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")
FIG = OUT / "figures"
FIG.mkdir(exist_ok=True)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def svg_line_chart(path, title, series, x_label, y_label, width=900, height=520):
    margin_l, margin_r, margin_t, margin_b = 78, 28, 54, 72
    plot_w = width - margin_l - margin_r
    plot_h = height - margin_t - margin_b
    all_x = [x for s in series for x, _ in s["points"]]
    all_y = [y for s in series for _, y in s["points"]]
    x_min, x_max = min(all_x), max(all_x)
    y_min, y_max = min(all_y), max(all_y)
    if abs(x_max - x_min) < 1e-30:
        x_max = x_min + 1.0
    if abs(y_max - y_min) < 1e-30:
        y_max = y_min + 1.0
    y_pad = 0.08 * (y_max - y_min)
    y_min = max(0.0, y_min - y_pad)
    y_max += y_pad

    def sx(x):
        return margin_l + (x - x_min) / (x_max - x_min) * plot_w

    def sy(y):
        return margin_t + (y_max - y) / (y_max - y_min) * plot_h

    colors = ["#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#ff7f0e"]
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="white"/>',
        f'<text x="{width/2}" y="28" text-anchor="middle" font-family="Arial" font-size="18" font-weight="700">{title}</text>',
        f'<line x1="{margin_l}" y1="{margin_t + plot_h}" x2="{margin_l + plot_w}" y2="{margin_t + plot_h}" stroke="#222"/>',
        f'<line x1="{margin_l}" y1="{margin_t}" x2="{margin_l}" y2="{margin_t + plot_h}" stroke="#222"/>',
    ]
    for i in range(6):
        x = x_min + (x_max - x_min) * i / 5
        px = sx(x)
        parts.append(f'<line x1="{px:.2f}" y1="{margin_t + plot_h}" x2="{px:.2f}" y2="{margin_t + plot_h + 5}" stroke="#222"/>')
        parts.append(f'<text x="{px:.2f}" y="{margin_t + plot_h + 22}" text-anchor="middle" font-family="Arial" font-size="11">{x:.3g}</text>')
    for i in range(6):
        y = y_min + (y_max - y_min) * i / 5
        py = sy(y)
        parts.append(f'<line x1="{margin_l - 5}" y1="{py:.2f}" x2="{margin_l}" y2="{py:.2f}" stroke="#222"/>')
        parts.append(f'<line x1="{margin_l}" y1="{py:.2f}" x2="{margin_l + plot_w}" y2="{py:.2f}" stroke="#ddd"/>')
        parts.append(f'<text x="{margin_l - 9}" y="{py + 4:.2f}" text-anchor="end" font-family="Arial" font-size="11">{y:.3g}</text>')
    parts.append(f'<text x="{margin_l + plot_w/2}" y="{height - 22}" text-anchor="middle" font-family="Arial" font-size="13">{x_label}</text>')
    parts.append(f'<text x="18" y="{margin_t + plot_h/2}" transform="rotate(-90 18 {margin_t + plot_h/2})" text-anchor="middle" font-family="Arial" font-size="13">{y_label}</text>')

    legend_x = margin_l + plot_w - 190
    legend_y = margin_t + 12
    for idx, s in enumerate(series):
        color = colors[idx % len(colors)]
        pts = " ".join(f"{sx(x):.2f},{sy(y):.2f}" for x, y in s["points"])
        parts.append(f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2.2"/>')
        for x, y in s["points"]:
            parts.append(f'<circle cx="{sx(x):.2f}" cy="{sy(y):.2f}" r="3.2" fill="{color}"/>')
        ly = legend_y + idx * 20
        parts.append(f'<line x1="{legend_x}" y1="{ly}" x2="{legend_x + 28}" y2="{ly}" stroke="{color}" stroke-width="2.2"/>')
        parts.append(f'<text x="{legend_x + 36}" y="{ly + 4}" font-family="Arial" font-size="12">{s["label"]}</text>')
    parts.append("</svg>")
    path.write_text("\n".join(parts), encoding="utf-8")


def make_amplitude_figure():
    rows = read_csv(OUT / "iqcot_pis_iek_amplitude_sweep.csv")
    series = []
    for input_type in ["Lambda", "Ton", "Mixed"]:
        grouped = {}
        for r in rows:
            if r["input_type"] != input_type:
                continue
            x = float(r["amplitude_si"])
            if input_type == "Lambda":
                x = x / 1e-13
            elif input_type == "Ton":
                x = x * 1e9
            y = float(r["rms_wait_error_pct"])
            grouped[x] = max(grouped.get(x, 0.0), y)
        points = sorted(grouped.items())
        if points:
            x_label = "normalized amplitude: Lambda/(1e-13 V*s), Ton(ns), Mixed index"
            series.append({"label": input_type, "points": points})
    svg_line_chart(
        FIG / "fig16_pis_iek_amplitude_error.svg",
        "PIS-IEK amplitude sweep: worst rms wait error",
        series,
        x_label,
        "max rms wait error (%)",
    )


def make_frequency_figure():
    rows = read_csv(OUT / "iqcot_pis_iek_frequency_response.csv")
    wanted = ["ton_m2_alt", "mixed_m2", "lambda_common"]
    series = []
    for base in wanted:
        exact = []
        pred = []
        for r in rows:
            if not r["case"].startswith(base + "_"):
                continue
            x = float(r["omega_over_pi"])
            exact.append((x, float(r["wait_exact_amp_ns"])))
            pred.append((x, float(r["wait_pred_amp_ns"])))
        if exact:
            series.append({"label": base + " exact", "points": sorted(exact)})
            series.append({"label": base + " pred", "points": sorted(pred)})
    svg_line_chart(
        FIG / "fig17_pis_iek_lifted_frequency_response.svg",
        "PIS-IEK lifted frequency response: exact vs predicted wait amplitude",
        series,
        "omega/pi in four-event lifted domain",
        "wait modal amplitude (ns)",
    )


def main():
    make_amplitude_figure()
    make_frequency_figure()
    print(FIG / "fig16_pis_iek_amplitude_error.svg")
    print(FIG / "fig17_pis_iek_lifted_frequency_response.svg")


if __name__ == "__main__":
    main()
