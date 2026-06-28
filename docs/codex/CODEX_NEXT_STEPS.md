# Codex Next Steps

## Immediate

1. Run E001 baseline wiring audit on the local ideal IQCOT baseline.
2. Confirm or add logging in a derived copy for all required signals.
3. Create the first E010 derived model for `A1 Ton truncation only`.
4. Run one smallest useful load-drop case before expanding:

```text
40A -> 10A
```

5. Generate metrics CSV and Markdown report under `experiments/E010_load_drop_overshoot/`.

## Then

Proceed in this order:

```text
E010 load-drop overshoot
E020 load-rise undershoot
E030 balance recovery
E040 active-phase management
```

Do not start broad sweeps until the smallest chunk has a clean wiring audit and a classified result.

## Theory Feedback Loop

After each run, update:

```text
results/current/latest_summary.md
docs/theory/06_claim_boundaries.md
experiment report under experiments/E###_*/
```

When a result contradicts the current theory, revise the theory before launching a larger grid.

## Standing Guardrail

The AI/table supervisor can observe load-step direction, magnitude, and estimated slew. It must not command external load-current slew.
