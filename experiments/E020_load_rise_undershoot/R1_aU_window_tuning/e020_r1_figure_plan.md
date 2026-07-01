# E020-R1 Manuscript Figure Plan

Date: 2026-07-01

## Purpose

Prepare publication-quality figure scaffolding for the frozen E020/E020-R1 `a_U` evidence. Figures must show early load-rise dynamic regulation and must not imply complete `120A` settling.

Primary data sources:

- first E020 metrics: `experiments/E020_load_rise_undershoot/e020_metrics.csv`
- E020-R1 metrics: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/e020_r1_metrics.csv`
- R1 waveform samples: `experiments/E020_load_rise_undershoot/R1_aU_window_tuning/r1_u1_wave_sample.csv`

## Figure E020-1: Vout Load-Rise Transient

Curves:

```text
B0
B3
R1-U1
```

Time windows:

```text
step time: 450 us
early window: 0-5 us after step
extended window: 0-90 us after step
```

Annotations:

- peak undershoot;
- final error at the end of the post-step window;
- no `1 mV` settling within the tested window.

Caption claim:

```text
Fast request plus Ton boost reduces the early peak undershoot, while R1-U1
preserves and slightly refines the early response. The panel also shows that
the tested variants do not demonstrate complete 120A settling.
```

Do not label any curve as "settled" or "full recovery."

## Figure E020-2: Inductor-Current Sum / Phase Current

Curves:

```text
I_Lsum for B0/B3/R1-U1
optional IL1..IL4 for R1-U1
```

Annotations:

- 90% current-rise time;
- phase-current peak;
- current limit not hit.

Caption claim:

```text
The a_U token accelerates the early current-building trajectory without
violating the tested phase-current limit.
```

## Figure E020-3: a_U Action Timing

Curves or event markers:

```text
fast_req_state
Ton_boost_state
Ton_boost_gain / Ton_boost_window
accepted REQ events
fallback_to_nominal_state if available
```

Purpose:

```text
show that R1-U1 preserves early energy injection while returning to nominal IQCOT
```

Caption claim:

```text
R1-U1 is a projected parameter-scheduling action, not a gate-command action:
fast request and Ton boost are active only inside the guarded early window.
```

## Figure E020-4: Compact Bar Chart

Bars:

```text
peak undershoot for B0/B1/B2/B3/R1-U1
90% current-rise time for B0/B1/B2/B3/R1-U1
final error for B0/B3/R1-U1
```

Required note:

```text
No listed variant demonstrates 1 mV settling within the tested 90 us post-step window.
```

Do not plot a "settling success" bar because all tested variants fail that condition.

## Figure Production Notes

- Use consistent colors for B0, B3, and R1-U1 across all panels.
- Put units directly in axis labels.
- Use `time after step (us)` on x-axes rather than absolute simulation time where possible.
- Mark the `1 mV` band only as a boundary reference, not as a success marker.
- Keep active Lambda and active-phase add/shed absent from this figure set.
