# Current Effectiveness Review

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

## `a_U`: Load-Rise Undershoot Recovery

Purpose: reduce early Vout undershoot during external load-current rise while avoiding current-limit, REQ, and phase-order guard failures.

Physical mechanism: fast request increases early accepted event density; Ton boost increases bounded per-event high-side energy.

What IQCOT already does: deterministic IQCOT naturally responds to load rise through variable-frequency pulse/event generation.

What the supervisor adds: bounded early fast-request and Ton-boost actions selected only after safety projection.

Best evidence:

- `experiments/E020_load_rise_undershoot/e020_metrics.csv`
- `experiments/E020_load_rise_undershoot/e020_research_summary.md`
- `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv`
- `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_research_summary.md`

Current numerical result:

```text
B0:
  peak undershoot = 397.42 mV
  90% current-rise time = 37.996 us

B3:
  peak undershoot = 319.08 mV
  90% current-rise time = 1.212 us
  phase-current peak = 34.09 A/phase
  current guard not hit

R1-U1:
  peak undershoot = 318.801 mV
  90% current-rise time = 1.196 us
  final Vout error = -297.766 mV
  current_limit_hit = false
  dropped_REQ_count = 0
  phase_order_error_rate = 0
```

What is solved: `a_U` is locally confirmed for early load-rise dynamic regulation, namely peak-undershoot reduction and current-rise acceleration.

What is not solved: full `120A` recovery, `1 mV` settling, active-phase add during the severe rise, active Lambda, and broad load-rise robustness.

Claim maturity: local mechanism confirmation.

Reviewer risk: a reader may overread the early improvement as full regulation recovery. The manuscript must explicitly state that no R1 variant settled within `1 mV` by `90 us`.

## `a_O`: Load-Drop Overshoot Protection

Purpose: reduce excess high-side energy injection and manage reentry after external load-current drop.

Physical mechanism: Ton truncation reduces residual high-side energy; pulse inhibit changes the first accepted reentry event; reentry projection limits undershoot and burst risk.

What IQCOT already does: IQCOT naturally changes pulse timing and skip behavior as Vout responds.

What the supervisor adds: a bounded load-drop action token that selects truncation/inhibit/reentry policies only when safety projection permits.

Best evidence:

- `experiments/E010_load_drop_overshoot/e010_research_summary.md`
- `results/current/e010_research_table.csv`
- `experiments/E010_load_drop_overshoot/A5_severe_drop_token/e010_a5_revision_synthesis.md`
- `experiments/E010_load_drop_overshoot/A6_structural_energy_management/e010_a6_concept_note.md`

Current numerical result:

```text
medium load-drop:
  local projected protection support exists.

A5 severe 40A -> 1A:
  A5-C0/A5-C4 baseline confirmed.
  A5-T4proxy / R1 / R2 / R3 all MODEL_REVISED.
  A5 frozen as boundary evidence.
```

What is solved: medium load-drop has local support for projected protection.

What is not solved: severe `40A -> 1A` remains unresolved under projected IQCOT scheduling.

Claim maturity: partial local support plus negative boundary evidence.

Reviewer risk: severe-drop revisions can look like incremental tuning failure. The correct interpretation is a claim boundary: A6 needs a structural energy-management hypothesis rather than A5-R4 tuning.

## `a_S`: Small-Signal Current-Sharing / Phase-Recovery

Purpose: use event-domain Ton-difference mainly for DC current sharing and guarded Lambda-side information mainly for phase-spacing/ripple recovery.

Physical mechanism: Ton_diff changes average phase-current injection; calibration/confidence projection prevents biased current-sense signals from driving harmful trims.

What IQCOT already does: IQCOT supplies the pulse/event base; current-sharing trims are parameter-level supervisory modifications.

What the supervisor adds: low-dimensional `a_S` mode selection under current-sense confidence, calibration, voltage, ripple, REQ, and phase-order guards.

Best evidence:

- `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv`
- `experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md`

Current numerical result:

```text
E030-R3:
  R3-C4a_cal real max current imbalance = 0.020618 A
  R3-C4c_cal real max current imbalance = 0.025784 A
  REQ dropped = 0
  phase order error = 0
  classification = MODEL_CONFIRMED
```

What is solved: `a_S` is locally confirmed for one calibration-aware current-sense mismatch guard pattern.

What is not solved: broad mismatch robustness, imperfect calibration, active Lambda, neural AI control, active-phase coupling, and hardware validation.

Claim maturity: local guard confirmation.

Reviewer risk: `g_hat_i = g_i` is ideal calibration. Manuscript wording must not imply practical online calibration is validated.

## `a_N`: Active-Phase Add/Shed

Purpose: manage active-phase add/shed events without destabilizing voltage protection, reentry, current sharing, REQ integrity, or phase order.

Physical mechanism: add requires remap, insertion, ramp, and relock; shed requires staged load-share transfer, disabled-phase drain, deterministic gate-enable mask, atomic commit, and two-phase relock.

What IQCOT already does: IQCOT remains the event generator for the active phases.

What the supervisor adds: a guarded hybrid event manager that changes the active-phase set only after projection and state-machine conditions pass.

Best evidence:

- `experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_metrics.csv`
- `experiments/E040_active_phase_add_shed/R1_phase_insertion_retune/e040_a_r1_research_summary.md`
- `experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_metrics.csv`
- `experiments/E040_active_phase_add_shed/S1_staged_shed_handoff/e040_s1_research_summary.md`

Current numerical result:

```text
E040-A-R1, 2 -> 4 add:
  N_active_final = 4
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_add = 0
  current_limit_hit = false

E040-S1, 4 -> [1,3] shed:
  N_active_final = 2
  actual_active_phase_set_final = 1010
  shed_commit_count = 1
  fallback_4ph_count = 0
  dropped_REQ_count = 0
  inactive_phase_REQ_count = 0
  phase_order_error_rate_post_shed = 0
  current_limit_hit = false
  residual_current_check = pass
  peak undershoot = 0.641487 mV
  final Vout error = 1.65264 mV
```

What is solved: `a_N` is locally confirmed for add/shed event integrity.

What is not solved: broad `1/2/4` active-phase scheduling, efficiency improvement, severe active-phase load-rise/drop performance, mismatch interaction, and hardware/HIL validation.

Claim maturity: local event-integrity confirmation.

Reviewer risk: event integrity is not the same as efficiency or broad active-phase optimality.
