# E020 Load-Rise Undershoot Hypothesis

Date: 2026-06-29

## Baseline

All E020 validation must derive from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

The baseline `.slx` must not be modified directly. Derived models must be created through MATLAB/Simulink APIs and saved under:

```text
models/derived/E020_<variant>_<short_purpose>_from_ideal_iqcot_<YYYYMMDD>.slx
```

## Physical Hypothesis

For a `40A -> 120A` external load-current increase:

```text
Iload_new > I_Lsum(t0+)
```

The inductor-current sum initially lags the new load demand. The output capacitor supplies the deficit current:

```text
I_def(t) = Iload(t) - I_Lsum(t)
Delta Vout_down ~= (1 / Cout) * integral(max(I_def(t), 0) dt)
```

The load-rise branch must add energy. It must not use load-drop actions such as Ton truncation or pulse inhibit.

## First Chunk

Run only:

```text
load step: 40A -> 120A
variants:
  B0 original ideal IQCOT with derived observability
  B1 fast request only
  B2 Ton boost only
  B3 fast request + Ton boost
```

Do not add phase-add in the first chunk.

## Candidate `a_U` Parameters

```text
fast_request_enable
Lambda_cm_reduce
min_off_override_level
Ton_boost_enable
Tton_boost_max
boost_window
boost_decay_rate
integrator_preload_policy
current_limit_guard
```

Ton boost must be bounded by current-limit and recovery-overshoot guards.

## Metrics

```text
peak undershoot
current rise time
recovery overshoot
phase current peak
current-limit hit
settling time
final error
event count during first 2us
Ton boost usage
fast-request count
```

## Classification Rule

```text
MODEL_CONFIRMED:
  B1/B2/B3 improve peak undershoot without unacceptable current peak or recovery overshoot.

MODEL_REVISED:
  improvement exists only in some action types or action windows; revise a_U and projection rules.

IMPLEMENTATION_ISSUE:
  logging, derived model wiring, load profile, or signal extraction is unreliable.

CLAIM_DOWNGRADED:
  fast request / Ton boost consistently worsens undershoot, overcurrent, or recovery overshoot.
```

## Expected Output Files

```text
experiments/E020_load_rise_undershoot/e020_metrics.csv
experiments/E020_load_rise_undershoot/e020_research_summary.md
experiments/E020_load_rise_undershoot/e020_waveform_audit.md
```
