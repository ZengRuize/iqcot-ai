### R036 dense-paired boundary validation

R035 left two folded-band delays in a candidate-only state because the `30us`
dense fallback had not yet been co-tested at the same AI commit delay.  R036
therefore executed two additional derived-Simulink delayed-reference cases for
`20A/score+0.05T_settle`: `tau_AI=1.25us, T_slew=30us` and
`tau_AI=1.75us, T_slew=30us`.  In the paired comparison, the dense fallback
scores are `4.989` and
`4.317`, while the corresponding folded probes
`46us` and `54us` score `2.146` and
`2.142`.  The improvement is accompanied by
removing one estimated skip and reducing phase-spacing dispersion in both
contexts.

This result upgrades `46us` at `tau_AI=1.25us` and `54us` at
`tau_AI=1.75us` from pending folded probes to locally dense-paired candidates
for the current four-phase derived model and objective.  The claim remains
bounded: R036 is not hardware/HIL validation, does not imply a global
`T_slew` optimum, and does not make the AI supervisor a replacement for the
IQCOT inner event loop.  Its role is to calibrate the
`q_phi/r_hat/B_epsilon^sw` supervision path by showing where the dense fallback
is genuinely too conservative and where it must remain active.
