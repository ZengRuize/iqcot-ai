# IQCOT / PIS-IEK / PR-ECB Research Workspace

This repository contains the research artifacts for the four-phase digital
IQCOT Buck / VRM project, including event-domain IEK/PIS-IEK modeling,
derived-Simulink validation, delayed supervisory scheduling studies, and the
PR-ECB large-signal first-peak risk-boundary calibration branch.

## Current Manuscript State

- Latest integrated manuscript draft:
  `output/iqcot_multiphase_iek_paper_latest.md`
- v8 PR-ECB integrated draft:
  `output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md`
- v8 figure/table/audit plan:
  `output/iqcot_v8_pr_ecb_figure_table_audit_plan.md`

## Research Logs

- Research wiki: `research-wiki/`
- Local audit/refinement logs: `refine-logs/`
- Claim/evidence matrix: `output/iqcot_claims_evidence_matrix.md`

## Important Claim Boundaries

- AI is only a supervisory parameter-scheduling layer; it does not replace the
  IQCOT inner loop.
- PR-ECB is a derived-Simulink/offline first-peak risk feature and safety
  boundary, not hardware or HIL validation.
- `T_slew` is objective-sensitive; do not claim global optimality.
- PIS-IEK should not be claimed to precisely predict large-signal first peaks.
- `E_HS,rem` is an active-HS segmentation feature, not a globally validated
  additive correction law.

## Repository Hygiene

The repository intentionally excludes local tool checkouts, vendored Python
dependencies, temporary literature downloads, cache directories, and installed
skill links. The reproducible research artifacts, scripts, CSV outputs, figures,
reports, wiki pages, and manuscript drafts are kept under version control.

