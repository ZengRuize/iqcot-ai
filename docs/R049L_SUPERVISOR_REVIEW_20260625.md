# R049L Supervisor Review

Date: 2026-06-25

## Verdict

```text
IMPLEMENTATION_ISSUE
```

The external R049L run cannot be used as PR-ECB scientific evidence.  Its A0
baseline is not comparable with the R049I/R049J/R049K `40A -> 20A` chunk.

## Why the R049L result is invalid

R049L reported `CLAIM_DOWNGRADED`, but the runner changed the simulation
scenario and metric semantics:

| Check | R049K expected baseline | R049L observed baseline | Interpretation |
|---|---:|---:|---|
| `t_load_step_us` at `0.050us` offset | `450.05 us` | `0.05 us` | wrong load-step epoch |
| `vout0` at `0.050us` offset | `0.9995155 V` | `0.9962361 V` | not same pre-step operating point |
| `il1..4` at `0.050us` offset | `7.11/9.82/12.64/12.35 A` | about `-0.194 A` each | plant not settled / wrong start condition |
| `qh4_at_step` at `0.050us` offset | `1` | `0` | not the active-HS boundary row |
| `remaining_ton4_ns` at `0.050us` offset | `52 ns` | `186.5 ns` | metric and/or timing wrong |
| `delta_v_actual_peak_mV` at `0.050us` offset | `2.1103 mV` | `1.2625 mV` | different waveform |

The core implementation errors are:

1. `t_load_step_s` was set to the offset itself (`0.05us` / `0.105us`) instead
   of `0.45ms + offset`.
2. `StopTime` was set around `81us` instead of `t_load_step + 150us`.
3. R049K/R049J operating parameters were not preserved:
   `Lambda_area=6e-10`, `Varea_bias=2e-3`, `Ri_area=0.5e-3`, `tau_ai=1.25us`,
   `selected_ref_slew=60us`, etc.
4. The remaining-on-time metric was changed incorrectly: when `qh_i` is not high
   at the load step, it measured the next future high-side pulse width instead
   of returning `0`.
5. `inhibit_duration_us` measured `inhibit_raw` after one-shot release rather
   than effective gate inhibition (`inhibit_raw AND NOT(one_shot_done)`), so
   the reported `~79.93us` duration is not an effective request block duration.

## Scientific implication

R049L does not downgrade the controlled-reentry concept.  It only shows that
this particular external implementation did not reproduce the required
baseline.  Therefore:

- do not update the main PR-ECB claim set from this R049L result;
- do not treat the all-zero A2-A0 waveform deltas as evidence that one-shot
  reentry is ineffective;
- repair the R049L runner first, then rerun the same one-shot / phase-boundary
  hypothesis under the exact R049K-compatible operating point.

## Next action

Use `docs/R049L_REPAIR_EXTERNAL_MODEL_EXECUTION_PROMPT_20260625.md` as the next
instruction file for the external execution model.
