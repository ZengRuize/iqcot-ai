# Validation Protocol

## Baseline

All Simulink validation starts from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Do not modify this baseline model directly. Do not edit raw `.slx` XML. Create derived copies through MATLAB APIs.

## Before Any Simulation

1. Audit the baseline model wiring.
2. Verify signal names for:

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

3. Create a derived model copy.
4. Write a hypothesis block.
5. Run the smallest useful chunk first.
6. Generate CSV metrics and a Markdown report.
7. Classify the result:

```text
MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED
```

8. Update theory and evidence before expanding the grid.

## Derived Copy Rule

Derived models should be created with MATLAB commands such as:

```matlab
baseline = 'E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx';
derived = 'E:/Desktop/codex/models/derived/e010_a1_ton_trunc_YYYYMMDD.slx';
load_system(baseline);
save_system(bdroot, derived);
load_system(derived);
```

Then apply changes with `set_param`, `add_block`, `add_line`, and logging APIs.

## Report Bundle

Each run should produce:

- derived model path;
- MATLAB build/run script path;
- hypothesis block;
- wiring audit status;
- metrics CSV path;
- Markdown report path;
- classification label;
- theory/evidence update notes.

## No Hardware Claim

Simulink-only evidence remains simulation evidence. It can motivate hardware/HIL work, but it must not be represented as hardware validation.
