# Claim Boundaries

## Allowed Claims

The current project may claim, after corresponding validation:

- Simulink-derived ideal IQCOT baseline behavior;
- bidirectional load-step regulation improvements in derived ideal models;
- event-domain PIS-IEK explanation of current sharing and phase recovery;
- safety-projected supervisory scheduling of low-dimensional IQCOT parameters;
- active-phase add/shed behavior in derived Simulink validation.

## Forbidden Claims

Do not claim:

- AI directly controls gate commands;
- AI controls external load-current slew rate;
- load-current profile is an actuator;
- Simulink-only evidence is hardware, silicon, board-level, or HIL validation;
- a result from a derived model is baseline behavior unless A0/B0/C0/D0 confirms it;
- current sharing, efficiency, or active-phase robustness without mismatch evidence.

## Evidence Labels

Every experiment report must classify the result as one of:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

Use `MODEL_CONFIRMED` only when the metric movement supports the written model and the wiring audit is clean.

Use `MODEL_REVISED` when the simulation is valid but the theory needs an update.

Use `IMPLEMENTATION_ISSUE` when missing logging, incorrect wiring, solver setup, copied-model errors, or projection bugs prevent theoretical interpretation.

Use `CLAIM_DOWNGRADED` when evidence is valid but weaker than the intended claim.

## Update Rule

After each simulation chunk, update evidence before expanding the grid. Theory documents may be revised only with explicit reference to the experiment, derived model, metrics CSV, and report path.

## Current E010 Evidence Boundary

Validated so far:

```text
experiment: E010 load-drop overshoot
cases: 40A -> 20A, 40A -> 10A, 40A -> 1A external load-current steps
operating-boundary check: 120A -> 10A
variants: A0-A4 where available
summary: experiments/E010_load_drop_overshoot/e010_research_summary.md
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, the table-selected load-drop a_O token
acts as a magnitude selector plus safety projection: it preserves no-op behavior
for the mild 40A -> 20A case, selects Ton truncation plus one early pulse inhibit
for the medium 40A -> 10A case and reduces the 2-12us recovery peak by about
22.2% versus A0 with a bounded 0.863951 mV undershoot penalty, and remains
no-harm but non-improving for the severe 40A -> 1A case under the present guard.
```

Not yet allowed:

- generalization to all E010 load-drop cases;
- claims at 120A initial load until the high-load operating boundary is resolved;
- load-rise undershoot recovery claims;
- current-sharing or phase-recovery claims under mismatch;
- active-phase add/shed claims;
- hardware, HIL, or board-level claims.

## Current E020 Evidence Boundary

Validated so far:

```text
experiment: E020 load-rise undershoot
case: 40A -> 120A external load-current step
variants: B0, B1, B2, B3
summary: experiments/E020_load_rise_undershoot/e020_research_summary.md
metrics: experiments/E020_load_rise_undershoot/e020_metrics.csv
classification: MODEL_CONFIRMED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, the projected load-rise a_U branch can
reduce peak undershoot and accelerate current rise for the severe 40A -> 120A
external load-current rise. Fast request is the dominant first lever; Ton boost
is weak alone but improves the result when combined with fast request.
```

Quantitative local evidence:

```text
B0 peak undershoot = 397.42 mV
B1 fast request only peak undershoot = 343.79 mV
B2 Ton boost only peak undershoot = 382.41 mV
B3 fast request + Ton boost peak undershoot = 319.08 mV

B0 90% current-rise time = 37.996 us
B3 90% current-rise time = 1.212 us
B3 phase-current peak = 34.09 A/phase
current-limit guard = not hit
```

Not yet allowed from E020:

- full `40A -> 120A` recovery or final-regulation claim;
- settling-time claim, because no tested variant settled within the `1 mV` band in the `90 us` post-step window;
- 120A operating-boundary claim, because B3 final error remained about `-297.93 mV` at `75-90 us`;
- phase-add benefit claim, because B4/B5 were not run;
- global load-rise generalization beyond this first derived-Simulink chunk.

## Current E030/E040 Boundary

E030 balance recovery is pending controller validation. PIS-IEK evidence may be used to motivate actuator classification, but not yet to claim closed-loop mismatch robustness.

E040 active-phase add/shed is planned. Do not claim active-phase robustness until add/shed transitions are validated with voltage, reentry, current-sharing, dwell, and residual-current guards.

These restrictions are standing:

- AI/table may observe load-step features but must not control external load-current slew.
- AI/table must not command gates.
- Current Simulink evidence is not hardware, HIL, board-level, or silicon evidence.
