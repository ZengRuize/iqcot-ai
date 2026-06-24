# Local Audit R035 Folded-Band Projection

Date: 2026-06-21
Generated UTC: 2026-06-21T04:34:04+00:00

## Checks

- Inputs present: yes (`R031`, `R033`, `R034` CSV evidence).
- New `.slx` simulations: no.
- Original `.slx` modified: no.
- Candidate-only rows explicitly marked: `2`.
- `tau_AI=2us` reviewer correction: transition candidate `46.000` is not directly committed; deployable fallback is `30.000`.
- `66us` direct override remains blocked in the rule table.
- Boundary language present: no hardware validation, no global optimum, AI only as supervisory parameter scheduler.
- Python syntax check: `iqcot_r035_folded_band_projection.py` compiles under bundled Codex Python.
- Integrated paper, claims-evidence matrix, PIS-IEK derivation package, AI supervisor validation design, and research-wiki were updated with R035.
- Heartbeat automation `iqcot` was advanced to R036 dense-paired boundary validation / short-horizon `r_hat` predictor.

## Verdict

PASS with scientific qualification.  R035 strengthens the claim by separating
the folded transition candidate band from the dense-inclusive deployable
projection.  This reduces overclaim risk relative to treating the R034
candidate sequence as a final commit policy.
