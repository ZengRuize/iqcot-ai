# E010-A5-R2 Comparison

Date: 2026-07-01

## Scope

Fixed `40A -> 1A` severe load drop; no active Lambda, active-phase add/shed, DCR mismatch, current-sense mismatch, or broad sweep.

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | Final err mV | Burst | Dropped REQ | Phase err | Energy used ns | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R2-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | 0 | NaN | NaN | 1 | REFERENCE |
| R2-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | 0 | NaN | NaN | 1 | REFERENCE |
| R2-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 2.96743 | 5/2 | 0 | NaN | NaN | 0 | MODEL_REVISED |
| R2-R1bad | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | NaN | NaN | 0 | MODEL_REVISED |
| R2-E1 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E2 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E3 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |
| R2-E4 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0 | 0 | 74.6 | 0 | MODEL_REVISED |

## Classification

`MODEL_REVISED`

R2-E1/E2 reduce the positive recovery peaks but violate the undershoot and burst guards. R2-E3/E4 suppress positive peaks only by scheduler-release starvation, reproducing the R1-like severe undershoot and final-error collapse. A5 remains MODEL_REVISED.

Best partial variant: `R2-E1`.

## Mechanism Interpretation

- `R2-E1`: energy budget plus Ton ramp gives the best partial waveform benefit, but peak undershoot is above the 2 mV guard and burst count remains `5 / 2`.
- `R2-E2`: soft area preload is observable but does not change the waveform versus E1 in this implementation.
- `R2-E3`: scheduler release gating is too hard or inserted at the wrong event boundary; it starves recovery energy and reproduces R1-like collapse.
- `R2-E4`: enabling voltage-window release on top of E3 does not rescue the current release semantics, so the next revision must restructure scheduler release rather than tune this token into a pass.

Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_metrics.csv`

Availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_signal_availability.csv`

Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R2_reentry_energy_shaping/e010_a5_r2_scheduler_audit.csv`
