# Local Audit: R044 / v8 PR-ECB Integrated Paper Draft

## Scope

This audit records the manuscript-generation step after R043. It updates the
paper draft only; it does not run new Simulink simulations, modify original
.slx files, or edit .slx XML.

## Automation Update

- Updated existing heartbeat automation id iqcot.
- Changed its task from R043 segmented PR-ECB post-processing to manuscript
  drafting and audit continuation.
- Attached the automation to the current thread and set it ACTIVE on the
  existing 2-hour heartbeat schedule.

## Paper Outputs

- output/iqcot_multiphase_iek_paper_v8_pr_ecb_integrated.md
- output/iqcot_multiphase_iek_paper_latest.md

## Manuscript Changes

- Retitled the paper to include PR-ECB large-signal first-peak risk-boundary
  calibration.
- Added a v8 boundary note stating that evidence remains derived-Simulink and
  offline only.
- Added Sections 20-25:
  - PR-ECB large-signal first-peak boundary.
  - R043 segmented PR-ECB calibration surface.
  - v8 claim/evidence matrix and allowed wording.
  - v8 reviewer-style risk table.
  - v8 data/script supplement.
  - v8 conclusion supplement.

## Key Claim Boundary

The v8 paper may claim that IEK/PIS-IEK supports event-domain small-signal
actuator classification and that PR-ECB supports a segmented supervisory
first-peak risk feature. It must not claim hardware/HIL validation, global
T_slew optimality, a universal additive E_HS,rem law, exact PIS-IEK
large-signal first-peak prediction, or AI replacement of the IQCOT inner loop.

## Verification

- Confirmed the v8 sections 20-25 exist.
- Confirmed the R043 segmented rule table is present in the manuscript.
- Confirmed output/iqcot_multiphase_iek_paper_latest.md matches the v8 draft.

## Remaining Submission Work

This is a rigorous manuscript draft, not a submission-complete PDF. Before
calling it submission-ready, run a paper claim audit, citation audit, formatting
pass, and compile/export workflow.
