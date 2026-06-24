# LOCAL AUDIT R023: Continuous Ref-Slew Landscape

Date: 2026-06-20

## Scope

R023 extends the four-phase digital IQCOT / PIS-IEK study from discrete table and score-regressor supervision to a continuous `T_slew` landscape pre-analysis.  It uses only completed dense+long derived Simulink switching results.  No original `.slx` file was modified.  No `.slx` XML was edited.  No new Simulink simulation was run.

## Inputs

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_dense_long_combined_scores.csv`

## New Outputs

- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape.py`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_grid.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_report.md`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_paper_section.md`
- `E:/Desktop/codex/output/figures/fig30_ref_slew_continuous_landscape.svg`
- `E:/Desktop/codex/research-wiki/experiments/ref-slew-continuous-landscape.md`

## Checks

- `python -m py_compile output/iqcot_ref_slew_continuous_landscape.py` passed.
- Summary rows: `9`.
- Interpolated grid rows: `909`.
- Figure exists: `fig30_ref_slew_continuous_landscape.svg`, length `7754` bytes.
- Local boundary phrase search found strong phrases only in explicit non-claim or forbidden-writing contexts.

## Main Results

- Maximum local quadratic estimated gain: `0.239`.
- Decision split:
  - `4` target/objective combinations: discrete grid sufficient.
  - `2` combinations: fine sweep candidate.
  - `3` combinations: requires new switching validation.
- Highest-priority fine validation candidates:
  - `20A`, `score+0.05T_settle`: local candidate `34.744 us`.
  - `20A`, `score+0.10T_settle`: local candidate `34.744 us`.
  - `near0A`, `score+0.10T_settle`: local candidate `34.633 us`.
- Secondary candidates:
  - `20A`, base: local candidate `87.244 us`, estimated gain `0.154`.
  - `near0A`, base: local candidate `65.710 us`, estimated gain `0.077`.

## Interpretation

R023 supports a cautious continuous-action claim:

> Continuous `T_slew` is useful as a smooth supervisory action and for safe-band clipping inside near-optimal regions.

It does not support:

- continuous `T_slew` as a proven global optimum;
- interpolation as a substitute for switching simulation;
- continuous AI as already outperforming the discrete table;
- hardware or HIL claims.

## Updated Documents

- `E:/Desktop/codex/RESEARCH_BRIEF.md`
- `E:/Desktop/codex/research-wiki/query_pack.md`
- `E:/Desktop/codex/research-wiki/index.md`
- `E:/Desktop/codex/research-wiki/log.md`
- `E:/Desktop/codex/research-wiki/graph/edges.jsonl`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`

## Next Work

The next stronger step is a small derived-Simulink fine sweep around the R023 candidates, using only `output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`:

- `20A`, `alpha=0.05/0.10`: `32/34/35/36/38 us`.
- `near0A`, `alpha=0.10`: `32/34/35/36/38 us`.
- Optional secondary: `20A` base around `84/86/88/90/92 us`, and near0A base around `62/64/66/68/70 us`.

If those fine points do not show stable switching-level improvement, continuous `T_slew` should be framed as smooth/safety projection rather than a primary performance gain.
