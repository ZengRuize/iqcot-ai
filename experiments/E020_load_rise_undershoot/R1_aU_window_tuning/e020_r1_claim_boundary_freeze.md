# E020-R1 a_U Claim Boundary Freeze

Date: 2026-07-01

## Scope

This freeze applies only to the local ideal IQCOT derived Simulink model and the fixed external `40A -> 120A` load-current rise case.

Evidence files:

- metrics: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv`
- summary: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_research_summary.md`
- variant config: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_variant_config.csv`
- signal availability: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_signal_availability.csv`
- scheduler audit: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_scheduler_audit.csv`

No new simulation is introduced by this document.

## Frozen Classification

```text
E020-R1 classification: MODEL_CONFIRMED
best variant: R1-U1
confirmation type: narrow local window-tuning confirmation
```

## Mechanism Interpretation

The E020 evidence supports the physical hypothesis that load-rise undershoot is dominated by early inductor-current deficit. Fast request increases early accepted event density. Ton boost increases early energy injection. Their combination in B3 gives the dominant improvement in peak undershoot and 90% current-rise time.

R1-U1 shows that a slightly shorter boost window can preserve the early benefit and marginally improve final error without current-limit, REQ, or phase-order violations. However, the final-error improvement is very small and no tested variant reaches `1 mV` settling by `90 us`. The validated contribution is dynamic load-rise peak/current-rise enhancement, not complete voltage-loop recovery.

U3 shows that an overly decayed or poorly timed boost policy can destroy the early current-rise benefit. U4 shows that the tested late-recovery guard triggers frequently but does not improve late recovery, indicating that final recovery is not solved by scalar guard insertion alone.

## Allowed Claim

```text
In the local ideal IQCOT derived Simulink model, a safety-projected a_U token
with fast request and Ton boost reduces the tested 40A -> 120A peak undershoot
and accelerates 90% current rise.

R1-U1 provides a narrow local window-tuning refinement:
  peak undershoot improves from B3 319.081 mV to 318.801 mV;
  90% current-rise time improves from B3 1.212 us to 1.196 us;
  final error improves from B3 -297.928 mV to -297.766 mV;
  current-limit, REQ, and phase-order guards pass.
```

Short manuscript version:

```text
The a_U branch is locally confirmed for early load-rise dynamic regulation,
namely peak-undershoot reduction and current-rise acceleration. The present
evidence does not demonstrate complete 120A settling.
```

## Forbidden Claims

- Complete `120A` recovery.
- `1 mV` settling.
- Broad load-rise robustness.
- Active Lambda validation.
- Active-phase add/shed during this load-rise.
- DCR/current-sense mismatch robustness.
- Hardware, HIL, board-level, or silicon validation.
- AI direct MOSFET gate command.
- AI control of external load-current slew.
- Global optimality of `R1-U1`.

## Quantitative Freeze

| Variant | Mechanism | Peak undershoot mV | 90% rise us | Final error mV | Phase-current peak A | Guard pass | Claim role |
|---|---|---:|---:|---:|---:|---|---|
| B0 | original IQCOT | 397.42 | 37.996 | -376.361 | 34.0379 | yes | baseline |
| B1 | fast request | 343.787 | 2.658 | -322.051 | 33.9041 | yes | ablation |
| B2 | Ton boost | 382.408 | 39.92 | -362.688 | 33.8865 | yes | ablation |
| B3 | fast request + Ton boost | 319.081 | 1.212 | -297.928 | 34.0934 | yes | confirmed base a_U |
| R1-U1 | window-tuned a_U | 318.801 | 1.196 | -297.766 | 33.9359 | yes | frozen local a_U |

No listed variant demonstrates `1 mV` settling within the tested `90 us` post-step window.
