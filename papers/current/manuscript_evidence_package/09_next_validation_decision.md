# Next Validation Decision

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

Do not run E020-R2 tuning yet.

Recommended first future simulation:

```text
E020 settling audit
```

Reason:

```text
a_U early benefit is already locally confirmed.
The unresolved question is why final error remains large and no variant reaches 1mV settling within 90us.
```

E020 settling audit outline:

```text
Run B0, B3, and R1-U1 with longer stop times:
  0.8ms
  1ms
  2ms

Log:
  Vout average
  I_Lsum average
  Iload actual
  Ton_actual_i
  event density
  comparator / integrator state
  fast_req_state
  Ton_boost_state
  fallback_to_nominal state

Classify:
  SETTLING_TIME_INSUFFICIENT
  STEADY_STATE_BIAS
  MODEL_OR_MEASUREMENT_ISSUE
  CONTROL_LIMITATION
```

Do not run the audit in this task.

Guardrails for the future audit:

```text
start from a derived copy of:
  E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx

do not modify the baseline model directly
write a hypothesis block before running
generate metrics CSV and Markdown report
do not claim hardware/HIL/board/silicon validation
```
