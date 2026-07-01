# Claim Boundary Table

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

| Topic | Evidence | Classification | Allowed Claim | Forbidden Claim | Manuscript Section |
|---|---|---|---|---|---|
| IQCOT inner loop | `docs/theory/01_iqcot_inner_loop.md`; `docs/theory/06_claim_boundaries.md` | Framing boundary | IQCOT remains the deterministic fast variable-frequency inner loop | IQCOT cannot regulate load transients; AI replaces IQCOT | Abstract, Introduction, Baseline |
| `a_U` | `experiments/E020_load_rise_undershoot/e020_metrics.csv`; `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv` | MODEL_CONFIRMED local | `a_U` is locally confirmed for early load-rise peak-undershoot reduction and current-rise acceleration | `a_U` solves complete `120A` recovery; `a_U` proves `1 mV` settling | Load-transient actions; Validation |
| `a_O` | `results/current/e010_research_table.csv`; `experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_revision_synthesis.md` | MODEL_REVISED / boundary | `a_O` has local support for medium load-drop projected protection; A5 severe `40A -> 1A` is boundary evidence | A5 solves severe load drop | Load-transient actions; Limitations |
| `a_S` | `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv` | MODEL_CONFIRMED local | `a_S` is locally confirmed for one calibration-aware current-sense mismatch guard pattern | `a_S` proves broad mismatch robustness; active Lambda is validated | Sensing-aware current sharing |
| `a_N` | `experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv`; `experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv` | MODEL_CONFIRMED local | `a_N` is locally confirmed for one add-phase and one shed-phase event-integrity point | `a_N` proves arbitrary `1/2/4` active-phase scheduling; `a_N` proves efficiency improvement | Active-phase event integrity |
| Validation level | All listed metrics and summaries | Local derived Simulink | Local derived Simulink evidence | hardware validation; HIL validation; board-level validation; silicon validation | Validation and Limitations |
| AI/table supervisor | `docs/theory/04_ai_action_space_and_projection.md` | Design boundary | Supervisor proposes bounded action tokens that pass model-based safety projection | AI directly controls MOSFET gates; AI controls external load-current slew | Architecture and Method |
