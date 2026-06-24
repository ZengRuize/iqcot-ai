# LOCAL AUDIT R049A PR-ECB Scaffold

Date: 2026-06-24

## Scope

R049A builds a PR-ECB derived-control scaffold from
`output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`.  The new model is
`output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx`.

No full simulation matrix was run.  No original `.slx` was modified.  No raw
`.slx` XML was edited.  Model construction used MATLAB API operations in
`output/iqcot_r049_build_pr_ecb_control_model.m`.

## Actions

- Copied the R048-audited derived source model to a new PR-ECB control scaffold.
- Persisted logging names / streaming taps for:
  `vout`, `req_global`, `phase_idx`, `il1..4`, `qh1..4`, `ql1..4`,
  `ton_iqcot1..4`, `ton_done1..4`, `nqmin1..4`, and `current_limit1..4`.
- Added no-op logged protection-token placeholders:
  `protect_state`, `r_p`, `ton_truncate1..4`, `pulse_inhibit1..4`,
  `hold_int1..4`, and `reset_int1..4`.
- Verified that `output/simulink_iek/*.slx` was not modified.
- Performed a non-simulation update-diagram check with explicit variable
  injection; result:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control
```

## Diagnosis

The R049A scaffold is an implementation surface, not a protection controller.
It confirms that the derived copy can carry the necessary observability and
future protection-token interface while preserving the existing IQCOT inner
loop.  It does not yet test A0/A1/A2/A3 cut-load performance.

Standalone model loading still does not define all required workspace
variables.  This is expected from R048 and was handled by explicit variable
injection for the update-diagram check.

## Decision

```text
MODEL_CONFIRMED
```

## Next Step

R049B should replace the no-op placeholders with one minimal derived-copy
protection action first, preferably simple over-voltage skip or Ton truncation,
then run one load-drop magnitude at two phase offsets.  Do not expand to the
full A matrix until that chunk is diagnosed.

## Claim Boundary

No performance claim is upgraded.  PR-ECB remains derived-Simulink/offline
evidence until protection actions are actually implemented and compared.  AI is
not an inner-loop gate controller.  `E_HS,rem` remains a segmentation feature,
not a universal additive law.
