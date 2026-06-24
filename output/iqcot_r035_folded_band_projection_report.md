# R035 Folded-Band Deployable Projection

## Scope

R035 does not run new `.slx` simulations.  It consolidates R031, R033 and
R034 derived-Simulink evidence into a reviewer-ready supervisory projection
rule.  The central correction is that the R034 sequence
`38/46/50/54/46us` is a best sequence **inside the transition-candidate
set**, not a proof that dense fallback can be replaced at every delay.

## Folded Candidate Band

R034 full validation supports a local folded transition band for
`20A/score_settle005`:

| tau_ai_us | best_slew_us | best_score | second_best_slew_us | second_best_regret | bad_skip_candidates | long_settle_candidates |
| --- | --- | --- | --- | --- | --- | --- |
| 1.000 | 38.000 | 2.221 | 46.000 | 2.155 | 4.000 | 0.000 |
| 1.250 | 46.000 | 2.146 | 38.000 | 0.189 | 1.000 | 3.000 |
| 1.500 | 50.000 | 2.141 | 38.000 | 0.205 | 0.000 | 1.000 |
| 1.750 | 54.000 | 2.142 | 38.000 | 0.159 | 1.000 | 2.000 |
| 2.000 | 46.000 | 2.274 | 50.000 | 0.027 | 0.000 | 2.000 |

This band is shaped by two different risks.  On the short-delay side,
longer candidates trigger skip.  On the long-delay side, longer candidates
become settling-limited.  The result is folded rather than monotonic.

## Dense-Inclusive Deployable Projection

| tau_ai_us | evidence_scope | folded_candidate_us | dense_fallback_us | deployable_commit_us | deployment_status |
| --- | --- | --- | --- | --- | --- |
| 0.500 | R031 dense-inclusive held-out | 50.000 | 30.000 | 50.000 | validated_commit |
| 0.750 | R033 boundary validation |  | 30.000 | 30.000 | validated_commit |
| 1.000 | R031 + R034 dense-inclusive validation | 38.000 | 30.000 | 38.000 | validated_commit |
| 1.250 | R034 transition-only validation | 46.000 |  |  | candidate_only_pending_dense_pair |
| 1.500 | R033 anchor + R031 dense-inclusive validation | 50.000 | 30.000 | 50.000 | validated_commit |
| 1.750 | R034 transition-only validation | 54.000 |  |  | candidate_only_pending_dense_pair |
| 2.000 | R031 dense fallback + R034 transition probes | 46.000 | 30.000 | 30.000 | fallback_overrides_transition_probe |
| 3.000 | R033 boundary validation |  | 30.000 | 30.000 | validated_commit |
| 5.000 | R031 dense-inclusive held-out | 58.000 | 30.000 | 30.000 | validated_commit |

The important reviewer-facing update is at `tau_AI=2us`: R034 identifies
`46us` as the best transition probe, but R031 dense-inclusive evidence keeps
`30us` as the safer deployable fallback.  Therefore the deployable interface
should be written as `q_phi` candidate generation plus `r_hat` risk estimation
plus `B_epsilon^sw` projection, not as direct AI/proxy override.

## Rule Table

| context | candidate_band_us | plant_commit_rule | risk_gate | claim_boundary |
| --- | --- | --- | --- | --- |
| 10A / score_settle010 | 30-34 | dense 30us remains acceptable; 32/33us are near-tie candidates under long delay | do not call a sharp optimum; check skip and phase std before choosing non-dense | local near-tie band, not global optimum |
| 20A / base | 80 fallback; 82/84/86 probes | keep 80us as default plant fallback; 86us is objective-dependent probe only | settling-aware objectives or longer-delay rows can reverse the 86us advantage | probe evidence, not generic unblocking of 86us |
| 20A / score_settle005 | folded probes 38/46/50/54/46us over tau=1.0-2.0; dense 30us fallback remains active | commit only where dense-inclusive evidence exists; otherwise keep candidate-only and require paired validation | block 66us direct override; reject candidates with skip or long-settling risk | folded candidate band, not full deployable optimum sequence |

## Reviewer Claim Audit

| claim_area | audit_status | safe_wording |
| --- | --- | --- |
| R034 folded sequence | tightened | Within the R034 transition-candidate set, the observed best sequence is 38/46/50/54/46us; dense fallback must still be co-tested before plant commit. |
| 20A score_settle005 tau=2us | tightened | R034 shows 46us is best among transition probes at tau=2us, but R031 dense-inclusive evidence keeps 30us as the safer fallback. |
| AI/proxy deployment | kept_guardrail | The supervisor can generate candidate scores and risks, but the final T_slew must pass B_epsilon^sw and derived-Simulink/HIL validation. |
| validation scope | kept_guardrail | R030-R034 are derived-Simulink/post-processing evidence for local policy refinement, not hardware validation or global optimum proof. |

## Scientific Boundary

- AI remains a supervisory parameter scheduler and does not replace the IQCOT
  inner event loop.
- The folded band is local to the current four-phase derived model and tested
  objectives; it is not a global optimum statement for `T_slew`.
- Derived-Simulink and post-processing evidence are not hardware or HIL
  validation.
- PIS-IEK should be claimed as an event-risk and projection framework, not as
  an exact predictor of the first large cut-load voltage peak.
