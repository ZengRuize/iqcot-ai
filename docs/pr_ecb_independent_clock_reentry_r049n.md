# R049N PR-ECB Independent-Clock One-Shot Reentry Audit

Date: 2026-06-25

## Scope

R049N tests the next design class identified by R049M: an upstream independent
phase-clock / predicted-slot release trigger for PR-ECB request-path controlled
reentry.

The derived model is:

```text
output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx
```

The source is the repaired R049L derived model.  R049N removes the downstream
`qh1` release dependency and adds:

```text
release_clock = t >= t_load_step + 1.685 us
one_shot_done = first release_clock event during inhibit_raw
allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
```

The release clock is generated outside the request / scheduler path, so it can
continue to evolve while request inhibition is active.  Ton truncation remains
disabled in A0 and A2.

## Quality gates

The repaired A0 baseline remains aligned with R049K / R049L repair:

| Offset | t_load_step | A0 peak | qh4 at step | remaining Ton4 | Gate |
|---:|---:|---:|---:|---:|---|
| `0.050 us` | `450.050 us` | `2.1103 mV` | `1` | `50.5 ns` | pass |
| `0.105 us` | `450.105 us` | `2.0936 mV` | `0` | `0.0 ns` | pass |

The independent release clock and one-shot state both fired in A2:

| Offset | release_clock | one_shot_done | raw inhibit | effective inhibit |
|---:|---:|---:|---:|---:|
| `0.050 us` | `1.686 us` | `1.750 us` | `1.690 us` | `1.680 us` |
| `0.105 us` | `1.685 us` | `1.735 us` | `1.690 us` | `1.664 us` |

The active high-side pulse was not truncated: Ton truncation stayed disabled,
and remaining Ton4 stayed `50.5 ns` for the active-HS row.

## Results

Global peak metrics show that the independent-clock release has a measurable
effect:

| Offset | A0 peak | A2 peak | Peak improvement | A2 undershoot change |
|---:|---:|---:|---:|---:|
| `0.050 us` | `2.1103 mV` | `2.0977 mV` | `0.0126 mV` | `-0.0714 mV` |
| `0.105 us` | `2.0936 mV` | `2.0241 mV` | `0.0694 mV` | `-0.0303 mV` |

The R049H three-window audit is stricter and shows the main trade-off:

| Offset | Window | Peak improvement | Undershoot change | Interpretation |
|---:|---|---:|---:|---|
| `0.050 us` | early local peak | `0.0000 mV` | `-0.2559 mV` | no early benefit |
| `0.050 us` | recovery peak | `+0.1127 mV` | `-0.5597 mV` | recovery peak improves but undershoot worsens |
| `0.050 us` | late settling | `-0.0696 mV` | `-0.0084 mV` | late positive peak penalty |
| `0.105 us` | early local peak | `0.0000 mV` | `-0.5775 mV` | no early benefit |
| `0.105 us` | recovery peak | `+0.1205 mV` | `-1.4429 mV` | strong undershoot penalty |
| `0.105 us` | late settling | `-0.0148 mV` | `-0.0303 mV` | small late peak penalty |

## Decision

```text
MODEL_REVISED
```

R049N confirms the implementation interface: an upstream independent-clock /
predicted-slot release can fire during request inhibition and avoids the R049L
downstream-`qh1` circular dependency.  It does not confirm the controller
performance.  A fixed `1.685 us` release still behaves like a hard recovery
gate: it improves recovery positive peaks but introduces significant undershoot
penalties under the three-window metric gate.

## Evidence files

- `output/iqcot_r049n_build_independent_clock_reentry_model.m`
- `output/iqcot_r049n_pr_ecb_independent_clock_reentry_chunk.m`
- `output/iqcot_r049n_waveform_metric_audit.py`
- `output/cutload_pr_ecb_control/four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry.slx`
- `output/cutload_pr_ecb_control/r049n_independent_clock_reentry_results_full.csv`
- `output/cutload_pr_ecb_control/r049n_independent_clock_reentry_comparison_full.csv`
- `output/cutload_pr_ecb_control/r049n_independent_clock_reentry_report_full.md`
- `output/cutload_pr_ecb_control/r049n_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049n_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049n_waveform_metric_summary.md`
- `output/data/*_r049n_independent_clock_reentry_wave.csv`

## Next step

Do not promote the fixed `1.685 us` independent-clock release as confirmed
PR-ECB behavior.  The next minimal step should keep the upstream release
interface but reduce the hard-inhibit recovery penalty, for example by auditing
one or two earlier release delays or a softened reentry gate under the same
four-row R049H windowed metric gate.

## Claim boundary

R049N is derived-Simulink switching evidence only.  It is not hardware/HIL
validation, not a complete PR-ECB controller, and not proof that an independent
phase clock is the final release mechanism.
