# Citation Scaffold

Date: 2026-07-01
Branch: `codex/manuscript-evidence-package`

Do not fabricate citations. Each row records the statement needing citation, any repository source already known, and whether a missing external citation is needed.

| Topic | Statement needing citation | Candidate source already in repository, if known | Missing citation needed | Manuscript section |
|---|---|---|---|---|
| COT / constant-on-time control | COT control regulates output voltage by event-triggered on-time pulses and variable switching frequency | `docs/theory/01_iqcot_inner_loop.md`; `docs/theory/02_bidirectional_large_signal_model.md` | MISSING_CITATION | Related Work; Baseline |
| IQCOT / inverse charge COT modeling | IQCOT can be modeled as a deterministic event/area or inverse-charge driven pulse generator | `docs/theory/01_iqcot_inner_loop.md` | MISSING_CITATION | Related Work; Baseline |
| multiphase COT and phase overlap | Multiphase interleaving requires event spacing and phase-order integrity to avoid ripple/order issues | `docs/theory/03_pis_iek_small_signal_model.md`; E040 summaries | MISSING_CITATION | Related Work; `a_N` |
| digital COT implementation and sampling effects | Digital event paths can lose narrow requests if sampled or serialized incorrectly | E030/E040 implementation notes | MISSING_CITATION | Related Work; Limitations |
| current-mode / current-sharing in multiphase buck | Per-phase current sharing is sensitive to DCR, sense gain, and calibration | E030 summaries and metrics | MISSING_CITATION | Related Work; `a_S` |
| active-phase management in multiphase converters | Phase add/shed can improve operating flexibility but requires dwell, residual-current, and transition guards | E040-A-R1 and E040-S1 summaries | MISSING_CITATION | Related Work; `a_N` |
| AI / learning-assisted power converter supervision | Learning/table supervisors can choose high-level parameters but need safety bounds in power converters | `docs/theory/04_ai_action_space_and_projection.md` | MISSING_CITATION | Introduction; Method |
| safety projection / constrained supervisory control | Raw supervisory actions should be projected onto a safe feasible set before reaching plant parameters | `docs/theory/04_ai_action_space_and_projection.md`; claim boundary register | MISSING_CITATION | Method; Claim Boundaries |

Citation task boundary:

```text
This scaffold identifies citation needs only.
It does not invent authors, titles, venues, DOIs, or publication years.
```
