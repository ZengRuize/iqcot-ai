# Adaptive Validation Automation for GAE-IQCOT

Date: 2026-06-24

## Purpose

This document adjusts the research automation after R047. Future validation must
not be a fixed batch that only produces CSV files. It must be an adaptive loop:

```text
validate -> diagnose -> revise model innovation -> revise next validation
```

The model innovation itself is allowed to change during validation, but only in
a controlled, evidence-tracked way.

## Automation Principle

Each automated research heartbeat must end with one of four decisions:

| Decision | Meaning | Required update |
|---|---|---|
| `MODEL_CONFIRMED` | results match the current GAE-IQCOT/PR-ECB/PIS-IEK expectation | keep model, advance to next matrix |
| `MODEL_REVISED` | results reveal a model-structure issue or missing feature | update the model innovation document and claim boundary |
| `IMPLEMENTATION_ISSUE` | result likely comes from `.slx` wiring, hard-coded parameter, solver, or logging issue | stop new validation and inspect model |
| `CLAIM_DOWNGRADED` | effect exists but is weaker/narrower than expected | update evidence matrix and safe wording |

No validation heartbeat should continue to the next simulation batch without one
of these decisions.

## Closed-Loop Workflow

### Step 0: Preflight model audit

Before any switching validation:

1. inspect the derived `.slx` model or extracted `.slx` XML;
2. verify whether `Ron`, `Rd`, `Vfd`, `Rs`, `Cs`, `L`, DCR, `Cout`, ESR, `Ton`,
   `Tdead`, `Tblank`, `Vhys`, solver, and step size are actual variables or
   hard-coded literals;
3. classify the controller as open-loop PWM, closed-loop COT/IQCOT, or cascaded
   PWM;
4. confirm the log paths for `Vout`, `Iload`, `IL1..IL4`, gates, `REQ`,
   `phase_idx`, area integrators, and active phase set.

If this audit fails, automation must not run new control validation.

### Step 1: Declare the current model hypothesis

Each validation chunk must begin with a short hypothesis block:

```text
Model version:
Hypothesis:
Expected improvement:
Expected failure mode:
Metrics:
Claim boundary if successful:
Claim boundary if unsuccessful:
```

For example:

```text
Model version: GAE-IQCOT R047
Hypothesis: PR-ECB-guided Ton truncation lowers cut-load overshoot versus
original IQCOT without causing severe secondary undershoot.
Expected failure mode: overly long pulse inhibit may delay reentry.
Metrics: peak overshoot, inhibit duration, reentry time, secondary oscillation.
```

### Step 2: Run the smallest useful validation chunk

Do not start with a full grid. Use minimal chunks:

- PR-ECB cut-load: one load-drop magnitude crossed with two phase offsets;
- PIS-IEK balance: one mismatch family crossed with two loads;
- phase add/shed: one add case and one shed case;
- model-vs-no-model: one representative transient and one representative
  steady-state point.

Only scale up after the model behavior is diagnosed.

### Step 3: Diagnose model mismatch

After each chunk, classify mismatch by branch:

| Branch | Symptom | Likely correction |
|---|---|---|
| PR-ECB | predicted low risk but overshoot high | add missing phase/energy feature or lower `r_high` |
| PR-ECB | bound very conservative and causes excessive inhibit | split segment or add reentry-aware aggressiveness |
| PIS-IEK | `Ton_diff` improves balance but ruins phase spacing | lower `T_trim_max`, increase `Lambda_diff` recovery, add phase-cost penalty |
| PIS-IEK | `Lambda_diff` unexpectedly changes DC current strongly | revise actuator matrix and cross-coupling terms |
| Add/shed | shed causes overshoot or reentry failure | increase dwell, require balance recovery, disable shed longer after cut-load |
| Add/shed | add phase causes large current spike | add new-phase ramp and integrator reset policy |
| Implementation | metrics inconsistent with physical trend | inspect `.slx` parameter literals, logging, solver, and timing |

### Step 4: Revise the model innovation

If the decision is `MODEL_REVISED`, update the relevant model object:

| Model part | Allowed revision |
|---|---|
| PR-ECB | risk thresholds, dominant-bound segment, active-HS classification, reentry aggressiveness |
| PIS-IEK | actuator matrix, trim projection, cross-coupling penalty, balance-recovery law |
| Active-set model | add/shed guard, dwell timer, active set sequence, new-phase ramp law |
| AI projector | feasible action set, fallback rule, rejection rule, confidence gate |

Every revision must include:

```text
old assumption
observed contradiction
new assumption
affected validation matrix
new forbidden claim if needed
```

### Step 5: Update evidence and next automation

Every heartbeat that changes interpretation must update:

- `docs/ai_control_oriented_model_innovation_20260624.md`
- `docs/control_state_machine_after_feedback.md` if state transitions change;
- `docs/auto_research_plan_after_feedback_20260624.md` if priority changes;
- `output/iqcot_claims_evidence_matrix.md`
- `research-wiki/query_pack.md`
- `research-wiki/log.md`
- a new `refine-logs/LOCAL_AUDIT_R0XX_*.md`.

Then commit and push.

## Real-Time Adjustment Rules by Validation Stage

### PR-ECB cut-load validation

After each A-matrix chunk:

1. compare actual peak overshoot against PR-ECB risk class;
2. compare reentry time and secondary oscillation against protection strength;
3. update `r_low/r_high`, `N_inhibit`, or bound-family segmentation if needed;
4. if first-peak behavior changes with phase offset more than expected, add a
   phase-state feature before expanding the grid.

Do not proceed to current-sharing validation if cut-load protection destabilizes
reentry.

### PIS-IEK current-sharing validation

After each B-matrix chunk:

1. compute current imbalance improvement;
2. compute phase-spacing cost;
3. revise the projection weights between `Ton_diff` and `Lambda_diff`;
4. if `Ton_diff` causes unacceptable phase error, reduce trim limit or add a
   phase-cost term;
5. if `Lambda_diff` shows stronger current authority than existing evidence,
   revise the actuator classification rather than forcing the old claim.

### Model-vs-no-model ablation

After each C-matrix chunk:

1. check whether PR-ECB-only helps cut-load but not steady current sharing;
2. check whether PIS-IEK-only helps balance but not first peak;
3. check whether combined control creates interaction problems;
4. if combined control is not best, diagnose coupling instead of hiding the
   result.

### Phase add/shed validation

After each D-matrix chunk:

1. verify voltage peak/undershoot before reporting efficiency proxy;
2. verify disabled-phase residual current;
3. verify new-phase current ramp;
4. verify phase-spacing recovery after active-set change;
5. revise add/shed dwell and reentry locks if any transient metric degrades.

## Automation Stop Conditions

Pause automation and notify the user if:

- a proposed action requires editing an original `.slx` file;
- `.slx` inspection finds a hard-coded parameter that invalidates planned
  sweeps;
- PR-ECB protection causes worse over-voltage than baseline in a representative
  case;
- PIS-IEK projected balance worsens both current sharing and phase spacing;
- phase shedding occurs during cut-load protection;
- any result would require claiming hardware/HIL validation.

## Updated Next Heartbeat

Status after R049A: the preflight model audit and actual model-path wiring
table are complete, and a PR-ECB derived-control scaffold has been built at
`output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control.slx`.

The next heartbeat should not run a full simulation matrix. It should replace
the no-op R049A protection placeholders with only one minimal derived-copy
protection action first, then run the smallest PR-ECB cut-load protection chunk:
one load-drop magnitude crossed with two phase offsets.

Recommended next output:

```text
docs/pr_ecb_control_minimal_chunk_r049b.md
refine-logs/LOCAL_AUDIT_R049B_PR_ECB_MINIMAL_*.md
```

Status after R049B: the smallest OV-skip chunk completed and ended in:

```text
CLAIM_DOWNGRADED
```

R049B used a new derived copy,
`output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049b_ovskip.slx`,
and ran only `40A -> 1A near0` at offsets `0.05 us` and `0.105 us` with
A0/A1 rows.  The simple over-voltage skip gate inhibited later requests
(`18.880 us` / `19.816 us`; `19` / `20` skipped REQ edges) but did not reduce
the first peak (`6.2586 mV` and `5.9603 mV`, unchanged from A0).

Adaptive revision:

- simple OV skip remains a valid `SKIP_HOLD` / request-inhibit action;
- it must not be claimed as a validated first-peak suppression action;
- the next chunk should test minimal Ton truncation or active-HS remaining-on-time
  truncation before any full PR-ECB A-matrix expansion.
