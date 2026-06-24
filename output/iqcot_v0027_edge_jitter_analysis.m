function result = iqcot_v0027_edge_jitter_analysis()
%IQCOT_V0027_EDGE_JITTER_ANALYSIS Non-invasive jitter metrics for v0027 model.
%
% This script does not edit four_phase.slx. It loads the model, marks existing
% signals for logging, runs a short steady-state simulation, and computes edge
% period jitter for req/trigger/qh signals.

modelRoot = "E:/Desktop/4cot/versions/v0027_20260611_135822_iqcot_optimized_final_cn_docs";
oldFolder = pwd;
cleanup = onCleanup(@() cd(oldFolder));
cd(modelRoot);
addpath(modelRoot);

initPath = fullfile(modelRoot, "init_four_phase_cot_sync.m");
evalin("base", sprintf("run('%s')", strrep(initPath, "'", "''")));
model = "four_phase";
load_system(model);
modelCleanup = onCleanup(@() close_system(model, 0));

signalSpecs = {
    "196", 1, "req";
    "219", 1, "trigger";
    "78",  1, "qh1";
    "99",  1, "qh2";
    "120", 1, "qh3";
    "141", 1, "qh4";
};

for k = 1:size(signalSpecs, 1)
    instrumentPort(model, signalSpecs{k, 1}, signalSpecs{k, 2}, signalSpecs{k, 3});
end

for phase = 1:4
    instrumentBlockPort(model + "/IL_Measurement" + phase, 1, "il" + phase);
end

stopTime = 0.50e-3;
steadyStart = 0.42e-3;

in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(stopTime, "%.15g"), ...
    "MaxStep", "4e-9", ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");

% Speed up soft-start for analysis only; the model file is not modified.
in = in.setVariable("Tss", 0.12e-3);

% Example overrides. Edit these values or build a loop around this script.
in = in.setVariable("Iqcot_enable", 1);
in = in.setVariable("Kiqcot", 0);
in = in.setVariable("Tiqcot_leak", 80e-6);

out = sim(in);
logs = out.logsout;

result = struct;
result.modelRoot = char(modelRoot);
result.stopTime = stopTime;
result.steadyStart = steadyStart;
result.Kiqcot = 0;
result.Tiqcot_leak = 80e-6;
result.req = edgeStats(logs, "req", steadyStart);
result.trigger = edgeStats(logs, "trigger", steadyStart);

for phase = 1:4
    result.qh(phase) = edgeStats(logs, "qh" + phase, steadyStart); %#ok<AGROW>
    il = steadyValues(logs, "il" + phase, steadyStart);
    result.il_mean_A(phase) = mean(il); %#ok<AGROW>
    result.il_ripple_pp_A(phase) = max(il) - min(il); %#ok<AGROW>
end
result.il_phase_imbalance_A = max(result.il_mean_A) - min(result.il_mean_A);

jsonText = jsonencode(result, PrettyPrint=true);
outputPath = "E:/Desktop/codex/output/iqcot_v0027_edge_jitter_last.json";
fid = fopen(outputPath, "w");
fileCleanup = onCleanup(@() fclose(fid));
fprintf(fid, "%s\n", jsonText);
clear fileCleanup;

disp(jsonText);
fprintf("EDGE_JITTER_JSON=%s\n", outputPath);
end

function instrumentPort(model, sid, portNumber, signalName)
blockPath = Simulink.ID.getFullName(model + ":" + sid);
instrumentBlockPort(blockPath, portNumber, signalName);
end

function instrumentBlockPort(blockPath, portNumber, signalName)
ports = get_param(blockPath, "PortHandles");
portHandle = ports.Outport(portNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", signalName);
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function stats = edgeStats(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
time = series.Time(mask);
values = squeeze(double(series.Data(mask)));
risingTimes = time(find(diff(values > 0.5) > 0) + 1);
periods = diff(risingTimes);
stats = struct;
stats.edge_count = numel(risingTimes);
if isempty(periods)
    stats.frequency_mean_Hz = 0;
    stats.period_mean_s = NaN;
    stats.period_std_s = NaN;
    stats.period_pp_s = NaN;
    stats.period_jitter_norm = NaN;
else
    stats.frequency_mean_Hz = 1 / mean(periods);
    stats.period_mean_s = mean(periods);
    stats.period_std_s = std(periods, 1);
    stats.period_pp_s = max(periods) - min(periods);
    stats.period_jitter_norm = stats.period_std_s / stats.period_mean_s;
end
end

function values = steadyValues(logs, signalName, steadyStart)
series = logs.get(char(signalName)).Values;
mask = series.Time >= steadyStart;
values = squeeze(double(series.Data(mask)));
end
