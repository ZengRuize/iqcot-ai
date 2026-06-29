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

## Current E030 Evidence Boundary

Validated so far:

```text
experiment: E030 balance recovery
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: C0, C1, C2, C3, C4
summary: experiments/E030_balance_recovery/e030_research_summary.md
metrics: experiments/E030_balance_recovery/e030_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, zero-mean Ton_diff is the dominant
small-signal DC current-sharing actuator for the tested DCR-mismatch case.
The C4 PIS-IEK projected balancer improves max current imbalance versus C0
while using less Ton trim and producing a smaller final Vout error magnitude
than the aggressive Ton_diff-only C1/C3 variants.
```

Quantitative local evidence:

```text
C0 max current imbalance = 0.853665 A
C1 Ton_diff-only max current imbalance = 0.313775 A
C2 Lambda_diff-only max current imbalance = 0.853665 A
C3 Ton_diff + Lambda_diff max current imbalance = 0.313775 A
C4 projected balancer max current imbalance = 0.376221 A

C1/C3 Ton trim usage = 0.865969
C4 Ton trim usage = 0.53786

C1/C3 final Vout error = -58.156 mV
C4 final Vout error = -23.494 mV
```

Not yet allowed from E030:

- robust current-sharing claims across all mismatch families;
- claim that C4 is globally better than Ton_diff-only, because C1/C3 give the lowest current imbalance in this first chunk;
- claim that Lambda_diff is an active DC current-sharing actuator;
- claim that sampled serial REQ-path Lambda control is valid, because that implementation dropped narrow pulses and was revised to side-band projection/logging;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R1 Evidence Boundary

Validated so far:

```text
experiment: E030-R1 projection retune
case: fixed 40A external load, fixed four active phases
mismatch: DCR_L1/L3 = +10%, DCR_L2/L4 = -10%
variants: R1-C0, R1-C1, R1-C4a, R1-C4b, R1-C4c, R1-C4d
summary: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_research_summary.md
metrics: experiments/E030_balance_recovery/R1_projection_retune/e030_r1_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model and one specified +/-10% DCR mismatch
pattern, retuned safety-projected a_S control can trade current-sharing strength
against lower Ton trim usage, smaller final Vout error, and bounded ripple/event
cost. R1-C4a is the best scored Pareto candidate in this chunk; R1-C4c is a
stronger balance candidate with higher trim and final-error cost than R1-C4a.
```

Quantitative local evidence:

```text
R1-C0 max current imbalance = 0.853665 A
R1-C1 Ton_diff reference max current imbalance = 0.313749 A
R1-C4a reduced-KT projection max current imbalance = 0.416996 A
R1-C4c voltage-aware projection max current imbalance = 0.319450 A

R1-C1 Ton trim usage = 0.866649, final Vout error = -58.188 mV, ripple = 15.311 mV
R1-C4a Ton trim usage = 0.404392, final Vout error = -3.604 mV, ripple = 8.128 mV
R1-C4c Ton trim usage = 0.676533, final Vout error = -29.407 mV, ripple = 7.121 mV

REQ dropped vs C0 = 0 for all R1 variants
phase order error rate = 0 for all R1 variants
```

Not yet allowed from E030-R1:

- broad mismatch robustness beyond the specified DCR pattern;
- claim that C4a or C4c globally outperforms Ton_diff-only on current sharing;
- active Lambda_diff closed-loop claims, because R1 keeps Lambda side-band/logging only;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R2 Evidence Boundary

Validated so far:

```text
experiment: E030-R2 current-sense gain mismatch
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R2-C0, R2-C1, R2-C4a, R2-C4c
summary: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_research_summary.md
metrics: experiments/E030_balance_recovery/R2_current_sense_mismatch/e030_r2_metrics.csv
classification: MODEL_REVISED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model, current-sense gain mismatch can create
a real-vs-sensed current-sharing divergence. Ton_diff and projected a_S actions
can reduce controller-observed sensed imbalance while increasing real phase-current
imbalance. Therefore a_S must include a current-sense-confidence or
calibration-aware guard before active-phase validation.
```

Quantitative local evidence:

```text
R2-C0 real max imbalance = 0.036272 A
R2-C0 sensed max imbalance = 0.538006 A

R2-C1 real max imbalance = 0.475724 A
R2-C1 sensed max imbalance = 0.141896 A
R2-C1 Ton usage = 0.871935

R2-C4a real max imbalance = 0.317534 A
R2-C4a sensed max imbalance = 0.195376 A
R2-C4a Ton usage = 0.401338
R2-C4a final Vout error = -7.459 mV

R2-C4c real max imbalance = 0.432627 A
R2-C4c sensed max imbalance = 0.126599 A
R2-C4c Ton usage = 0.681135
R2-C4c final Vout error = -29.616 mV

REQ dropped vs C0 = 0 for all R2 variants
phase order error rate = 0 for all R2 variants
```

Not yet allowed from E030-R2:

- claim that R1-C4a/R1-C4c are robust under current-sense gain mismatch;
- proceed-to-E040 claim before adding a sensing-confidence or calibration-aware guard;
- broad mismatch robustness;
- active Lambda_diff closed-loop claims;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims.

## Current E030-R3 Evidence Boundary

Validated so far:

```text
experiment: E030-R3 calibration-aware a_S guard
case: fixed 40A external load, fixed four active phases
power-stage DCR: nominal
current-sense gains: [1.05, 0.95, 1.05, 0.95]
variants: R3-C0, R3-C1low, R3-C4a_conf, R3-C4a_cal, R3-C4c_cal
summary: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_research_summary.md
metrics: experiments/E030_balance_recovery/R3_calibration_aware_guard/e030_r3_metrics.csv
classification: MODEL_CONFIRMED
```

Allowed claim from this chunk:

```text
In the local ideal IQCOT derived model and one specified current-sense
gain mismatch pattern, a confidence-gated or ideal-calibrated a_S projection
can prevent sensed-current optimization from harming real phase-current balance.
This supports requiring a sensing-aware safety projection before active-phase
scheduling.
```

Quantitative local evidence:

```text
R3-C0 real max imbalance = 0.036272 A
R3-C0 sensed max imbalance = 0.538006 A
real_no_harm threshold = 0.056272 A

R3-C1low real max imbalance = 0.030506 A
R3-C1low sensed max imbalance = 0.522300 A
R3-C1low real_no_harm = true

R3-C4a_conf real max imbalance = 0.036272 A
R3-C4a_conf sensed max imbalance = 0.538006 A
R3-C4a_conf real_no_harm = true

R3-C4a_cal real max imbalance = 0.020618 A
R3-C4a_cal sensed max imbalance = 0.523013 A
R3-C4a_cal real_no_harm = true

R3-C4c_cal real max imbalance = 0.025784 A
R3-C4c_cal sensed max imbalance = 0.527296 A
R3-C4c_cal real_no_harm = true

REQ dropped vs C0 = 0 for all R3 variants
phase order error rate = 0 for all R3 variants
```

Boundary details:

- `R3-C4a_cal` and `R3-C4c_cal` use ideal calibration with `g_hat_i = g_i`; this is not evidence of practical online calibration accuracy.
- `R3-C4a_conf` validates the low-confidence no-op guard behavior, not a current-sharing improvement.
- `R3-C1low` validates a conservative fallback under the tested mismatch pattern.

Not yet allowed from E030-R3:

- broad current-sense robustness beyond the tested gain pattern;
- imperfect calibration robustness;
- active Lambda_diff closed-loop claims;
- active-phase add/shed claims;
- AI neural controller validation;
- hardware, HIL, board-level, or silicon claims;
- global superiority over Ton_diff-only.

## Current E040 Boundary

E040 active-phase add/shed is planned. After E030-R3, it may be prepared only after the local guarded `a_S` selector is frozen. Do not claim active-phase robustness until add/shed transitions are validated with voltage, reentry, current-sharing, dwell, residual-current, and sensing-confidence guards.

These restrictions are standing:

- AI/table may observe load-step features but must not control external load-current slew.
- AI/table must not command gates.
- Current Simulink evidence is not hardware, HIL, board-level, or silicon evidence.
