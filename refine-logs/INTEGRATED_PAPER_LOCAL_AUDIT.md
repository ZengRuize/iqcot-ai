# Integrated Paper Local Audit

## Verdict

WARN, but acceptable as a research draft.

The integrated draft is internally consistent after one numeric correction. It is not submission-ready as a final journal paper because the AI-delay evidence is still an event-domain surrogate and the reference-slew optimum is only a five-point Simulink grid result.

## Files Audited

- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`

## Raw Evidence Files Checked

- `E:/Desktop/codex/output/iqcot_dynamic_load_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_best_summary.csv`
- `E:/Desktop/codex/output/iqcot_dynamic_ref_slew_summary.csv`
- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_summary.csv`
- `E:/Desktop/codex/output/iqcot_ai_delay_event_surrogate_report.md`

## Quantitative Checks

| Claim | Evidence | Status |
|---|---|---|
| near-0A instant undershoot `35.750 mV` | `iqcot_dynamic_load_summary.csv`, dynamic_instant, target `0.001A`: `35.7504772412017` | rounding_ok |
| near-0A hold final error `+4.413 mV` | `iqcot_dynamic_load_summary.csv`, dynamic_hold, target `0.001A`: `4.41337295806421` | rounding_ok |
| ref slew best `40 us` for all three load steps | `iqcot_dynamic_ref_slew_best_summary.csv`: `40`, `40`, `40` | exact_match |
| ref slew near-0A undershoot `10.897 mV` | best summary: `10.897` | exact_match |
| ref slew near-0A final error `-0.569 mV` | best summary: `-0.569` | exact_match |
| tau=5us zero-delay violations `147.875` | AI summary/report: `147.875` | exact_match |
| tau=5us projected violations `24.297` | AI summary/report: `24.296875` | rounding_ok |
| tau=1us delay-aware tail current `502.307 mA` | AI summary: `502.3066632866881` | corrected_and_rounding_ok |

## Scope Checks

| Risk | Draft Handling | Status |
|---|---|---|
| Overclaiming AI as replacement for IQCOT inner loop | Draft explicitly says AI should be supervisory parameter scheduler, not gate-level inner loop | PASS |
| Calling `40 us` globally optimal | Draft repeatedly says current scanned grid / five-point grid | PASS |
| Claiming PIS-IEK predicts first cut-load peak | Draft says first peak needs energy/capacitor large-signal model | PASS |
| Treating event-domain surrogate as switching-level validation | Draft labels AI-delay result as surrogate and lists this as a limitation | PASS |
| Understating remaining work | Draft lists dense `T_slew` scan, AI-in-loop Simulink, HIL/hardware as open work | PASS |

## Main Remaining Weaknesses

1. The integrated draft cites literature from the v7 reference list but does not yet contain verified BibTeX entries.
2. The AI-delay result is still a surrogate. It is appropriate for training-environment motivation, not for a final hardware-performance claim.
3. The reference-slew scan has only five slew values. It supports `T_slew` as a meaningful action, but not the exact optimum.
4. The dynamic load model validates cut-load behavior in copied Simulink models, but not in a physical prototype.

## Recommended Next Experiment

Run a denser reference-slew scan around the current best region:

```text
T_slew = 20, 30, 40, 50, 60, 80 us
cut-load = 40A->20A, 40A->10A, 40A->near-0A
metrics = undershoot, final error, skip count, phase std, current imbalance, score
```

This is the highest-value next step because it directly strengthens the newest Simulink-backed contribution without requiring full AI-in-the-loop integration.
