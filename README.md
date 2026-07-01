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

## Current Research Direction

After the 2026-06-24 direction review, the project main line is revised away
from AI/`T_slew` as the primary claim. The active research direction is:

```text
PR-ECB cut-load voltage stabilization
+ PIS-IEK steady-state current sharing
+ variable-phase add/shed hybrid event management
```

Key planning documents:

- `docs/research_direction_after_user_feedback_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`
- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md`
- `docs/adaptive_validation_automation_20260624.md`

## Codex Research Workflow

- Long-term Codex research skill lives in `.codex/skills/iqcot-research/SKILL.md`.
- Workflow protocol is in `docs/CODEX_RESEARCH_WORKFLOW.md`.
- Output protocol is in `docs/CODEX_OUTPUT_PROTOCOL.md`.
- Every future Codex round should read these files before executing research tasks.

## Research Logs

- Research wiki: `research-wiki/`
- Local audit/refinement logs: `refine-logs/`
- Claim/evidence matrix: `output/iqcot_claims_evidence_matrix.md`

## Important Claim Boundaries

- AI is only a supervisory parameter-scheduling layer; it does not replace the
  IQCOT inner loop.
- `T_slew` is not the external load-current slew rate and should not be treated
  as the main control variable.
- PR-ECB is a derived-Simulink/offline first-peak risk feature and safety
  boundary, not hardware or HIL validation.
- PIS-IEK should not be claimed to precisely predict large-signal first peaks.
- `E_HS,rem` is an active-HS segmentation feature, not a globally validated
  additive correction law.

## Repository Hygiene

The repository intentionally excludes local tool checkouts, vendored Python
dependencies, temporary literature downloads, cache directories, and installed
skill links. The reproducible research artifacts, scripts, CSV outputs, figures,
reports, wiki pages, and manuscript drafts are kept under version control.
