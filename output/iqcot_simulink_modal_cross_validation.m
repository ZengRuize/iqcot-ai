function results = iqcot_simulink_modal_cross_validation()
%IQCOT_SIMULINK_MODAL_CROSS_VALIDATION
% Cross-validate four-phase modal on-time perturbations on the user's
% Simulink four_phase.slx model without saving or editing the model.

modelRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(modelRoot);
addpath(modelRoot);
initPath = fullfile(modelRoot, "init_four_phase_cot_sync.m");
evalin("base", sprintf("run('%s')", strrep(initPath, "'", "''")));

model = "four_phase";
load_system(model);
modelCleanup = onCleanup(@() close_system(model, 0));

baseTon = evalin("base", "Ton_cmd");
tblank = evalin("base", "Tblank");
fprintf("MODEL_ROOT=%s\n", modelRoot);
fprintf("BASE_TON_NS=%.6f\n", 1e9 * baseTon);
fprintf("TBLANK_NS=%.6f\n", 1e9 * tblank);

cases = buildCases();
rows = table();
detail = struct([]);
for k = 1:numel(cases)
    fprintf("Running %02d/%02d: %s\n", k, numel(cases), cases(k).tag);
    metrics = runCase(model, cases(k), baseTon);
    detail(k).tag = cases(k).tag; %#ok<AGROW>
    detail(k).pattern = cases(k).pattern;
    detail(k).delta_ns = cases(k).delta_ns;
    detail(k).metrics = metrics;
    rows = [rows; makeRow(cases(k), metrics)]; %#ok<AGROW>
end

csvPath = fullfile(outputRoot, "iqcot_simulink_modal_cross_validation_summary.csv");
writetable(rows, csvPath);

jsonPath = fullfile(outputRoot, "iqcot_simulink_modal_cross_validation_detail.json");
fid = fopen(jsonPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonencode(detail, PrettyPrint=true));
clear cleanup;

makePlots(rows, figureRoot);
reportPath = writeReport(rows, modelRoot, outputRoot);

fprintf("SUMMARY_CSV=%s\n", csvPath);
fprintf("DETAIL_JSON=%s\n", jsonPath);
fprintf("REPORT_MD=%s\n", reportPath);
disp(rows);
results = rows;
end

function cases = buildCases()
common = [1 1 1 1];
m2 = [1 -1 1 -1];
m13 = [1 0 -1 0];
m24 = [0 1 0 -1];

specs = {
    "baseline", "common", [0 0 0 0], 0;
    "common_m4ns", "common", common, -4;
    "common_m2ns", "common", common, -2;
    "common_m1ns", "common", common, -1;
    "common_p1ns", "common", common, 1;
    "common_p2ns", "common", common, 2;
    "common_p4ns", "common", common, 4;
    "m2_p0p25ns", "m2", m2, 0.25;
    "m2_p0p5ns", "m2", m2, 0.5;
    "m2_p1ns", "m2", m2, 1;
    "m2_p2ns", "m2", m2, 2;
    "m2_p4ns", "m2", m2, 4;
    "m13_p2ns", "pair13", m13, 2;
    "m24_p2ns", "pair24", m24, 2;
};

cases = struct([]);
for k = 1:size(specs, 1)
    cases(k).tag = specs{k, 1}; %#ok<AGROW>
    cases(k).mode = specs{k, 2};
    cases(k).pattern = specs{k, 3};
    cases(k).delta_ns = specs{k, 4};
    cases(k).stop_time = 0.65e-3;
    cases(k).steady_window = 50e-6;
    cases(k).max_step = "5e-9";
    cases(k).fast_tss = 0.18e-3;
end
end

function metrics = runCase(model, caseSpec, baseTon)
instrumentSignals(model);

tonVector = baseTon + 1e-9 * caseSpec.delta_ns * caseSpec.pattern(:).';
tonVector = max(tonVector, 20e-9);

in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(caseSpec.stop_time, "%.15g"), ...
    "MaxStep", char(caseSpec.max_step), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");

in = in.setVariable("Tss", caseSpec.fast_tss);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);

for phase = 1:4
    satPath = sprintf("%s/IQCOT_Ton_Adapter/Ton_Limit%d", model, phase);
    value = num2str(tonVector(phase), "%.15g");
    in = in.setBlockParameter(satPath, "LowerLimit", value);
    in = in.setBlockParameter(satPath, "UpperLimit", value);
end

out = sim(in);
logs = out.logsout;
steadyStart = caseSpec.stop_time - caseSpec.steady_window;

metrics = struct();
metrics.ton_vector_ns = 1e9 * tonVector;
metrics.vout_mean_V = mean(steadyValues(logs, "vout", steadyStart));
vout = steadyValues(logs, "vout", steadyStart);
metrics.vout_ripple_pp_mV = 1e3 * (max(vout) - min(vout));

metrics.il_mean_A = zeros(1, 4);
metrics.il_min_A = zeros(1, 4);
metrics.il_max_A = zeros(1, 4);
metrics.il_ripple_pp_A = zeros(1, 4);
metrics.qh_frequency_Hz = zeros(1, 4);
for phase = 1:4
    il = steadyValues(logs, "il" + phase, steadyStart);
    metrics.il_mean_A(phase) = mean(il);
    metrics.il_min_A(phase) = min(il);
    metrics.il_max_A(phase) = max(il);
    metrics.il_ripple_pp_A(phase) = max(il) - min(il);
    metrics.qh_frequency_Hz(phase) = risingEdgeFrequency(logs, "qh" + phase, steadyStart);
end

metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.il_phase_imbalance_A = max(metrics.il_mean_A) - min(metrics.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 -1 1 -1]) / 4;
metrics.il_pair13_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 0 -1 0]) / 2;
metrics.il_pair24_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [0 1 0 -1]) / 2;
metrics.qh_frequency_mean_Hz = mean(metrics.qh_frequency_Hz);
metrics.qh_frequency_spread_Hz = max(metrics.qh_frequency_Hz) - min(metrics.qh_frequency_Hz);
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);
end

function instrumentSignals(model)
signalSpecs = {
    "33",  1, "vout";
    "196", 1, "req";
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

spacing = struct("mean_ns", NaN, "std_ns", NaN, "rms_from_mean_ns", NaN, ...
    "sequence_error_fraction", NaN, "event_count", numel(allTimes));
if numel(allTimes) < 6
    return;
end

dt = diff(allTimes);
spacing.mean_ns = 1e9 * mean(dt);
spacing.std_ns = 1e9 * std(dt);
spacing.rms_from_mean_ns = 1e9 * sqrt(mean((dt - mean(dt)).^2));
expectedNext = mod(allPhases(1:end-1), 4) + 1;
spacing.sequence_error_fraction = mean(allPhases(2:end) ~= expectedNext);
end

function row = makeRow(caseSpec, metrics)
row = table( ...
    string(caseSpec.tag), ...
    string(caseSpec.mode), ...
    caseSpec.delta_ns, ...
    metrics.ton_vector_ns(1), metrics.ton_vector_ns(2), metrics.ton_vector_ns(3), metrics.ton_vector_ns(4), ...
    metrics.vout_mean_V, ...
    metrics.vout_ripple_pp_mV, ...
    metrics.il_mean_A(1), metrics.il_mean_A(2), metrics.il_mean_A(3), metrics.il_mean_A(4), ...
    metrics.il_total_mean_A, ...
    metrics.il_phase_imbalance_A, ...
    metrics.il_m2_projection_A, ...
    metrics.il_pair13_projection_A, ...
    metrics.il_pair24_projection_A, ...
    metrics.qh_frequency_mean_Hz, ...
    metrics.qh_frequency_spread_Hz, ...
    metrics.phase_spacing.mean_ns, ...
    metrics.phase_spacing.std_ns, ...
    metrics.phase_spacing.rms_from_mean_ns, ...
    metrics.phase_spacing.sequence_error_fraction, ...
    metrics.phase_spacing.event_count, ...
    'VariableNames', { ...
        'tag','mode','delta_ns', ...
        'ton1_ns','ton2_ns','ton3_ns','ton4_ns', ...
        'vout_mean_V','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','il_phase_imbalance_A','il_m2_projection_A', ...
        'il_pair13_projection_A','il_pair24_projection_A', ...
        'qh_frequency_mean_Hz','qh_frequency_spread_Hz', ...
        'phase_spacing_mean_ns','phase_spacing_std_ns','phase_spacing_rms_from_mean_ns', ...
        'phase_sequence_error_fraction','phase_event_count'});
end

function makePlots(rows, figureRoot)
baseline = rows(rows.tag == "baseline", :);

fig = figure(Visible="off", Position=[100 100 1100 760]);
cleanup = onCleanup(@() close(fig));
tiledlayout(2, 2);

nexttile;
commonRows = rows(rows.mode == "common", :);
plot(commonRows.delta_ns, commonRows.vout_mean_V - baseline.vout_mean_V, "-o", LineWidth=1.2);
grid on; xlabel("common Ton perturbation (ns)"); ylabel("\Delta Vout mean (V)");

nexttile;
plot(commonRows.delta_ns, commonRows.qh_frequency_mean_Hz / 1e3, "-o", LineWidth=1.2);
grid on; xlabel("common Ton perturbation (ns)"); ylabel("mean phase frequency (kHz)");

nexttile;
m2Rows = rows(rows.mode == "m2", :);
plot(m2Rows.delta_ns, m2Rows.il_phase_imbalance_A, "-o", LineWidth=1.2);
grid on; xlabel("m2 Ton perturbation amplitude (ns)"); ylabel("phase current imbalance (A)");

nexttile;
plot(m2Rows.delta_ns, m2Rows.il_m2_projection_A, "-o", LineWidth=1.2);
grid on; xlabel("m2 Ton perturbation amplitude (ns)"); ylabel("m2 current projection (A)");

exportgraphics(fig, fullfile(figureRoot, "fig11_simulink_modal_cross_validation.png"), Resolution=180);
end

function reportPath = writeReport(rows, modelRoot, outputRoot)
baseline = rows(rows.tag == "baseline", :);
commonRows = rows(rows.mode == "common", :);
m2Rows = rows(rows.mode == "m2", :);

[~, idxCommon] = max(abs(commonRows.delta_ns));
commonEdge = commonRows(idxCommon, :);
[~, idxM2] = max(m2Rows.delta_ns);
m2Edge = m2Rows(idxM2, :);

reportPath = fullfile(outputRoot, "iqcot_simulink_modal_cross_validation_report.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# Simulink 四相 IQCOT/COT 模态交叉验证\n\n");
fprintf(fid, "模型：`%s`。本脚本未保存或修改 `.slx`，仅通过 `SimulationInput.setBlockParameter` 临时钳位四相 `Ton_Limit`。\n\n", modelRoot);
fprintf(fid, "## 基线\n\n");
fprintf(fid, "- Vout mean: %.9f V\n", baseline.vout_mean_V);
fprintf(fid, "- Vout ripple: %.6f mVpp\n", baseline.vout_ripple_pp_mV);
fprintf(fid, "- IL mean: [%.6f, %.6f, %.6f, %.6f] A\n", baseline.il1_mean_A, baseline.il2_mean_A, baseline.il3_mean_A, baseline.il4_mean_A);
fprintf(fid, "- Phase-current imbalance: %.6f A\n", baseline.il_phase_imbalance_A);
fprintf(fid, "- Mean phase frequency: %.3f kHz\n\n", baseline.qh_frequency_mean_Hz / 1e3);

fprintf(fid, "## 主要观察\n\n");
fprintf(fid, "1. Common-mode `Ton` 扰动主要改变输出工作点与等效频率。最大 common 扰动样本 `%s` 相对基线的 Vout 均值变化为 %.6g V，频率变化为 %.6g kHz。\n", ...
    commonEdge.tag, commonEdge.vout_mean_V - baseline.vout_mean_V, (commonEdge.qh_frequency_mean_Hz - baseline.qh_frequency_mean_Hz) / 1e3);
fprintf(fid, "2. m2 差模 `Ton` 扰动主要放大相电流不均衡。最大 m2 样本 `%s` 的相电流不均衡为 %.6f A，m2 电流投影为 %.6f A；基线分别为 %.6f A 与 %.6f A。\n", ...
    m2Edge.tag, m2Edge.il_phase_imbalance_A, m2Edge.il_m2_projection_A, baseline.il_phase_imbalance_A, baseline.il_m2_projection_A);
fprintf(fid, "3. 该模型验证的是论文创新中的“模态执行量分类/差模 on-time 均流通道”，不是面积阈值 `Lambda` 触发的完整 IEK 结构。要验证 `Lambda` 通道，需要在模型中加入输出误差面积积分触发器或等效数字事件核。\n\n");

fprintf(fid, "## 文件\n\n");
fprintf(fid, "- `iqcot_simulink_modal_cross_validation_summary.csv`\n");
fprintf(fid, "- `iqcot_simulink_modal_cross_validation_detail.json`\n");
fprintf(fid, "- `figures/fig11_simulink_modal_cross_validation.png`\n");
end
