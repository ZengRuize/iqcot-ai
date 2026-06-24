# Experiment Tracker Supplement: R019 AI Supervisory Scheduler Validation Design

| Run ID | Milestone | Purpose | System / Variant | Split | Metrics | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| R019 | M7 | Define delay-aware AI supervisory scheduler validation | Existing `four_phase_iek_dynamic_load_refslew.slx` derived model + event-domain delay surrogate | Training labels: 3 load targets × 3 objective weights × 5 FPGA delays; proposed validation V1-V5 | undershoot, final error, settling, skip, phase std, current imbalance, objective score | SHOULD | DESIGN_DONE | Generated `iqcot_ai_supervisor_training_targets.csv` and validation design. This is not yet AI-in-loop simulation; it defines the next controlled Simulink validation path. |

