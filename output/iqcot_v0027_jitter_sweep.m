function tableOut = iqcot_v0027_jitter_sweep()
%IQCOT_V0027_JITTER_SWEEP Small non-invasive jitter sweep for v0027.
%
% Runs a compact set of simulations with SimulationInput overrides only.
% The original four_phase.slx file is not saved or modified.

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
    "33",  1, "vout";
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

cases = [
    struct("name", "k0_q1", "Kiqcot", 0,     "Tiqcot_leak", 80e-6, "qint", 1)
    struct("name", "k3e5_q1", "Kiqcot", 3e-5, "Tiqcot_leak", 20e-6, "qint", 1)
    struct("name", "k0_q4", "Kiqcot", 0,     "Tiqcot_leak", 80e-6, "qint", 4)
    struct("name", "k3e5_q4", "Kiqcot", 3e-5, "Tiqcot_leak", 20e-6, "qint", 4)
];

rows = table();
for idx = 1:numel(cases)
    fprintf("Running %s\n", cases(idx).name);
    one = runCase(model, cases(idx));
    rows = [rows; struct2table(one, AsArray=true)]; %#ok<AGROW>
end

tableOut = rows;
outputCsv = "E:/Desktop/codex/output/iqcot_v0027_jitter_sweep_summary.csv";
writetable(tableOut, outputCsv);
disp(tableOut);
fprintf("JITTER_SWEEP_CSV=%s\n", outputCsv);
end

function row = runCase(model, cfg)
stopTime = 0.50e-3;
steadyStart = 0.42e-3;

in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(stopTime, "%.15g"), ...
    "MaxStep", "4e-9", ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");

in = in.setVariable("Tss", 0.12e-3);
in = in.setVariable("Iqcot_enable", 1);
in = in.setVariable("Kiqcot", cfg.Kiqcot);
in = in.setVariable("Tiqcot_leak", cfg.Tiqcot_leak);

quantizers = ["four_phase/Quantizer1", "four_phase/Quantizer2", ...
              "four_phase/Quantizer3", "four_phase/Quantizer4"];
for q = quantizers
    in = in.setBlockParameter(q, "QuantizationInterval", num2str(cfg.qint));
end

out = sim(in);
logs = out.logsout;

req = edgeStats(logs, "req", steadyStart);
trigger = edgeStats(logs, "trigger", steadyStart);
qhStats = repmat(edgeStats(logs, "qh1", steadyStart), 1, 4);
for phase = 1:4
    qhStats(phase) = edgeStats(logs, "qh" + phase, steadyStart);
    il = steadyValues(logs, "il" + phase, steadyStart);
    ilMean(phase) = mean(il); %#ok<AGROW>
    ilRipple(phase) = max(il) - min(il); %#ok<AGROW>
end

vout = steadyValues(logs, "vout", steadyStart);

row = struct;
row.name = string(cfg.name);
row.Kiqcot = cfg.Kiqcot;
row.Tiqcot_leak_us = cfg.Tiqcot_leak * 1e6;
row.quantizer_interval_count = cfg.qint;
row.vout_mean_V = mean(vout);
row.vout_ripple_pp_mV = 1e3 * (max(vout) - min(vout));
row.req_period_std_ns = req.period_std_s * 1e9;
row.trigger_period_std_ns = trigger.period_std_s * 1e9;
row.qh_period_std_mean_ns = mean([qhStats.period_std_s]) * 1e9;
row.qh_period_pp_max_ns = max([qhStats.period_pp_s]) * 1e9;
row.qh_frequency_mean_Hz = mean([qhStats.frequency_mean_Hz]);
row.il_phase_imbalance_A = max(ilMean) - min(ilMean);
row.il_ripple_pp_mean_A = mean(ilRipple);
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
