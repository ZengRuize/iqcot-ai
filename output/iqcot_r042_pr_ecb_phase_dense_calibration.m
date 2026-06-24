function rows = iqcot_r042_pr_ecb_phase_dense_calibration(runSimulink, maxCases, startRow)
%IQCOT_R042_PR_ECB_PHASE_DENSE_CALIBRATION Calibrate PR-ECB across load-step phase and magnitude.
%
% Dry run:
%   iqcot_r042_pr_ecb_phase_dense_calibration(false)
%
% Small true run:
%   iqcot_r042_pr_ecb_phase_dense_calibration(true, 5, 1)
%
% This script does not save or directly edit any .slx file. It loads only the
% derived delayed-reference model in output/simulink_iek and streams selected
% signals through logsout.

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

setappdata(0, "iqcot_r042_run_simulink", runSimulink);
setappdata(0, "iqcot_r042_max_cases", maxCases);
setappdata(0, "iqcot_r042_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r042_run_simulink");
maxCases = getappdata(0, "iqcot_r042_max_cases");
startRow = getappdata(0, "iqcot_r042_start_row");
rmappdata(0, "iqcot_r042_run_simulink");
rmappdata(0, "iqcot_r042_max_cases");
rmappdata(0, "iqcot_r042_start_row");

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
dataRoot = fullfile(outputRoot, "data");
if ~exist(dataRoot, "dir")
    mkdir(dataRoot);
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

fullPlan = buildR042Plan();
planPath = fullfile(outputRoot, "iqcot_r042_pr_ecb_phase_dense_plan.csv");
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
    writeDryRunReport(outputRoot, planPath);
    fprintf("R042_PR_ECB_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run a small true run:\n");
    fprintf("  iqcot_r042_pr_ecb_phase_dense_calibration(true, 5, 1)\n");
    return;
end

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(modelRoot);

load_system(modelFile);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

common = makeCommon();
phys = makePhysicalParams();
rows = table();
for k = 1:height(plan)
    spec = makeR042Spec(plan(k, :), common);
    fprintf("R042 case %s: %.1f A -> %.3f A, offset %.3f us, slew %.3f us, delay %.3f us\n", ...
        string(spec.case_id), spec.base_load_A, spec.load_A, ...
        spec.load_step_offset_us, spec.ref_slew_us, spec.ref_start_delay_us);
    try
        out = runDelayedSlewCase(model, spec);
        logs = out.logsout;
        row = prEcbRowFromLogs(plan(k, :), spec, common, phys, logs, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R042PrEcbCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(outputRoot, "iqcot_r042_pr_ecb_phase_dense_results_" + runLabel + ".csv");
reportPath = fullfile(outputRoot, "iqcot_r042_pr_ecb_phase_dense_report_" + runLabel + ".md");
writetable(rows, resultPath);
writeRunReport(rows, resultPath, reportPath, runLabel);
fprintf("R042_PR_ECB_RESULTS=%s\n", resultPath);
fprintf("R042_PR_ECB_REPORT=%s\n", reportPath);
end

function plan = buildR042Plan()
targetLabels = ["near0", "5A", "10A", "20A"];
targetLoads = [1, 5, 10, 20];
offsets = [0.050, 0.090, 0.105, 0.125, 0.200];
n = numel(targetLabels) * numel(offsets);
case_id = strings(n, 1);
target_label = strings(n, 1);
base_load_A = 40 * ones(n, 1);
target_load_A = zeros(n, 1);
load_step_offset_us = zeros(n, 1);
tau_ai_us = 1.25 * ones(n, 1);
selected_ref_slew_us = zeros(n, 1);
delta_v_allow_mV = 10 * ones(n, 1);
objective = repmat("pr_ecb_phase_dense", n, 1);
role = strings(n, 1);
k = 0;
for ti = 1:numel(targetLabels)
    for oi = 1:numel(offsets)
        k = k + 1;
        token = strrep(sprintf("%.3f", offsets(oi)), ".", "p");
        case_id(k) = "r042_" + targetLabels(ti) + "_off" + token;
        target_label(k) = targetLabels(ti);
        target_load_A(k) = targetLoads(ti);
        load_step_offset_us(k) = offsets(oi);
        if targetLoads(ti) == 20
            selected_ref_slew_us(k) = 46;
        else
            selected_ref_slew_us(k) = 60;
        end
        if offsets(oi) < 0.102
            role(k) = "pre_turnoff_probe";
        elseif offsets(oi) < 0.125
            role(k) = "turnoff_boundary_probe";
        else
            role(k) = "post_turnoff_probe";
        end
    end
end
load_drop_A = base_load_A - target_load_A;
plan = table(case_id, target_label, objective, base_load_A, target_load_A, ...
    load_drop_A, load_step_offset_us, tau_ai_us, selected_ref_slew_us, ...
    delta_v_allow_mV, role);
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
if evalin("base", "exist('Vo_ref','var')")
    common.voRef = evalin("base", "Vo_ref");
else
    common.voRef = 1.0;
end
end

function phys = makePhysicalParams()
phys = struct();
phys.L = evalWithDefault("L", 200e-9) * ones(1, 4);
if evalin("base", "exist('DCR_L1','var')")
    phys.DCR = [evalin("base", "DCR_L1"), evalin("base", "DCR_L2"), ...
        evalin("base", "DCR_L3"), evalin("base", "DCR_L4")];
else
    phys.DCR = evalWithDefault("DCR_L", 10e-3) * ones(1, 4);
end
phys.Cout = evalWithDefault("Cout", 7.26e-3);
phys.ESR = evalWithDefault("ESR_C", 90e-6);
phys.Vin = evalWithDefault("Vin", 12);
phys.Vo_ref = evalWithDefault("Vo_ref", 1.0);
end

function value = evalWithDefault(name, fallback)
if evalin("base", "exist('" + name + "','var')")
    value = evalin("base", name);
else
    value = fallback;
end
end

function spec = makeR042Spec(planRow, common)
spec = struct();
spec.case_id = string(planRow.case_id);
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
spec.delta_v_allow_mV = planRow.delta_v_allow_mV;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runDelayedSlewCase(model, spec)
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

function row = prEcbRowFromLogs(planRow, spec, common, phys, logs, dataRoot)
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
for phase = 1:4
    il(:, phase) = valuesAt(logs, "il" + phase, t);
    qh(:, phase) = valuesAt(logs, "qh" + phase, t);
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

iNewPh = spec.load_A / 4;
energySurplus = 0.5 * sum(phys.L .* max(il0.^2 - iNewPh.^2, 0));
deltaVEnergy = sqrt(max(v0^2 + 2 * energySurplus / phys.Cout, 0)) - v0;

iC = sum(il, 2) - spec.load_A;
crossIdx = find(iC <= 0, 1, "first");
if isempty(crossIdx)
    [~, peakIdxFallback] = max(vout);
    crossIdx = max(2, peakIdxFallback);
end
chargeIntegral = trapz(tRel(1:crossIdx), max(iC(1:crossIdx), 0));
deltaVCharge = chargeIntegral / phys.Cout;
deltaVEsr = phys.ESR * max(sum(il0) - spec.load_A, 0);
deltaVChargeEsr = deltaVCharge + deltaVEsr;
tPkPred = 1e6 * tRel(crossIdx);

[vPeak, idxPeak] = max(vout);
tPeakActualUs = 1e6 * tRel(idxPeak);
deltaVActual = vPeak - common.voRef;
deltaVPred = max(deltaVEnergy, deltaVChargeEsr);
rE = (1e3 * deltaVPred) / spec.delta_v_allow_mV;

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r042_pr_ecb_wave.csv");
Iload = spec.load_A * ones(numel(t), 1);
wave = table(1e6 * tRel, vout, Iload, il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A','il1_A','il2_A','il3_A','il4_A', ...
    'qh1','qh2','qh3','qh4','iph_ref_A'});
writetable(wave, wavePath);

row = table(true, "", string(planRow.case_id), string(planRow.target_label), ...
    string(planRow.objective), string(planRow.role), spec.base_load_A, spec.load_A, ...
    spec.load_drop_A, spec.load_step_offset_us, 1e6 * spec.t_load_step_s, ...
    spec.ref_slew_us, spec.ref_start_delay_us, spec.delta_v_allow_mV, v0, ...
    il0(1), il0(2), il0(3), il0(4), qh0(1), qh0(2), qh0(3), qh0(4), ...
    1e9 * remainingTon(1), 1e9 * remainingTon(2), 1e9 * remainingTon(3), 1e9 * remainingTon(4), ...
    1e6 * energySurplus, 1e3 * deltaVEnergy, 1e3 * deltaVCharge, ...
    1e3 * deltaVEsr, 1e3 * deltaVChargeEsr, tPkPred, ...
    1e3 * deltaVActual, tPeakActualUs, rE, string(wavePath), ...
    'VariableNames', resultNames());
end

function row = failureRow(planRow, message)
nan1x4 = NaN(1, 4);
row = table(false, string(message), string(planRow.case_id), string(planRow.target_label), ...
    string(planRow.objective), string(planRow.role), planRow.base_load_A, planRow.target_load_A, ...
    planRow.load_drop_A, planRow.load_step_offset_us, NaN, planRow.selected_ref_slew_us, ...
    planRow.tau_ai_us, planRow.delta_v_allow_mV, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "", ...
    'VariableNames', resultNames());
end

function names = resultNames()
names = {'success','error_message','case_id','target_label','objective','role', ...
    'base_load_A','target_load_A','load_drop_A','load_step_offset_us','t_load_step_us', ...
    'selected_ref_slew_us','tau_ai_us','delta_v_allow_mV','vout0_V', ...
    'il1_0_A','il2_0_A','il3_0_A','il4_0_A', ...
    'qh1_at_step','qh2_at_step','qh3_at_step','qh4_at_step', ...
    'remaining_ton1_ns','remaining_ton2_ns','remaining_ton3_ns','remaining_ton4_ns', ...
    'energy_surplus_uJ','delta_v_energy_mV','delta_v_charge_mV','delta_v_esr_mV', ...
    'delta_v_charge_esr_mV','t_peak_pred_us','delta_v_actual_peak_mV','t_peak_actual_us', ...
    'r_E','wave_csv'};
end

function values = valuesAt(logs, signalName, queryTime)
series = logs.get(char(signalName)).Values;
t = double(series.Time(:));
y = squeeze(double(series.Data));
values = interp1(t, y, queryTime, "previous", "extrap");
values = values(:);
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

function instrumentSignals(model)
signalSpecs = {
    "33",  1, "vout";
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

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1800));
message = strtrim(message);
end

function writeDryRunReport(outputRoot, planPath)
reportPath = fullfile(outputRoot, "iqcot_r042_pr_ecb_phase_dense_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R042 PR-ECB Phase-Dense Calibration Dry Run\n\n");
fprintf(fid, "Prepared phase-dense high-side remaining-on-time boundary calibration plan.\n\n");
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- Derived model only: output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx\n");
fprintf(fid, "- No original .slx is modified or saved.\n\n");
fprintf(fid, "Run a small batch with iqcot_r042_pr_ecb_phase_dense_calibration(true, 5, 1).\n");
end

function writeRunReport(rows, resultPath, reportPath, runLabel)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R042 PR-ECB Phase-Dense Calibration\n\n");
fprintf(fid, "Run label: %s\n\n", runLabel);
fprintf(fid, "- Results: %s\n", resultPath);
fprintf(fid, "- Wave snapshots: output/data/*_r042_pr_ecb_wave.csv\n\n");
fprintf(fid, "| case | target | offset us | energy mV | charge+ESR mV | actual peak mV | r_E | energy/actual |\n");
fprintf(fid, "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n");
for k = 1:height(rows)
    if rows.success(k)
        ratio = rows.delta_v_energy_mV(k) / max(rows.delta_v_actual_peak_mV(k), eps);
        fprintf(fid, "| %s | %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n", ...
            rows.case_id(k), rows.target_label(k), rows.load_step_offset_us(k), ...
            rows.delta_v_energy_mV(k), rows.delta_v_charge_esr_mV(k), ...
            rows.delta_v_actual_peak_mV(k), rows.r_E(k), ratio);
    else
        fprintf(fid, "| %s | %s | %.3f | failed | failed | failed | NaN | NaN |\n", ...
            rows.case_id(k), rows.target_label(k), rows.load_step_offset_us(k));
    end
end
fprintf(fid, "\nBoundary: derived Simulink and offline post-processing only; not hardware/HIL validation.\n");
end



