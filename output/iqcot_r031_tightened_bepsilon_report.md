# R031 Tightened `B_epsilon^sw` / Risk Predictor Prototype

## Scope

This is an offline post-processing prototype based on the completed R030
dense-anchor challenge.  It does not run or edit any `.slx` model.  Its purpose
is to turn R030 negative samples into a more conservative switching-calibrated
projection rule and a minimal next validation matrix.

## Policy Replay on R030 Challenge Contexts

| policy | deployability | n_contexts | mean_regret | max_regret | proxy_selected_count | unsafe_proxy_selected_count | zero_regret_context_count |
| --- | --- | --- | --- | --- | --- | --- | --- |
| r031_pair_oracle_upper_bound | non_deployable_upper_bound | 15 | 0.000 | 0.000 | 7 | 1 | 15 |
| r031_tightened_sw_projection | switching_calibrated_candidate | 15 | 0.132 | 1.688 | 3 | 0 | 11 |
| dense_anchor_baseline | deployable_baseline | 15 | 0.186 | 1.688 | 0 | 0 | 8 |
| r031_small_delta_only | candidate_rule | 15 | 0.189 | 1.688 | 5 | 1 | 9 |
| direct_proxy_override | deployable_negative_control | 15 | 0.574 | 2.793 | 15 | 5 | 7 |

Direct proxy override remains unsafe on this challenge set: mean regret
`0.574` versus dense-anchor `0.186`.
A naive small-delta rule (`<=2us`) gives mean regret `0.189`,
which is not better than dense-anchor because near-tie delay behavior is
non-monotonic.  The R031 switching-calibrated candidate blocks the high-risk
`20A/score_settle005 -> 66us` override and only permits the `10A/score_settle010`
proxy in locally observed winning subbands.  It reaches mean regret
`0.132`, but it is a calibration candidate and must be
held-out tested.  The pair oracle `0.000` is a non-deployable
lower bound.

## Tightened Projection Rules

| target_label | objective | risk_category | B_epsilon_sw_rule | allowed_proxy_condition | blocked_proxy_condition |
| --- | --- | --- | --- | --- | --- |
| 10A | score_settle010 | near_tie_delay_sensitive | local band [30,32] us; default dense; proxy only in locally verified subband | calibration candidate only: tau_AI in {0,0.5,2} us; needs held-out check | tau_AI in {1,5} us or predictor uncertainty |
| 20A | base | small_gain_delay_sensitive | block direct 86us override until intermediate 82/84us delay sweep is checked | none for deployable rule; 86us only as validation candidate | tau_AI in {0.5,2,5} us showed dense better; ranking not stable |
| 20A | score_settle005 | large_jump_settling_sensitive_negative_sample | tighten to exclude 66us direct override; require short-horizon skip/settle risk prediction | none for deployable rule; only re-admit if predictor flags low skip and low settling risk | tau_AI in {0.5,2,5} us produced large proxy regret and extra skip/settling cost |

## Minimal Follow-Up Validation Matrix

The next derived-Simulink check should be small and targeted.  It should test
intermediate slopes rather than re-run the already completed dense/proxy pairs.
The generated plan has `22` rows and is saved as
`iqcot_r031_minimal_validation_plan.csv`.

| r031_case_id | target_label | objective | tau_ai_us | candidate_ref_slew_us | reference_baseline_slew_us | priority |
| --- | --- | --- | --- | --- | --- | --- |
| R031_0001 | 10A | score_settle010 | 1.000 | 31.000 | 30.000 | 2 |
| R031_0002 | 10A | score_settle010 | 1.000 | 33.000 | 30.000 | 2 |
| R031_0003 | 10A | score_settle010 | 5.000 | 31.000 | 30.000 | 2 |
| R031_0004 | 10A | score_settle010 | 5.000 | 33.000 | 30.000 | 2 |
| R031_0005 | 20A | base | 0.500 | 82.000 | 80.000 | 2 |
| R031_0006 | 20A | base | 0.500 | 84.000 | 80.000 | 2 |
| R031_0007 | 20A | base | 2.000 | 82.000 | 80.000 | 2 |
| R031_0008 | 20A | base | 2.000 | 84.000 | 80.000 | 2 |
| R031_0009 | 20A | base | 5.000 | 82.000 | 80.000 | 2 |
| R031_0010 | 20A | base | 5.000 | 84.000 | 80.000 | 2 |
| R031_0011 | 20A | score_settle005 | 0.500 | 38.000 | 30.000 | 1 |
| R031_0012 | 20A | score_settle005 | 0.500 | 50.000 | 30.000 | 1 |

## Claim Boundary

R031 does not prove dense-anchor is globally optimal and does not prove the
proxy is useless.  It narrows the deployable interface: proxy or AI should
generate score/risk candidates, while `B_epsilon^sw` blocks unverified override
actions unless short-horizon event risk prediction can justify them.  All
evidence remains derived-Simulink or offline post-processing, not hardware
validation.
