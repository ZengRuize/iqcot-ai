# Local Audit: R047 AI-Ready Large/Small-Signal Model Innovation

## Scope

This update continues the interrupted research request in
`codex://threads/019eee01-cb3d-7960-a467-4ef020e2acf7`: design a more
innovative large/small-signal model that remains suitable for AI control.

The task triggers the mandatory `power-electronics-simulink-design` workflow.
The skill and its COT/Simulink references were read before writing the design.

## Files Added

- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md`
- `refine-logs/LOCAL_AUDIT_R047_AI_READY_MODEL_INNOVATION_20260624.md`

## Files Updated

- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `output/iqcot_claims_evidence_matrix.md`
- `README.md`
- `docs/auto_research_plan_after_feedback_20260624.md`

## Research Result

R047 reframes the next innovation as:

```text
GAE-IQCOT:
Guarded AI-ready Event model for IQCOT

= PR-ECB large-signal peak-risk guard
+ PIS-IEK small-signal balance/reentry model
+ variable-active-phase hybrid event map
+ safety projection interface for AI or table supervision
```

The novelty is not direct neural gate control. The novelty is a converter model
interface that exposes compact event features, risk scores, feasible action
sets, and constrained supervisory tokens:

- `a_P`: protection token for Ton truncation, pulse inhibit, integrator policy,
  and reentry policy;
- `a_S`: small-signal balance token for `K_T`, `K_Lambda`, and trim limits;
- `a_N`: active-phase token for `1/2/4` phase selection, hysteresis, dwell, and
  new-phase ramping.

The converter applies only projected safe actions:

```math
a_{safe} = \Pi_{\mathcal G(z_k)}(a_{AI})
```

where the guard set enforces voltage peak risk, current-sharing error,
phase-spacing error, switching-frequency limits, and trim bounds.

## Claim Boundary

Allowed:

- R047 proposes an AI-ready model interface, not an AI gate controller.
- PR-ECB provides a large-signal first-peak risk coordinate and protection
  action guard.
- PIS-IEK provides small-signal balance/reentry channels.
- Active phase set modeling is needed for add/shed hybrid events.

Forbidden:

- AI controls external load-current slew.
- AI replaces IQCOT gate pulse generation.
- PIS-IEK predicts all first peaks.
- PR-ECB is hardware/HIL validated.
- `E_HS,rem` is a global additive correction law.

## Verification Status

No new Simulink simulation was run. No `.slx` file was modified. The next
technical step is model inspection and derived-model wiring before any new
switching validation.
