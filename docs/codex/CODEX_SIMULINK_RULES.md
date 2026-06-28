# Codex Simulink Rules

## Baseline

All future validation starts from:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Never modify this baseline model directly.

## Model Editing

Use MATLAB and Simulink APIs only:

```text
load_system
save_system
set_param
add_block
add_line
delete_line
Simulink.sdi
signal logging APIs
```

Never edit raw `.slx` XML manually.

## Derived Copy Naming

Use a descriptive derived model name:

```text
models/derived/E###_<variant>_<short_purpose>_from_ideal_iqcot_<YYYYMMDD>.slx
```

Examples:

```text
models/derived/E010_A1_ton_trunc_from_ideal_iqcot_20260628.slx
models/derived/E020_B4_fast_request_ton_boost_phase_add_from_ideal_iqcot_20260628.slx
```

## Required Logged Signals

Verify before simulation:

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

Missing signals must be added only in derived copies.

## Simulation Gate

Before any simulation:

1. Audit baseline wiring.
2. Verify signal names and logging.
3. Create a derived model copy.
4. Write a hypothesis block.
5. Run the smallest useful chunk first.
6. Generate CSV metrics and a Markdown report.
7. Classify the result as `MODEL_CONFIRMED`, `MODEL_REVISED`, `IMPLEMENTATION_ISSUE`, or `CLAIM_DOWNGRADED`.
8. Update theory and evidence before expanding the grid.

## Claim Boundary

Simulink-only results are simulation results. Do not claim hardware, HIL, board, or silicon validation from them.
