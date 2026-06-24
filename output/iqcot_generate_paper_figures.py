import csv
import math
from pathlib import Path


OUT = Path("E:/Desktop/codex/output")
FIG = OUT / "figures"
FIG.mkdir(exist_ok=True)


def read_csv(name):
    with (OUT / name).open(newline="") as f:
        return list(csv.DictReader(f))


def esc(s):
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


class SVG:
    def __init__(self, width=900, height=560):
        self.w = width
        self.h = height
        self.items = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
            '<rect width="100%" height="100%" fill="white"/>',
            '<style>text{font-family:Arial,"Microsoft YaHei",sans-serif;fill:#111} .axis{stroke:#111;stroke-width:1.4} .grid{stroke:#ddd;stroke-width:1} .thin{stroke:#555;stroke-width:1.2} .main{stroke:#1f4e79;stroke-width:2.4;fill:none} .alt{stroke:#a23b2a;stroke-width:2.4;fill:none} .green{stroke:#2d6a4f;stroke-width:2.4;fill:none} .dash{stroke-dasharray:6 4}</style>',
        ]

    def text(self, x, y, s, size=18, anchor="start", weight="normal"):
        self.items.append(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" font-weight="{weight}">{esc(s)}</text>')

    def line(self, x1, y1, x2, y2, cls="thin", extra=""):
        self.items.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" class="{cls}" {extra}/>')

    def rect(self, x, y, w, h, fill="#f7f7f7", stroke="#333", extra=""):
        self.items.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" fill="{fill}" stroke="{stroke}" stroke-width="1.2" {extra}/>')

    def path(self, d, cls="main", extra=""):
        self.items.append(f'<path d="{d}" class="{cls}" {extra}/>')

    def polyline(self, pts, cls="main", extra=""):
        p = " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)
        self.items.append(f'<polyline points="{p}" class="{cls}" {extra}/>')

    def circle(self, x, y, r=4, fill="#1f4e79"):
        self.items.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}"/>')

    def save(self, path):
        self.items.append("</svg>")
        path.write_text("\n".join(self.items), encoding="utf-8")


def arrow(svg, x1, y1, x2, y2, cls="thin"):
    svg.line(x1, y1, x2, y2, cls, 'marker-end="url(#arrow)"')


def defs_arrow(svg):
    svg.items.append(
        '<defs><marker id="arrow" markerWidth="10" markerHeight="8" refX="9" refY="4" orient="auto" markerUnits="strokeWidth">'
        '<path d="M0,0 L10,4 L0,8 Z" fill="#555"/></marker></defs>'
    )


def plot_frame(svg, x0, y0, w, h, title, xlabel, ylabel):
    svg.line(x0, y0 + h, x0 + w, y0 + h, "axis")
    svg.line(x0, y0, x0, y0 + h, "axis")
    svg.text(x0 + w / 2, y0 - 42, title, 20, "middle", "bold")
    svg.text(x0, y0 - 15, ylabel, 14, "start")
    svg.text(x0 + w / 2, y0 + h + 48, xlabel, 16, "middle")
    return x0, y0, w, h


def scale_linear(vals, lo=None, hi=None):
    lo = min(vals) if lo is None else lo
    hi = max(vals) if hi is None else hi
    if abs(hi - lo) < 1e-30:
        hi = lo + 1.0
    return lo, hi


def map_xy(x, y, xlim, ylim, box):
    x0, y0, w, h = box
    xp = x0 + (x - xlim[0]) / (xlim[1] - xlim[0]) * w
    yp = y0 + h - (y - ylim[0]) / (ylim[1] - ylim[0]) * h
    return xp, yp


def fig1_event_kernel():
    svg = SVG(980, 620)
    defs_arrow(svg)
    svg.text(490, 42, "Integral-event kernel view of IQCOT", 24, "middle", "bold")
    svg.rect(70, 120, 230, 90, "#eef5fb")
    svg.text(185, 152, "Power stage memory", 17, "middle", "bold")
    svg.text(185, 180, "xk, past events", 15, "middle")
    svg.rect(380, 105, 240, 120, "#fff8e8")
    svg.text(500, 142, "IQCOT area event", 17, "middle", "bold")
    svg.text(500, 172, "∫[vc(t) - Ri iL(t)]dt = Λ", 16, "middle")
    svg.text(500, 199, "moving-boundary linearization", 14, "middle")
    svg.rect(715, 120, 200, 90, "#eef7ef")
    svg.text(815, 152, "Event time", 17, "middle", "bold")
    svg.text(815, 180, "τk+1, ΔTk, duty", 15, "middle")
    arrow(svg, 300, 165, 380, 165)
    arrow(svg, 620, 165, 715, 165)
    arrow(svg, 815, 210, 185, 255)
    svg.text(485, 255, "state reset and memory feedback", 14, "middle")

    svg.rect(105, 365, 770, 115, "#f7f7f7")
    svg.text(490, 400, "[He z - Hs + K(z)] Tau(z) = UA(z)", 24, "middle", "bold")
    svg.text(490, 432, "K(z) collects power-stage and control-chain memory; K(1)=Hs-He enforces time-shift invariance.", 15, "middle")
    svg.text(490, 462, "UA contains Λ, CT, VTH, gm, Ri, delay and area-noise perturbations.", 15, "middle")
    svg.save(FIG / "fig1_iek_event_kernel.svg")


def fig2_dynamic_single_phase():
    rows = read_csv("iqcot_dynamic_iek_nonlinear_frequency_validation.csv")
    x = [float(r["omega_over_pi"]) for r in rows]
    sim = [float(r["period_amp_ns_sim"]) for r in rows]
    theory = [float(r["period_amp_ns_theory"]) for r in rows]
    err = [abs(float(r["period_amp_error_pct"])) for r in rows]
    svg = SVG(980, 560)
    box = plot_frame(svg, 92, 76, 360, 330, "Period response", "normalized frequency (ω/π)", "amplitude (ns)")
    xlim = scale_linear(x, 0.0, 0.75)
    ylim = scale_linear(sim + theory, 0.0, max(sim + theory) * 1.1)
    for gx in [0.0, 0.2, 0.4, 0.6]:
        xp, _ = map_xy(gx, 0, xlim, ylim, box)
        svg.line(xp, box[1], xp, box[1] + box[3], "grid")
        svg.text(xp, box[1] + box[3] + 24, f"{gx:.1f}", 13, "middle")
    for gy in [0, 1, 2, 3, 4, 5]:
        _, yp = map_xy(0, gy, xlim, ylim, box)
        svg.line(box[0], yp, box[0] + box[2], yp, "grid")
        svg.text(box[0] - 10, yp + 4, f"{gy}", 13, "end")
    svg.polyline([map_xy(a, b, xlim, ylim, box) for a, b in zip(x, sim)], "main")
    svg.polyline([map_xy(a, b, xlim, ylim, box) for a, b in zip(x, theory)], "alt dash")
    svg.text(190, 448, "nonlinear event simulation", 14)
    svg.line(150, 443, 180, 443, "main")
    svg.text(190, 474, "dynamic IEK", 14)
    svg.line(150, 469, 180, 469, "alt dash")

    box2 = plot_frame(svg, 585, 76, 300, 330, "Dynamic IEK error", "normalized frequency (ω/π)", "|error| (%)")
    xlim2 = scale_linear(x, 0.0, 0.75)
    ylim2 = scale_linear(err, 0.0, max(err) * 1.4)
    for gx in [0.0, 0.2, 0.4, 0.6]:
        xp, _ = map_xy(gx, 0, xlim2, ylim2, box2)
        svg.line(xp, box2[1], xp, box2[1] + box2[3], "grid")
        svg.text(xp, box2[1] + box2[3] + 24, f"{gx:.1f}", 13, "middle")
    for gy in [0.0, 0.00005, 0.00010, 0.00015, 0.00020]:
        _, yp = map_xy(0, gy, xlim2, ylim2, box2)
        svg.line(box2[0], yp, box2[0] + box2[2], yp, "grid")
        svg.text(box2[0] - 10, yp + 4, f"{gy:.5f}", 12, "end")
    svg.polyline([map_xy(a, b, xlim2, ylim2, box2) for a, b in zip(x, err)], "green")
    svg.text(490, 525, "Validation: maximum period-amplitude error is below 0.00018%.", 16, "middle")
    svg.save(FIG / "fig2_single_phase_dynamic_iek_validation.svg")


def fig3_multiphase_modal():
    svg = SVG(980, 620)
    defs_arrow(svg)
    svg.text(490, 42, "Multiphase modal decomposition and actuator channels", 23, "middle", "bold")
    for i, label in enumerate(["phase 0", "phase 1", "phase 2", "phase 3"]):
        x = 80 + i * 105
        svg.rect(x, 120, 80, 55, "#eef5fb")
        svg.text(x + 40, 154, label, 14, "middle")
    arrow(svg, 500, 148, 610, 148)
    svg.text(555, 130, "DFT", 18, "middle", "bold")
    labels = [
        ("m=0 common mode", "output, total-period jitter"),
        ("m=1,2,3 differential modes", "phase spacing, ripple cancellation"),
    ]
    for i, (a, b) in enumerate(labels):
        y = 102 + i * 96
        svg.rect(650, y, 250, 70, "#fff8e8" if i == 0 else "#eef7ef")
        svg.text(775, y + 30, a, 15, "middle", "bold")
        svg.text(775, y + 53, b, 13, "middle")
    svg.rect(120, 365, 210, 90, "#f6f6f6")
    svg.text(225, 397, "Λcm", 22, "middle", "bold")
    svg.text(225, 425, "output regulation", 15, "middle")
    svg.rect(385, 365, 210, 90, "#f6f6f6")
    svg.text(490, 397, "Λdiff", 22, "middle", "bold")
    svg.text(490, 425, "phase-spacing actuator", 15, "middle")
    svg.rect(650, 365, 210, 90, "#f6f6f6")
    svg.text(755, 397, "Ton,diff", 22, "middle", "bold")
    svg.text(755, 425, "current-sharing actuator", 15, "middle")
    svg.text(490, 525, "Key separation: threshold differential offsets mainly move event spacing; on-time differential offsets set average phase current.", 15, "middle")
    svg.save(FIG / "fig3_multiphase_modal_channels.svg")


def fig4_common_error():
    rows = read_csv("iqcot_multiphase_iek_common_response.csv")
    x = [float(r["omega_over_pi"]) for r in rows]
    sim = [float(r["sim_wait_amp_ns"]) for r in rows]
    static = [float(r["static_he_amp_ns"]) for r in rows]
    err = [abs(float(r["static_he_amp_error_pct"])) for r in rows]
    svg = SVG(980, 560)
    box = plot_frame(svg, 90, 76, 360, 330, "Common-mode wait response", "normalized frequency (ω/π)", "amplitude (ns)")
    xlim = scale_linear(x, 0.0, 0.72)
    ylim = scale_linear(sim + static, 0.0, max(sim + static) * 1.2)
    for gx in [0.0, 0.2, 0.4, 0.6]:
        xp, _ = map_xy(gx, 0, xlim, ylim, box)
        svg.line(xp, box[1], xp, box[1] + box[3], "grid")
        svg.text(xp, box[1] + box[3] + 24, f"{gx:.1f}", 13, "middle")
    for gy in [0.0, 0.1, 0.2, 0.3]:
        _, yp = map_xy(0, gy, xlim, ylim, box)
        svg.line(box[0], yp, box[0] + box[2], yp, "grid")
        svg.text(box[0] - 10, yp + 4, f"{gy:.1f}", 13, "end")
    svg.polyline([map_xy(a, b, xlim, ylim, box) for a, b in zip(x, sim)], "main")
    svg.polyline([map_xy(a, b, xlim, ylim, box) for a, b in zip(x, static)], "alt dash")

    box2 = plot_frame(svg, 585, 76, 300, 330, "He-only amplitude error", "normalized frequency (ω/π)", "|error| (%)")
    xlim2 = xlim
    ylim2 = (0.0, max(err) * 1.1)
    for gx in [0.0, 0.2, 0.4, 0.6]:
        xp, _ = map_xy(gx, 0, xlim2, ylim2, box2)
        svg.line(xp, box2[1], xp, box2[1] + box2[3], "grid")
        svg.text(xp, box2[1] + box2[3] + 24, f"{gx:.1f}", 13, "middle")
    for gy in [0, 1000, 2000, 3000]:
        _, yp = map_xy(0, gy, xlim2, ylim2, box2)
        svg.line(box2[0], yp, box2[0] + box2[2], yp, "grid")
        svg.text(box2[0] - 10, yp + 4, str(gy), 13, "end")
    svg.polyline([map_xy(a, b, xlim2, ylim2, box2) for a, b in zip(x, err)], "green")
    svg.text(490, 525, "The static He approximation misses the frequency-selective event memory of the four-phase system.", 16, "middle")
    svg.save(FIG / "fig4_common_mode_he_only_error.svg")


def fig5_actuator_mismatch():
    rows = read_csv("iqcot_multiphase_mismatch_dynamic_validation.csv")
    keep_case = "strong_monotonic_DCR_pm20pct"
    labels = ["no_trim", "lambda_diff_only_8e-13_scaled_to_DCR", "limited_ton_trim_0p10ns", "limited_ton_trim_0p20ns", "analytic_full_ton_trim"]
    short = ["no trim", "Λdiff", "Ton ±0.1 ns", "Ton ±0.2 ns", "full Ton"]
    data = {r["actuator"]: r for r in rows if r["case"] == keep_case}
    vals_i = [float(data[x]["current_pkpk_A"]) for x in labels]
    vals_w = [float(data[x]["mean_wait_phase_pkpk_ns"]) for x in labels]
    svg = SVG(980, 560)
    svg.text(490, 42, "DCR mismatch: current balance benefit versus phase-spacing cost", 22, "middle", "bold")
    x0, y0, w, h = 95, 100, 760, 310
    max_i = max(vals_i) * 1.15
    max_w = max(vals_w) * 1.15
    svg.line(x0, y0 + h, x0 + w, y0 + h, "axis")
    svg.line(x0, y0, x0, y0 + h, "axis")
    svg.line(x0 + w, y0, x0 + w, y0 + h, "axis")
    svg.text(x0 - 18, y0 + h / 2, "current pk-pk (A)", 15, "middle")
    svg.text(x0 + w + 58, y0 + h / 2, "phase wait pk-pk (ns)", 15, "middle")
    bar_w = 56
    gap = 90
    for idx, lab in enumerate(short):
        cx = x0 + 78 + idx * (bar_w + gap)
        hi = vals_i[idx] / max_i * h
        hw = vals_w[idx] / max_w * h
        svg.rect(cx - bar_w / 2, y0 + h - hi, bar_w, hi, "#4f81bd", "#4f81bd")
        svg.rect(cx + bar_w / 2 + 6, y0 + h - hw, bar_w, hw, "#c0504d", "#c0504d")
        svg.text(cx + bar_w / 2, y0 + h + 32, lab, 12, "middle")
        svg.text(cx - 4, y0 + h - hi - 8, f"{vals_i[idx]:.2f}", 12, "middle")
        svg.text(cx + bar_w + 30, y0 + h - hw - 8, f"{vals_w[idx]:.0f}", 12, "middle")
    for gy in [0, 1, 2, 3, 4]:
        yp = y0 + h - gy / max_i * h
        svg.line(x0, yp, x0 + w, yp, "grid")
        svg.text(x0 - 10, yp + 4, str(gy), 13, "end")
    for gy in [0, 125, 250, 375, 500]:
        yp = y0 + h - gy / max_w * h
        svg.text(x0 + w + 10, yp + 4, str(gy), 13)
    svg.rect(250, 455, 24, 14, "#4f81bd", "#4f81bd")
    svg.text(282, 468, "current imbalance", 14)
    svg.rect(430, 455, 24, 14, "#c0504d", "#c0504d")
    svg.text(462, 468, "mean phase-wait cost", 14)
    svg.text(490, 520, "Λdiff alone leaves current imbalance unchanged; Ton trim balances current but consumes phase-spacing margin.", 15, "middle")
    svg.save(FIG / "fig5_mismatch_actuator_tradeoff.svg")


def fig6_limited_trim_curve():
    rows = read_csv("iqcot_multiphase_current_balance_limited_trim.csv")
    rows = [r for r in rows if r["case"] == "strong_monotonic_pm20pct"]
    x = [float(r["event_wait_pkpk_ns_cost"]) for r in rows]
    y = [float(r["current_pkpk_reduction_pct"]) for r in rows]
    labels = [float(r["trim_limit_ns"]) for r in rows]
    svg = SVG(900, 540)
    box = plot_frame(svg, 95, 76, 650, 330, "Limited Ton-trim design curve", "phase-spacing cost, wait pk-pk (ns)", "current pk-pk reduction (%)")
    xlim = scale_linear(x, 0.0, max(x) * 1.08)
    ylim = scale_linear(y, 0.0, 105.0)
    for gx in [0, 250, 500, 750, 1000]:
        xp, _ = map_xy(gx, 0, xlim, ylim, box)
        svg.line(xp, box[1], xp, box[1] + box[3], "grid")
        svg.text(xp, box[1] + box[3] + 24, str(gx), 13, "middle")
    for gy in [0, 25, 50, 75, 100]:
        _, yp = map_xy(0, gy, xlim, ylim, box)
        svg.line(box[0], yp, box[0] + box[2], yp, "grid")
        svg.text(box[0] - 10, yp + 4, str(gy), 13, "end")
    pts = [map_xy(a, b, xlim, ylim, box) for a, b in zip(x, y)]
    svg.polyline(pts, "main")
    for (px, py), lab in zip(pts, labels):
        svg.circle(px, py, 5)
        svg.text(px + 8, py - 8, f"{lab:.2f} ns", 13)
    svg.text(450, 500, "This curve turns current-balance tuning into a constrained design problem instead of a single-objective trim.", 15, "middle")
    svg.save(FIG / "fig6_limited_ton_trim_design_curve.svg")


def main():
    fig1_event_kernel()
    fig2_dynamic_single_phase()
    fig3_multiphase_modal()
    fig4_common_error()
    fig5_actuator_mismatch()
    fig6_limited_trim_curve()
    print(f"Generated SVG figures under {FIG}")


if __name__ == "__main__":
    main()
