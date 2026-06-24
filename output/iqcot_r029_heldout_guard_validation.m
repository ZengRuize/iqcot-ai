function rows = iqcot_r029_heldout_guard_validation(runSimulink, maxCases, startRow)
%IQCOT_R029_HELDOUT_GUARD_VALIDATION Run or dry-run R029 held-out guard cases.
%
% Default dry run:
%   iqcot_r029_heldout_guard_validation(false)
%
% Full held-out switching validation:
%   iqcot_r029_heldout_guard_validation(true)
%
% Chunked validation:
%   iqcot_r029_heldout_guard_validation(true, 6, 7)
%
% This runner reads:
%   E:/Desktop/codex/output/iqcot_r029_guarded_heldout_matlab_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. The AI layer is represented
% as a supervisory T_slew scheduler with a delayed reference-commit channel.

clc;

if nargin < 1 || isempty(runSimulink)
    runSimulink = false;
end
if nargin < 2
    maxCases = [];
end
if nargin < 3 || isempty(startRow)
    startRow = 1;
end
startRow = max(1, round(double(startRow)));

setappdata(0, "iqcot_r029_run_simulink", runSimulink);
setappdata(0, "iqcot_r029_max_cases", maxCases);
setappdata(0, "iqcot_r029_start_row", startRow);

initRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
run(fullfile(initRoot, "init_four_phase_cot_sync.m"));

runSimulink = getappdata(0, "iqcot_r029_run_simulink");
maxCases = getappdata(0, "iqcot_r029_max_cases");
startRow = getappdata(0, "iqcot_r029_start_row");
rmappdata(0, "iqcot_r029_run_simulink");
rmappdata(0, "iqcot_r029_max_cases");
rmappdata(0, "iqcot_r029_start_row");

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end
addpath(outputRoot);
addpath(srcRoot);

localVars = whos;
for varIdx = 1:numel(localVars)
    varName = localVars(varIdx).name;
    if varName ~= "localVars" && varName ~= "varIdx"
        assignin("base", varName, eval(varName));
    end
end

model = "four_phase_iek_dynamic_load_refslew";
modelFile = fullfile(modelRoot, model + ".slx");
if ~exist(modelFile, "file")
    error("Derived model not found: %s", modelFile);
end

plan = loadR029Plan(outputRoot);
fullPlanHeight = height(plan);
if startRow > fullPlanHeight
    error("startRow %d exceeds plan height %d.", startRow, fullPlanHeight);
end
if isempty(maxCases)
    endRow = fullPlanHeight;
else
    endRow = min(fullPlanHeight, startRow + round(double(maxCases)) - 1);
end
plan = plan(startRow:endRow, :);
runLabel = makeR029RunLabel(startRow, endRow, fullPlanHeight);

planOut = fullfile(outputRoot, "iqcot_r029_heldout_guard_matlab_plan_" + runLabel + ".csv");
writetable(plan, planOut);

if ~runSimulink
    writeR029DryRunReport(plan, planOut, outputRoot, runLabel);
    fprintf("R029_HELDOUT_PLAN=%s\n", planOut);
    fprintf("Dry run only. To run switching validation, call:\n");
    fprintf("  iqcot_r029_heldout_guard_validation(true)\n");
    rows = plan;
    return;
end

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(modelRoot);

load_system(modelFile);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

common = makeCommon();
baseLoadA = 40;
rows = table();
for k = 1:height(plan)
    spec = makeR029Spec(baseLoadA, plan.target_load_A(k), ...
        plan.selected_ref_slew_us(k), plan.ref_start_delay_us_for_simulink(k), common);
    fprintf("R029 case %s: %s, %.1f A -> %.6g A, %s, slew %.3f us, delay %.3f us\n", ...
        string(plan.r029_case_id(k)), string(plan.policy(k)), baseLoadA, ...
        spec.load_A, string(plan.objective(k)), spec.ref_slew_us, spec.ref_start_delay_us);
    try
        out = runDelayedSlewCase(model, spec, common);
        logs = out.logsout;
        baseMetrics = preStepMetrics(logs, common, baseLoadA);
        metrics = transientMetrics(logs, spec, common, baseMetrics);
        rows = [rows; r029RowFromMetrics(plan(k, :), spec, metrics)]; %#ok<AGROW>
    catch ME
        detailedMessage = compactErrorReport(ME);
        rows = [rows; r029FailureRow(plan(k, :), spec, detailedMessage)]; %#ok<AGROW>
        warning("iqcot:R029HeldoutCaseFailed", "Case failed: %s", detailedMessage);
    end
end
rows = addSwitchingRegret(rows);

resultPath = fullfile(outputRoot, "iqcot_r029_heldout_guard_results_" + runLabel + ".csv");
policyPath = fullfile(outputRoot, "iqcot_r029_heldout_guard_policy_eval_" + runLabel + ".csv");
contextPath = fullfile(outputRoot, "iqcot_r029_heldout_guard_context_eval_" + runLabel + ".csv");
reportPath = fullfile(outputRoot, "iqcot_r029_heldout_guard_switching_report_" + runLabel + ".md");
figurePath = fullfile(figureRoot, "fig37_r029_heldout_guard_" + runLabel + ".png");
writetable(rows, resultPath);
policyEval = summarizeR029Policies(rows);
contextEval = summarizeR029Contexts(rows);
writetable(policyEval, policyPath);
writetable(contextEval, contextPath);
writeR029SwitchingReport(rows, policyEval, contextEval, resultPath, policyPath, contextPath, reportPath, runLabel);
makeR029PolicyPlot(policyEval, figurePath);

fprintf("R029_HELDOUT_RESULTS=%s\n", resultPath);
fprintf("R029_HELDOUT_POLICY_EVAL=%s\n", policyPath);
fprintf("R029_HELDOUT_CONTEXT_EVAL=%s\n", contextPath);
fprintf("R029_HELDOUT_SWITCHING_REPORT=%s\n", reportPath);
fprintf("R029_HELDOUT_FIGURE=%s\n", figurePath);
end

function plan = loadR029Plan(outputRoot)
planPath = fullfile(outputRoot, "iqcot_r029_guarded_heldout_matlab_plan.csv");
if ~exist(planPath, "file")
    error("R029 plan file not found: %s", planPath);
end
opts = detectImportOptions(planPath, "TextType", "string");
plan = readtable(planPath, opts);
end

function runLabel = makeR029RunLabel(startRow, endRow, fullPlanHeight)
if startRow == 1 && endRow == fullPlanHeight
    runLabel = "heldout";
else
    runLabel = sprintf("heldout_rows%03d_%03d", startRow, endRow);
end
runLabel = string(runLabel);
end

function common = makeCommon()
common = struct();
common.lambdaArea = 6e-10;
common.vAreaBias = 2e-3;
common.riArea = 0.5e-3;
common.tStep = 0.45e-3;
common.stopTime = 0.60e-3;
common.postSteadyWindow = 20e-6;
common.preSteadyWindow = 50e-6;
common.maxStep = "5e-9";
common.fastTss = 5e-9;
if evalin("base", "exist('Vo_ref','var')")
    common.voRef = evalin("base", "Vo_ref");
else
    common.voRef = 1.0;
end
if evalin("base", "exist('Tslot','var')")
    common.expectedSlot = evalin("base", "Tslot");
else
    common.expectedSlot = 0.5e-6;
end
end

function spec = makeR029Spec(baseLoadA, targetLoadA, slewUs, delayUs, common)
spec = struct();
spec.controller_mode = "r029_heldout_guard_validation";
spec.base_load_A = baseLoadA;
spec.load_A = targetLoadA;
spec.effective_load_A = max(targetLoadA, 1e-3);
spec.Rload = common.voRef / spec.effective_load_A;
spec.Iph_initial = baseLoadA / 4;
spec.Iph_final = targetLoadA / 4;
spec.Iph = spec.Iph_final;
spec.ref_slew_us = slewUs;
spec.ref_slew_s = slewUs * 1e-6;
spec.ref_start_delay_us = delayUs;
spec.ref_start_delay_s = delayUs * 1e-6;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runDelayedSlewCase(model, spec, common)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(common.stopTime, "%.15g"), ...
    "MaxStep", char(common.maxStep), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", common.fastTss);
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.load_A);
in = in.setVariable("t_load_step", common.tStep);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.Iph);
in = in.setVariable("Iph_ref_ts", makeDelayedIphRefTimeseries(spec, common));
in = in.setVariable("Lambda_area", spec.Lambda_area);
in = in.setVariable("Lambda_m2", 0);
for phase = 1:4
    in = in.setVariable("Lambda" + phase, spec.Lambda_vec(phase));
    in = in.setVariable("Ton_trim" + phase, spec.Ton_trim_vec(phase));
end
in = in.setVariable("Varea_bias", spec.Varea_bias);
in = in.setVariable("Ri_area", spec.Ri_area);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);
out = sim(in);
end

function ts = makeDelayedIphRefTimeseries(spec, common)
slew = max(spec.ref_slew_s, common.fastTss);
start = common.tStep + max(spec.ref_start_delay_s, 0);
finish = start + slew;
if spec.ref_start_delay_s <= 0
    t = [0; common.tStep; finish; common.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
else
    t = [0; common.tStep; start; finish; common.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
end
ts = timeseries(y, t);
ts.Name = "Iph_ref_ts";
end

function metrics = preStepMetrics(logs, common, loadA)
steadyStart = common.tStep - common.preSteadyWindow;
metrics = steadyMetrics(logs, steadyStart, common.tStep, loadA);
end

function metrics = steadyMetrics(logs, steadyStart, steadyEnd, loadA)
metrics = struct();
metrics.vout = windowValues(logs, "vout", steadyStart, steadyEnd);
metrics.vout_mean_V = mean(metrics.vout);
metrics.il_mean_A = zeros(1, 4);
for phase = 1:4
    il = windowValues(logs, "il" + phase, steadyStart, steadyEnd);
    metrics.il_mean_A(phase) = mean(il);
end
metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.load_error_A = metrics.il_total_mean_A - loadA;
end

function metrics = transientMetrics(logs, spec, common, baseMetrics)
voutSeries = logs.get("vout").Values;
timeAbs = voutSeries.Time;
vout = squeeze(double(voutSeries.Data));
maskPost = timeAbs >= common.tStep;
time = timeAbs(maskPost) - common.tStep;
vout = vout(maskPost);

metrics = struct();
metrics.vout_initial_V = baseMetrics.vout_mean_V;
metrics.vout_peak_V = max(vout);
metrics.vout_min_V = min(vout);
metrics.overshoot_mV = 1e3 * (metrics.vout_peak_V - common.voRef);
metrics.undershoot_mV = 1e3 * (common.voRef - metrics.vout_min_V);
metrics.t_peak_us = 1e6 * time(find(vout == metrics.vout_peak_V, 1, "first"));
metrics.settle_time_us = settleTimeUs(time, vout, common.voRef, 2e-3);

allEdgesAbs = allGateEdges(logs, common.tStep);
allEdges = allEdgesAbs - common.tStep;
metrics.first_gate_edge_us = NaN;
metrics.max_gate_gap_us = NaN;
metrics.skip_count_est = NaN;
if ~isempty(allEdges)
    metrics.first_gate_edge_us = 1e6 * allEdges(1);
    gaps = diff(allEdges);
    if ~isempty(gaps)
        metrics.max_gate_gap_us = 1e6 * max(gaps);
        metrics.skip_count_est = max(0, round(max(gaps) / common.expectedSlot) - 1);
    else
        metrics.skip_count_est = max(0, round(allEdges(1) / common.expectedSlot) - 1);
    end
end

steadyStart = common.stopTime - common.postSteadyWindow;
metrics.final = steadyMetrics(logs, steadyStart, common.stopTime, spec.load_A);
metrics.final_vout_error_mV = 1e3 * (metrics.final.vout_mean_V - common.voRef);
metrics.il_phase_imbalance_A = max(metrics.final.il_mean_A) - min(metrics.final.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.final.il_mean_A - mean(metrics.final.il_mean_A), [1 -1 1 -1]) / 4;
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);

metrics.base_score = abs(metrics.final_vout_error_mV) + metrics.undershoot_mV ...
    + 0.02 * metrics.phase_spacing.std_ns + 2.0 * metrics.skip_count_est;
metrics.score_settle005 = metrics.base_score + 0.05 * metrics.settle_time_us;
metrics.score_settle010 = metrics.base_score + 0.10 * metrics.settle_time_us;
end

function row = r029RowFromMetrics(planRow, spec, m)
selectedObjective = objectiveScoreFromMetrics(planRow.objective, m);
row = table( ...
    true, "", string(planRow.r029_case_id), string(planRow.target_label), ...
    string(planRow.objective), string(planRow.policy), string(planRow.policy_family), ...
    boolFromPlanValue(planRow.online_available_inputs_only), ...
    planRow.objective_alpha_settle, planRow.target_load_A, planRow.load_drop_A, ...
    spec.ref_slew_us, planRow.tau_ai_us, planRow.delay_events_at_0p5us, spec.ref_start_delay_us, ...
    string(planRow.selection_basis), string(planRow.heldout_reason), ...
    m.vout_initial_V, m.vout_peak_V, m.vout_min_V, m.overshoot_mV, m.undershoot_mV, ...
    m.t_peak_us, m.settle_time_us, m.first_gate_edge_us, m.max_gate_gap_us, m.skip_count_est, ...
    m.final_vout_error_mV, ...
    m.final.il_mean_A(1), m.final.il_mean_A(2), m.final.il_mean_A(3), m.final.il_mean_A(4), ...
    m.final.il_total_mean_A, m.final.load_error_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    m.base_score, m.score_settle005, m.score_settle010, selectedObjective, NaN, ...
    'VariableNames', r029ResultVariableNames());
end

function row = r029FailureRow(planRow, spec, message)
row = table( ...
    false, string(message), string(planRow.r029_case_id), string(planRow.target_label), ...
    string(planRow.objective), string(planRow.policy), string(planRow.policy_family), ...
    boolFromPlanValue(planRow.online_available_inputs_only), ...
    planRow.objective_alpha_settle, planRow.target_load_A, planRow.load_drop_A, ...
    spec.ref_slew_us, planRow.tau_ai_us, planRow.delay_events_at_0p5us, spec.ref_start_delay_us, ...
    string(planRow.selection_basis), string(planRow.heldout_reason), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', r029ResultVariableNames());
end

function value = objectiveScoreFromMetrics(objective, m)
objective = string(objective);
if objective == "base"
    value = m.base_score;
elseif objective == "score_settle005"
    value = m.score_settle005;
elseif objective == "score_settle010"
    value = m.score_settle010;
else
    error("Unknown objective '%s'.", objective);
end
end

function value = boolFromPlanValue(rawValue)
if islogical(rawValue)
    value = rawValue;
elseif isnumeric(rawValue)
    value = rawValue ~= 0;
else
    token = lower(strtrim(string(rawValue)));
    value = token == "true" || token == "1" || token == "yes";
end
end

function rows = addSwitchingRegret(rows)
if isempty(rows) || ~any(rows.success)
    return;
end
rows.switching_regret_vs_best_in_context(:) = NaN;
validIdx = find(rows.success);
keys = rows(validIdx, {'target_label','objective','tau_ai_us'});
[groupIds, ~] = findgroups(keys);
for g = 1:max(groupIds)
    idx = validIdx(groupIds == g);
    bestScore = min(rows.selected_objective_score(idx), [], "omitnan");
    rows.switching_regret_vs_best_in_context(idx) = rows.selected_objective_score(idx) - bestScore;
end
end

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1800));
message = strtrim(message);
end

function names = r029ResultVariableNames()
names = {'success','error_message','r029_case_id','target_label','objective', ...
    'policy','policy_family','online_available_inputs_only', ...
    'objective_alpha_settle','target_load_A','load_drop_A', ...
    'selected_ref_slew_us','tau_ai_us','delay_events_at_0p5us','ref_start_delay_us', ...
    'selection_basis','heldout_reason', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction', ...
    'base_score','score_settle005','score_settle010','selected_objective_score', ...
    'switching_regret_vs_best_in_context'};
end

function values = windowValues(logs, signalName, startTime, endTime)
series = logs.get(char(signalName)).Values;
mask = series.Time >= startTime & series.Time <= endTime;
values = squeeze(double(series.Data(mask)));
end

function tSettle = settleTimeUs(time, signal, ref, band)
tSettle = NaN;
outside = abs(signal - ref) > band;
if ~any(outside)
    tSettle = 0;
    return;
end
lastOutside = find(outside, 1, "last");
if lastOutside < numel(time)
    tSettle = 1e6 * time(lastOutside + 1);
end
end

function allTimes = allGateEdges(logs, startTime)
allTimes = [];
for phase = 1:4
    allTimes = [allTimes; edgeTimes(logs, "qh" + phase, startTime)]; %#ok<AGROW>
end
allTimes = sort(allTimes);
end

function times = edgeTimes(logs, signalName, startTime)
series = logs.get(char(signalName)).Values;
mask = series.Time >= startTime;
time = series.Time(mask);
values = squeeze(double(series.Data(mask)));
times = time(find(diff(values > 0.5) > 0) + 1);
end

function spacing = phaseSpacingMetrics(logs, steadyStart)
allTimes = [];
allPhases = [];
for phase = 1:4
    t = edgeTimes(logs, "qh" + phase, steadyStart);
    allTimes = [allTimes; t(:)]; %#ok<AGROW>
    allPhases = [allPhases; phase * ones(numel(t), 1)]; %#ok<AGROW>
end
[allTimes, order] = sort(allTimes);
allPhases = allPhases(order);
spacing = struct("mean_ns", NaN, "std_ns", NaN, "sequence_error_fraction", NaN);
if numel(allTimes) < 6
    return;
end
dt = diff(allTimes);
spacing.mean_ns = 1e9 * mean(dt);
spacing.std_ns = 1e9 * std(dt);
expectedNext = mod(allPhases(1:end-1), 4) + 1;
spacing.sequence_error_fraction = mean(allPhases(2:end) ~= expectedNext);
end

function instrumentSignals(model)
signalSpecs = {
    "33",  1, "vout";
    "219", 1, "trigger";
    "78",  1, "qh1";
    "99",  1, "qh2";
    "120", 1, "qh3";
    "141", 1, "qh4";
};
for k = 1:size(signalSpecs, 1)
    blockPath = Simulink.ID.getFullName(model + ":" + signalSpecs{k, 1});
    instrumentBlockPort(blockPath, signalSpecs{k, 2}, signalSpecs{k, 3});
end
for phase = 1:4
    instrumentBlockPort(model + "/IL_Measurement" + phase, 1, "il" + phase);
end
end

function instrumentBlockPort(blockPath, portNumber, signalName)
ports = get_param(blockPath, "PortHandles");
portHandle = ports.Outport(portNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function policyEval = summarizeR029Policies(rows)
valid = rows(rows.success, :);
policyEval = table();
if isempty(valid)
    return;
end
families = unique(valid.policy_family, "stable");
for k = 1:numel(families)
    r = valid(valid.policy_family == families(k), :);
    policyEval = [policyEval; table( ... %#ok<AGROW>
        families(k), height(r), mean(r.switching_regret_vs_best_in_context, "omitnan"), ...
        max(r.switching_regret_vs_best_in_context, [], "omitnan"), ...
        mean(r.selected_objective_score, "omitnan"), ...
        mean(r.undershoot_mV, "omitnan"), max(r.undershoot_mV, [], "omitnan"), ...
        mean(abs(r.final_vout_error_mV), "omitnan"), ...
        mean(r.skip_count_est, "omitnan"), mean(r.settle_time_us, "omitnan"), ...
        mean(r.final_phase_spacing_std_ns, "omitnan"), ...
        'VariableNames', {'policy_family','n_cases','mean_switching_regret', ...
        'max_switching_regret','mean_selected_objective_score','mean_undershoot_mV', ...
        'max_undershoot_mV','mean_abs_final_vout_error_mV','mean_skip_count', ...
        'mean_settle_time_us','mean_phase_spacing_std_ns'})];
end
policyEval = sortrows(policyEval, ["mean_switching_regret","max_switching_regret"]);
end

function contextEval = summarizeR029Contexts(rows)
valid = rows(rows.success, :);
contextEval = table();
if isempty(valid)
    return;
end
keys = valid(:, {'target_label','objective','tau_ai_us'});
[groupIds, groupTable] = findgroups(keys);
for g = 1:max(groupIds)
    r = valid(groupIds == g, :);
    [bestScore, bestIdx] = min(r.selected_objective_score, [], "omitnan");
    bestRow = r(bestIdx, :);
    denseRows = r(r.policy_family == "dense_anchor", :);
    guardedRows = r(r.policy_family == "guarded_candidate", :);
    oldRows = r(r.policy_family == "old_proxy_failure_probe", :);
    denseRegret = NaN;
    guardedRegret = NaN;
    oldRegret = NaN;
    if ~isempty(denseRows)
        denseRegret = min(denseRows.switching_regret_vs_best_in_context, [], "omitnan");
    end
    if ~isempty(guardedRows)
        guardedRegret = min(guardedRows.switching_regret_vs_best_in_context, [], "omitnan");
    end
    if ~isempty(oldRows)
        oldRegret = min(oldRows.switching_regret_vs_best_in_context, [], "omitnan");
    end
    contextEval = [contextEval; table( ... %#ok<AGROW>
        string(groupTable.target_label(g)), string(groupTable.objective(g)), groupTable.tau_ai_us(g), ...
        string(bestRow.policy(1)), string(bestRow.policy_family(1)), bestRow.selected_ref_slew_us(1), ...
        bestScore, denseRegret, guardedRegret, oldRegret, ...
        'VariableNames', {'target_label','objective','tau_ai_us','best_policy', ...
        'best_policy_family','best_slew_us','best_score','dense_anchor_regret', ...
        'guarded_candidate_regret','old_proxy_regret'})];
end
end

function writeR029DryRunReport(plan, planPath, outputRoot, runLabel)
reportPath = fullfile(outputRoot, "iqcot_r029_heldout_guard_matlab_dryrun_" + runLabel + ".md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R029 MATLAB held-out guard dry run\n\n");
fprintf(fid, "Run label: `%s`.\n\n", runLabel);
fprintf(fid, "Plan CSV: `%s`.\n\n", strrep(planPath, "\", "/"));
fprintf(fid, "Rows: `%d`.\n\n", height(plan));
fprintf(fid, "Contexts: `%d`.\n\n", height(unique(plan(:, {'target_label','objective','tau_ai_us'}))));
fprintf(fid, "This dry run did not execute Simulink. It verified that R029 CSV rows can be loaded by MATLAB and converted into delayed `Iph_ref_ts` cases.\n\n");
fprintf(fid, "Boundary: R029 dry-run is not switching-level or hardware validation. AI remains a supervisory parameter scheduler.\n");
end

function writeR029SwitchingReport(rows, policyEval, contextEval, resultPath, policyPath, contextPath, reportPath, runLabel)
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R029 held-out guarded-proxy switching validation\n\n");
fprintf(fid, "- Run label: `%s`\n", runLabel);
fprintf(fid, "- Result CSV: `%s`\n", strrep(resultPath, "\", "/"));
fprintf(fid, "- Policy CSV: `%s`\n", strrep(policyPath, "\", "/"));
fprintf(fid, "- Context CSV: `%s`\n\n", strrep(contextPath, "\", "/"));
fprintf(fid, "This run uses only the derived Simulink model and delayed `Iph_ref_ts` profiles. It checks whether R028 guarded candidates survive held-out delay contexts.\n\n");
fprintf(fid, "Executed rows: `%d`.\n\n", height(rows));
if isempty(policyEval)
    fprintf(fid, "No successful policy rows were produced.\n");
    return;
end
fprintf(fid, "## Policy-family summary\n\n");
fprintf(fid, "| Family | n | mean regret | max regret | mean objective | mean undershoot mV | mean settle us |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(policyEval)
    fprintf(fid, "| `%s` | %d | %.3f | %.3f | %.3f | %.3f | %.3f |\n", ...
        policyEval.policy_family(k), policyEval.n_cases(k), policyEval.mean_switching_regret(k), ...
        policyEval.max_switching_regret(k), policyEval.mean_selected_objective_score(k), ...
        policyEval.mean_undershoot_mV(k), policyEval.mean_settle_time_us(k));
end
fprintf(fid, "\n## Context winners\n\n");
fprintf(fid, "| target | objective | tau us | best policy | best slew us | dense regret | guarded regret | old proxy regret |\n");
fprintf(fid, "|---|---|---:|---|---:|---:|---:|---:|\n");
for k = 1:height(contextEval)
    fprintf(fid, "| `%s` | `%s` | %.3f | `%s` | %.3f | %.3f | %.3f | %.3f |\n", ...
        contextEval.target_label(k), contextEval.objective(k), contextEval.tau_ai_us(k), ...
        contextEval.best_policy(k), contextEval.best_slew_us(k), ...
        contextEval.dense_anchor_regret(k), contextEval.guarded_candidate_regret(k), ...
        contextEval.old_proxy_regret(k));
end
fprintf(fid, "\nBoundary: these are derived-model switching results, not hardware validation and not proof of global `T_slew` optimality. The guarded policy remains a supervisory candidate, not an IQCOT inner-loop replacement.\n");
end

function makeR029PolicyPlot(policyEval, figurePath)
if isempty(policyEval)
    return;
end
fig = figure(Visible="off", Position=[100 100 1000 520]);
cleanup = onCleanup(@() close(fig));
x = categorical(policyEval.policy_family);
x = reordercats(x, cellstr(policyEval.policy_family));
bar(x, [policyEval.mean_switching_regret policyEval.mean_selected_objective_score]);
grid on;
ylabel("Mean value");
legend("switching regret", "selected objective score", Location="best");
title("R029 held-out guarded-proxy switching validation");
xtickangle(25);
exportgraphics(fig, figurePath, Resolution=180);
end
