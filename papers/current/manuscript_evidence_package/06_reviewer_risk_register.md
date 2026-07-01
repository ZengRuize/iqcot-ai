# Reviewer Risk Register

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

## Risk 1: Reviewer thinks AI claim is overblown.

Reviewer concern: The manuscript may sound like a neural controller replaces converter control.

Defensible response: The paper uses AI/table supervisor as a bounded token selector only. All actions pass safety projection before affecting IQCOT parameters.

Where to mention in manuscript: Abstract, Introduction, Fig. 1 caption, Claim Boundaries.

Needed future work: If neural policies are later used, evaluate them against the same projection and claim-boundary framework.

## Risk 2: Reviewer objects that IQCOT already has variable-frequency transient response.

Reviewer concern: The paper may appear to claim a false deficiency in IQCOT.

Defensible response: The paper explicitly preserves IQCOT as the deterministic fast variable-frequency inner loop. The contribution is supervisory augmentation around IQCOT.

Where to mention in manuscript: Abstract, Introduction, Baseline section, Fig. 2.

Needed future work: None for the current framing; keep language audit active.

## Risk 3: Reviewer asks why `a_U` does not settle to `1mV`.

Reviewer concern: E020 confirms early improvement but not late recovery.

Defensible response: The result is reported as early load-rise dynamic regulation only. The next simulation is an E020 settling audit to classify late error.

Where to mention in manuscript: Validation, Limitations, Table 3 note.

Needed future work: E020 settling audit at `0.8 ms`, `1 ms`, and `2 ms`.

## Risk 4: Reviewer asks why severe `40A -> 1A` is not solved.

Reviewer concern: The load-drop branch may look incomplete.

Defensible response: The severe branch is intentionally reported as `MODEL_REVISED` boundary evidence. Tested A5 variants did not satisfy signed energy, undershoot, burst, final-error, and phase-order guards together.

Where to mention in manuscript: Load-transient section, Limitations, Figure 4.

Needed future work: A6 structural energy-management concept, not A5-R4 tuning.

## Risk 5: Reviewer asks whether current-sense calibration is practical.

Reviewer concern: E030-R3 calibrated modes use ideal `g_hat_i = g_i`.

Defensible response: The current evidence validates the guard architecture under one ideal-calibration local case. It does not claim practical online calibration.

Where to mention in manuscript: `a_S` section, Limitations, Table 4.

Needed future work: Imperfect-calibration mini-test with residual error `1%`, `2%`, and `5%`.

## Risk 6: Reviewer asks whether add/shed generalizes.

Reviewer concern: E040-A-R1 and E040-S1 are one-point confirmations.

Defensible response: The claim is local event integrity, not broad active-phase scheduling. The paper should emphasize the confirmed state-machine mechanisms and boundaries.

Where to mention in manuscript: `a_N` section, Validation, Limitations.

Needed future work: Minimal nearby add/shed cross-check before broad grids.

## Risk 7: Reviewer asks about hardware or nonideal digital implementation.

Reviewer concern: Simulink-only evidence may not capture sampling, delay, quantization, board parasitics, or hardware constraints.

Defensible response: The manuscript states all evidence is local derived Simulink evidence and does not claim hardware, HIL, board-level, or silicon validation.

Where to mention in manuscript: Abstract, Validation, Limitations.

Needed future work: Nonideal digital sampling/ADC/comparator delay study and eventual HIL or simplified hardware validation.

## Risk 8: Reviewer asks whether active Lambda is validated.

Reviewer concern: The token definition includes Lambda-related terms.

Defensible response: Active Lambda remains disabled or side-band/logging only in current validated results. No active Lambda control claim is made.

Where to mention in manuscript: `a_S` section, Action-token table, Limitations.

Needed future work: Dedicated active Lambda experiment only after event-path safety and sampling issues are isolated.
