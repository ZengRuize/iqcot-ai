# E010-A5-R3 Hypothesis

Date: 2026-07-01

The previous A5 failures occurred because reentry control was implemented as pulse blocking, burst counting, or scheduler gating. These methods either allow pulse clustering or starve recovery energy.

A5-R3 should treat reentry as an event-queue energy-allocation problem: each accepted request is either served, deferred, resized, or released later with bounded Ton allocation and explicit accounting.

The controller should preserve enough recovery energy to avoid undershoot collapse, but prevent too much clustered energy from creating post-reentry bursts.

Fixed case: external `40A -> 1A` load-current drop, fixed four phases, nominal DCR/sense, active Lambda disabled, active-phase add/shed disabled. The load-current transition remains an external disturbance, not an AI action.
