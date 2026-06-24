# Local Audit R032 Delay-Aware Band Projection

## Scope

This audit covers the R032 short-horizon risk predictor / delay-aware
`B_epsilon^sw` band projection prototype.  R032 is an offline post-processing
and documentation update step based on the completed R031 minimal held-out
derived-Simulink validation.  It does not edit or run any `.slx` model and does
not directly edit `.slx` XML.

## Files Added or Updated

- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`
- `E:/Desktop/codex/output/iqcot_r032_append_docs.py`
- `E:/Desktop/codex/output/iqcot_r032_candidate_risk_features.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_band_rules.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_replay.csv`
- `E:/Desktop/codex/output/iqcot_r032_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv`
- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_report.md`
- `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_paper_section.md`
- `E:/Desktop/codex/output/figures/fig43_r032_delay_aware_band.svg`
- `E:/Desktop/codex/research-wiki/experiments/delay-aware-band-r032.md`
- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`

## Mechanical Checks

- Python compile passed:
  - `python -m py_compile E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`
  - `python -m py_compile E:/Desktop/codex/output/iqcot_r032_append_docs.py`
- R032 post-processing executed successfully with bundled Python:
  - `E:/Desktop/codex/output/iqcot_r032_delay_aware_band_predictor.py`
- Documentation append helper executed successfully:
  - `E:/Desktop/codex/output/iqcot_r032_append_docs.py`
- CSV row counts:
  - `iqcot_r032_candidate_risk_features.csv`: `40`
  - `iqcot_r032_delay_band_rules.csv`: `3`
  - `iqcot_r032_policy_replay.csv`: `45`
  - `iqcot_r032_policy_summary.csv`: `5`
  - `iqcot_r032_next_validation_plan.csv`: `31`
- Figure exists:
  - `E:/Desktop/codex/output/figures/fig43_r032_delay_aware_band.svg`, size `3636` bytes.
- Git status was unavailable because `E:/Desktop/codex` is not a git repository in this session.

## Key Numerical Consistency

`iqcot_r032_policy_summary.csv` reports:

| Policy | Mean regret | Max regret | Non-dense selected | Mean risk |
|---|---:|---:|---:|---:|
| `r032_delay_aware_band_projection` | `0.000` | `0.000` | `3` | `0.100` |
| `r031_best_intermediate_only` | `0.143` | `0.532` | `9` | `0.422` |
| `dense_fallback` | `0.337` | `2.338` | `0` | `0.050` |
| `nearest_tau_loto_predictor` | `0.589` | `2.189` | `4` | `0.317` |
| `direct_proxy_override` | `1.107` | `2.793` | `9` | `0.761` |

Candidate band decisions:

| Decision | Count |
|---|---:|
| `plant_admissible` | `12` |
| `candidate_only` | `20` |
| `blocked` | `8` |

R032 selected plant actions in the known-context replay:

| Context | Selected action | Interpretation |
|---|---:|---|
| `10A / score_settle010 / tau=1us` | `30us` | Keep dense fallback |
| `10A / score_settle010 / tau=5us` | `33us` | Long-delay near-tie band |
| `20A / base / tau=0.5/2/5us` | `80us` | Keep dense fallback; block `86us` override |
| `20A / score_settle005 / tau=0.5us` | `50us` | Short-delay intermediate band |
| `20A / score_settle005 / tau=1us` | `38us` | Mid-delay intermediate band |
| `20A / score_settle005 / tau=2/5us` | `30us` | Dense fallback |

## Issue Found and Fixed

Initial R032 risk classification treated every `abs(T_slew - T_dense) >= 20us`
as a large-jump negative sample.  That incorrectly blocked the R031-supported
`50us` intermediate candidate for `20A / score_settle005`.  The rule was
corrected so the strong large-jump negative sample is the `66us` direct proxy
region, while `38/50/58us` remain intermediate band candidates.

After the fix, the candidate decisions changed from
`11/13/16` to `12/20/8` for plant-admissible / candidate-only / blocked.

## Claim Boundary Check

Local text search confirmed the R032 documents include boundary language:

- The `0.000` fitted replay is calibration consistency on known R031 contexts,
  not an independent generalization proof.
- R032 does not prove hardware performance or global `T_slew` optimality.
- AI remains a supervisory parameter scheduler and does not replace the IQCOT
  inner loop or output gate commands.
- `20A / score_settle005 -> 66us` remains blocked unless a future short-horizon
  predictor and derived-Simulink or hardware/HIL validation certify low risk.
- The leave-one-tau nearest-neighbor stress result (`0.589` mean regret) is
  explicitly used as negative evidence against simple delay interpolation.

## Remaining Risks

- R032 fitted projection is derived from R031 known contexts; it still needs
  new derived-Simulink validation on the 31-row transition-boundary plan.
- The risk predictor is currently rule-based and calibrated, not a learned
  online model with independent validation.
- Recent phase/skip state is specified as an interface input but is not yet
  connected to a real Simulink online predictor.
- No hardware, HIL, FPGA timing, or neural-network AI-in-loop validation has
  been performed in R032.
