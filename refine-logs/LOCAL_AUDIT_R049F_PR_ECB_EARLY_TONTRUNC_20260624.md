# LOCAL AUDIT R049F PR-ECB Early Ton-Truncation Trigger Timing

Date: 2026-06-24

## Scope

R049F diagnoses trigger timing on the same mild chunk that caused the R049E
claim downgrade:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 load-step-synchronous early Ton truncation
```

The new model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049f_early_tontrunc.slx
```

It was created by copying the completed R049E model through
`output/iqcot_r049f_build_early_tontrunc_model.m`.  The builder reconfigured
`R049C_TonTrunc_Global` from a three-input after/before/over-voltage AND into a
two-input after/before time-window AND.  No original or completed older `.slx`
model was intentionally modified.

## Validation

Key outputs:

- `output/cutload_pr_ecb_control/r049f_early_tontrunc_results_full.csv`
- `output/cutload_pr_ecb_control/r049f_early_tontrunc_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049f_early_tontrunc_report_full.md`
- `output/data/*_r049f_early_tontrunc_wave.csv`

Non-simulation preflight passed:

```text
UPDATE_DIAGRAM_OK model=four_phase_iek_pr_ecb_control_r049f_early_tontrunc R049F_early_trigger
```

## Results

| Offset | A0 peak | A2 peak metric | A0 rem Ton4 | A2 rem Ton4 | A2 trunc | A2 final error |
|---:|---:|---:|---:|---:|---:|---:|
| `0.05 us` | `2.1103 mV` | `-184.1030 mV` | `52 ns` | `0 ns` | `80 ns` | `-239.1723 mV` |
| `0.105 us` | `2.0936 mV` | `-189.3089 mV` | `0 ns` | `0 ns` | `80 ns` | `-241.9473 mV` |

## Diagnosis

The early trigger confirms that Ton-command truncation can remove the mild-load
active high-side remaining on-time when asserted early enough: the `0.05 us`
row changes phase-4 remaining Ton from about `52 ns` to `0 ns`.

However, the global all-phase early Ton-min action is unsafe in this derived
model.  Both offsets show a large negative voltage excursion and large final
error.  Thus the model should be revised from a global early Ton-min action to
a phase-selective / active-HS-only action before any further claim expansion.

## Decision

```text
MODEL_REVISED
```

## Next Step

R049G should use the same `40A -> 20A` two-offset chunk but apply early
truncation only to the currently active high-side phase, e.g.
`early_window AND qh_i`, or an equivalent phase-selective guard.  Do not expand
to a full A matrix.

## Claim Boundary

R049F is derived-Simulink evidence only.  It is not hardware/HIL validation, not
a complete PR-ECB controller, not global calibration, and not a universal
additive `E_HS,rem` law.

## R049G Erratum

R049G later found that the inherited `R049C_After_LoadStep` block had input 2
unconnected.  Once R049F removed the over-voltage gate, the intended early
window therefore began at simulation time zero rather than at `t_load_step`.
The severe R049F undervoltage should be treated as an implementation-timing
artifact of that diagnostic wiring.  R049G repairs the lower bound in a new
derived copy and supersedes the R049F action interpretation.
