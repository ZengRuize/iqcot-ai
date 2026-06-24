# Table-Supervisor Delay Sensitivity

## Scope

This report combines the zero-delay reference ordering with derived Simulink
delayed-reference switching runs at `tau_AI=0.5/1/2/5 us`.  The table-driven
supervisor still only schedules `T_slew`; it does not replace the IQCOT inner
loop and is not neural-network AI-in-loop.

## Best Policy By Delay

| tau_AI | best base | best 0.05 | best 0.10 |
|---:|---|---|---|
| `0 us` | `oracle_base_table` (9.299) | `table_settle005` (10.356) | `table_settle010` (11.115) |
| `0.5 us` | `oracle_base_table` (9.133) | `table_settle010` (10.212) | `table_settle010` (10.630) |
| `1 us` | `oracle_base_table` (8.598) | `table_settle010` (9.992) | `table_settle010` (10.404) |
| `2 us` | `table_settle005` (8.104) | `table_settle005` (9.110) | `table_settle005` (10.116) |
| `5 us` | `table_settle005` (8.383) | `table_settle005` (9.657) | `table_settle010` (10.785) |

## Interpretation

The ordering is objective-sensitive across all tested delays.  The base-score
winner shifts from the zero-delay oracle base table to `table_settle005` at
`5 us`, while smaller delayed-reference slices favor `oracle_base_table` for
base score.  The strong settling penalty consistently favors
`table_settle010`.  This is a useful result, not a contradiction: the best
`T_slew` schedule depends jointly on the objective and the parameter-commit
delay.

## Boundary

`tau=0` rows are reference-ordering rows from prior dense+long sweep
post-processing.  `tau>0` rows are derived switching-model delayed-reference
runs.  None of these rows prove hardware performance or neural-network
AI-in-loop superiority.
