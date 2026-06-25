# R049M PR-ECB Reentry Upstream Boundary Audit

Date: 2026-06-25

## Scope

R049M performs a read-only structural audit after R049L repair showed that
downstream `qh1` cannot be used as a one-shot release trigger.  The goal is to
identify whether the current R049L repair model already exposes an upstream
phase-boundary / scheduler-slot signal that keeps evolving while
`allow_to_scheduler` is inhibited.

No new switching simulation was run.  No `.slx` file was saved or modified.

Model audited:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx
```

## Verified scheduler trigger chain

The model topology is:

```text
REQ + GlobalReady
  -> existing allow logic
  -> R049L_Gate_And
  -> Goto16(tag=Allow)
  -> From16(tag=Allow)
  -> Detect Rise Positive
  -> Goto17(tag=tr)
  -> From18(tag=tr)
  -> PhaseScheduler_4Phase trigger port
```

Inside `PhaseScheduler_4Phase`, the phase state is held in:

```text
PhaseScheduler_4Phase/phase_state
```

and advances only when the triggered subsystem receives an `Allow` rising edge.
The trigger port is configured as:

```text
TriggerType = rising
StatesWhenEnabling = held
phase_state SampleTime = -1
phase_state InitialCondition = 0
```

Therefore, scheduler-internal state is downstream of the R049L request gate.
It freezes during request-path inhibition and cannot be the causal release
clock for that same inhibition.

## Candidate audit

| Candidate | Signal / path | Upstream of R049L gate | Evolves during inhibit | Phase-boundary semantics | Causal release candidate | Verdict |
|---|---|---:|---:|---:|---:|---|
| C1 | `req_global` / `Goto14` | yes | yes | no | no | reject: comparator request, not phase boundary |
| C2 | existing allow / `Logical Operator` output | yes | yes | no | no | reject: gate input, not phase slot |
| C3 | `Allow` rising / `tr` | no | no | yes | no | reject: downstream of R049L gate |
| C4 | `PhaseScheduler_4Phase/phase_state` | no | no | yes | no | reject: freezes during inhibit |
| C5 | `PhaseScheduler_4Phase/phase_idx` | no | no | yes | no | reject as cause; useful as effect log |
| C6 | `phase_en1..4` / `tr1..4` | no | no | yes | no | reject: downstream scheduler outputs |
| C7 | downstream `qh1` | no | no | yes | no | reject: circular dependency already observed |
| C8 | independent phase-clock / predicted slot | yes | yes | yes | yes | promote to next minimal design |

## Decision

```text
MODEL_REVISED
```

R049M does not confirm controlled reentry.  It revises the implementation
model: the current scheduler has no exposed upstream phase-boundary signal that
can be reused directly.  Existing `phase_state`, `phase_idx`, phase enable
outputs, and `qh1` are all downstream of the gated `Allow` trigger.

The next viable design class is an independent upstream phase-clock or
predicted scheduler-slot signal.  It should be generated outside the inhibited
request path and calibrated against the observed R049K / R049L repair phase
boundary region:

```text
first useful release boundary ≈ 1.678-1.690 us after load step
```

## Next minimal validation

Build a new derived copy, tentatively R049M-one-shot or R049N depending on
naming continuity, with:

```text
release_clock = independent phase-clock / predicted slot
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

Then run only the same four-row chunk:

```text
40A -> 20A
offsets = 0.050 us, 0.105 us
A0 same-model no-reentry-control
A2 independent-clock one-shot reentry
```

Quality gates:

- A0 baseline must remain matched to R049K.
- `one_shot_edge_count >= 1` and finite `one_shot_time_us`.
- current active-HS pulse must not be truncated.
- Ton truncation must remain disabled.
- R049H three-window audit must report early/recovery/late metrics.

## Evidence files

- `output/iqcot_r049m_reentry_boundary_audit.m`
- `output/cutload_pr_ecb_control/r049m_reentry_boundary_candidates.csv`
- `output/cutload_pr_ecb_control/r049m_reentry_boundary_audit_report.md`

## Claim boundary

R049M is a structural audit only.  It is not a switching-performance result,
not hardware/HIL validation, and not confirmation of PR-ECB controlled reentry.
