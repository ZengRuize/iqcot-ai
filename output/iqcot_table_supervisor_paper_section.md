### Table-in-loop supervisor validation design

To connect the reference-slew sweep with the FPGA-delay argument, a
table-driven supervisory layer was formulated before training a neural
network.  The validation matrix contains `75` planned cases: three
cut-load depths, five latency contexts, and five policies.  Fixed `40 us` and
`80 us` baselines are treated as precommitted references, while table-driven
policies start the reference transition at `t_load_step + tau_AI` to emulate
parameter computation and commit delay.  Under the zero-delay reference
ordering inherited from the dense+long Simulink sweep, the base-score table
selects `80/80/60 us` and reaches mean base score
`9.299`, whereas the settling-aware
`alpha=0.05` table selects `30/50/60 us` and reaches mean
`score+0.05*T_settle` of `10.356`.
The next validation step is therefore not to claim a globally optimal
`T_slew`, but to test whether this ordering is preserved when the selected
reference profile is committed after `0.5-5 us` of equivalent FPGA delay in the
derived switching model.
