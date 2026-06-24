# LOCAL AUDIT R024 REF SLEW FINE SWEEP 2026-06-20

## Scope

R024 local validation of continuous `T_slew` candidates for the four-phase
digital IQCOT / PIS-IEK research line.

## Inputs

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_sweep.m`
- `E:/Desktop/codex/output/iqcot_ref_slew_continuous_landscape_summary.csv`
- `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

## New Artifacts

- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_sweep.m`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_fine_summary.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_postprocess.py`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_plan.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_plan_matlab.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_summary_scores.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_best_by_objective.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_candidate_comparison.csv`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_report.md`
- `E:/Desktop/codex/output/iqcot_ref_slew_fine_sweep_paper_section.md`
- `E:/Desktop/codex/output/figures/fig31_ref_slew_fine_sweep.svg`
- `E:/Desktop/codex/research-wiki/experiments/ref-slew-fine-sweep.md`

## Simulation Result

- Ran `iqcot_dynamic_ref_slew_fine_sweep()` in MATLAB.
- Fine grid: `32/34/35/36/38/62/64/66/68/70/84/86/88/90/92 us`.
- Target loads: `20A`, `10A`, `near0A`.
- Total cases: `45`.
- Successful cases: `45`.

## Key Findings

- R023's `34-35 us` interpolation should not be written as point-optimal.
- For `20A` settling-aware objectives, the nearest `35 us` point is worse than old `30 us` because it enters a `skip_count=1` mode.
- `20A` local `38 us` improves old `30 us` by about `0.076` score under `score+0.05/0.10T_settle`.
- The wider fine grid finds `20A` settling-aware best near `66 us`, with about `0.095` improvement over the previous best.
- `near0A`, `score+0.10T_settle`, improves from old `30 us` score `19.784` to `38 us` score `19.549`, gain about `0.235`.
- Base-score fine examples include `20A` at `86 us` and near0A at `92 us`; these remain current-grid observations only.

## Local Checks

- MATLAB Code Analyzer on `iqcot_dynamic_ref_slew_fine_sweep.m`: no issues.
- Python compile check on `iqcot_ref_slew_fine_sweep_postprocess.py`: passed.
- Artifact existence check: all listed R024 core artifacts exist.
- Row-count check: `45` fine summary rows and `45` successful rows.
- Claim-boundary grep found only boundary/forbidden-claim wording such as “不能声称”, “禁止写”, or “不等同”; no unsupported positive claim was introduced.

## Interpretation Boundary

- R024 is derived Simulink evidence, not hardware validation.
- R024 is not neural-network AI-in-loop.
- R024 does not prove any `T_slew` has a global optimum.
- The correct claim is mode-aware continuous/fine `T_slew` scheduling with safety projection, not point-optimal `34-35 us`.

