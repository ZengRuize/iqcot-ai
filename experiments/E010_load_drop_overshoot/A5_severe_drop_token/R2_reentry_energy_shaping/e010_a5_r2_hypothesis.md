# E010-A5-R2 Hypothesis

Date: 2026-07-01

The A5-T4-R1 failure occurred because scheduler release was treated as pulse counting. This prevented or clustered recovery energy in a way that either violated the burst guard or caused severe undershoot collapse.

A5-R2 should shape the reentry energy per accepted event: not just how many pulses are allowed, but how much Ton/area each reentry event is allowed to inject, how quickly the event scheduler is released, and how `area_int_i` is restored.

Fixed case: external `40A -> 1A` load-current drop, fixed four phases, nominal DCR/sense, active Lambda disabled, active-phase add/shed disabled. The load-current transition remains an external disturbance, not an AI action.
