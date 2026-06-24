# Local Audit R026 Deployable Risk Proxy

**Date**: 2026-06-20  
**Scope**: Four-phase digital IQCOT / PIS-IEK R026 deployable `T_slew` risk proxy post-processing.

## Artifacts Checked

- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy.py`
- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_report.md`
- `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv`
- `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_eval.csv`
- `E:/Desktop/codex/output/iqcot_deployable_risk_proxy_table.csv`
- `E:/Desktop/codex/output/figures/fig33_deployable_proxy_policy.svg`
- `E:/Desktop/codex/output/iqcot_integrated_research_paper.md`
- `E:/Desktop/codex/output/iqcot_claims_evidence_matrix.md`
- `E:/Desktop/codex/output/iqcot_pis_iek_derivation_package.md`
- `E:/Desktop/codex/output/iqcot_ai_supervisor_validation_design.md`
- `E:/Desktop/codex/research-wiki/experiments/deployable-risk-proxy.md`

## Execution Check

Ran:

```text
C:/Users/zengruize/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe output/iqcot_deployable_risk_proxy.py
```

The script completed successfully. `matplotlib` was unavailable in the bundled Python, so the script used its fallback SVG writer. No packages were installed and no `.slx` model was modified.

## Numeric Consistency

Values re-read from `E:/Desktop/codex/output/iqcot_deployable_proxy_policy_summary.csv`:

| Policy | n cases | mean regret | max regret |
|---|---:|---:|---:|
| posterior mode-aware projection | 45 | 0.0639075652 | 0.2347572960 |
| calibrated risk proxy projection | 45 | 0.1186906970 | 0.3550054799 |
| discrete dense-long table | 45 | 0.1626204304 | 0.4896433099 |
| naked smooth continuous | 45 | 0.6542736148 | 2.4292769244 |
| parametric proxy only | 45 | 0.8570752731 | 2.4064673178 |

These match the report, integrated paper, evidence matrix, derivation package, and AI-supervisor validation design.

## Claim Boundary Check

Searched the updated documents for over-claim patterns around:

- `T_slew` global optimum
- AI replacing the IQCOT inner loop
- hardware proof / hardware validation
- completed neural-network AI-in-loop claims

Hits were boundary statements such as “不声称” or explicit non-claims. No positive over-claim was found.

## Wiki Check

Added and verified:

- `exp:deployable-risk-proxy`
- `idea:iqcot-pis-iek-four-phase --tested_by--> exp:deployable-risk-proxy`
- `exp:deployable-risk-proxy --supports--> claim:objective-sensitive-ref-slew`

The support edge is explicitly qualified in evidence: R026 supports a deployable proxy interface, not hardware AI-in-loop.

`research-wiki/query_pack.md` now includes the R026 status in the project direction section. The helper still truncates recent relationships aggressively, but the latest R026 state is visible near the top of the generated pack.

## Verdict

**PASS with scope warning.**

R026 is internally consistent and useful as a deployable-interface design step. The calibrated risk proxy improves offline replay ranking over the dense-long table and naked smooth continuous policy, while remaining weaker than the posterior mode-aware upper bound. The result should be written as a cautious interface contribution:

```text
posterior mode metrics -> calibrated/short-horizon r_hat(z,T_slew) -> safety projection
```

It must not be written as cross-load generalization, hardware safety proof, global `T_slew` optimality, or completed neural-network AI-in-loop validation.

## Recommended Next Step

Use only the derived model `E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx` to run a small table-in-loop validation of:

- fixed reference slew baselines,
- dense-long table,
- calibrated risk proxy projection,
- posterior upper-bound candidate for comparison only,

under `tau_AI = 0/0.5/1/2/5 us`. The main question is whether the R026 offline ordering survives parameter submission delay in the derived switching model.
