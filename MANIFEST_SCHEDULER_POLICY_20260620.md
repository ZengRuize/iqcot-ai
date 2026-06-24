# Scheduler Policy Update Manifest

> 本清单记录 2026-06-20 本轮 ARIS 安装确认、research-wiki 初始化与参考斜率调度器策略验证新增产物。

| Timestamp | Workflow | File | Stage | Description |
|---|---|---|---|---|
| 2026-06-20 11:30 | ARIS setup | `RESEARCH_BRIEF.md` | project-memory | 四相数字 IQCOT / PIS-IEK 研究简报，供 ARIS research-wiki 和后续自动科研读取 |
| 2026-06-20 11:32 | research-wiki | `research-wiki/` | knowledge-base | 初始化项目研究知识库，并写入 PIS-IEK idea、参考斜率 sweep experiment、objective-sensitive claim |
| 2026-06-20 11:36 | analyze-results | `output/iqcot_ref_slew_scheduler_policy_eval.csv` | results | 7 类参考斜率策略的汇总指标 |
| 2026-06-20 11:36 | analyze-results | `output/iqcot_ref_slew_scheduler_policy_eval_detail.csv` | results | 策略-负载逐工况选择和指标明细 |
| 2026-06-20 11:36 | paper-figure | `output/figures/fig25_ref_slew_scheduler_policy_eval.png` | figure | 参考斜率策略在 base score、settling-aware score 和 settling time 下的柱状图 |
| 2026-06-20 11:36 | analyze-results | `refine-logs/EXPERIMENT_RESULTS_REF_SLEW_SCHEDULER.md` | analysis | 离线调度器策略验证报告 |
| 2026-06-20 11:36 | paper-writing | `output/iqcot_ref_slew_scheduler_paper_section.md` | writing | 可插入论文第 8 节后的参考斜率调度器策略验证段落 |
| 2026-06-20 11:38 | research-refine | `output/iqcot_integrated_research_paper.md` | writing | 已接入策略验证、小结和数据清单 |
| 2026-06-20 11:38 | paper-claim-audit | `output/iqcot_claims_evidence_matrix.md` | review | 已更新 C7b 证据与允许/禁止写法 |
| 2026-06-20 11:38 | formula-derivation | `output/iqcot_pis_iek_derivation_package.md` | modeling | 已补充 `T_slew` 作为目标敏感 AI 调度量的推导解释 |
| 2026-06-20 11:40 | local-audit | `refine-logs/ARIS_INSTALL_AND_SCHEDULER_LOCAL_AUDIT_20260620.md` | audit | 本地一致性审查，最终 PASS |

