function rows = iqcot_dynamic_ref_slew_sweep(slewTimesUs, outputTag)
%IQCOT_DYNAMIC_REF_SLEW_SWEEP Sweep Iph reference slew time under cut-load.
%
% The model copy replaces static Rload with an SPS controlled current source
% and replaces internal Iph reference constants with From Workspace signals.
% This tests whether a rate-limited reference schedule can trade off the
% dynamic_hold and dynamic_instant behaviors observed earlier.

clc;

if nargin < 1 || isempty(slewTimesUs)
    slewTimesUs = [0 5 10 20 40];
end
if nargin < 2 || strlength(string(outputTag)) == 0
    outputTag = "";
else
    outputTag = string(outputTag);
    if ~startsWith(outputTag, "_")
        outputTag = "_" + outputTag;
    end
end
assignin("base", "iqcotRefSlewRequestedGrid", slewTimesUs);
assignin("base", "iqcotRefSlewRequestedTag", outputTag);

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
run(fullfile(srcRoot, "init_four_phase_cot_sync.m"));

% The init script may clear caller variables, so define paths after it.
slewTimesUs = evalin("base", "iqcotRefSlewRequestedGrid");
outputTag = evalin("base", "iqcotRefSlewRequestedTag");
evalin("base", "clear iqcotRefSlewRequestedGrid iqcotRefSlewRequestedTag");
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

model = buildRefSlewModel(modelRoot);
load_system(fullfile(modelRoot, model + ".slx"));
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

baseLoadA = 40;
targetLoadsA = [20 10 1e-3];

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
common.voRef = evalin("base", "Vo_ref");
common.expectedSlot = evalin("base", "Tslot");

rows = table();
waveRows = table();
for idx = 1:numel(targetLoadsA)
    targetLoadA = targetLoadsA(idx);
    for slewIdx = 1:numel(slewTimesUs)
        slewUs = slewTimesUs(slewIdx);
        spec = makeSpec(baseLoadA, targetLoadA, slewUs, common);
        fprintf("Reference slew case: %.1f A -> %.6g A, slew %.3f us\n", ...
            baseLoadA, targetLoadA, slewUs);
        try
            out = runSlewCase(model, spec, common);
            logs = out.logsout;
            baseMetrics = preStepMetrics(logs, common, baseLoadA);
            metrics = transientMetrics(logs, spec, common, baseMetrics);
            rows = [rows; rowFromMetrics(baseLoadA, targetLoadA, spec, metrics)]; %#ok<AGROW>
            waveRows = [waveRows; waveformSummaryRows(baseLoadA, targetLoadA, spec, logs, common)]; %#ok<AGROW>
        catch ME
            rows = [rows; failureRow(baseLoadA, targetLoadA, spec, ME.message)]; %#ok<AGROW>
            warning("iqcot:RefSlewCaseFailed", "Reference slew case failed: %s", ME.message);
        end
    end
end

summaryPath = fullfile(outputRoot, "iqcot_dynamic_ref_slew" + outputTag + "_summary.csv");
wavePath = fullfile(outputRoot, "iqcot_dynamic_ref_slew" + outputTag + "_wave_samples.csv");
bestPath = fullfile(outputRoot, "iqcot_dynamic_ref_slew" + outputTag + "_best_summary.csv");
reportPath = fullfile(outputRoot, "iqcot_dynamic_ref_slew" + outputTag + "_report.md");
writetable(rows, summaryPath);
writetable(waveRows, wavePath);
bestRows = bestSummary(rows);
writetable(bestRows, bestPath);
writeReport(rows, summaryPath, wavePath, bestPath, reportPath, slewTimesUs);
makePlot(rows, figureRoot, outputTag);

fprintf("REF_SLEW_SUMMARY=%s\n", summaryPath);
fprintf("REF_SLEW_WAVE=%s\n", wavePath);
fprintf("REF_SLEW_BEST=%s\n", bestPath);
fprintf("REF_SLEW_REPORT=%s\n", reportPath);
disp(rows);
end

function model = buildRefSlewModel(modelRoot)
srcModel = "four_phase_iek_perphase_trim";
model = "four_phase_iek_dynamic_load_refslew";
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
stepPosition = [oldPosition(1)-230 oldPosition(2)+30 oldPosition(1)-150 oldPosition(2)+60];
add_block("simulink/Sources/Step", stepBlock, ...
    "Position", stepPosition, ...
    "Time", "t_load_step", ...
    "Before", "Iload_initial", ...
    "After", "Iload_final", ...
    "SampleTime", "0");
connectToPort(stepBlock, 1, ccs, 1);

replaceIphConstantsWithFromWorkspace(model);

save_system(model, modelFile);
fprintf("REF_SLEW_MODEL=%s\n", modelFile);
end

function replaceIphConstantsWithFromWorkspace(model)
iphBlocks = [
    model + "/IEK_PerPhase_Request/Iph1";
    model + "/IEK_PerPhase_Request/Iph2";
    model + "/IEK_PerPhase_Request/Iph3";
    model + "/IEK_PerPhase_Request/Iph4";
    model + "/IQCOT_Ton_Adapter/Iref_Phase";
];
for idx = 1:numel(iphBlocks)
    replaceConstantWithFromWorkspace(iphBlocks(idx));
end
end

function replaceConstantWithFromWorkspace(blockPath)
parent = get_param(blockPath, "Parent");
position = get_param(blockPath, "Position");
if strcmp(get_param(blockPath, "BlockType"), "Constant")
    ports = get_param(blockPath, "PortHandles");
    line = get_param(ports.Outport(1), "Line");
    dstPorts = [];
    if line ~= -1
        dstPorts = get_param(line, "DstPortHandle");
        delete_line(line);
    end
    delete_block(blockPath);
else
    dstPorts = [];
end
add_block("simulink/Sources/From Workspace", blockPath, ...
    "Position", position, ...
    "VariableName", "Iph_ref_ts");
try
    set_param(blockPath, "Interpolate", "on");
catch
end
try
    set_param(blockPath, "OutputAfterFinalValue", "Holding final value");
catch
end
if ~isempty(dstPorts)
    newPorts = get_param(blockPath, "PortHandles");
    for k = 1:numel(dstPorts)
        add_line(parent, newPorts.Outport(1), dstPorts(k), "autorouting", "on");
    end
end
end

function spec = makeSpec(baseLoadA, targetLoadA, slewUs, common)
spec = struct();
spec.controller_mode = "dynamic_refslew";
spec.base_load_A = baseLoadA;
spec.load_A = targetLoadA;
spec.effective_load_A = max(targetLoadA, 1e-3);
spec.Rload = common.voRef / spec.effective_load_A;
spec.Iph_initial = baseLoadA / 4;
spec.Iph_final = targetLoadA / 4;
spec.Iph = spec.Iph_final;
spec.ref_slew_us = slewUs;
spec.ref_slew_s = slewUs * 1e-6;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runSlewCase(model, spec, common)
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
in = in.setVariable("Iph_ref_ts", makeIphRefTimeseries(spec, common));
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

function ts = makeIphRefTimeseries(spec, common)
slew = max(spec.ref_slew_s, common.fastTss);
t = [0; common.tStep; common.tStep + slew; common.stopTime];
y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
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
metrics.success = true;
metrics.error_message = "";

metrics.tradeoff_score = abs(metrics.final_vout_error_mV) + metrics.undershoot_mV ...
    + 0.02 * metrics.phase_spacing.std_ns + 2.0 * metrics.skip_count_est;
end

function row = rowFromMetrics(baseLoadA, targetLoadA, spec, m)
row = table( ...
    true, "", string(spec.controller_mode), baseLoadA, targetLoadA, spec.Rload, ...
    spec.Iph_initial, spec.Iph_final, spec.ref_slew_us, ...
    m.vout_initial_V, m.vout_peak_V, m.vout_min_V, m.overshoot_mV, m.undershoot_mV, ...
    m.t_peak_us, m.settle_time_us, m.first_gate_edge_us, m.max_gate_gap_us, m.skip_count_est, ...
    m.final_vout_error_mV, ...
    m.final.il_mean_A(1), m.final.il_mean_A(2), m.final.il_mean_A(3), m.final.il_mean_A(4), ...
    m.final.il_total_mean_A, m.final.load_error_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, m.tradeoff_score, ...
    'VariableNames', {'success','error_message','controller_mode','base_load_A','target_load_A','target_Rload_ohm', ...
    'Iph_initial_A','Iph_final_A','ref_slew_us', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction','tradeoff_score'});
end

function row = failureRow(baseLoadA, targetLoadA, spec, message)
row = table( ...
    false, string(message), string(spec.controller_mode), baseLoadA, targetLoadA, spec.Rload, ...
    spec.Iph_initial, spec.Iph_final, spec.ref_slew_us, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', {'success','error_message','controller_mode','base_load_A','target_load_A','target_Rload_ohm', ...
    'Iph_initial_A','Iph_final_A','ref_slew_us', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction','tradeoff_score'});
end

function bestRows = bestSummary(rows)
bestRows = table();
valid = rows(rows.success, :);
if isempty(valid)
    return;
end
targets = unique(valid.target_load_A, "stable");
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    [~, idx] = min(r.tradeoff_score);
    b = r(idx, :);
    bestRows = [bestRows; table( ... %#ok<AGROW>
        b.target_load_A, b.ref_slew_us, b.undershoot_mV, b.final_vout_error_mV, ...
        b.skip_count_est, b.settle_time_us, b.final_phase_spacing_std_ns, b.tradeoff_score, ...
        'VariableNames', {'target_load_A','best_ref_slew_us','undershoot_mV', ...
        'final_vout_error_mV','skip_count_est','settle_time_us', ...
        'final_phase_spacing_std_ns','tradeoff_score'})];
end
end

function rows = waveformSummaryRows(baseLoadA, targetLoadA, spec, logs, common)
series = logs.get("vout").Values;
timeAbs = series.Time;
vout = squeeze(double(series.Data));
time = timeAbs - common.tStep;
mask = time >= -20e-6;
time = time(mask);
vout = vout(mask);
sampleCount = min(2000, numel(time));
if sampleCount < numel(time)
    sampleIdx = unique(round(linspace(1, numel(time), sampleCount)));
else
    sampleIdx = 1:numel(time);
end
rows = table( ...
    repmat(string(spec.controller_mode), numel(sampleIdx), 1), ...
    repmat(baseLoadA, numel(sampleIdx), 1), ...
    repmat(targetLoadA, numel(sampleIdx), 1), ...
    repmat(spec.ref_slew_us, numel(sampleIdx), 1), ...
    1e6 * time(sampleIdx), ...
    vout(sampleIdx), ...
    'VariableNames', {'controller_mode','base_load_A','target_load_A','ref_slew_us','time_us','vout_V'});
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

function makePlot(rows, figureRoot, outputTag)
valid = rows(rows.success, :);
if isempty(valid)
    return;
end
targets = unique(valid.target_load_A, "stable");
fig = figure(Visible="off", Position=[100 100 1100 720]);
cleanup = onCleanup(@() close(fig));
tiledlayout(2, 2);

nexttile;
hold on;
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    plot(r.ref_slew_us, r.undershoot_mV, "-o", DisplayName=sprintf("%g A", targets(k)));
end
grid on; xlabel("Iph reference slew (us)"); ylabel("Vout undershoot (mV)"); legend(Location="best");

nexttile;
hold on;
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    plot(r.ref_slew_us, abs(r.final_vout_error_mV), "-o", DisplayName=sprintf("%g A", targets(k)));
end
grid on; xlabel("Iph reference slew (us)"); ylabel("|final Vout error| (mV)");

nexttile;
hold on;
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    plot(r.ref_slew_us, r.skip_count_est, "-o", DisplayName=sprintf("%g A", targets(k)));
end
grid on; xlabel("Iph reference slew (us)"); ylabel("estimated skipped events");

nexttile;
hold on;
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    plot(r.ref_slew_us, r.tradeoff_score, "-o", DisplayName=sprintf("%g A", targets(k)));
end
grid on; xlabel("Iph reference slew (us)"); ylabel("tradeoff score");

exportgraphics(fig, fullfile(figureRoot, "fig23_dynamic_ref_slew" + outputTag + "_sweep.png"), Resolution=180);
end

function writeReport(rows, summaryPath, wavePath, bestPath, reportPath, slewTimesUs)
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "Actual slew grid used by this run: `%s us`.\n", strjoin(string(slewTimesUs), ", "));
fprintf(fid, "Best summary CSV: `%s`.\n\n", strrep(bestPath, "\", "/"));
fprintf(fid, "# PIS-IEK 动态参考斜率扫描\n\n");
fprintf(fid, "该实验在 `four_phase_iek_dynamic_load_refslew.slx` 中使用受控电流源施加连续切载，并用 `From Workspace` 给 `IEK_PerPhase_Request/Iph1..4` 和 `IQCOT_Ton_Adapter/Iref_Phase` 输入分段线性参考。扫描 `Iph_ref` 从 `40A/4` 过渡到目标负载/4 的时间：`0, 5, 10, 20, 40 us`。\n\n");
fprintf(fid, "- Summary CSV: `%s`\n", strrep(summaryPath, "\", "/"));
fprintf(fid, "- Wave sample CSV: `%s`\n\n", strrep(wavePath, "\", "/"));

valid = rows(rows.success, :);
if isempty(valid)
    fprintf(fid, "没有成功工况。\n");
    return;
end

fprintf(fid, "## 最优折中点\n\n");
targets = unique(valid.target_load_A, "stable");
for k = 1:numel(targets)
    r = valid(valid.target_load_A == targets(k), :);
    [~, idx] = min(r.tradeoff_score);
    best = r(idx, :);
    fprintf(fid, "- `40A -> %.6gA`: best slew `%.3f us`, undershoot `%.3f mV`, final error `%.3f mV`, skip `%.0f`, score `%.3f`.\n", ...
        targets(k), best.ref_slew_us, best.undershoot_mV, best.final_vout_error_mV, best.skip_count_est, best.tradeoff_score);
end

fprintf(fid, "\n## 关键解释\n\n");
fprintf(fid, "参考斜率扫描把 `dynamic_hold` 和 `dynamic_instant` 之间的离散选择变成连续调度问题。若某个中间斜率同时显著降低 final Vout error 且避免 instant 的大欠压，则说明 AI 可以把 `Iph_ref` 斜率作为低维动作；若所有中间斜率都呈单调折中，则仍可用 PIS-IEK 给 AI 提供安全投影边界和 reward shaping。\n");
end
