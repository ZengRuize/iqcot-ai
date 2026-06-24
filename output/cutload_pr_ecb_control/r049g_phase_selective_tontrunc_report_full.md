# R049G PR-ECB Phase-Selective Ton-Truncation Chunk

Run label: `full`

## Scope and hypothesis

- Model version: R049G copy of R049F with repaired `t_load_step` lower bound and per-phase `early_window AND qh_i` guards.
- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.
- A2 phase-selective trigger: `Tton_trunc_min=5ns`, `Tton_trunc_window=80ns`.
- A0 baseline: same model, negative time window disables truncation.
- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.

## Outputs

- Model: `E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc.slx`
- Results: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049g_phase_selective_tontrunc_results_full.csv`
- Comparison: `E:\Desktop\codex\output\cutload_pr_ecb_control\r049g_phase_selective_tontrunc_comparison_full.csv`
- Wave snapshots: `output/data/*_r049g_phase_selective_tontrunc_wave.csv`

## Per-case results

| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | tr1 us | tr2 us | tr3 us | tr4 us | undershoot mV | final mV |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| r049g_20A_off0p050_a0 | A0_no_trunc | 0.050 | 2.1103 | 9.4540 | 52.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8909 | -0.4397 |
| r049g_20A_off0p050_a2_phase_select | A2_phase_selective_ton_trunc | 0.050 | 2.3879 | 0.8980 | 2.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0040 | -0.8562 | -0.4351 |
| r049g_20A_off0p105_a0 | A0_no_trunc | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8991 | -0.4344 |
| r049g_20A_off0p105_a2_phase_select | A2_phase_selective_ton_trunc | 0.105 | 2.0936 | 8.3890 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | -0.8991 | -0.4344 |

## A2 versus A0 comparison

| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 tr1 us | A2 tr2 us | A2 tr3 us | A2 tr4 us | A2-A0 undershoot mV | A2-A0 final mV |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0.050 | 2.1103 | 2.3879 | -0.2776 | 50.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0040 | 0.0348 | 0.0046 |
| 0.105 | 2.0936 | 2.0936 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 | 0.0000 |

## Diagnosis

R049G also repaired a latent timing-wiring issue exposed by R049F: the
`R049C_After_LoadStep` lower-bound input was unconnected in the inherited
derived model, so removing the over-voltage gate in R049F made the early window
start at simulation time zero.  The repaired R049G copy explicitly connects
`R049G_LoadStep_Time = t_load_step` into `R049C_After_LoadStep/2`.

After this repair, A2 no longer collapses before the load step: all four rows
have `vout0` near `0.9995 V`.  The phase-selective guard is therefore a valid
diagnostic of the intended action, not the earlier startup artifact.

At the active-HS offset `0.05us`, A2 does affect only the active phase: phase-4
remaining Ton falls from about `52ns` to about `2ns`, with only a `0.004us`
phase-4 truncation duration and no phase-1/2/3 truncation.  However, this action
does not improve the first-peak metric.  It shifts the dominant positive peak
earlier and makes it larger:

| Window after load step | A0 max | A2 max |
|---|---:|---:|
| `0-2us` | `2.0977mV @ 0.484us` | `2.3879mV @ 0.898us` |
| `2-12us` | `2.1103mV @ 9.454us` | `2.1580mV @ 7.602us` |
| `12-80us` | `1.9392mV` | `2.0258mV` |

At the post-turnoff offset `0.105us`, A2 remains effectively identical to A0,
consistent with no active high-side Ton remaining to remove.

Thus R049G rejects the simple assumption that an early active-HS-only Ton-min
cut is automatically a useful PR-ECB action.  The model needs a revised action
or metric split that distinguishes immediate local spike risk from later
recovery-peak risk.

## Decision

```text
MODEL_REVISED
```

This decision applies only to this R049G phase-selective diagnostic chunk.
