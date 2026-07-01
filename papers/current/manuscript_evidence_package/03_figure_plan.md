# Figure Plan

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

Do not generate plots unless the required CSV files are present and safe to parse. All paths listed here were found locally during this task.

## Figure 1: System Architecture

Title:

```text
Safety-Projected Supervisory Action Tokens Around Digital IQCOT
```

Must show:

- deterministic IQCOT inner loop;
- AI/table supervisor;
- safety projection;
- action tokens: `a_U`, `a_O`, `a_S`, `a_N`;
- guards: voltage, current, REQ, phase order, sense confidence, residual current.

Mandatory note:

```text
AI does not command gates.
AI does not control external load-current slew.
```

Source:

```text
docs/theory/04_ai_action_space_and_projection.md
papers/current/rigorous_iqcot_expert_review/00_corrected_problem_framing.md
```

## Figure 2: Corrected Problem Framing

Show:

```text
IQCOT inner loop:
  fast variable-frequency voltage regulation

supervisor:
  bounded action-token selection
```

Do not imply that IQCOT lacks basic regulation.

Source:

```text
papers/current/rigorous_iqcot_expert_review/00_corrected_problem_framing.md
docs/theory/06_claim_boundaries.md
```

## Figure 3: E020 / E020-R1 Load-Rise Result

Curves or bars:

```text
B0
B3
R1-U1
```

Annotate:

```text
B0 peak undershoot = 397.42 mV
B3 peak undershoot = 319.08 mV
R1-U1 peak undershoot = 318.801 mV

B0 rise90 = 37.996 us
B3 rise90 = 1.212 us
R1-U1 rise90 = 1.196 us

No 1mV settling within 90us.
```

Source:

```text
experiments/E020_load_rise_undershoot/e020_metrics.csv
experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv
```

## Figure 4: E010 Load-Drop Boundary

Show:

```text
medium load-drop supported branch
severe 40A -> 1A MODEL_REVISED boundary
```

Do not imply severe-drop success.

Source:

```text
results/current/e010_research_table.csv
experiments/E010_load_drop_overshoot/e010_research_summary.md
experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_revision_synthesis.md
```

## Figure 5: E030 Current-Sharing Guard

Show:

```text
sensed imbalance vs real imbalance divergence
R3 calibration-aware guard result
```

Annotate:

```text
active Lambda remains disabled / not validated.
R3-C4a_cal real max imbalance = 0.020618 A.
R3-C4c_cal real max imbalance = 0.025784 A.
```

Source:

```text
experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
```

## Figure 6: E040 Add/Shed Event Integrity

Show:

```text
2 -> 4 add remap / insertion / relock
4 -> [1,3] staged shed handoff
```

Annotate:

```text
REQ integrity
phase-order integrity
residual-current check
final active set
```

Source:

```text
experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv
experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv
```
