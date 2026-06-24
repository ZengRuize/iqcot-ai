# Local Audit: R021 Table-Supervisor Delay Sensitivity

## Checks

- `tau_AI=0.5/1/2 us` result rows: `45`
- `tau_AI=0.5/1/2 us` successful rows: `45`
- Existing `tau_AI=5 us` result rows: `15`
- Existing `tau_AI=5 us` successful rows: `15`
- Total positive-delay switching rows: `60`
- Best-by-tau rows: `15`

## Key Consistency

- Base objective best policies:
  - `0 us`: `oracle_base_table`
  - `0.5 us`: `oracle_base_table`
  - `1 us`: `oracle_base_table`
  - `2 us`: `table_settle005`
  - `5 us`: `table_settle005`
- The result is not monotonic in delay for all objectives, so the paper was
  updated to say "objective and delay jointly sensitive" rather than "delay
  monotonically changes the best T_slew."

## Static Check

`check_matlab_code` reports only an informational dynamic-array growth note in
policy summary construction after replacing the `numel()==1` check with
`isscalar`.

## Claim Boundary Review

Updated paper, evidence matrix, derivation package, and validation design were
searched for risky phrases.  Matches related to global optimality, hardware
proof, or AI replacing IQCOT appear only in forbidden/boundary contexts.

## Pass Criteria

PASS.

Allowed claim:

> Table-driven delayed-reference validation over `tau_AI=0.5/1/2/5 us` supports
> treating `T_slew` as a target- and delay-sensitive supervisory scheduling
> variable.

Forbidden claim:

- Neural-network AI-in-loop has been validated.
- Hardware improvement has been proven.
- `T_slew` has a global optimum.
- AI replaces the IQCOT inner loop.
