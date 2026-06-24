function rows = iqcot_simulink_perphase_fd_validation()
%IQCOT_SIMULINK_PERPHASE_FD_VALIDATION Circuit-level finite-difference study.
%
% Uses the trim-enabled Simulink copy:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase_trim.slx
%
% The script does not touch the user's original model.

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
model = "four_phase_iek_perphase_trim";
load_system(fullfile(modelRoot, model + ".slx"));
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

lambdaArea = 6e-10;
vAreaBias = 2e-3;
riArea = 0.5e-3;
loadValues = [20 40 50];
patterns = patternLibrary();
lambdaAmps = 0.10 * lambdaArea;
% The Simulink COT cells include discrete timing effects; ps-level Ton trims
% can be below the effective event resolution.  Use a finite 4 ns trim for
% circuit-level direction/scale validation and report the normalization.
tonAmps = 4.0 * 1e-9;

sampleRows = table();
jacRows = table();
caseIndex = 0;
for iLoad = 1:numel(loadValues)
    loadA = loadValues(iLoad);
    baseSpec = makeSpec(loadA, "baseline", "none", 0, 0, zeros(1,4), zeros(1,4), ...
        lambdaArea, vAreaBias, riArea);
    baseMetrics = tryRun(model, baseSpec);
    sampleRows = [sampleRows; rowFromMetrics(baseSpec, 0, baseMetrics)]; %#ok<AGROW>

    for iPattern = 1:numel(patterns)
        pat = patterns(iPattern);
        for amp = lambdaAmps
            caseIndex = caseIndex + 1;
            [plusRow, minusRow, jacRow] = centralPair(model, baseMetrics, loadA, ...
                "Lambda", pat.name, amp, pat.vector, lambdaArea, vAreaBias, riArea, caseIndex);
            sampleRows = [sampleRows; plusRow; minusRow]; %#ok<AGROW>
            jacRows = [jacRows; jacRow]; %#ok<AGROW>
        end
        for amp = tonAmps
            caseIndex = caseIndex + 1;
            [plusRow, minusRow, jacRow] = centralPair(model, baseMetrics, loadA, ...
                "Ton", pat.name, amp, pat.vector, lambdaArea, vAreaBias, riArea, caseIndex);
            sampleRows = [sampleRows; plusRow; minusRow]; %#ok<AGROW>
            jacRows = [jacRows; jacRow]; %#ok<AGROW>
        end
    end
end

samplePath = fullfile(outputRoot, "iqcot_simulink_perphase_fd_samples.csv");
jacPath = fullfile(outputRoot, "iqcot_simulink_perphase_fd_jacobian.csv");
writetable(sampleRows, samplePath);
writetable(jacRows, jacPath);
makePlot(jacRows, figureRoot);
reportPath = writeReport(sampleRows, jacRows, outputRoot);

fprintf("SIMULINK_FD_SAMPLES=%s\n", samplePath);
fprintf("SIMULINK_FD_JACOBIAN=%s\n", jacPath);
fprintf("SIMULINK_FD_REPORT=%s\n", reportPath);
disp(jacRows);
rows = jacRows;
end

function patterns = patternLibrary()
patterns = struct( ...
    "name", {"m2_alt", "one_phase"}, ...
    "vector", {[1 -1 1 -1], [1 -1/3 -1/3 -1/3]});
end

function [plusRow, minusRow, jacRow] = centralPair(model, baseMetrics, loadA, ...
    actuator, patternName, amp, pattern, lambdaArea, vAreaBias, riArea, caseIndex)

if actuator == "Lambda"
    normDen = amp / 1e-13;
    unit = "per_1e-13_Vs";
else
    normDen = amp / 0.1e-9;
    unit = "per_0p1ns";
end

plusSpec = signedSpec(loadA, actuator, patternName, amp, pattern, +1, ...
    lambdaArea, vAreaBias, riArea, caseIndex);
minusSpec = signedSpec(loadA, actuator, patternName, amp, pattern, -1, ...
    lambdaArea, vAreaBias, riArea, caseIndex);

fprintf("FD %03d load %.0f A %s/%s amp=%g\n", ...
    caseIndex, loadA, actuator, patternName, amp);
plusMetrics = tryRun(model, plusSpec);
minusMetrics = tryRun(model, minusSpec);

plusRow = rowFromMetrics(plusSpec, +1, plusMetrics);
minusRow = rowFromMetrics(minusSpec, -1, minusMetrics);
jacRow = jacobianRow(plusSpec, plusMetrics, minusMetrics, baseMetrics, normDen, unit);
end

function spec = signedSpec(loadA, actuator, patternName, amp, pattern, signVal, ...
    lambdaArea, vAreaBias, riArea, caseIndex)

lambdaVec = lambdaArea * ones(1, 4);
tonVec = zeros(1, 4);
if actuator == "Lambda"
    lambdaVec = lambdaVec + signVal * amp * pattern;
else
    tonVec = signVal * amp * pattern;
end
spec = makeSpec(loadA, actuator, patternName, amp, signVal, lambdaVec, tonVec, ...
    lambdaArea, vAreaBias, riArea);
spec.case_index = caseIndex;
end

function spec = makeSpec(loadA, actuator, patternName, amp, signVal, lambdaVec, tonVec, ...
    lambdaArea, vAreaBias, riArea)
spec = struct();
spec.case_index = 0;
spec.load_A = loadA;
spec.Rload = 1.0 / loadA;
spec.Iph = loadA / 4;
spec.actuator = actuator;
spec.pattern = patternName;
spec.amplitude = amp;
spec.sign = signVal;
spec.Lambda_area = lambdaArea;
spec.Lambda_vec = lambdaVec;
spec.Ton_trim_vec = tonVec;
spec.Varea_bias = vAreaBias;
spec.Ri_area = riArea;
spec.stop_time = 0.30e-3;
spec.steady_window = 35e-6;
spec.max_step = "1e-8";
spec.fast_tss = 5e-9;
end

function metrics = tryRun(model, spec)
try
    metrics = runCase(model, spec);
    metrics.success = true;
    metrics.error_message = "";
catch ME
    metrics = failureMetrics(ME.message);
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
metrics.il_m1_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 0 -1 0]) / 2;
metrics.il_m2_projection_A = dot(metrics.il_mean_A - mean(metrics.il_mean_A), [1 -1 1 -1]) / 4;
metrics.qh_frequency_mean_Hz = mean(metrics.qh_frequency_Hz);
metrics.qh_frequency_spread_Hz = max(metrics.qh_frequency_Hz) - min(metrics.qh_frequency_Hz);
metrics.trigger_frequency_Hz = risingEdgeFrequency(logs, "trigger", steadyStart);
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);
metrics.success = true;
metrics.error_message = "";
end

function metrics = failureMetrics(message)
metrics.success = false;
metrics.error_message = string(message);
metrics.vout_mean_V = NaN;
metrics.vout_ripple_pp_mV = NaN;
metrics.il_mean_A = NaN(1,4);
metrics.il_ripple_pp_A = NaN(1,4);
metrics.il_total_mean_A = NaN;
metrics.il_phase_imbalance_A = NaN;
metrics.il_m1_projection_A = NaN;
metrics.il_m2_projection_A = NaN;
metrics.qh_frequency_mean_Hz = NaN;
metrics.qh_frequency_spread_Hz = NaN;
metrics.trigger_frequency_Hz = NaN;
metrics.phase_spacing = struct("mean_ns", NaN, "std_ns", NaN, "sequence_error_fraction", NaN);
end

function row = rowFromMetrics(spec, signVal, m)
row = table( ...
    spec.case_index, string(spec.actuator), string(spec.pattern), spec.load_A, ...
    spec.amplitude, signVal, string(vecText(spec.Lambda_vec, "%.12g")), string(vecText(1e9*spec.Ton_trim_vec, "%.9g")), ...
    m.success, string(m.error_message), ...
    m.vout_mean_V, m.vout_ripple_pp_mV, ...
    m.il_mean_A(1), m.il_mean_A(2), m.il_mean_A(3), m.il_mean_A(4), ...
    m.il_total_mean_A, m.il_phase_imbalance_A, m.il_m1_projection_A, m.il_m2_projection_A, ...
    m.qh_frequency_mean_Hz, m.qh_frequency_spread_Hz, m.trigger_frequency_Hz, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    'VariableNames', {'case_index','actuator','pattern','load_A','amplitude','sign', ...
    'Lambda_vec','Ton_trim_vec_ns','success','error_message','vout_mean_V','vout_ripple_pp_mV', ...
    'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A','il_total_mean_A', ...
    'il_phase_imbalance_A','il_m1_projection_A','il_m2_projection_A', ...
    'qh_frequency_mean_Hz','qh_frequency_spread_Hz','trigger_frequency_Hz', ...
    'phase_spacing_mean_ns','phase_spacing_std_ns','phase_sequence_error_fraction'});
end

function row = jacobianRow(spec, plusM, minusM, baseM, normDen, unit)
if plusM.success && minusM.success
    d = @(a,b) (a - b) / (2 * normDen);
    rel = @(a,b) (a - b);
    success = true;
    err = "";
else
    d = @(a,b) NaN;
    rel = @(a,b) NaN;
    success = false;
    err = plusM.error_message + " | " + minusM.error_message;
end
row = table( ...
    spec.case_index, string(spec.actuator), string(spec.pattern), string(unit), spec.load_A, spec.amplitude, success, string(err), ...
    d(plusM.vout_mean_V, minusM.vout_mean_V), ...
    d(plusM.vout_ripple_pp_mV, minusM.vout_ripple_pp_mV), ...
    d(plusM.il_phase_imbalance_A, minusM.il_phase_imbalance_A), ...
    d(plusM.il_m1_projection_A, minusM.il_m1_projection_A), ...
    d(plusM.il_m2_projection_A, minusM.il_m2_projection_A), ...
    d(plusM.qh_frequency_mean_Hz, minusM.qh_frequency_mean_Hz), ...
    d(plusM.qh_frequency_spread_Hz, minusM.qh_frequency_spread_Hz), ...
    d(plusM.phase_spacing.mean_ns, minusM.phase_spacing.mean_ns), ...
    d(plusM.phase_spacing.std_ns, minusM.phase_spacing.std_ns), ...
    rel(baseM.il_phase_imbalance_A, 0), rel(baseM.phase_spacing.std_ns, 0), ...
    'VariableNames', {'case_index','actuator','pattern','normalization','load_A','amplitude','success','error_message', ...
    'G_vout_mean_V','G_vout_ripple_mVpp','G_current_imbalance_A','G_m1_current_A','G_m2_current_A', ...
    'G_qh_frequency_mean_Hz','G_qh_frequency_spread_Hz','G_phase_spacing_mean_ns','G_phase_spacing_std_ns', ...
    'baseline_current_imbalance_A','baseline_phase_spacing_std_ns'});
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

function makePlot(jacRows, figureRoot)
valid = jacRows(jacRows.success, :);
fig = figure(Visible="off", Position=[100 100 1150 760]);
cleanup = onCleanup(@() close(fig));
tiledlayout(2, 2);

nexttile;
plotMetric(valid, "Lambda", "m2_alt", "G_m2_current_A", 1e3);
ylabel("G m2 current (mA / 1e-13 V*s)");
title("Lambda m2 -> current");

nexttile;
plotMetric(valid, "Ton", "m2_alt", "G_m2_current_A", 1e3);
ylabel("G m2 current (mA / 0.1 ns)");
title("Ton m2 -> current");

nexttile;
plotMetric(valid, "Lambda", "m2_alt", "G_phase_spacing_std_ns", 1);
ylabel("G spacing std (ns / 1e-13 V*s)");
title("Lambda m2 -> spacing");

nexttile;
plotMetric(valid, "Ton", "m2_alt", "G_phase_spacing_std_ns", 1);
ylabel("G spacing std (ns / 0.1 ns)");
title("Ton m2 -> spacing");

exportgraphics(fig, fullfile(figureRoot, "fig18_simulink_fd_jacobian.png"), Resolution=180);
end

function plotMetric(rows, actuator, pattern, metric, scale)
pick = rows(rows.actuator == actuator & rows.pattern == pattern, :);
amps = unique(pick.amplitude);
hold on;
for i = 1:numel(amps)
    r = pick(abs(pick.amplitude - amps(i)) < max(1e-30, abs(amps(i))*1e-9), :);
    plot(r.load_A, r.(metric) * scale, "-o", LineWidth=1.2, ...
        DisplayName=sprintf("amp %.3g", amps(i)));
end
grid on; xlabel("load current (A)"); legend(Location="best");
end

function reportPath = writeReport(sampleRows, jacRows, outputRoot)
valid = jacRows(jacRows.success, :);
reportPath = fullfile(outputRoot, "iqcot_simulink_perphase_fd_validation_report.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, "# Simulink per-phase IEK finite-difference validation\n\n");
fprintf(fid, "Model copy: `E:/Desktop/codex/output/simulink_iek/four_phase_iek_perphase_trim.slx`.\n\n");
fprintf(fid, "Raw simulation samples: `%d`; central-difference Jacobian rows: `%d`.\n\n", height(sampleRows), height(jacRows));
if isempty(valid)
    fprintf(fid, "No successful finite-difference rows.\n");
    return;
end

lambdaM2 = valid(valid.actuator == "Lambda" & valid.pattern == "m2_alt", :);
tonM2 = valid(valid.actuator == "Ton" & valid.pattern == "m2_alt", :);
fprintf(fid, "## Key observations\n\n");
fprintf(fid, "- Lambda m2 median `|G_m2_current|` = `%.6g mA/(1e-13 V*s)`, median `|G_spacing_std|` = `%.6g ns/(1e-13 V*s)`.\n", ...
    1e3 * median(abs(lambdaM2.G_m2_current_A)), median(abs(lambdaM2.G_phase_spacing_std_ns)));
fprintf(fid, "- Ton m2 median `|G_m2_current|` = `%.6g mA/(0.1 ns)`, median `|G_spacing_std|` = `%.6g ns/(0.1 ns)`.\n", ...
    1e3 * median(abs(tonM2.G_m2_current_A)), median(abs(tonM2.G_phase_spacing_std_ns)));
fprintf(fid, "- The comparison is not an exact equality test against the analytical PIS-IEK model. It is a circuit-level direction and scale check using the strict area-trigger Simulink copy with direct per-phase variables.\n\n");
fprintf(fid, "## Interpretation\n\n");
fprintf(fid, "The finite-difference data are intended to close the evidence gap noted by the reviewer: PIS-IEK should not be supported only by an analytical event script. If the Simulink copy keeps showing that Lambda-differential perturbations have weak DC current gain while Ton-differential perturbations have much stronger current gain, the actuator-classification claim is supported at the switching-circuit level.\n");
end

function txt = vecText(vec, fmtSpec)
parts = strings(1, numel(vec));
for k = 1:numel(vec)
    parts(k) = sprintf(fmtSpec, vec(k));
end
txt = strjoin(parts, " ");
end
