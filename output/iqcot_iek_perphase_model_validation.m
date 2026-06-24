function results = iqcot_iek_perphase_model_validation()
%IQCOT_IEK_PERPHASE_MODEL_VALIDATION Validate per-phase IQCOT-like IEK copy.

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

model = "four_phase_iek_perphase";
load_system(model);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

% The product Lambda/Twait suggests an average h_i near sub-mV to a few mV.
% Sweep both because the signed Ri*(Iph-IL_i) term changes effective area.
lambdaValues = [1e-10 2e-10 3e-10 6e-10 1e-9];
vBiasValues = [0.5e-3 1.0e-3 1.5e-3 2.0e-3];
riArea = 0.5e-3;
rows = table();

caseIndex = 0;
for vb = vBiasValues
    for la = lambdaValues
        caseIndex = caseIndex + 1;
        spec = makeSpec("cm_" + string(caseIndex), la, 0, vb, riArea);
        fprintf("Running CM %02d: Lambda=%g Vbias=%g\n", caseIndex, la, vb);
        rows = [rows; tryRun(model, spec)]; %#ok<AGROW>
    end
end

valid = rows(rows.success, :);
valid = valid(valid.qh_frequency_mean_Hz > 300e3 & valid.qh_frequency_mean_Hz < 700e3, :);
if isempty(valid)
    error("No valid per-phase IEK cases near target frequency.");
end
score = abs(valid.qh_frequency_mean_Hz - 500e3) / 1e3 + ...
    2000 * abs(valid.vout_mean_V - 1.0) + ...
    3 * valid.il_phase_imbalance_A + ...
    0.1 * valid.phase_spacing_std_ns;
[~, bestIdx] = min(score);
best = valid(bestIdx, :);

m2Ratios = [0 0.05 0.10 0.20 0.40];
for k = 1:numel(m2Ratios)
    spec = makeSpec("m2_" + string(k), best.Lambda_area, best.Lambda_area * m2Ratios(k), best.Varea_bias, riArea);
    fprintf("Running M2 %d/%d: Lambda=%g Lambda_m2=%g Vbias=%g\n", ...
        k, numel(m2Ratios), spec.Lambda_area, spec.Lambda_m2, spec.Varea_bias);
    rows = [rows; tryRun(model, spec)]; %#ok<AGROW>
end

csvPath = fullfile(outputRoot, "iqcot_iek_perphase_model_validation_summary.csv");
writetable(rows, csvPath);
makePlot(rows, figureRoot);
reportPath = writeReport(rows, best, outputRoot);

fprintf("IEK_PERPHASE_VALIDATION_CSV=%s\n", csvPath);
fprintf("IEK_PERPHASE_VALIDATION_REPORT=%s\n", reportPath);
disp(rows);
results = rows;
end

function spec = makeSpec(tag, lambdaArea, lambdaM2, vBias, riArea)
spec = struct( ...
    "tag", tag, ...
    "Lambda_area", lambdaArea, ...
    "Lambda_m2", lambdaM2, ...
    "Varea_bias", vBias, ...
    "Ri_area", riArea, ...
    "stop_time", 0.45e-3, ...
    "steady_window", 50e-6, ...
    "max_step", "5e-9", ...
    "fast_tss", 0.12e-3);
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
    spec.Varea_bias, spec.Ri_area, ...
    m.vout_mean_V, m.vout_ripple_pp_mV, ...
    m.il_mean_A(1), m.il_mean_A(2), m.il_mean_A(3), m.il_mean_A(4), ...
    m.il_total_mean_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.qh_frequency_mean_Hz, m.qh_frequency_spread_Hz, m.trigger_frequency_Hz, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    'VariableNames', { ...
        'tag','success','error_message','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'Varea_bias','Ri_area','vout_mean_V','vout_ripple_pp_mV', ...
        'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A', ...
        'il_total_mean_A','il_phase_imbalance_A','il_m2_projection_A', ...
        'qh_frequency_mean_Hz','qh_frequency_spread_Hz','trigger_frequency_Hz', ...
        'phase_spacing_mean_ns','phase_spacing_std_ns','phase_sequence_error_fraction'});
end

function row = failureRow(spec, message)
row = table( ...
    string(spec.tag), false, string(message), ...
    spec.Lambda_area, spec.Lambda_m2, spec.Lambda_m2 / max(spec.Lambda_area, eps), ...
    spec.Varea_bias, spec.Ri_area, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', { ...
        'tag','success','error_message','Lambda_area','Lambda_m2','Lambda_m2_ratio', ...
        'Varea_bias','Ri_area','vout_mean_V','vout_ripple_pp_mV', ...
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

cmRows = valid(startsWith(valid.tag, "cm_"), :);
nexttile;
scatter(cmRows.qh_frequency_mean_Hz / 1e3, cmRows.vout_mean_V, 36, cmRows.Varea_bias * 1e3, "filled");
grid on; xlabel("mean phase frequency (kHz)"); ylabel("Vout mean (V)");
cb = colorbar; ylabel(cb, "Varea bias (mV)");

nexttile;
scatter(cmRows.qh_frequency_mean_Hz / 1e3, cmRows.phase_spacing_std_ns, 36, log10(cmRows.Lambda_area), "filled");
grid on; xlabel("mean phase frequency (kHz)"); ylabel("phase spacing std (ns)");
cb = colorbar; ylabel(cb, "log10 Lambda");

m2Rows = valid(startsWith(valid.tag, "m2_"), :);
nexttile;
plot(m2Rows.Lambda_m2_ratio, m2Rows.il_phase_imbalance_A, "-o", LineWidth=1.2);
grid on; xlabel("Lambda m2 / Lambda area"); ylabel("phase current imbalance (A)");

nexttile;
plot(m2Rows.Lambda_m2_ratio, m2Rows.il_m2_projection_A, "-o", LineWidth=1.2);
grid on; xlabel("Lambda m2 / Lambda area"); ylabel("m2 current projection (A)");

exportgraphics(fig, fullfile(figureRoot, "fig14_iek_perphase_simulink_validation.png"), Resolution=180);
end

function reportPath = writeReport(rows, best, outputRoot)
valid = rows(rows.success, :);
m2Rows = valid(startsWith(valid.tag, "m2_"), :);
reportPath = fullfile(outputRoot, "iqcot_iek_perphase_model_validation_report.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# 逐相 IEK 面积核 Simulink 副本验证\n\n");
fprintf(fid, "模型副本：`E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase.slx`。\n");
fprintf(fid, "面积核：`h_i = Varea_bias + e_v + Ri_area*(Iph - IL_i)`，并按 `phase_idx` 选择对应相的面积比较结果生成 `REQ`。\n\n");
fprintf(fid, "## 最佳候选\n\n");
fprintf(fid, "- `Lambda_area = %.4g V*s`\n", best.Lambda_area);
fprintf(fid, "- `Varea_bias = %.4g V`\n", best.Varea_bias);
fprintf(fid, "- `Ri_area = %.4g ohm`\n", best.Ri_area);
fprintf(fid, "- `Vout_mean = %.9f V`\n", best.vout_mean_V);
fprintf(fid, "- `Vout_ripple = %.6f mVpp`\n", best.vout_ripple_pp_mV);
fprintf(fid, "- mean phase frequency = `%.3f kHz`\n", best.qh_frequency_mean_Hz / 1e3);
fprintf(fid, "- phase-current imbalance = `%.6f A`\n", best.il_phase_imbalance_A);
fprintf(fid, "- phase-spacing std = `%.6f ns`\n\n", best.phase_spacing_std_ns);

fprintf(fid, "## Lambda_m2 扫描\n\n");
if ~isempty(m2Rows)
    [~, idx] = max(abs(m2Rows.Lambda_m2_ratio));
    r = m2Rows(idx, :);
    fprintf(fid, "最大扫描比值 `Lambda_m2/Lambda_area=%.3f` 时，相电流不均衡 `%.6f A`，m2 电流投影 `%.6f A`，phase-spacing std `%.6f ns`。\n\n", ...
        r.Lambda_m2_ratio, r.il_phase_imbalance_A, r.il_m2_projection_A, r.phase_spacing_std_ns);
end
fprintf(fid, "## 解释\n\n");
fprintf(fid, "该副本比 v4 的 `integral(max(e_v,0))` 更接近 IQCOT 小信号形式，因为它显式引入逐相电感电流项 `Ri_area*(Iph-IL_i)`。当前结果可用于检验 `Lambda_m2` 是否产生可观 DC 均流，以及它对 phase-spacing 的副作用。\n");
end
