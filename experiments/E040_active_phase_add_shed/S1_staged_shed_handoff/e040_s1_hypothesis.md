# E040-S1 Staged Shed-Handoff Hypothesis

Date: 2026-06-30

## Scope

E040-S1 is a design-first follow-up to the E040-S0 `MODEL_REVISED` result.
It does not contain new simulation results.

The future validation scope is fixed:

```text
External load-current drop: 40A -> 20A
Initial active phases: 4
Target active phases: 2
Target physical phases: [1,3]
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
Baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline model must remain read-only. Any future implementation must create a derived copy through MATLAB/Simulink APIs.

## E040-S0 Failure Mechanism

E040-S0 showed that the simple shed model is insufficient:

```text
S1 immediate shed:
  N_active_final = 2
  peak undershoot = 663.614 mV
  final Vout error = -624.357 mV
  current_limit_hit = true

S2 dwell/lockout shed:
  N_active_final = 2
  peak undershoot = 543.833 mV
  final Vout error = -500.714 mV
  current_limit_hit = true
  phase_order_error_rate_post_shed = 0.265152

S3 residual/relock/a_S guarded shed:
  N_active_final = 3.79065
  peak undershoot = 19.133 mV
  final Vout error = -3.371 mV
  current_limit_hit = false
  phase_order_error_rate_post_shed = 0.992308
```

Immediate or dwell-only shed reaches two-phase mode but over-stresses the remaining phases and voltage loop. Residual-qualified S3 avoids the severe voltage/current-limit failure but fails to commit to stable two-phase operation.

## Hypothesis

A safe 4 -> 2 shed transition requires staged handoff rather than another delay-only guard:

```text
NORMAL_4PH
SHED_REQUESTED
LOAD_SHARE_TRANSFER
DISABLED_PHASE_DRAIN
SHED_COMMIT_ARMED
SHED_COMMIT
ORDER_RELOCK_2PH
POST_SHED_RECOVERY
NORMAL_2PH
FALLBACK_4PH
```

The expected mechanism is:

```text
1. Transfer average current away from phases [2,4] while phases [1,3] remain under current guard.
2. Stop new high-side energy injection into phases [2,4] without directly commanding gates.
3. Wait until disabled-phase residual current is below threshold.
4. Commit active_phase_set atomically to [1,0,1,0].
5. Relock accepted events to physical sequence [1,3].
6. Enable only conservative post-shed a_S recovery after commit, relock, residual, and voltage guards pass.
```

## Primary Claim To Test Later

If later validated, E040-S1 may support only this narrow claim:

```text
A staged shed handoff is required for safe active-phase reduction in the local ideal IQCOT derived model. Shed must first transfer load share, drain disabled-phase current, atomically commit the active set, and relock two-phase order before conservative post-shed a_S recovery is allowed.
```

## Anti-Claims

E040-S1 design does not claim:

- shed success;
- S4 AI/table selected `a_N` success;
- broad 1/2/4 phase scheduling robustness;
- severe load-drop behavior;
- active Lambda control;
- efficiency improvement;
- hardware, HIL, board-level, or silicon validation.
