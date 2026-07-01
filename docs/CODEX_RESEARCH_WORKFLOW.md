# Codex Research Workflow for Four-Phase Digital IQCOT

This document is the long-term repository workflow for Codex-assisted IQCOT research rounds. Future rounds should read this file, `.codex/skills/iqcot-research/SKILL.md`, and `docs/CODEX_OUTPUT_PROTOCOL.md` before changing research artifacts, running validation, or drafting claims.

## 1. Project Scope

The current project scope is:

- four-phase digital IQCOT Buck / VRM;
- PIS-IEK phase-indexed integral-event modeling;
- Ton_diff / Lambda_diff / delay_diff actuator separation;
- digital implementation budget;
- PR-ECB cut-load first-peak risk boundary / guard framework;
- AI-ready safe supervisor;
- active-set add/shed as an exploratory extension.

The project does not claim to invent IQCOT, replace the IQCOT inner loop with AI, or complete hardware/HIL validation.

## 2. Current Strongest Paper Line

The current strongest paper line is:

1. PIS-IEK event-domain small-signal model;
2. Ton_diff / Lambda_diff / delay_diff actuator separation;
3. digital implementation budget.

These three lines are stronger than PR-ECB, AI supervisor, and active-set add/shed as a present manuscript core because they are closer to the recurring model structure and can be validated with smaller, more interpretable ablations. They also define the interface through which later guarded supervisory actions can be described without claiming that AI replaces the inner loop.

## 3. Exploratory Lines

- PR-ECB is valuable but currently should be described as a risk-boundary / guard framework.
- AI supervisor is valuable but should be described as a safe low-dimensional parameter proposer.
- Active-set add/shed is promising but requires further validation.

Use exploratory lines as controlled extensions. Do not let them overwrite the stronger PIS-IEK + actuator separation + digital budget story unless new evidence justifies that change.

## 4. Validation Ladder

Recommended validation sequence:

- R050: research state alignment
- R051: PIS-IEK actuator ablation consolidation
- R052: digital jitter budget consolidation
- R053: PR-ECB controlled reentry minimal chunk
- R054: related work and contribution rewrite
- R055+: active-set add/shed and AI supervisor validation

Each round should consume the previous round's classification before expanding scope. A `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED` result should tighten or redirect the next task before any full matrix is proposed.

## 5. Minimal-Chunk Principle

Do not start from a full simulation matrix. Use the smallest useful chunk:

- PR-ECB: one load-drop magnitude x two phase offsets
- PIS-IEK balance: one mismatch family x two loads
- digital budget: one parameter sweep at a time
- AI supervisor: table/rule-based first, neural model later
- active-set: one add case and one shed case

Only expand a matrix after the minimal chunk is classified and the claim boundary is updated.

## 6. Model Revision Rules

Revise the model interpretation, implementation, or claim boundary when:

- PR-ECB predicts low risk but overshoot is high
- PR-ECB is too conservative and causes severe undershoot
- Ton_diff improves balance but destroys phase spacing
- Lambda_diff unexpectedly changes DC current strongly
- active phase shedding causes overshoot/reentry failure
- new phase ramp causes current spike
- metrics conflict with physical trend

Do not hide a conflicting result behind wording such as "effect improved" without reporting metrics, baseline, and the affected claim.

## 7. Claim Boundary Rules

Allowed claim language:

- "derived-Simulink validation suggests..."
- "within the studied four-phase digital IQCOT implementation..."
- "the current evidence supports..."
- "the result motivates..."
- "risk-coordinate framework..."
- "guarded supervisor interface..."

Forbidden claim language:

- "hardware proves..."
- "globally optimal..."
- "universal first-peak bound..."
- "AI replaces the controller..."
- "Lambda_diff controls DC current sharing..."

Keep evidence labels attached to claims. Derived Simulink, offline processing, and CSV-only evidence must not be described as hardware/HIL evidence.

## 8. Relationship to External Literature

The external deep-research report is now available at `docs/deep_research_external_literature_review.md`, with an R050 integration summary at `docs/deep_research_external_literature_review_summary.md`.

R050 integration conclusions:

- IQCOT base literature exists and must be cited; this project must not claim to invent IQCOT.
- Multiphase COT small-signal and phase-overlap modeling literature exists and must be cited; this project must not claim to be the first multiphase COT small-signal model.
- Digital COT / DICOT, current-balance loops, load transient / unload overshoot studies, and AI / RL / safe projection literature exist and must be treated as related work.
- The strongest current novelty is the IQCOT-specific four-phase digital event interface: PIS-IEK, Ton/Lambda/delay actuator separation, and digital implementation budget.
- PR-ECB should be written as a risk boundary / risk coordinate / safety guard, not a universal first-peak predictor.
- AI supervisor should be written as a guarded low-dimensional parameter proposer, not an AI inner-loop controller.
- Active-set add/shed should be kept as a controlled extension until further validation exists.

## 9. Per-Round Operating Rules

Before a round:

- Read `.codex/skills/iqcot-research/SKILL.md`.
- Read `docs/CODEX_OUTPUT_PROTOCOL.md`.
- Check `git status`.
- Identify whether the round touches PIS-IEK, actuator separation, digital budget, PR-ECB, AI supervisor, or active-set model.

During a validation round:

- Use derived `.slx` copies only.
- Document critical power-stage, control, solver, step-size, and logging settings.
- Record baseline metrics and candidate metrics.
- Stop at the smallest chunk that can decide the hypothesis.

After a round:

- Classify the result as `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`.
- Update the claim boundary before expanding the validation grid.
- End with one recommended next minimal task and an exact next prompt draft.
- Commit and push the intended files only.
