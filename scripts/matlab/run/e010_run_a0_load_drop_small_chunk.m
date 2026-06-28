function rows = e010_run_a0_load_drop_small_chunk(variant, baseLoadA, targetLoadA)
%E010_RUN_A0_LOAD_DROP_SMALL_CHUNK Run the first E010 40A->10A case.

if nargin < 1
    variant = "A0";
end
if nargin < 2
    baseLoadA = 40;
end
if nargin < 3
    targetLoadA = 10;
end
variant = string(variant);
caseTag = loadCaseTag(baseLoadA, targetLoadA);
deltaLoadDropA = baseLoadA - targetLoadA;

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

modelFile = e010_build_load_drop_observable_model(variant);
[~, modelName] = fileparts(modelFile);
load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

experimentRoot = fullfile(projectRoot, "experiments", "E010_load_drop_overshoot");
ensureDir(experimentRoot);

spec = struct();
if variant == "A0"
    spec.variant = "A0_original_ideal_iqcot_observable";
    spec.file_prefix = "e010_a0_" + caseTag;
    spec.report_title = "E010 A0 Load-Drop Small Chunk";
    spec.classification = "MODEL_CONFIRMED";
    spec.classification_detail = "the derived A0 model ran and produced the required first-pass E010 metrics. This confirms measurability of the baseline branch, not improvement.";
elseif variant == "A1"
    spec.variant = "A1_ton_trunc_only";
    spec.file_prefix = "e010_a1_" + caseTag;
    spec.report_title = "E010 A1 Ton-Truncation Small Chunk";
    spec.classification = "MODEL_CONFIRMED";
    spec.classification_detail = "the derived A1 model ran and produced first-pass Ton-truncation metrics. The result must be compared against A0 before claiming improvement.";
    spec.Tton_trunc_min = 80e-9;
    spec.Tton_trunc_window = 2e-6;
    spec.E010_TonTrunc_Enable = 1;
elseif variant == "A2"
    spec.variant = "A2_ton_trunc_pulse_inhibit";
    spec.file_prefix = "e010_a2_" + caseTag;
    spec.report_title = "E010 A2 Ton-Truncation Plus Pulse-Inhibit Small Chunk";
    spec.classification = "MODEL_CONFIRMED";
    spec.classification_detail = "the derived A2 model ran and produced first-pass Ton-truncation plus pulse-inhibit metrics. The result must be compared against A0/A1 before claiming improvement.";
    spec.Tton_trunc_min = 80e-9;
    spec.Tton_trunc_window = 2e-6;
    spec.E010_TonTrunc_Enable = 1;
    spec.E010_PulseInhibit_Enable = 1;
    spec.E010_PulseInhibit_Count = 1;
    spec.E010_PulseInhibit_Time = 1.8e-6;
    spec.E010_ReentryGuard_Enable = 0;
    spec.E010_Reentry_Band_Down = 0;
elseif variant == "A3"
    spec.variant = "A3_guarded_reentry";
    spec.file_prefix = "e010_a3_" + caseTag;
    spec.report_title = "E010 A3 Guarded-Reentry Small Chunk";
    spec.classification = "MODEL_CONFIRMED";
    spec.classification_detail = "the derived A3 model ran and produced first-pass guarded-reentry metrics. The result must be compared against A0/A1/A2 before claiming improvement.";
    spec.Tton_trunc_min = 80e-9;
    spec.Tton_trunc_window = 2e-6;
    spec.E010_TonTrunc_Enable = 1;
    spec.E010_PulseInhibit_Enable = 1;
    spec.E010_PulseInhibit_Count = 1;
    spec.E010_PulseInhibit_Time = 1.8e-6;
    spec.E010_ReentryGuard_Enable = 1;
    spec.E010_Reentry_Band_Down = 1.2e-3;
elseif variant == "A4"
    spec.variant = "A4_ai_table_selected_aO";
    spec.file_prefix = "e010_a4_" + caseTag;
    spec.report_title = "E010 A4 AI/Table-Selected a_O Small Chunk";
    spec.classification = "MODEL_CONFIRMED";
    spec.classification_detail = "the derived A4 model ran the table-selected load-drop a_O token under a 1 mV undershoot safety constraint and load-drop magnitude selector.";
    if deltaLoadDropA <= 20
        spec.A4_selected_policy = "noop_for_mild_load_drop";
        spec.Tton_trunc_min = 0;
        spec.Tton_trunc_window = 0;
        spec.E010_TonTrunc_Enable = 0;
        spec.E010_PulseInhibit_Enable = 0;
        spec.E010_PulseInhibit_Count = 0;
        spec.E010_PulseInhibit_Time = 0;
        spec.E010_ReentryGuard_Enable = 0;
        spec.E010_Reentry_Band_Down = 0;
    else
        spec.A4_selected_policy = "aggressive_drop_protection_under_1mV_budget";
        spec.Tton_trunc_min = 80e-9;
        spec.Tton_trunc_window = 2e-6;
        spec.E010_TonTrunc_Enable = 1;
        spec.E010_PulseInhibit_Enable = 1;
        spec.E010_PulseInhibit_Count = 1;
        spec.E010_PulseInhibit_Time = 1.8e-6;
        spec.E010_ReentryGuard_Enable = 1;
        spec.E010_Reentry_Band_Down = 1.0e-3;
    end
else
    error("Unknown E010 variant: %s", variant);
end
spec.base_load_A = baseLoadA;
spec.target_load_A = targetLoadA;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.54e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;

metricsCsv = fullfile(experimentRoot, spec.file_prefix + "_metrics.csv");
waveCsv = fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv");
reportPath = fullfile(experimentRoot, spec.file_prefix + "_report.md");

try
    out = runCase(modelName, spec);
    logs = out.logsout;
    metrics = collectMetrics(logs, spec);
    rows = rowFromMetrics(spec, metrics, true, "");
    writetable(rows, metricsCsv);
    exportWaveSample(logs, spec, waveCsv);
    writeReport(reportPath, modelFile, spec, rows, metricsCsv, waveCsv);
catch ME
    details = errorDetails(ME);
    rows = failureRow(spec, details);
    writetable(rows, metricsCsv);
    writeFailureReport(reportPath, modelFile, spec, metricsCsv, details);
end

fprintf("E010_%s_METRICS=%s\n", variant, metricsCsv);
fprintf("E010_%s_WAVE_SAMPLE=%s\n", variant, waveCsv);
fprintf("E010_%s_REPORT=%s\n", variant, reportPath);
disp(rows);
end

function out = runCase(modelName, spec)
in = Simulink.SimulationInput(modelName);
in = in.setModelParameter( ...
    "StopTime", num2str(spec.stop_time, "%.15g"), ...
    "MaxStep", char(spec.max_step), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", 5e-9);
in = in.setVariable("Kiqcot", 0);
in = in.setVariable("Iqcot_enable", 1);
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.target_load_A);
in = in.setVariable("t_load_step", spec.t_load_step);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.base_load_A / 4);
if isfield(spec, "E010_TonTrunc_Enable")
    in = in.setVariable("E010_TonTrunc_Enable", spec.E010_TonTrunc_Enable);
    in = in.setVariable("Tton_trunc_min", spec.Tton_trunc_min);
    in = in.setVariable("Tton_trunc_window", spec.Tton_trunc_window);
else
    in = in.setVariable("E010_TonTrunc_Enable", 0);
    in = in.setVariable("Tton_trunc_min", 0);
    in = in.setVariable("Tton_trunc_window", 0);
end
if isfield(spec, "E010_PulseInhibit_Enable")
    in = in.setVariable("E010_PulseInhibit_Enable", spec.E010_PulseInhibit_Enable);
    in = in.setVariable("E010_PulseInhibit_Count", spec.E010_PulseInhibit_Count);
    in = in.setVariable("E010_PulseInhibit_Time", spec.E010_PulseInhibit_Time);
    in = in.setVariable("E010_ReentryGuard_Enable", spec.E010_ReentryGuard_Enable);
    in = in.setVariable("E010_Reentry_Band_Down", spec.E010_Reentry_Band_Down);
else
    in = in.setVariable("E010_PulseInhibit_Enable", 0);
    in = in.setVariable("E010_PulseInhibit_Count", 0);
    in = in.setVariable("E010_PulseInhibit_Time", 0);
    in = in.setVariable("E010_ReentryGuard_Enable", 0);
    in = in.setVariable("E010_Reentry_Band_Down", 0);
end
in = in.setVariable("E010_Vref", spec.vref);
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
[t, vout] = signalSeries(logs, "Vout");
tau = t - spec.t_load_step;
post = tau >= 0;
tauPost = tau(post);
vPost = vout(post);
metrics = struct();
metrics.peak_overshoot_mV = 1e3 * max(vPost - spec.vref);
metrics.early_local_peak_0_2us_mV = 1e3 * maxWindow(tauPost, vPost - spec.vref, 0, 2e-6);
metrics.recovery_peak_2_12us_mV = 1e3 * maxWindow(tauPost, vPost - spec.vref, 2e-6, 12e-6);
metrics.late_settling_12_80us_abs_mV = 1e3 * max(abs(windowValues(tauPost, vPost - spec.vref, 12e-6, 80e-6)));
metrics.undershoot_penalty_mV = 1e3 * max(max(spec.vref - vPost), 0);
metrics.final_error_mV = 1e3 * meanWindow(tauPost, vPost - spec.vref, 75e-6, 90e-6);
metrics.reentry_time_us = NaN;
metrics.skip_count_est = estimateSkipCount(logs, spec);
metrics.phase_current_peak_A = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time);
metrics.ton_actual_peak_ns = maxTonActualNs(logs, spec.t_load_step);
metrics.ton_cmd_trunc_peak_ns = maxOptionalSignalNs(logs, "Ton_cmd_trunc", spec.t_load_step);
metrics.ton_trunc_active_fraction = activeFraction(logs, "ton_trunc_active", spec.t_load_step, spec.t_load_step + 5e-6);
metrics.pulse_inhibit_active_fraction = activeFraction(logs, "pulse_inhibit_active", spec.t_load_step, spec.t_load_step + 5e-6);
metrics.pulse_inhibit_event_est = maxOptionalSignalValue(logs, "pulse_inhibit_count", spec.t_load_step);
end

function value = maxWindow(t, y, startTime, endTime)
vals = windowValues(t, y, startTime, endTime);
if isempty(vals)
    value = NaN;
else
    value = max(vals);
end
end

function value = meanWindow(t, y, startTime, endTime)
vals = windowValues(t, y, startTime, endTime);
if isempty(vals)
    value = NaN;
else
    value = mean(vals);
end
end

function vals = windowValues(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
vals = y(mask);
end

function skipCount = estimateSkipCount(logs, spec)
edges = [];
for phase = 1:4
    edges = [edges; risingEdges(logs, "QH" + phase)]; %#ok<AGROW>
end
edges = sort(edges);
preEdges = edges(edges >= spec.t_load_step - 40e-6 & edges < spec.t_load_step);
postEdges = edges(edges >= spec.t_load_step & edges <= spec.t_load_step + 12e-6);
if numel(preEdges) < 3 || numel(postEdges) < 2
    skipCount = NaN;
    return;
end
preGap = median(diff(preEdges));
maxPostGap = max(diff(postEdges));
skipCount = max(0, round(maxPostGap / preGap) - 1);
end

function peak = maxPhaseCurrent(logs, startTime, endTime)
peak = -inf;
for phase = 1:4
    [t, values] = signalSeries(logs, "IL" + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        peak = max(peak, max(values(mask)));
    end
end
if isinf(peak)
    peak = NaN;
end
end

function peakNs = maxTonActualNs(logs, startTime)
peak = -inf;
for phase = 1:4
    name = "Ton_actual" + phase;
    sig = logs.get(char(name));
    if isempty(sig)
        continue;
    end
    t = sig.Values.Time(:);
    values = squeeze(double(sig.Values.Data));
    values = values(:);
    mask = t >= startTime;
    if any(mask)
        peak = max(peak, max(values(mask)));
    end
end
if isinf(peak)
    peakNs = NaN;
else
    peakNs = 1e9 * peak;
end
end

function row = rowFromMetrics(spec, m, success, errorMessage)
row = table( ...
    success, string(errorMessage), string(spec.variant), spec.base_load_A, spec.target_load_A, ...
    m.peak_overshoot_mV, m.early_local_peak_0_2us_mV, ...
    m.recovery_peak_2_12us_mV, m.late_settling_12_80us_abs_mV, ...
    m.undershoot_penalty_mV, m.reentry_time_us, m.skip_count_est, ...
    m.final_error_mV, m.phase_current_peak_A, m.ton_actual_peak_ns, ...
    m.ton_cmd_trunc_peak_ns, m.ton_trunc_active_fraction, ...
    m.pulse_inhibit_active_fraction, m.pulse_inhibit_event_est, ...
    'VariableNames', {'success','error_message','variant','base_load_A','target_load_A', ...
    'peak_overshoot_mV','early_local_peak_0_2us_mV', ...
    'recovery_peak_2_12us_mV','late_settling_12_80us_abs_mV', ...
    'undershoot_penalty_mV','reentry_time_us','skip_count_est', ...
    'final_error_mV','phase_current_peak_A','ton_actual_peak_ns', ...
    'ton_cmd_trunc_peak_ns','ton_trunc_active_fraction', ...
    'pulse_inhibit_active_fraction','pulse_inhibit_event_est'});
end

function row = failureRow(spec, errorMessage)
emptyMetrics = struct( ...
    "peak_overshoot_mV", NaN, ...
    "early_local_peak_0_2us_mV", NaN, ...
    "recovery_peak_2_12us_mV", NaN, ...
    "late_settling_12_80us_abs_mV", NaN, ...
    "undershoot_penalty_mV", NaN, ...
    "reentry_time_us", NaN, ...
    "skip_count_est", NaN, ...
    "final_error_mV", NaN, ...
    "phase_current_peak_A", NaN, ...
    "ton_actual_peak_ns", NaN, ...
    "ton_cmd_trunc_peak_ns", NaN, ...
    "ton_trunc_active_fraction", NaN, ...
    "pulse_inhibit_active_fraction", NaN, ...
    "pulse_inhibit_event_est", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage);
end

function exportWaveSample(logs, spec, csvPath)
[t, vout] = signalSeries(logs, "Vout");
[ti, iload] = signalSeries(logs, "Iload");
timeGrid = unique([t(:); ti(:)]);
maxRows = 20000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
out = table(1e6 * (timeGrid - spec.t_load_step), ...
    interp1(t, vout, timeGrid, "linear", "extrap"), ...
    interp1(ti, iload, timeGrid, "previous", "extrap"), ...
    'VariableNames', {'time_after_step_us', 'Vout', 'Iload'});
for phase = 1:4
    [tp, il] = signalSeries(logs, "IL" + phase);
    out.("IL" + phase) = interp1(tp, il, timeGrid, "linear", "extrap");
end
writetable(out, csvPath);
end

function writeReport(reportPath, modelFile, spec, rows, metricsCsv, waveCsv)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-28\n\n");
fprintf(fid, "## Hypothesis\n\n");
if string(spec.variant) == "A1_ton_trunc_only"
    fprintf(fid, "A1 tests whether Ton truncation alone reduces load-drop overshoot for an external `%.6gA -> %.6gA` load-current disturbance. The load current remains an external test profile, not an AI command.\n\n", spec.base_load_A, spec.target_load_A);
    fprintf(fid, "Ton truncation parameters:\n\n");
    fprintf(fid, "```text\n");
    fprintf(fid, "Tton_trunc_min = %.6g ns\n", 1e9 * spec.Tton_trunc_min);
    fprintf(fid, "Tton_trunc_window = %.6g us\n", 1e6 * spec.Tton_trunc_window);
    fprintf(fid, "```\n\n");
elseif string(spec.variant) == "A2_ton_trunc_pulse_inhibit"
    fprintf(fid, "A2 tests whether deterministic Ton truncation plus early event-domain pulse inhibit reduces load-drop overshoot for an external `%.6gA -> %.6gA` load-current disturbance. The inhibit block applies a short combinational time-window gate to scheduled COT triggers only; it does not command QH/QL gates or the load current.\n\n", spec.base_load_A, spec.target_load_A);
    fprintf(fid, "Action-token parameters:\n\n");
    fprintf(fid, "```text\n");
    fprintf(fid, "Tton_trunc_min = %.6g ns\n", 1e9 * spec.Tton_trunc_min);
    fprintf(fid, "Tton_trunc_window = %.6g us\n", 1e6 * spec.Tton_trunc_window);
    fprintf(fid, "pulse_inhibit_count_guard = %.6g\n", spec.E010_PulseInhibit_Count);
    fprintf(fid, "inhibit_time = %.6g us\n", 1e6 * spec.E010_PulseInhibit_Time);
    fprintf(fid, "```\n\n");
elseif string(spec.variant) == "A3_guarded_reentry"
    fprintf(fid, "A3 tests the same Ton truncation and early event-domain pulse inhibit as A2, but applies a model-based reentry projection for an external `%.6gA -> %.6gA` disturbance: inhibit is allowed only while `Vout >= Vref + reentry_band_down`. The load current remains an external disturbance.\n\n", spec.base_load_A, spec.target_load_A);
    fprintf(fid, "Action-token and projection parameters:\n\n");
    fprintf(fid, "```text\n");
    fprintf(fid, "Tton_trunc_min = %.6g ns\n", 1e9 * spec.Tton_trunc_min);
    fprintf(fid, "Tton_trunc_window = %.6g us\n", 1e6 * spec.Tton_trunc_window);
    fprintf(fid, "pulse_inhibit_count_guard = %.6g\n", spec.E010_PulseInhibit_Count);
    fprintf(fid, "inhibit_time = %.6g us\n", 1e6 * spec.E010_PulseInhibit_Time);
    fprintf(fid, "reentry_band_down = %.6g mV\n", 1e3 * spec.E010_Reentry_Band_Down);
    fprintf(fid, "```\n\n");
elseif string(spec.variant) == "A4_ai_table_selected_aO"
    fprintf(fid, "A4 tests the table-selected load-drop `a_O` token under a simple safety projection for an external `%.6gA -> %.6gA` disturbance. The selection rule is: choose no-op for mild load drops, otherwise accept only candidates with projected undershoot penalty at or below `1 mV`, then minimize recovery peak and late settling. The load-current step remains an external disturbance.\n\n", spec.base_load_A, spec.target_load_A);
    fprintf(fid, "Selected `a_O` parameters:\n\n");
    fprintf(fid, "```text\n");
    fprintf(fid, "protect_level_down = %s\n", spec.A4_selected_policy);
    fprintf(fid, "active_HS_trunc_enable = %.6g\n", spec.E010_TonTrunc_Enable);
    fprintf(fid, "Tton_trunc_min = %.6g ns\n", 1e9 * spec.Tton_trunc_min);
    fprintf(fid, "Tton_trunc_window = %.6g us\n", 1e6 * spec.Tton_trunc_window);
    fprintf(fid, "pulse_inhibit_count_guard = %.6g\n", spec.E010_PulseInhibit_Count);
    fprintf(fid, "inhibit_time = %.6g us\n", 1e6 * spec.E010_PulseInhibit_Time);
    fprintf(fid, "reentry_band_down = %.6g mV\n", 1e3 * spec.E010_Reentry_Band_Down);
    fprintf(fid, "```\n\n");
else
    fprintf(fid, "A0 measures the original ideal IQCOT response to an external `%.6gA -> %.6gA` load-current disturbance. No AI/table action is applied, and the load current is not an AI command.\n\n", spec.base_load_A, spec.target_load_A);
end
fprintf(fid, "## Paths\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Metrics CSV: `%s`\n", slashPath(metricsCsv));
fprintf(fid, "- Wave sample CSV: `%s`\n\n", slashPath(waveCsv));
fprintf(fid, "## Observability\n\n");
if string(spec.variant) == "A1_ton_trunc_only"
    fprintf(fid, "The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, and `Ton_cmd_trunc1..4` logging. A1 inserts only a deterministic Ton-truncation block between the IQCOT Ton adapter and each COT cell; no AI/table action and no load-current command are applied.\n\n");
elseif string(spec.variant) == "A2_ton_trunc_pulse_inhibit"
    fprintf(fid, "The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and pulse-inhibit logging. A2 inserts deterministic supervisory event logic before COT cell requests and Ton truncation before COT Ton inputs; no gate command or load-current command is directly controlled.\n\n");
elseif string(spec.variant) == "A3_guarded_reentry"
    fprintf(fid, "The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and guarded pulse-inhibit logging. A3 inserts deterministic supervisory event logic plus a voltage reentry guard before COT cell requests; no gate command or load-current command is directly controlled.\n\n");
elseif string(spec.variant) == "A4_ai_table_selected_aO"
    fprintf(fid, "The derived model adds external `Iload`, fixed-four-phase `active_phase_set`, `Ton_actual1..4`, `Ton_cmd_trunc1..4`, and guarded pulse-inhibit logging. A4 applies a table-selected supervisory token after safety projection; no gate command or load-current command is directly controlled.\n\n");
else
    fprintf(fid, "The derived model adds observability only: external `Iload`, fixed-four-phase `active_phase_set`, and `Ton_actual1..4` pulse-width estimates. The baseline IQCOT request path is not protected, boosted, truncated, or AI scheduled in A0.\n\n");
end
fprintf(fid, "## Metrics\n\n");
fprintf(fid, "| Metric | Value |\n");
fprintf(fid, "|---|---:|\n");
fprintf(fid, "| peak overshoot mV | %.6g |\n", rows.peak_overshoot_mV(1));
fprintf(fid, "| early local peak 0-2us mV | %.6g |\n", rows.early_local_peak_0_2us_mV(1));
fprintf(fid, "| recovery peak 2-12us mV | %.6g |\n", rows.recovery_peak_2_12us_mV(1));
fprintf(fid, "| late settling 12-80us abs mV | %.6g |\n", rows.late_settling_12_80us_abs_mV(1));
fprintf(fid, "| undershoot penalty mV | %.6g |\n", rows.undershoot_penalty_mV(1));
fprintf(fid, "| skip count estimate | %.6g |\n", rows.skip_count_est(1));
fprintf(fid, "| final error mV | %.6g |\n", rows.final_error_mV(1));
fprintf(fid, "| phase current peak A | %.6g |\n", rows.phase_current_peak_A(1));
fprintf(fid, "| Ton actual peak ns | %.6g |\n", rows.ton_actual_peak_ns(1));
fprintf(fid, "| Ton trunc command peak ns | %.6g |\n", rows.ton_cmd_trunc_peak_ns(1));
fprintf(fid, "| Ton trunc active fraction | %.6g |\n", rows.ton_trunc_active_fraction(1));
fprintf(fid, "| pulse inhibit active fraction | %.6g |\n", rows.pulse_inhibit_active_fraction(1));
fprintf(fid, "| pulse inhibit event estimate | %.6g |\n\n", rows.pulse_inhibit_event_est(1));
fprintf(fid, "## Classification\n\n");
fprintf(fid, "`%s`: %s\n", spec.classification, spec.classification_detail);
end

function writeFailureReport(reportPath, modelFile, spec, metricsCsv, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-28\n\n");
fprintf(fid, "## Classification\n\n");
fprintf(fid, "`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "The derived model or run failed before interpretable E010 metrics were produced.\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Metrics CSV: `%s`\n", slashPath(metricsCsv));
fprintf(fid, "- Load profile: `%.6gA -> %.6gA`\n", spec.base_load_A, spec.target_load_A);
fprintf(fid, "- Error: `%s`\n", message);
end

function details = errorDetails(ME)
parts = strings(0, 1);
parts(end + 1) = string(ME.message);
try
    parts(end + 1) = string(getReport(ME, "extended", "hyperlinks", "off"));
catch
end
for idx = 1:numel(ME.cause)
    cause = ME.cause{idx};
    parts(end + 1) = "CAUSE " + idx + ": " + string(cause.message);
    try
        parts(end + 1) = string(getReport(cause, "extended", "hyperlinks", "off"));
    catch
    end
end
details = strjoin(parts, " | ");
end

function peakNs = maxOptionalSignalNs(logs, prefix, startTime)
peak = -inf;
for phase = 1:4
    sig = optionalSignal(logs, prefix + phase);
    if isempty(sig)
        continue;
    end
    t = sig.Values.Time(:);
    values = squeeze(double(sig.Values.Data));
    values = values(:);
    mask = t >= startTime;
    if any(mask)
        peak = max(peak, max(values(mask)));
    end
end
if isinf(peak)
    peakNs = NaN;
else
    peakNs = 1e9 * peak;
end
end

function peakValue = maxOptionalSignalValue(logs, prefix, startTime)
peakValue = -inf;
for phase = 1:4
    sig = optionalSignal(logs, prefix + phase);
    if isempty(sig)
        continue;
    end
    t = sig.Values.Time(:);
    values = squeeze(double(sig.Values.Data));
    values = values(:);
    mask = t >= startTime;
    if any(mask)
        peakValue = max(peakValue, max(values(mask)));
    end
end
if isinf(peakValue)
    peakValue = NaN;
end
end

function frac = activeFraction(logs, prefix, startTime, endTime)
vals = [];
for phase = 1:4
    sig = optionalSignal(logs, prefix + phase);
    if isempty(sig)
        continue;
    end
    t = sig.Values.Time(:);
    data = squeeze(double(sig.Values.Data));
    data = data(:);
    mask = t >= startTime & t <= endTime;
    vals = [vals; data(mask)]; %#ok<AGROW>
end
if isempty(vals)
    frac = NaN;
else
    frac = mean(vals > 0.5);
end
end

function edges = risingEdges(logs, name)
[time, values] = signalSeries(logs, name);
if numel(values) < 2
    edges = [];
else
    edges = time(find(diff(values > 0.5) > 0) + 1);
end
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

function sig = optionalSignal(logs, name)
sig = [];
try
    found = logs.find("Name", char(name));
    if ~isempty(found)
        sig = found(1);
    end
catch
    try
        evalc("sig = logs.get(char(name));");
    catch
        sig = [];
    end
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

function tag = loadCaseTag(baseLoadA, targetLoadA)
tag = sprintf("%gA_to_%gA", baseLoadA, targetLoadA);
tag = regexprep(tag, "[^0-9A-Za-z]+", "_");
end
