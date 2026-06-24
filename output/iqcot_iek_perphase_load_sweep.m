%IQCOT_IEK_PERPHASE_LOAD_SWEEP Static load sweep for the per-phase IEK copy.
% The script does not save the model. It uses SimulationInput variables only.

clear; clc;

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
initPath = fullfile(srcRoot, "init_four_phase_cot_sync.m");
evalin("base", sprintf("run('%s')", strrep(initPath, "'", "''")));

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(modelRoot);
addpath(srcRoot);

model = "four_phase_iek_perphase";
modelFile = fullfile(modelRoot, model + ".slx");
load_system(modelFile);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

loadValues = [20 30 40 50];
m2Ratios = [0 0.40];
lambdaArea = 6e-10;
vAreaBias = 2e-3;
riArea = 0.5e-3;
voRef = evalin("base", "Vo_ref");

rows = table();
for iLoad = 1:numel(loadValues)
    for iRatio = 1:numel(m2Ratios)
        spec = makeSpec(loadValues(iLoad), m2Ratios(iRatio), voRef, ...
            lambdaArea, vAreaBias, riArea);
        fprintf("Running load %.1f A, Lambda_m2/Lambda=%.2f\n", ...
            spec.load_A, spec.Lambda_m2_ratio);
        rows = [rows; tryRun(model, spec)]; %#ok<AGROW>
    end
end

csvPath = fullfile(outputRoot, "iqcot_iek_perphase_load_sweep_summary.csv");
writetable(rows, csvPath);
makePlot(rows, figureRoot);
reportPath = writeReport(rows, outputRoot);

fprintf("LOAD_SWEEP_CSV=%s\n", csvPath);
fprintf("LOAD_SWEEP_REPORT=%s\n", reportPath);
disp(rows);

function spec = makeSpec(loadA, m2Ratio, voRef, lambdaArea, vAreaBias, riArea)
spec = struct();
spec.tag = sprintf("load_%02gA_m2_%03g", loadA, round(100*m2Ratio));
spec.load_A = loadA;
spec.Rload = voRef / loadA;
spec.Iph = loadA / 4;
spec.Lambda_area = lambdaArea;
spec.Lambda_m2_ratio = m2Ratio;
spec.Lambda_m2 = lambdaArea * m2Ratio;
spec.Varea_bias = vAreaBias;
spec.Ri_area = riArea;
spec.stop_time = 0.55e-3;
spec.steady_window = 70e-6;
spec.max_step = "5e-9";
spec.fast_tss = 5e-9;
end

function row = tryRun(model, spec)
try
    metrics = runCase(model, spec);
    row = rowFromMetrics(spec, metrics);
catch ME
    row = failureRow(spec, ME.message);
end
end

function metrics = runCase(model, spec)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(spec.stop_time, "%.15g"), ...
    "MaxStep", char(spec.max_step), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", spec.fast_tss);
in = in.setVariable("Rload", spec.Rload);
in = in.setVariable("Iout", spec.load_A);
in = in.setVariable("Iph", spec.Iph);
in = in.setVariable("Lambda_area", spec.Lambda_area);
in = in.setVariable("Lambda_m2", spec.Lambda_m2);
in = in.setVariable("Varea_bias", spec.Varea_bias);
in = in.setVariable("Ri_area", spec.Ri_area);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);

out = sim(in);
logs = out.logsout;
steadyStart = spec.stop_time - spec.steady_window;

vout = steadyValues(logs, "vout", steadyStart);
metrics.vout_mean_V = mean(vout);
metrics.vout_ripple_pp_mV = 1e3 * (max(vout) - min(vout));
metrics.il_mean_A = zeros(1, 4);
metrics.qh_frequency_Hz = zeros(1, 4);
for phase = 1:4
    il = steadyValues(logs, "il" + phase, steadyStart);
    metrics.il_mean_A(phase) = mean(il);
    metrics.qh_frequency_Hz(phase) = risingEdgeFrequency(logs, "qh" + phase, steadyStart);
end
metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.il_phase_imbalance_A = max(metrics.il_mean_A) - min(metrics.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 -1 1 -1]) / 4;
metrics.qh_frequency_mean_Hz = mean(metrics.qh_frequency_Hz);
metrics.qh_frequency_spread_Hz = max(metrics.qh_frequency_Hz) - min(metrics.qh_frequency_Hz);
metrics.trigger_frequency_Hz = risingEdgeFrequency(logs, "trigger", steadyStart);
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);
metrics.vout_error_mV = 1e3 * (metrics.vout_mean_V - 1.0);
metrics.load_error_A = metrics.il_total_mean_A - spec.load_A;
end

function row = rowFromMetrics(spec, m)
row = table( ...
    string(spec.tag), true, "", ...
    spec.load_A, spec.Rload, spec.Iph, spec.Lambda_area, spec.Lambda_m2, spec.Lambda_m2_ratio, ...
    spec.Varea_bias, spec.Ri_area, ...
    m.vout_mean_V, m.vout_error_mV, m.vout_ripple_pp_mV, ...
    m.il_mean_A(1), m.il_mean_A(2), m.il_mean_A(3), m.il_mean_A(4), ...
    m.il_total_mean_A, m.load_error_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.qh_frequency_mean_Hz, m.qh_frequency_spread_Hz, m.trigger_frequency_Hz, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    'VariableNames', { ...
        'tag','success','error_message', ...
        'load_A','Rload_ohm','Iph_ref_A','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'Varea_bias','Ri_area', ...
        'vout_mean_V','vout_error_mV','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','load_error_A','il_phase_imbalance_A','il_m2_projection_A', ...
        'qh_frequency_mean_Hz','qh_frequency_spread_Hz','trigger_frequency_Hz', ...
        'phase_spacing_mean_ns','phase_spacing_std_ns','phase_sequence_error_fraction'});
end

function row = failureRow(spec, message)
row = table( ...
    string(spec.tag), false, string(message), ...
    spec.load_A, spec.Rload, spec.Iph, spec.Lambda_area, spec.Lambda_m2, spec.Lambda_m2_ratio, ...
    spec.Varea_bias, spec.Ri_area, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', { ...
        'tag','success','error_message', ...
        'load_A','Rload_ohm','Iph_ref_A','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'Varea_bias','Ri_area', ...
        'vout_mean_V','vout_error_mV','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','load_error_A','il_phase_imbalance_A','il_m2_projection_A', ...
        'qh_frequency_mean_Hz','qh_frequency_spread_Hz','trigger_frequency_Hz', ...
        'phase_spacing_mean_ns','phase_spacing_std_ns','phase_sequence_error_fraction'});
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

function values = steadyValues(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
values = squeeze(double(series.Data(mask)));
end

function frequency = risingEdgeFrequency(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
time = series.Time(mask);
values = squeeze(double(series.Data(mask)));
risingTimes = time(find(diff(values > 0.5) > 0) + 1);
if numel(risingTimes) < 2
    frequency = 0;
else
    frequency = (numel(risingTimes) - 1) / (risingTimes(end) - risingTimes(1));
end
end

function times = edgeTimes(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
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

function makePlot(rows, figureRoot)
valid = rows(rows.success, :);
fig = figure(Visible="off", Position=[100 100 1120 760]);
cleanup = onCleanup(@() close(fig));
tiledlayout(2, 2);

baseRows = valid(valid.Lambda_m2_ratio == 0, :);
m2Rows = valid(valid.Lambda_m2_ratio > 0, :);

nexttile;
plot(baseRows.load_A, baseRows.vout_mean_V, "-o", LineWidth=1.2); hold on;
plot(m2Rows.load_A, m2Rows.vout_mean_V, "-s", LineWidth=1.2);
grid on; xlabel("load current command (A)"); ylabel("Vout mean (V)");
legend("Lambda m2=0", "Lambda m2/Lambda=0.4", Location="best");

nexttile;
plot(baseRows.load_A, baseRows.il_phase_imbalance_A, "-o", LineWidth=1.2); hold on;
plot(m2Rows.load_A, m2Rows.il_phase_imbalance_A, "-s", LineWidth=1.2);
grid on; xlabel("load current command (A)"); ylabel("phase current imbalance (A)");

nexttile;
plot(baseRows.load_A, baseRows.phase_spacing_std_ns, "-o", LineWidth=1.2); hold on;
plot(m2Rows.load_A, m2Rows.phase_spacing_std_ns, "-s", LineWidth=1.2);
grid on; xlabel("load current command (A)"); ylabel("phase spacing std (ns)");

nexttile;
plot(baseRows.load_A, baseRows.qh_frequency_mean_Hz/1e3, "-o", LineWidth=1.2); hold on;
plot(m2Rows.load_A, m2Rows.qh_frequency_mean_Hz/1e3, "-s", LineWidth=1.2);
grid on; xlabel("load current command (A)"); ylabel("mean phase frequency (kHz)");

exportgraphics(fig, fullfile(figureRoot, "fig15_iek_perphase_load_sweep.png"), Resolution=180);
end

function reportPath = writeReport(rows, outputRoot)
valid = rows(rows.success, :);
reportPath = fullfile(outputRoot, "iqcot_iek_perphase_load_sweep_report.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# 逐相 IEK 面积核静态负载扫点验证\n\n");
fprintf(fid, "模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase.slx`。该脚本不保存模型，仅通过 `SimulationInput` 设置 `Rload`、`Iout`、`Iph`、`Lambda_area`、`Lambda_m2`、`Varea_bias` 和 `Ri_area`。\n\n");
fprintf(fid, "固定面积核参数：`Lambda_area=6e-10 V*s`，`Varea_bias=2 mV`，`Ri_area=0.5 mOhm`。负载点为 20/30/40/50 A，且每个负载点比较 `Lambda_m2/Lambda_area=0` 与 `0.4`。\n\n");
if isempty(valid)
    fprintf(fid, "没有成功工况。\n");
    return;
end
baseRows = valid(valid.Lambda_m2_ratio == 0, :);
m2Rows = valid(valid.Lambda_m2_ratio > 0, :);
[~, idxWorstV] = max(abs(baseRows.vout_error_mV));
[~, idxWorstImb] = max(baseRows.il_phase_imbalance_A);
fprintf(fid, "## 主要结果\n\n");
fprintf(fid, "- baseline `Lambda_m2=0` 下，最大输出均值误差出现在 %.0f A：`%.3f mV`。\n", baseRows.load_A(idxWorstV), baseRows.vout_error_mV(idxWorstV));
fprintf(fid, "- baseline `Lambda_m2=0` 下，最大相电流不均衡出现在 %.0f A：`%.6f A`。\n", baseRows.load_A(idxWorstImb), baseRows.il_phase_imbalance_A(idxWorstImb));
if ~isempty(m2Rows)
    maxM2 = max(abs(m2Rows.il_m2_projection_A));
    maxM2Imb = max(m2Rows.il_phase_imbalance_A);
    maxM2PhaseStd = max(m2Rows.phase_spacing_std_ns);
    fprintf(fid, "- `Lambda_m2/Lambda_area=0.4` 跨负载最大 m2 电流投影为 `%.6f A`，最大相电流不均衡为 `%.6f A`，最大 phase-spacing std 为 `%.6f ns`。\n", maxM2, maxM2Imb, maxM2PhaseStd);
end
fprintf(fid, "\n## 解释\n\n");
fprintf(fid, "该扫点不是负载阶跃瞬态验证，而是静态负载鲁棒性补充。结果用于检查 v5 的逐相面积核结论是否只在 40 A 单点成立。若 `Lambda_m2` 在 20--50 A 范围内仍只产生很小 m2 电流投影，则支持其主要是相位/事件间隔执行量，而非强 DC 均流执行量。\n");
end
