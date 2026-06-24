# R049H PR-ECB Waveform Metric Audit

Date: 2026-06-24

## Scope

R049H is an offline audit only.  It does not run new Simulink switching
simulations and does not modify any `.slx` model.  It reuses the existing wave
CSV exports from:

```text
R049C: near0 command-path Ton truncation
R049D: 10A hold-out command-path Ton truncation
R049E: 20A over-voltage-triggered mild hold-out
R049F: early Ton-truncation timing diagnostic, now treated as timing artifact
R049G: repaired phase-selective early Ton-truncation diagnostic
```

The audit script is:

```text
output/iqcot_r049h_waveform_metric_audit.py
```

Outputs:

- `output/cutload_pr_ecb_control/r049h_waveform_metric_case_windows.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_pair_delta.csv`
- `output/cutload_pr_ecb_control/r049h_waveform_metric_summary.md`

## Window definition

R049H splits the cut-load response into three windows after the load step:

| Window | Range | Meaning |
|---|---:|---|
| early local peak | `0-2 us` | immediate switching / active-HS interaction |
| recovery peak | `2-12 us` | post-event recovery peak |
| late settling / undershoot | `12-80 us` | late residual peak and undershoot |

This split is necessary because R049G showed that a single first-peak metric can
hide a trade: hard active-HS Ton-min truncation removes remaining Ton but moves
or amplifies an earlier local voltage spike.

## Active-HS results

| Chunk | Early peak improvement | Recovery peak improvement | Late peak improvement | Early undershoot change | Late undershoot change |
|---|---:|---:|---:|---:|---:|
| R049C near0 | `+0.7660 mV` | `+1.0047 mV` | `-0.4480 mV` | `+0.0000 mV` | `+2.7395 mV` |
| R049D 10A | `+0.6036 mV` | `-0.0323 mV` | `-0.0045 mV` | `-0.7576 mV` | `-0.0901 mV` |
| R049E 20A OV-triggered | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| R049G 20A repaired phase-selective | `-0.2902 mV` | `-0.0476 mV` | `-0.0866 mV` | `+0.4725 mV` | `+0.0348 mV` |

Positive peak improvement means A2 reduced the positive peak relative to A0.
Positive undershoot change means the A2 minimum is less negative than A0.

## Diagnosis

R049H revises the Ton-truncation evidence hierarchy:

1. R049C supports a broad near0 active-HS benefit: command-path Ton truncation
   improves both early local and recovery peak windows.
2. R049D is still a useful `10A` hold-out, but its support is narrower than the
   earlier single-peak wording: the main benefit is the `0-2 us` early local
   peak.  Recovery and late positive peaks are effectively unchanged or
   slightly worse.
3. R049E confirms that the over-voltage-triggered command-path action is too
   late for the mild `40A -> 20A` active-HS case.
4. R049G is the repaired mild-load diagnostic: phase-selective hard Ton-min
   truncation is structurally effective at removing remaining Ton, but worsens
   the early local peak and slightly worsens recovery/late peak windows.
5. R049F is a timing-artifact reference, not controller evidence.  Its A2 rows
   begin around `-1117 mV` relative to regulation because the early-window
   lower bound was unconnected before R049G repaired it.

## Revised action model

```text
R049C near0:
    command-path Ton truncation remains a useful active-HS action.

R049D 10A:
    command-path Ton truncation is confirmed mainly for early-local-peak
    reduction, not as a broad recovery-window improvement.

R049E 20A:
    over-voltage-triggered Ton truncation is too late.

R049G 20A:
    repaired phase-selective hard Ton-min truncation removes remaining Ton but
    worsens early/recovery positive peak metrics.
```

Therefore PR-ECB must keep three separate response metrics:

```text
J_early_peak    = max(Vout - Vref) over 0-2 us
J_recovery_peak = max(Vout - Vref) over 2-12 us
J_late_min      = min(Vout - Vref) over 12-80 us
```

Hard active-HS Ton-min truncation is not a confirmed mild-load PR-ECB action.

## Decision

```text
MODEL_REVISED
```

## Next validation

R049I should run one minimal repaired-model action chunk, not a full matrix.  A
reasonable next candidate is a gentler phase-selective Ton trim on the same
`40A -> 20A` two-offset setup, using the same three-window metrics.

Before choosing a numeric Ton floor, R049I should inspect the baseline Ton traces
from R049G and document the proposed floor.  A first candidate range is
`80-120 ns`, rather than hard `5 ns`.  If the early local peak remains worse,
stop Ton-min variants and switch to deferred post-active pulse inhibit or
controlled reentry.

## Claim boundary

R049H is offline derived-Simulink waveform evidence only.  It is not
hardware/HIL validation, not global PR-ECB calibration, not proof of complete
PR-ECB control, not proof that AI replaces IQCOT, and not a universal additive
`E_HS,rem` law.
