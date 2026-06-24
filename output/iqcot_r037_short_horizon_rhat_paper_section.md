### R037 short-horizon `r_hat` predictor prototype

After R036 upgraded `46us@1.25us` and `54us@1.75us` to locally dense-paired
folded candidates, the remaining modeling question is how to express this
boundary in a deployable AI supervisor without using future simulation metrics
as inputs.  R037 therefore merges R031/R033/R034/R036 derived-Simulink rows for
`20A/score+0.05T_settle` into a short-horizon risk table.  The predictor input
contains only context and candidate quantities, plus a `q_phi` folded-band
prior; the labels are `skip`, `settling` and `phase` risks observed in the
switching replay.

The resulting local replay shows that a risk-gated projection can represent
the intended supervision path:

```text
q_phi(z_k,T_slew,tau_AI) -> candidate band
r_hat(z_k,T_slew,tau_AI,recent_event_state) -> risk vector
T_slew,plant = Proj_{B_epsilon^sw}(candidate; T_dense,r_hat)
```

Across the current local contexts, dense fallback mean regret is
`1.116`, the folded prior mean regret is `0.020`, and the
R037 representative projection mean regret is `0.000`.  These values
should be read as local derived-model consistency checks, not as independent
generalization proof.  The important contribution is conceptual and
methodological: PIS-IEK turns non-smooth skip/settling/phase phenomena into
explicit risk labels and a minimal validation plan, so an AI supervisor can be
trained to propose candidates while a switching-calibrated projection layer
protects the IQCOT inner loop.
