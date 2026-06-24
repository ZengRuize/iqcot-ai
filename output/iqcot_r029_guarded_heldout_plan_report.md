# R029 held-out guarded-proxy validation plan

## Purpose

R029 tests whether the R028 guarded proxy candidate is merely fitted to the R027 priority contexts.  The plan uses only the derived model when executed and does not edit any `.slx` XML.

## Matrix

- `10A / score_settle005`: `tau_AI = 1.5/2.5/3 us`, `T_slew = 34/40/50/62 us`.
- `near0A / score_settle010`: `tau_AI = 0/0.25/0.5 us`, `T_slew = 30/35/38 us`.

- Total held-out cases: `21`.

## Interpretation Rules

- If `34 us` remains best for `10A/score_settle005` at `tau_AI=2.5/3 us` and is not best at `1.5 us`, the R028 delay guard has local support.
- If `50 us` remains competitive at `tau_AI=2.5/3 us`, the dense-anchor rule is safer than an aggressive delay guard.
- If `62 us` remains poor, R028 correctly rejected the old proxy action.
- For near0A, if `35 us` is best only at `tau_AI=0` but `30 us` wins once delay is introduced, the zero-delay guard is locally supported.

## Boundary

This is a validation plan.  It does not prove hardware performance, global optimality of `T_slew`, or neural-network AI-in-loop superiority.
