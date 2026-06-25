# R049M PR-ECB Reentry Upstream Boundary Audit

Date: 2026-06-25

## Scope

Read-only structural audit of `four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx`.
No new switching simulation was run and no `.slx` model was saved.

## Verified trigger chain

- Allow Goto: `four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry/Goto16` tag `Allow`
- Allow source: `four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry/R049L_Gate_And/1`
- Scheduler trigger source: `four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry/From18/1`
- Scheduler trigger type: `rising`
- Scheduler state behavior: `held`, `phase_state` sample time `-1`, initial `0`

The scheduler is triggered by `tr`, which is generated from the gated `Allow` path.  Therefore scheduler-internal phase state does not continue to advance while request-path inhibition is active.

## Candidate table

| Candidate | Signal | Upstream of R049L gate | Evolves during inhibit | Phase-boundary semantics | Causal release candidate | Verdict |
|---|---|---:|---:|---:|---:|---|
| `C1` | `req_global` | `yes` | `yes` | `no` | `no` | Reject for R049M release trigger. |
| `C2` | `existing_allow` | `yes` | `yes` | `no` | `no` | Reject for release trigger. |
| `C3` | `Allow rising / tr` | `no` | `no` | `yes` | `no` | Reject; downstream of gate. |
| `C4` | `PhaseScheduler phase_state` | `no` | `no` | `yes` | `no` | Reject; freezes during inhibit. |
| `C5` | `phase_idx outport` | `no` | `no` | `yes` | `no` | Reject as cause; keep as logged effect. |
| `C6` | `phase_en1..4 / tr1..4` | `no` | `no` | `yes` | `no` | Reject; downstream. |
| `C7` | `downstream qh1` | `no` | `no` | `yes` | `no` | Reject; circular dependency already observed. |
| `C8` | `independent phase-clock / predicted slot` | `yes` | `yes` | `yes` | `yes` | Promote to next minimal design candidate. |

## Decision

```text
MODEL_REVISED
```

R049L repair remains `IMPLEMENTATION_ISSUE`, but this structure audit identifies the next viable design class: an independent upstream phase-clock / predicted scheduler-slot trigger.  Existing scheduler outputs (`phase_state`, `phase_idx`, `phase_en`, `tr1..4`) are not valid causal release triggers because they are downstream of the gated `Allow` trigger and freeze during inhibit.

## Next minimal design

Build a new derived copy that adds an upstream phase-clock / predicted-slot one-shot trigger.  Calibrate its first release boundary against the R049K observed qh1 release region around `1.678-1.690 us`, then run only the same four-row `40A -> 20A` chunk with the R049H three-window audit.
