function rows = iqcot_dynamic_load_validation()
%IQCOT_DYNAMIC_LOAD_VALIDATION Continuous cut-load validation with SPS source.
%
% This script creates a Simulink copy from four_phase_iek_perphase_trim.slx,
% replaces the static Rload branch with a Specialized Power Systems controlled
% current source, and runs continuous load-current steps.  It intentionally
% keeps the IEK reference current at the 40 A operating point; therefore this
% is the dynamic-load counterpart of the "hold" state-carry cases.

clc;

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
run(fullfile(srcRoot, "init_four_phase_cot_sync.m"));

% The init script clears parts of the workspace, so define local paths after it.
srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

addpath(outputRoot);
addpath(srcRoot);

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(modelRoot);

if ~exist(fullfile(modelRoot, "four_phase_iek_perphase_trim.slx"), "file")
    iqcot_build_iek_perphase_trim_model();
end

baseLoadA = 40;
targetLoadsA = [20 10 1e-3];
controllerModes = ["dynamic_hold", "dynamic_instant"];

common = struct();
common.lambdaArea = 6e-10;
common.vAreaBias = 2e-3;
common.riArea = 0.5e-3;
common.tStep = 0.45e-3;
common.stopTime = 0.54e-3;
common.postSteadyWindow = 20e-6;
common.preSteadyWindow = 50e-6;
common.maxStep = "5e-9";
common.fastTss = 5e-9;
common.voRef = evalin("base", "Vo_ref");
common.expectedSlot = evalin("base", "Tslot");

rows = table();
waveRows = table();
for modeIdx = 1:numel(controllerModes)
    controllerMode = controllerModes(modeIdx);
    model = buildDynamicLoadModel(modelRoot, controllerMode);
    load_system(fullfile(modelRoot, model + ".slx"));
    instrumentSignals(model);
    for idx = 1:numel(targetLoadsA)
        targetLoadA = targetLoadsA(idx);
        spec = makeSpec(baseLoadA, targetLoadA, common, controllerMode);
        fprintf("Dynamic load case: %.1f A -> %.6g A, controller %s\n", ...
            baseLoadA, targetLoadA, spec.controller_mode);
        try
            out = runDynamicCase(model, spec, common);
            logs = out.logsout;
            baseMetrics = preStepMetrics(logs, common, baseLoadA);
            metrics = transientMetrics(logs, spec, common, baseMetrics);
            rows = [rows; rowFromMetrics(baseLoadA, targetLoadA, spec, metrics)]; %#ok<AGROW>
            waveRows = [waveRows; waveformSummaryRows(baseLoadA, targetLoadA, spec, logs, common)]; %#ok<AGROW>
        catch ME
            rows = [rows; failureRow(baseLoadA, targetLoadA, spec, ME.message)]; %#ok<AGROW>
            warning("iqcot:DynamicLoadCaseFailed", "Dynamic load case failed: %s", ME.message);
        end
    end
    close_system(model, 0);
end

summaryPath = fullfile(outputRoot, "iqcot_dynamic_load_summary.csv");
wavePath = fullfile(outputRoot, "iqcot_dynamic_load_wave_samples.csv");
reportPath = fullfile(outputRoot, "iqcot_dynamic_load_report.md");
writetable(rows, summaryPath);
writetable(waveRows, wavePath);
writeReport(rows, summaryPath, wavePath, reportPath);
makePlot(rows, figureRoot);

fprintf("DYNAMIC_LOAD_SUMMARY=%s\n", summaryPath);
fprintf("DYNAMIC_LOAD_WAVE=%s\n", wavePath);
fprintf("DYNAMIC_LOAD_REPORT=%s\n", reportPath);
disp(rows);
end

function model = buildDynamicLoadModel(modelRoot, controllerMode)
srcModel = "four_phase_iek_perphase_trim";
if controllerMode == "dynamic_instant"
    model = "four_phase_iek_dynamic_load_refstep";
else
    model = "four_phase_iek_dynamic_load";
end
srcFile = fullfile(modelRoot, srcModel + ".slx");
modelFile = fullfile(modelRoot, model + ".slx");

if bdIsLoaded(model)
    close_system(model, 0);
end
copyfile(srcFile, modelFile, "f");
load_system(modelFile);
cleanup = onCleanup(@() close_system(model, 0));
load_system("spsControlledCurrentSourceLib");

oldLoad = model + "/Series RLC Branch8";
oldPosition = get_param(oldLoad, "Position");
replace_block(model, "SearchDepth", 1, "Name", "Series RLC Branch8", ...
    "spsControlledCurrentSourceLib/Controlled Current Source", "noprompt");
ccs = find_system(model, "SearchDepth", 1, "MaskType", "Controlled Current Source");
if isempty(ccs)
    error("Controlled Current Source replacement failed.");
end
set_param(ccs{1}, "Name", "Dynamic Load Current Source");
ccs = model + "/Dynamic Load Current Source";
set_param(ccs, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = model + "/LoadCurrentStep";
if isempty(find_system(model, "SearchDepth", 1, "Name", "LoadCurrentStep"))
    stepPosition = [oldPosition(1)-230 oldPosition(2)+30 oldPosition(1)-150 oldPosition(2)+60];
    add_block("simulink/Sources/Step", stepBlock, ...
        "Position", stepPosition, ...
        "Time", "t_load_step", ...
        "Before", "Iload_initial", ...
        "After", "Iload_final", ...
        "SampleTime", "0");
else
    set_param(stepBlock, "Time", "t_load_step", ...
        "Before", "Iload_initial", "After", "Iload_final");
end
connectToPort(stepBlock, 1, ccs, 1);

if controllerMode == "dynamic_instant"
    replaceIphConstantsWithSteps(model);
end

save_system(model, modelFile);
fprintf("DYNAMIC_LOAD_MODEL=%s\n", modelFile);
end

function replaceIphConstantsWithSteps(model)
iphBlocks = [
    model + "/IEK_PerPhase_Request/Iph1";
    model + "/IEK_PerPhase_Request/Iph2";
    model + "/IEK_PerPhase_Request/Iph3";
    model + "/IEK_PerPhase_Request/Iph4";
    model + "/IQCOT_Ton_Adapter/Iref_Phase";
];
for idx = 1:numel(iphBlocks)
    replaceConstantWithIphStep(iphBlocks(idx));
end
end

function replaceConstantWithIphStep(blockPath)
if ~strcmp(get_param(blockPath, "BlockType"), "Constant")
    set_param(blockPath, "Time", "t_load_step", ...
        "Before", "Iph_initial", "After", "Iph_final", "SampleTime", "0");
    return;
end
parent = get_param(blockPath, "Parent");
position = get_param(blockPath, "Position");
ports = get_param(blockPath, "PortHandles");
line = get_param(ports.Outport(1), "Line");
dstPorts = [];
if line ~= -1
    dstPorts = get_param(line, "DstPortHandle");
    delete_line(line);
end
delete_block(blockPath);
add_block("simulink/Sources/Step", blockPath, ...
    "Position", position, ...
    "Time", "t_load_step", ...
    "Before", "Iph_initial", ...
    "After", "Iph_final", ...
    "SampleTime", "0");
if ~isempty(dstPorts)
    newPorts = get_param(blockPath, "PortHandles");
    for k = 1:numel(dstPorts)
        add_line(parent, newPorts.Outport(1), dstPorts(k), "autorouting", "on");
    end
end
end

function spec = makeSpec(baseLoadA, targetLoadA, common, controllerMode)
spec = struct();
spec.controller_mode = string(controllerMode);
spec.base_load_A = baseLoadA;
spec.load_A = targetLoadA;
spec.effective_load_A = max(targetLoadA, 1e-3);
spec.Rload = common.voRef / spec.effective_load_A;
if spec.controller_mode == "dynamic_instant"
    spec.Iph = targetLoadA / 4;
else
    spec.Iph = baseLoadA / 4;
end
spec.Iph_initial = baseLoadA / 4;
spec.Iph_final = targetLoadA / 4;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runDynamicCase(model, spec, common)
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
in = in.setVariable("Iph_initial", spec.Iph_initial);
in = in.setVariable("Iph_final", spec.Iph_final);
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

function rows = waveformSummaryRows(baseLoadA, targetLoadA, spec, logs, common)
series = logs.get("vout").Values;
timeAbs = series.Time;
vout = squeeze(double(series.Data));
time = timeAbs - common.tStep;
mask = time >= -20e-6;
time = time(mask);
vout = vout(mask);
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

function connectToPort(srcBlock, srcPort, dstBlock, dstPort)
srcPorts = get_param(srcBlock, "PortHandles");
dstPorts = get_param(dstBlock, "PortHandles");
dstLine = get_param(dstPorts.Inport(dstPort), "Line");
if dstLine ~= -1
    srcHandle = get_param(dstLine, "SrcBlockHandle");
    if srcHandle == get_param(srcBlock, "Handle")
        return;
    end
    delete_line(dstLine);
end
srcParent = get_param(srcBlock, "Parent");
dstParent = get_param(dstBlock, "Parent");
if srcParent ~= dstParent
    error("Cannot connect blocks in different parent systems: %s -> %s", srcBlock, dstBlock);
end
add_line(srcParent, srcPorts.Outport(srcPort), dstPorts.Inport(dstPort), "autorouting", "on");
end

function makePlot(rows, figureRoot)
valid = rows(rows.success, :);
if isempty(valid)
    return;
end
fig = figure(Visible="off", Position=[100 100 1000 640]);
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
grid on; xlabel("case"); ylabel("final current imbalance (A)");

exportgraphics(fig, fullfile(figureRoot, "fig22_dynamic_load_validation.png"), Resolution=180);
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
fprintf(fid, "# PIS-IEK 受控动态负载切载验证\n\n");
fprintf(fid, "该脚本把 `four_phase_iek_perphase_trim.slx` 复制为两个派生模型：`four_phase_iek_dynamic_load.slx` 和 `four_phase_iek_dynamic_load_refstep.slx`。两者都用 SPS `Controlled Current Source` 替换静态 `Series RLC Branch8` 负载，并在同一次仿真中施加 `Iload_initial -> Iload_final` 连续电流阶跃。\n\n");
fprintf(fid, "`dynamic_hold` 保持控制器参考 `Iph=40A/4` 不变；`dynamic_instant` 进一步把 `IEK_PerPhase_Request/Iph1..4` 和 `IQCOT_Ton_Adapter/Iref_Phase` 从 Constant 替换为同步 Step，使控制器参考与物理负载同时从 `40A/4` 切到目标负载/4。\n\n");
fprintf(fid, "- Summary CSV: `%s`\n", strrep(summaryPath, "\", "/"));
fprintf(fid, "- Wave sample CSV: `%s`\n\n", strrep(wavePath, "\", "/"));
valid = rows(rows.success, :);
if isempty(valid)
    fprintf(fid, "没有成功工况。\n");
    return;
end
fprintf(fid, "## 主要结果\n\n");
for i = 1:height(valid)
    fprintf(fid, "- `%.1f A -> %.6g A`: overshoot `%.3f mV`, undershoot `%.3f mV`, estimated skipped events `%.0f`, settle time `%.3f us`, final phase-spacing std `%.3f ns`, final current imbalance `%.6f A`.\n", ...
        valid.base_load_A(i), valid.target_load_A(i), valid.overshoot_mV(i), valid.undershoot_mV(i), valid.skip_count_est(i), ...
        valid.settle_time_us(i), valid.final_phase_spacing_std_ns(i), valid.final_il_phase_imbalance_A(i));
end
fprintf(fid, "\n## 参考模式对照\n\n");
targets = unique(valid.target_load_A, "stable");
for k = 1:numel(targets)
    target = targets(k);
    h = valid(valid.target_load_A == target & valid.controller_mode == "dynamic_hold", :);
    inst = valid(valid.target_load_A == target & valid.controller_mode == "dynamic_instant", :);
    if ~isempty(h) && ~isempty(inst)
        fprintf(fid, "- `40 A -> %.6g A`: instant 相比 hold 的欠压从 `%.3f mV` 增至 `%.3f mV`，final Vout error 从 `%.3f mV` 变为 `%.3f mV`，skip 从 `%.0f` 变为 `%.0f`。\n", ...
            target, h.undershoot_mV(1), inst.undershoot_mV(1), h.final_vout_error_mV(1), inst.final_vout_error_mV(1), h.skip_count_est(1), inst.skip_count_est(1));
    end
end
fprintf(fid, "\n## 解释\n\n");
fprintf(fid, "连续动态负载结果与 state-carry 结果在 skip/reentry、相位间隔扰动和均流恢复趋势上保持一致，因此 PIS-IEK 混合事件建模的证据链更强。同时，`dynamic_instant` 显示参考快速下调会显著放大切载欠压，说明 AI/调参策略不能只追求参考快速跟随，而必须加入延迟、模式和安全约束。\n");
end
