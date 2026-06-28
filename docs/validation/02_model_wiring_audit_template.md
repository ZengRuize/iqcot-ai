# Model Wiring Audit Template

## Metadata

```text
audit_id:
date:
auditor:
baseline_model:
derived_model:
init_script:
build_script:
run_script:
git_status_summary:
```

## Model Identity

```text
topology:
control_architecture:
phase_count:
active_phase_modes:
solver:
fixed_step_or_max_step:
stop_time:
```

## Required Signal Audit

| Signal | Present | Logged | Source block/path | Notes |
|---|---:|---:|---|---|
| Vout | | | | |
| Iload | | | | |
| IL1 | | | | |
| IL2 | | | | |
| IL3 | | | | |
| IL4 | | | | |
| QH1 | | | | |
| QH2 | | | | |
| QH3 | | | | |
| QH4 | | | | |
| QL1 | | | | |
| QL2 | | | | |
| QL3 | | | | |
| QL4 | | | | |
| REQ1 | | | | |
| REQ2 | | | | |
| REQ3 | | | | |
| REQ4 | | | | |
| phase_idx | | | | |
| Ton_cmd_i | | | | |
| Ton_actual_i | | | | |
| Lambda_i | | | | |
| area_int_i | | | | |
| active_phase_set | | | | |

## Parameter Audit

Before editing a derived model, compare actual `.slx` values against init-script values.

| Parameter | Actual `.slx` value | Init-script value | Proposed value | Reason |
|---|---:|---:|---:|---|
| Ron_HS | | | | |
| Ron_LS | | | | |
| DCR_L | | | | |
| L | | | | |
| Cout | | | | |
| ESR | | | | |
| fsw | | | | |
| Ton | | | | |
| Tdead | | | | |
| Tblank | | | | |
| Vhys | | | | |
| solver / step | | | | |

## Wiring Decision

```text
audit_result: PASS | BLOCKED | NEEDS_DERIVED_LOGGING | IMPLEMENTATION_ISSUE
missing_signals:
hard_coded_parameters:
required_derived_edits:
```

## Hypothesis Block

```text
experiment_id:
variant:
load_profile:
expected_branch:
expected_metric_direction:
safety_projection_expected_action:
claim_under_test:
```

## Result Classification

```text
classification: MODEL_CONFIRMED | MODEL_REVISED | IMPLEMENTATION_ISSUE | CLAIM_DOWNGRADED
metrics_csv:
markdown_report:
theory_update_required:
evidence_update_required:
```
