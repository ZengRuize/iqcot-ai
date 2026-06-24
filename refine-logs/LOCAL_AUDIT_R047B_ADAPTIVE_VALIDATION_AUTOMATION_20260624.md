# Local Audit: R047B Adaptive Validation Automation

## Scope

The user requested that automation be adjusted and that model innovation be
updated during validation rather than after all validation is finished.

This update modifies the project automation plan so future validation follows:

```text
validate -> diagnose -> revise model innovation -> revise next validation
```

No new Simulink simulation was run. No `.slx` file was modified.

## Files Added

- `docs/adaptive_validation_automation_20260624.md`
- `refine-logs/LOCAL_AUDIT_R047B_ADAPTIVE_VALIDATION_AUTOMATION_20260624.md`

## Files Updated

- `docs/auto_research_plan_after_feedback_20260624.md`
- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md`
- `README.md`
- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `output/iqcot_claims_evidence_matrix.md`

## New Automation Rule

Each validation chunk must end with one of four decisions:

| Decision | Meaning |
|---|---|
| `MODEL_CONFIRMED` | current model expectation is supported |
| `MODEL_REVISED` | model innovation must be changed before next chunk |
| `IMPLEMENTATION_ISSUE` | stop and inspect `.slx` wiring/parameters/solver/logging |
| `CLAIM_DOWNGRADED` | evidence exists but claim scope must be narrowed |

## Adaptive Revision Policy

Validation results can revise:

- PR-ECB risk thresholds, dominant-bound segmentation, active-HS classification,
  and protection/reentry aggressiveness;
- PIS-IEK actuator matrix, trim limits, cross-coupling penalties, and
  balance-recovery law;
- active-phase add/shed guards, dwell timers, reentry lockouts, and new-phase
  ramp logic;
- AI action projection, feasible action set, fallback rule, and confidence gate.

Any such revision must update the model innovation document, state-machine rules
if relevant, evidence matrix, wiki/log, and refine-log before the next
simulation chunk.

## App Automation Note

The Codex automation tool was discovered, but this environment did not expose
`CODEX_HOME`, and the user did not specify a concrete schedule or existing
automation id. Therefore this update changes the project's automated research
plan rather than creating or modifying a timed Codex App automation.
