# E040-S1 Staged Shed-Handoff Design Summary

Date: 2026-06-30

## Status

`DESIGN_ONLY`

No E040-S1 simulation has been run in this design step. No new model-derived result, metrics movement, or `MODEL_CONFIRMED` claim is made here.

## Motivation

E040-S0 produced `MODEL_REVISED` evidence:

```text
Immediate shed and dwell-only shed can force N_active = 2,
but they produce unacceptable voltage and current-limit behavior.

Residual-qualified S3 avoids severe voltage/current-limit failure,
but fails to commit to stable two-phase operation.
```

Therefore the next shed design must manage current handoff and commit stability, not only scheduler remap.

## Proposed Mechanism

E040-S1 introduces:

```text
LOAD_SHARE_TRANSFER:
  gradually unload phases [2,4] and shift load share to [1,3]

DISABLED_PHASE_DRAIN:
  hold off new energy injection into [2,4] through projected scheduling
  wait for residual IL2/IL4 to fall below threshold

SHED_COMMIT:
  atomically switch active_phase_set from [1,1,1,1] to [1,0,1,0]

ORDER_RELOCK_2PH:
  prove accepted events target physical sequence [1,3]

POST_SHED_RECOVERY:
  allow only C1low or C4a_conf after all commit/relock/residual guards pass
```

Active Lambda remains disabled.

## Future Validation Package

This folder defines:

- hypothesis: `e040_s1_hypothesis.md`;
- protocol: `e040_s1_protocol.md`;
- state machine: `e040_s1_state_machine.md`;
- scheduler audit: `e040_s1_scheduler_audit.md`;
- metrics template: `e040_s1_metrics_template.csv`.

## Future Variants

```text
S1-R0: fixed four-phase reference
S1-R1: immediate shed failure baseline from E040-S0
S1-R2: staged transfer + drain, no final commit unless guards pass
S1-R3: staged transfer + drain + atomic commit + relock
S1-R4: optional conservative post-shed a_S, only after S1-R3 passes
```

## Future Claim Boundary

If later validated, the narrow claim may be:

```text
Shed-phase active-set reduction requires staged load-share transfer,
disabled-phase drain, atomic commit, and two-phase order relock before
post-shed recovery is enabled.
```

Still forbidden:

- E040-S shed success before simulation;
- S4 AI/table selected `a_N` shed claim;
- broad active-phase robustness;
- severe load-drop shed behavior;
- active Lambda control;
- efficiency improvement;
- hardware, HIL, board-level, or silicon validation.
