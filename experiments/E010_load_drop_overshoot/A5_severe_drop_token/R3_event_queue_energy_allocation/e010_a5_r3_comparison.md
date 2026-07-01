# E010-A5-R3 Comparison

Date: 2026-07-01

## Scope

Fixed `40A -> 1A` severe load drop; no active Lambda, active-phase add/shed, DCR mismatch, current-sense mismatch, or broad sweep.

| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | Final err mV | Burst | Queue max/final | Deferred/Rejected/Dropped | Budget used ns | Guard | Hint |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| R3-C0 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | NaN/NaN | 0/0/0 | NaN | 1 | REFERENCE |
| R3-C4 | 1 | 4.06085 | 0 | 3.61172 | 3.59863 | 2.97793 | NaN/NaN | NaN/NaN | 0/0/0 | NaN | 1 | REFERENCE |
| R3-T4proxy | 1 | 4.06085 | 0.697797 | 3.55696 | 3.5337 | 2.96743 | 5/2 | NaN/NaN | 0/0/0 | NaN | 0 | MODEL_REVISED |
| R3-R2E1 | 1 | 3.51629 | 7.63188 | 1.75366 | 3.51629 | 2.89307 | 5/2 | NaN/NaN | 0/0/0 | 74.6 | 0 | MODEL_REVISED |
| R3-E1 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |
| R3-E2 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |
| R3-E3 | 1 | 0 | 971.618 | 0 | 0 | -919.625 | 5/2 | 0/0 | 0/0/0 | 60 | 0 | MODEL_REVISED |

## Classification

`MODEL_REVISED`

R3 suppresses positive recovery peaks only by starving the recovery trajectory, producing severe undershoot/final-error collapse and failing burst/phase-order guards. Treat this as token-structure revision evidence, not as A5 validation.

Best partial variant: `none_safe_candidate`. R3-E1/E2/E3 share the same recovery-starvation failure mechanism, so no R3 candidate should be carried forward as a validated partial selector.

## Mechanism Interpretation

- `R3-E1`: tests whether event queue plus per-event Ton allocation alone can retain R2-E1 recovery benefit without unsafe undershoot or burst.
- `R3-E2`: adds queue release spacing and max-per-window control to test burst control through allocation rather than hard blocking.
- `R3-E3`: adds area-int queue coupling as a release guard; if behavior is unchanged, the coupling is not yet a validated actuator.
- `R3-E4`: not run; E3 was not close to passing and did not isolate voltage-window release as the missing guard.

Metrics: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_metrics.csv`

Availability: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_signal_availability.csv`

Scheduler audit: `E:/Desktop/codex/experiments/E010_load_drop_overshoot/A5_severe_drop_token/R3_event_queue_energy_allocation/e010_a5_r3_scheduler_audit.csv`
