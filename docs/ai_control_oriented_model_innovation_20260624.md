# R047 AI-Control-Oriented Large/Small-Signal Model Innovation

Date: 2026-06-24

## Executive Decision

After the R046 direction correction, the next model innovation should not return
to an AI/`T_slew` main story. The better innovation is an AI-control-oriented
model layer:

```text
GAE-IQCOT:
Guarded AI-ready Event model for IQCOT

= PR-ECB large-signal peak-risk guard
+ PIS-IEK small-signal balance/reentry model
+ variable-active-phase hybrid event map
+ safety projection interface for AI or table supervision
```

The main novelty is not that AI directly controls the converter. The novelty is
that the converter model is reorganized into a form that an AI controller can
query, optimize, and be constrained by, while the original IQCOT inner loop still
generates the fast area-triggered pulse sequence.

## Why a New AI-Ready Model Is Needed

The previous AI/`T_slew` direction had a physical weakness: the load-current
slew rate is imposed by the external load, not selected by the VRM. Therefore an
AI controller should not be described as controlling `dI_load/dt`.

However, AI can still be meaningful if its role is redefined:

```text
AI does not command gate pulses.
AI does not choose the external load slew.
AI proposes low-dimensional supervisory parameters.
The model projects those proposals into a safe event-control set.
```

This gives a stronger and cleaner contribution: a large/small-signal model that
is directly usable as a constrained action interface for AI, MPC, Bayesian
optimization, lookup tables, or rule-based supervision.

## Model Source Boundary

Current repository evidence uses derived Simulink/Simscape model copies under:

- `output/simulink_iek/four_phase_iek_area.slx`
- `output/simulink_iek/four_phase_iek_perphase.slx`
- `output/simulink_iek/four_phase_iek_perphase_trim.slx`
- `output/simulink_iek/four_phase_iek_dynamic_load.slx`
- `output/simulink_iek/four_phase_iek_dynamic_load_refstep.slx`
- `output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx`

The established design point in the existing documents is a four-phase
interleaved synchronous Buck/VRM around:

| Item | Current research value |
|---|---:|
| `Vin` | `12 V` |
| `Vref` | `1 V` |
| phases | `4` |
| per-phase switching frequency | about `500 kHz` |
| `L` | about `200 nH` |
| `Cout` | about `7.2 mF` to `7.26 mF` |
| DCR evidence point | about `1.5 mOhm` |

Before any new model construction or parameter sweep, the actual `.slx` block
parameters must still be inspected through MATLAB APIs or `.slx` package
inspection. In particular, `Ron`, `Rd`, `Vfd`, `Rs`, `Cs`, `L`, `DCR`, `Cout`,
`ESR`, `Ton`, `Tdead`, `Tblank`, solver, and step size must be checked against
the initialization path. This document is a research design and does not modify
any `.slx` file.

## Core Innovation: Two-Regime, One-Interface Model

The key idea is to separate physical regimes but expose them through one
supervisory interface:

```text
large-signal mode:
    first-peak over-voltage risk after cut-load
    handled by PR-ECB and hard protection actions

small-signal mode:
    current sharing, phase spacing, reentry, and active-phase recovery
    handled by PIS-IEK and limited trim actions

hybrid mode:
    phase add/shed changes the active phase set
    handled by active-set event maps and dwell/hysteresis guards
```

The AI-facing model state is not the full switching waveform. It is a compact
event feature vector:

```math
z_k =
[
V_o,\dot V_o,
I_{load,est},
i_{L,1..4},
g_{HS,1..4},
t_{HS,rem,1..4},
p_k,
\mathcal A_k,
e_I,
e_\phi,
protect\_state,
dwell\_timer
].
```

Here `p_k` is the phase/event index and `A_k` is the active phase set. The model
returns risk scores, feasible action sets, and limited trim commands rather than
raw gate commands.

## Large-Signal Component: PR-ECB as a Peak-Risk Guard

For cut-load events, define the excess current:

```math
I_{ex}(t)=\sum_{i\in\mathcal A} i_{L,i}(t)-I_{load,new}.
```

The PR-ECB branch computes a conservative first-peak feature from two families:

```math
\Delta V_E
\approx
\sqrt{V_0^2+\frac{2E_{ex}}{C_o}}-V_0
```

```math
\Delta V_{Q+ESR}
\approx
\frac{Q_{ex}}{C_o}+I_{ex,0}R_{ESR}.
```

The risk value exposed to AI is normalized:

```math
r_p =
\frac{
  \Delta V_{bound}
}{
  \Delta V_{allow}
},
\qquad
\Delta V_{bound}
=
\operatorname{segment\_select}
(
\Delta V_E,
\Delta V_{Q+ESR},
E_{HS,rem}
).
```

`E_HS,rem` is only a segmentation feature for active high-side state. It must
not be described as a universal additive energy law.

The AI/control action is not a continuous `T_slew`; it is a protection token:

```text
a_P = [
  truncate_current_Ton,
  inhibit_event_count,
  integrator_hold_or_reset,
  reentry_band,
  reentry_phase_policy
]
```

This token is then projected by guards:

```text
if r_p >= r_high or active_HS_large_drop:
    Ton truncation and pulse inhibit are allowed
elif r_p >= r_mid:
    skip/inhibit monitoring is allowed
else:
    normal IQCOT is preferred
```

This creates an AI-compatible large-signal model: AI can select the
aggressiveness of protection, but it cannot inject new high-side energy when the
guard says the first peak is unsafe.

## Small-Signal Component: PIS-IEK as a Balance and Reentry Model

Near normal event sequences, use the PIS-IEK small-signal map:

```math
\delta x_{k+1}
=
A_{\mathcal A,p}\delta x_k
B_{T,\mathcal A,p}\delta T_{on}
B_{\Lambda,\mathcal A,p}\delta \Lambda
B_{d,\mathcal A,p}\delta t_d
G_{\mathcal A,p}w_k.
```

For four-phase fixed operation, existing evidence supports:

```text
Ton_diff    -> dominant DC current-sharing actuator
Lambda_diff -> phase-spacing / ripple-cancellation actuator
delay_diff  -> phase-jitter disturbance
```

Define current and phase errors over the active phase set:

```math
I_{avg}
=
\frac{1}{|\mathcal A|}
\sum_{i\in\mathcal A}i_{L,i},
\qquad
e_{I,i}=i_{L,i}-I_{avg}.
```

```math
e_{\phi,i}
=
\Delta t_i-\frac{T_{cycle}}{|\mathcal A|}.
```

The small-signal control token is:

```text
a_S = [
  K_T,
  K_Lambda,
  T_trim_max,
  Lambda_trim_max,
  balance_recovery_rate
]
```

Projected commands are:

```math
\Delta T_{on,i}
=
\Pi_T(-K_T e_{I,i}),
\qquad
\sum_{i\in\mathcal A}\Delta T_{on,i}=0.
```

```math
\Delta \Lambda_i
=
\Pi_\Lambda(-K_\Lambda e_{\phi,i}),
\qquad
\sum_{i\in\mathcal A}\Delta \Lambda_i=0.
```

The projection is essential: it prevents a fast current-sharing action from
destroying phase spacing or creating a switching-frequency excursion.

## Variable-Phase Component: Active-Set PIS-IEK

The active phase set extends the event map:

```math
x_{k+1}
=
F_{p_k,\mathcal A_k}
(x_k,u_k,T_k).
```

Phase add/shed events are saltation-like hybrid events:

```math
x_{k}^{+}
=
S_{\mathcal A^-\to\mathcal A^+}x_k^{-}
 + b_{\mathcal A^-\to\mathcal A^+}.
```

The nominal phase spacing changes by active phase count:

| Active phase count | Example active set | Nominal spacing |
|---:|---|---:|
| `1` | `{1}` | none |
| `2` | `{1,3}` | `180 deg` |
| `4` | `{1,2,3,4}` | `90 deg` |

The phase-management token is:

```text
a_N = [
  N_active_candidate,
  I_add_high,
  I_shed_low,
  dwell_time,
  new_phase_ramp_rate
]
```

The hard guard is:

```text
if protect_state != NORMAL_IQCOT:
    phase shedding is disabled
```

Recommended event order:

```text
cut-load protection
-> controlled reentry
-> balance recovery
-> phase shed decision
```

This is important because immediate phase shedding after cut-load may look
efficient but can interfere with first-peak protection and reentry.

## AI Action Projection

Let the AI or optimizer propose:

```math
a_{AI}=[a_P,a_S,a_N].
```

The converter never directly applies `a_AI`. It applies:

```math
a_{safe}
=
\Pi_{\mathcal G(z_k)}(a_{AI}),
```

where the guard set is:

```math
\mathcal G(z_k)=
\{
a:
r_p(a)\le r_{max},
|e_I^+(a)|\le I_{bal,max},
\|e_\phi^+(a)\|\le \phi_{max},
f_{sw,min}\le f_{sw}(a)\le f_{sw,max},
|\Delta T_{on,i}|\le T_{trim,max},
|\Delta\Lambda_i|\le \Lambda_{trim,max}
\}.
```

For implementation, `Pi` can begin as a rule-based projection rather than a
neural layer:

1. reject unsafe phase shedding;
2. clamp trim amplitudes;
3. prefer PR-ECB protection during cut-load;
4. use PIS-IEK balance only after reentry;
5. fall back to original IQCOT when model confidence is low.

This is a much safer and more defensible AI story than direct neural gate
control.

## Why This Is More Innovative Than the Previous Direction

The previous `T_slew` direction mainly tuned one recovery parameter. R047
proposes a structured model interface with three new research elements:

1. A normalized large-signal first-peak risk coordinate `r_p` that selects
   protection action classes, not merely a post-processing bound.
2. An active-set PIS-IEK small-signal model that changes with `1/2/4` phase
   operation and supplies separate balance and phase-spacing channels.
3. A guarded AI action projection layer that makes the model directly usable by
   AI, MPC, or table supervision without allowing unsafe gate-level behavior.

The novelty is therefore:

```text
AI-ready model structure
not AI as the main controller.
```

## Paper Claim Candidate

Safe Chinese wording:

> 本文提出一种面向 AI 监督控制的四相数字 IQCOT 大小信号协同事件模型。该模型将切载第一峰风险写成 PR-ECB 大信号保护坐标，将稳态均流与相位恢复写成 PIS-IEK 小信号事件映射，并进一步引入 active phase set 形成可变相数混合事件模型。AI 或查表监督层只输出低维保护、均流和加减相候选参数，最终动作必须经过 PR-ECB/PIS-IEK 约束投影后才能作用于 IQCOT 内环。

Safe English wording:

> This work develops a guarded AI-ready event model for four-phase digital
> IQCOT buck control. PR-ECB provides a large-signal cut-load first-peak risk
> coordinate, PIS-IEK provides a small-signal balance and phase-recovery map,
> and an active-phase-set extension captures phase add/shed hybrid events. The
> supervisory AI layer proposes low-dimensional action tokens, while a
> model-based projection enforces voltage, current-sharing, phase-spacing, and
> switching constraints before the original IQCOT inner loop is affected.

Forbidden wording:

- AI controls the external load-current slew rate.
- AI replaces IQCOT gate-level pulse generation.
- PIS-IEK predicts all large-signal first peaks.
- PR-ECB is hardware/HIL validated.
- `E_HS,rem` is a global additive energy correction law.

## Validation Roadmap

### R048: State Machine and Wiring Audit

No switching simulation yet. First inspect the derived `.slx` model path and
write a block/signal table for:

- `Vout`, `Iload`, `IL1..IL4`;
- high-side and low-side gate signals;
- `REQ1..REQ4`;
- `phase_idx`;
- area integrator states;
- actual high-side pulse width;
- existing skip/reentry behavior.

### R049: PR-ECB Protection Ablation

Compare:

| Case | Controller |
|---|---|
| A0 | original IQCOT |
| A1 | simple over-voltage skip |
| A2 | PR-ECB + Ton truncation |
| A3 | PR-ECB + Ton truncation + pulse inhibit + controlled reentry |

Main metrics: peak overshoot, first-peak time, truncated pulse count, inhibit
duration, skip count, reentry time, secondary oscillation, and final error.

### R049B Result: Simple OV Skip Claim Downgrade

R049B implemented the first minimal derived-copy protection action: simple
over-voltage request skip,

```text
Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip).
```

The minimal chunk used `40A -> 1A near0` and two offsets, `0.05 us` and
`0.105 us`.  With `Vov_skip = 2 mV`, A1 inhibited new requests for about
`18.880 us` and `19.816 us`, blocking `19` and `20` raw REQ edges.  However,
the first-peak overshoot remained unchanged relative to A0:

| Offset | A0 peak | A1 OV-skip peak | Improvement |
|---:|---:|---:|---:|
| `0.05 us` | `6.2586 mV` | `6.2586 mV` | `0.0000 mV` |
| `0.105 us` | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` |

Revision to the GAE-IQCOT/PR-ECB action model:

```text
simple OV skip = post-threshold request-inhibit / SKIP_HOLD action
simple OV skip != validated first-peak suppression action
```

For first-peak protection, PR-ECB should prioritize actions that can reduce
remaining high-side energy injection, such as minimal Ton truncation or
active-HS remaining-on-time truncation.  Simple OV skip may still be useful for
skip-hold/reentry management, but it should not be the primary A1 first-peak
claim.

### R049C Result: Ton Truncation Confirms Active-HS First-Peak Action

R049C implemented command-path Ton truncation as the next minimal derived-copy
protection action:

```text
if t_load_step <= t <= t_load_step + Tton_trunc_window
   and Vout > Vo_ref + Vton_trunc_ov
then
   Ton_iqcot_i -> Tton_trunc_min
```

The minimal chunk reused `40A -> 1A near0` and offsets `0.05 us` / `0.105 us`.
With `Vton_trunc_ov = 2 mV`, `Tton_trunc_min = 5 ns`, and
`Tton_trunc_window = 2 us`, A2 produced:

| Offset | Phase state | A0 peak | A2 peak | Improvement |
|---:|---|---:|---:|---:|
| `0.05 us` | active-HS boundary, phase-4 remaining Ton about `52 ns` | `6.2586 mV` | `5.4926 mV` | `0.7660 mV` |
| `0.105 us` | post-turnoff, remaining Ton `0 ns` | `5.9603 mV` | `5.9603 mV` | `0.0000 mV` |

Decision:

```text
MODEL_CONFIRMED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
Ton truncation = first-peak active-HS energy-reduction action
OV skip        = post-threshold request-inhibit / SKIP_HOLD action
E_HS,rem       = phase-state segmentation feature, not a global additive law
```

The next validation should not jump to the full A matrix.  It should first run
one hold-out load-drop magnitude, such as `40A -> 10A`, crossed with the same
two offsets to test whether the active-HS Ton-truncation benefit transfers
without creating a new reentry or secondary-oscillation penalty.

### R049D Result: Ton-Truncation Hold-Out Confirms Load-Magnitude Transfer

R049D copied the completed R049C command-path Ton-truncation model into a new
hold-out derived copy and changed only the validation plan:

```text
40A -> 10A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The hold-out produced:

| Offset | Phase state | A0 peak | A2 peak | Improvement | Secondary undershoot change |
|---:|---|---:|---:|---:|---:|
| `0.05 us` | active-HS boundary, phase-4 remaining Ton about `52 ns` | `3.9908 mV` | `3.3873 mV` | `0.6036 mV` | `+2.0279 mV` |
| `0.105 us` | post-turnoff, remaining Ton `0 ns` | `3.7607 mV` | `3.7607 mV` | `0.0000 mV` | `0.0000 mV` |

Decision:

```text
MODEL_CONFIRMED
```

Revision to the action hierarchy: no structural revision is needed.  R049D
extends the R049C evidence from `40A -> 1A near0` to the `40A -> 10A`
hold-out.  The safe wording is now:

```text
Ton truncation is a confirmed active-HS first-peak action in two small chunks:
near0 and 10A targets, both at the same active-HS / post-turnoff offset pair.
```

This still must not be upgraded to hardware/HIL, full-matrix, all-offset, or
global PR-ECB calibration evidence.  Before broadening claims, the next small
step should either test a milder hold-out such as `40A -> 20A`, or add a
separate reentry / pulse-inhibit validation chunk.

### R049E Result: Mild Hold-Out Downgrades Trigger Generalization

R049E tested the same command-path Ton-truncation mechanism on a milder
hold-out:

```text
40A -> 20A
offsets: 0.05 us, 0.105 us
controllers: A0 same-model no-trunc, A2 Ton truncation
```

The result did not reproduce the R049C/R049D first-peak improvement:

| Offset | Phase state | A0 peak | A2 peak | Improvement | Trigger observation |
|---:|---|---:|---:|---:|---|
| `0.05 us` | active-HS boundary, phase-4 remaining Ton about `52 ns` | `2.1103 mV` | `2.1103 mV` | `0.0000 mV` | trunc flag asserted only after `0.228 us`, when `qh4=0` |
| `0.105 us` | post-turnoff, remaining Ton `0 ns` | `2.0936 mV` | `2.0936 mV` | `0.0000 mV` | no truncation |

Decision:

```text
CLAIM_DOWNGRADED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
Ton truncation is phase-state and trigger-timing selective.
The current Vout-over-threshold trigger helped near0 and 10A active-HS chunks,
but it can be too late for mild 20A cut-load even when active-HS state exists.
```

Therefore R049C/R049D should be worded as evidence for an
over-voltage-triggered command-path truncation mechanism in larger drops, not as
a general active-HS law.  The next validation should diagnose trigger timing:
use the same `40A -> 20A` offsets with a pre-threshold or
load-step-synchronous active-HS truncation variant before any full-grid claim.

### R049F Result: Early Timing Works but Global Action Is Over-Aggressive

R049F changed the R049E model from an over-voltage-triggered truncation flag to
a load-step-synchronous time-window flag:

```text
R049C/R049D/R049E:
    after_load_step AND before_window_end AND over_voltage

R049F:
    after_load_step AND before_window_end
```

A2 used `Tton_trunc_min = 5 ns` and an `80 ns` early window.  The same
`40A -> 20A` two-offset chunk produced:

| Offset | A0 peak | A2 peak metric | A0 rem Ton4 | A2 rem Ton4 | A2 final error | Interpretation |
|---:|---:|---:|---:|---:|---:|---|
| `0.05 us` | `2.1103 mV` | `-184.1030 mV` | `52 ns` | `0 ns` | `-239.1723 mV` | early timing removes active Ton but causes severe undervoltage |
| `0.105 us` | `2.0936 mV` | `-189.3089 mV` | `0 ns` | `0 ns` | `-241.9473 mV` | global early action is unsafe even without phase-4 remaining Ton |

Decision:

```text
MODEL_REVISED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
active-HS Ton command truncation needs both:
    1. early-enough trigger timing, and
    2. phase-selective / state-gated application.

Global all-phase load-step-synchronous Ton-min truncation is over-aggressive
and should not be the PR-ECB action.
```

R049F clarifies the R049E negative result: the command path can remove active
Ton when asserted early enough, but the action must be redesigned as an
active-HS-only guard before further expansion.

### R049G Result: Repaired Phase-Selective Truncation Still Revises the Action

R049G copied the completed R049F model into a new derived copy and first
repaired a timing-wiring issue exposed by R049F:

```text
R049C_After_LoadStep/2 was unconnected.
R049G adds R049G_LoadStep_Time = t_load_step
and connects it to R049C_After_LoadStep/2.
```

This means the severe R049F undervoltage should be treated as an
implementation-timing artifact of the over-voltage-free early window starting
at simulation time zero.  R049G then tested the intended phase-selective action:

```text
ton_truncate_i = early_window AND Memory(qh_i)
```

The repaired `40A -> 20A` two-offset chunk produced:

| Offset | A0 peak | A2 peak | A0 rem Ton4 | A2 rem Ton4 | Interpretation |
|---:|---:|---:|---:|---:|---|
| `0.05 us` | `2.1103 mV` | `2.3879 mV` | `52 ns` | `2 ns` | active phase is truncated, but first peak worsens |
| `0.105 us` | `2.0936 mV` | `2.0936 mV` | `0 ns` | `0 ns` | no active Ton to remove, no change |

Decision:

```text
MODEL_REVISED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
Hard active-HS Ton-min truncation is structurally effective but not yet a
confirmed beneficial PR-ECB action for mild 40A -> 20A cuts.

The PR-ECB first-peak metric must split:
    early local spike risk,
    recovery peak risk,
    late undershoot / settling risk.
```

The next validation should be R049H, an offline waveform-metric audit over
existing R049C/R049D/R049E/R049F/R049G wave exports.  Do not run a full matrix
or another Ton-min action before this metric/state-machine revision is
documented.

### R049H Result: Windowed Peak Metrics Revise the PR-ECB Acceptance Gate

R049H ran no new switching simulation.  It reprocessed existing wave CSVs from
R049C/R049D/R049E/R049F/R049G with three windows:

```text
0-2 us    early local peak
2-12 us   recovery peak
12-80 us  late settling / undershoot
```

Active-HS summary:

| Chunk | Early peak improvement | Recovery peak improvement | Late peak improvement |
|---|---:|---:|---:|
| R049C near0 | `+0.7660 mV` | `+1.0047 mV` | `-0.4480 mV` |
| R049D 10A | `+0.6036 mV` | `-0.0323 mV` | `-0.0045 mV` |
| R049E 20A OV-triggered | `0.0000 mV` | `0.0000 mV` | `0.0000 mV` |
| R049G 20A repaired phase-selective | `-0.2902 mV` | `-0.0476 mV` | `-0.0866 mV` |

Decision:

```text
MODEL_REVISED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
PR-ECB action acceptance requires segmented metrics:
    J_early_peak    over 0-2 us
    J_recovery_peak over 2-12 us
    J_late_min      over 12-80 us

R049C supports broad near0 Ton-truncation benefit.
R049D supports mainly early-local-peak benefit for 10A.
R049G rejects hard phase-selective Ton-min as a confirmed mild-load action.
```

The next validation should be R049I: a single repaired-model gentle
phase-selective Ton-trim chunk on the same `40A -> 20A` two-offset setup, using
R049H's three-window metrics as the acceptance gate.

### R049I Result: Gentle Ton Floor Still Fails the Early-Peak Gate

R049I copied the completed R049G repaired model into a new derived copy and ran
one `40A -> 20A` two-offset chunk:

```text
A0: same-model no trim
A2: early_window AND qh_i, Tton_trunc_min = 120 ns
```

The `120 ns` floor was selected after inspecting the R049G baseline Ton trace.
At the active-HS `0.05 us` offset, the baseline command was `196.5 ns` and
phase 4 had about `52 ns` remaining, so the pulse had already been on for about
`144.5 ns`.  Model inspection confirmed that `Tton_trunc_min` is a whole-pulse
Ton command into the COT cell, not a remaining-on-time floor.  Therefore even a
`120 ns` floor is already expired at the active-HS load-step instant.

Windowed result:

| Offset | Window | A2-A0 max | Interpretation |
|---:|---|---:|---|
| `0.050 us` | `0-2 us` early local peak | `+0.2902 mV` | fails acceptance gate |
| `0.050 us` | `2-12 us` recovery peak | `+0.0476 mV` | slightly worse |
| `0.050 us` | `12-80 us` late peak | `+0.0866 mV` | worse |
| `0.105 us` | all windows | `0.0000 mV` | no active Ton to affect |

Decision:

```text
MODEL_REVISED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
Phase-selective Ton floors are not sufficient if the active pulse has already
exceeded the proposed floor.  Do not keep scanning Ton-min/Ton-floor variants
for this mild active-HS case.
```

The next validation should switch to deferred post-active pulse inhibit or
controlled reentry, preserving the R049H three-window acceptance gate.

### R049J Result: Request Inhibit Avoids Ton Truncation but Needs Controlled Reentry

R049J copied the completed R049I model into a new derived copy and inserted a
request-path post-active inhibit gate:

```text
allow_to_scheduler = existing_allow AND NOT(post_active_inhibit)
```

The selected A2 window was evidence-based:

```text
baseline qh4 natural fall: 0.052 us after load step
post_active_inhibit: 0.070 us -> 2.000 us
```

This avoided the R049G/R049I failure mode.  In the `0.05 us` active-HS row:

```text
remaining Ton4: 52 ns -> 52 ns
global Ton-trunc duration: 0 us
skipped REQ count during inhibit: 1
```

However, the hard request inhibit caused an undershoot/reentry penalty:

| Offset | Early peak A2-A0 | Recovery peak improvement | Recovery undershoot penalty |
|---:|---:|---:|---:|
| `0.050 us` | `0.0000 mV` | `+0.6262 mV` | `-2.9901 mV` |
| `0.105 us` | `0.0000 mV` | `+0.5813 mV` | `-4.1571 mV` |

Decision:

```text
MODEL_REVISED
```

Revision to the GAE-IQCOT/PR-ECB action model:

```text
Avoiding current-pulse truncation is necessary, but a hard post-active request
inhibit is not sufficient.  The next action must include controlled reentry or
soft request restoration, and the R049H window gate must include recovery
undershoot penalties.
```

This result motivates a minimal controlled-reentry follow-up rather than a full
matrix; R049K below performs that follow-up.

### R049K Result: Short Soft Reentry Reduces but Does Not Eliminate the Trade-Off

R049K copied the completed R049I model into a new derived copy and inserted the
same request-path gate family as R049J, but shortened the A2 window:

```text
allow_to_scheduler = existing_allow AND NOT(soft_reentry)
soft_reentry = 0.070 us -> 1.760 us
```

The end point was selected from R049J waveform timing: the first future request
and qh1 boundary appears around `1.678-1.690 us`, whereas R049J held until
`2.000 us`.

R049K preserved the key safety property:

```text
0.05 us active-HS row remaining Ton4: 52 ns -> 52 ns
global / phase Ton-trunc duration: 0 us
```

Windowed result:

| Offset | Window | Peak improvement | Undershoot change |
|---:|---|---:|---:|
| `0.050 us` | `0-2 us` early local peak | `0.0000 mV` | `-0.2917 mV` |
| `0.050 us` | `2-12 us` recovery peak | `+0.1796 mV` | `-0.6388 mV` |
| `0.050 us` | `12-80 us` late peak | `-0.1318 mV` | `-0.0261 mV` |
| `0.105 us` | `0-2 us` early local peak | `0.0000 mV` | `-0.6663 mV` |
| `0.105 us` | `2-12 us` recovery peak | `+0.1954 mV` | `-1.6588 mV` |
| `0.105 us` | `12-80 us` late peak | `-0.0223 mV` | `+0.0547 mV` |

Decision:

```text
MODEL_REVISED
```

Revision to the action model:

```text
Shorter request restoration is better than a hard 2 us inhibit, but a single
fixed scalar reentry window still trades recovery-peak reduction against
undershoot and late-peak penalties.
```

The next validation should stop scanning fixed inhibit windows and instead test
an explicit controlled-reentry proxy, such as edge-aligned one-shot request
restoration or phase-aware release, with the R049H three-window metric gate.

### R049L Repair Result: Downstream qh1 Is Not a Valid Release Trigger

R049L repair first fixed the external R049L implementation issue by restoring
the R049K-compatible baseline:

```text
t_load_step = 0.45 ms + offset
0.050 us A0: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us A0: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

The repaired A2 then attempted a phase-boundary one-shot release triggered by
`qh1` rising during the inhibit window.  This failed structurally:

```text
one_shot_edge_count = 0
one_shot_time_us = NaN
```

The reason is a circular dependency.  `qh1` is downstream of the same
request-path gate that the reentry logic controls.  Once the gate suppresses
the scheduler request, the `qh1` edge needed to release the gate cannot occur.

R049L repair is therefore:

```text
IMPLEMENTATION_ISSUE
```

This revises the controlled-reentry implementation rule: a one-shot reentry
trigger must come from an upstream phase-boundary / scheduler-slot signal that
continues to evolve during request inhibition, or from an independent
phase-clock proxy.  Downstream gate outputs such as `qh1` can be audited as
effects, but should not be used as the release cause for request-path
controlled reentry.

### R049M Result: Existing Scheduler State Freezes During Request Inhibit

R049M performed a read-only structural audit of the R049L repair model. The
actual trigger path is:

```text
R049L_Gate_And
-> Allow
-> Detect Rise Positive
-> tr
-> PhaseScheduler_4Phase trigger
```

Inside `PhaseScheduler_4Phase`, `phase_state` is a triggered `UnitDelay`. It is
held except when `tr` rises. Therefore the existing scheduler state and outputs
are downstream effects of the gated request path:

```text
phase_state / phase_idx / phase_en1..4 / tr1..4 / qh1
```

They do not continue to evolve during request inhibition and cannot be causal
release triggers.

R049M decision:

```text
MODEL_REVISED
```

This revises the PR-ECB controlled-reentry interface. The release trigger must
be an independent upstream phase-clock or predicted scheduler-slot signal,
calibrated against the observed R049K boundary near `1.678-1.690 us`, rather
than an existing scheduler output.

### R050: PIS-IEK Balance Control

Compare:

| Case | Controller |
|---|---|
| B0 | original IQCOT |
| B1 | `Lambda_diff` only |
| B2 | `Ton_diff` only |
| B3 | `Ton_diff + Lambda_diff` |
| B4 | PIS-IEK projected balance |

Main metrics: max/RMS current imbalance, phase-spacing standard deviation,
output ripple, switching-frequency drift, and trim usage.

### R051: Variable-Phase Add/Shed

Compare fixed four-phase control against `1/2/4` active-phase control with and
without PR-ECB/PIS-IEK guards. The success condition is not just fewer active
phases. It must preserve voltage protection, reentry, and current-sharing
recovery.

## Immediate Next Step

The next concrete research step should be the R048 state-machine and model
wiring document. Only after that should a derived Simulink model be built or
modified through MATLAB APIs. Original `.slx` files should remain untouched.

## Adaptive Validation Commitment

The GAE-IQCOT model is not frozen before validation. Future validation must be
used to refine the model innovation itself.

After each validation chunk, automation should classify the result as:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

If the result is `MODEL_REVISED`, this document must be updated before the next
simulation chunk. The update must state:

```text
old assumption
observed contradiction
new assumption
affected controller/state-machine rule
affected validation matrix
new safe claim boundary
```

Examples:

- If PR-ECB predicts low first-peak risk but the measured overshoot is high,
  revise the risk segmentation or add a missing phase-state feature.
- If PR-ECB protection lowers overshoot but creates excessive secondary
  undershoot, revise the inhibit/reentry token rather than claiming simple
  superiority.
- If PIS-IEK `Ton_diff` improves current balance but damages phase spacing, add
  a stronger projection penalty or reduce `T_trim_max`.
- If phase shedding creates a transient spike, revise dwell/reentry locks and
  new-phase ramp logic before claiming an efficiency benefit.

### R049N Result: Independent Upstream Release Fires but Needs Softer Recovery

R049N implemented the next interface proposed by R049M: an upstream independent
phase-clock / predicted-slot release trigger.  The fixed release was calibrated
at:

```text
release_clock = t_load_step + 1.685 us
```

Unlike R049L repair, the A2 release is not downstream of `qh1` or the gated
scheduler.  The quality gates passed:

```text
0.050 us A2: release_clock=1.686 us, one_shot_done=1.750 us
0.105 us A2: release_clock=1.685 us, one_shot_done=1.735 us
```

The repaired A0 baseline remained aligned with R049K / R049L repair:

```text
0.050 us A0: peak 2.1103 mV, qh4_at_step=1, remaining Ton4=50.5 ns
0.105 us A0: peak 2.0936 mV, qh4_at_step=0, remaining Ton4=0 ns
```

However, R049H three-window metrics show that this is not a confirmed
controller improvement.  Recovery positive peaks improve, but recovery
undershoot worsens:

```text
0.050 us recovery: +0.1127 mV peak improvement, -0.5597 mV undershoot change
0.105 us recovery: +0.1205 mV peak improvement, -1.4429 mV undershoot change
```

R049N decision:

```text
MODEL_REVISED
```

The research interpretation is now sharper: the upstream release interface is
viable, but a fixed hard release at `1.685 us` is too coarse.  The next PR-ECB
iteration should keep the upstream-causal interface while reducing recovery
undershoot, e.g. via earlier release timing or softened request restoration.

### R049O Result: Earlier Binary Release Becomes Transparent

R049O kept the R049N upstream-causal release interface and tested two earlier
binary release delays:

```text
Tphase_release_delay = 1.250 us
Tphase_release_delay = 1.450 us
```

Both releases fired successfully, but all R049H three-window deltas versus A0
were `0.0000 mV`.  The earlier release settings remove the R049N recovery
undershoot penalty by also removing the controlled-reentry effect.

R049O decision:

```text
CLAIM_DOWNGRADED
```

This brackets the useful timing region: `1.250-1.450 us` is too early and
transparent; `1.685 us` is active but too hard.  The next step should be a
single narrow intermediate timing point or a soft request-restoration action.

### R049P Result: 1.600us Midpoint Is Offset-Selective

R049P tested exactly one intermediate binary release:

```text
Tphase_release_delay = 1.600 us
```

The release fired in both offsets, but only the `0.105 us` row showed useful
change.  At `0.050 us`, all R049H three-window deltas remained `0.0000 mV`.
At `0.105 us`, recovery peak improved by `+0.1244 mV`, recovery undershoot
worsened by `-0.7873 mV`, and late settling improved.

R049P decision:

```text
MODEL_REVISED
```

The result narrows the path: binary timing around `1.600 us` can be less
damaging than R049N's `1.685 us`, but the action is phase/offset selective.
The next step should be either one slightly later point (`1.62-1.64 us`) or a
soft/ramped release rather than a broad sweep.

### R049Q Result: 1.630us Moves Back Toward Hard-Release Penalty

R049Q tested one slightly later binary release:

```text
Tphase_release_delay = 1.630 us
```

The source model still uses the R049N upstream-causal release interface:

```text
release_clock = t_load_step + Tphase_release_delay
```

The release fired in both offsets:

```text
0.050 us A2: release_clock=1.630 us, one_shot_done=1.670 us
0.105 us A2: release_clock=1.631 us, one_shot_done=1.695 us
```

The `0.050 us` row remained transparent.  At `0.105 us`, recovery peak
improvement increased from R049P's `+0.1244 mV` to `+0.1365 mV`, but recovery
undershoot worsened from `-0.7873 mV` to `-1.1109 mV`, and late peak changed
from an improvement to a degradation.

R049Q decision:

```text
MODEL_REVISED
```

The result narrows the safe assumption again: later binary release increases
action strength but accelerates the undershoot penalty.  The next step should
not keep moving later.  Test one point between `1.600 us` and `1.630 us`, or
replace binary restore with soft/ramped restoration.

### R049R Result: Binary Release Timing Is Event-Quantized

R049R tested the between-point:

```text
Tphase_release_delay = 1.615 us
```

The release clock moved as intended, but the actual one-shot event did not move
relative to R049P:

```text
R049P 0.105 us: release delay 1.600 us -> one_shot_done 1.655 us
R049R 0.105 us: release delay 1.615 us -> one_shot_done 1.655 us
R049Q 0.105 us: release delay 1.630 us -> one_shot_done 1.695 us
```

Consequently R049R's window metrics match R049P:

```text
0.105 us recovery: +0.1244 mV peak improvement, -0.7873 mV undershoot change
```

R049R decision:

```text
MODEL_REVISED
```

The revised model is now clearer: binary release delay is not a smooth timing
knob.  It selects the next actual release/scheduler event.  More points inside
the same event plateau are low value; the next research step should either
audit the event boundary between `1.655 us` and `1.695 us` or replace the hard
binary restore with a soft/ramped restoration.

The automation plan for this loop is recorded in
`docs/adaptive_validation_automation_20260624.md`.
