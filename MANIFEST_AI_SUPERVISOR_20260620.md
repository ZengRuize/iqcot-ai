# AI Supervisor Update Manifest

> 本清单记录 2026-06-20 心跳继续推进阶段新增的 AI 监督层训练接口与验证设计产物。

| Timestamp | Workflow | File | Stage | Description |
|---|---|---|---|---|
| 2026-06-20 12:02 | analyze-results | `output/iqcot_ai_supervisor_training_targets.csv` | results | 3 个切载目标 × 3 个目标权重 × 5 个 FPGA 延迟上下文，共 45 行 `T_slew` 监督标签 |
| 2026-06-20 12:02 | analyze-results | `output/iqcot_ai_supervisor_training_targets.md` | analysis | 训练标签表说明，强调 `tau_AI` 是部署上下文特征 |
| 2026-06-20 12:05 | experiment-plan | `output/iqcot_ai_supervisor_validation_design.md` | planning | AI/table-in-loop 监督层验证设计，含 V1-V5 验证矩阵 |
| 2026-06-20 12:05 | paper-writing | `output/iqcot_ai_delay_ref_slew_paper_section.md` | writing | 可并入论文的延迟感知 AI 监督层训练接口段落 |
| 2026-06-20 12:05 | tracking | `refine-logs/EXPERIMENT_TRACKER_R019_AI_SUPERVISOR_VALIDATION_DESIGN.md` | tracking | R019 实验追踪补充，状态为 DESIGN_DONE |
| 2026-06-20 12:08 | research-wiki | `research-wiki/experiments/ai-supervisor-training-interface.md` | knowledge-base | 将训练接口作为 partial experiment 写入项目研究知识库 |
| 2026-06-20 12:10 | local-audit | `refine-logs/AI_SUPERVISOR_TRAINING_INTERFACE_AUDIT_20260620.md` | audit | 本地一致性审查，最终 PASS |

