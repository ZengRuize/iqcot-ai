function rows = iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(runSimulink, maxCases, startRow)
%IQCOT_R049L_REPAIR_PR_ECB_CONTROLLED_REENTRY_CHUNK Run phase-boundary controlled-reentry chunk.
%
% Dry run:
%   iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(false)
%
% True run:
%   iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(true)
%
% Scope: same R049I 40A->20A two-offset chunk. A2 uses phase-boundary (qh1 rising
% edge) one-shot controlled-reentry proxy. Ton truncation disabled for both A0/A2.
% R049K-compatible operating parameters restored.

clc;

if nargin < 1 || isempty(runSimulink), runSimulink = false; end
if nargin < 2 || isempty(maxCases), maxCases = []; end
if nargin < 3 || isempty(startRow), startRow = 1; end
startRow = max(1, round(double(startRow)));

setappdata(0, "iqcot_r049l_repair_run_simulink", runSimulink);
setappdata(0, "iqcot_r049l_repair_max_cases", maxCases);
setappdata(0, "iqcot_r049l_repair_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r049l_repair_run_simulink");
maxCases = getappdata(0, "iqcot_r049l_repair_max_cases");
startRow = getappdata(0, "iqcot_r049l_repair_start_row");
rmappdata(0, "iqcot_r049l_repair_run_simulink");
rmappdata(0, "iqcot_r049l_repair_max_cases");
rmappdata(0, "iqcot_r049l_repair_start_row");

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
outputRoot = "E:\Desktop\codex\output";
dataRoot = fullfile(outputRoot, "data");
chunkRoot = fullfile(outputRoot, "cutload_pr_ecb_control");
if ~exist(dataRoot, "dir"), mkdir(dataRoot); end
if ~exist(chunkRoot, "dir"), mkdir(chunkRoot); end
addpath(outputRoot);
addpath(srcRoot);

localVars = whos;
for varIdx = 1:numel(localVars)
    varName = localVars(varIdx).name;
    if varName ~= "localVars" && varName ~= "varIdx"
        assignin("base", varName, eval(varName));
    end
end

modelFile = iqcot_r049l_repair_build_controlled_reentry_model();
[~, model] = fileparts(modelFile);

fullPlan = buildPlan();
planPath = fullfile(chunkRoot, "r049l_repair_controlled_reentry_plan.csv");
writetable(fullPlan, planPath);

fullPlanHeight = height(fullPlan);
if startRow > fullPlanHeight
    error("startRow %d exceeds plan height %d.", startRow, fullPlanHeight);
end
if isempty(maxCases)
    endRow = fullPlanHeight;
else
    endRow = min(fullPlanHeight, startRow + round(double(maxCases)) - 1);
end
plan = fullPlan(startRow:endRow, :);
runLabel = makeRunLabel(startRow, endRow, fullPlanHeight);

if ~runSimulink
    rows = plan;
    writeDryRunReport(chunkRoot, planPath, modelFile);
    fprintf("R049L_REPAIR_CONTROLLED_REENTRY_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run the phase-boundary controlled-reentry chunk:\n");
    fprintf("  iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(true)\n");
    return;
end

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(modelRoot);

load_system(modelFile);
modelCleanup = onCleanup(@() close_system(model, 0)); %#ok<NASGU>
instrumentSignals(model);

common = makeCommon();
rows = table();
for k = 1:height(plan)
    spec = makeSpec(plan(k, :), common);
    fprintf("R049L repair case %s: %s, %.1f A -> %.3f A, offset %.3f us, delay %.3f us\n", ...
        string(spec.case_id), string(spec.controller), spec.base_load_A, spec.load_A, ...
        spec.load_step_offset_us, spec.post_inhibit_delay_us);
    try
        out = runCase(model, spec);
        row = metricsRowFromLogs(plan(k, :), spec, common, out.logsout, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R049LRepairControlledReentryCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(chunkRoot, "r049l_repair_controlled_reentry_results_" + runLabel + ".csv");
comparisonPath = fullfile(chunkRoot, "r049l_repair_controlled_reentry_comparison_" + runLabel + ".csv");
reportPath = fullfile(chunkRoot, "r049l_repair_controlled_reentry_report_" + runLabel + ".md");
writetable(rows, resultPath);
comparison = compareControllers(rows);
writetable(comparison, comparisonPath);
decision = diagnoseDecision(rows, comparison);
writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel);

fprintf("R049L_REPAIR_CONTROLLED_REENTRY_RESULTS=%s\n", resultPath);
fprintf("R049L_REPAIR_CONTROLLED_REENTRY_COMPARISON=%s\n", comparisonPath);
fprintf("R049L_REPAIR_CONTROLLED_REENTRY_REPORT=%s\n", reportPath);
fprintf("R049L_REPAIR_DECISION=%s\n", decision);
end

function plan = buildPlan()
case_id = [
    "r049l_repair_20A_off0p050_a0";
    "r049l_repair_20A_off0p050_a2_one_shot";
    "r049l_repair_20A_off0p105_a0";
    "r049l_repair_20A_off0p105_a2_one_shot"
];
controller = [
    "A0_no_inhibit";
    "A2_one_shot_reentry";
    "A0_no_inhibit";
    "A2_one_shot_reentry"
];
target_label = repmat("20A", numel(case_id), 1);
base_load_A = 40 * ones(numel(case_id), 1);
target_load_A = 20 * ones(numel(case_id), 1);
load_drop_A = base_load_A - target_load_A;
load_step_offset_us = [0.050; 0.050; 0.105; 0.105];
tau_ai_us = 1.25 * ones(numel(case_id), 1);
selected_ref_slew_us = 60 * ones(numel(case_id), 1);
trigger_mode = [
    "disabled_negative_window";
    "one_shot_phase_boundary_reentry";
    "disabled_negative_window";
    "one_shot_phase_boundary_reentry"
];
tton_trunc_min_ns = 196.5 * ones(numel(case_id), 1);
tton_trunc_window_us = -0.001 * ones(numel(case_id), 1);
post_inhibit_delay_us = [0.070; 0.070; 0.070; 0.070];
post_inhibit_window_us = [-0.001; 1.690; -0.001; 1.690];
delta_v_allow_mV = 10 * ones(numel(case_id), 1);
objective = repmat("r049l_repair_controlled_reentry_proxy", numel(case_id), 1);
role = [
    "baseline_same_model";
    "one_shot_phase_boundary_reentry";
    "baseline_same_model";
    "one_shot_phase_boundary_reentry"
];
plan = table(case_id, controller, target_label, objective, role, trigger_mode, ...
    base_load_A, target_load_A, load_drop_A, load_step_offset_us, tau_ai_us, ...
    selected_ref_slew_us, tton_trunc_min_ns, tton_trunc_window_us, ...
    post_inhibit_delay_us, post_inhibit_window_us, delta_v_allow_mV);
end

function runLabel = makeRunLabel(startRow, endRow, fullPlanHeight)
if startRow == 1 && endRow == fullPlanHeight
    runLabel = "full";
else
    runLabel = sprintf("rows%03d_%03d", startRow, endRow);
end
end

function common = makeCommon()
% R049K-compatible operating parameters (FIXED from old R049L)
common = struct();
common.lambdaArea = 6e-10;
common.vAreaBias = 2e-3;
common.riArea = 0.5e-3;
common.baseTStep = 0.45e-3;
common.postStepDuration = 0.150e-3;
common.maxStep = "5e-9";
common.fastTss = 5e-9;
common.preWindow = 2e-6;
common.peakWindow = 80e-6;
common.finalWindow = 10e-6;
if evalin("base", "exist('Vo_ref','var')")
    common.voRef = evalin("base", "Vo_ref");
else
    common.voRef = 1.0;
end
end

function spec = makeSpec(planRow, common)
% R049K-compatible makeSpec (FIXED from old R049L)
spec = struct();
spec.case_id = string(planRow.case_id);
spec.controller = string(planRow.controller);
spec.target_label = string(planRow.target_label);
spec.objective = string(planRow.objective);
spec.role = string(planRow.role);
spec.trigger_mode = string(planRow.trigger_mode);
spec.base_load_A = planRow.base_load_A;
spec.load_A = planRow.target_load_A;
spec.load_drop_A = planRow.load_drop_A;
spec.load_step_offset_us = planRow.load_step_offset_us;
spec.t_load_step_s = common.baseTStep + spec.load_step_offset_us * 1e-6;
spec.stopTime = spec.t_load_step_s + common.postStepDuration;
spec.Iph_initial = spec.base_load_A / 4;
spec.Iph_final = spec.load_A / 4;
spec.Iph = spec.Iph_final;
spec.ref_slew_us = planRow.selected_ref_slew_us;
spec.ref_slew_s = spec.ref_slew_us * 1e-6;
spec.ref_start_delay_us = planRow.tau_ai_us;
spec.ref_start_delay_s = spec.ref_start_delay_us * 1e-6;
spec.tton_trunc_min_ns = planRow.tton_trunc_min_ns;
spec.tton_trunc_min_s = planRow.tton_trunc_min_ns * 1e-9;
spec.tton_trunc_window_us = planRow.tton_trunc_window_us;
spec.tton_trunc_window_s = planRow.tton_trunc_window_us * 1e-6;
spec.post_inhibit_delay_us = planRow.post_inhibit_delay_us;
spec.post_inhibit_delay_s = planRow.post_inhibit_delay_us * 1e-6;
spec.post_inhibit_window_us = planRow.post_inhibit_window_us;
spec.post_inhibit_window_s = planRow.post_inhibit_window_us * 1e-6;
spec.delta_v_allow_mV = planRow.delta_v_allow_mV;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runCase(model, spec)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(spec.stopTime, "%.15g"), ...
    "MaxStep", "5e-9", ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", 5e-9);
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.load_A);
in = in.setVariable("t_load_step", spec.t_load_step_s);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.Iph);
in = in.setVariable("Iph_ref_ts", makeDelayedIphRefTimeseries(spec));
in = in.setVariable("Lambda_area", spec.Lambda_area);
in = in.setVariable("Lambda_m2", 0);
in = in.setVariable("Vton_trunc_ov", 0);
in = in.setVariable("Tton_trunc_min", spec.tton_trunc_min_s);
in = in.setVariable("Tton_trunc_window", spec.tton_trunc_window_s);
in = in.setVariable("Tpost_inhibit_delay", spec.post_inhibit_delay_s);
in = in.setVariable("Tpost_inhibit_window", spec.post_inhibit_window_s);
for phase = 1:4
    in = in.setVariable("Lambda" + phase, spec.Lambda_vec(phase));
    in = in.setVariable("Ton_trim" + phase, spec.Ton_trim_vec(phase));
end
out = sim(in, "ShowProgress", "off");
end

function ts = makeDelayedIphRefTimeseries(spec)
slew = max(spec.ref_slew_s, 5e-9);
start = spec.t_load_step_s + max(spec.ref_start_delay_s, 0);
finish = start + slew;
if spec.ref_start_delay_s <= 0
    t = [0; spec.t_load_step_s; finish; spec.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
else
    t = [0; spec.t_load_step_s; start; finish; spec.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
end
ts = timeseries(y(:), t(:));
end

function row = metricsRowFromLogs(planRow, spec, common, logs, dataRoot)
t0 = spec.t_load_step_s;
windowEnd = t0 + common.peakWindow;
vSeries = logs.get("vout").Values;
tAll = double(vSeries.Time(:));
vAll = squeeze(double(vSeries.Data));
mask = tAll >= t0 & tAll <= windowEnd;
t = tAll(mask);
vout = vAll(mask);
tRel = t - t0;

il = zeros(numel(t), 4);
qh = zeros(numel(t), 4);
tonCmd = zeros(numel(t), 4);
phaseTrunc = zeros(numel(t), 4);
for phase = 1:4
    il(:, phase) = valuesAt(logs, "il" + phase, t);
    qh(:, phase) = valuesAt(logs, "qh" + phase, t);
    tonCmd(:, phase) = valuesAtOptional(logs, "ton_cmd_trunc" + phase, t, NaN(size(t)));
    phaseTrunc(:, phase) = valuesAtOptional(logs, "ton_truncate" + phase, t, zeros(size(t)));
end
truncGlobal = valuesAtOptional(logs, "ton_trunc_global", t, zeros(size(t)));
phaseIdx = valuesAtOptional(logs, "phase_idx", t, NaN(size(t)));
req = valuesAtOptional(logs, "req_global", t, zeros(size(t)));
allowCtrl = valuesAtOptional(logs, "allow_controlled_reentry", t, zeros(size(t)));
inhibitRaw = valuesAtOptional(logs, "inhibit_raw", t, zeros(size(t)));
oneShotDone = valuesAtOptional(logs, "one_shot_done", t, zeros(size(t)));
iphRef = iphRefAt(spec, t);

il0 = zeros(1, 4);
qh0 = zeros(1, 4);
remainingTon = zeros(1, 4);
for phase = 1:4
    il0(phase) = valueAt(logs, "il" + phase, t0);
    qh0(phase) = valueAt(logs, "qh" + phase, t0);
    remainingTon(phase) = remainingHighSideOnTime(logs, "qh" + phase, t0, windowEnd);
end

v0 = mean(vAll(tAll >= t0 - common.preWindow & tAll <= t0), "omitnan");
if isnan(v0)
    v0 = valueAt(logs, "vout", t0);
end

[vPeak, idxPeak] = max(vout);
tPeakActualUs = 1e6 * tRel(idxPeak);
deltaVActual = vPeak - common.voRef;
postPeak = idxPeak:numel(vout);
secondaryUndershoot = min(vout(postPeak) - common.voRef);
secondaryPp = max(vout(postPeak) - common.voRef) - min(vout(postPeak) - common.voRef);
finalMask = t >= (windowEnd - common.finalWindow) & t <= windowEnd;
if any(finalMask)
    finalError = mean(vout(finalMask), "omitnan") - common.voRef;
else
    finalError = NaN;
end

dt = [diff(t); median(diff(t), "omitnan")];
if isempty(dt) || any(isnan(dt))
    globalDuration = NaN;
    phaseDuration = NaN(1, 4);
    inhibitRawDuration = NaN;
    effectiveInhibitDuration = NaN;
else
    globalDuration = sum(dt .* (truncGlobal(:) > 0.5));
    phaseDuration = zeros(1, 4);
    for phase = 1:4
        phaseDuration(phase) = sum(dt .* (phaseTrunc(:, phase) > 0.5));
    end
    inhibitRawDuration = sum(dt .* (inhibitRaw(:) > 0.5));
    effectiveInhibitMask = inhibitRaw(:) > 0.5 & oneShotDone(:) < 0.5;
    effectiveInhibitDuration = sum(dt .* effectiveInhibitMask);
end

phaseEdges = zeros(1, 4);
tonMinHits = zeros(1, 4);
qhEdges = zeros(1, 4);
firstTruncUs = NaN(1, 4);
firstInhibitUs = NaN;
oneshotTimeUs = NaN;
idxInhibit = find(inhibitRaw(:) > 0.5, 1, "first");
if ~isempty(idxInhibit)
    firstInhibitUs = 1e6 * tRel(idxInhibit);
end
idxOneshot = find(oneShotDone(:) > 0.5, 1, "first");
if ~isempty(idxOneshot)
    oneshotTimeUs = 1e6 * tRel(idxOneshot);
end
for phase = 1:4
    phaseEdges(phase) = countRisingEdges(phaseTrunc(:, phase));
    tonMinHits(phase) = sum(abs(tonCmd(:, phase) - spec.tton_trunc_min_s) < 1e-12, "omitnan");
    qhEdges(phase) = countRisingEdges(qh(:, phase));
    idx = find(phaseTrunc(:, phase) > 0.5, 1, "first");
    if ~isempty(idx)
        firstTruncUs(phase) = 1e6 * tRel(idx);
    end
end
inhibitEdges = countRisingEdges(inhibitRaw);
allowEdges = countRisingEdges(allowCtrl);
reqEdgesDuringInhibit = countReqEdgesDuringInhibit(req, inhibitRaw);
oneShotEdges = countRisingEdges(oneShotDone);

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r049l_repair_controlled_reentry_wave.csv");
wave = table(1e6 * tRel, vout, spec.load_A * ones(numel(t), 1), ...
    il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), ...
    req, allowCtrl, inhibitRaw, oneShotDone, phaseIdx, ...
    truncGlobal, ...
    phaseTrunc(:,1), phaseTrunc(:,2), phaseTrunc(:,3), phaseTrunc(:,4), ...
    tonCmd(:,1), tonCmd(:,2), tonCmd(:,3), tonCmd(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A', ...
    'il1_A','il2_A','il3_A','il4_A','qh1','qh2','qh3','qh4', ...
    'req_global','allow_controlled_reentry','inhibit_raw','one_shot_done','phase_idx', ...
    'ton_trunc_global', ...
    'ton_truncate1','ton_truncate2','ton_truncate3','ton_truncate4', ...
    'ton_cmd1_s','ton_cmd2_s','ton_cmd3_s','ton_cmd4_s','iph_ref_A'});
writetable(wave, wavePath);

row = table(true, "", string(planRow.case_id), string(planRow.controller), ...
    string(planRow.target_label), string(planRow.objective), string(planRow.role), ...
    string(planRow.trigger_mode), spec.base_load_A, spec.load_A, spec.load_drop_A, ...
    spec.load_step_offset_us, 1e6 * spec.t_load_step_s, spec.ref_slew_us, ...
    spec.ref_start_delay_us, spec.tton_trunc_min_ns, spec.tton_trunc_window_us, ...
    spec.post_inhibit_delay_us, spec.post_inhibit_window_us, spec.delta_v_allow_mV, ...
    v0, il0(1), il0(2), il0(3), il0(4), ...
    qh0(1), qh0(2), qh0(3), qh0(4), ...
    1e9 * remainingTon(1), 1e9 * remainingTon(2), 1e9 * remainingTon(3), 1e9 * remainingTon(4), ...
    1e3 * deltaVActual, tPeakActualUs, 1e3 * secondaryUndershoot, ...
    1e3 * secondaryPp, 1e3 * finalError, 1e6 * globalDuration, ...
    1e6 * phaseDuration(1), 1e6 * phaseDuration(2), 1e6 * phaseDuration(3), 1e6 * phaseDuration(4), ...
    phaseEdges(1), phaseEdges(2), phaseEdges(3), phaseEdges(4), ...
    firstTruncUs(1), firstTruncUs(2), firstTruncUs(3), firstTruncUs(4), ...
    1e6 * inhibitRawDuration, 1e6 * effectiveInhibitDuration, inhibitEdges, reqEdgesDuringInhibit, ...
    allowEdges, oneShotEdges, firstInhibitUs, oneshotTimeUs, ...
    qhEdges(1), qhEdges(2), qhEdges(3), qhEdges(4), ...
    tonMinHits(1), tonMinHits(2), tonMinHits(3), tonMinHits(4), string(wavePath), ...
    'VariableNames', resultNames());
end

function row = failureRow(planRow, message)
N = NaN;
row = table(false, string(message), string(planRow.case_id), string(planRow.controller), ...
    string(planRow.target_label), string(planRow.objective), string(planRow.role), ...
    string(planRow.trigger_mode), planRow.base_load_A, planRow.target_load_A, ...
    planRow.load_drop_A, planRow.load_step_offset_us, N, ...
    planRow.selected_ref_slew_us, planRow.tau_ai_us, planRow.tton_trunc_min_ns, ...
    planRow.tton_trunc_window_us, planRow.post_inhibit_delay_us, ...
    planRow.post_inhibit_window_us, planRow.delta_v_allow_mV, N, ...
    N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, ...
    N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, "", ...
    'VariableNames', resultNames());
end

function names = resultNames()
names = {'success','error_message','case_id','controller','target_label','objective','role', ...
    'trigger_mode','base_load_A','target_load_A','load_drop_A','load_step_offset_us', ...
    't_load_step_us','selected_ref_slew_us','tau_ai_us','tton_trunc_min_ns', ...
    'tton_trunc_window_us','post_inhibit_delay_us','post_inhibit_window_us', ...
    'delta_v_allow_mV','vout0_V', ...
    'il1_0_A','il2_0_A','il3_0_A','il4_0_A', ...
    'qh1_at_step','qh2_at_step','qh3_at_step','qh4_at_step', ...
    'remaining_ton1_ns','remaining_ton2_ns','remaining_ton3_ns','remaining_ton4_ns', ...
    'delta_v_actual_peak_mV','t_peak_actual_us','secondary_undershoot_mV', ...
    'secondary_pp_mV','final_error_mV','global_trunc_duration_us', ...
    'trunc_duration1_us','trunc_duration2_us','trunc_duration3_us','trunc_duration4_us', ...
    'trunc_edges1','trunc_edges2','trunc_edges3','trunc_edges4', ...
    'first_trunc1_us','first_trunc2_us','first_trunc3_us','first_trunc4_us', ...
    'inhibit_raw_duration_us','effective_inhibit_duration_us','inhibit_edge_count', ...
    'req_edges_during_inhibit','allow_edge_count','one_shot_edge_count', ...
    'first_inhibit_us','one_shot_time_us', ...
    'qh1_edge_count','qh2_edge_count','qh3_edge_count','qh4_edge_count', ...
    'ton_min_hits1','ton_min_hits2','ton_min_hits3','ton_min_hits4','wave_csv'};
end

function comparison = compareControllers(rows)
if isempty(rows) || any(~rows.success)
    comparison = table();
    return;
end
offsets = unique(rows.load_step_offset_us);
comparison = table();
for k = 1:numel(offsets)
    offset = offsets(k);
    sub = rows(rows.load_step_offset_us == offset, :);
    a0 = sub(sub.controller == "A0_no_inhibit", :);
    a2 = sub(sub.controller == "A2_one_shot_reentry", :);
    if height(a0) ~= 1 || height(a2) ~= 1
        continue;
    end
    comparison = [comparison; table(offset, ...
        a0.delta_v_actual_peak_mV, a2.delta_v_actual_peak_mV, ...
        a2.delta_v_actual_peak_mV - a0.delta_v_actual_peak_mV, ...
        a0.delta_v_actual_peak_mV - a2.delta_v_actual_peak_mV, ...
        a0.t_peak_actual_us, a2.t_peak_actual_us, ...
        a0.secondary_undershoot_mV, a2.secondary_undershoot_mV, ...
        a2.secondary_undershoot_mV - a0.secondary_undershoot_mV, ...
        a0.final_error_mV, a2.final_error_mV, a2.final_error_mV - a0.final_error_mV, ...
        a0.remaining_ton4_ns, a2.remaining_ton4_ns, ...
        a0.remaining_ton4_ns - a2.remaining_ton4_ns, ...
        a2.inhibit_raw_duration_us, a2.effective_inhibit_duration_us, ...
        a2.req_edges_during_inhibit, a2.one_shot_edge_count, ...
        a2.first_inhibit_us, a2.one_shot_time_us, ...
        'VariableNames', {'load_step_offset_us', 'a0_peak_mV', 'a2_peak_mV', ...
        'a2_minus_a0_peak_mV', 'peak_improvement_mV', ...
        'a0_t_peak_us', 'a2_t_peak_us', ...
        'a0_undershoot_mV', 'a2_undershoot_mV', 'a2_minus_a0_undershoot_mV', ...
        'a0_final_error_mV', 'a2_final_error_mV', 'a2_minus_a0_final_error_mV', ...
        'a0_remaining_ton4_ns', 'a2_remaining_ton4_ns', 'remaining_ton4_reduction_ns', ...
        'a2_inhibit_raw_duration_us', 'a2_effective_inhibit_duration_us', ...
        'a2_req_edges_during_inhibit', 'a2_one_shot_edge_count', ...
        'a2_first_inhibit_us', 'a2_one_shot_time_us'})]; %#ok<AGROW>
end
end

function decision = diagnoseDecision(rows, comparison)
if isempty(comparison)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(~rows.success)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
a2Rows = rows(rows.controller == "A2_one_shot_reentry", :);
if isempty(a2Rows) || any(a2Rows.one_shot_edge_count < 1) || any(isnan(a2Rows.one_shot_time_us))
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
recoveryPeakImprovement = comparison.peak_improvement_mV( ...
    comparison.load_step_offset_us == 0.050);
hasPeakImprovement = any(recoveryPeakImprovement > 0.02);
undershootChange = comparison.a2_minus_a0_undershoot_mV( ...
    comparison.load_step_offset_us == 0.050);
hasUndershootPenalty = any(undershootChange < -0.1);
latePenalty = comparison.a2_minus_a0_peak_mV( ...
    comparison.load_step_offset_us == 0.050);
if hasUndershootPenalty
    if hasPeakImprovement
        decision = "MODEL_REVISED";
    else
        decision = "CLAIM_DOWNGRADED";
    end
elseif hasPeakImprovement
    decision = "MODEL_CONFIRMED";
else
    decision = "CLAIM_DOWNGRADED";
end
end

function y = valuesAt(logs, signalName, queryTime)
try
    s = logs.get(char(signalName)).Values;
    y = interp1(double(s.Time(:)), squeeze(double(s.Data)), double(queryTime), "previous", "extrap");
    y = double(y);
catch
    y = zeros(size(queryTime));
end
end

function y = valuesAtOptional(logs, signalName, queryTime, fallback)
try
    s = logs.get(char(signalName)).Values;
    y = interp1(double(s.Time(:)), squeeze(double(s.Data)), double(queryTime), "previous", "extrap");
    y = double(y);
catch
    if numel(fallback) == 1
        y = fallback * ones(size(queryTime));
    else
        y = fallback;
    end
end
end

function v = valueAt(logs, signalName, queryTime)
try
    s = logs.get(char(signalName)).Values;
    v = interp1(double(s.Time(:)), squeeze(double(s.Data)), double(queryTime), "nearest", "extrap");
    v = double(v);
catch
    v = NaN;
end
end

function remaining = remainingHighSideOnTime(logs, signalName, t0, windowEnd)
% R049K-compatible: returns 0 if qh is not high at t0
series = logs.get(char(signalName)).Values;
isOn = valueAt(logs, signalName, t0) > 0.5;
remaining = 0;
if ~isOn
    return;
end
t = double(series.Time(:));
y = squeeze(double(series.Data)) > 0.5;
mask = t >= t0;
tMask = t(mask);
yMask = y(mask);
fallIdx = find(diff([yMask; 0]) < -0.5, 1, "first");
if isempty(fallIdx)
    remaining = windowEnd - t0;
else
    remaining = tMask(fallIdx) - t0;
end
remaining = max(0, remaining);
end

function y = iphRefAt(spec, t)
y = spec.Iph_final * ones(size(t));
for i = 1:numel(t)
    if t(i) < spec.t_load_step_s
        y(i) = spec.Iph_initial;
    end
end
end

function n = countRisingEdges(x)
n = sum(diff([0; x(:)]) > 0.5);
end

function n = countReqEdgesDuringInhibit(req, inhibit)
active = req(:) > 0.5 & inhibit(:) > 0.5;
reqActive = req(active);
n = sum(diff([0; reqActive(:)]) > 0.5);
end

function instrumentSignals(model)
try; markBlockOutport(model + "/Voltage Measurement", 1, "vout"); catch; end
try; markInportLine(model + "/Goto14", 1, "req_global"); catch; end
try; markInportLine(model + "/Goto16", 1, "existing_allow"); catch; end
try; markBlockOutport(model + "/PhaseScheduler_4Phase", 5, "phase_idx"); catch; end
try; markBlockOutport(model + "/R049C_TonTrunc_Global", 1, "early_ton_trunc_global_raw"); catch; end
try; markBlockOutport(model + "/R049C_ton_trunc_global_double", 1, "ton_trunc_global"); catch; end
try; markBlockOutport(model + "/R049L_one_shot_done_double", 1, "one_shot_done"); catch; end
try; markBlockOutport(model + "/R049L_inhibit_raw_double", 1, "inhibit_raw"); catch; end
try; markBlockOutport(model + "/R049L_allow_controlled_double", 1, "allow_controlled_reentry"); catch; end
for phase = 1:4
    try; markBlockOutport(model + "/Phase" + phase + "/q_hs", 1, "qh" + phase); catch; end
    try; markBlockOutport(model + "/Phase" + phase + "/i_L", 2, "il" + phase); catch; end
    try; markBlockOutport(model + "/R049C_ton_truncate" + phase + "_double", 1, "ton_truncate" + phase); catch; end
    try; markBlockOutport(model + "/R049C_ton_cmd_trunc" + phase + "_double", 1, "ton_cmd_trunc" + phase); catch; end
end
end

function markInportLine(blockPath, inportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1, return; end
srcPort = get_param(lineHandle, "SrcPortHandle");
lineHandle = get_param(srcPort, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(srcPort, "on");
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber, return; end
portHandle = ports.Outport(outportNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1800));
message = strtrim(message);
end

function writeDryRunReport(chunkRoot, planPath, modelFile)
reportPath = fullfile(chunkRoot, "r049l_repair_controlled_reentry_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049L Repair Phase-Boundary Controlled-Reentry Dry Run\n\n");
fprintf(fid, "Prepared 40A->20A crossed with two phase offsets.\n\n");
fprintf(fid, "- Derived model: %s\n", modelFile);
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- R049I model copied into new R049L repair derived file.\n");
fprintf(fid, "- A2 uses phase-boundary (qh1 rising edge) one-shot controlled-reentry.\n");
fprintf(fid, "- Ton truncation disabled in both A0 and A2.\n");
fprintf(fid, "- R049K-compatible operating parameters restored.\n\n");
fprintf(fid, "Run with `iqcot_r049l_repair_pr_ecb_controlled_reentry_chunk(true)`.\n");
end

function writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049L Repair PR-ECB Phase-Boundary Controlled-Reentry Chunk\n\n");
fprintf(fid, "Run label: `%s`\n\n", runLabel);
fprintf(fid, "## Scope\n\n");
fprintf(fid, "- Model: R049L repair copy of R049I with phase-boundary one-shot reentry gate.\n");
fprintf(fid, "- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.\n");
fprintf(fid, "- A2: qh1-rising-edge one-shot reentry proxy; Ton truncation disabled.\n");
fprintf(fid, "- A0: same model, negative inhibit window; Ton truncation disabled.\n");
fprintf(fid, "- R049K-compatible operating parameters restored.\n\n");
fprintf(fid, "## Outputs\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Results: `%s`\n", resultPath);
fprintf(fid, "- Comparison: `%s`\n", comparisonPath);
fprintf(fid, "- Wave: `output/data/*_r049l_repair_controlled_reentry_wave.csv`\n\n");
fprintf(fid, "## Per-case results\n\n");
fprintf(fid, "| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | inhibit_raw us | eff_inhibit us | skipped REQ | first inhibit us | one_shot us | undershoot mV | final mV |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.3f | %.4f | %.4f | %.4f | %.4f | %.4f | %.0f | %.4f | %.4f | %.4f | %.4f |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k), ...
            rows.delta_v_actual_peak_mV(k), rows.t_peak_actual_us(k), rows.remaining_ton4_ns(k), ...
            rows.inhibit_raw_duration_us(k), rows.effective_inhibit_duration_us(k), ...
            rows.req_edges_during_inhibit(k), rows.first_inhibit_us(k), rows.one_shot_time_us(k), ...
            rows.secondary_undershoot_mV(k), rows.final_error_mV(k));
    else
        fprintf(fid, "| %s | %s | %.3f | failed | failed | failed | failed | failed | failed | failed | failed | failed | failed |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k));
    end
end
fprintf(fid, "\n## Decision\n\n");
fprintf(fid, "```text\n%s\n```\n\n", decision);
fprintf(fid, "This decision applies only to this R049L repair phase-boundary controlled-reentry chunk.\n");
end
