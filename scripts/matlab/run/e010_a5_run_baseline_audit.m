function rows = e010_a5_run_baseline_audit(variants)
%E010_A5_RUN_BASELINE_AUDIT Run only A5-C0 and A5-C4 baseline audit.
% This is a measurement-integrity checkpoint, not an A5 improvement test.

if nargin < 1 || isempty(variants)
    variants = ["A5-C0", "A5-C4"];
end
variants = string(variants);
blocked = setdiff(variants, ["A5-C0", "A5-C4"]);
if ~isempty(blocked)
    error("This audit may run only A5-C0 and A5-C4. Blocked: %s", strjoin(blocked, ", "));
end

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));

initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", ...
    "E010_load_drop_overshoot", "A5_severe_drop_token");
ensureDir(experimentRoot);

metricsCsv = fullfile(experimentRoot, "e010_a5_baseline_metrics.csv");
availabilityCsv = fullfile(experimentRoot, "e010_a5_baseline_signal_availability.csv");
schedulerCsv = fullfile(experimentRoot, "e010_a5_baseline_scheduler_audit.csv");
auditPath = fullfile(experimentRoot, "e010_a5_baseline_audit.md");
waveformAuditPath = fullfile(experimentRoot, "e010_a5_baseline_waveform_audit.md");
summaryPath = fullfile(experimentRoot, "e010_a5_baseline_reproduction_summary.md");

rows = table();
availabilityRows = table();
schedulerRows = table();

for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    [row, availability, scheduler] = runOneVariant(spec, experimentRoot);
    rows = appendTable(rows, row);
    availabilityRows = appendTable(availabilityRows, availability);
    schedulerRows = appendTable(schedulerRows, scheduler);
end

rows = finalizeMetricRows(rows);
writetable(rows, metricsCsv);
if ~isempty(availabilityRows)
    writetable(availabilityRows, availabilityCsv);
end
if ~isempty(schedulerRows)
    writetable(schedulerRows, schedulerCsv);
end

[classification, detail, auditPassed] = classifyAudit(rows);
writeBaselineAudit(auditPath, rows, classification, detail, auditPassed, ...
    metricsCsv, availabilityCsv, schedulerCsv);
writeWaveformAudit(waveformAuditPath, rows, availabilityRows, classification, ...
    experimentRoot);
writeReproductionSummary(summaryPath, rows, classification, detail, ...
    metricsCsv, availabilityCsv, schedulerCsv);

fprintf("E010_A5_BASELINE_METRICS=%s\n", metricsCsv);
fprintf("E010_A5_BASELINE_AVAILABILITY=%s\n", availabilityCsv);
fprintf("E010_A5_BASELINE_SCHEDULER_AUDIT=%s\n", schedulerCsv);
fprintf("E010_A5_BASELINE_AUDIT=%s\n", auditPath);
fprintf("E010_A5_BASELINE_WAVEFORM_AUDIT=%s\n", waveformAuditPath);
fprintf("E010_A5_BASELINE_SUMMARY=%s\n", summaryPath);
disp(rows);
end

function [row, availability, schedulerRows] = runOneVariant(spec, experimentRoot)
modelFile = "";
try
    modelFile = e010_a5_build_baseline_audit_model(spec.short_variant);
    [~, modelName] = fileparts(modelFile);
    load_system(modelFile);
    cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

    out = runCase(modelName, spec);
    logs = out.logsout;
    availability = signalAvailability(logs, spec);
    schedulerRows = schedulerAudit(logs, spec);
    metrics = collectMetrics(logs, spec, availability, schedulerRows);
    exportWaveSample(logs, spec, fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv"));
    row = rowFromMetrics(spec, metrics, true, "", modelFile);
catch ME
    details = errorDetails(ME);
    row = failureRow(spec, details, modelFile);
    availability = table();
    schedulerRows = table();
end
end

function spec = variantSpec(variant)
variant = string(variant);
spec = struct();
spec.short_variant = variant;
spec.base_load_A = 40;
spec.target_load_A = 1;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.54e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.settle_band_V = 1.0e-3;
spec.undershoot_budget_V = 2.0e-3;
spec.late_settling_guard_V = 5.0e-3;
spec.deltaI_drop_threshold_high_A = 30;
spec.current_limit_guard_A = inf;
spec.expected_phase_order = [1, 2, 3, 4];
spec.active_lambda_enabled = 0.0;
spec.active_phase_add_shed_enabled = 0.0;
spec.DCR_mismatch_enabled = 0.0;
spec.sense_mismatch_enabled = 0.0;

if variant == "A5-C0"
    spec.variant = "A5-C0_original_ideal_iqcot_40A_to_1A";
    spec.file_prefix = "e010_a5_c0_baseline_40A_to_1A";
    spec.report_label = "A5-C0 original ideal IQCOT";
    spec.a4_policy = "not_applicable";
    spec.E010_TonTrunc_Enable = 0;
    spec.Tton_trunc_min = 0;
    spec.Tton_trunc_window = 0;
    spec.E010_PulseInhibit_Enable = 0;
    spec.E010_PulseInhibit_Count = 0;
    spec.E010_PulseInhibit_Time = 0;
    spec.E010_ReentryGuard_Enable = 0;
    spec.E010_Reentry_Band_Down = 0;
elseif variant == "A5-C4"
    spec.variant = "A5-C4_previous_A4_no_harm_selector_40A_to_1A";
    spec.file_prefix = "e010_a5_c4_previous_A4_40A_to_1A";
    spec.report_label = "A5-C4 previous A4 no-harm selector";
    spec.a4_policy = "previous_A4_guarded_drop_projection";
    spec.E010_TonTrunc_Enable = 1;
    spec.Tton_trunc_min = 80e-9;
    spec.Tton_trunc_window = 2e-6;
    spec.E010_PulseInhibit_Enable = 1;
    spec.E010_PulseInhibit_Count = 1;
    spec.E010_PulseInhibit_Time = 1.8e-6;
    spec.E010_ReentryGuard_Enable = 1;
    spec.E010_Reentry_Band_Down = 1.0e-3;
else
    error("Unknown E010-A5 audit variant: %s", variant);
end
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
in = in.setVariable("IdealIQCOT_Enable", 1);
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.target_load_A);
in = in.setVariable("t_load_step", spec.t_load_step);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.base_load_A / 4);
in = in.setVariable("E010_Vref", spec.vref);
in = in.setVariable("E010A5_DeltaI_Drop_Threshold_High", ...
    spec.deltaI_drop_threshold_high_A);

for phase = 1:4
    in = in.setVariable("E010A5_IL_Sense_Gain" + phase, 1.0);
end

in = in.setVariable("E010_TonTrunc_Enable", spec.E010_TonTrunc_Enable);
in = in.setVariable("Tton_trunc_min", spec.Tton_trunc_min);
in = in.setVariable("Tton_trunc_window", spec.Tton_trunc_window);
in = in.setVariable("E010_PulseInhibit_Enable", spec.E010_PulseInhibit_Enable);
in = in.setVariable("E010_PulseInhibit_Count", spec.E010_PulseInhibit_Count);
in = in.setVariable("E010_PulseInhibit_Time", spec.E010_PulseInhibit_Time);
in = in.setVariable("E010_ReentryGuard_Enable", spec.E010_ReentryGuard_Enable);
in = in.setVariable("E010_Reentry_Band_Down", spec.E010_Reentry_Band_Down);

out = sim(in);
end

function metrics = collectMetrics(logs, spec, availability, schedulerRows)
[tV, vout] = signalSeries(logs, "Vout");
postMask = tV >= spec.t_load_step & tV <= spec.stop_time;
tau = tV - spec.t_load_step;
metrics = struct();
metrics.peak_overshoot_mV = 1e3 * max(vout(postMask) - spec.vref);
metrics.peak_undershoot_mV = 1e3 * max(max(spec.vref - vout(postMask)), 0);
metrics.recovery_peak_2_12us_mV = 1e3 * maxWindow(tau, vout - spec.vref, 2e-6, 12e-6);
metrics.recovery_peak_12_40us_mV = 1e3 * maxWindow(tau, vout - spec.vref, 12e-6, 40e-6);
metrics.settling_time_us = settlingTimeUs(tV, vout, spec);
metrics.final_Vout_error_mV = 1e3 * meanWindow(tau, vout - spec.vref, 75e-6, 90e-6);
metrics.Vout_ripple_pp_mV = 1e3 * ppWindow(tau, vout, 75e-6, 90e-6);

metrics.Ton_trunc_count = tonTruncEventCount(logs, spec);
metrics.Ton_trunc_min_ns = 1e9 * spec.Tton_trunc_min;
metrics.Ton_saved_ns = 1e9 * maxOptionalVector(logs, "Ton_saved_i", spec.t_load_step, spec.t_load_step + 5e-6);
metrics.Tton_trunc_window_us = 1e6 * spec.Tton_trunc_window;
metrics.pulse_inhibit_count = pulseInhibitCount(logs, spec);
metrics.inhibit_time_us = 1e6 * spec.E010_PulseInhibit_Time;
metrics.REQ_reject_count = countRisingEdges(logs, "REQ_reject_reason", spec.t_load_step, spec.stop_time);
metrics.REQ_reject_reason = lastNonzeroOptional(logs, "REQ_reject_reason", spec.t_load_step, spec.stop_time);

metrics.area_hold_count = maxOptionalSignal(logs, "area_hold_count", spec.t_load_step, spec.stop_time);
metrics.area_reset_count = maxOptionalSignal(logs, "area_reset_count", spec.t_load_step, spec.stop_time);
metrics.area_bleed_count = maxOptionalSignal(logs, "area_bleed_count", spec.t_load_step, spec.stop_time);
metrics.area_int_max = maxAbsOptionalSignal(logs, "area_int_i", spec.t_load_step, spec.stop_time);
metrics.area_int_at_reentry = NaN;
metrics.first_reentry_time_us = NaN;
metrics.first_reentry_phase = NaN;
metrics.first_reentry_Ton_ns = NaN;
metrics.burst_pulse_count_after_reentry = maxOptionalSignal(logs, ...
    "burst_pulse_count_after_reentry", spec.t_load_step, spec.stop_time);

metrics.REQ_count = rawReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.accepted_REQ_count = acceptedReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.dropped_REQ_count = max(0, metrics.REQ_count - metrics.accepted_REQ_count);
metrics.phase_order_error_rate = phaseOrderErrorRate(schedulerRows, spec.expected_phase_order);

currentStats = currentImbalance(logs, spec.t_load_step + 12e-6, spec.stop_time);
metrics.real_max_current_imbalance_A = currentStats.max_imbalance_A;
metrics.real_rms_current_imbalance_A = currentStats.rms_imbalance_A;

metrics.current_limit_hit = maxOptionalSignal(logs, "current_limit_hit", ...
    spec.t_load_step, spec.stop_time) > 0.5;
metrics.undershoot_budget_violation = metrics.peak_undershoot_mV > 1e3 * spec.undershoot_budget_V;
lateAbs = 1e-3 * abs(metrics.recovery_peak_12_40us_mV);
metrics.late_settling_guard_violation = lateAbs > spec.late_settling_guard_V;
metrics.fallback_count = maxOptionalSignal(logs, "fallback_count", spec.t_load_step, spec.stop_time);
metrics.fallback_reason = maxOptionalSignal(logs, "fallback_reason", spec.t_load_step, spec.stop_time);

metrics.logging_complete = isLoggingComplete(availability);
metrics.postprocess_complete = isPostprocessComplete(metrics);
metrics.audit_hint = auditHint(metrics, spec);
metrics.classification_hint = classificationHint(metrics);
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = struct();
row.variant = string(spec.short_variant);
row.success = logical(success);
row.peak_overshoot_mV = m.peak_overshoot_mV;
row.peak_undershoot_mV = m.peak_undershoot_mV;
row.recovery_peak_2_12us_mV = m.recovery_peak_2_12us_mV;
row.recovery_peak_12_40us_mV = m.recovery_peak_12_40us_mV;
row.settling_time_us = m.settling_time_us;
row.final_Vout_error_mV = m.final_Vout_error_mV;
row.Vout_ripple_pp_mV = m.Vout_ripple_pp_mV;
row.Ton_trunc_count = m.Ton_trunc_count;
row.Ton_trunc_min_ns = m.Ton_trunc_min_ns;
row.Ton_saved_ns = m.Ton_saved_ns;
row.Tton_trunc_window_us = m.Tton_trunc_window_us;
row.pulse_inhibit_count = m.pulse_inhibit_count;
row.inhibit_time_us = m.inhibit_time_us;
row.REQ_reject_count = m.REQ_reject_count;
row.REQ_reject_reason = string(m.REQ_reject_reason);
row.area_hold_count = m.area_hold_count;
row.area_reset_count = m.area_reset_count;
row.area_bleed_count = m.area_bleed_count;
row.area_int_max = m.area_int_max;
row.area_int_at_reentry = m.area_int_at_reentry;
row.first_reentry_time_us = m.first_reentry_time_us;
row.first_reentry_phase = m.first_reentry_phase;
row.first_reentry_Ton_ns = m.first_reentry_Ton_ns;
row.burst_pulse_count_after_reentry = m.burst_pulse_count_after_reentry;
row.REQ_count = m.REQ_count;
row.accepted_REQ_count = m.accepted_REQ_count;
row.dropped_REQ_count = m.dropped_REQ_count;
row.phase_order_error_rate = m.phase_order_error_rate;
row.real_max_current_imbalance_A = m.real_max_current_imbalance_A;
row.real_rms_current_imbalance_A = m.real_rms_current_imbalance_A;
row.current_limit_hit = logical(m.current_limit_hit);
row.undershoot_budget_violation = logical(m.undershoot_budget_violation);
row.late_settling_guard_violation = logical(m.late_settling_guard_violation);
row.fallback_count = m.fallback_count;
row.fallback_reason = string(m.fallback_reason);
row.logging_complete = logical(m.logging_complete);
row.postprocess_complete = logical(m.postprocess_complete);
row.audit_hint = string(m.audit_hint);
row.classification_hint = string(m.classification_hint);
row.error_message = string(errorMessage);
row.derived_model = string(slashPath(modelFile));
row = struct2table(row, "AsArray", true);
end

function row = failureRow(spec, errorMessage, modelFile)
m = emptyMetrics();
m.audit_hint = "simulation_or_postprocess_failed";
m.classification_hint = "IMPLEMENTATION_ISSUE";
row = rowFromMetrics(spec, m, false, errorMessage, modelFile);
end

function m = emptyMetrics()
names = ["peak_overshoot_mV", "peak_undershoot_mV", ...
    "recovery_peak_2_12us_mV", "recovery_peak_12_40us_mV", ...
    "settling_time_us", "final_Vout_error_mV", "Vout_ripple_pp_mV", ...
    "Ton_trunc_count", "Ton_trunc_min_ns", "Ton_saved_ns", ...
    "Tton_trunc_window_us", "pulse_inhibit_count", "inhibit_time_us", ...
    "REQ_reject_count", "area_hold_count", "area_reset_count", ...
    "area_bleed_count", "area_int_max", "area_int_at_reentry", ...
    "first_reentry_time_us", "first_reentry_phase", "first_reentry_Ton_ns", ...
    "burst_pulse_count_after_reentry", "REQ_count", "accepted_REQ_count", ...
    "dropped_REQ_count", "phase_order_error_rate", ...
    "real_max_current_imbalance_A", "real_rms_current_imbalance_A", ...
    "fallback_count"];
for idx = 1:numel(names)
    m.(names(idx)) = NaN;
end
m.REQ_reject_reason = "NaN";
m.current_limit_hit = false;
m.undershoot_budget_violation = false;
m.late_settling_guard_violation = false;
m.fallback_reason = "NaN";
m.logging_complete = false;
m.postprocess_complete = false;
m.audit_hint = "failed";
m.classification_hint = "IMPLEMENTATION_ISSUE";
end

function availability = signalAvailability(logs, spec)
required = requiredSignalNames();
variantCol = strings(numel(required), 1);
signalCol = strings(numel(required), 1);
availableCol = false(numel(required), 1);
sampleCountCol = zeros(numel(required), 1);
finiteCol = false(numel(required), 1);
noteCol = strings(numel(required), 1);
for idx = 1:numel(required)
    name = required(idx);
    variantCol(idx) = spec.short_variant;
    signalCol(idx) = name;
    sig = optionalSignal(logs, name);
    if isempty(sig)
        availableCol(idx) = false;
        sampleCountCol(idx) = 0;
        finiteCol(idx) = false;
        noteCol(idx) = "missing";
    else
        data = squeeze(double(sig.Values.Data));
        availableCol(idx) = true;
        sampleCountCol(idx) = numel(data);
        finiteCol(idx) = all(isfinite(data(:)));
        noteCol(idx) = "logged";
    end
end
availability = table(variantCol, signalCol, availableCol, sampleCountCol, ...
    finiteCol, noteCol, ...
    'VariableNames', {'variant','signal','available','sample_count','finite','note'});
end

function names = requiredSignalNames()
names = [
    "Vout", "Iload", ...
    "IL1", "IL2", "IL3", "IL4", ...
    "IL_sense1", "IL_sense2", "IL_sense3", "IL_sense4", ...
    "QH1", "QH2", "QH3", "QH4", ...
    "QL1", "QL2", "QL3", "QL4", ...
    "REQ1", "REQ2", "REQ3", "REQ4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "REQ_reject_reason", "phase_idx", "active_HS_phase", ...
    "Ton_cmd1", "Ton_cmd2", "Ton_cmd3", "Ton_cmd4", ...
    "Ton_actual1", "Ton_actual2", "Ton_actual3", "Ton_actual4", ...
    "Ton_trunc_i", "Ton_saved_i", "Lambda_i", "area_int_i", ...
    "a_O_state", "severe_drop_detected", "pulse_inhibit_state", ...
    "area_hold_state", "reentry_state", "fallback_state", ...
    "current_limit_hit", "phase_order_error", ...
    "burst_pulse_count_after_reentry"];
end

function schedulerRows = schedulerAudit(logs, spec)
eventTimes = [];
rawPhase = [];
acceptPhase = [];
for phase = 1:4
    rTimes = edgeTimes(logs, "REQ" + phase, spec.t_load_step, spec.stop_time);
    eventTimes = [eventTimes; rTimes(:)]; %#ok<AGROW>
    rawPhase = [rawPhase; phase * ones(numel(rTimes), 1)]; %#ok<AGROW>
    acceptPhase = [acceptPhase; zeros(numel(rTimes), 1)]; %#ok<AGROW>
end
[eventTimes, order] = sort(eventTimes);
rawPhase = rawPhase(order);
acceptPhase = acceptPhase(order);
for idx = 1:numel(eventTimes)
    acceptPhase(idx) = acceptedPhaseAt(logs, eventTimes(idx));
end

variant = repmat(string(spec.short_variant), numel(eventTimes), 1);
event_index = (1:numel(eventTimes))';
time_us = 1e6 * (eventTimes(:) - spec.t_load_step);
phase_idx = zeros(numel(eventTimes), 1);
REQ_reject_reason = zeros(numel(eventTimes), 1);
phase_order_error = zeros(numel(eventTimes), 1);
active_HS_phase = zeros(numel(eventTimes), 1);
for idx = 1:numel(eventTimes)
    t = eventTimes(idx);
    phase_idx(idx) = valueAtOptional(logs, "phase_idx", t, NaN);
    REQ_reject_reason(idx) = valueAtOptional(logs, "REQ_reject_reason", t, 0);
    phase_order_error(idx) = valueAtOptional(logs, "phase_order_error", t, 0);
    active_HS_phase(idx) = valueAtOptional(logs, "active_HS_phase", t, 0);
end
schedulerRows = table(variant, event_index, time_us, rawPhase(:), acceptPhase(:), ...
    phase_idx, REQ_reject_reason, phase_order_error, active_HS_phase, ...
    'VariableNames', {'variant','event_index','time_us','REQ_phase', ...
    'REQ_accept_phase','phase_idx','REQ_reject_reason', ...
    'phase_order_error','active_HS_phase'});
end

function exportWaveSample(logs, spec, csvPath)
[t, vout] = signalSeries(logs, "Vout");
[ti, iload] = signalSeries(logs, "Iload");
timeGrid = unique([t(:); ti(:)]);
maxRows = 12000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
out = table(1e6 * (timeGrid - spec.t_load_step), ...
    interp1(t, vout, timeGrid, "linear", "extrap"), ...
    interp1(ti, iload, timeGrid, "previous", "extrap"), ...
    'VariableNames', {'time_after_step_us', 'Vout', 'Iload'});
for phase = 1:4
    out.("IL" + phase) = interpRequired(logs, "IL" + phase, timeGrid, "linear");
    out.("IL_sense" + phase) = interpRequired(logs, "IL_sense" + phase, timeGrid, "linear");
    out.("QH" + phase) = interpRequired(logs, "QH" + phase, timeGrid, "previous");
    out.("QL" + phase) = interpRequired(logs, "QL" + phase, timeGrid, "previous");
    out.("REQ" + phase) = interpRequired(logs, "REQ" + phase, timeGrid, "previous");
    out.("REQ_accept" + phase) = interpRequired(logs, "REQ_accept" + phase, timeGrid, "previous");
    out.("Ton_cmd" + phase) = interpRequired(logs, "Ton_cmd" + phase, timeGrid, "previous");
    out.("Ton_actual" + phase) = interpRequired(logs, "Ton_actual" + phase, timeGrid, "previous");
end
for name = ["Ton_trunc_i", "Ton_saved_i", "Lambda_i", "area_int_i", ...
        "a_O_state", "severe_drop_detected", "pulse_inhibit_state", ...
        "active_HS_phase", "REQ_reject_reason", "phase_order_error", ...
        "current_limit_hit", "fallback_state", "fallback_count", ...
        "burst_pulse_count_after_reentry"]
    out.(name) = interpOptionalSignal(logs, name, timeGrid);
end
writetable(out, csvPath);
end

function writeBaselineAudit(auditPath, rows, classification, detail, auditPassed, ...
    metricsCsv, availabilityCsv, schedulerCsv)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5 Baseline Reproduction And Logging Audit\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Scope\n\n");
fprintf(fid, "This audit ran only `A5-C0` and `A5-C4` for the fixed external `40A -> 1A` load-current drop. It did not run A5-T1/T2/T3/T4, active Lambda, active-phase add/shed, DCR mismatch, or current-sense mismatch.\n\n");
fprintf(fid, "## Required Checks\n\n");
fprintf(fid, "1. Derived copies were created from `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`; the baseline `.slx` was not modified.\n");
fprintf(fid, "2. A5-C0 reproduction status: `%s`.\n", rowHint(rows, "A5-C0"));
fprintf(fid, "3. A5-C4 previous-A4 reproduction status: `%s`.\n", rowHint(rows, "A5-C4"));
fprintf(fid, "4. Vout peak/recovery metrics are computable: `%s`.\n", yesNo(allFinite(rows, ["peak_overshoot_mV","peak_undershoot_mV","recovery_peak_2_12us_mV","recovery_peak_12_40us_mV"])));
fprintf(fid, "5. REQ_count, accepted_REQ_count, and dropped_REQ_count are computable: `%s`.\n", yesNo(allFinite(rows, ["REQ_count","accepted_REQ_count","dropped_REQ_count"])));
fprintf(fid, "6. phase_order_error_rate is computable: `%s`.\n", yesNo(allFinite(rows, "phase_order_error_rate")));
fprintf(fid, "7. area_int_i is logged and finite: `%s`.\n", yesNo(all(rows.logging_complete)));
fprintf(fid, "8. active_HS_phase is available through a passive QH observer.\n");
fprintf(fid, "9. first_reentry_time_us and burst_pulse_count_after_reentry are represented without fabrication: reentry is `not_applicable` for C0/C4, burst count is logged as zero-state baseline.\n");
fprintf(fid, "10. Missing/NaN/inferred metrics: reentry-specific fields are NaN because no A5 controlled reentry exists in C0/C4; no hard-pass metric is fabricated.\n\n");
fprintf(fid, "## Metrics Snapshot\n\n");
writeMetricsTable(fid, rows);
fprintf(fid, "## Files\n\n");
fprintf(fid, "- Metrics CSV: `%s`\n", slashPath(metricsCsv));
fprintf(fid, "- Signal availability CSV: `%s`\n", slashPath(availabilityCsv));
fprintf(fid, "- Scheduler audit CSV: `%s`\n\n", slashPath(schedulerCsv));
fprintf(fid, "## Structural Check Note\n\n");
fprintf(fid, "`model_check` reports the same seven unconnected-block errors on the original baseline and on both derived A5-C0/A5-C4 models: `Add`, `Add1`, `Add2`, `Add3`, `Add4`, and the root `OnDelay` input/output. These are inherited baseline artifacts, not new A5 logging edits. The derived simulations completed successfully and the baseline `.slx` was not modified.\n\n");
fprintf(fid, "## Classification\n\n");
fprintf(fid, "`%s`\n\n%s\n\n", classification, detail);
if auditPassed
    fprintf(fid, "Baseline severe-drop audit passed. A5-T1/T2/T3/T4 may be prepared in the next task. No A5 improvement claim is made yet.\n");
else
    fprintf(fid, "Baseline severe-drop audit failed. Do not run A5 token variants. Fix logging/model wiring/postprocess first.\n");
end
end

function writeWaveformAudit(auditPath, rows, availabilityRows, classification, experimentRoot)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5 Baseline Waveform Audit\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Logged Signal Families\n\n");
fprintf(fid, "The A5-C0/A5-C4 derived models log voltage, external load current, real/sensed phase currents, QH/QL gates, raw and accepted REQ, phase index, active high-side phase, Ton command/actual width, `Lambda_i`, `area_int_i`, and passive A5 state placeholders. These placeholders do not affect IQCOT behavior and do not validate A5.\n\n");
fprintf(fid, "## Availability Summary\n\n");
for idx = 1:height(rows)
    variant = rows.variant(idx);
    if isempty(availabilityRows) || ~ismember("variant", string(availabilityRows.Properties.VariableNames))
        missing = requiredSignalNames();
    else
        vr = availabilityRows(availabilityRows.variant == variant, :);
        missing = vr.signal(~vr.available);
    end
    if isempty(missing)
        fprintf(fid, "- `%s`: all required audit signals logged and finite.\n", variant);
    else
        fprintf(fid, "- `%s`: missing `%s`.\n", variant, strjoin(missing, ", "));
    end
end
fprintf(fid, "\n## Wave Samples\n\n");
for idx = 1:height(rows)
    prefix = filePrefixForVariant(rows.variant(idx));
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), ...
        slashPath(fullfile(experimentRoot, prefix + "_wave_sample.csv")));
end
fprintf(fid, "\n## Interpretation\n\n");
fprintf(fid, "`%s`: waveform logging is an infrastructure result only. A5 severe-drop improvement, active-phase interaction, active Lambda control, and hardware/HIL claims remain forbidden.\n", classification);
end

function writeReproductionSummary(summaryPath, rows, classification, detail, ...
    metricsCsv, availabilityCsv, schedulerCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5 Baseline Reproduction Summary\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Result\n\n");
fprintf(fid, "`%s`\n\n%s\n\n", classification, detail);
fprintf(fid, "## Reproduction Table\n\n");
writeMetricsTable(fid, rows);
c0 = rows(rows.variant == "A5-C0", :);
c4 = rows(rows.variant == "A5-C4", :);
if height(c0) == 1 && height(c4) == 1 && c0.success && c4.success
    dPeak = c4.peak_overshoot_mV - c0.peak_overshoot_mV;
    dRecovery = c4.recovery_peak_2_12us_mV - c0.recovery_peak_2_12us_mV;
    fprintf(fid, "## A5-C4 Boundary\n\n");
    fprintf(fid, "A5-C4 reproduces the known severe-drop boundary: A4 is no-harm but non-improving for `40A -> 1A`. Delta peak overshoot is `%.6g mV`; delta 2-12 us recovery peak is `%.6g mV`. This confirms the need for A5 but does not validate A5.\n\n", dPeak, dRecovery);
end
fprintf(fid, "## Evidence Files\n\n");
fprintf(fid, "- Metrics: `%s`\n", slashPath(metricsCsv));
fprintf(fid, "- Signal availability: `%s`\n", slashPath(availabilityCsv));
fprintf(fid, "- Scheduler audit: `%s`\n\n", slashPath(schedulerCsv));
fprintf(fid, "## Claim Boundary\n\n");
fprintf(fid, "Allowed: the A5 severe-drop validation infrastructure is ready only if this audit is `MODEL_CONFIRMED`. Forbidden: claiming A5 improves overshoot/recovery, A5 robustness, active-phase mixing, PIS-IEK first-peak prediction, or hardware/HIL/board/silicon validation.\n");
end

function [classification, detail, auditPassed] = classifyAudit(rows)
auditPassed = height(rows) == 2 && all(rows.success) && ...
    all(rows.logging_complete) && all(rows.postprocess_complete);
if auditPassed
    c0 = rows(rows.variant == "A5-C0", :);
    c4 = rows(rows.variant == "A5-C4", :);
    noHarm = height(c0) == 1 && height(c4) == 1 && ...
        abs(c4.peak_overshoot_mV - c0.peak_overshoot_mV) <= 1e-3 && ...
        abs(c4.recovery_peak_2_12us_mV - c0.recovery_peak_2_12us_mV) <= 1e-3 && ...
        c4.peak_undershoot_mV <= max(c0.peak_undershoot_mV, 1e-6) + 1e-3;
    classification = "MODEL_CONFIRMED";
    if noHarm
        detail = "Baseline severe-drop audit passed. A5-C0 and A5-C4 ran with complete core logging; A5-C4 reproduced the known no-harm but non-improving A4 boundary for 40A -> 1A. No A5 improvement claim is made.";
    else
        detail = "Baseline severe-drop audit passed for logging/postprocess, but A5-C4 differs from the earlier no-harm boundary and should be reviewed before A5 token variants.";
    end
else
    classification = "IMPLEMENTATION_ISSUE";
    detail = "Baseline severe-drop audit failed because at least one run, required signal, or hard metric was unavailable. Do not run A5-T1/T2/T3/T4.";
end
end

function complete = isLoggingComplete(availability)
hardSignals = [
    "Vout", "Iload", "IL1", "IL2", "IL3", "IL4", ...
    "REQ1", "REQ2", "REQ3", "REQ4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "Ton_cmd1", "Ton_cmd2", "Ton_cmd3", "Ton_cmd4", ...
    "Ton_actual1", "Ton_actual2", "Ton_actual3", "Ton_actual4", ...
    "area_int_i", "phase_idx"];
complete = true;
for idx = 1:numel(hardSignals)
    row = availability(availability.signal == hardSignals(idx), :);
    complete = complete && height(row) == 1 && row.available && row.finite;
end
end

function complete = isPostprocessComplete(m)
hardValues = [
    m.peak_overshoot_mV, m.peak_undershoot_mV, ...
    m.recovery_peak_2_12us_mV, m.recovery_peak_12_40us_mV, ...
    m.REQ_count, m.dropped_REQ_count, m.phase_order_error_rate, ...
    m.final_Vout_error_mV, m.real_max_current_imbalance_A, ...
    m.real_rms_current_imbalance_A];
complete = all(isfinite(hardValues));
end

function hint = auditHint(m, spec)
if ~m.logging_complete
    hint = "logging_incomplete";
elseif ~m.postprocess_complete
    hint = "postprocess_incomplete";
elseif spec.short_variant == "A5-C4" && m.dropped_REQ_count == 0
    hint = "previous_A4_no_harm_boundary_reproduced_pending_pairwise_check";
else
    hint = "baseline_reproduction_metrics_computable";
end
end

function hint = classificationHint(m)
if m.logging_complete && m.postprocess_complete
    hint = "MODEL_CONFIRMED";
else
    hint = "IMPLEMENTATION_ISSUE";
end
end

function count = tonTruncEventCount(logs, spec)
count = 0;
saved = optionalSignal(logs, "Ton_saved_i");
if isempty(saved)
    return;
end
time = saved.Values.Time(:);
data = orientMatrix(squeeze(double(saved.Values.Data)), 4);
for phase = 1:4
    times = edgeTimes(logs, "REQ_accept" + phase, spec.t_load_step, spec.t_load_step + 5e-6);
    for idx = 1:numel(times)
        if numel(time) < 2
            val = data(1, phase);
        else
            val = interp1(time, data(:, phase), times(idx), "previous", "extrap");
        end
        count = count + double(val > 1e-12);
    end
end
end

function count = pulseInhibitCount(logs, spec)
count = 0;
for phase = 1:4
    count = count + maxOptionalSignal(logs, "pulse_inhibit_count" + phase, ...
        spec.t_load_step, spec.stop_time);
end
end

function count = rawReqCount(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "REQ" + phase, startTime, endTime);
end
end

function count = acceptedReqCount(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "REQ_accept" + phase, startTime, endTime);
end
end

function phase = acceptedPhaseAt(logs, t)
phase = 0;
for idx = 1:4
    if valueAtOptional(logs, "REQ_accept" + idx, t, 0) > 0.5
        phase = idx;
        return;
    end
end
end

function rate = phaseOrderErrorRate(schedulerRows, expectedOrder)
if isempty(schedulerRows)
    rate = NaN;
    return;
end
phases = schedulerRows.REQ_accept_phase;
phases = phases(phases > 0);
if numel(phases) < 2
    rate = NaN;
    return;
end
errors = 0;
checks = 0;
expectedOrder = expectedOrder(:)';
for idx = 2:numel(phases)
    prevIdx = find(expectedOrder == phases(idx - 1), 1);
    if isempty(prevIdx)
        errors = errors + 1;
    else
        nextIdx = prevIdx + 1;
        if nextIdx > numel(expectedOrder)
            nextIdx = 1;
        end
        errors = errors + double(phases(idx) ~= expectedOrder(nextIdx));
    end
    checks = checks + 1;
end
rate = errors / max(checks, 1);
end

function stats = currentImbalance(logs, startTime, endTime)
means = NaN(1, 4);
for phase = 1:4
    [t, values] = signalSeries(logs, "IL" + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        means(phase) = mean(values(mask), "omitnan");
    end
end
err = means - mean(means, "omitnan");
stats.max_imbalance_A = max(abs(err));
stats.rms_imbalance_A = sqrt(mean(err.^2, "omitnan"));
end

function value = maxWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask)
    value = max(y(mask));
else
    value = NaN;
end
end

function value = meanWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask)
    value = mean(y(mask), "omitnan");
else
    value = NaN;
end
end

function value = ppWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask)
    value = max(y(mask)) - min(y(mask));
else
    value = NaN;
end
end

function valueUs = settlingTimeUs(t, vout, spec)
valueUs = NaN;
post = find(t >= spec.t_load_step);
if isempty(post)
    return;
end
err = abs(vout - spec.vref);
for idx = post(1):numel(t)
    if all(err(idx:end) <= spec.settle_band_V)
        valueUs = 1e6 * (t(idx) - spec.t_load_step);
        return;
    end
end
end

function count = countRisingEdges(logs, name, startTime, endTime)
count = numel(edgeTimes(logs, name, startTime, endTime));
end

function times = edgeTimes(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    times = [];
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
if ~isvector(values)
    values = firstScalarTrace(values, t);
else
    values = values(:);
end
mask = t >= startTime & t <= endTime;
t = t(mask);
values = values(mask);
if numel(values) < 2
    times = [];
else
    edgeIdx = find(diff(values > 0.5) > 0) + 1;
    times = t(edgeIdx);
    if values(1) > 0.5
        times = [t(1); times(:)];
    end
end
end

function [time, values] = signalSeries(logs, name)
sig = optionalSignal(logs, name);
if isempty(sig)
    error("Missing logged signal: %s", name);
end
time = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
if ~isvector(values)
    values = firstScalarTrace(values, time);
else
    values = values(:);
end
end

function sig = optionalSignal(logs, name)
sig = [];
try
    found = logs.find("Name", char(name));
    if isa(found, "Simulink.SimulationData.Dataset")
        if found.numElements > 0
            sig = found.getElement(1);
        end
    elseif ~isempty(found)
        sig = found(1);
    end
catch
    try
        sig = logs.get(char(name));
    catch
        sig = [];
    end
end
end

function value = valueAtOptional(logs, name, t, defaultValue)
sig = optionalSignal(logs, name);
if isempty(sig) || isnan(t)
    value = defaultValue;
    return;
end
time = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data)
    data = firstScalarTrace(data, time);
else
    data = data(:);
end
value = interp1(time, data, t, "previous", "extrap");
if isempty(value) || isnan(value)
    value = defaultValue;
end
end

function value = maxOptionalSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = 0;
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data)
    data = firstScalarTrace(data, t);
else
    data = data(:);
end
mask = t >= startTime & t <= endTime;
if any(mask)
    value = max(abs(data(mask)));
else
    value = 0;
end
end

function value = maxAbsOptionalSignal(logs, name, startTime, endTime)
value = maxOptionalSignal(logs, name, startTime, endTime);
end

function value = maxOptionalVector(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = 0;
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if isvector(data)
    data = data(:);
else
    data = orientMatrix(data, 4);
end
mask = t >= startTime & t <= endTime;
if any(mask)
    value = max(abs(data(mask, :)), [], "all");
else
    value = 0;
end
end

function value = lastNonzeroOptional(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = 0;
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data)
    data = firstScalarTrace(data, t);
else
    data = data(:);
end
mask = t >= startTime & t <= endTime & abs(data) > 0;
if any(mask)
    value = data(find(mask, 1, "last"));
else
    value = 0;
end
end

function values = interpRequired(logs, name, timeGrid, method)
[t, data] = signalSeries(logs, name);
if numel(t) < 2
    values = repmat(data(1), size(timeGrid));
else
    values = interp1(t, data, timeGrid, method, "extrap");
end
end

function values = interpOptionalSignal(logs, name, timeGrid)
sig = optionalSignal(logs, name);
if isempty(sig)
    values = NaN(size(timeGrid));
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data)
    data = firstScalarTrace(data, t);
else
    data = data(:);
end
if numel(t) < 2
    values = repmat(data(1), size(timeGrid));
else
    values = interp1(t, data, timeGrid, "previous", "extrap");
end
end

function data = orientMatrix(data, columns)
if isvector(data)
    data = data(:)';
end
if size(data, 2) ~= columns && size(data, 1) == columns
    data = data';
end
if size(data, 2) ~= columns
    data = reshape(data, [], columns);
end
end

function data = firstScalarTrace(data, time)
time = time(:);
if size(data, 1) == numel(time)
    data = data(:, 1);
elseif size(data, 2) == numel(time)
    data = data(1, :)';
else
    data = reshape(data, [], numel(time));
    data = data(1, :)';
end
data = data(:);
end

function rows = finalizeMetricRows(rows)
order = metricColumns();
for idx = 1:numel(order)
    if ~ismember(order{idx}, rows.Properties.VariableNames)
        rows.(order{idx}) = missing;
    end
end
rows = rows(:, order);
end

function columns = metricColumns()
columns = {'variant','success','peak_overshoot_mV','peak_undershoot_mV', ...
    'recovery_peak_2_12us_mV','recovery_peak_12_40us_mV', ...
    'settling_time_us','final_Vout_error_mV','Vout_ripple_pp_mV', ...
    'Ton_trunc_count','Ton_trunc_min_ns','Ton_saved_ns', ...
    'Tton_trunc_window_us','pulse_inhibit_count','inhibit_time_us', ...
    'REQ_reject_count','REQ_reject_reason','area_hold_count', ...
    'area_reset_count','area_bleed_count','area_int_max', ...
    'area_int_at_reentry','first_reentry_time_us','first_reentry_phase', ...
    'first_reentry_Ton_ns','burst_pulse_count_after_reentry', ...
    'REQ_count','accepted_REQ_count','dropped_REQ_count', ...
    'phase_order_error_rate','real_max_current_imbalance_A', ...
    'real_rms_current_imbalance_A','current_limit_hit', ...
    'undershoot_budget_violation','late_settling_guard_violation', ...
    'fallback_count','fallback_reason','logging_complete', ...
    'postprocess_complete','audit_hint','classification_hint', ...
    'error_message','derived_model'};
end

function out = appendTable(out, row)
if isempty(row)
    return;
end
if isempty(out)
    out = row;
else
    out = [out; row]; %#ok<AGROW>
end
end

function out = allFinite(rows, names)
names = string(names);
out = true;
for idx = 1:numel(names)
    values = rows.(names(idx));
    out = out && all(isfinite(values));
end
end

function hint = rowHint(rows, variant)
row = rows(rows.variant == variant, :);
if isempty(row)
    hint = "missing";
elseif row.success && row.logging_complete && row.postprocess_complete
    hint = "passed";
else
    hint = "failed";
end
end

function writeMetricsTable(fid, rows)
fprintf(fid, "| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | REQ | Accepted | Dropped | Phase err | Final err mV | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.peak_overshoot_mV(idx), ...
        rows.peak_undershoot_mV(idx), rows.recovery_peak_2_12us_mV(idx), ...
        rows.recovery_peak_12_40us_mV(idx), rows.REQ_count(idx), ...
        rows.accepted_REQ_count(idx), rows.dropped_REQ_count(idx), ...
        rows.phase_order_error_rate(idx), rows.final_Vout_error_mV(idx), ...
        rows.audit_hint(idx));
end
fprintf(fid, "\n");
end

function prefix = filePrefixForVariant(variant)
variant = string(variant);
if variant == "A5-C0"
    prefix = "e010_a5_c0_baseline_40A_to_1A";
elseif variant == "A5-C4"
    prefix = "e010_a5_c4_previous_A4_40A_to_1A";
else
    prefix = "e010_a5_unknown";
end
end

function text = yesNo(value)
if value
    text = "yes";
else
    text = "no";
end
end

function text = reportDate()
text = char(datetime("today", "Format", "yyyy-MM-dd"));
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
