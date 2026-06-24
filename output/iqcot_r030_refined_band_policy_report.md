# R030 refined band policy synthesis

## Scope

R030 is a post-processing and validation-design step.  It does not modify any
original `.slx` file, does not edit `.slx` XML, and does not claim hardware or
neural-network AI-in-loop validation.  The goal is to convert R029 held-out
guard evidence into a more careful band policy and to choose the next derived
Simulink challenge points.

## Refined policy

The R030 representative rule is:

- `10A / score_settle005`: use dense-anchor at `tau_AI <= 1us`; use `40us`
  around the measured `1.5us` transition; use the short-slew edge `34us` for
  `tau_AI >= 2us`.
- `near0A / score_settle010`: replace the fixed `35us` guard with a
  `30-38us` local band; use `38us` for `tau_AI < 0.5us` and `30us` from
  `0.5us` upward in the current representative table.
- All other contexts fall back to the R028 dense-anchor projection.

This is intentionally written as a local band/projection rule, not as a global
optimum for `T_slew`.

## Offline consistency replay

The offline replay uses the completed dense+long+fine grid and should be read
only as a consistency check.  It cannot replace switching-level delayed
reference validation.

| policy | contexts | mean regret | max regret |
| --- | ---: | ---: | ---: |
| R030 refined band | 45 | 0.104 | 0.235 |
| R028 guarded candidate | 45 | 0.106 | 0.235 |
| R028 dense-anchor | 45 | 0.099 | 0.235 |

R030 is essentially tied with the old stress-fitted guarded rule in pure
offline replay and remains slightly worse than dense-anchor on that static
grid because it deliberately rejects the fixed near0A `35us` point and uses
R029 held-out switching evidence instead.  This is a feature of the claim
boundary, not a failure of the policy.

## Switching evidence synthesis

Combining R027 priority replay and R029 held-out rows gives
`12` known guard-context entries.  The R030-selected rows have
mean switching regret `0.000` over
these known contexts, while the corresponding dense-anchor rows have mean
regret `0.128`.  This is not an
independent proof because the rule was synthesized from these local findings,
but it is a useful consistency check:

- the old `62us` proxy action remains excluded for `10A / score_settle005`;
- the short `34us` guard is retained only at and above the `2us` delay region;
- near0A uses a `30-38us` band rather than a fixed `35us` point.

## Dense-anchor challenge plan

R027 had `315` planned rows but only `48` priority rows were switched.  R030
finds `24` non-priority contexts where calibrated proxy and
dense table select different `T_slew` values; `20` of them
look better for proxy in the offline score.  The next compact challenge plan
contains `30` rows, paired by dense/proxy policy, and is
written to:

```text
E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv
```

The executable entry point is:

```matlab
iqcot_r030_dense_anchor_challenge_validation(false)      % dry run
iqcot_r030_dense_anchor_challenge_validation(true)       % run all 30 rows
iqcot_r030_dense_anchor_challenge_validation(true,10,11) % chunked run
```

The main motifs are:

- `10A / score_settle010`: dense `30us` vs proxy `32us`, proxy offline
  advantage about `0.490` score points.
- `20A / base`: dense `80us` vs proxy `86us`, proxy offline advantage about
  `0.140` score points.
- `20A / score_settle005`: dense `30us` vs proxy `66us`, proxy offline
  advantage about `0.095` score points, but with a much longer slew, so it
  deserves switching validation before any deployment claim.

## Boundary

- AI remains a supervisory scheduler for low-dimensional parameters such as
  `T_slew`; IQCOT remains the inner loop.
- The R030 band is derived Simulink evidence plus offline post-processing, not
  hardware/HIL validation.
- R030 does not claim that `34us`, `38us`, or any single `T_slew` is globally
  optimal.
- The challenge plan is a future experiment design, not a result.
