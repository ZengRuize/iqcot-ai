function rows = iqcot_r049e_pr_ecb_tontrunc_holdout_chunk(runSimulink, maxCases, startRow)
%IQCOT_R049E_PR_ECB_TONTRUNC_HOLDOUT_CHUNK Run the R049E mild hold-out chunk.
%
% Dry run:
%   iqcot_r049e_pr_ecb_tontrunc_holdout_chunk(false)
%
% True run:
%   iqcot_r049e_pr_ecb_tontrunc_holdout_chunk(true)
%
% Scope: one mild hold-out load-drop magnitude (40A -> 20A) crossed with two
% phase offsets (0.05us active-HS boundary and 0.105us post-turnoff reference).
% For each offset, run A0 same-model no-trunc and A2 command-path Ton truncation.

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

setappdata(0, "iqcot_r049e_run_simulink", runSimulink);
setappdata(0, "iqcot_r049e_max_cases", maxCases);
setappdata(0, "iqcot_r049e_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r049e_run_simulink");
maxCases = getappdata(0, "iqcot_r049e_max_cases");
startRow = getappdata(0, "iqcot_r049e_start_row");
rmappdata(0, "iqcot_r049e_run_simulink");
rmappdata(0, "iqcot_r049e_max_cases");
rmappdata(0, "iqcot_r049e_start_row");

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

modelFile = iqcot_r049e_build_tontrunc_holdout_model();
[~, model] = fileparts(modelFile);

fullPlan = buildR049EPlan();
planPath = fullfile(chunkRoot, "r049e_tontrunc_holdout_plan.csv");
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
    fprintf("R049E_TONTRUNC_HOLDOUT_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run the hold-out chunk:\n");
    fprintf("  iqcot_r049e_pr_ecb_tontrunc_holdout_chunk(true)\n");
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
    fprintf("R049E case %s: %s, %.1f A -> %.3f A, offset %.3f us, threshold %.3f mV\n", ...
        string(spec.case_id), string(spec.controller), spec.base_load_A, spec.load_A, ...
        spec.load_step_offset_us, 1e3 * spec.vton_trunc_ov_V);
    try
        out = runTonTruncCase(model, spec);
        row = metricsRowFromLogs(plan(k, :), spec, common, out.logsout, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R049ETonTruncHoldoutCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(chunkRoot, "r049e_tontrunc_holdout_results_" + runLabel + ".csv");
comparisonPath = fullfile(chunkRoot, "r049e_tontrunc_holdout_comparison_" + runLabel + ".csv");
reportPath = fullfile(chunkRoot, "r049e_tontrunc_holdout_report_" + runLabel + ".md");
writetable(rows, resultPath);
comparison = compareControllers(rows);
writetable(comparison, comparisonPath);
decision = diagnoseDecision(rows, comparison);
writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel);

fprintf("R049E_TONTRUNC_HOLDOUT_RESULTS=%s\n", resultPath);
fprintf("R049E_TONTRUNC_HOLDOUT_COMPARISON=%s\n", comparisonPath);
fprintf("R049E_TONTRUNC_HOLDOUT_REPORT=%s\n", reportPath);
fprintf("R049E_DECISION=%s\n", decision);
end

function plan = buildR049EPlan()
case_id = [
    "r049e_20A_off0p050_a0";
    "r049e_20A_off0p050_a2_tontrunc";
    "r049e_20A_off0p105_a0";
    "r049e_20A_off0p105_a2_tontrunc"
];
controller = [
    "A0_no_trunc";
    "A2_ton_trunc";
    "A0_no_trunc";
    "A2_ton_trunc"
];
target_label = repmat("20A", numel(case_id), 1);
base_load_A = 40 * ones(numel(case_id), 1);
target_load_A = 20 * ones(numel(case_id), 1);
load_drop_A = base_load_A - target_load_A;
load_step_offset_us = [0.050; 0.050; 0.105; 0.105];
tau_ai_us = 1.25 * ones(numel(case_id), 1);
selected_ref_slew_us = 60 * ones(numel(case_id), 1);
vton_trunc_ov_mV = [1000; 2.0; 1000; 2.0];
tton_trunc_min_ns = [196.5; 5.0; 196.5; 5.0];
tton_trunc_window_us = [2.0; 2.0; 2.0; 2.0];
delta_v_allow_mV = 10 * ones(numel(case_id), 1);
objective = repmat("r049e_tontrunc_holdout", numel(case_id), 1);
role = [
    "baseline_same_model";
    "mild_holdout_ton_truncation";
    "baseline_same_model";
    "mild_holdout_ton_truncation"
];
plan = table(case_id, controller, target_label, objective, role, base_load_A, ...
    target_load_A, load_drop_A, load_step_offset_us, tau_ai_us, ...
    selected_ref_slew_us, vton_trunc_ov_mV, tton_trunc_min_ns, ...
    tton_trunc_window_us, delta_v_allow_mV);
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
spec.vton_trunc_ov_mV = planRow.vton_trunc_ov_mV;
spec.vton_trunc_ov_V = planRow.vton_trunc_ov_mV * 1e-3;
spec.tton_trunc_min_ns = planRow.tton_trunc_min_ns;
spec.tton_trunc_min_s = planRow.tton_trunc_min_ns * 1e-9;
spec.tton_trunc_window_us = planRow.tton_trunc_window_us;
spec.tton_trunc_window_s = planRow.tton_trunc_window_us * 1e-6;
spec.delta_v_allow_mV = planRow.delta_v_allow_mV;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runTonTruncCase(model, spec)
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
in = in.setVariable("Vton_trunc_ov", spec.vton_trunc_ov_V);
in = in.setVariable("Tton_trunc_min", spec.tton_trunc_min_s);
in = in.setVariable("Tton_trunc_window", spec.tton_trunc_window_s);
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
for phase = 1:4
    il(:, phase) = valuesAt(logs, "il" + phase, t);
    qh(:, phase) = valuesAt(logs, "qh" + phase, t);
    tonCmd(:, phase) = valuesAtOptional(logs, "ton_cmd_trunc" + phase, t, NaN(size(t)));
end
truncGlobal = valuesAtOptional(logs, "ton_trunc_global", t, zeros(size(t)));
protectState = valuesAtOptional(logs, "protect_state", t, truncGlobal);
phaseIdx = valuesAtOptional(logs, "phase_idx", t, NaN(size(t)));
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
    truncDuration = NaN;
else
    truncDuration = sum(dt .* (truncGlobal(:) > 0.5));
end
truncEdges = countRisingEdges(truncGlobal);
qhEdges = zeros(1, 4);
tonMinHits = zeros(1, 4);
for phase = 1:4
    qhEdges(phase) = countRisingEdges(qh(:, phase));
    tonMinHits(phase) = sum(abs(tonCmd(:, phase) - spec.tton_trunc_min_s) < 1e-12, "omitnan");
end

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r049e_tontrunc_holdout_wave.csv");
wave = table(1e6 * tRel, vout, spec.load_A * ones(numel(t), 1), ...
    il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), ...
    truncGlobal, protectState, phaseIdx, ...
    tonCmd(:,1), tonCmd(:,2), tonCmd(:,3), tonCmd(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A', ...
    'il1_A','il2_A','il3_A','il4_A','qh1','qh2','qh3','qh4', ...
    'ton_trunc_global','protect_state','phase_idx', ...
    'ton_cmd1_s','ton_cmd2_s','ton_cmd3_s','ton_cmd4_s','iph_ref_A'});
writetable(wave, wavePath);

row = table(true, "", string(planRow.case_id), string(planRow.controller), ...
    string(planRow.target_label), string(planRow.objective), string(planRow.role), ...
    spec.base_load_A, spec.load_A, spec.load_drop_A, spec.load_step_offset_us, ...
    1e6 * spec.t_load_step_s, spec.ref_slew_us, spec.ref_start_delay_us, ...
    spec.vton_trunc_ov_mV, spec.tton_trunc_min_ns, spec.tton_trunc_window_us, ...
    spec.delta_v_allow_mV, v0, il0(1), il0(2), il0(3), il0(4), ...
    qh0(1), qh0(2), qh0(3), qh0(4), ...
    1e9 * remainingTon(1), 1e9 * remainingTon(2), 1e9 * remainingTon(3), 1e9 * remainingTon(4), ...
    1e3 * deltaVActual, tPeakActualUs, 1e3 * secondaryUndershoot, ...
    1e3 * secondaryPp, 1e3 * finalError, 1e6 * truncDuration, truncEdges, ...
    qhEdges(1), qhEdges(2), qhEdges(3), qhEdges(4), ...
    tonMinHits(1), tonMinHits(2), tonMinHits(3), tonMinHits(4), string(wavePath), ...
    'VariableNames', resultNames());
end

function row = failureRow(planRow, message)
nan1x4 = NaN(1, 4);
row = table(false, string(message), string(planRow.case_id), string(planRow.controller), ...
    string(planRow.target_label), string(planRow.objective), string(planRow.role), ...
    planRow.base_load_A, planRow.target_load_A, planRow.load_drop_A, ...
    planRow.load_step_offset_us, NaN, planRow.selected_ref_slew_us, planRow.tau_ai_us, ...
    planRow.vton_trunc_ov_mV, planRow.tton_trunc_min_ns, planRow.tton_trunc_window_us, ...
    planRow.delta_v_allow_mV, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "", ...
    'VariableNames', resultNames());
end

function names = resultNames()
names = {'success','error_message','case_id','controller','target_label','objective','role', ...
    'base_load_A','target_load_A','load_drop_A','load_step_offset_us','t_load_step_us', ...
    'selected_ref_slew_us','tau_ai_us','vton_trunc_ov_mV','tton_trunc_min_ns', ...
    'tton_trunc_window_us','delta_v_allow_mV','vout0_V', ...
    'il1_0_A','il2_0_A','il3_0_A','il4_0_A', ...
    'qh1_at_step','qh2_at_step','qh3_at_step','qh4_at_step', ...
    'remaining_ton1_ns','remaining_ton2_ns','remaining_ton3_ns','remaining_ton4_ns', ...
    'delta_v_actual_peak_mV','t_peak_actual_us','secondary_undershoot_mV', ...
    'secondary_pp_mV','final_error_mV','trunc_duration_us','trunc_edge_count', ...
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
    a0 = sub(sub.controller == "A0_no_trunc", :);
    a2 = sub(sub.controller == "A2_ton_trunc", :);
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
        a2.trunc_duration_us, a2.trunc_edge_count, ...
        a2.remaining_ton4_ns, a2.ton_min_hits1 + a2.ton_min_hits2 + a2.ton_min_hits3 + a2.ton_min_hits4, ...
        'VariableNames', {'load_step_offset_us','a0_peak_mV','a2_peak_mV', ...
        'a2_minus_a0_peak_mV','peak_improvement_mV','a0_t_peak_us','a2_t_peak_us', ...
        'a0_secondary_undershoot_mV','a2_secondary_undershoot_mV','a2_minus_a0_undershoot_mV', ...
        'a0_final_error_mV','a2_final_error_mV','a2_minus_a0_final_error_mV', ...
        'a2_trunc_duration_us','a2_trunc_edge_count','a2_remaining_ton4_ns','a2_total_ton_min_hits'});
    comparison = [comparison; row]; %#ok<AGROW>
end
end

function decision = diagnoseDecision(rows, comparison)
if isempty(rows) || any(~rows.success) || isempty(comparison)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(comparison.a2_minus_a0_peak_mV > 0.05)
    decision = "MODEL_REVISED";
    return;
end
if any(comparison.a2_minus_a0_undershoot_mV < -0.5)
    decision = "MODEL_REVISED";
    return;
end
activeRow = comparison(comparison.load_step_offset_us == 0.05, :);
postTurnoffRow = comparison(comparison.load_step_offset_us == 0.105, :);
if isempty(activeRow)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if activeRow.a2_trunc_duration_us <= 0 && activeRow.a0_peak_mV >= 2.0
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if activeRow.peak_improvement_mV >= 0.05
    if isempty(postTurnoffRow) || postTurnoffRow.a2_minus_a0_peak_mV <= 0.05
        decision = "MODEL_CONFIRMED";
        return;
    end
end
decision = "CLAIM_DOWNGRADED";
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

function instrumentSignals(model)
markBlockOutport(model + "/Voltage Measurement", 1, "vout");
markInportLine(model + "/Goto14", 1, "req_global");
markBlockOutport(model + "/PhaseScheduler_4Phase", 5, "phase_idx");
markBlockOutport(model + "/R049C_TonTrunc_Global", 1, "ton_trunc_global_raw");
markBlockOutport(model + "/R049C_ton_trunc_global_double", 1, "ton_trunc_global");
markBlockOutport(model + "/R049C_protect_state_double", 1, "protect_state");
for phase = 1:4
    markBlockOutport(model + "/IL_Measurement" + phase, 1, "il" + phase);
    markBlockOutport(model + "/GateDriver_1Phase" + phase, 1, "qh" + phase);
    markBlockOutport(model + "/GateDriver_1Phase" + phase, 2, "ql" + phase);
    markBlockOutport(model + "/R049C_Ton_Switch" + phase, 1, "ton_cmd_trunc" + phase);
    markBlockOutport(model + "/R049C_ton_truncate" + phase + "_double", 1, "ton_truncate" + phase);
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
reportPath = fullfile(chunkRoot, "r049e_tontrunc_holdout_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049E Ton-Truncation Mild Hold-Out Dry Run\n\n");
fprintf(fid, "Prepared 40A->20A crossed with two phase offsets.\n\n");
fprintf(fid, "- Derived model: %s\n", modelFile);
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- The completed R049D `.slx` model is copied, not modified.\n\n");
fprintf(fid, "Run with `iqcot_r049e_pr_ecb_tontrunc_holdout_chunk(true)`.\n");
end

function writeRunReport(rows, comparison, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049E PR-ECB Ton-Truncation Mild Hold-Out Chunk\n\n");
fprintf(fid, "Run label: `%s`\n\n", runLabel);
fprintf(fid, "## Scope and hypothesis\n\n");
fprintf(fid, "- Model version: R049E copy of the R049D/R049C command-path Ton-truncation model.\n");
fprintf(fid, "- Hold-out: `40A -> 20A` at offsets `0.05us` and `0.105us`.\n");
fprintf(fid, "- Hypothesis: the active-HS offset should still benefit, but with smaller magnitude, while the post-turnoff offset should remain unchanged.\n");
fprintf(fid, "- Claim boundary: derived-Simulink only; no hardware/HIL claim; no universal additive E_HS,rem claim.\n\n");
fprintf(fid, "## Outputs\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Results: `%s`\n", resultPath);
fprintf(fid, "- Comparison: `%s`\n", comparisonPath);
fprintf(fid, "- Wave snapshots: `output/data/*_r049e_tontrunc_holdout_wave.csv`\n\n");
fprintf(fid, "## Per-case results\n\n");
fprintf(fid, "| case | ctrl | target A | offset us | peak mV | t_peak us | trunc us | trunc edges | rem Ton4 ns | undershoot mV | final mV |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.1f | %.3f | %.4f | %.4f | %.4f | %.0f | %.4f | %.4f | %.4f |\n", ...
            rows.case_id(k), rows.controller(k), rows.target_load_A(k), rows.load_step_offset_us(k), ...
            rows.delta_v_actual_peak_mV(k), rows.t_peak_actual_us(k), ...
            rows.trunc_duration_us(k), rows.trunc_edge_count(k), ...
            rows.remaining_ton4_ns(k), rows.secondary_undershoot_mV(k), rows.final_error_mV(k));
    else
        fprintf(fid, "| %s | %s | %.1f | %.3f | failed | failed | failed | failed | failed | failed | failed |\n", ...
            rows.case_id(k), rows.controller(k), rows.target_load_A(k), rows.load_step_offset_us(k));
    end
end
fprintf(fid, "\n## A2 versus A0 comparison\n\n");
if isempty(comparison)
    fprintf(fid, "No comparison table was produced because at least one case failed.\n\n");
else
    fprintf(fid, "| offset us | A0 peak mV | A2 peak mV | improvement mV | A2 trunc us | A2 Ton-min hits | A2-A0 undershoot mV | A2-A0 final mV |\n");
    fprintf(fid, "|---:|---:|---:|---:|---:|---:|---:|---:|\n");
    for k = 1:height(comparison)
        fprintf(fid, "| %.3f | %.4f | %.4f | %.4f | %.4f | %.0f | %.4f | %.4f |\n", ...
            comparison.load_step_offset_us(k), comparison.a0_peak_mV(k), ...
            comparison.a2_peak_mV(k), comparison.peak_improvement_mV(k), ...
            comparison.a2_trunc_duration_us(k), comparison.a2_total_ton_min_hits(k), ...
            comparison.a2_minus_a0_undershoot_mV(k), comparison.a2_minus_a0_final_error_mV(k));
    end
end
fprintf(fid, "\n## Decision\n\n");
fprintf(fid, "```text\n%s\n```\n\n", decision);
fprintf(fid, "This decision applies only to this R049E mild hold-out chunk.\n");
end
