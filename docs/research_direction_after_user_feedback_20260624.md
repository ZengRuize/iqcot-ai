# R046 Research Direction Revision After User Feedback

Date: 2026-06-24

Reference input:

- `C:/Users/zengruize/Downloads/iqcot_research_direction_guidance_after_repo_review.md`

## Executive Decision

The research direction should be corrected from an AI/`T_slew`-centered
supervisory scheduling story to a power-control-centered story:

```text
PR-ECB large-signal cut-load voltage stabilization
+ PIS-IEK small-signal steady-state current sharing
+ variable-phase add/shed hybrid event management
```

The existing `T_slew` and AI-delay results remain useful as historical and
future-extension evidence, but they should no longer be the main control
objective or the main manuscript claim.

## Why `T_slew` Must Be Downgraded

The load-current transition rate is imposed by the external load. A VRM
controller cannot choose the real CPU/GPU/FPGA load-current slew rate:

```text
dI_load/dt is an external disturbance, not a controlled plant input.
```

The controller can only decide how it responds after detecting or estimating
the load change. Therefore `T_slew` should not be described as controlling the
load-current transition. In the existing work, it is more accurately an internal
reference-recovery or supervisory candidate parameter. It may still be useful
after the first peak, during controlled reentry and soft recovery, but it is not
the right main contribution for the present paper.

Allowed wording:

- "`T_slew` is a possible post-peak reference-recovery parameter."
- "AI or table supervision may tune low-dimensional recovery parameters in a
  future layer."

Disallowed wording:

- "`T_slew` controls the load-current slew rate."
- "`T_slew` is the main cut-load control variable."
- "`T_slew` has a global optimum."

## Revised Engineering Objective

The project should be framed around two primary converter objectives:

1. During cut-load transients, keep output voltage within the overshoot
   specification.
2. During steady state, achieve phase-current sharing while preserving phase
   spacing and ripple cancellation.

These are different physical regimes and should not be collapsed into one
small-signal model.

## Layered Control Architecture

### Layer 0: Original IQCOT Inner Loop

Keep the IQCOT area-event inner loop as the fast deterministic control core:

```math
\int_{a_k}^{t_{k+1}} [v_c(t)-R_i i_L(t)]dt=\Lambda .
```

The AI or any slow supervisory logic must not replace per-pulse gate command
generation.

### Layer 1: PR-ECB Large-Signal Cut-Load Protection

PR-ECB should be promoted from an offline risk metric into a design guide for
large-signal cut-load protection. It estimates first-peak risk from phase
current, active high-side state, output capacitance, ESR, inductance, load-drop
magnitude, and remaining high-side on-time class.

Recommended actions by risk class:

| Risk class | Typical condition | Candidate action |
|---|---|---|
| low | first-peak bound far below allowance | normal IQCOT |
| medium | bound near allowance, no active-HS hazard | allow skip, monitor reentry |
| high | large drop, active-HS state, or bound near/exceeding allowance | Ton truncation, pulse inhibit, integrator hold/reset |

Important boundary:

`E_HS,rem` is an active-HS segmentation feature. It must not be claimed as a
globally valid additive energy law.

### Layer 2: PIS-IEK Small-Signal Current Sharing

PIS-IEK should be framed as the steady-state and post-reentry small-signal
model for actuator classification:

```text
Ton_diff    -> dominant DC current-sharing actuator
Lambda_diff -> phase-spacing / ripple-cancellation actuator
delay_diff  -> timing and phase-jitter disturbance
```

The next validation should move from "does the model fit?" toward "does a
PIS-IEK-guided controller improve current sharing without damaging phase
spacing?"

### Layer 3: Variable-Phase Add/Shed Hybrid Event Management

Add/shed phase logic is an important next research direction because it connects
the model to wide-load-range VRM efficiency and thermal management. Introduce an
active phase set:

```math
\mathcal{A}\subseteq \{1,2,3,4\}
```

and extend PIS-IEK from:

```math
x_{k+1}=F_{p_k}(x_k,u_k,T_k)
```

to:

```math
x_{k+1}=F_{p_k,\mathcal{A}}(x_k,u_k,T_k).
```

The nominal phase spacing changes with active phase count:

| Active phases | Nominal spacing |
|---:|---:|
| 1 | none |
| 2 | 180 degrees |
| 4 | 90 degrees |

Phase shedding must be disabled during cut-load protection. The correct order
is:

```text
cut-load protection -> controlled reentry -> balance recovery -> phase-shed decision
```

not immediate shedding during the first peak.

## Revised Control State Machine

The next Simulink control design should use an explicit state machine:

| State | Purpose | Main outputs |
|---|---|---|
| `NORMAL_IQCOT` | ordinary IQCOT area-event operation | normal `REQ`, `Ton`, phase scheduler |
| `CUT_LOAD_PROTECT` | suppress first over-voltage peak | `ton_truncate`, `pulse_inhibit`, integrator hold/reset |
| `SKIP_HOLD` | allow inductor current to decay | skip permission, high-side inhibit |
| `REENTRY` | restore phase sequence after voltage returns to band | phase-index recovery, integrator reset policy |
| `BALANCE_RECOVERY` | restore steady-state current sharing | `Ton_diff` balance trim, `Lambda_diff` phase trim |
| `PHASE_ADD_PENDING` | safely add phases under load rise or undervoltage risk | active-set expansion |
| `PHASE_SHED_PENDING` | conservatively shed phases at light load | active-set reduction after dwell and balance checks |

## Revised Validation Matrix

### A. Cut-Load Voltage Stabilization

Question: Does model-guided cut-load protection reduce overshoot relative to
original IQCOT?

Compare:

| Case | Controller |
|---|---|
| A0 | original IQCOT |
| A1 | IQCOT + simple over-voltage skip |
| A2 | IQCOT + PR-ECB risk class + Ton truncation |
| A3 | IQCOT + PR-ECB + Ton truncation + pulse inhibit + controlled reentry |

Load steps:

- `40A -> 20A`
- `40A -> 10A`
- `40A -> 5A`
- `40A -> near0A`

Offsets:

- `0`, `0.05`, `0.09`, `0.105`, `0.125`, `0.20`, `0.25`, `0.375 us`

Metrics:

- peak overshoot
- first-peak time
- active-HS state at step
- truncated Ton count
- pulse-inhibit duration
- skip count
- reentry time
- secondary oscillation
- final steady-state error

### B. Steady-State Current Sharing

Question: Does PIS-IEK-guided actuator selection improve current sharing while
respecting phase spacing?

Compare:

| Case | Controller |
|---|---|
| B0 | original IQCOT |
| B1 | `Lambda_diff` only |
| B2 | `Ton_diff` only |
| B3 | `Ton_diff` balance + `Lambda_diff` phase-spacing trim |
| B4 | empirical gain control |
| B5 | PIS-IEK-guided limited control |

Mismatch cases:

- DCR mismatch: `±5%`, `±10%`
- inductance mismatch: `±5%`
- MOSFET `Ron` mismatch: `±5%`, `±10%`
- current-sense gain mismatch: `±2%`, `±5%`
- driver delay mismatch: `±5 ns`, `±10 ns`
- load: `20A`, `30A`, `40A`, `50A`

Metrics:

- max current imbalance
- RMS current imbalance
- balance settling time
- phase-spacing standard deviation
- output ripple
- effective switching frequency
- trim usage

### C. Model-Ablation Study

Question: What is the control value of introducing the large-signal and
small-signal models?

Compare:

| Case | Meaning |
|---|---|
| C0 | original IQCOT |
| C1 | empirical control without models |
| C2 | PIS-IEK only |
| C3 | PR-ECB only |
| C4 | PR-ECB + PIS-IEK coordinated control |

Expected claim boundary:

PIS-IEK should improve steady-state balance and phase recovery; PR-ECB should
improve cut-load first-peak protection. The combined case should be best across
both objectives, but this must be proven by simulation rather than asserted.

### D. Phase Add/Shed Validation

Question: Can variable active phase count be added without destabilizing
cut-load protection, reentry, or current sharing?

Compare:

| Case | Controller |
|---|---|
| D0 | fixed four-phase original IQCOT |
| D1 | fixed four-phase + PR-ECB |
| D2 | fixed four-phase + PIS-IEK balance |
| D3 | basic `1/2/4` phase add/shed |
| D4 | add/shed + PR-ECB cut-load protection |
| D5 | add/shed + PR-ECB + PIS-IEK recovery |

Scenarios:

- `0A -> 10A`
- `10A -> 40A`
- `40A -> 10A`
- `40A -> near0A`
- slow `0A -> 50A -> 0A`
- repeated `10A <-> 40A`

Metrics:

- active phase timeline
- add-phase time
- shed-phase time
- add-phase undershoot
- shed-phase overshoot
- disabled-phase residual current
- new-phase current ramp
- phase-spacing recovery time
- switching-count or efficiency proxy

## Simulink Implementation Requirements

Do not edit raw `.slx` XML. Build derived models or modify copies through
MATLAB APIs.

The next derived model should expose and log:

- `Vout`
- `Iload` or estimated load current
- `IL1..IL4`
- `QH1..QH4`, `QL1..QL4`
- `REQ1..REQ4`
- `phase_idx`
- active phase set
- `Ton_cmd_i` and actual high-side pulse width
- `Lambda_i`
- area integrator state
- `skip_flag`
- `reentry_flag`
- `protect_state`
- phase-spacing measurements

Recommended modules:

| Module | Responsibility |
|---|---|
| `PR_ECB_Risk_Estimator` | first-peak risk and bound-family classification |
| `Cut_Load_Protector` | Ton truncation, pulse inhibit, integrator hold/reset |
| `PIS_IEK_Balancer` | `Ton_diff` balance and `Lambda_diff` phase-spacing trim |
| `Phase_Add_Shed_Controller` | active phase set selection with hysteresis and dwell |
| `Reentry_Manager` | safe return from skip/protect states to normal IQCOT |

## Revised Manuscript Direction

Recommended title:

```text
Four-Phase Digital IQCOT Buck Control via Large-Signal Cut-Load Protection,
Small-Signal Current Sharing, and Variable-Phase Hybrid Event Management
```

Chinese title:

```text
四相数字 IQCOT Buck 的大小信号协同控制：
PR-ECB 切载稳压、PIS-IEK 稳态均流与可变相数混合事件管理
```

Recommended section structure:

1. Introduction: cut-load voltage stability, steady-state current sharing, and
   phase add/shed as practical VRM goals.
2. Related work and boundaries: IQCOT, COT sampled-data modeling, multiphase
   COT, DICOT current sharing.
3. PIS-IEK small-signal model for actuator classification.
4. PIS-IEK-guided steady-state current-sharing control.
5. PR-ECB large-signal first-peak risk and cut-load protection.
6. Variable active phase set and hybrid event management.
7. Simulation validation: PR-ECB protection, PIS-IEK balance, model ablation,
   phase add/shed.
8. Limitations and future hardware/HIL validation.

## Four-Week Execution Plan

### Week 1: Direction and Derived-Control Design

- Rewrite project direction documents.
- Draw the new layered architecture: IQCOT inner loop, PR-ECB, PIS-IEK, phase
  add/shed.
- Specify the state machine and logged signals.
- Avoid new claims about AI and `T_slew`.

### Week 2: Cut-Load Protection Validation

- Implement or plan a derived Simulink copy with Ton truncation, pulse inhibit,
  integrator hold/reset, and controlled reentry.
- Run the A-matrix cut-load cases only after confirming model wiring.
- Generate overshoot and reentry metrics.

### Week 3: Current-Sharing Validation

- Implement `Ton_diff` balance trim and `Lambda_diff` phase-spacing trim.
- Run mismatch and load-grid cases.
- Compare original IQCOT, empirical control, and PIS-IEK-guided limited control.

### Week 4: Phase Add/Shed Validation

- Implement active phase set `1/2/4`, hysteresis, and dwell.
- Disable shedding during cut-load protection.
- Validate add/shed transients and balance recovery.

## Safe Claim Set

Allowed:

- PIS-IEK supports event-domain actuator classification and digital budgeting.
- `Ton_diff` is the dominant DC current-sharing actuator, with phase-spacing
  cost.
- `Lambda_diff` is better suited for phase-spacing/ripple-cancellation trim.
- PR-ECB is a derived-Simulink/offline first-peak risk feature.
- Add/shed phase requires active-set hybrid event modeling.

Forbidden:

- PIS-IEK precisely predicts all large-signal first peaks.
- PR-ECB is hardware/HIL validated.
- `E_HS,rem` is a globally additive correction law.
- `T_slew` controls external load-current slew rate.
- AI replaces the IQCOT inner loop or directly produces gate commands.

