# Local Audit: R046 Direction Revision After User Feedback

## Scope

This update responds to the user's four research-direction corrections:

1. External load-current slew rate is not controlled by the converter, so
   `T_slew` is not an appropriate main control variable.
2. The IQCOT project objective should be cut-load voltage stabilization and
   steady-state current sharing.
3. Phase add/shed functionality and decision logic should be introduced.
4. Validation should compare model-informed control versus original IQCOT and
   empirical no-model control, without considering AI delay in the next stage.

No new Simulink simulations were run. No original `.slx` file was modified.

## Files Added

- `docs/research_direction_after_user_feedback_20260624.md`
- `docs/auto_research_plan_after_feedback_20260624.md`

## Files Updated

- `README.md`
- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- `output/iqcot_claims_evidence_matrix.md`

## New Research Main Line

```text
PR-ECB cut-load voltage stabilization
+ PIS-IEK steady-state current sharing
+ variable-phase add/shed hybrid event management
```

AI and `T_slew` are downgraded to future supervisory/recovery extensions. They
are not the next-stage main claim.

## Next Required Work

The next automation step should specify:

- the derived control state machine;
- the model-wiring table for PR-ECB, Ton truncation, pulse inhibit, integrator
  hold/reset, PIS-IEK balancer, and phase add/shed logic;
- logged signals and metrics.

Only after that should derived Simulink model construction or new simulation
cases begin.

## Claim Boundary

Allowed:

- PR-ECB guides cut-load first-peak protection actions.
- PIS-IEK guides steady-state current-sharing and phase recovery.
- Active phase set modeling is needed for 1/2/4 phase add/shed.

Forbidden:

- `T_slew` controls external load-current slew.
- AI replaces IQCOT inner-loop gate generation.
- PIS-IEK precisely predicts all large-signal first peaks.
- PR-ECB or the revised framework has hardware/HIL validation.

