# Table Plan

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

## Table 1: Contribution and Boundary Summary

Columns:

```text
Contribution | Evidence | Supported | Not Supported
```

Draft rows:

| Contribution | Evidence | Supported | Not Supported |
|---|---|---|---|
| Safety-projected supervisor around IQCOT | `docs/theory/04_ai_action_space_and_projection.md` | Token-level supervisor with model-based projection | Direct gate control or load-current slew control |
| Early load-rise enhancement | E020/E020-R1 metrics | Peak undershoot and rise90 improvement | Complete `120A` settling |
| Medium load-drop protection | E010 medium branch | Local protected `a_O` behavior | Severe `40A -> 1A` solution |
| Sensing-aware sharing guard | E030-R3 | Local calibration-aware real-current no-harm/improvement | Broad mismatch or active Lambda |
| Active-phase event integrity | E040-A-R1 and E040-S1 | One add and one shed local event-integrity point | Efficiency or arbitrary phase scheduling |

## Table 2: Action Token Summary

Columns:

```text
Token | Purpose | Supervisor Action | Guard | Evidence | Boundary
```

| Token | Purpose | Supervisor Action | Guard | Evidence | Boundary |
|---|---|---|---|---|---|
| `a_U` | Load-rise undershoot recovery | Fast request + Ton boost | Current, REQ, phase order, Ton window | E020/E020-R1 | No full `120A` recovery |
| `a_O` | Load-drop overshoot protection | Ton truncation + pulse inhibit + reentry policy | Undershoot, burst, reentry, final error | E010; E010-A5 | Severe `40A -> 1A` unresolved |
| `a_S` | Current-sharing / phase recovery | Ton_diff with confidence/calibration guard | Sense confidence, voltage, ripple, REQ/order | E030-R3 | No active Lambda validation |
| `a_N` | Active-phase add/shed | Add remap/relock; shed transfer/drain/commit | Residual current, active set, REQ/order, current limit | E040-A-R1; E040-S1 | No broad `1/2/4` scheduling |

## Table 3: E020 / E020-R1 Metrics

Source:

```text
experiments/E020_load_rise_undershoot/e020_metrics.csv
experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv
```

| Variant | Mechanism | Peak undershoot mV | Rise90 us | Final error mV | Guard pass | Claim role |
|---|---|---:|---:|---:|---|---|
| B0 | original IQCOT | 397.42 | 37.996 | -376.361 | yes | baseline |
| B3 | fast request + Ton boost | 319.08 | 1.212 | -297.928 | yes | confirmed base `a_U` |
| R1-U1 | window-tuned `a_U` | 318.801 | 1.196 | -297.766 | yes | frozen local `a_U` |

Note:

```text
No listed variant demonstrates 1mV settling within the tested 90us post-step window.
```

## Table 4: Evidence Classification Matrix

Columns:

```text
Case | Best Variant | Classification | Supported Claim | Boundary
```

| Case | Best Variant | Classification | Supported Claim | Boundary |
|---|---|---|---|---|
| E010 medium | A4 table-selected `a_O` | MODEL_REVISED / local useful branch | Medium load-drop projected protection | Not severe-drop success |
| E010-A5 | no safe candidate | MODEL_REVISED | Severe-drop boundary evidence | `40A -> 1A` unresolved |
| E020-B3 | B3 | MODEL_CONFIRMED | Early load-rise improvement | No full `120A` recovery |
| E020-R1-U1 | R1-U1 | MODEL_CONFIRMED | Narrow local `a_U` refinement | No `1 mV` settling |
| E030-R3 | C4a_cal / C4c_cal | MODEL_CONFIRMED | Calibration-aware guard pattern | Ideal calibration only |
| E040-A-R1 | R1-D1/R1-D2/R1-D3 | MODEL_CONFIRMED | Local add event integrity | No efficiency claim |
| E040-S1 | S1-R3 | MODEL_CONFIRMED | Local shed handoff integrity | No broad active-phase scheduling |
