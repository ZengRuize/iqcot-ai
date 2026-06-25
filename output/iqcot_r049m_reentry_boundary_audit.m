function outputs = iqcot_r049m_reentry_boundary_audit()
%IQCOT_R049M_REENTRY_BOUNDARY_AUDIT Audit upstream release-trigger candidates.
%
% This is a read-only structural audit.  It loads the R049L repair derived
% model, verifies the request/scheduler trigger chain, and writes a candidate
% table for the next controlled-reentry design.  It does not save or modify
% any .slx model.

modelFile = "E:\Desktop\codex\output\cutload_pr_ecb_control\four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx";
[~, model] = fileparts(modelFile);
outDir = "E:\Desktop\codex\output\cutload_pr_ecb_control";
if ~exist(outDir, "dir")
    mkdir(outDir);
end

if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(modelFile);
cleanup = onCleanup(@() close_system(model, 0)); %#ok<NASGU>

chain = verifyTriggerChain(model);
candidates = buildCandidateTable(model, chain);

csvPath = fullfile(outDir, "r049m_reentry_boundary_candidates.csv");
reportPath = fullfile(outDir, "r049m_reentry_boundary_audit_report.md");
writetable(candidates, csvPath);
writeReport(reportPath, candidates, chain);

outputs = struct("candidate_csv", csvPath, "report", reportPath);
fprintf("R049M_BOUNDARY_CANDIDATES=%s\n", csvPath);
fprintf("R049M_BOUNDARY_REPORT=%s\n", reportPath);
fprintf("R049M_DECISION=MODEL_REVISED\n");
end

function chain = verifyTriggerChain(model)
chain = struct();
chain.allow_goto_path = model + "/Goto16";
chain.allow_goto_tag = string(get_param(chain.allow_goto_path, "GotoTag"));
chain.scheduler_path = model + "/PhaseScheduler_4Phase";
chain.scheduler_trigger_source = describeTriggerSource(chain.scheduler_path);
chain.scheduler_trigger_type = string(get_param(chain.scheduler_path + "/Trigger", "TriggerType"));
chain.scheduler_states_when_enabling = string(get_param(chain.scheduler_path + "/Trigger", "StatesWhenEnabling"));
chain.phase_state_path = chain.scheduler_path + "/phase_state";
chain.phase_state_sample_time = string(get_param(chain.phase_state_path, "SampleTime"));
chain.phase_state_initial_condition = string(get_param(chain.phase_state_path, "InitialCondition"));
chain.allow_source = describeInportSource(chain.allow_goto_path, 1);
end

function candidates = buildCandidateTable(model, chain)
candidate_id = [
    "C1";
    "C2";
    "C3";
    "C4";
    "C5";
    "C6";
    "C7";
    "C8"
];
signal = [
    "req_global";
    "existing_allow";
    "Allow rising / tr";
    "PhaseScheduler phase_state";
    "phase_idx outport";
    "phase_en1..4 / tr1..4";
    "downstream qh1";
    "independent phase-clock / predicted slot"
];
model_path = [
    model + "/Goto14";
    chain.allow_source;
    chain.scheduler_trigger_source;
    chain.phase_state_path;
    chain.scheduler_path + "/phase_idx";
    chain.scheduler_path + "/phase_en1..4 then Goto18..21";
    model + "/GateDriver_1Phase1";
    "<not present in model yet>"
];
relation_to_allow_gate = [
    "Upstream comparator request into existing allow logic.";
    "Immediate upstream input to R049L_Gate_And.";
    "Generated from Allow after R049L_Gate_And and Detect Rise Positive.";
    "Inside PhaseScheduler triggered by Allow rising.";
    "Outport driven by PhaseScheduler phase_state.";
    "Phase enables and per-phase triggers downstream of PhaseScheduler.";
    "Gate-driver output downstream of scheduler and request gate.";
    "Would be generated independently from time / scheduler-slot prediction."
];
upstream_of_r049l_gate = [
    true;
    true;
    false;
    false;
    false;
    false;
    false;
    true
];
continues_during_inhibit = [
    true;
    true;
    false;
    false;
    false;
    false;
    false;
    true
];
phase_boundary_semantics = [
    false;
    false;
    true;
    true;
    true;
    true;
    true;
    true
];
causal_release_candidate = [
    false;
    false;
    false;
    false;
    false;
    false;
    false;
    true
];
evidence = [
    "R049L old run showed req_global fired near 0.5-0.6 us, earlier than the R049K qh1 boundary; it is a comparator event, not scheduler phase boundary.";
    "existing_allow is req_global AND GlobalReady before R049L_Gate_And; useful as input to gate, but not a phase slot.";
    "From16(tag=Allow) feeds Detect Rise Positive, which writes Goto17(tag=tr); scheduler trigger is From18(tag=tr), so this is downstream of the gate.";
    "phase_state is a Unit Delay inside a triggered subsystem; it updates only on tr/Allow rising and freezes when requests are inhibited.";
    "phase_idx is just the exposed outport of phase_state; useful for logging/effects, not causal release during inhibit.";
    "phase_en and tr1..tr4 are scheduler outputs gated with tr; downstream of Allow and unavailable as independent release causes.";
    "R049L repair proved qh1 rising never occurs during inhibit: one_shot_edge_count=0, one_shot_time_us=NaN.";
    "Not present yet, but it is the only audited class that can remain upstream and evolve while request-path gating suppresses scheduler pulses."
];
verdict = [
    "Reject for R049M release trigger.";
    "Reject for release trigger.";
    "Reject; downstream of gate.";
    "Reject; freezes during inhibit.";
    "Reject as cause; keep as logged effect.";
    "Reject; downstream.";
    "Reject; circular dependency already observed.";
    "Promote to next minimal design candidate."
];
required_next_action = [
    "Log only if needed for comparator diagnostics.";
    "May keep as gate input, not release source.";
    "Use only to explain why scheduler freezes.";
    "Use as evidence that scheduler has no independent clock.";
    "Log as effect and phase recovery metric.";
    "Log as effect only.";
    "Do not reuse as causal release.";
    "Build a new derived model with a read-only/upstream phase-clock or predicted-slot tap, then run the same 4-row A0/A2 chunk."
];

candidates = table(candidate_id, signal, model_path, relation_to_allow_gate, ...
    upstream_of_r049l_gate, continues_during_inhibit, phase_boundary_semantics, ...
    causal_release_candidate, evidence, verdict, required_next_action);
end

function s = describeTriggerSource(blockPath)
ports = get_param(blockPath, "PortHandles");
if isempty(ports.Trigger)
    s = "<no trigger port>";
    return;
end
line = get_param(ports.Trigger(1), "Line");
if line == -1
    s = "<unconnected trigger>";
    return;
end
src = get_param(line, "SrcPortHandle");
s = string(getfullname(get_param(src, "Parent"))) + "/" + string(get_param(src, "PortNumber"));
end

function s = describeInportSource(blockPath, portNumber)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Inport) < portNumber
    s = "<no inport>";
    return;
end
line = get_param(ports.Inport(portNumber), "Line");
if line == -1
    s = "<unconnected>";
    return;
end
src = get_param(line, "SrcPortHandle");
s = string(getfullname(get_param(src, "Parent"))) + "/" + string(get_param(src, "PortNumber"));
end

function writeReport(path, candidates, chain)
fid = fopen(path, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, "# R049M PR-ECB Reentry Upstream Boundary Audit\n\n");
fprintf(fid, "Date: 2026-06-25\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Read-only structural audit of `four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry.slx`.\n");
fprintf(fid, "No new switching simulation was run and no `.slx` model was saved.\n\n");
fprintf(fid, "## Verified trigger chain\n\n");
fprintf(fid, "- Allow Goto: `%s` tag `%s`\n", chain.allow_goto_path, chain.allow_goto_tag);
fprintf(fid, "- Allow source: `%s`\n", chain.allow_source);
fprintf(fid, "- Scheduler trigger source: `%s`\n", chain.scheduler_trigger_source);
fprintf(fid, "- Scheduler trigger type: `%s`\n", chain.scheduler_trigger_type);
fprintf(fid, "- Scheduler state behavior: `%s`, `phase_state` sample time `%s`, initial `%s`\n\n", ...
    chain.scheduler_states_when_enabling, chain.phase_state_sample_time, chain.phase_state_initial_condition);

fprintf(fid, "The scheduler is triggered by `tr`, which is generated from the gated `Allow` path.  Therefore scheduler-internal phase state does not continue to advance while request-path inhibition is active.\n\n");
fprintf(fid, "## Candidate table\n\n");
fprintf(fid, "| Candidate | Signal | Upstream of R049L gate | Evolves during inhibit | Phase-boundary semantics | Causal release candidate | Verdict |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---|\n");
for k = 1:height(candidates)
    fprintf(fid, "| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | %s |\n", ...
        candidates.candidate_id(k), candidates.signal(k), yn(candidates.upstream_of_r049l_gate(k)), ...
        yn(candidates.continues_during_inhibit(k)), yn(candidates.phase_boundary_semantics(k)), ...
        yn(candidates.causal_release_candidate(k)), candidates.verdict(k));
end

fprintf(fid, "\n## Decision\n\n");
fprintf(fid, "```text\nMODEL_REVISED\n```\n\n");
fprintf(fid, "R049L repair remains `IMPLEMENTATION_ISSUE`, but this structure audit identifies the next viable design class: an independent upstream phase-clock / predicted scheduler-slot trigger.  Existing scheduler outputs (`phase_state`, `phase_idx`, `phase_en`, `tr1..4`) are not valid causal release triggers because they are downstream of the gated `Allow` trigger and freeze during inhibit.\n\n");
fprintf(fid, "## Next minimal design\n\n");
fprintf(fid, "Build a new derived copy that adds an upstream phase-clock / predicted-slot one-shot trigger.  Calibrate its first release boundary against the R049K observed qh1 release region around `1.678-1.690 us`, then run only the same four-row `40A -> 20A` chunk with the R049H three-window audit.\n");
end

function out = yn(x)
if x
    out = "yes";
else
    out = "no";
end
end
