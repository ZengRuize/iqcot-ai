# E010-A5 Severe-Drop a_O Hypothesis

Date: 2026-06-30

Status: DESIGN_ONLY

## Scope

E010-A5 targets the unresolved severe load-drop case:

```text
External load-current drop: 40A -> 1A
Active phases: fixed four-phase
Power-stage DCR: nominal
Current-sense gains: nominal
Active Lambda: disabled
Active-phase add/shed: disabled
Baseline source: E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline model must not be modified directly. Future validation must create derived copies through MATLAB/Simulink APIs.

## Current Evidence

Current E010 evidence is `MODEL_REVISED`.

```text
40A -> 20A:
  A4 projects to no-op or gentle protection because fixed truncation/inhibit is too aggressive.

40A -> 10A:
  A4 selected Ton truncation + one early pulse inhibit.
  Recovery peak improved by about 22.2%.
  Undershoot penalty = 0.863951 mV.

40A -> 1A:
  A4 is no-harm but non-improving.
  A0/A4 recovery peak 2-12us = 3.61172 mV.
```

## Hypothesis

A severe load-drop token can reduce the `40A -> 1A` overshoot or recovery peak only if it addresses both residual high-side energy and event-domain reentry:

```text
H1: active-HS-aware Ton truncation can reduce immediate residual energy injection.
H2: bounded multi-event pulse inhibit can delay unsafe reentry pulses.
H3: area-integrator hold or controlled reset can prevent stored area state from forcing burst reentry.
H4: controlled reentry can avoid a large undershoot penalty and burst pulses.
H5: fallback-to-A4/no-op is required when predicted undershoot or reentry instability is too large.
```

## Model Boundary

The severe-drop first peak is a large-signal excess-current / excess-energy behavior:

```text
I_ex(t0+) = I_Lsum(t0+) - Iload_new
Delta Vout ~= (1 / Cout) * integral(max(I_Lsum(t) - Iload_new, 0) dt)
```

PIS-IEK must not be used to claim accurate first-peak prediction. PIS-IEK may be used only after protection and reentry as conservative balance recovery.

## Expected Outcome

The useful result is not "maximum pulse suppression." A useful A5 candidate must reduce peak overshoot or recovery peak versus both A5-C0 and A5-C4 while keeping:

```text
peak_undershoot within budget
dropped_REQ_count == 0
phase_order_error_rate == 0
current_limit_hit == false
burst_pulse_count_after_reentry bounded
final_Vout_error bounded
```

If no A5 candidate satisfies these gates, the correct classification is `MODEL_REVISED` or `CLAIM_DOWNGRADED`, not a forced success.
