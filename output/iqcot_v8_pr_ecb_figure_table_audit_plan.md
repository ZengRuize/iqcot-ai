# IQCOT v8 PR-ECB Figure, Table, and Audit Plan

## Scope

This plan supports the v8 manuscript:

- output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md
- output/iqcot_multiphase_iek_paper_latest.md

It does not request new Simulink runs. All proposed figures and tables are
derived from existing CSV, Markdown reports, and figure assets.

## Required Figures

| ID | Purpose | Source data | Status | Notes |
|---|---|---|---|---|
| Fig. V8-1 | Two-layer supervisory architecture: PIS-IEK/r_hat/B_epsilon for event recovery plus PR-ECB for first-peak risk | Manuscript Sections 20-25; output/iqcot_claims_evidence_matrix.md | Planned | Best as deterministic architecture SVG; should visually prevent the reader from thinking AI replaces IQCOT inner loop |
| Fig. V8-2 | PR-ECB phase-state boundary: active high-side remaining on-time versus load-step offset | output/iqcot_r042_pr_ecb_phase_dense_results_combined.csv | Planned | Show 52 ns at 0.05 us, 12 ns at 0.09 us, and 0 ns from 0.105 us onward across near0/5A/10A/20A |
| Fig. V8-3 | Segmented PR-ECB conservative ratio bands | output/iqcot_r043_pr_ecb_segmented_rules.csv | Planned | Group by high_drop_charge_esr, mid_drop_transition, low_drop_energy and active-HS state |
| Fig. V8-4 | Relationship between load-drop magnitude and dominant bound family | output/iqcot_r043_pr_ecb_segmented_rows.csv | Planned | Use charge+ESR, raw energy, corrected-energy markers; avoid implying a continuous global law |
| Fig. V8-5 | Existing PIS-IEK validation summary panel | Existing v7 figures 16-19 | Existing | Keep as small-signal/event-domain evidence, separate from PR-ECB |

## Required Tables

| ID | Purpose | Source | Status |
|---|---|---|---|
| Table V8-1 | R043 segmented PR-ECB calibration rules | output/iqcot_r043_pr_ecb_segmented_rules.csv | Already in v8 Section 21 |
| Table V8-2 | Claim-evidence and allowed wording | v8 Section 22; output/iqcot_claims_evidence_matrix.md | Already in v8 Section 22 |
| Table V8-3 | Reviewer risk and remaining work | v8 Section 23 | Already in v8 Section 23 |
| Table V8-4 | Data/script manifest | v8 Section 24 | Already in v8 Section 24 |

## Submission Audit Checklist

| Audit | Why it matters | Current status | Blocking before submission-ready? |
|---|---|---|---|
| Number/claim audit | Verify every numerical claim against CSV/Markdown evidence | Not run after v8 | Yes |
| Citation audit | Verify existence, metadata, and support context of references | Not run after v8 | Yes |
| Structure audit | Move v8 Sections 20-25 from appended update style into main narrative before references/appendices | Not done | Yes for formal submission |
| Figure audit | Ensure every planned figure has source data, caption, and claim mapping | Plan created here | Yes |
| Formatting/compile audit | Convert to LaTeX/PDF, check references, page count, overfull boxes | Not run | Yes |

## Safe Next Automation Step

Next heartbeat should not run new simulations. It should either:

1. Generate Fig. V8-1 as an architecture SVG or Mermaid diagram, or
2. Generate Fig. V8-2 and Fig. V8-3 from existing R042/R043 CSV files, or
3. Perform a number/claim audit pass over v8 against R039-R043 CSV and report files.

Do not claim the paper is submission-ready until the claim, citation, figure,
and formatting audits pass.
