---
name: iqcot-research
description: Use for IQCOT, PIS-IEK, PR-ECB, AI supervisor, active-set add/shed, four-phase digital Buck/VRM, COT, Simulink validation, manuscript, claim-boundary, evidence, or GitHub-synced research-round tasks in this repository. Enforces project scope, forbidden claims, evidence hierarchy, validation workflow, output protocol, and next-prompt discipline.
---

# IQCOT Research Skill

## 1. Research Identity

This project studies four-phase digital IQCOT Buck/VRM modeling and guarded supervisory control.

The project does not claim to invent IQCOT. It focuses on:

- phase-indexed integral-event modeling;
- Ton/Lambda/delay actuator separation;
- digital implementation budget;
- PR-ECB cut-load first-peak risk boundary;
- AI-ready guarded supervisory projection.

Treat the original `.slx` files as protected source artifacts. Use derived copies for validation, document evidence strength explicitly, and keep claims inside the validated scope.

## 2. Main Research Lines

### Strong paper-ready line

- PIS-IEK small-signal event model
- Ton_diff / Lambda_diff / delay_diff actuator separation
- Digital implementation budget

### Exploratory line

- PR-ECB first-peak risk boundary
- AI supervisor
- active-set add/shed

Use the strong paper-ready line as the default manuscript spine unless the user explicitly asks for exploratory validation or writing.

## 3. Forbidden Claims

- Never claim this project invented IQCOT.
- Never claim this project is the first multiphase COT small-signal model.
- Never claim hardware/HIL validation is complete.
- Never claim AI is universally better than every baseline.
- Never claim AI replaces the IQCOT inner loop.
- Never claim AI directly controls gate-level pulses.
- Never claim PR-ECB is a universal first-peak bound.
- Never claim PR-ECB precisely predicts all first peaks.
- Never claim Lambda_diff is a strong DC current-sharing actuator.
- Never claim active-set PIS-IEK is fully validated.
- Never equate derived-Simulink or offline evidence with hardware measurement.
- Never modify original `.slx` models.

## 4. Evidence Hierarchy

Highest:

- hardware measurement
- HIL validation

Strong:

- switching-level derived Simulink / Simscape validation with clear baseline, repeatable scripts, and metrics

Medium:

- event-domain surrogate with switching-level cross-validation
- table-driven delayed-supervisor validation

Weak:

- offline post-processing only
- isolated CSV without baseline
- claim without ablation
- neural label generation without closed-loop validation

Always state the evidence level before upgrading a claim.

## 5. Validation Workflow

Every validation heartbeat must follow:

```text
validate -> diagnose -> revise model interpretation -> revise next validation
```

Every round must end with one of:

- MODEL_CONFIRMED
- MODEL_REVISED
- IMPLEMENTATION_ISSUE
- CLAIM_DOWNGRADED

Definitions:

MODEL_CONFIRMED:
Results match the current model hypothesis within the declared scope.

MODEL_REVISED:
Results reveal a missing feature, wrong assumption, or model-structure issue.

IMPLEMENTATION_ISSUE:
The result is likely caused by wiring, parameter, logging, solver, script, or derived-model issue.

CLAIM_DOWNGRADED:
The effect exists but is weaker, narrower, or more conditional than expected.

## 6. Simulink Rules

- Never modify original `.slx` files.
- Always use derived copies for validation.
- Before running new validation, inspect or document:
  - Ron
  - Rd
  - Vfd
  - Rs
  - Cs
  - L
  - DCR
  - Cout
  - ESR
  - Ton
  - Tdead
  - Tblank
  - solver
  - step size
  - logging paths
- Log at least:
  - Vout
  - Iload
  - IL1..IL4
  - gate signals
  - REQ
  - phase_idx
  - area integrators if applicable
  - active phase set if applicable
- Do not run full matrix before minimal-chunk confirmation.

## 7. Claim Rules

Every round must explicitly comment on whether it touches:

- PIS-IEK
- actuator separation
- digital budget
- PR-ECB
- AI supervisor
- active-set model

If a topic is not touched, write `not touched`.

## 8. Output Protocol

Every round must produce:

- task metadata
- objective
- hypothesis block
- files inspected
- files changed
- data / figures generated
- key metrics
- result classification
- claim impact
- forbidden claims check
- limitations
- updated research state
- next minimal task
- exact next prompt draft
- GitHub branch and commit SHA

Use `docs/CODEX_OUTPUT_PROTOCOL.md` as the canonical template for final round output.

## 9. GitHub Protocol

Every round must run:

```text
git status
git add ...
git commit -m "R0XX: concise task summary"
git push
```

The final Codex response must include:

- Branch
- Commit SHA
- Commit message
- Files pushed

If the working tree contains unrelated pre-existing changes, avoid staging them unless the user explicitly requests it.

## 10. Next Prompt Rule

Every round must end with exactly one recommended next minimal task and an exact next prompt draft.

Do not recommend multiple large tasks at once.
Do not propose full-matrix validation unless prior minimal validation was MODEL_CONFIRMED.
