# LOCAL AUDIT R049M Reentry Upstream Boundary

Date: 2026-06-25

## Decision

```text
MODEL_REVISED
```

## Scope

R049M performed a read-only structural audit of:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx
```

No new switching simulation was run.  No `.slx` file was saved or modified.

## Finding

The scheduler trigger chain is downstream of the request-path gate:

```text
R049L_Gate_And -> Allow -> Detect Rise Positive -> tr -> PhaseScheduler_4Phase trigger
```

`PhaseScheduler_4Phase/phase_state` is a `UnitDelay` inside a triggered
subsystem.  It updates only on `tr` / `Allow` rising edges and is held
otherwise.  Therefore `phase_state`, `phase_idx`, `phase_en1..4`, `tr1..4`,
and downstream `qh1` all freeze or disappear during request inhibition.

## Candidate conclusion

Rejected as causal release triggers:

- raw `req_global` because it is a comparator request, not a scheduler phase boundary;
- existing allow because it is a gate input, not a phase slot;
- `tr` because it is downstream of the R049L gate;
- scheduler `phase_state` / `phase_idx` because they update only on `tr`;
- phase enables / per-phase triggers because they are downstream scheduler outputs;
- `qh1` because R049L repair already proved the circular dependency.

Promoted next design class:

```text
independent upstream phase-clock / predicted scheduler-slot trigger
```

## Evidence

- `docs/pr_ecb_reentry_upstream_boundary_audit_r049m.md`
- `output/iqcot_r049m_reentry_boundary_audit.m`
- `output/cutload_pr_ecb_control/r049m_reentry_boundary_candidates.csv`
- `output/cutload_pr_ecb_control/r049m_reentry_boundary_audit_report.md`

## Next step

Build a new derived model that adds an independent upstream phase-clock /
predicted-slot one-shot release.  Calibrate the first release event near the
R049K observed boundary (`1.678-1.690 us`) and run only the same `40A -> 20A`
two-offset A0/A2 chunk with the R049H three-window audit.

## Claim boundary

R049M is model-structure evidence only.  It does not confirm controlled reentry,
does not prove hardware/HIL behavior, and does not complete the PR-ECB
controller.
