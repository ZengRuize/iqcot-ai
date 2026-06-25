function rows = iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(runSimulink, maxCases, startRow)
%IQCOT_R049N_PR_ECB_INDEPENDENT_CLOCK_REENTRY_CHUNK Run independent-clock reentry chunk.
%
% Dry run:
%   iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(false)
%
% True run:
%   iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(true)
%
% Scope: repaired R049K-compatible 40A->20A two-offset chunk.  A2 uses an
% independent upstream phase-clock / predicted-slot release; Ton truncation is
% disabled in A0 and A2.

clc;

if nargin < 1 || isempty(runSimulink), runSimulink = false; end
if nargin < 2 || isempty(maxCases), maxCases = []; end
if nargin < 3 || isempty(startRow), startRow = 1; end
startRow = max(1, round(double(startRow)));

setappdata(0, "iqcot_r049n_run_simulink", runSimulink);
setappdata(0, "iqcot_r049n_max_cases", maxCases);
setappdata(0, "iqcot_r049n_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r049n_run_simulink");
maxCases = getappdata(0, "iqcot_r049n_max_cases");
startRow = getappdata(0, "iqcot_r049n_start_row");
rmappdata(0, "iqcot_r049n_run_simulink");
rmappdata(0, "iqcot_r049n_max_cases");
rmappdata(0, "iqcot_r049n_start_row");

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

modelFile = iqcot_r049n_build_independent_clock_reentry_model();
[~, model] = fileparts(modelFile);

fullPlan = buildPlan();
planPath = fullfile(chunkRoot, "r049n_independent_clock_reentry_plan.csv");
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
    fprintf("R049N_INDEPENDENT_CLOCK_REENTRY_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run the independent-clock reentry chunk:\n");
    fprintf("  iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(true)\n");
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
    fprintf("R049N case %s: %s, %.1f A -> %.3f A, offset %.3f us, release %.3f us\n", ...
        string(spec.case_id), string(spec.controller), spec.base_load_A, spec.load_A, ...
        spec.load_step_offset_us, spec.phase_release_delay_us);
    try
        out = runCase(model, spec);
        row = metricsRowFromLogs(plan(k, :), spec, common, out.logsout, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R049NIndependentClockCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(chunkRoot, "r049n_independent_clock_reentry_results_" + runLabel + ".csv");
comparisonPath = fullfile(chunkRoot, "r049n_independent_clock_reentry_comparison_" + runLabel + ".csv");
reportPath = fullfile(chunkRoot, "r049n_independent_clock_reentry_report_" + runLabel + ".md");
writetable(rows, resultPath);
comparison = compareControllers(rows);
writetable(comparison, comparisonPath);
baselineFailures = checkBaseline(rows);
decision = diagnoseDecision(rows, comparison, baselineFailures);
writeRunReport(rows, comparison, baselineFailures, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel);

fprintf("R049N_INDEPENDENT_CLOCK_REENTRY_RESULTS=%s\n", resultPath);
fprintf("R049N_INDEPENDENT_CLOCK_REENTRY_COMPARISON=%s\n", comparisonPath);
fprintf("R049N_INDEPENDENT_CLOCK_REENTRY_REPORT=%s\n", reportPath);
fprintf("R049N_DECISION=%s\n", decision);
if isempty(baselineFailures)
    fprintf("R049N_BASELINE_CHECK=PASS\n");
else
    fprintf("R049N_BASELINE_CHECK=FAIL\n");
    for k = 1:numel(baselineFailures)
        fprintf("  %s\n", baselineFailures(k));
    end
end
end

function plan = buildPlan()
case_id = [
    "r049n_20A_off0p050_a0";
    "r049n_20A_off0p050_a2_independent_clock";
    "r049n_20A_off0p105_a0";
    "r049n_20A_off0p105_a2_independent_clock"
];
controller = [
    "A0_no_inhibit";
    "A2_independent_clock_reentry";
    "A0_no_inhibit";
    "A2_independent_clock_reentry"
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
    "independent_clock_one_shot_reentry";
    "disabled_negative_window";
    "independent_clock_one_shot_reentry"
];
tton_trunc_min_ns = 196.5 * ones(numel(case_id), 1);
tton_trunc_window_us = -0.001 * ones(numel(case_id), 1);
post_inhibit_delay_us = [0.070; 0.070; 0.070; 0.070];
post_inhibit_window_us = [-0.001; 1.690; -0.001; 1.690];
phase_release_delay_us = [1.685; 1.685; 1.685; 1.685];
delta_v_allow_mV = 10 * ones(numel(case_id), 1);
objective = repmat("r049n_independent_clock_reentry_proxy", numel(case_id), 1);
role = [
    "baseline_same_model";
    "independent_clock_one_shot_reentry";
    "baseline_same_model";
    "independent_clock_one_shot_reentry"
];
plan = table(case_id, controller, target_label, objective, role, trigger_mode, ...
    base_load_A, target_load_A, load_drop_A, load_step_offset_us, tau_ai_us, ...
    selected_ref_slew_us, tton_trunc_min_ns, tton_trunc_window_us, ...
    post_inhibit_delay_us, post_inhibit_window_us, phase_release_delay_us, ...
    delta_v_allow_mV);
end

function runLabel = makeRunLabel(startRow, endRow, fullPlanHeight)
if startRow == 1 && endRow == fullPlanHeight
    runLabel = "full";
else
    runLabel = sprintf("rows%03d_%03d", startRow, endRow);
end
end

function common = makeCommon()
common = struct();
common.lambdaArea = 6e-10;
common.vAreaBias = 2e-3;
common.riArea = 0.5e-3;
common.baseTStep = 0.45e-3;
common.postStepDuration = 0.150e-3;
common.peakWindow = 80e-6;
common.preWindow = 2e-6;
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
spec.post_inhibit_delay_s = spec.post_inhibit_delay_us * 1e-6;
spec.post_inhibit_window_us = planRow.post_inhibit_window_us;
spec.post_inhibit_window_s = spec.post_inhibit_window_us * 1e-6;
spec.phase_release_delay_us = planRow.phase_release_delay_us;
spec.phase_release_delay_s = spec.phase_release_delay_us * 1e-6;
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
in = in.setVariable("Varea_bias", spec.Varea_bias);
in = in.setVariable("Ri_area", spec.Ri_area);
in = in.setVariable("Vton_trunc_ov", 0);
in = in.setVariable("Tton_trunc_min", spec.tton_trunc_min_s);
in = in.setVariable("Tton_trunc_window", spec.tton_trunc_window_s);
in = in.setVariable("Tpost_inhibit_delay", spec.post_inhibit_delay_s);
in = in.setVariable("Tpost_inhibit_window", spec.post_inhibit_window_s);
in = in.setVariable("Tphase_release_delay", spec.phase_release_delay_s);
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
releaseClock = valuesAtOptional(logs, "release_clock", t, zeros(size(t)));
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
for phase = 1:4
    phaseEdges(phase) = countRisingEdges(phaseTrunc(:, phase));
    tonMinHits(phase) = sum(abs(tonCmd(:, phase) - spec.tton_trunc_min_s) < 1e-12, "omitnan");
    qhEdges(phase) = countRisingEdges(qh(:, phase));
    idx = find(phaseTrunc(:, phase) > 0.5, 1, "first");
    if ~isempty(idx)
        firstTruncUs(phase) = 1e6 * tRel(idx);
    end
end

firstInhibitUs = firstTimeUs(inhibitRaw, tRel);
oneshotTimeUs = firstTimeUs(oneShotDone, tRel);
releaseClockTimeUs = firstTimeUs(releaseClock, tRel);
inhibitEdges = countRisingEdges(inhibitRaw);
allowEdges = countRisingEdges(allowCtrl);
reqEdgesDuringInhibit = countReqEdgesDuringInhibit(req, inhibitRaw);
oneShotEdges = countRisingEdges(oneShotDone);
releaseClockEdges = countRisingEdges(releaseClock);

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r049n_independent_clock_reentry_wave.csv");
wave = table(1e6 * tRel, vout, spec.load_A * ones(numel(t), 1), ...
    il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), ...
    req, allowCtrl, inhibitRaw, releaseClock, oneShotDone, phaseIdx, ...
    truncGlobal, ...
    phaseTrunc(:,1), phaseTrunc(:,2), phaseTrunc(:,3), phaseTrunc(:,4), ...
    tonCmd(:,1), tonCmd(:,2), tonCmd(:,3), tonCmd(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A', ...
    'il1_A','il2_A','il3_A','il4_A','qh1','qh2','qh3','qh4', ...
    'req_global','allow_controlled_reentry','inhibit_raw','release_clock','one_shot_done','phase_idx', ...
    'ton_trunc_global', ...
    'ton_truncate1','ton_truncate2','ton_truncate3','ton_truncate4', ...
    'ton_cmd1_s','ton_cmd2_s','ton_cmd3_s','ton_cmd4_s','iph_ref_A'});
writetable(wave, wavePath);

s = baseResult(planRow);
s.success = true;
s.t_load_step_us = 1e6 * spec.t_load_step_s;
s.vout0_V = v0;
s.il1_0_A = il0(1); s.il2_0_A = il0(2); s.il3_0_A = il0(3); s.il4_0_A = il0(4);
s.qh1_at_step = qh0(1); s.qh2_at_step = qh0(2); s.qh3_at_step = qh0(3); s.qh4_at_step = qh0(4);
s.remaining_ton1_ns = 1e9 * remainingTon(1);
s.remaining_ton2_ns = 1e9 * remainingTon(2);
s.remaining_ton3_ns = 1e9 * remainingTon(3);
s.remaining_ton4_ns = 1e9 * remainingTon(4);
s.delta_v_actual_peak_mV = 1e3 * deltaVActual;
s.t_peak_actual_us = tPeakActualUs;
s.secondary_undershoot_mV = 1e3 * secondaryUndershoot;
s.secondary_pp_mV = 1e3 * secondaryPp;
s.final_error_mV = 1e3 * finalError;
s.global_trunc_duration_us = 1e6 * globalDuration;
s.trunc_duration1_us = 1e6 * phaseDuration(1);
s.trunc_duration2_us = 1e6 * phaseDuration(2);
s.trunc_duration3_us = 1e6 * phaseDuration(3);
s.trunc_duration4_us = 1e6 * phaseDuration(4);
s.trunc_edges1 = phaseEdges(1); s.trunc_edges2 = phaseEdges(2);
s.trunc_edges3 = phaseEdges(3); s.trunc_edges4 = phaseEdges(4);
s.first_trunc1_us = firstTruncUs(1); s.first_trunc2_us = firstTruncUs(2);
s.first_trunc3_us = firstTruncUs(3); s.first_trunc4_us = firstTruncUs(4);
s.inhibit_raw_duration_us = 1e6 * inhibitRawDuration;
s.effective_inhibit_duration_us = 1e6 * effectiveInhibitDuration;
s.inhibit_edge_count = inhibitEdges;
s.req_edges_during_inhibit = reqEdgesDuringInhibit;
s.allow_edge_count = allowEdges;
s.release_clock_edge_count = releaseClockEdges;
s.release_clock_time_us = releaseClockTimeUs;
s.one_shot_edge_count = oneShotEdges;
s.first_inhibit_us = firstInhibitUs;
s.one_shot_time_us = oneshotTimeUs;
s.qh1_edge_count = qhEdges(1); s.qh2_edge_count = qhEdges(2);
s.qh3_edge_count = qhEdges(3); s.qh4_edge_count = qhEdges(4);
s.ton_min_hits1 = tonMinHits(1); s.ton_min_hits2 = tonMinHits(2);
s.ton_min_hits3 = tonMinHits(3); s.ton_min_hits4 = tonMinHits(4);
s.wave_csv = string(wavePath);
row = struct2table(s, "AsArray", true);
end

function row = failureRow(planRow, message)
s = baseResult(planRow);
s.error_message = string(message);
row = struct2table(s, "AsArray", true);
end

function s = baseResult(planRow)
N = NaN;
s = struct();
s.success = false;
s.error_message = "";
s.case_id = string(planRow.case_id);
s.controller = string(planRow.controller);
s.target_label = string(planRow.target_label);
s.objective = string(planRow.objective);
s.role = string(planRow.role);
s.trigger_mode = string(planRow.trigger_mode);
s.base_load_A = planRow.base_load_A;
s.target_load_A = planRow.target_load_A;
s.load_drop_A = planRow.load_drop_A;
s.load_step_offset_us = planRow.load_step_offset_us;
s.t_load_step_us = N;
s.selected_ref_slew_us = planRow.selected_ref_slew_us;
s.tau_ai_us = planRow.tau_ai_us;
s.tton_trunc_min_ns = planRow.tton_trunc_min_ns;
s.tton_trunc_window_us = planRow.tton_trunc_window_us;
s.post_inhibit_delay_us = planRow.post_inhibit_delay_us;
s.post_inhibit_window_us = planRow.post_inhibit_window_us;
s.phase_release_delay_us = planRow.phase_release_delay_us;
s.delta_v_allow_mV = planRow.delta_v_allow_mV;
s.vout0_V = N;
s.il1_0_A = N; s.il2_0_A = N; s.il3_0_A = N; s.il4_0_A = N;
s.qh1_at_step = N; s.qh2_at_step = N; s.qh3_at_step = N; s.qh4_at_step = N;
s.remaining_ton1_ns = N; s.remaining_ton2_ns = N; s.remaining_ton3_ns = N; s.remaining_ton4_ns = N;
s.delta_v_actual_peak_mV = N; s.t_peak_actual_us = N; s.secondary_undershoot_mV = N;
s.secondary_pp_mV = N; s.final_error_mV = N; s.global_trunc_duration_us = N;
s.trunc_duration1_us = N; s.trunc_duration2_us = N; s.trunc_duration3_us = N; s.trunc_duration4_us = N;
s.trunc_edges1 = N; s.trunc_edges2 = N; s.trunc_edges3 = N; s.trunc_edges4 = N;
s.first_trunc1_us = N; s.first_trunc2_us = N; s.first_trunc3_us = N; s.first_trunc4_us = N;
s.inhibit_raw_duration_us = N; s.effective_inhibit_duration_us = N; s.inhibit_edge_count = N;
s.req_edges_during_inhibit = N; s.allow_edge_count = N;
s.release_clock_edge_count = N; s.release_clock_time_us = N;
s.one_shot_edge_count = N; s.first_inhibit_us = N; s.one_shot_time_us = N;
s.qh1_edge_count = N; s.qh2_edge_count = N; s.qh3_edge_count = N; s.qh4_edge_count = N;
s.ton_min_hits1 = N; s.ton_min_hits2 = N; s.ton_min_hits3 = N; s.ton_min_hits4 = N;
s.wave_csv = "";
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
    a2 = sub(sub.controller == "A2_independent_clock_reentry", :);
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
        a2.release_clock_edge_count, a2.release_clock_time_us, ...
        a2.req_edges_during_inhibit, a2.one_shot_edge_count, ...
        a2.first_inhibit_us, a2.one_shot_time_us, ...
        'VariableNames', {'load_step_offset_us', 'a0_peak_mV', 'a2_peak_mV', ...
        'a2_minus_a0_peak_mV', 'peak_improvement_mV', ...
        'a0_t_peak_us', 'a2_t_peak_us', ...
        'a0_undershoot_mV', 'a2_undershoot_mV', 'a2_minus_a0_undershoot_mV', ...
        'a0_final_error_mV', 'a2_final_error_mV', 'a2_minus_a0_final_error_mV', ...
        'a0_remaining_ton4_ns', 'a2_remaining_ton4_ns', 'remaining_ton4_reduction_ns', ...
        'a2_inhibit_raw_duration_us', 'a2_effective_inhibit_duration_us', ...
        'a2_release_clock_edge_count', 'a2_release_clock_time_us', ...
        'a2_req_edges_during_inhibit', 'a2_one_shot_edge_count', ...
        'a2_first_inhibit_us', 'a2_one_shot_time_us'})]; %#ok<AGROW>
end
end

function failures = checkBaseline(rows)
failures = strings(0, 1);
if isempty(rows) || any(~rows.success)
    failures(end+1, 1) = "one or more cases failed";
    return;
end
refs = table([0.050; 0.105], [450.050; 450.105], [2.1103; 2.0936], ...
    [1; 0], [50.5; 0.0], ...
    'VariableNames', {'offset_us','t_load_us','peak_mV','qh4','remaining_ton4_ns'});
for k = 1:height(refs)
    a0 = rows(rows.controller == "A0_no_inhibit" & abs(rows.load_step_offset_us - refs.offset_us(k)) < 1e-12, :);
    if height(a0) ~= 1
        failures(end+1, 1) = sprintf("offset %.3fus: expected one A0 row, found %d", refs.offset_us(k), height(a0));
        continue;
    end
    if abs(a0.t_load_step_us - refs.t_load_us(k)) > 0.001
        failures(end+1, 1) = sprintf("offset %.3fus: t_load %.6fus vs %.6fus", refs.offset_us(k), a0.t_load_step_us, refs.t_load_us(k));
    end
    if abs(a0.delta_v_actual_peak_mV - refs.peak_mV(k)) > 0.02
        failures(end+1, 1) = sprintf("offset %.3fus: A0 peak %.4fmV vs %.4fmV", refs.offset_us(k), a0.delta_v_actual_peak_mV, refs.peak_mV(k));
    end
    if round(a0.qh4_at_step) ~= refs.qh4(k)
        failures(end+1, 1) = sprintf("offset %.3fus: qh4_at_step %.0f vs %.0f", refs.offset_us(k), a0.qh4_at_step, refs.qh4(k));
    end
    if abs(a0.remaining_ton4_ns - refs.remaining_ton4_ns(k)) > 2.0
        failures(end+1, 1) = sprintf("offset %.3fus: remaining Ton4 %.4fns vs %.4fns", refs.offset_us(k), a0.remaining_ton4_ns, refs.remaining_ton4_ns(k));
    end
end
end

function decision = diagnoseDecision(rows, comparison, baselineFailures)
if ~isempty(baselineFailures) || isempty(comparison) || any(~rows.success)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
a2Rows = rows(rows.controller == "A2_independent_clock_reentry", :);
if isempty(a2Rows) || any(a2Rows.one_shot_edge_count < 1) || any(isnan(a2Rows.one_shot_time_us))
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(a2Rows.release_clock_edge_count < 1) || any(isnan(a2Rows.release_clock_time_us))
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
if any(abs(a2Rows.global_trunc_duration_us) > 1e-6)
    decision = "IMPLEMENTATION_ISSUE";
    return;
end
hasPeakImprovement = any(comparison.peak_improvement_mV > 0.02);
hasUndershootPenalty = any(comparison.a2_minus_a0_undershoot_mV < -0.02);
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
    v = interp1(double(s.Time(:)), squeeze(double(s.Data)), queryTime, "nearest", "extrap");
    v = double(v);
catch
    v = NaN;
end
end

function remaining = remainingHighSideOnTime(logs, signalName, t0, windowEnd)
try
    series = logs.get(char(signalName)).Values;
catch
    remaining = NaN;
    return;
end
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

function tUs = firstTimeUs(x, tRel)
idx = find(x(:) > 0.5, 1, "first");
if isempty(idx)
    tUs = NaN;
else
    tUs = 1e6 * tRel(idx);
end
end

function instrumentSignals(model)
try; markBlockOutport(model + "/Voltage Measurement", 1, "vout"); catch; end
try; markInportLine(model + "/Goto14", 1, "req_global"); catch; end
try; markInportLine(model + "/Goto16", 1, "existing_allow"); catch; end
try; markBlockOutport(model + "/PhaseScheduler_4Phase", 5, "phase_idx"); catch; end
try; markBlockOutport(model + "/R049C_TonTrunc_Global", 1, "early_ton_trunc_global_raw"); catch; end
try; markBlockOutport(model + "/R049C_ton_trunc_global_double", 1, "ton_trunc_global"); catch; end
try; markBlockOutport(model + "/R049N_one_shot_done_double", 1, "one_shot_done"); catch; end
try; markBlockOutport(model + "/R049N_inhibit_raw_double", 1, "inhibit_raw"); catch; end
try; markBlockOutport(model + "/R049N_allow_controlled_double", 1, "allow_controlled_reentry"); catch; end
try; markBlockOutport(model + "/R049N_release_clock_double", 1, "release_clock"); catch; end
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
reportPath = fullfile(chunkRoot, "r049n_independent_clock_reentry_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049N Independent-Clock Reentry Dry Run\n\n");
fprintf(fid, "Prepared 40A->20A crossed with two phase offsets.\n\n");
fprintf(fid, "- Derived model: %s\n", modelFile);
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- Source: R049L repair derived model.\n");
fprintf(fid, "- A2 uses an independent upstream timer / predicted-slot one-shot reentry.\n");
fprintf(fid, "- Release clock threshold: `t_load_step + 1.685 us`.\n");
fprintf(fid, "- Ton truncation disabled in both A0 and A2.\n\n");
fprintf(fid, "Run with `iqcot_r049n_pr_ecb_independent_clock_reentry_chunk(true)`.\n");
end

function writeRunReport(rows, comparison, baselineFailures, decision, resultPath, comparisonPath, reportPath, modelFile, runLabel)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049N PR-ECB Independent-Clock One-Shot Reentry Chunk\n\n");
fprintf(fid, "Run label: `%s`\n\n", runLabel);
fprintf(fid, "## Scope\n\n");
fprintf(fid, "- Model: R049N copy of R049L repair with independent upstream release clock.\n");
fprintf(fid, "- Diagnostic: `40A -> 20A` at offsets `0.05us` and `0.105us`.\n");
fprintf(fid, "- A2: release at `t_load_step + 1.685us` during inhibit; Ton truncation disabled.\n");
fprintf(fid, "- A0: same model, negative inhibit window; Ton truncation disabled.\n");
fprintf(fid, "- R049K-compatible operating parameters restored.\n\n");
fprintf(fid, "## Outputs\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Results: `%s`\n", resultPath);
fprintf(fid, "- Comparison: `%s`\n", comparisonPath);
fprintf(fid, "- Wave: `output/data/*_r049n_independent_clock_reentry_wave.csv`\n\n");
fprintf(fid, "## Baseline quality gate\n\n");
if isempty(baselineFailures)
    fprintf(fid, "Baseline check: `PASS`.\n\n");
else
    fprintf(fid, "Baseline check: `FAIL`.\n\n");
    for k = 1:numel(baselineFailures)
        fprintf(fid, "- %s\n", baselineFailures(k));
    end
    fprintf(fid, "\n");
end
fprintf(fid, "## Per-case results\n\n");
fprintf(fid, "| case | ctrl | offset us | peak mV | t_peak us | rem Ton4 ns | release us | one-shot us | inhibit raw us | effective inhibit us | undershoot mV | final mV |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.3f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k), ...
            rows.delta_v_actual_peak_mV(k), rows.t_peak_actual_us(k), rows.remaining_ton4_ns(k), ...
            rows.release_clock_time_us(k), rows.one_shot_time_us(k), ...
            rows.inhibit_raw_duration_us(k), rows.effective_inhibit_duration_us(k), ...
            rows.secondary_undershoot_mV(k), rows.final_error_mV(k));
    else
        fprintf(fid, "| %s | %s | %.3f | failed | failed | failed | failed | failed | failed | failed | failed | failed |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k));
    end
end
fprintf(fid, "\n## Pair comparison\n\n");
if isempty(comparison)
    fprintf(fid, "No valid A0/A2 comparison was produced.\n\n");
else
    fprintf(fid, "| offset us | peak improvement mV | A2-A0 undershoot mV | A2 one-shot us | A2 effective inhibit us |\n");
    fprintf(fid, "|---:|---:|---:|---:|---:|\n");
    for k = 1:height(comparison)
        fprintf(fid, "| %.3f | %.4f | %.4f | %.4f | %.4f |\n", ...
            comparison.load_step_offset_us(k), comparison.peak_improvement_mV(k), ...
            comparison.a2_minus_a0_undershoot_mV(k), comparison.a2_one_shot_time_us(k), ...
            comparison.a2_effective_inhibit_duration_us(k));
    end
    fprintf(fid, "\n");
end
fprintf(fid, "## Decision\n\n");
fprintf(fid, "```text\n%s\n```\n\n", decision);
fprintf(fid, "This decision applies only to the R049N independent-clock one-shot reentry chunk.\n");
end
