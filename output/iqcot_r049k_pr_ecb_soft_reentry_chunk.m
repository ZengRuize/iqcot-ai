function rows = iqcot_r049k_pr_ecb_soft_reentry_chunk(runSimulink, maxCases, startRow)
%IQCOT_R049K_PR_ECB_SOFT_REENTRY_CHUNK Run shortened soft-reentry chunk.
%
% Dry run:
%   iqcot_r049k_pr_ecb_soft_reentry_chunk(false)
%
% True run:
%   iqcot_r049k_pr_ecb_soft_reentry_chunk(true)
%
% Scope: same repaired R049I 40A->20A two-offset chunk, but A2 uses a deferred
% request-path shortened soft-reentry proxy window.  Ton truncation is disabled for both
% A0 and A2.

clc;

if nargin < 1 || isempty(runSimulink)
    runSimulink = false;
end
if nargin < 2 || isempty(maxCases)
    maxCases = [];
end
if nargin < 3 || isempty(startRow)
    startRow = 1;
end
startRow = max(1, round(double(startRow)));

setappdata(0, "iqcot_r049k_run_simulink", runSimulink);
setappdata(0, "iqcot_r049k_max_cases", maxCases);
setappdata(0, "iqcot_r049k_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r049k_run_simulink");
maxCases = getappdata(0, "iqcot_r049k_max_cases");
startRow = getappdata(0, "iqcot_r049k_start_row");
rmappdata(0, "iqcot_r049k_run_simulink");
rmappdata(0, "iqcot_r049k_max_cases");
rmappdata(0, "iqcot_r049k_start_row");

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
outputRoot = "E:\Desktop\codex\output";
dataRoot = fullfile(outputRoot, "data");
chunkRoot = fullfile(outputRoot, "cutload_pr_ecb_control");
if ~exist(dataRoot, "dir")
    mkdir(dataRoot);
end
if ~exist(chunkRoot, "dir")
    mkdir(chunkRoot);
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

modelFile = iqcot_r049k_build_soft_reentry_model();
[~, model] = fileparts(modelFile);

fullPlan = buildPlan();
planPath = fullfile(chunkRoot, "r049k_soft_reentry_plan.csv");
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
    fprintf("R049K_SOFT_REENTRY_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run the soft-reentry proxy chunk:\n");
    fprintf("  iqcot_r049k_pr_ecb_soft_reentry_chunk(true)\n");
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
    fprintf("R049K case %s: %s, %.1f A -> %.3f A, offset %.3f us, inhibit %.3f..%.3f us\n", ...
        string(spec.case_id), string(spec.controller), spec.base_load_A, spec.load_A, ...
        spec.load_step_offset_us, spec.post_inhibit_delay_us, ...
        spec.post_inhibit_delay_us + spec.post_inhibit_window_us);
    try
        out = runCase(model, spec);
        row = metricsRowFromLogs(plan(k, :), spec, common, out.logsout, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R049KSoftReentryCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(chunkRoot, "r049k_soft_reentry_results_" + runLabel + ".csv");
comparisonPath = fullfile(chunkRoot, "r049k_soft_reentry_comparison_" + runLabel + ".csv");
reportPath = fullfile(chunkRoot, "r049k_soft_reentry_report_" + runLabel + ".md");
writetable(rows, resultPath);
comparison = compareControllers(rows);
writetable(comparison, comparisonPath);
decision = diagnoseDecision(rows, comparison);
writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel);

fprintf("R049K_SOFT_REENTRY_RESULTS=%s\n", resultPath);
fprintf("R049K_SOFT_REENTRY_COMPARISON=%s\n", comparisonPath);
fprintf("R049K_SOFT_REENTRY_REPORT=%s\n", reportPath);
fprintf("R049K_DECISION=%s\n", decision);
end

function plan = buildPlan()
case_id = [
    "r049k_20A_off0p050_a0";
    "r049k_20A_off0p050_a2_soft_reentry";
    "r049k_20A_off0p105_a0";
    "r049k_20A_off0p105_a2_soft_reentry"
];
controller = [
    "A0_no_inhibit";
    "A2_short_soft_reentry";
    "A0_no_inhibit";
    "A2_short_soft_reentry"
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
    "short_soft_reentry_proxy";
    "disabled_negative_window";
    "short_soft_reentry_proxy"
];
tton_trunc_min_ns = 196.5 * ones(numel(case_id), 1);
tton_trunc_window_us = -0.001 * ones(numel(case_id), 1);
post_inhibit_delay_us = [0.070; 0.070; 0.070; 0.070];
post_inhibit_window_us = [-0.001; 1.690; -0.001; 1.690];
delta_v_allow_mV = 10 * ones(numel(case_id), 1);
objective = repmat("r049k_short_soft_reentry_proxy", numel(case_id), 1);
role = [
    "baseline_same_model";
    "deferred_short_soft_reentry_proxy";
    "baseline_same_model";
    "deferred_short_soft_reentry_proxy"
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
runLabel = string(runLabel);
end

function common = makeCommon()
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
in = in.setVariable("Varea_bias", spec.Varea_bias);
in = in.setVariable("Ri_area", spec.Ri_area);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);
out = sim(in);
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
ts = timeseries(y, t);
ts.Name = "Iph_ref_ts";
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
protectState = valuesAtOptional(logs, "protect_state", t, truncGlobal);
phaseIdx = valuesAtOptional(logs, "phase_idx", t, NaN(size(t)));
req = valuesAtOptional(logs, "req_global", t, zeros(size(t)));
allow = valuesAtOptional(logs, "allow_after_inhibit", t, zeros(size(t)));
postInhibit = valuesAtOptional(logs, "soft_reentry", t, zeros(size(t)));
pulseInhibit = zeros(numel(t), 4);
for phase = 1:4
    pulseInhibit(:, phase) = valuesAtOptional(logs, "pulse_inhibit" + phase, t, postInhibit);
end
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
    inhibitDuration = NaN;
    phaseInhibitDuration = NaN(1, 4);
else
    globalDuration = sum(dt .* (truncGlobal(:) > 0.5));
    phaseDuration = zeros(1, 4);
    for phase = 1:4
        phaseDuration(phase) = sum(dt .* (phaseTrunc(:, phase) > 0.5));
    end
    inhibitDuration = sum(dt .* (postInhibit(:) > 0.5));
    phaseInhibitDuration = zeros(1, 4);
    for phase = 1:4
        phaseInhibitDuration(phase) = sum(dt .* (pulseInhibit(:, phase) > 0.5));
    end
end
phaseEdges = zeros(1, 4);
phaseInhibitEdges = zeros(1, 4);
tonMinHits = zeros(1, 4);
qhEdges = zeros(1, 4);
firstTruncUs = NaN(1, 4);
firstInhibitUs = NaN;
idxInhibit = find(postInhibit(:) > 0.5, 1, "first");
if ~isempty(idxInhibit)
    firstInhibitUs = 1e6 * tRel(idxInhibit);
end
for phase = 1:4
    phaseEdges(phase) = countRisingEdges(phaseTrunc(:, phase));
    phaseInhibitEdges(phase) = countRisingEdges(pulseInhibit(:, phase));
    tonMinHits(phase) = sum(abs(tonCmd(:, phase) - spec.tton_trunc_min_s) < 1e-12, "omitnan");
    qhEdges(phase) = countRisingEdges(qh(:, phase));
    idx = find(phaseTrunc(:, phase) > 0.5, 1, "first");
    if ~isempty(idx)
        firstTruncUs(phase) = 1e6 * tRel(idx);
    end
end
inhibitEdges = countRisingEdges(postInhibit);
allowEdges = countRisingEdges(allow);
reqEdgesDuringInhibit = countReqEdgesDuringInhibit(req, postInhibit);

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r049k_soft_reentry_wave.csv");
wave = table(1e6 * tRel, vout, spec.load_A * ones(numel(t), 1), ...
    il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), ...
    req, allow, postInhibit, protectState, phaseIdx, ...
    pulseInhibit(:,1), pulseInhibit(:,2), pulseInhibit(:,3), pulseInhibit(:,4), ...
    truncGlobal, ...
    phaseTrunc(:,1), phaseTrunc(:,2), phaseTrunc(:,3), phaseTrunc(:,4), ...
    tonCmd(:,1), tonCmd(:,2), tonCmd(:,3), tonCmd(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A', ...
    'il1_A','il2_A','il3_A','il4_A','qh1','qh2','qh3','qh4', ...
    'req_global','allow_after_inhibit','soft_reentry','protect_state','phase_idx', ...
    'pulse_inhibit1','pulse_inhibit2','pulse_inhibit3','pulse_inhibit4', ...
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
    1e6 * inhibitDuration, inhibitEdges, reqEdgesDuringInhibit, allowEdges, firstInhibitUs, ...
    1e6 * phaseInhibitDuration(1), 1e6 * phaseInhibitDuration(2), 1e6 * phaseInhibitDuration(3), 1e6 * phaseInhibitDuration(4), ...
    phaseInhibitEdges(1), phaseInhibitEdges(2), phaseInhibitEdges(3), phaseInhibitEdges(4), ...
    qhEdges(1), qhEdges(2), qhEdges(3), qhEdges(4), ...
    tonMinHits(1), tonMinHits(2), tonMinHits(3), tonMinHits(4), string(wavePath), ...
    'VariableNames', resultNames());
end

function row = failureRow(planRow, message)
nan1x4 = NaN(1, 4);
row = table(false, string(message), string(planRow.case_id), string(planRow.controller), ...
    string(planRow.target_label), string(planRow.objective), string(planRow.role), ...
    string(planRow.trigger_mode), planRow.base_load_A, planRow.target_load_A, ...
    planRow.load_drop_A, planRow.load_step_offset_us, NaN, ...
    planRow.selected_ref_slew_us, planRow.tau_ai_us, planRow.tton_trunc_min_ns, ...
    planRow.tton_trunc_window_us, planRow.post_inhibit_delay_us, ...
    planRow.post_inhibit_window_us, planRow.delta_v_allow_mV, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    NaN, NaN, NaN, NaN, NaN, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    NaN, NaN, NaN, NaN, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), "", ...
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
    'inhibit_duration_us','inhibit_edge_count','req_edges_during_inhibit', ...
    'allow_edge_count','first_inhibit_us', ...
    'pulse_inhibit_duration1_us','pulse_inhibit_duration2_us', ...
    'pulse_inhibit_duration3_us','pulse_inhibit_duration4_us', ...
    'pulse_inhibit_edges1','pulse_inhibit_edges2','pulse_inhibit_edges3','pulse_inhibit_edges4', ...
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
    a2 = sub(sub.controller == "A2_short_soft_reentry", :);
    if height(a0) ~= 1 || height(a2) ~= 1
        continue;
    end
    row = table(offset, a0.delta_v_actual_peak_mV, a2.delta_v_actual_peak_mV, ...
        a2.delta_v_actual_peak_mV - a0.delta_v_actual_peak_mV, ...
        a0.delta_v_actual_peak_mV - a2.delta_v_actual_peak_mV, ...
        a0.t_peak_actual_us, a2.t_peak_actual_us, ...
        a0.secondary_undershoot_mV, a2.secondary_undershoot_mV, ...
        a2.secondary_undershoot_mV - a0.secondary_undershoot_mV, ...
        a0.final_error_mV, a2.final_error_mV, a2.final_error_mV - a0.final_error_mV, ...
        a0.remaining_ton4_ns, a2.remaining_ton4_ns, ...
        a0.remaining_ton4_ns - a2.remaining_ton4_ns, ...
        a2.inhibit_duration_us, a2.inhibit_edge_count, a2.req_edges_during_inhibit, ...
        a2.allow_edge_count, a2.first_inhibit_us, ...
        a2.pulse_inhibit_duration1_us, a2.pulse_inhibit_duration2_us, ...
        a2.pulse_inhibit_duration3_us, a2.pulse_inhibit_duration4_us, ...
        'VariableNames', {'load_step_offset_us','a0_peak_mV','a2_peak_mV', ...
        'a2_minus_a0_peak_mV','peak_improvement_mV','a0_t_peak_us','a2_t_peak_us', ...
        'a0_secondary_undershoot_mV','a2_secondary_undershoot_mV','a2_minus_a0_undershoot_mV', ...
        'a0_final_error_mV','a2_final_error_mV','a2_minus_a0_final_error_mV', ...
        'a0_remaining_ton4_ns','a2_remaining_ton4_ns','remaining_ton4_reduction_ns', ...
        'a2_inhibit_duration_us','a2_inhibit_edge_count','a2_req_edges_during_inhibit', ...
        'a2_allow_edge_count','a2_first_inhibit_us', ...
        'a2_pulse_inhibit_duration1_us','a2_pulse_inhibit_duration2_us', ...
        'a2_pulse_inhibit_duration3_us','a2_pulse_inhibit_duration4_us'});
    comparison = [comparison; row]; %#ok<AGROW>
end
end

function decision = diagnoseDecision(rows, comparison)
if isempty(rows) || any(~rows.success) || isempty(comparison)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(comparison.remaining_ton4_reduction_ns > 1.0)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(comparison.a2_minus_a0_peak_mV > 0.05)
    decision = "MODEL_REVISED";
    return;
end
if any(comparison.a2_minus_a0_undershoot_mV < -0.5) || any(abs(comparison.a2_minus_a0_final_error_mV) > 5)
    decision = "MODEL_REVISED";
    return;
end
activeRow = comparison(comparison.load_step_offset_us == 0.05, :);
if isempty(activeRow)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if activeRow.peak_improvement_mV >= 0.05
    decision = "MODEL_CONFIRMED";
    return;
end
if activeRow.a2_inhibit_duration_us > 0
    decision = "MODEL_REVISED";
    return;
end
decision = "IMPLEMENTATION_ISSUE";
end
function values = valuesAt(logs, signalName, queryTime)
series = logs.get(char(signalName)).Values;
t = double(series.Time(:));
y = squeeze(double(series.Data));
values = interp1(t, y, queryTime, "previous", "extrap");
values = values(:);
end

function values = valuesAtOptional(logs, signalName, queryTime, fallback)
try
    values = valuesAt(logs, signalName, queryTime);
catch
    values = fallback(:);
end
end

function value = valueAt(logs, signalName, queryTime)
value = valuesAt(logs, signalName, queryTime);
value = value(1);
end

function iphRef = iphRefAt(spec, t)
start = spec.t_load_step_s + max(spec.ref_start_delay_s, 0);
finish = start + max(spec.ref_slew_s, 5e-9);
iphRef = spec.Iph_initial * ones(numel(t), 1);
slewMask = t >= start & t <= finish;
if any(slewMask)
    frac = (t(slewMask) - start) / max(spec.ref_slew_s, 5e-9);
    iphRef(slewMask) = spec.Iph_initial + frac * (spec.Iph_final - spec.Iph_initial);
end
iphRef(t > finish) = spec.Iph_final;
end

function remaining = remainingHighSideOnTime(logs, signalName, t0, windowEnd)
series = logs.get(char(signalName)).Values;
t = double(series.Time(:));
y = squeeze(double(series.Data)) > 0.5;
isOn = valueAt(logs, signalName, t0) > 0.5;
remaining = 0;
if ~isOn
    return;
end
mask = t >= t0 & t <= windowEnd;
tw = t(mask);
yw = y(mask);
fallIdx = find(diff(double(yw)) < 0, 1, "first");
if isempty(fallIdx)
    remaining = max(0, windowEnd - t0);
else
    remaining = max(0, tw(fallIdx + 1) - t0);
end
end

function n = countRisingEdges(y)
if isempty(y)
    n = NaN;
    return;
end
yb = y(:) > 0.5;
n = sum(diff([false; yb]) > 0);
end

function n = countReqEdgesDuringInhibit(req, inhibit)
if isempty(req) || isempty(inhibit)
    n = NaN;
    return;
end
reqb = req(:) > 0.5;
inhb = inhibit(:) > 0.5;
rising = diff([false; reqb]) > 0;
n = sum(rising & inhb);
end

function instrumentSignals(model)
markBlockOutport(model + "/Voltage Measurement", 1, "vout");
markInportLine(model + "/Goto14", 1, "req_global");
markInportLine(model + "/Goto16", 1, "allow_after_inhibit");
markBlockOutport(model + "/PhaseScheduler_4Phase", 5, "phase_idx");
markBlockOutport(model + "/R049C_TonTrunc_Global", 1, "early_ton_trunc_global_raw");
markBlockOutport(model + "/R049C_ton_trunc_global_double", 1, "ton_trunc_global");
markBlockOutport(model + "/R049K_soft_reentry_double", 1, "soft_reentry");
markBlockOutport(model + "/R049K_protect_state_double", 1, "protect_state");
for phase = 1:4
    markBlockOutport(model + "/IL_Measurement" + phase, 1, "il" + phase);
    markBlockOutport(model + "/GateDriver_1Phase" + phase, 1, "qh" + phase);
    markBlockOutport(model + "/GateDriver_1Phase" + phase, 2, "ql" + phase);
    markBlockOutport(model + "/R049C_Ton_Switch" + phase, 1, "ton_cmd_trunc" + phase);
    markBlockOutport(model + "/R049G_ton_truncate" + phase + "_double", 1, "ton_truncate" + phase);
    markBlockOutport(model + "/R049K_pulse_inhibit" + phase + "_double", 1, "pulse_inhibit" + phase);
end
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber
    error("Missing outport %d on %s", outportNumber, blockPath);
end
portHandle = ports.Outport(outportNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function markInportLine(blockPath, inportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1
    error("Missing incoming line for %s/%d", blockPath, inportNumber);
end
srcPort = get_param(lineHandle, "SrcPortHandle");
lineHandle = get_param(srcPort, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(srcPort, "on");
end

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1800));
message = strtrim(message);
end

function writeDryRunReport(chunkRoot, planPath, modelFile)
reportPath = fullfile(chunkRoot, "r049k_soft_reentry_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049K Deferred Post-Active Pulse-Inhibit Dry Run\n\n");
fprintf(fid, "Prepared 40A->20A crossed with two phase offsets.\n\n");
fprintf(fid, "- Derived model: %s\n", modelFile);
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- The completed R049I `.slx` model is copied into a new R049K derived file, not modified in place.\n");
fprintf(fid, "- A2 uses request-path `soft_reentry` after the baseline active pulse's natural end.\n");
fprintf(fid, "- Ton truncation is disabled in both A0 and A2.\n\n");
fprintf(fid, "Run with `iqcot_r049k_pr_ecb_soft_reentry_chunk(true)`.\n");
end

function writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049K PR-ECB Deferred Post-Active Pulse-Inhibit Chunk\n\n");
fprintf(fid, "Run label: `%s`\n\n", runLabel);
fprintf(fid, "## Scope and hypothesis\n\n");
fprintf(fid, "- Model version: R049K copy of R049I with inherited repaired lower bound and added request-path short soft-reentry gate.\n");
fprintf(fid, "- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.\n");
fprintf(fid, "- A2 short soft-reentry proxy: `delay=70ns`, `window=1.69us`; Ton truncation disabled.\n");
fprintf(fid, "- A0 baseline: same model, negative inhibit window; Ton truncation disabled.\n");
fprintf(fid, "- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.\n\n");
fprintf(fid, "## Outputs\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Results: `%s`\n", resultPath);
fprintf(fid, "- Comparison: `%s`\n", comparisonPath);
fprintf(fid, "- Wave snapshots: `output/data/*_r049k_soft_reentry_wave.csv`\n\n");
fprintf(fid, "## Per-case results\n\n");
fprintf(fid, "| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | inhibit us | skipped REQ | first inhibit us | undershoot mV | final mV |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.3f | %.4f | %.4f | %.4f | %.4f | %.0f | %.4f | %.4f | %.4f |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k), ...
            rows.delta_v_actual_peak_mV(k), rows.t_peak_actual_us(k), rows.remaining_ton4_ns(k), ...
            rows.inhibit_duration_us(k), rows.req_edges_during_inhibit(k), rows.first_inhibit_us(k), ...
            rows.secondary_undershoot_mV(k), rows.final_error_mV(k));
    else
        fprintf(fid, "| %s | %s | %.3f | failed | failed | failed | failed | failed | failed | failed | failed |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k));
    end
end
fprintf(fid, "\n## A2 versus A0 comparison\n\n");
if isempty(comparison)
    fprintf(fid, "No comparison table was produced because at least one case failed.\n\n");
else
    fprintf(fid, "| offset us | A0 peak mV | A2 peak mV | improvement mV | rem Ton4 reduction ns | A2 inhibit us | A2 skipped REQ | A2 first inhibit us | A2-A0 undershoot mV | A2-A0 final mV |\n");
    fprintf(fid, "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
    for k = 1:height(comparison)
        fprintf(fid, "| %.3f | %.4f | %.4f | %.4f | %.4f | %.4f | %.0f | %.4f | %.4f | %.4f |\n", ...
            comparison.load_step_offset_us(k), comparison.a0_peak_mV(k), ...
            comparison.a2_peak_mV(k), comparison.peak_improvement_mV(k), ...
            comparison.remaining_ton4_reduction_ns(k), ...
            comparison.a2_inhibit_duration_us(k), comparison.a2_req_edges_during_inhibit(k), ...
            comparison.a2_first_inhibit_us(k), ...
            comparison.a2_minus_a0_undershoot_mV(k), comparison.a2_minus_a0_final_error_mV(k));
    end
end
fprintf(fid, "\n## Decision\n\n");
fprintf(fid, "```text\n%s\n```\n\n", decision);
fprintf(fid, "This decision applies only to this R049K soft-reentry proxy chunk.\n");
end
