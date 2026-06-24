# Local Audit: R045 v8 Figure, Table, and Audit Plan

## Scope

This heartbeat did not run new simulations, did not repeat R042/R043
post-processing, and did not modify any original .slx model. It continued the
paper-preparation workflow after the v8 PR-ECB integrated manuscript draft.

## Files Added

- output/iqcot_v8_pr_ecb_figure_table_audit_plan.md

## Result

The plan identifies the required v8 submission figures and tables:

- A two-layer supervisory architecture figure separating PIS-IEK/r_hat/B_epsilon
  event recovery from PR-ECB first-peak risk screening.
- A phase-state boundary figure from R042 CSV rows.
- A segmented conservative-ratio-band figure from R043 rules.
- A dominant-bound-family figure from R043 row-level evidence.
- Existing PIS-IEK validation panels from v7.

It also lists blocking audits before submission-ready status: number/claim
audit, citation audit, structure audit, figure audit, and formatting/compile
audit.

## Next Safe Step

Next heartbeat should generate one of the planned figures from existing data or
perform a number/claim audit. It should not run new Simulink simulations unless
a paper audit explicitly identifies a missing evidence gap.
