function rows = iqcot_r039_pr_ecb_large_signal_probe(runSimulink, maxCases, startRow)
%IQCOT_R039_PR_ECB_LARGE_SIGNAL_PROBE Prototype PR-ECB large-signal validation.
%
% Dry run:
%   iqcot_r039_pr_ecb_large_signal_probe(false)
%
% One-case smoke run on the derived model:
%   iqcot_r039_pr_ecb_large_signal_probe(true, 1, 1)
%
% This script does not save or directly edit any .slx file. It loads only the
% derived delayed-reference model in output/simulink_iek, streams selected
% signals through logsout, and exports first-peak wave snapshots for the
% phase-resolved energy-charge boundary (PR-ECB) model.

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

setappdata(0, "iqcot_r039_run_simulink", runSimulink);
setappdata(0, "iqcot_r039_max_cases", maxCases);
setappdata(0, "iqcot_r039_start_row", startRow);

run("E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\init_four_phase_cot_sync.m");

runSimulink = getappdata(0, "iqcot_r039_run_simulink");
maxCases = getappdata(0, "iqcot_r039_max_cases");
startRow = getappdata(0, "iqcot_r039_start_row");
rmappdata(0, "iqcot_r039_run_simulink");
rmappdata(0, "iqcot_r039_max_cases");
rmappdata(0, "iqcot_r039_start_row");

initRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
srcRoot = initRoot;
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
dataRoot = fullfile(outputRoot, "data");
figureRoot = fullfile(outputRoot, "figures");
if ~exist(dataRoot, "dir")
    mkdir(dataRoot);
end
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

plan = buildR039Plan();
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
runLabel = makeRunLabel(startRow, endRow, fullPlanHeight);

planPath = fullfile(outputRoot, "iqcot_r039_pr_ecb_large_signal_plan.csv");
writetable(buildR039Plan(), planPath);

if ~runSimulink
    rows = plan;
    writeDryRunReport(outputRoot, planPath);
    fprintf("R039_PR_ECB_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run a smoke case:\n");
    fprintf("  iqcot_r039_pr_ecb_large_signal_probe(true, 1, 1)\n");
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
    spec = makeR039Spec(plan(k, :), common);
    fprintf("R039 case %s: %.1f A -> %.1f A, slew %.3f us, delay %.3f us\n", ...
        string(spec.case_id), spec.base_load_A, spec.load_A, ...
        spec.ref_slew_us, spec.ref_start_delay_us);
    try
        out = runDelayedSlewCase(model, spec, common);
        logs = out.logsout;
        row = prEcbRowFromLogs(plan(k, :), spec, common, phys, logs, dataRoot);
        rows = [rows; row]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(plan(k, :), compactErrorReport(ME))]; %#ok<AGROW>
        warning("iqcot:R039PrEcbCaseFailed", "Case failed: %s", compactErrorReport(ME));
    end
end

resultPath = fullfile(outputRoot, "iqcot_r039_pr_ecb_large_signal_results_" + runLabel + ".csv");
writetable(rows, resultPath);
writeRunReport(rows, outputRoot, resultPath, runLabel);
fprintf("R039_PR_ECB_RESULTS=%s\n", resultPath);
end

function plan = buildR039Plan()
case_id = ["r039_20A_tau1p25_slew46"; "r039_20A_tau1p50_slew50"; ...
    "r039_20A_tau1p75_slew54"; "r039_20A_tau2p00_slew30"; ...
    "r039_20A_tau2p00_slew48"];
target_label = repmat("20A", numel(case_id), 1);
objective = repmat("score_settle005", numel(case_id), 1);
base_load_A = 40 * ones(numel(case_id), 1);
target_load_A = 20 * ones(numel(case_id), 1);
load_drop_A = base_load_A - target_load_A;
tau_ai_us = [1.25; 1.50; 1.75; 2.00; 2.00];
selected_ref_slew_us = [46; 50; 54; 30; 48];
role = ["folded_anchor"; "folded_anchor"; "folded_anchor"; ...
    "dense_fallback"; "r038_near_tie_probe"];
source = ["R036/R038"; "R037/R038"; "R036/R038"; "R031/R038"; "R038"];
delta_v_allow_mV = 10 * ones(numel(case_id), 1);
plan = table(case_id, target_label, objective, base_load_A, target_load_A, ...
    load_drop_A, tau_ai_us, selected_ref_slew_us, role, source, delta_v_allow_mV);
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
common.tStep = 0.45e-3;
common.stopTime = 0.60e-3;
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

function spec = makeR039Spec(planRow, common)
spec = struct();
spec.case_id = string(planRow.case_id);
spec.base_load_A = planRow.base_load_A;
spec.load_A = planRow.target_load_A;
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

function row = prEcbRowFromLogs(planRow, spec, common, phys, logs, dataRoot)
t0 = common.tStep;
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
iphRef = iphRefAt(spec, common, t);
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

wavePath = fullfile(dataRoot, string(spec.case_id) + "_r039_pr_ecb_wave.csv");
Iload = spec.load_A * ones(numel(t), 1);
wave = table(1e6 * tRel, vout, Iload, il(:,1), il(:,2), il(:,3), il(:,4), ...
    qh(:,1), qh(:,2), qh(:,3), qh(:,4), iphRef, ...
    'VariableNames', {'time_from_load_step_us','vout_V','iload_A','il1_A','il2_A','il3_A','il4_A', ...
    'qh1','qh2','qh3','qh4','iph_ref_A'});
writetable(wave, wavePath);

row = table(true, "", string(planRow.case_id), string(planRow.role), ...
    string(planRow.source), string(planRow.objective), ...
    spec.base_load_A, spec.load_A, spec.ref_slew_us, spec.ref_start_delay_us, ...
    spec.delta_v_allow_mV, v0, il0(1), il0(2), il0(3), il0(4), ...
    qh0(1), qh0(2), qh0(3), qh0(4), ...
    1e9 * remainingTon(1), 1e9 * remainingTon(2), 1e9 * remainingTon(3), 1e9 * remainingTon(4), ...
    1e6 * energySurplus, 1e3 * deltaVEnergy, 1e3 * deltaVCharge, ...
    1e3 * deltaVEsr, 1e3 * deltaVChargeEsr, tPkPred, ...
    1e3 * deltaVActual, tPeakActualUs, rE, string(wavePath), ...
    'VariableNames', resultNames());
end

function row = failureRow(planRow, message)
nan1x4 = NaN(1, 4);
row = table(false, string(message), string(planRow.case_id), string(planRow.role), ...
    string(planRow.source), string(planRow.objective), ...
    planRow.base_load_A, planRow.target_load_A, planRow.selected_ref_slew_us, ...
    planRow.tau_ai_us, planRow.delta_v_allow_mV, NaN, ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    nan1x4(1), nan1x4(2), nan1x4(3), nan1x4(4), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, "", ...
    'VariableNames', resultNames());
end

function names = resultNames()
names = {'success','error_message','case_id','role','source','objective', ...
    'base_load_A','target_load_A','selected_ref_slew_us','tau_ai_us','delta_v_allow_mV', ...
    'vout0_V','il1_0_A','il2_0_A','il3_0_A','il4_0_A', ...
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

function iphRef = iphRefAt(spec, common, t)
start = common.tStep + max(spec.ref_start_delay_s, 0);
finish = start + max(spec.ref_slew_s, common.fastTss);
iphRef = spec.Iph_initial * ones(numel(t), 1);
slewMask = t >= start & t <= finish;
if any(slewMask)
    frac = (t(slewMask) - start) / max(spec.ref_slew_s, common.fastTss);
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
reportPath = fullfile(outputRoot, "iqcot_r039_pr_ecb_large_signal_dryrun_report.md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R039 PR-ECB Large-Signal Probe Dry Run\n\n");
fprintf(fid, "Prepared a first-peak phase-resolved energy-charge boundary plan.\n\n");
fprintf(fid, "- Plan: %s\n", planPath);
fprintf(fid, "- Derived model only: output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx\n");
fprintf(fid, "- No original .slx is modified or saved.\n\n");
fprintf(fid, "Run one smoke case with iqcot_r039_pr_ecb_large_signal_probe(true, 1, 1).\n");
end

function writeRunReport(rows, outputRoot, resultPath, runLabel)
reportPath = fullfile(outputRoot, "iqcot_r039_pr_ecb_large_signal_report_" + runLabel + ".md");
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# R039 PR-ECB Large-Signal Probe\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "R039 starts the large-signal line requested after R038. It estimates the first load-drop peak using a phase-resolved energy-charge boundary (PR-ECB) interface and compares the estimate with derived-Simulink waveforms.\n\n");
fprintf(fid, "## Outputs\n\n");
fprintf(fid, "- Results: %s\n", resultPath);
fprintf(fid, "- Wave snapshots: output/data/*_r039_pr_ecb_wave.csv\n\n");
fprintf(fid, "## Smoke Results\n\n");
fprintf(fid, "| case | role | tau AI us | slew us | energy mV | charge+ESR mV | actual peak mV | r_E |\n");
fprintf(fid, "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n");
for k = 1:height(rows)
    if rows.success(k)
        fprintf(fid, "| %s | %s | %.3f | %.3f | %.3f | %.3f | %.3f | %.3f |\n", ...
            rows.case_id(k), rows.role(k), rows.tau_ai_us(k), rows.selected_ref_slew_us(k), ...
            rows.delta_v_energy_mV(k), rows.delta_v_charge_esr_mV(k), ...
            rows.delta_v_actual_peak_mV(k), rows.r_E(k));
    else
        fprintf(fid, "| %s | %s | %.3f | %.3f | failed | failed | failed | NaN |\n", ...
            rows.case_id(k), rows.role(k), rows.tau_ai_us(k), rows.selected_ref_slew_us(k));
    end
end
fprintf(fid, "\n## Interpretation Boundary\n\n");
fprintf(fid, "This is a derived-Simulink and offline post-processing probe, not hardware or HIL validation. PR-ECB is intended as a first-peak risk feature r_E for the supervisory layer. It complements PIS-IEK, which remains the normal/quasi-normal event recovery model; it does not make PIS-IEK a precise predictor of the large load-drop first peak.\n");
end
