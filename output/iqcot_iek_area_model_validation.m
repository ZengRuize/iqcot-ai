function results = iqcot_iek_area_model_validation()
%IQCOT_IEK_AREA_MODEL_VALIDATION Validate the copied area-trigger model.

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(modelRoot);
addpath(srcRoot);
initPath = fullfile(srcRoot, "init_four_phase_cot_sync.m");
evalin("base", sprintf("run('%s')", strrep(initPath, "'", "''")));

model = "four_phase_iek_area";
load_system(model);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

lambdaSweep = [1e-12 3e-12 1e-11 3e-11 1e-10 3e-10 1e-9 3e-9];
rows = table();
for k = 1:numel(lambdaSweep)
    spec = struct("tag", "lambda_cm_" + string(k), ...
        "Lambda_area", lambdaSweep(k), "Lambda_m2", 0, ...
        "stop_time", 0.45e-3, "steady_window", 50e-6, ...
        "max_step", "5e-9", "fast_tss", 0.12e-3);
    fprintf("Running common sweep %d/%d: Lambda=%g\n", k, numel(lambdaSweep), lambdaSweep(k));
    try
        m = runCase(model, spec);
        rows = [rows; rowFromMetrics(spec, m)]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(spec, ME.message)]; %#ok<AGROW>
    end
end

valid = rows(rows.success, :);
if isempty(valid)
    error("No valid area-trigger cases.");
end
[~, bestIdx] = min(abs(valid.qh_frequency_mean_Hz - 500e3) + 5e5 * abs(valid.vout_mean_V - 1.0));
bestLambda = valid.Lambda_area(bestIdx);

m2Amps = [0 0.05 0.10 0.20 0.40] * bestLambda;
for k = 1:numel(m2Amps)
    spec = struct("tag", "lambda_m2_" + string(k), ...
        "Lambda_area", bestLambda, "Lambda_m2", m2Amps(k), ...
        "stop_time", 0.45e-3, "steady_window", 50e-6, ...
        "max_step", "5e-9", "fast_tss", 0.12e-3);
    fprintf("Running m2 sweep %d/%d: Lambda_area=%g Lambda_m2=%g\n", k, numel(m2Amps), bestLambda, m2Amps(k));
    try
        m = runCase(model, spec);
        rows = [rows; rowFromMetrics(spec, m)]; %#ok<AGROW>
    catch ME
        rows = [rows; failureRow(spec, ME.message)]; %#ok<AGROW>
    end
end

csvPath = fullfile(outputRoot, "iqcot_iek_area_model_validation_summary.csv");
writetable(rows, csvPath);
reportPath = writeReport(rows, bestLambda, outputRoot);
makePlot(rows, figureRoot);

fprintf("IEK_AREA_VALIDATION_CSV=%s\n", csvPath);
fprintf("IEK_AREA_VALIDATION_REPORT=%s\n", reportPath);
disp(rows);
results = rows;
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
in = in.setVariable("Lambda_area", spec.Lambda_area);
in = in.setVariable("Lambda_m2", spec.Lambda_m2);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);
out = sim(in);
logs = out.logsout;
steadyStart = spec.stop_time - spec.steady_window;

vout = steadyValues(logs, "vout", steadyStart);
metrics.vout_mean_V = mean(vout);
metrics.vout_ripple_pp_mV = 1e3 * (max(vout) - min(vout));
metrics.il_mean_A = zeros(1, 4);
metrics.il_ripple_pp_A = zeros(1, 4);
metrics.qh_frequency_Hz = zeros(1, 4);
for phase = 1:4
    il = steadyValues(logs, "il" + phase, steadyStart);
    metrics.il_mean_A(phase) = mean(il);
    metrics.il_ripple_pp_A(phase) = max(il) - min(il);
    metrics.qh_frequency_Hz(phase) = risingEdgeFrequency(logs, "qh" + phase, steadyStart);
end
metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.il_phase_imbalance_A = max(metrics.il_mean_A) - min(metrics.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 -1 1 -1]) / 4;
metrics.qh_frequency_mean_Hz = mean(metrics.qh_frequency_Hz);
metrics.qh_frequency_spread_Hz = max(metrics.qh_frequency_Hz) - min(metrics.qh_frequency_Hz);
metrics.trigger_frequency_Hz = risingEdgeFrequency(logs, "trigger", steadyStart);
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);
end

function row = rowFromMetrics(spec, m)
row = table( ...
    string(spec.tag), true, "", ...
    spec.Lambda_area, spec.Lambda_m2, spec.Lambda_m2 / max(spec.Lambda_area, eps), ...
    m.vout_mean_V, m.vout_ripple_pp_mV, ...
    m.il_mean_A(1), m.il_mean_A(2), m.il_mean_A(3), m.il_mean_A(4), ...
    m.il_total_mean_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.qh_frequency_mean_Hz, m.qh_frequency_spread_Hz, m.trigger_frequency_Hz, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    'VariableNames', { ...
        'tag','success','error_message','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'vout_mean_V','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','il_phase_imbalance_A','il_m2_projection_A', ...
        'qh_frequency_mean_Hz','qh_frequency_spread_Hz','trigger_frequency_Hz', ...
        'phase_spacing_mean_ns','phase_spacing_std_ns','phase_sequence_error_fraction'});
end

function row = failureRow(spec, message)
row = table( ...
    string(spec.tag), false, string(message), ...
    spec.Lambda_area, spec.Lambda_m2, spec.Lambda_m2 / max(spec.Lambda_area, eps), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', { ...
        'tag','success','error_message','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'vout_mean_V','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','il_phase_imbalance_A','il_m2_projection_A', ...
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

commonRows = valid(valid.Lambda_m2 == 0, :);
nexttile;
semilogx(commonRows.Lambda_area, commonRows.qh_frequency_mean_Hz / 1e3, "-o", LineWidth=1.2);
grid on; xlabel("Lambda area (V*s)"); ylabel("mean phase frequency (kHz)");

nexttile;
semilogx(commonRows.Lambda_area, commonRows.vout_ripple_pp_mV, "-o", LineWidth=1.2);
grid on; xlabel("Lambda area (V*s)"); ylabel("Vout ripple (mVpp)");

m2Rows = valid(valid.Lambda_m2 ~= 0 | startsWith(valid.tag, "lambda_m2_"), :);
nexttile;
plot(m2Rows.Lambda_m2_ratio, m2Rows.il_phase_imbalance_A, "-o", LineWidth=1.2);
grid on; xlabel("Lambda m2 / Lambda area"); ylabel("phase current imbalance (A)");

nexttile;
plot(m2Rows.Lambda_m2_ratio, m2Rows.il_m2_projection_A, "-o", LineWidth=1.2);
grid on; xlabel("Lambda m2 / Lambda area"); ylabel("m2 current projection (A)");

exportgraphics(fig, fullfile(figureRoot, "fig13_iek_area_simulink_validation.png"), Resolution=180);
end

function reportPath = writeReport(rows, bestLambda, outputRoot)
valid = rows(rows.success, :);
commonRows = valid(valid.Lambda_m2 == 0, :);
m2Rows = valid(startsWith(valid.tag, "lambda_m2_"), :);
reportPath = fullfile(outputRoot, "iqcot_iek_area_model_validation_report.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# IEK 面积触发 Simulink 副本验证\n\n");
fprintf(fid, "模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_area.slx`。\n");
fprintf(fid, "原始模型未修改。副本将 `Relay` 请求替换为面积积分请求：`REQ = integral(max(e_v,0)) >= Lambda_area + Lambda_m2*cos(pi*phase_idx)`。\n\n");
fprintf(fid, "## Lambda_cm 调谐\n\n");
fprintf(fid, "最佳候选 `Lambda_area = %.4g V*s`。\n\n", bestLambda);
if ~isempty(commonRows)
    [~, idx] = min(abs(commonRows.Lambda_area - bestLambda));
    r = commonRows(idx, :);
    fprintf(fid, "该点结果：`Vout_mean=%.9f V`，`Vout_ripple=%.6f mVpp`，平均相频率 `%.3f kHz`，相电流不均衡 `%.6f A`。\n\n", ...
        r.vout_mean_V, r.vout_ripple_pp_mV, r.qh_frequency_mean_Hz/1e3, r.il_phase_imbalance_A);
end
fprintf(fid, "## Lambda_m2 初探\n\n");
if ~isempty(m2Rows)
    [~, idx] = max(abs(m2Rows.Lambda_m2_ratio));
    r = m2Rows(idx, :);
    fprintf(fid, "最大扫描比值 `Lambda_m2/Lambda_area=%.3f` 时，相电流不均衡 `%.6f A`，m2 电流投影 `%.6f A`。\n\n", ...
        r.Lambda_m2_ratio, r.il_phase_imbalance_A, r.il_m2_projection_A);
end
fprintf(fid, "## 解释边界\n\n");
fprintf(fid, "这是首次把严格面积触发 REQ 放进用户四相 Simulink 副本的验证。当前版本的 `phase_idx` 阈值选择仍是探索实现，适合证明 `Lambda_cm` 可闭环工作，并初步观察 `Lambda_m2` 对相电流的影响；后续应进一步校准 phase index 与 next-phase threshold 的对应关系。\n");
end
