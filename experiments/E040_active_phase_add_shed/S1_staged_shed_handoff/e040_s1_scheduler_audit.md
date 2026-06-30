# E040-S1 Scheduler Audit Design

Date: 2026-06-30

This document defines the scheduler audit table used by the executed E040-S1 run and records the local S1-R3 audit result.

## Executed Audit Result

```text
classification: MODEL_CONFIRMED
scheduler audit CSVs:
  e040_s1_r0_fixed4_scheduler_audit.csv
  e040_s1_r2_transfer_drain_scheduler_audit.csv
  e040_s1_r3_commit_relock_scheduler_audit.csv
signal availability CSVs:
  e040_s1_r0_fixed4_signal_availability.csv
  e040_s1_r2_transfer_drain_signal_availability.csv
  e040_s1_r3_commit_relock_signal_availability.csv
```

S1-R3 passed the local audit gate:

```text
N_active_final = 2
actual_active_phase_set_final = 1010
shed_commit_count = 1
fallback_4ph_count = 0
dropped_REQ_count = 0
inactive_phase_REQ_count = 0
phase_order_error_rate_post_shed = 0
current_limit_hit = false
residual_current_check = pass
```

## Required Audit Columns

```text
event_index
time_us
shed_state
active_phase_set
N_active
logical_slot
physical_phase_selected
REQ_in_phase
REQ_accept_phase
REQ_reject_reason
phase_idx_before
phase_idx_after
commit_armed
commit_done
fallback_4ph_triggered
fallback_reason
```

## Audit Table Semantics

| Column | Meaning |
|---|---|
| `event_index` | Monotonic accepted scheduler event index; dropped and inactive request checks are audited through raw-vs-accepted counts |
| `time_us` | Time relative to external load step |
| `shed_state` | Discrete E040-S1 state machine state |
| `active_phase_set` | Four-bit mask, for example `1111` or `1010` |
| `N_active` | Integer active phase count; post-commit must be exactly `2` |
| `logical_slot` | Logical scheduler slot before physical remap |
| `physical_phase_selected` | Physical phase selected after remap/projection |
| `REQ_in_phase` | Phase associated with raw request |
| `REQ_accept_phase` | Phase associated with accepted request |
| `REQ_reject_reason` | Encoded reason for rejected request |
| `phase_idx_before` | Scheduler phase index before the event |
| `phase_idx_after` | Scheduler phase index after the event |
| `commit_armed` | Boolean indicating the commit boundary is armed |
| `commit_done` | Boolean indicating atomic shed commit has occurred |
| `fallback_4ph_triggered` | Boolean indicating fallback to four-phase mode |
| `fallback_reason` | Encoded hard-guard or timeout reason |

## Required Proofs

Before commit:

```text
events may be four-phase or transfer-limited
active_phase_set must remain [1,1,1,1]
candidate phases [2,4] may be energy-limited but not falsely reported as committed off
```

During commit:

```text
active_phase_set changes atomically from [1,1,1,1] to [1,0,1,0]
N_active changes atomically from 4 to 2
commit_done rises once
```

After commit:

```text
accepted events target only physical phases [1,3]
no accepted event targets phases [2,4]
phase_order_error_rate_post_shed == 0
inactive_phase_REQ_count == 0
dropped_REQ_count == 0
```

## Reject Reason Encoding

Future implementation should reserve stable integer encodings:

```text
0 = none
1 = inactive_phase_blocked
2 = transfer_guard_active
3 = residual_guard_fail
4 = voltage_guard_fail
5 = current_limit_guard_fail
6 = order_relock_guard_fail
7 = fallback_active
8 = aS_guard_not_ready
```

## Fallback Reason Encoding

```text
0 = none
1 = Vout_undershoot_budget_exceeded
2 = current_limit_hit
3 = phase_order_error_rate_window_gt_zero
4 = inactive_phase_REQ_count_window_gt_zero
5 = residual_current_timeout
6 = commit_instability
7 = drain_timeout
8 = implementation_signal_missing
```

## Audit Acceptance Gate

The scheduler audit is accepted only if it can reconstruct:

```text
request time
transfer start time
drain start time
commit armed time
commit time
order relock completion time
a_S enable time, if any
fallback time and reason, if any
```

If any of these cannot be reconstructed from logs, the future result must be classified as `IMPLEMENTATION_ISSUE`.

## S1-R3 Interpretation

The S1-R3 audit shows that after commit, accepted requests target only the retained physical phases `[1,3]`. No accepted event targets inactive phases `[2,4]`, raw-vs-accepted counts show no silently dropped request, and `commit_done` rises once. The separate signal-availability audit confirms `phase_gate_enable1..4`, residual-current signals, commit/fallback flags, and active-phase-set logs are present.

The during-transfer order error metric is not a post-shed failure: transfer/drain intentionally remaps events before active-set commit while the model still reports `active_phase_set = 1111`. The claim gate uses the post-shed relock metric, which is zero for S1-R3.
