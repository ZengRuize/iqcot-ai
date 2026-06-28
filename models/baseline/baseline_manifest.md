# Baseline Manifest

## Baseline Model Local Path

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

## Model Purpose

Local ideal four-phase digital IQCOT baseline for all future Simulink validation. It is the reference A0/B0/C0/D0 behavior for load-drop, load-rise, current-sharing, phase-recovery, and active-phase experiments.

## Git Tracking Status

As of 2026-06-28, this baseline file is present locally and is not tracked in git. The check was:

```text
git ls-files -- output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

which returned no tracked path.

## Required Logged Signals

```text
Vout
Iload
IL1..IL4
QH1..QH4
QL1..QL4
REQ1..REQ4
phase_idx
Ton_cmd_i
Ton_actual_i
Lambda_i
area_int_i
active_phase_set
```

## Do-Not-Modify Rule

Do not modify the baseline `.slx` directly. Do not run `set_param`, add blocks, change logging, or save over this baseline path. Do not edit raw `.slx` XML.

## Derived-Copy Naming Rule

Create derived models only through MATLAB APIs and save them under:

```text
models/derived/E###_<variant>_<short_purpose>_from_ideal_iqcot_<YYYYMMDD>.slx
```

Example:

```text
models/derived/E010_A1_ton_trunc_from_ideal_iqcot_20260628.slx
```
