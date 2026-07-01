# E020-R1 Manuscript Table

Date: 2026-07-01

Source metrics:

- `experiments/E020_load_rise_undershoot/e020_metrics.csv`
- `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv`

## Table: Local Load-Rise a_U Evidence

| Variant | Mechanism | Peak undershoot mV | 90% rise us | Final error mV | Phase-current peak A | Guard pass | Claim role |
|---|---|---:|---:|---:|---:|---|---|
| B0 | original IQCOT | 397.42 | 37.996 | -376.361 | 34.0379 | yes | baseline |
| B1 | fast request | 343.787 | 2.658 | -322.051 | 33.9041 | yes | ablation |
| B2 | Ton boost | 382.408 | 39.92 | -362.688 | 33.8865 | yes | ablation |
| B3 | fast request + Ton boost | 319.081 | 1.212 | -297.928 | 34.0934 | yes | confirmed base a_U |
| R1-U1 | window-tuned a_U | 318.801 | 1.196 | -297.766 | 33.9359 | yes | frozen local a_U |

Table note:

```text
No listed variant demonstrates 1 mV settling within the tested 90 us post-step window.
```

## Recommended Caption

```text
Local E020/E020-R1 evidence for the load-rise a_U branch under a fixed external
40A -> 120A disturbance. Fast request is the dominant early mechanism, Ton boost
adds benefit when paired with accepted-event density, and R1-U1 provides only a
narrow window-tuning refinement. The table does not support a complete 120A
settling claim.
```
