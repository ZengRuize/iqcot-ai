import csv
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")
FIG = OUT / "figures"


def read_rows():
    with (OUT / "iqcot_pis_iek_monte_carlo_summary.csv").open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def scale(x, xmin, xmax, a, b):
    if xmax == xmin:
        return 0.5 * (a + b)
    return a + (x - xmin) * (b - a) / (xmax - xmin)


def polyline(points, color):
    pts = " ".join(f"{x:.2f},{y:.2f}" for x, y in points)
    return f'<polyline points="{pts}" fill="none" stroke="{color}" stroke-width="2"/>'


def circle(x, y, color):
    return f'<circle cx="{x:.2f}" cy="{y:.2f}" r="3.5" fill="{color}"/>'


def text(x, y, body, size=12, anchor="start"):
    return f'<text x="{x:.2f}" y="{y:.2f}" font-family="Arial" font-size="{size}" text-anchor="{anchor}">{body}</text>'


def axes(x0, y0, w, h, title, xlabel, ylabel):
    parts = [
        f'<rect x="{x0}" y="{y0}" width="{w}" height="{h}" fill="white" stroke="#333" stroke-width="1"/>',
        text(x0 + w / 2, y0 - 12, title, 14, "middle"),
        text(x0 + w / 2, y0 + h + 36, xlabel, 12, "middle"),
        f'<text x="{x0 - 45}" y="{y0 + h / 2}" font-family="Arial" font-size="12" text-anchor="middle" transform="rotate(-90 {x0 - 45},{y0 + h / 2})">{ylabel}</text>',
    ]
    return parts


def make_plot():
    rows = read_rows()
    FIG.mkdir(exist_ok=True)
    path = FIG / "fig19_pis_iek_monte_carlo_budget.svg"
    colors = ["#1f77b4", "#ff7f0e", "#2ca02c", "#d62728"]
    svg = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1150" height="470" viewBox="0 0 1150 470">',
        '<rect width="1150" height="470" fill="#ffffff"/>',
    ]

    # Left: area bits vs phase-spacing p95 for selected clocks.
    x0, y0, w, h = 85, 65, 440, 300
    svg.extend(axes(x0, y0, w, h, "Area-bit and clock budget", "area threshold bits", "spacing std p95 (ns)"))
    left = [
        r for r in rows
        if int(r["ton_resolution_ps"]) == 10
        and abs(float(r["comp_delay_sigma_ns"]) - 0.5) < 1e-12
    ]
    yvals = [float(r["phase_spacing_std_ns_p95"]) for r in left]
    ymin, ymax = 0.0, max(yvals) * 1.08
    bits = [10, 12, 14, 16]
    for i, clk in enumerate([0.5, 1.0, 2.0, 5.0]):
        seq = sorted([r for r in left if abs(float(r["detect_clock_ns"]) - clk) < 1e-12], key=lambda r: int(r["area_bits"]))
        pts = []
        for r in seq:
            x = scale(int(r["area_bits"]), min(bits), max(bits), x0 + 35, x0 + w - 25)
            y = scale(float(r["phase_spacing_std_ns_p95"]), ymin, ymax, y0 + h - 25, y0 + 20)
            pts.append((x, y))
        svg.append(polyline(pts, colors[i]))
        for x, y in pts:
            svg.append(circle(x, y, colors[i]))
        svg.append(text(x0 + w - 5, y0 + 30 + i * 18, f"{clk:g} ns clock", 11, "end"))
    for b in bits:
        x = scale(b, min(bits), max(bits), x0 + 35, x0 + w - 25)
        svg.append(f'<line x1="{x:.2f}" y1="{y0+h-25}" x2="{x:.2f}" y2="{y0+h-20}" stroke="#333"/>')
        svg.append(text(x, y0 + h - 5, str(b), 11, "middle"))
    for tick in [0, ymax / 2, ymax]:
        y = scale(tick, ymin, ymax, y0 + h - 25, y0 + 20)
        svg.append(f'<line x1="{x0+30}" y1="{y:.2f}" x2="{x0+35}" y2="{y:.2f}" stroke="#333"/>')
        svg.append(text(x0 + 25, y + 4, f"{tick:.2f}", 10, "end"))

    # Right: Ton resolution vs instantaneous current ripple p95 for delay sigma.
    x0, y0, w, h = 650, 65, 430, 300
    svg.extend(axes(x0, y0, w, h, "Ton and delay budget", "Ton resolution (ps)", "current rms p95 (mA)"))
    right = [
        r for r in rows
        if int(r["area_bits"]) == 12
        and abs(float(r["detect_clock_ns"]) - 1.0) < 1e-12
    ]
    yvals = [float(r["current_snapshot_rms_mA_p95"]) for r in right]
    ymin, ymax = min(yvals) * 0.9995, max(yvals) * 1.0005
    tons = [5, 10, 20, 50]
    for i, delay in enumerate([0.0, 0.5, 1.0, 2.0]):
        seq = sorted([r for r in right if abs(float(r["comp_delay_sigma_ns"]) - delay) < 1e-12], key=lambda r: int(r["ton_resolution_ps"]))
        pts = []
        for r in seq:
            x = scale(int(r["ton_resolution_ps"]), min(tons), max(tons), x0 + 40, x0 + w - 25)
            y = scale(float(r["current_snapshot_rms_mA_p95"]), ymin, ymax, y0 + h - 25, y0 + 20)
            pts.append((x, y))
        svg.append(polyline(pts, colors[i]))
        for x, y in pts:
            svg.append(circle(x, y, colors[i]))
        svg.append(text(x0 + w - 5, y0 + 30 + i * 18, f"{delay:g} ns delay sigma", 11, "end"))
    for t in tons:
        x = scale(t, min(tons), max(tons), x0 + 40, x0 + w - 25)
        svg.append(f'<line x1="{x:.2f}" y1="{y0+h-25}" x2="{x:.2f}" y2="{y0+h-20}" stroke="#333"/>')
        svg.append(text(x, y0 + h - 5, str(t), 11, "middle"))
    for tick in [ymin, 0.5 * (ymin + ymax), ymax]:
        y = scale(tick, ymin, ymax, y0 + h - 25, y0 + 20)
        svg.append(f'<line x1="{x0+35}" y1="{y:.2f}" x2="{x0+40}" y2="{y:.2f}" stroke="#333"/>')
        svg.append(text(x0 + 30, y + 4, f"{tick:.1f}", 10, "end"))

    svg.append(text(575, 435, "Fig. 19. PIS-IEK Monte Carlo digital implementation budget.", 13, "middle"))
    svg.append("</svg>")
    path.write_text("\n".join(svg), encoding="utf-8")
    print(f"FIG19={path}")


if __name__ == "__main__":
    make_plot()
