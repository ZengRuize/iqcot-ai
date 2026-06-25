function rows = iqcot_r049r_pr_ecb_release_between_point_audit(runSimulink)
%IQCOT_R049R_PR_ECB_RELEASE_BETWEEN_POINT_AUDIT Test one between-point binary release.
%
% R049R keeps the R049N upstream-causal release interface and tests exactly
% one binary release delay between R049P and R049Q:
%
%   Tphase_release_delay = 1.615 us
%
% This is intentionally narrower than R049O.  It probes the knee between the
% useful-but-penalized 1.600us point and the more penalized 1.630us point.

clc;

if nargin < 1 || isempty(runSimulink), runSimulink = false; end
setappdata(0, "iqcot_r049r_run_simulink", runSimulink);
run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");
runSimulink = getappdata(0, "iqcot_r049r_run_simulink");
rmappdata(0, "iqcot_r049r_run_simulink");

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
plan = buildPlan();
planPath = fullfile(chunkRoot, "r049r_release_between_point_plan.csv");
writetable(plan, planPath);

if ~runSimulink
    rows = plan;
    writeDryRunReport(chunkRoot, planPath, modelFile);
    fprintf("R049R_RELEASE_BETWEEN_POINT_PLAN=%s\n", planPath);
    fprintf("Dry run only. Run with iqcot_r049r_pr_ecb_release_between_point_audit(true).\n");
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
    fprintf("R049R case %s: %s, offset %.3fus, release %.3fus\n", ...
        string(spec.case_id), string(spec.controller), spec.load_step_offset_us, spec.phase_release_delay_us);
    try
        out = runCase(model, spec);
        rows = [rows; metricsRowFromLogs(plan(k, :), spec, common, out.logsout, dataRoot)]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R049RReleaseBetweenPointCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(chunkRoot, "r049r_release_between_point_results_full.csv");
reportPath = fullfile(chunkRoot, "r049r_release_between_point_report_full.md");
writetable(rows, resultPath);
writeRunReport(rows, resultPath, reportPath, modelFile);
fprintf("R049R_RELEASE_BETWEEN_POINT_RESULTS=%s\n", resultPath);
fprintf("R049R_RELEASE_BETWEEN_POINT_REPORT=%s\n", reportPath);
end

function plan = buildPlan()
case_id = [
    "r049r_20A_off0p050_a0";
    "r049r_20A_off0p050_a2_rel1p615";
    "r049r_20A_off0p105_a0";
    "r049r_20A_off0p105_a2_rel1p615"
];
controller = [
    "A0_no_inhibit";
    "A2_release_1p615us";
    "A0_no_inhibit";
    "A2_release_1p615us"
];
role = [
    "baseline_same_model";
    "release_between_point_probe";
    "baseline_same_model";
    "release_between_point_probe"
];
trigger_mode = [
    "disabled_negative_window";
    "release_timing_1p615us";
    "disabled_negative_window";
    "release_timing_1p615us"
];
load_step_offset_us = [0.050; 0.050; 0.105; 0.105];
post_inhibit_window_us = [-0.001; 1.690; -0.001; 1.690];
phase_release_delay_us = 1.615 * ones(4, 1);
base_load_A = 40 * ones(4, 1);
target_load_A = 20 * ones(4, 1);
load_drop_A = base_load_A - target_load_A;
tau_ai_us = 1.25 * ones(4, 1);
selected_ref_slew_us = 60 * ones(4, 1);
tton_trunc_min_ns = 196.5 * ones(4, 1);
tton_trunc_window_us = -0.001 * ones(4, 1);
post_inhibit_delay_us = 0.070 * ones(4, 1);
plan = table(case_id, controller, role, trigger_mode, base_load_A, ...
    target_load_A, load_drop_A, load_step_offset_us, tau_ai_us, ...
    selected_ref_slew_us, tton_trunc_min_ns, tton_trunc_window_us, ...
    post_inhibit_delay_us, post_inhibit_window_us, phase_release_delay_us);
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
spec.role = string(planRow.role);
spec.trigger_mode = string(planRow.trigger_mode);
spec.base_load_A = planRow.base_load_A;
spec.load_A = planRow.target_load_A;
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
spec.tton_trunc_min_s = planRow.tton_trunc_min_ns * 1e-9;
spec.tton_trunc_window_s = planRow.tton_trunc_window_us * 1e-6;
spec.post_inhibit_delay_us = planRow.post_inhibit_delay_us;
spec.post_inhibit_delay_s = spec.post_inhibit_delay_us * 1e-6;
spec.post_inhibit_window_us = planRow.post_inhibit_window_us;
spec.post_inhibit_window_s = spec.post_inhibit_window_us * 1e-6;
spec.phase_release_delay_us = planRow.phase_release_delay_us;
spec.phase_release_delay_s = spec.phase_release_delay_us * 1e-6;
spec.Lambda_area = common.lambdaArea;
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runCase(model, spec)
in = Simulink.SimulationInput(model);
in = in.setModelParameter("StopTime", num2str(spec.stopTime, "%.15g"), ...
    "MaxStep", "5e-9", "SignalLogging", "on", "SignalLoggingName", "logsout", ...
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
    in = in.setVariable("Lambda" + phase, spec.Lambda_area);
    in = in.setVariable("Ton_trim" + phase, 0);
end
out = sim(in, "ShowProgress", "off");
end

function ts = makeDelayedIphRefTimeseries(spec)
start = spec.t_load_step_s + max(spec.ref_start_delay_s, 0);
finish = start + max(spec.ref_slew_s, 5e-9);
t = [0; spec.t_load_step_s; start; finish; spec.stopTime];
y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
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

qh4 = valuesAt(logs, "qh4", t);
req = valuesAtOptional(logs, "req_global", t, zeros(size(t)));
allowCtrl = valuesAtOptional(logs, "allow_controlled_reentry", t, zeros(size(t)));
inhibitRaw = valuesAtOptional(logs, "inhibit_raw", t, zeros(size(t)));
releaseClock = valuesAtOptional(logs, "release_clock", t, zeros(size(t)));
oneShotDone = valuesAtOptional(logs, "one_shot_done", t, zeros(size(t)));
truncGlobal = valuesAtOptional(logs, "ton_trunc_global", t, zeros(size(t)));

v0 = mean(vAll(tAll >= t0 - common.preWindow & tAll <= t0), "omitnan");
if isnan(v0), v0 = valueAt(logs, "vout", t0); end
[vPeak, idxPeak] = max(vout);
postPeak = idxPeak:numel(vout);
finalMask = t >= (windowEnd - common.finalWindow) & t <= windowEnd;

dt = [diff(t); median(diff(t), "omitnan")];
if isempty(dt) || any(isnan(dt))
    inhibitRawDuration = NaN;
    effectiveInhibitDuration = NaN;
    truncDuration = NaN;
else
    inhibitRawDuration = sum(dt .* (inhibitRaw(:) > 0.5));
    effectiveInhibitDuration = sum(dt .* (inhibitRaw(:) > 0.5 & oneShotDone(:) < 0.5));
    truncDuration = sum(dt .* (truncGlobal(:) > 0.5));
end

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r049r_release_between_point_wave.csv");
wave = table(1e6 * tRel, vout, spec.load_A * ones(numel(t), 1), qh4, ...
    req, allowCtrl, inhibitRaw, releaseClock, oneShotDone, truncGlobal, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A','qh4', ...
    'req_global','allow_controlled_reentry','inhibit_raw','release_clock', ...
    'one_shot_done','ton_trunc_global'});
writetable(wave, wavePath);

s = baseResult(planRow);
s.success = true;
s.t_load_step_us = 1e6 * spec.t_load_step_s;
s.vout0_V = v0;
s.qh4_at_step = valueAt(logs, "qh4", t0);
s.remaining_ton4_ns = 1e9 * remainingHighSideOnTime(logs, "qh4", t0, windowEnd);
s.delta_v_actual_peak_mV = 1e3 * (vPeak - common.voRef);
s.t_peak_actual_us = 1e6 * tRel(idxPeak);
s.secondary_undershoot_mV = 1e3 * min(vout(postPeak) - common.voRef);
s.final_error_mV = 1e3 * (mean(vout(finalMask), "omitnan") - common.voRef);
s.global_trunc_duration_us = 1e6 * truncDuration;
s.inhibit_raw_duration_us = 1e6 * inhibitRawDuration;
s.effective_inhibit_duration_us = 1e6 * effectiveInhibitDuration;
s.release_clock_edge_count = countRisingEdges(releaseClock);
s.release_clock_time_us = firstTimeUs(releaseClock, tRel);
s.one_shot_edge_count = countRisingEdges(oneShotDone);
s.one_shot_time_us = firstTimeUs(oneShotDone, tRel);
s.req_edges_during_inhibit = countReqEdgesDuringInhibit(req, inhibitRaw);
s.wave_csv = string(wavePath);
row = struct2table(s, "AsArray", true);
end

function s = baseResult(planRow)
N = NaN;
s = struct("success", false, "error_message", "", ...
    "case_id", string(planRow.case_id), "controller", string(planRow.controller), ...
    "role", string(planRow.role), "trigger_mode", string(planRow.trigger_mode), ...
    "load_step_offset_us", planRow.load_step_offset_us, ...
    "phase_release_delay_us", planRow.phase_release_delay_us, ...
    "t_load_step_us", N, "vout0_V", N, "qh4_at_step", N, ...
    "remaining_ton4_ns", N, "delta_v_actual_peak_mV", N, ...
    "t_peak_actual_us", N, "secondary_undershoot_mV", N, ...
    "final_error_mV", N, "global_trunc_duration_us", N, ...
    "inhibit_raw_duration_us", N, "effective_inhibit_duration_us", N, ...
    "release_clock_edge_count", N, "release_clock_time_us", N, ...
    "one_shot_edge_count", N, "one_shot_time_us", N, ...
    "req_edges_during_inhibit", N, "wave_csv", "");
end

function row = failureRow(planRow, message)
s = baseResult(planRow);
s.error_message = string(message);
row = struct2table(s, "AsArray", true);
end

function y = valuesAt(logs, signalName, queryTime)
try
    s = logs.get(char(signalName)).Values;
    y = interp1(double(s.Time(:)), squeeze(double(s.Data)), double(queryTime), "previous", "extrap");
catch
    y = zeros(size(queryTime));
end
y = double(y);
end

function y = valuesAtOptional(logs, signalName, queryTime, fallback)
try
    s = logs.get(char(signalName)).Values;
    y = interp1(double(s.Time(:)), squeeze(double(s.Data)), double(queryTime), "previous", "extrap");
    y = double(y);
catch
    if isscalar(fallback)
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
catch
    v = NaN;
end
v = double(v);
end

function remaining = remainingHighSideOnTime(logs, signalName, t0, windowEnd)
try
    series = logs.get(char(signalName)).Values;
catch
    remaining = NaN;
    return;
end
if valueAt(logs, signalName, t0) <= 0.5
    remaining = 0;
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

function n = countRisingEdges(x)
n = sum(diff([0; x(:)]) > 0.5);
end

function n = countReqEdgesDuringInhibit(req, inhibit)
active = req(:) > 0.5 & inhibit(:) > 0.5;
n = sum(diff([0; req(active)]) > 0.5);
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
try; markBlockOutport(model + "/R049C_ton_trunc_global_double", 1, "ton_trunc_global"); catch; end
try; markBlockOutport(model + "/R049N_one_shot_done_double", 1, "one_shot_done"); catch; end
try; markBlockOutport(model + "/R049N_inhibit_raw_double", 1, "inhibit_raw"); catch; end
try; markBlockOutport(model + "/R049N_allow_controlled_double", 1, "allow_controlled_reentry"); catch; end
try; markBlockOutport(model + "/R049N_release_clock_double", 1, "release_clock"); catch; end
try; markBlockOutport(model + "/Phase4/q_hs", 1, "qh4"); catch; end
end

function markInportLine(blockPath, inportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1, return; end
srcPort = get_param(lineHandle, "SrcPortHandle");
lineHandle = get_param(srcPort, "Line");
if lineHandle ~= -1, set_param(lineHandle, "Name", char(signalName)); end
Simulink.sdi.markSignalForStreaming(srcPort, "on");
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber, return; end
portHandle = ports.Outport(outportNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1, set_param(lineHandle, "Name", char(signalName)); end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1600));
message = strtrim(message);
end

function writeDryRunReport(chunkRoot, planPath, modelFile)
reportPath = fullfile(chunkRoot, "r049r_release_between_point_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049R Release-Between-Point Dry Run\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Plan: `%s`\n", planPath);
fprintf(fid, "- Release delay: `1.615 us`.\n");
end

function writeRunReport(rows, resultPath, reportPath, modelFile)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, "# R049R PR-ECB Release-Between-Point Audit\n\n");
fprintf(fid, "- Model: `%s`\n", modelFile);
fprintf(fid, "- Results: `%s`\n\n", resultPath);
fprintf(fid, "| case | ctrl | offset us | release us | peak mV | undershoot mV | one-shot us | eff inhibit us |\n");
fprintf(fid, "|---|---|---:|---:|---:|---:|---:|---:|\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.3f | %.3f | %.4f | %.4f | %.4f | %.4f |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k), ...
            rows.phase_release_delay_us(k), rows.delta_v_actual_peak_mV(k), ...
            rows.secondary_undershoot_mV(k), rows.one_shot_time_us(k), ...
            rows.effective_inhibit_duration_us(k));
    else
        fprintf(fid, "| %s | %s | %.3f | %.3f | failed | failed | failed | failed |\n", ...
            rows.case_id(k), rows.controller(k), rows.load_step_offset_us(k), ...
            rows.phase_release_delay_us(k));
    end
end
end
