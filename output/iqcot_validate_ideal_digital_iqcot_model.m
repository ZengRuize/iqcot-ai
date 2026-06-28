function results = iqcot_validate_ideal_digital_iqcot_model()
%IQCOT_VALIDATE_IDEAL_DIGITAL_IQCOT_MODEL Validate the ideal IQCOT copy.

projectRoot = "E:\Desktop\codex";
modelRoot = fullfile(projectRoot, "output", "simulink_ideal_iqcot");
modelName = "four_phase_ideal_digital_iqcot";
modelFile = fullfile(modelRoot, modelName + ".slx");
dataRoot = fullfile(projectRoot, "output", "ideal_digital_iqcot_data");
resultsRoot = fullfile(projectRoot, "output", "ideal_digital_iqcot_results");
docsRoot = fullfile(projectRoot, "docs");
ensureDir(dataRoot);
ensureDir(resultsRoot);
ensureDir(docsRoot);

if ~isfile(modelFile)
    run(fullfile(projectRoot, "output", "iqcot_build_ideal_digital_iqcot_model.m"));
end

evalin("base", sprintf("run('%s')", escapeForEval(fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m"))));
oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(modelRoot);

load_system(modelFile);
modelCleanup = onCleanup(@() close_system(modelName, 0));

updateStatus = "FAIL";
updateMessage = "";
try
    set_param(modelName, "SimulationCommand", "update");
    updateStatus = "PASS";
    fprintf("UPDATE_DIAGRAM_OK\n");
catch ME
    updateMessage = string(ME.message);
    fprintf("UPDATE_DIAGRAM_FAIL: %s\n", updateMessage);
end

cases = [
    struct("name", "short_50us", "stopTime", 50e-6, "steadyStart", 0, "maxStep", "5e-9")
    struct("name", "steady_0p5ms", "stopTime", 0.5e-3, "steadyStart", 0.42e-3, "maxStep", "5e-9")
    ];

rows = table();
steadyOut = [];
for idx = 1:numel(cases)
    spec = cases(idx);
    try
        fprintf("Running %s StopTime=%g\n", spec.name, spec.stopTime);
        [metrics, simOut] = runCase(modelName, spec);
        rows = [rows; rowFromMetrics(spec, true, "", metrics)]; %#ok<AGROW>
        if spec.name == "steady_0p5ms"
            steadyOut = simOut;
        end
    catch ME
        fprintf("CASE_FAIL %s: %s\n", spec.name, ME.message);
        rows = [rows; failureRow(spec, ME.message)]; %#ok<AGROW>
    end
end

summaryCsv = fullfile(resultsRoot, "ideal_iqcot_validation_summary.csv");
writetable(rows, summaryCsv);

auditCsv = fullfile(dataRoot, "ideal_iqcot_timeseries.csv");
if ~isempty(steadyOut)
    exportAuditTimeseries(steadyOut.logsout, auditCsv);
end

reportPath = fullfile(docsRoot, "ideal_digital_iqcot_simulink_build_report.md");
writeBuildReport(reportPath, modelFile, updateStatus, updateMessage, rows, summaryCsv, auditCsv);

fprintf("IDEAL_IQCOT_VALIDATION_SUMMARY=%s\n", summaryCsv);
fprintf("IDEAL_IQCOT_AUDIT_TIMESERIES=%s\n", auditCsv);
fprintf("IDEAL_IQCOT_BUILD_REPORT=%s\n", reportPath);
results = rows;
end

function [metrics, simOut] = runCase(modelName, spec)
in = Simulink.SimulationInput(modelName);
in = in.setModelParameter( ...
    "StopTime", num2str(spec.stopTime, "%.15g"), ...
    "MaxStep", char(spec.maxStep), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", 5e-9);
in = in.setVariable("Kiqcot", 0);
in = in.setVariable("Iqcot_enable", 1);
simOut = sim(in);
logs = simOut.logsout;
metrics = collectMetrics(logs, spec);
end

function metrics = collectMetrics(logs, spec)
steadyStart = spec.steadyStart;
metrics = struct();

trTimes = risingEdgeTimes(logs, "tr", 0);
reqTimes = risingEdgeTimes(logs, "REQ_iqcot", 0);
metrics.tr_count = numel(trTimes);
metrics.req_count = numel(reqTimes);
metrics.req_high_fraction = highFraction(logs, "REQ_iqcot", 0);
metrics.phase_coverage_count = phaseCoverageCount(logs, "phase_idx", 0);
metrics.a_reset_fraction = resetFraction(logs, trTimes);

for phase = 1:4
    qhTimes = risingEdgeTimes(logs, "QH" + phase, steadyStart);
    metrics.qh_count(phase) = numel(qhTimes); %#ok<AGROW>
    metrics.qh_freq_Hz(phase) = edgeFrequency(qhTimes); %#ok<AGROW>
    il = signalValues(logs, "IL" + phase, steadyStart);
    metrics.il_mean_A(phase) = meanOrNaN(il); %#ok<AGROW>
end

vout = signalValues(logs, "Vout", steadyStart);
metrics.vout_mean_V = meanOrNaN(vout);
metrics.vout_ripple_pp_mV = 1e3 * rangeOrNaN(vout);
metrics.il_phase_imbalance_A = max(metrics.il_mean_A) - min(metrics.il_mean_A);
metrics.qh_frequency_mean_Hz = mean(metrics.qh_freq_Hz, "omitnan");
metrics.qh_frequency_spread_Hz = max(metrics.qh_freq_Hz) - min(metrics.qh_freq_Hz);
metrics.tr_period_mean_ns = periodMeanNs(trTimes, steadyStart);
metrics.tr_period_jitter_ns = periodStdNs(trTimes, steadyStart);

metrics.pass_short = metrics.tr_count >= 20 && metrics.phase_coverage_count == 4 && ...
    metrics.req_high_fraction < 0.95 && all(metrics.qh_count > 0);
metrics.pass_steady = abs(metrics.vout_mean_V - 1.0) <= 30e-3 && ...
    all(metrics.qh_count > 0) && metrics.req_high_fraction < 0.95;
end

function row = rowFromMetrics(spec, success, message, m)
row = table( ...
    string(spec.name), success, string(message), ...
    m.tr_count, m.req_count, m.req_high_fraction, m.phase_coverage_count, ...
    m.a_reset_fraction, m.vout_mean_V, m.vout_ripple_pp_mV, ...
    m.il_mean_A(1), m.il_mean_A(2), m.il_mean_A(3), m.il_mean_A(4), ...
    m.il_phase_imbalance_A, m.qh_frequency_mean_Hz, m.qh_frequency_spread_Hz, ...
    m.tr_period_mean_ns, m.tr_period_jitter_ns, m.pass_short, m.pass_steady, ...
    'VariableNames', { ...
    'case','success','error_message','tr_count','req_count','req_high_fraction', ...
    'phase_coverage_count','a_reset_fraction','vout_mean_V','vout_ripple_pp_mV', ...
    'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A','il_phase_imbalance_A', ...
    'qh_frequency_mean_Hz','qh_frequency_spread_Hz','tr_period_mean_ns', ...
    'tr_period_jitter_ns','pass_short','pass_steady'});
end

function row = failureRow(spec, message)
row = table( ...
    string(spec.name), false, string(message), ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, false, false, ...
    'VariableNames', { ...
    'case','success','error_message','tr_count','req_count','req_high_fraction', ...
    'phase_coverage_count','a_reset_fraction','vout_mean_V','vout_ripple_pp_mV', ...
    'il1_mean_A','il2_mean_A','il3_mean_A','il4_mean_A','il_phase_imbalance_A', ...
    'qh_frequency_mean_Hz','qh_frequency_spread_Hz','tr_period_mean_ns', ...
    'tr_period_jitter_ns','pass_short','pass_steady'});
end

function exportAuditTimeseries(logs, csvPath)
names = ["tr", "REQ_iqcot", "A_iqcot", "Lambda_i", "h_iqcot", "phase_idx", "IL_sel", "vc_ctrl", "Vout"];
timeGrid = [];
series = struct();
for idx = 1:numel(names)
    [t, v] = signalSeries(logs, names(idx));
    series.(names(idx)) = struct("t", t, "v", v);
    timeGrid = [timeGrid; t(:)]; %#ok<AGROW>
end
timeGrid = unique(timeGrid);
maxRows = 250000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end

out = table(timeGrid, 'VariableNames', {'time_s'});
for idx = 1:numel(names)
    s = series.(names(idx));
    out.(names(idx)) = interpPrevious(s.t, s.v, timeGrid);
end
writetable(out, csvPath);
end

function writeBuildReport(reportPath, modelFile, updateStatus, updateMessage, rows, summaryCsv, auditCsv)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Ideal Digital IQCOT Simulink Build Report\n\n");
fprintf(fid, "Generated: 2026-06-28\n\n");
fprintf(fid, "## Paths\n\n");
fprintf(fid, "- Source model: `E:/Desktop/codex/output/simulink_iek/four_phase_iek_area.slx`\n");
fprintf(fid, "- New model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Validation summary: `%s`\n", slashPath(summaryCsv));
fprintf(fid, "- Event-audit timeseries: `%s`\n\n", slashPath(auditCsv));

fprintf(fid, "## Preserved Power Stage\n\n");
fprintf(fid, "The derived model is copied non-destructively from the IEK-area model. The four-phase synchronous Buck power stage, `PhaseScheduler_4Phase`, global blanking chain, COT cells, gate drivers, and `IQCOT_Ton_Adapter` are preserved. `Kiqcot` is held at 0 for first-stage validation.\n\n");

fprintf(fid, "## Replaced Control Block\n\n");
fprintf(fid, "`IEK_Area_Request` was replaced by `Ideal_Digital_IQCOT_Request`. The new request block uses sampled `e_v`, `IL1..IL4`, scheduler `phase_idx`, and accepted trigger reset `tr_reset`.\n\n");

fprintf(fid, "## IQCOT Equation\n\n");
fprintf(fid, "```text\n");
fprintf(fid, "vc_ctrl = Vc_bias_iqcot + Kvc_iqcot * e_v\n");
fprintf(fid, "IL_sel  = IL(phase_idx)\n");
fprintf(fid, "h_iqcot = vc_ctrl - Ri_iqcot * exp(kappa_cmd) * IL_sel\n");
fprintf(fid, "Lambda_i = Lambda0_iqcot * (1 + rho_cmd) + Lambda_m2 * cos(pi * phase_idx)\n");
fprintf(fid, "A_update = max(A_lower, A_prev + Ts_ctrl * h_iqcot)\n");
fprintf(fid, "REQ_iqcot = A_update >= Lambda_i\n");
fprintf(fid, "A_state resets on accepted tr_reset rising edge or accepted scheduler phase_idx transition\n");
fprintf(fid, "```\n\n");

fprintf(fid, "## Digital Timing\n\n");
fprintf(fid, "All controller inputs are sampled with ZOH blocks at `Ts_ctrl=40 ns`. `phase_idx` and `tr_reset` pass through Memory blocks before sampling to avoid the trigger-scheduler algebraic loop. Because the accepted `tr` pulse is about a few ns wide, the controller treats the persistent scheduler `phase_idx` transition as an equivalent accepted-event reset in addition to sampled `tr_reset`. The logged `A_iqcot` is the pre-reset area update at the current sample; state reset is applied after detecting accepted `tr_reset` or accepted phase transition.\n\n");

fprintf(fid, "## Parameter Table\n\n");
fprintf(fid, "| Parameter | Value | Reason |\n");
fprintf(fid, "|---|---:|---|\n");
fprintf(fid, "| `Ts_ctrl` | `40e-9` | digital controller sample time |\n");
fprintf(fid, "| `CT_iqcot` | `15e-12` | tuned so `Lambda0_iqcot=3e-10 V*s` |\n");
fprintf(fid, "| `VTH_iqcot` | `20e-3` | IQCOT threshold seed |\n");
fprintf(fid, "| `gm_iqcot` | `1e-3` | transconductance seed |\n");
fprintf(fid, "| `Lambda0_iqcot` | `3e-10` | matches validated IEK area event scale |\n");
fprintf(fid, "| `Ri_iqcot` | `0.5e-3` | current injection gain |\n");
fprintf(fid, "| `Vc_bias_iqcot` | `5.6e-3` | makes steady-state kernel slightly positive |\n");
fprintf(fid, "| `Lambda_m2` | `0` | first validation without differential threshold |\n");
fprintf(fid, "| `Kiqcot` | `0` | Ton adapter neutral during first validation |\n\n");

fprintf(fid, "## Signal Logging\n\n");
fprintf(fid, "Logged signals include `Vout`, `e_v`, `vc_ctrl`, `IL1..IL4`, `IL_sel`, `h_iqcot`, `A_iqcot`, `Lambda_i`, `REQ_iqcot`, `tr`, `tr_reset`, `phase_idx`, `tr1..tr4`, `QH1..QH4`, `QL1..QL4`, `SW1..SW4`, and `Ton_iqcot1..4` where available in the copied model.\n\n");

fprintf(fid, "## Update Diagram\n\n");
if updateStatus == "PASS"
    fprintf(fid, "`UPDATE_DIAGRAM_OK`\n\n");
else
    fprintf(fid, "`UPDATE_DIAGRAM_FAIL`: %s\n\n", updateMessage);
end

fprintf(fid, "## Validation Results\n\n");
fprintf(fid, "| case | success | tr_count | phase coverage | req high frac | Vout mean | ripple mVpp | QH mean Hz | pass short | pass steady |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for idx = 1:height(rows)
    fprintf(fid, "| `%s` | %d | %.0f | %.0f | %.3g | %.6g | %.6g | %.6g | %d | %d |\n", ...
        rows.case(idx), rows.success(idx), rows.tr_count(idx), rows.phase_coverage_count(idx), ...
        rows.req_high_fraction(idx), rows.vout_mean_V(idx), rows.vout_ripple_pp_mV(idx), ...
        rows.qh_frequency_mean_Hz(idx), rows.pass_short(idx), rows.pass_steady(idx));
end
fprintf(fid, "\n");

fprintf(fid, "## Event Audit\n\n");
fprintf(fid, "Run `python output/iqcot_ideal_digital_iqcot_event_audit.py` after validation to generate the detailed sampled-event audit. The expected relation is `A_iqcot >= Lambda_i` at accepted trigger events, with one `Ts_ctrl` worth of quantization/overshoot allowance.\n\n");

fprintf(fid, "## Boundaries\n\n");
fprintf(fid, "This is a derived Simulink switching model only. It does not claim hardware/HIL validation, optimal performance, AI supervision, PR-ECB cut-load protection, or final production controller timing. The first-stage claim is limited to a sampled IQCOT event kernel driving the existing four-phase Buck chain.\n");
end

function [time, values] = signalSeries(logs, name)
sig = logs.get(char(name));
if isempty(sig)
    error("Missing logged signal: %s", name);
end
time = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
end

function values = signalValues(logs, name, startTime)
[time, values] = signalSeries(logs, name);
values = values(time >= startTime);
end

function times = risingEdgeTimes(logs, name, startTime)
[time, values] = signalSeries(logs, name);
mask = time >= startTime;
time = time(mask);
values = values(mask);
if numel(values) < 2
    times = [];
else
    times = time(find(diff(values > 0.5) > 0) + 1);
end
end

function f = highFraction(logs, name, startTime)
values = signalValues(logs, name, startTime);
if isempty(values)
    f = NaN;
else
    f = mean(values > 0.5);
end
end

function count = phaseCoverageCount(logs, name, startTime)
values = signalValues(logs, name, startTime);
if isempty(values)
    count = 0;
else
    phases = unique(mod(round(values), 4));
    count = numel(phases);
end
end

function frac = resetFraction(logs, trTimes)
if isempty(trTimes)
    frac = NaN;
    return;
end
[aTime, aValues] = signalSeries(logs, "A_iqcot");
[lTime, lValues] = signalSeries(logs, "Lambda_i");
hits = false(numel(trTimes), 1);
for idx = 1:numel(trTimes)
    after = find(aTime > trTimes(idx) + 1e-12, 1, "first");
    beforeLambda = interpPrevious(lTime, lValues, trTimes(idx));
    if ~isempty(after)
        hits(idx) = aValues(after) <= max(0.1 * beforeLambda, 1e-12);
    end
end
frac = mean(hits);
end

function frequency = edgeFrequency(times)
if numel(times) < 2
    frequency = 0;
else
    frequency = (numel(times) - 1) / (times(end) - times(1));
end
end

function m = meanOrNaN(values)
if isempty(values)
    m = NaN;
else
    m = mean(values);
end
end

function r = rangeOrNaN(values)
if isempty(values)
    r = NaN;
else
    r = max(values) - min(values);
end
end

function ns = periodMeanNs(times, startTime)
times = times(times >= startTime);
if numel(times) < 2
    ns = NaN;
else
    ns = 1e9 * mean(diff(times));
end
end

function ns = periodStdNs(times, startTime)
times = times(times >= startTime);
if numel(times) < 3
    ns = NaN;
else
    ns = 1e9 * std(diff(times));
end
end

function values = interpPrevious(time, data, queryTime)
if isempty(time)
    values = NaN(size(queryTime));
elseif numel(time) == 1
    values = repmat(data(1), size(queryTime));
else
    values = interp1(time, data, queryTime, "previous", "extrap");
end
end

function ensureDir(pathValue)
if ~exist(pathValue, "dir")
    mkdir(pathValue);
end
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end

function out = slashPath(pathValue)
out = strrep(char(pathValue), "\", "/");
end
