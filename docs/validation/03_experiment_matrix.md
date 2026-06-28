# Experiment Matrix

## E001 Baseline Audit

Purpose: confirm the local ideal IQCOT baseline wiring, logged signals, solver settings, and original A0/B0/C0/D0 behavior before any derived-model claims.

Baseline:

```text
E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx
```

Outputs:

- wiring audit report;
- baseline metrics CSV;
- baseline Markdown summary;
- list of missing signals to add only in derived copies.

## E010 Load-Drop Overshoot Validation

Compare:

```text
A0 original ideal IQCOT
A1 Ton truncation only
A2 Ton truncation + pulse inhibit
A3 Ton truncation + pulse inhibit + controlled reentry
A4 AI/table selected a_O
```

Test:

```text
40A -> 20A
40A -> 10A
40A -> 1A
120A -> 40A
120A -> 10A
```

Metrics:

```text
peak overshoot
early local peak 0-2us
recovery peak 2-12us
late settling 12-80us
undershoot penalty
reentry time
skip count
final error
```

Current status:

```text
40A -> 10A completed for A0-A4
40A -> 20A completed for A0-A4
40A -> 1A completed for A0/A4
120A -> 10A A0 completed as operating-boundary check, not improvement evidence
comparison: experiments/E010_load_drop_overshoot/e010_research_summary.md
classification: MODEL_REVISED
next E010 expansion target: severe-drop a_O token for 40A -> 1A
```

## E020 Load-Rise Undershoot Validation

Compare:

```text
B0 original ideal IQCOT
B1 fast request only
B2 Ton boost only
B3 fast request + Ton boost
B4 fast request + Ton boost + phase add
B5 AI/table selected a_U
```

Test:

```text
10A -> 40A
40A -> 80A
40A -> 120A
20A -> 120A
1A -> 40A
```

Metrics:

```text
peak undershoot
current rise time
recovery overshoot
phase current peak
current limit hit
settling time
final error
```

## E030 Balance Recovery Validation

Compare:

```text
C0 original ideal IQCOT
C1 Ton_diff only
C2 Lambda_diff only
C3 Ton_diff + Lambda_diff
C4 PIS-IEK projected balancer
C5 AI/table selected a_S
```

Mismatch cases:

```text
L mismatch +/-5%
DCR mismatch +/-5/10%
Ron mismatch +/-5/10%
current-sense gain mismatch +/-2/5%
driver delay mismatch +/-5/10ns
```

Metrics:

```text
max current imbalance
RMS current imbalance
phase spacing std
output ripple
effective switching frequency
trim usage
```

## E040 Active-Phase Validation

Compare:

```text
D0 fixed 4-phase
D1 basic add/shed
D2 add/shed + overshoot/undershoot guards
D3 add/shed + PIS-IEK balance recovery
D4 AI/table selected a_N
```

Test:

```text
1A -> 40A
10A -> 120A
120A -> 10A
40A <-> 120A repeated
10A <-> 40A repeated
slow ramp 0A -> 120A -> 0A
```

Metrics:

```text
active phase timeline
add-phase time
shed-phase time
new phase current ramp
disabled phase residual current
phase spacing recovery time
overshoot/undershoot during add/shed
switching count / efficiency proxy
```
