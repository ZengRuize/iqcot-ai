function rows = iqcot_cutload_statecarry_validation()
%IQCOT_CUTLOAD_STATECARRY_VALIDATION First cut-load transient validation.
%
% This script does not modify or save the user's original model.  It uses a
% two-segment simulation strategy:
%   1) run the trim-enabled four-phase IEK model at 40 A to obtain a final
%      operating state;
%   2) restart from that final state with a lighter Rload/Iout/Iph setting.
%
% This is an event-recovery validation surrogate, not a final controlled-load
% hardware model.  It is intended to measure whether the PIS-IEK copy exposes
% pulse skipping/reentry, phase-spacing disturbance, and current-sharing
% recovery after an instantaneous load parameter change.

clc;

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

initPath = fullfile(srcRoot, "init_four_phase_cot_sync.m");
evalin("base", sprintf("run('%s')", strrep(initPath, "'", "''")));

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(outputRoot);
if ~exist(fullfile(modelRoot, "four_phase_iek_perphase_trim.slx"), "file")
    iqcot_build_iek_perphase_trim_model();
end

cd(modelRoot);
addpath(srcRoot);
addpath(outputRoot);

model = "four_phase_iek_perphase_trim";
load_system(fullfile(modelRoot, model + ".slx"));
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

baseLoadA = 40;
targetLoadsA = [20 10 1e-3];
controllerModes = ["hold", "instant"];
lambdaArea = 6e-10;
vAreaBias = 2e-3;
riArea = 0.5e-3;
voRef = evalin("base", "Vo_ref");

common = struct();
common.lambdaArea = lambdaArea;
common.vAreaBias = vAreaBias;
common.riArea = riArea;
common.preStop = 0.45e-3;
common.postStop = 90e-6;
common.postAbsStop = common.postStop;
common.preSteadyWindow = 50e-6;
common.postSteadyWindow = 20e-6;
common.maxStep = "5e-9";
common.fastTss = 5e-9;
common.voRef = voRef;
common.expectedSlot = evalin("base", "Tslot");

fprintf("Preparing base operating point at %.1f A...\n", baseLoadA);
baseSpec = makeSpec(baseLoadA, common, "hold", baseLoadA);
preOut = runPreCase(model, baseSpec, common);
baseMetrics = steadyMetrics(preOut.logsout, common.preStop - common.preSteadyWindow, baseLoadA);

rows = table();
waveRows = table();
for idx = 1:numel(targetLoadsA)
    targetLoadA = targetLoadsA(idx);
    for modeIdx = 1:numel(controllerModes)
        controllerMode = controllerModes(modeIdx);
        fprintf("Cut-load state-carry case: %.1f A -> %.6g A, controller %s\n", ...
            baseLoadA, targetLoadA, controllerMode);
        targetSpec = makeSpec(targetLoadA, common, controllerMode, baseLoadA);
        try
            postOut = runPostCase(model, targetSpec, common, preOut.xFinal);
            metrics = transientMetrics(postOut.logsout, targetSpec, common, baseMetrics);
            rows = [rows; rowFromMetrics(baseLoadA, targetLoadA, targetSpec, metrics)]; %#ok<AGROW>
            waveRows = [waveRows; waveformSummaryRows(baseLoadA, targetLoadA, targetSpec, postOut.logsout)]; %#ok<AGROW>
        catch ME
            rows = [rows; failureRow(baseLoadA, targetLoadA, targetSpec, ME.message)]; %#ok<AGROW>
        end
    end
end

summaryPath = fullfile(outputRoot, "iqcot_cutload_statecarry_summary.csv");
wavePath = fullfile(outputRoot, "iqcot_cutload_statecarry_wave_samples.csv");
reportPath = fullfile(outputRoot, "iqcot_cutload_statecarry_report.md");
writetable(rows, summaryPath);
if ~isempty(waveRows)
    writetable(waveRows, wavePath);
end
writeReport(rows, summaryPath, wavePath, reportPath);
makePlot(rows, figureRoot);

fprintf("CUTLOAD_SUMMARY=%s\n", summaryPath);
fprintf("CUTLOAD_WAVE=%s\n", wavePath);
fprintf("CUTLOAD_REPORT=%s\n", reportPath);
disp(rows);
end

function spec = makeSpec(loadA, common, controllerMode, baseLoadA)
spec = struct();
spec.load_A = loadA;
spec.effective_load_A = max(loadA, 1e-3);
spec.Rload = common.voRef / spec.effective_load_A;
spec.controller_mode = string(controllerMode);
if spec.controller_mode == "hold"
    spec.Iph = baseLoadA / 4;
else
    spec.Iph = loadA / 4;
end
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runPreCase(model, spec, common)
in = baseInput(model, spec, common);
in = in.setModelParameter( ...
    "StopTime", num2str(common.preStop, "%.15g"), ...
    "SaveFinalState", "on", ...
    "FinalStateName", "xFinal", ...
    "SaveCompleteFinalSimState", "off", ...
    "SaveFormat", "StructureWithTime");
out = sim(in);
end

function out = runPostCase(model, spec, common, xFinal)
in = baseInput(model, spec, common);
in = in.setModelParameter( ...
    "StopTime", num2str(common.postStop, "%.15g"), ...
    "LoadInitialState", "on", ...
    "InitialState", "xFinal");
in = in.setVariable("xFinal", xFinal);
out = sim(in);
end

function in = baseInput(model, spec, common)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "MaxStep", char(common.maxStep), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", common.fastTss);
in = in.setVariable("Rload", spec.Rload);
in = in.setVariable("Iout", spec.load_A);
in = in.setVariable("Iph", spec.Iph);
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
end

function metrics = steadyMetrics(logs, steadyStart, loadA)
metrics = struct();
metrics.vout = steadyValues(logs, "vout", steadyStart);
metrics.vout_mean_V = mean(metrics.vout);
metrics.il_mean_A = zeros(1, 4);
for phase = 1:4
    il = steadyValues(logs, "il" + phase, steadyStart);
    metrics.il_mean_A(phase) = mean(il);
end
metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.load_error_A = metrics.il_total_mean_A - loadA;
end

function metrics = transientMetrics(logs, spec, common, baseMetrics)
voutSeries = logs.get("vout").Values;
timeAbs = voutSeries.Time;
time = timeAbs - min(timeAbs);
vout = squeeze(double(voutSeries.Data));
maskPost = time >= 0;
time = time(maskPost);
vout = vout(maskPost);
metrics = struct();
metrics.vout_initial_V = baseMetrics.vout_mean_V;
metrics.vout_peak_V = max(vout);
metrics.vout_min_V = min(vout);
metrics.overshoot_mV = 1e3 * (metrics.vout_peak_V - common.voRef);
metrics.undershoot_mV = 1e3 * (common.voRef - metrics.vout_min_V);
metrics.t_peak_us = 1e6 * time(find(vout == metrics.vout_peak_V, 1, "first"));
metrics.settle_time_us = settleTimeUs(time, vout, common.voRef, 2e-3);

allEdgesAbs = allGateEdges(logs, min(timeAbs));
allEdges = allEdgesAbs - min(timeAbs);
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

steadyStart = max(timeAbs) - common.postSteadyWindow;
metrics.final = steadyMetrics(logs, steadyStart, spec.load_A);
metrics.final_vout_error_mV = 1e3 * (metrics.final.vout_mean_V - common.voRef);
metrics.il_phase_imbalance_A = max(metrics.final.il_mean_A) - min(metrics.final.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.final.il_mean_A - mean(metrics.final.il_mean_A), [1 -1 1 -1]) / 4;
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);
metrics.success = true;
metrics.error_message = "";
end

function row = rowFromMetrics(baseLoadA, targetLoadA, spec, m)
row = table( ...
    true, "", string(spec.controller_mode), baseLoadA, targetLoadA, spec.Rload, spec.Iph, ...
    m.vout_initial_V, m.vout_peak_V, m.vout_min_V, m.overshoot_mV, m.undershoot_mV, ...
    m.t_peak_us, m.settle_time_us, m.first_gate_edge_us, m.max_gate_gap_us, m.skip_count_est, ...
    m.final.vout_mean_V, m.final_vout_error_mV, ...
    m.final.il_mean_A(1), m.final.il_mean_A(2), m.final.il_mean_A(3), m.final.il_mean_A(4), ...
    m.final.il_total_mean_A, m.final.load_error_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    'VariableNames', {'success','error_message','controller_mode','base_load_A','target_load_A','target_Rload_ohm','target_Iph_ref_A', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_mean_V','final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction'});
end

function row = failureRow(baseLoadA, targetLoadA, spec, message)
row = table( ...
    false, string(message), string(spec.controller_mode), baseLoadA, targetLoadA, spec.Rload, spec.Iph, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'success','error_message','controller_mode','base_load_A','target_load_A','target_Rload_ohm','target_Iph_ref_A', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_mean_V','final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction'});
end

function rows = waveformSummaryRows(baseLoadA, targetLoadA, spec, logs)
series = logs.get("vout").Values;
timeAbs = series.Time;
vout = squeeze(double(series.Data));
preStop = min(timeAbs);
time = timeAbs - preStop;
sampleCount = min(3000, numel(time));
if sampleCount < numel(time)
    sampleIdx = unique(round(linspace(1, numel(time), sampleCount)));
else
    sampleIdx = 1:numel(time);
end
rows = table( ...
    repmat(string(spec.controller_mode), numel(sampleIdx), 1), ...
    repmat(baseLoadA, numel(sampleIdx), 1), ...
    repmat(targetLoadA, numel(sampleIdx), 1), ...
    1e6 * time(sampleIdx), ...
    vout(sampleIdx), ...
    'VariableNames', {'controller_mode','base_load_A','target_load_A','time_us','vout_V'});
end

function values = steadyValues(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
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

function makePlot(rows, figureRoot)
valid = rows(rows.success, :);
if isempty(valid)
    return;
end
fig = figure(Visible="off", Position=[100 100 1100 720]);
cleanup = onCleanup(@() close(fig));
tiledlayout(2, 2);

nexttile;
bar(categorical(labelText(valid)), valid.overshoot_mV);
grid on; xlabel("case"); ylabel("Vout overshoot (mV)");

nexttile;
bar(categorical(labelText(valid)), valid.skip_count_est);
grid on; xlabel("case"); ylabel("estimated skipped events");

nexttile;
bar(categorical(labelText(valid)), valid.final_phase_spacing_std_ns);
grid on; xlabel("case"); ylabel("final phase-spacing std (ns)");

nexttile;
bar(categorical(labelText(valid)), valid.final_il_phase_imbalance_A);
grid on; xlabel("case"); ylabel("final phase current imbalance (A)");

exportgraphics(fig, fullfile(figureRoot, "fig20_cutload_statecarry_validation.png"), Resolution=180);
end

function labels = labelText(rows)
labels = strings(height(rows), 1);
for i = 1:height(rows)
    labels(i) = sprintf("%gA-%s", rows.target_load_A(i), rows.controller_mode(i));
end
end

function writeReport(rows, summaryPath, wavePath, reportPath)
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# PIS-IEK 切载状态继承仿真首轮验证\n\n");
fprintf(fid, "该脚本采用两段仿真：先在 40 A 跑到稳态并保存 final state，再把 `Rload/Iout/Iph` 切到轻载并从该状态继续仿真。该方法不修改 `.slx`，适合作为动态负载模型之前的事件恢复验证。\n\n");
fprintf(fid, "脚本同时比较两种控制器参考处理：`hold` 表示物理负载改变但面积核中的 `Iph` 仍保持 40 A/4；`instant` 表示 `Iph` 也瞬时改为目标负载/4。二者用于区分物理切载与参考调度对 IQCOT 面积事件的影响。\n\n");
fprintf(fid, "- Summary CSV: `%s`\n", strrep(summaryPath, "\", "/"));
fprintf(fid, "- Wave sample CSV: `%s`\n\n", strrep(wavePath, "\", "/"));
valid = rows(rows.success, :);
if isempty(valid)
    fprintf(fid, "没有成功工况。\n");
    return;
end
fprintf(fid, "## 主要结果\n\n");
for i = 1:height(valid)
    fprintf(fid, "- `%.1f A -> %.6g A`, controller `%s`: overshoot `%.3f mV`, estimated skipped events `%.0f`, settle time `%.3f us`, final phase-spacing std `%.3f ns`, final current imbalance `%.6f A`.\n", ...
        valid.base_load_A(i), valid.target_load_A(i), valid.controller_mode(i), valid.overshoot_mV(i), valid.skip_count_est(i), valid.settle_time_us(i), valid.final_phase_spacing_std_ns(i), valid.final_il_phase_imbalance_A(i));
end
fprintf(fid, "\n## 边界说明\n\n");
fprintf(fid, "这是状态继承切载验证，不是最终的受控动态负载硬件等价模型。若该结果显示明显 skip/reentry，则下一步应在 `.slx` 副本中把静态 `Series RLC Branch8` 替换为受控电流源或受控负载，以验证连续仿真中的同一现象。\n");
end
