# Deep Research External Literature Review Summary

Source report: `docs/deep_research_external_literature_review.md`

## R050 Integration Summary

The external review supports a bounded research position:

- IQCOT and multiphase COT literature already exist and must be cited; this project should not claim to invent IQCOT or the first multiphase COT small-signal model.
- Direct literature for machine learning replacing the multiphase COT inner loop is limited; stronger support exists for AI or learning methods as parameter optimization, compensation tuning, safe supervisory scheduling, and sim-to-real support.
- The most defensible project novelty is the four-phase digital IQCOT event interface: phase-indexed integral-event modeling, Ton/Lambda/delay actuator classification, and digital implementation budgets that map quantization, clocks, Ton resolution, and supervisor delay to event jitter, phase-spacing jitter, and current-sharing quantization.
- PR-ECB should remain a risk boundary, risk coordinate, safety guard, or protection-oriented framework. It should not be described as a universal first-peak bound.
- AI supervisor should remain a low-dimensional parameter proposer and safety-projected action interface. It should not be described as an AI inner-loop controller or direct gate/PWM controller.
- Active-set add/shed is a promising extension, but the current repository should keep it as future or controlled-extension work until specific validation exists.

## Impact on Current Paper Line

The current paper-ready spine should be:

1. PIS-IEK event-domain small-signal model;
2. Ton_diff / Lambda_diff / delay_diff actuator separation;
3. digital implementation budget.

PR-ECB, AI supervisor, and active-set add/shed remain controlled extensions unless later minimal validation upgrades their evidence level.

## Claim Boundary

Allowed wording:

- "within the studied four-phase digital IQCOT implementation..."
- "the current evidence supports..."
- "derived-Simulink validation suggests..."
- "risk-coordinate framework..."
- "guarded supervisor interface..."

Forbidden wording:

- "this project invents IQCOT"
- "first multiphase COT small-signal model"
- "AI replaces the IQCOT inner loop"
- "AI directly controls gate/PWM pulses"
- "PR-ECB is a universal first-peak bound"
- "active-set PIS-IEK is fully validated"
