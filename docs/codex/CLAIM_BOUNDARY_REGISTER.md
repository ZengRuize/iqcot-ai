# Claim Boundary Register

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

| Claim | Evidence | Allowed Wording | Forbidden Wording | Status |
|---|---|---|---|---|
| IQCOT inner loop | Theory docs and baseline-derived evidence | Deterministic variable-frequency IQCOT inner loop is retained | IQCOT cannot regulate load transients | Frozen framing |
| `a_U` load-rise | E020 and E020-R1 | Early load-rise peak-undershoot reduction and current-rise acceleration | Full `120A` recovery / `1 mV` settling | Local confirmation |
| `a_O` load-drop | E010 medium branch and E010-A5 | Medium load-drop local projected protection and severe-drop boundary evidence | Severe `40A -> 1A` solved | Partial support plus boundary |
| `a_S` sharing | E030-R3 | One local calibration-aware current-sense mismatch guard pattern | Broad mismatch robustness / active Lambda validation | Local confirmation |
| `a_N` active phase | E040-A-R1 and E040-S1 | One local add and one local shed event-integrity confirmation | Arbitrary `1/2/4` phase scheduling or efficiency improvement | Local confirmation |
| Validation | Derived ideal Simulink reports | Derived Simulink local evidence | Hardware/HIL/board/silicon validation | Simulink-only |
| AI/table supervisor | `docs/theory/04_ai_action_space_and_projection.md` | AI/table proposes bounded tokens that pass safety projection | AI directly controls gates or external load slew | Standing guardrail |

## Frozen Core Wording

```text
The deterministic IQCOT inner loop already provides fast variable-frequency
voltage regulation. The proposed work does not replace the IQCOT inner loop and
does not claim that IQCOT cannot respond to load transients. The contribution is
a safety-projected supervisory layer for bounded action-token selection around
IQCOT.
```
