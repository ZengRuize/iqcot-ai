# R046 Automated Research Plan After Direction Revision

Date: 2026-06-24

## Purpose

This plan replaces the previous automation focus on v8 manuscript polishing and
AI/`T_slew` scheduling. Future automated work should support the revised
converter-control direction:

```text
PR-ECB cut-load voltage stabilization
+ PIS-IEK steady-state current sharing
+ variable-phase add/shed hybrid event management
```

## Automation Rules

1. Do not repeat R042/R043 post-processing unless a new audit identifies a
   concrete error.
2. Do not run new switching simulations until a derived-control model plan has
   been written and checked.
3. Do not treat `T_slew` as a main control variable. It is only a possible
   post-peak recovery parameter.
4. Do not make AI the main claim. AI is future supervisory scheduling only.
5. Preserve original `.slx` files. If a model change is needed, build a derived
   copy through MATLAB APIs.

## Next Heartbeat Priority Order

### Priority 1: Architecture and State-Machine Specification

Create or update:

- `docs/control_state_machine_after_feedback.md`
- an architecture figure showing:
  - original IQCOT inner loop
  - PR-ECB cut-load protection layer
  - PIS-IEK current-sharing/reentry layer
  - phase add/shed layer

No simulation is required.

### Priority 2: Derived Simulink Model Plan

Before editing or building any model copy, produce a table:

| Item | Existing signal/block | Proposed derived signal/block | Reason |
|---|---|---|---|
| Ton truncation | TBD from model inspection | `ton_truncate_i` | cut-load over-voltage protection |
| Pulse inhibit | TBD | `inhibit_hs_i` | prevent new high-side energy injection |
| Integrator hold/reset | TBD | `hold_int_i`, `reset_int_i` | safe reentry |
| Active phase set | TBD | `active_phase_set` | phase add/shed |
| Balance trim | TBD | `Ton_trim_i`, `Lambda_trim_i` | steady-state current sharing |

Only after this table exists should automation proceed to MATLAB model-copy
construction.

### Priority 3: PR-ECB Cut-Load Protection Ablation

Run only after model wiring is checked:

| Case | Controller |
|---|---|
| A0 | original IQCOT |
| A1 | simple over-voltage skip |
| A2 | PR-ECB + Ton truncation |
| A3 | PR-ECB + Ton truncation + pulse inhibit + controlled reentry |

Output directory:

```text
output/cutload_pr_ecb_control/
```

### Priority 4: PIS-IEK Current-Sharing Ablation

Run only after the cut-load model path is stable:

| Case | Controller |
|---|---|
| B0 | original IQCOT |
| B1 | Lambda_diff only |
| B2 | Ton_diff only |
| B3 | Ton_diff + Lambda_diff |
| B4 | PIS-IEK-guided limited control |

Output directory:

```text
output/pis_iek_balance_control/
```

### Priority 5: Phase Add/Shed Hybrid Event Validation

Implement after PR-ECB and PIS-IEK controller comparisons exist:

- `1/2/4` active phase sets
- add/shed hysteresis
- dwell timer
- shedding disabled during cut-load protection
- reentry before shedding

Output directory:

```text
output/phase_add_shed_control/
```

## Required Updates After Each Heartbeat

Each heartbeat that changes files should update:

- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `refine-logs/LOCAL_AUDIT_R0XX_*.md`
- relevant `docs/*.md`

Then commit and push to GitHub:

```text
git status
git add <changed files>
git commit -m "<concise research-step message>"
git push
```

## Stop Conditions

Pause and notify the user if:

- a proposed simulation requires modifying original `.slx` files;
- a model inspection finds hard-coded parameters that invalidate the assumed
  control path;
- GitHub push fails;
- generated results would require claiming hardware/HIL validation.

