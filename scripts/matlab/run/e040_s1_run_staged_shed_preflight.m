function rows = e040_s1_run_staged_shed_preflight(variants)
%E040_S1_RUN_STAGED_SHED_PREFLIGHT Run the minimal E040-S1 staged shed check.
% Default execution starts with S1-R0 and S1-R2. S1-R3 is run only after
% S1-R2 produces interpretable transfer/drain logs. S1-R4 is intentionally
% blocked by this script.

if nargin < 1
    variants = ["S1-R0", "S1-R2"];
    autoRunR3 = true;
else
    variants = string(variants);
    autoRunR3 = any(variants == "S1-R3");
end
variants = string(variants);

if any(variants == "S1-R4")
    error("S1-R4 is blocked until S1-R3 passes all hard gates.");
end

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));

initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E040_active_phase_add_shed", ...
    "S1_staged_shed_handoff");
ensureDir(experimentRoot);

metricsCsv = fullfile(experimentRoot, "e040_s1_metrics.csv");
summaryPath = fullfile(experimentRoot, "e040_s1_research_summary.md");
waveformAuditPath = fullfile(experimentRoot, "e040_s1_waveform_audit.md");
baselineAuditPath = fullfile(experimentRoot, "e040_s1_baseline_wiring_audit.md");

writeBaselineAudit(projectRoot, baselineAuditPath);

rows = table();
r2Gate = false;
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    [row, gate] = runOneVariant(spec, experimentRoot);
    rows = appendRow(rows, row);
    if spec.short_variant == "S1-R2"
        r2Gate = gate;
    end
end

if autoRunR3 && ~any(rows.variant == "S1-R3")
    if r2Gate
        spec = variantSpec("S1-R3");
        [row, ~] = runOneVariant(spec, experimentRoot);
        rows = appendRow(rows, row);
    else
        row = blockedRow(variantSpec("S1-R3"), ...
            "S1-R3 not run because S1-R2 transfer/drain logs did not pass the interpretability gate.");
        rows = appendRow(rows, row);
        writeBlockedReport(fullfile(experimentRoot, "e040_s1_r3_commit_relock_report.md"), row);
    end
end

rows = finalizeRows(rows);
writetable(rows, metricsCsv);
[classification, detail] = classifyRows(rows);
writeSummary(summaryPath, rows, classification, detail, metricsCsv, baselineAuditPath);
writeWaveformAudit(waveformAuditPath, rows, classification, experimentRoot);

fprintf("E040_S1_METRICS=%s\n", metricsCsv);
fprintf("E040_S1_SUMMARY=%s\n", summaryPath);
fprintf("E040_S1_WAVEFORM_AUDIT=%s\n", waveformAuditPath);
disp(rows);
end

function [row, r2Gate] = runOneVariant(spec, experimentRoot)
r2Gate = false;
modelFile = "";
auditCsv = fullfile(experimentRoot, spec.file_prefix + "_scheduler_audit.csv");
availabilityCsv = fullfile(experimentRoot, spec.file_prefix + "_signal_availability.csv");
waveCsv = fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv");
reportPath = fullfile(experimentRoot, spec.file_prefix + "_report.md");

try
    modelFile = e040_s1_build_staged_shed_model(spec.short_variant);
    [~, modelName] = fileparts(modelFile);
    load_system(modelFile);
    cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

    out = runCase(modelName, spec);
    logs = out.logsout;

    writeSignalAvailability(logs, availabilityCsv);
    [metrics, auditRows] = collectMetrics(logs, spec);
    writetable(auditRows, auditCsv);
    exportWaveSample(logs, spec, waveCsv);
    row = rowFromMetrics(spec, metrics, true);
    writeVariantReport(reportPath, modelFile, spec, row, auditCsv, availabilityCsv, waveCsv);

    if spec.short_variant == "S1-R2"
        r2Gate = r2Interpretable(row);
    end
catch ME
    details = errorDetails(ME);
    row = failureRow(spec, details);
    writeFailureReport(reportPath, modelFile, spec, details);
end
end

function spec = variantSpec(variant)
variant = string(variant);
spec = struct();
spec.short_variant = variant;
spec.base_load_A = 40;
spec.target_load_A = 20;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.52e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.settle_band_V = 1.0e-3;
spec.current_limit_guard_A = 55;
spec.I_shed_low_A = 25;
spec.dwell_time_s = 0.0;
spec.post_reentry_shed_delay_s = 0.0;
spec.order_relock_window_s = 2.0e-6;
spec.severe_overshoot_band_V = 80e-3;
spec.residual_current_threshold_A = 1.5;
spec.T_trim_max_s = 60e-9;
spec.K_T = 2.2e-9;
spec.fallback_K_T = 1.0e-10;
spec.current_deadband_A = 0.15;
spec.sense_confidence = 1.0;
spec.calibration_enable = 0.0;
spec.v_error_budget = 15e-3;
spec.v_error_hard_limit = 60e-3;
spec.min_scale = 0.25;
spec.ton_diff_enable = 0.0;
spec.shed_transfer_rate = 1.0;
spec.shed_transfer_window_s = 6.0e-6;
spec.max_transfer_Ton_trim_s = 60.0e-9;
spec.remaining_phase_current_limit_guard_A = 50;
spec.disabled_phase_drain_timeout_s = 6.0e-6;
spec.shed_undershoot_budget_V = 45e-3;
spec.post_shed_aS_delay_s = 3.0e-6;
spec.shed_fallback_enable = 1.0;
spec.shed_commit_boundary_policy = 0.0;
spec.expected_pre_phases = [1, 2, 3, 4];
spec.expected_post_phases = [1, 3];
spec.target_active_phase_set = "1010";
spec.variant_mode = 0.0;

if variant == "S1-R0"
    spec.variant = "fixed_four_phase_reference";
    spec.file_prefix = "e040_s1_r0_fixed4";
    spec.report_title = "E040-S1 R0 Fixed Four-Phase Reference";
elseif variant == "S1-R1"
    spec.variant = "immediate_four_to_two_shed_reference";
    spec.file_prefix = "e040_s1_r1_immediate_shed";
    spec.report_title = "E040-S1 R1 Immediate Shed Reference";
    spec.variant_mode = 1.0;
elseif variant == "S1-R2"
    spec.variant = "staged_transfer_drain_no_commit";
    spec.file_prefix = "e040_s1_r2_transfer_drain";
    spec.report_title = "E040-S1 R2 Transfer And Drain";
    spec.variant_mode = 2.0;
elseif variant == "S1-R3"
    spec.variant = "staged_transfer_drain_commit_relock";
    spec.file_prefix = "e040_s1_r3_commit_relock";
    spec.report_title = "E040-S1 R3 Commit And Relock";
    spec.variant_mode = 3.0;
else
    error("Unknown E040-S1 variant: %s", variant);
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
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.target_load_A);
in = in.setVariable("t_load_step", spec.t_load_step);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.base_load_A / 4);
for phase = 1:4
    in = in.setVariable("DCR_L" + phase, 0.01);
    in = in.setVariable("E040_IL_Sense_Gain" + phase, 1.0);
end

in = in.setVariable("E040_Variant_Mode", spec.variant_mode);
in = in.setVariable("E040_LoadStep_Time", spec.t_load_step);
in = in.setVariable("E040_I_Shed_Low", spec.I_shed_low_A);
in = in.setVariable("E040_Dwell_Time", spec.dwell_time_s);
in = in.setVariable("E040_Post_Reentry_Shed_Delay", spec.post_reentry_shed_delay_s);
in = in.setVariable("E040_Vref", spec.vref);
in = in.setVariable("E040_Severe_Overshoot_Band", spec.severe_overshoot_band_V);
in = in.setVariable("E040_Current_Limit_A", spec.current_limit_guard_A);
in = in.setVariable("E040_TonDiff_Enable", spec.ton_diff_enable);
in = in.setVariable("E040_K_T", spec.K_T);
in = in.setVariable("E040_Fallback_K_T", spec.fallback_K_T);
in = in.setVariable("E040_T_Trim_Max", spec.T_trim_max_s);
in = in.setVariable("E040_Current_Deadband", spec.current_deadband_A);
in = in.setVariable("E040_Sense_Confidence", spec.sense_confidence);
in = in.setVariable("E040_Calibration_Enable", spec.calibration_enable);
in = in.setVariable("E040_V_Error_Budget", spec.v_error_budget);
in = in.setVariable("E040_V_Error_Hard_Limit", spec.v_error_hard_limit);
in = in.setVariable("E040_Min_Scale", spec.min_scale);
in = in.setVariable("E040_Residual_Current_Threshold", spec.residual_current_threshold_A);
in = in.setVariable("E040_Order_Relock_Window", spec.order_relock_window_s);
in = in.setVariable("E040_Shed_Transfer_Rate", spec.shed_transfer_rate);
in = in.setVariable("E040_Shed_Transfer_Window", spec.shed_transfer_window_s);
in = in.setVariable("E040_Max_Transfer_Ton_Trim", spec.max_transfer_Ton_trim_s);
in = in.setVariable("E040_Remaining_Phase_Current_Limit", spec.remaining_phase_current_limit_guard_A);
in = in.setVariable("E040_Disabled_Phase_Drain_Timeout", spec.disabled_phase_drain_timeout_s);
in = in.setVariable("E040_Shed_Undershoot_Budget", spec.shed_undershoot_budget_V);
in = in.setVariable("E040_Post_Shed_AS_Delay", spec.post_shed_aS_delay_s);
in = in.setVariable("E040_Shed_Fallback_Enable", spec.shed_fallback_enable);
in = in.setVariable("E040_Shed_Commit_Boundary_Policy", spec.shed_commit_boundary_policy);
out = sim(in);
end

function [metrics, auditRows] = collectMetrics(logs, spec)
[tV, vout] = signalSeries(logs, "Vout");
post = tV >= spec.t_load_step & tV <= spec.stop_time;
finalStart = spec.stop_time - 10e-6;
finalMask = tV >= finalStart & tV <= spec.stop_time;
evalStart = spec.t_load_step + 12e-6;
evalMask = tV >= evalStart & tV <= spec.stop_time;

metrics = struct();
metrics.peak_overshoot_mV = 1e3 * max(0.0, max(vout(post) - spec.vref));
metrics.peak_undershoot_mV = 1e3 * max(0.0, max(spec.vref - vout(post)));
metrics.final_Vout_error_mV = 1e3 * mean(vout(finalMask) - spec.vref, "omitnan");
metrics.Vout_ripple_pp_mV = 1e3 * (max(vout(evalMask)) - min(vout(evalMask)));
metrics.settling_time_us = settlingTimeUs(tV, vout, spec);

[tN, nActive] = signalSeries(logs, "N_active");
metrics.N_active_initial = meanWindow(tN, nActive, spec.t_load_step - 8e-6, spec.t_load_step - 1e-6);
metrics.N_active_final = meanWindow(tN, nActive, finalStart, spec.stop_time);
metrics.actual_active_phase_set_final = activeSetStringAt(logs, spec.stop_time - 1e-9);

metrics.shed_request_count = countRisingEdges(logs, "phase_shed_request", spec.t_load_step, spec.stop_time);
metrics.shed_accept_count = countRisingEdges(logs, "phase_shed_accept", spec.t_load_step, spec.stop_time);
metrics.shed_reject_count = countRisingEdges(logs, "phase_shed_reject", spec.t_load_step, spec.stop_time);
metrics.shed_commit_count = countRisingEdges(logs, "commit_done", spec.t_load_step, spec.stop_time);
metrics.fallback_4ph_count = countRisingEdges(logs, "fallback_4ph_triggered", spec.t_load_step, spec.stop_time);

metrics.shed_request_time_us = firstHighTimeUs(logs, "phase_shed_request", spec.t_load_step, spec.stop_time);
metrics.load_share_transfer_start_us = firstStateTimeUs(logs, "shed_state", 2, spec.t_load_step, spec.stop_time);
metrics.load_share_transfer_done_us = firstThresholdTimeUs(logs, "shed_transfer_progress", 0.999, spec.t_load_step, spec.stop_time);
metrics.disabled_phase_drain_done_us = firstDrainDoneUs(logs, spec);
metrics.shed_commit_time_us = firstHighTimeUs(logs, "commit_done", spec.t_load_step, spec.stop_time);
metrics.order_relock_done_us = firstHighTimeUs(logs, "order_relock_window_done", spec.t_load_step, spec.stop_time);
metrics.a_S_enable_time_us = firstHighTimeUs(logs, "a_S_enable_after_shed", spec.t_load_step, spec.stop_time);

commitAbsTime = timeFromUs(spec, metrics.shed_commit_time_us);
residualAbsTime = residualEvalTime(spec, metrics, commitAbsTime);
metrics.IL1_at_commit_A = valueAtOrNaN(logs, "IL1", commitAbsTime);
metrics.IL2_at_commit_A = valueAtOrNaN(logs, "IL2", commitAbsTime);
metrics.IL3_at_commit_A = valueAtOrNaN(logs, "IL3", commitAbsTime);
metrics.IL4_at_commit_A = valueAtOrNaN(logs, "IL4", commitAbsTime);
metrics.residual_current_phase2_A = valueAtOrNaN(logs, "residual_current_phase2_A", residualAbsTime);
metrics.residual_current_phase4_A = valueAtOrNaN(logs, "residual_current_phase4_A", residualAbsTime);
if isnan(metrics.residual_current_phase2_A)
    metrics.residual_current_phase2_A = valueAtOrNaN(logs, "IL2", residualAbsTime);
end
if isnan(metrics.residual_current_phase4_A)
    metrics.residual_current_phase4_A = valueAtOrNaN(logs, "IL4", residualAbsTime);
end
metrics.residual_current_threshold_A = spec.residual_current_threshold_A;
metrics.residual_current_check = residualCheckText(metrics);

metrics.remaining_phase_current_peak_A = remainingPhasePeak(logs, spec.t_load_step, spec.stop_time);
metrics.current_limit_hit = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time) >= spec.current_limit_guard_A || ...
    maxOptionalSignal(logs, "current_limit_hit", spec.t_load_step, spec.stop_time) > 0.5;

activeMask = finalActiveMask(logs, finalStart, spec.stop_time);
realMetrics = currentMetrics(logs, "IL", activeMask, evalStart, spec.stop_time);
sensedMetrics = currentMetrics(logs, "IL_sense", activeMask, evalStart, spec.stop_time);
metrics.real_max_current_imbalance_A = realMetrics.max_imbalance;
metrics.real_rms_current_imbalance_A = realMetrics.rms_imbalance;
metrics.sensed_max_current_imbalance_A = sensedMetrics.max_imbalance;
metrics.sensed_rms_current_imbalance_A = sensedMetrics.rms_imbalance;

auditRows = schedulerAudit(logs, spec);
metrics.REQ_count = rawReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.accepted_REQ_count = height(auditRows);
metrics.dropped_REQ_count = max(0, metrics.REQ_count - metrics.accepted_REQ_count);
metrics.inactive_phase_REQ_count = inactiveAcceptedReqCount(auditRows);
metrics.REQ_reject_count = max(metrics.dropped_REQ_count, ...
    countRisingEdges(logs, "REQ_reject_reason", spec.t_load_step, spec.stop_time));

[metrics.phase_order_error_rate_pre_shed, ...
    metrics.phase_order_error_rate_during_transfer, ...
    metrics.phase_order_error_rate_during_commit, ...
    metrics.phase_order_error_rate_post_shed] = phaseOrderMetrics(auditRows, spec, metrics);

metrics.Ton_trim_usage = maxOptionalSignal(logs, "Ton_trim_usage", spec.t_load_step, spec.stop_time);
if metrics.Ton_trim_usage == 0
    metrics.Ton_trim_usage = trimUsage(logs, "Ton_trim", spec.T_trim_max_s, spec.t_load_step, spec.stop_time);
end
metrics.post_shed_aS_mode = maxOptionalSignal(logs, "a_S_mode", timeFromUs(spec, metrics.shed_commit_time_us), spec.stop_time);
metrics.Lambda_trim_usage = maxOptionalSignal(logs, "Lambda_trim_usage", spec.t_load_step, spec.stop_time);
metrics.shed_state_final = valueAtOptional(logs, "shed_state", spec.stop_time - 1e-9, NaN);
metrics.fallback_reason = lastNonzeroOptional(logs, "fallback_reason", spec.t_load_step, spec.stop_time);
metrics.transfer_progress_max = maxOptionalSignal(logs, "shed_transfer_progress", spec.t_load_step, spec.stop_time);
metrics.disabled_phase_current_sum_max = maxOptionalSignal(logs, "disabled_phase_current_sum", spec.t_load_step, spec.stop_time);
end

function auditRows = schedulerAudit(logs, spec)
eventTimes = [];
eventPhases = [];
for phase = 1:4
    times = edgeTimes(logs, "REQ_accept" + phase, spec.t_load_step, spec.stop_time);
    eventTimes = [eventTimes; times(:)]; %#ok<AGROW>
    eventPhases = [eventPhases; phase * ones(numel(times), 1)]; %#ok<AGROW>
end
[eventTimes, order] = sort(eventTimes);
eventPhases = eventPhases(order);
count = numel(eventTimes);

eventIndex = (1:count)';
timeUs = 1e6 * (eventTimes(:) - spec.t_load_step);
shedState = zeros(count, 1);
activePhaseSet = strings(count, 1);
nActive = zeros(count, 1);
logicalSlot = zeros(count, 1);
physicalPhaseSelected = zeros(count, 1);
reqInPhase = zeros(count, 1);
reqAcceptPhase = eventPhases(:);
reqRejectReason = zeros(count, 1);
phaseIdxBefore = zeros(count, 1);
phaseIdxAfter = zeros(count, 1);
commitArmed = zeros(count, 1);
commitDone = zeros(count, 1);
fallback4phTriggered = zeros(count, 1);
fallbackReason = zeros(count, 1);

for idx = 1:count
    t = eventTimes(idx);
    shedState(idx) = valueAtOptional(logs, "shed_state", t, 0);
    activePhaseSet(idx) = activeSetStringAt(logs, t);
    nActive(idx) = valueAtOptional(logs, "N_active", t, NaN);
    logicalSlot(idx) = valueAtOptional(logs, "logical_slot", t, 0);
    physicalPhaseSelected(idx) = valueAtOptional(logs, "physical_phase_selected", t, reqAcceptPhase(idx));
    reqInPhase(idx) = rawReqPhaseAt(logs, t);
    reqRejectReason(idx) = valueAtOptional(logs, "REQ_reject_reason", t, 0);
    phaseIdxBefore(idx) = valueAtOptional(logs, "phase_idx", max(t - 1e-9, 0), NaN);
    phaseIdxAfter(idx) = valueAtOptional(logs, "phase_idx", min(t + 1e-9, spec.stop_time), NaN);
    commitArmed(idx) = valueAtOptional(logs, "commit_armed", t, 0);
    commitDone(idx) = valueAtOptional(logs, "commit_done", t, 0);
    fallback4phTriggered(idx) = valueAtOptional(logs, "fallback_4ph_triggered", t, 0);
    fallbackReason(idx) = valueAtOptional(logs, "fallback_reason", t, 0);
end

auditRows = table(eventIndex, timeUs, shedState, activePhaseSet, nActive, ...
    logicalSlot, physicalPhaseSelected, reqInPhase, reqAcceptPhase, ...
    reqRejectReason, phaseIdxBefore, phaseIdxAfter, commitArmed, commitDone, ...
    fallback4phTriggered, fallbackReason, ...
    'VariableNames', {'event_index','time_us','shed_state','active_phase_set', ...
    'N_active','logical_slot','physical_phase_selected','REQ_in_phase', ...
    'REQ_accept_phase','REQ_reject_reason','phase_idx_before','phase_idx_after', ...
    'commit_armed','commit_done','fallback_4ph_triggered','fallback_reason'});
end

function [preRate, transferRate, commitRate, postRate] = phaseOrderMetrics(auditRows, spec, metrics)
if isempty(auditRows) || height(auditRows) < 2
    preRate = NaN; transferRate = NaN; commitRate = NaN; postRate = NaN;
    return;
end
preRows = auditRows(auditRows.time_us < 0, :);
transferStart = metrics.load_share_transfer_start_us;
transferDone = metrics.load_share_transfer_done_us;
commitDone = metrics.shed_commit_time_us;
orderDone = metrics.order_relock_done_us;

if isnan(transferStart)
    transferStart = 0;
end
if isnan(transferDone)
    transferDone = inf;
end
if isnan(commitDone)
    commitDone = inf;
end
if isnan(orderDone)
    orderDone = inf;
end

transferRows = auditRows(auditRows.time_us >= transferStart & auditRows.time_us <= transferDone, :);
commitRows = auditRows(auditRows.time_us > transferDone & auditRows.time_us <= orderDone, :);
postRows = auditRows(auditRows.time_us > orderDone, :);

preRate = orderErrorRate(preRows.physical_phase_selected, spec.expected_pre_phases);
transferRate = orderErrorRate(transferRows.physical_phase_selected, spec.expected_pre_phases);
commitRate = orderErrorRate(commitRows.physical_phase_selected, spec.expected_post_phases);
postRate = orderErrorRate(postRows.physical_phase_selected, spec.expected_post_phases);

if isinf(commitDone)
    commitRate = NaN;
    postRate = NaN;
end
end

function rate = orderErrorRate(eventPhases, expectedPhases)
eventPhases = eventPhases(:);
eventPhases = eventPhases(eventPhases > 0);
expectedPhases = expectedPhases(:)';
if numel(eventPhases) < 2 || isempty(expectedPhases)
    rate = NaN;
    return;
end
errors = 0;
checks = 0;
for idx = 2:numel(eventPhases)
    prevIdx = find(expectedPhases == eventPhases(idx - 1), 1);
    if isempty(prevIdx)
        errors = errors + 1;
        checks = checks + 1;
        continue;
    end
    nextIdx = prevIdx + 1;
    if nextIdx > numel(expectedPhases)
        nextIdx = 1;
    end
    errors = errors + double(eventPhases(idx) ~= expectedPhases(nextIdx));
    checks = checks + 1;
end
rate = errors / max(checks, 1);
end

function row = rowFromMetrics(spec, m, success)
row = table( ...
    string(spec.short_variant), success, ...
    m.N_active_initial, m.N_active_final, string(spec.target_active_phase_set), ...
    string(m.actual_active_phase_set_final), ...
    m.shed_request_count, m.shed_accept_count, m.shed_commit_count, ...
    m.shed_reject_count, m.fallback_4ph_count, ...
    m.shed_request_time_us, m.load_share_transfer_start_us, ...
    m.load_share_transfer_done_us, m.disabled_phase_drain_done_us, ...
    m.shed_commit_time_us, m.order_relock_done_us, m.a_S_enable_time_us, ...
    m.peak_overshoot_mV, m.peak_undershoot_mV, m.final_Vout_error_mV, ...
    m.Vout_ripple_pp_mV, m.settling_time_us, ...
    m.IL1_at_commit_A, m.IL2_at_commit_A, m.IL3_at_commit_A, m.IL4_at_commit_A, ...
    m.residual_current_phase2_A, m.residual_current_phase4_A, ...
    m.residual_current_threshold_A, string(m.residual_current_check), ...
    m.remaining_phase_current_peak_A, m.current_limit_hit, ...
    m.real_max_current_imbalance_A, m.real_rms_current_imbalance_A, ...
    m.sensed_max_current_imbalance_A, m.sensed_rms_current_imbalance_A, ...
    m.phase_order_error_rate_pre_shed, m.phase_order_error_rate_during_transfer, ...
    m.phase_order_error_rate_during_commit, m.phase_order_error_rate_post_shed, ...
    m.REQ_count, m.accepted_REQ_count, m.dropped_REQ_count, ...
    m.inactive_phase_REQ_count, m.REQ_reject_count, ...
    m.Ton_trim_usage, m.post_shed_aS_mode, m.Lambda_trim_usage, ...
    m.shed_state_final, m.fallback_reason, "pending", ...
    'VariableNames', metricColumns());
end

function row = failureRow(spec, message)
m = emptyMetrics(spec);
row = rowFromMetrics(spec, m, false);
row.classification_hint(1) = "implementation_issue: " + truncateText(message, 180);
end

function row = blockedRow(spec, message)
m = emptyMetrics(spec);
row = rowFromMetrics(spec, m, false);
row.classification_hint(1) = "blocked: " + truncateText(message, 180);
end

function m = emptyMetrics(spec)
m = struct();
m.N_active_initial = NaN;
m.N_active_final = NaN;
m.actual_active_phase_set_final = "";
m.shed_request_count = NaN;
m.shed_accept_count = NaN;
m.shed_commit_count = NaN;
m.shed_reject_count = NaN;
m.fallback_4ph_count = NaN;
m.shed_request_time_us = NaN;
m.load_share_transfer_start_us = NaN;
m.load_share_transfer_done_us = NaN;
m.disabled_phase_drain_done_us = NaN;
m.shed_commit_time_us = NaN;
m.order_relock_done_us = NaN;
m.a_S_enable_time_us = NaN;
m.peak_overshoot_mV = NaN;
m.peak_undershoot_mV = NaN;
m.final_Vout_error_mV = NaN;
m.Vout_ripple_pp_mV = NaN;
m.settling_time_us = NaN;
m.IL1_at_commit_A = NaN;
m.IL2_at_commit_A = NaN;
m.IL3_at_commit_A = NaN;
m.IL4_at_commit_A = NaN;
m.residual_current_phase2_A = NaN;
m.residual_current_phase4_A = NaN;
m.residual_current_threshold_A = spec.residual_current_threshold_A;
m.residual_current_check = "na";
m.remaining_phase_current_peak_A = NaN;
m.current_limit_hit = false;
m.real_max_current_imbalance_A = NaN;
m.real_rms_current_imbalance_A = NaN;
m.sensed_max_current_imbalance_A = NaN;
m.sensed_rms_current_imbalance_A = NaN;
m.phase_order_error_rate_pre_shed = NaN;
m.phase_order_error_rate_during_transfer = NaN;
m.phase_order_error_rate_during_commit = NaN;
m.phase_order_error_rate_post_shed = NaN;
m.REQ_count = NaN;
m.accepted_REQ_count = NaN;
m.dropped_REQ_count = NaN;
m.inactive_phase_REQ_count = NaN;
m.REQ_reject_count = NaN;
m.Ton_trim_usage = NaN;
m.post_shed_aS_mode = NaN;
m.Lambda_trim_usage = NaN;
m.shed_state_final = NaN;
m.fallback_reason = NaN;
end

function rows = finalizeRows(rows)
for idx = 1:height(rows)
    if rows.success(idx) == false
        if rows.classification_hint(idx) == "pending"
            rows.classification_hint(idx) = "implementation_issue";
        end
    elseif rows.variant(idx) == "S1-R0"
        rows.classification_hint(idx) = "fixed_four_phase_reference";
    elseif rows.variant(idx) == "S1-R2"
        if r2Interpretable(rows(idx, :))
            rows.classification_hint(idx) = "transfer_drain_interpretable";
        else
            rows.classification_hint(idx) = "transfer_drain_not_interpretable";
        end
    elseif rows.variant(idx) == "S1-R3"
        if r3Pass(rows(idx, :), rows)
            rows.classification_hint(idx) = "local_staged_shed_integrity_pass";
        elseif rows.shed_commit_count(idx) < 1
            rows.classification_hint(idx) = "shed_commit_not_reached";
        elseif rows.fallback_4ph_count(idx) > 0
            rows.classification_hint(idx) = "fallback_triggered";
        elseif rows.dropped_REQ_count(idx) > 0
            rows.classification_hint(idx) = "dropped_req";
        elseif rows.inactive_phase_REQ_count(idx) > 0
            rows.classification_hint(idx) = "inactive_phase_req";
        elseif rows.phase_order_error_rate_post_shed(idx) > 0
            rows.classification_hint(idx) = "post_shed_phase_order_error";
        elseif rows.current_limit_hit(idx)
            rows.classification_hint(idx) = "current_limit_hit";
        elseif rows.residual_current_check(idx) ~= "pass"
            rows.classification_hint(idx) = "residual_current_violation";
        else
            rows.classification_hint(idx) = "model_revised_needed";
        end
    end
end
end

function tf = r2Interpretable(row)
tf = row.success(1) && ...
    row.load_share_transfer_done_us(1) >= 0 && ...
    row.shed_state_final(1) >= 3 && ...
    row.fallback_4ph_count(1) == 0 && ...
    ~row.current_limit_hit(1) && ...
    ~isnan(row.remaining_phase_current_peak_A(1));
end

function tf = r3Pass(row, rows)
tf = row.success(1) && ...
    abs(row.N_active_final(1) - 2.0) <= 1e-6 && ...
    row.actual_active_phase_set_final(1) == "1010" && ...
    row.shed_commit_count(1) == 1 && ...
    row.fallback_4ph_count(1) == 0 && ...
    row.dropped_REQ_count(1) == 0 && ...
    row.inactive_phase_REQ_count(1) == 0 && ...
    row.phase_order_error_rate_post_shed(1) == 0 && ...
    ~row.current_limit_hit(1) && ...
    row.residual_current_check(1) == "pass";
if tf && any(rows.variant == "S1-R0")
    ref = rows(rows.variant == "S1-R0", :);
    tf = row.peak_undershoot_mV(1) <= ref.peak_undershoot_mV(1) + 45.0 && ...
        abs(row.final_Vout_error_mV(1)) <= max(abs(ref.final_Vout_error_mV(1)) + 20.0, 25.0);
end
end

function [classification, detail] = classifyRows(rows)
if any(~rows.success & startsWith(rows.classification_hint, "implementation_issue"))
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E040-S1 script/model execution failed before reliable metrics were produced.";
    return;
end
if ~any(rows.variant == "S1-R2")
    classification = "IMPLEMENTATION_ISSUE";
    detail = "S1-R2 transfer/drain gate was not run, so S1-R3 cannot be interpreted.";
    return;
end
r2 = rows(rows.variant == "S1-R2", :);
if ~r2Interpretable(r2)
    classification = "MODEL_REVISED";
    detail = "S1-R2 ran, but transfer/drain observability or hard guards were not sufficient to justify S1-R3 expansion.";
    return;
end
if any(rows.variant == "S1-R3")
    r3 = rows(rows.variant == "S1-R3", :);
    if r3.success(1) && r3Pass(r3, rows)
        classification = "MODEL_CONFIRMED";
        detail = "The local 40A->20A staged shed reached exact two-phase operation with REQ integrity, residual qualification, no fallback, and bounded voltage/current behavior.";
    elseif r3.success(1) && r3.shed_commit_count(1) >= 1
        classification = "MODEL_REVISED";
        detail = "S1-R3 committed, but at least one hard integrity or bounded-waveform criterion failed.";
    elseif r3.success(1)
        classification = "MODEL_REVISED";
        detail = "S1-R3 ran but did not reach an accepted atomic shed commit under the current guard settings.";
    else
        classification = "IMPLEMENTATION_ISSUE";
        detail = "S1-R3 was attempted only after R2, but did not produce reliable metrics.";
    end
else
    classification = "MODEL_REVISED";
    detail = "S1-R2 transfer/drain is interpretable, but S1-R3 was not included in this invocation.";
end
end

function writeBaselineAudit(projectRoot, auditPath)
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", ...
    "four_phase_ideal_digital_iqcot.slx");
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S1 Baseline Wiring Audit\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "Baseline model: `%s`\n\n", slashPath(baselineModel));
fprintf(fid, "Rule: the baseline is loaded only for inspection. E040-S1 models are created by copying it and editing only derived `.slx` files through MATLAB/Simulink APIs.\n\n");
if ~isfile(baselineModel)
    fprintf(fid, "Status: `IMPLEMENTATION_ISSUE` - baseline model was not found.\n");
    return;
end
[~, modelName] = fileparts(baselineModel);
load_system(baselineModel);
cleanupModel = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>
blockNames = ["Voltage Measurement", "PhaseScheduler_4Phase", "IQCOT_Ton_Adapter", ...
    "COT_Cell_1Phase1", "COT_Cell_1Phase2", "COT_Cell_1Phase3", "COT_Cell_1Phase4", ...
    "IL_Measurement1", "IL_Measurement2", "IL_Measurement3", "IL_Measurement4", ...
    "GateDriver_1Phase1", "GateDriver_1Phase2", "GateDriver_1Phase3", "GateDriver_1Phase4"];
fprintf(fid, "## Required Baseline Blocks\n\n");
fprintf(fid, "| Block | Present |\n|---|---:|\n");
for idx = 1:numel(blockNames)
    present = ~isempty(find_system(modelName, "SearchDepth", 1, "Name", char(blockNames(idx))));
    fprintf(fid, "| `%s` | %d |\n", blockNames(idx), present);
end
fprintf(fid, "\n## Required Goto/From Tags\n\n");
tags = ["tr1", "tr2", "tr3", "tr4", "IL1", "IL2", "IL3", "IL4", "Lambda_i", "A_iqcot"];
fprintf(fid, "| Tag | Present |\n|---|---:|\n");
for idx = 1:numel(tags)
    present = hasGotoTag(modelName, tags(idx));
    fprintf(fid, "| `%s` | %d |\n", tags(idx), present);
end
fprintf(fid, "\n## Notes\n\n");
fprintf(fid, "- External load-current change remains a disturbance generated by the test harness current source in the derived copy.\n");
fprintf(fid, "- AI/table logic does not command gates directly. Supervisory tokens are projected into IQCOT request/Ton parameters, and the deterministic active-phase event manager may apply a residual-qualified gate-enable safety mask in the derived model.\n");
fprintf(fid, "- Active Lambda remains disabled in E040-S1 preflight.\n");
end

function writeSignalAvailability(logs, csvPath)
names = requiredSignalsForAudit();
available = false(numel(names), 1);
for idx = 1:numel(names)
    available(idx) = ~isempty(optionalSignal(logs, names(idx)));
end
signal_name = names(:); %#ok<NASGU>
is_available = available(:); %#ok<NASGU>
writetable(table(signal_name, is_available), csvPath);
end

function names = requiredSignalsForAudit()
names = ["Vout", "Iload", ...
    "IL1", "IL2", "IL3", "IL4", ...
    "IL_sense1", "IL_sense2", "IL_sense3", "IL_sense4", ...
    "REQ1", "REQ2", "REQ3", "REQ4", ...
    "REQ_raw1", "REQ_raw2", "REQ_raw3", "REQ_raw4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "REQ_reject_reason", ...
    "QH1", "QH2", "QH3", "QH4", "QL1", "QL2", "QL3", "QL4", ...
    "phase_idx", "logical_slot", "physical_phase_selected", ...
    "active_phase_set", "N_active", ...
    "phase_shed_request", "phase_shed_accept", "phase_shed_reject", ...
    "phase_shed_reject_reason", "shed_state", "shed_transfer_progress", ...
    "disabled_phase_current_sum", "commit_armed", "commit_done", ...
    "shed_commit_count", "fallback_4ph_triggered", "fallback_reason", ...
    "fallback_count", "fallback_4ph_count", ...
    "phase_gate_enable1", "phase_gate_enable2", "phase_gate_enable3", "phase_gate_enable4", ...
    "residual_current_phase2_A", "residual_current_phase4_A", ...
    "residual_current_threshold", "residual_current_check", ...
    "dwell_timer", "post_reentry_shed_delay_timer", ...
    "order_relock_state", "order_relock_window_done", ...
    "phase_order_error_rate_window", "protect_state", "reentry_state", ...
    "balance_recovery_state", "a_S_enable_after_shed", "a_S_mode", ...
    "Ton_cmd1", "Ton_cmd2", "Ton_cmd3", "Ton_cmd4", ...
    "Ton_actual1", "Ton_actual2", "Ton_actual3", "Ton_actual4", ...
    "Ton_trim1", "Ton_trim2", "Ton_trim3", "Ton_trim4", ...
    "Ton_trim_usage", "Lambda_i", "Lambda_trim_usage", "area_int_i", ...
    "current_limit_hit", "guard_clamp_count"];
end

function writeVariantReport(reportPath, modelFile, spec, row, auditCsv, availabilityCsv, waveCsv)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "E040-S1 tests whether staged load-share transfer and disabled-phase drain can avoid the E040-S0 failure mode, where phases were removed before they were safely unloaded. The supervisor does not command gates or external load-current slew.\n\n");
fprintf(fid, "## Derived Model\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Fixed Case\n\n`40A -> 20A`, initial four phases, target mask `1010`, nominal DCR/sense gains, active Lambda disabled.\n\n");
fprintf(fid, "## Key Guard Parameters\n\n");
fprintf(fid, "- `shed_transfer_window = %.6g us`\n", 1e6 * spec.shed_transfer_window_s);
fprintf(fid, "- `disabled_phase_drain_timeout = %.6g us`\n", 1e6 * spec.disabled_phase_drain_timeout_s);
fprintf(fid, "- `residual_current_threshold = %.6g A`\n", spec.residual_current_threshold_A);
fprintf(fid, "- `remaining_phase_current_limit_guard = %.6g A`\n", spec.remaining_phase_current_limit_guard_A);
fprintf(fid, "- `shed_undershoot_budget = %.6g mV`\n", 1e3 * spec.shed_undershoot_budget_V);
fprintf(fid, "- `active Lambda = disabled`\n\n");
fprintf(fid, "## Output Files\n\n");
fprintf(fid, "- Scheduler audit CSV: `%s`\n", slashPath(auditCsv));
fprintf(fid, "- Signal availability CSV: `%s`\n", slashPath(availabilityCsv));
fprintf(fid, "- Wave sample CSV: `%s`\n\n", slashPath(waveCsv));
fprintf(fid, "## Metrics\n\n");
writeMetricsMarkdownTable(fid, row);
fprintf(fid, "## Per-Run Classification Hint\n\n`%s`\n", row.classification_hint(1));
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Baseline path: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n");
fprintf(fid, "- Error: `%s`\n", truncateText(message, 4000));
end

function writeBlockedReport(reportPath, row)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S1 R3 Commit And Relock\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Status\n\n`BLOCKED_BY_R2_PREFLIGHT`\n\n");
fprintf(fid, "`%s`\n", row.classification_hint(1));
end

function writeSummary(summaryPath, rows, classification, detail, metricsCsv, baselineAuditPath)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S1 Staged Shed-Handoff Summary\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Local derived-Simulink preflight for `40A -> 20A`, `4 -> 2` active-phase shed only. The baseline source is `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx` and is not modified.\n\n");
fprintf(fid, "## Baseline Audit\n\n`%s`\n\n", slashPath(baselineAuditPath));
fprintf(fid, "## Metrics CSV\n\n`%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Interpretation\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: success `%d`, N_final `%.6g`, active_set `%s`, commit_count `%.6g`, fallback_count `%.6g`, dropped_REQ `%.6g`, inactive_REQ `%.6g`, residual `%s`, hint `%s`.\n", ...
        rows.variant(idx), rows.success(idx), rows.N_active_final(idx), ...
        rows.actual_active_phase_set_final(idx), rows.shed_commit_count(idx), ...
        rows.fallback_4ph_count(idx), rows.dropped_REQ_count(idx), ...
        rows.inactive_phase_REQ_count(idx), rows.residual_current_check(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n## Classification\n\n`%s`\n\n%s\n\n", classification, detail);
fprintf(fid, "## Claim Boundary\n\n");
if classification == "MODEL_CONFIRMED"
    fprintf(fid, "Allowed local claim: in the local ideal IQCOT derived model, staged load-share transfer, disabled-phase drain, atomic commit, and two-phase relock enable the tested `40A -> 20A`, `4 -> 2` handoff while preserving REQ integrity and residual-current qualification. This remains Simulink-only evidence.\n\n");
else
    fprintf(fid, "The evidence is not yet broad shed validation. The current S1 result should be used to revise transfer rate, drain timeout, residual threshold, commit boundary, fallback logic, or post-shed recovery gates before expanding cases.\n\n");
end
fprintf(fid, "Forbidden claims remain: broad active-phase robustness, arbitrary 1/2/4 scheduling, severe shed behavior, active Lambda control, efficiency gain, hardware, HIL, board-level, or silicon validation.\n");
end

function writeWaveformAudit(auditPath, rows, classification, experimentRoot)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S1 Waveform And Scheduler Audit\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Signal Boundary\n\n");
fprintf(fid, "The derived models log voltage, load, inductor currents, gate commands, raw/accepted REQ, active-phase state, staged shed state, commit/fallback flags, residual-current guards, order relock, Ton trim, and Lambda usage. Per-phase Ton command logs are exported as `Ton_cmd1..4`; active Lambda remains disabled and `Lambda_trim_usage` must stay zero.\n\n");
fprintf(fid, "## Required Audit Table\n\n");
fprintf(fid, "Each per-variant scheduler audit CSV uses accepted-event rows with columns: `event_index`, `time_us`, `shed_state`, `active_phase_set`, `N_active`, `logical_slot`, `physical_phase_selected`, `REQ_in_phase`, `REQ_accept_phase`, `REQ_reject_reason`, `phase_idx_before`, `phase_idx_after`, `commit_armed`, `commit_done`, `fallback_4ph_triggered`, `fallback_reason`. Raw-vs-accepted counts in the metrics CSV are used to check dropped requests and inactive accepted events.\n\n");
fprintf(fid, "## Per-Variant Files\n\n");
for idx = 1:height(rows)
    prefix = filePrefixForVariant(rows.variant(idx));
    fprintf(fid, "- `%s`: scheduler `%s`, signals `%s`, wave `%s`\n", rows.variant(idx), ...
        slashPath(fullfile(experimentRoot, prefix + "_scheduler_audit.csv")), ...
        slashPath(fullfile(experimentRoot, prefix + "_signal_availability.csv")), ...
        slashPath(fullfile(experimentRoot, prefix + "_wave_sample.csv")));
end
fprintf(fid, "\n## Metrics Snapshot\n\n");
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "## Missing Signal Rule\n\nUnavailable signals are recorded in each `*_signal_availability.csv`. Metrics are not fabricated when a signal is unavailable; failed collection is classified as `IMPLEMENTATION_ISSUE`.\n");
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | N init | N final | Active final | Commit | Fallback | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %s | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %s | %.6g | %.6g | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.N_active_initial(idx), ...
        rows.N_active_final(idx), rows.actual_active_phase_set_final(idx), ...
        rows.shed_commit_count(idx), rows.fallback_4ph_count(idx), ...
        rows.peak_undershoot_mV(idx), rows.final_Vout_error_mV(idx), ...
        rows.residual_current_phase2_A(idx), rows.residual_current_phase4_A(idx), ...
        rows.residual_current_check(idx), rows.phase_order_error_rate_post_shed(idx), ...
        rows.dropped_REQ_count(idx), rows.inactive_phase_REQ_count(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function exportWaveSample(logs, spec, csvPath)
[t, vout] = signalSeries(logs, "Vout");
[ti, iload] = signalSeries(logs, "Iload");
[tn, nActive] = signalSeries(logs, "N_active");
timeGrid = unique([t(:); ti(:); tn(:)]);
maxRows = 30000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
out = table(1e6 * (timeGrid - spec.t_load_step), ...
    interp1(t, vout, timeGrid, "linear", "extrap"), ...
    interp1(ti, iload, timeGrid, "previous", "extrap"), ...
    interp1(tn, nActive, timeGrid, "previous", "extrap"), ...
    'VariableNames', {'time_after_step_us', 'Vout', 'Iload', 'N_active'});
for phase = 1:4
    out.("IL" + phase) = interpRequired(logs, "IL" + phase, timeGrid, "linear");
    out.("QH" + phase) = interpRequired(logs, "QH" + phase, timeGrid, "previous");
    out.("REQ_raw" + phase) = interpOptionalSignal(logs, "REQ_raw" + phase, timeGrid);
    out.("REQ_accept" + phase) = interpOptionalSignal(logs, "REQ_accept" + phase, timeGrid);
    out.("Ton_cmd" + phase) = interpOptionalSignal(logs, "Ton_cmd" + phase, timeGrid);
    out.("Ton_trim" + phase) = interpOptionalSignal(logs, "Ton_trim" + phase, timeGrid);
end
for name = ["active_phase_set", "shed_state", "shed_transfer_progress", ...
        "disabled_phase_current_sum", "commit_armed", "commit_done", ...
        "fallback_4ph_triggered", "fallback_reason", "residual_current_check", ...
        "phase_gate_enable1", "phase_gate_enable2", "phase_gate_enable3", "phase_gate_enable4", ...
        "order_relock_state", "order_relock_window_done", ...
        "a_S_enable_after_shed", "a_S_mode", "current_limit_hit"]
    out.(name) = interpOptionalSignal(logs, name, timeGrid);
end
writetable(out, csvPath);
end

function values = interpRequired(logs, name, timeGrid, method)
[t, data] = signalSeries(logs, name);
values = interp1(t, data, timeGrid, method, "extrap");
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
values = interp1(t, data, timeGrid, "previous", "extrap");
end

function count = inactiveAcceptedReqCount(auditRows)
count = 0;
for idx = 1:height(auditRows)
    activeText = char(auditRows.active_phase_set(idx));
    phase = round(auditRows.physical_phase_selected(idx));
    if phase < 1 || phase > strlength(auditRows.active_phase_set(idx))
        count = count + 1;
    elseif activeText(phase) ~= '1'
        count = count + 1;
    end
end
end

function count = rawReqCount(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "REQ_raw" + phase, startTime, endTime);
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
values = values(:);
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

function phase = rawReqPhaseAt(logs, t)
phase = 0;
for idx = 1:4
    if valueAtOptional(logs, "REQ_raw" + idx, t, 0) > 0.5
        phase = idx;
        return;
    end
end
end

function value = valueAtOrNaN(logs, name, t)
if isnan(t)
    value = NaN;
else
    value = valueAtOptional(logs, name, t, NaN);
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

function value = lastNonzeroOptional(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = 0;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime & abs(values) > 0;
if any(mask)
    idx = find(mask, 1, "last");
    value = values(idx);
else
    value = 0;
end
end

function valueUs = firstHighTimeUs(logs, name, startTime, endTime)
valueUs = firstThresholdTimeUs(logs, name, 0.5, startTime, endTime);
end

function valueUs = firstStateTimeUs(logs, name, stateValue, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    valueUs = NaN;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime & round(values) == stateValue;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
else
    valueUs = NaN;
end
end

function valueUs = firstThresholdTimeUs(logs, name, threshold, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    valueUs = NaN;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime & values >= threshold;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
else
    valueUs = NaN;
end
end

function valueUs = firstDrainDoneUs(logs, spec)
sig = optionalSignal(logs, "residual_current_check");
if isempty(sig)
    valueUs = NaN;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
startTime = spec.t_load_step + spec.shed_transfer_window_s;
endTime = spec.stop_time;
mask = t >= startTime & t <= endTime & values > 0.5;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - spec.t_load_step);
else
    valueUs = NaN;
end
end

function text = activeSetStringAt(logs, t)
sig = optionalSignal(logs, "active_phase_set");
if isempty(sig)
    text = "1111";
    return;
end
time = sig.Values.Time(:);
data = orientMatrix(squeeze(double(sig.Values.Data)), 4);
vals = zeros(1, 4);
for idx = 1:4
    vals(idx) = interp1(time, data(:, idx), t, "previous", "extrap");
end
text = sprintf("%d%d%d%d", vals > 0.5);
end

function mask = finalActiveMask(logs, startTime, endTime)
sig = optionalSignal(logs, "active_phase_set");
if isempty(sig)
    mask = [true, true, true, true];
    return;
end
t = sig.Values.Time(:);
data = orientMatrix(squeeze(double(sig.Values.Data)), 4);
timeMask = t >= startTime & t <= endTime;
if any(timeMask)
    vals = mean(data(timeMask, :), 1, "omitnan");
else
    vals = data(end, :);
end
mask = vals > 0.5;
if ~any(mask)
    mask = [true, true, true, true];
end
end

function out = currentMetrics(logs, prefix, activeMask, startTime, endTime)
means = NaN(1, 4);
for phase = 1:4
    [t, values] = signalSeries(logs, prefix + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        means(phase) = mean(values(mask), "omitnan");
    end
end
activeMeans = means(activeMask);
err = activeMeans - mean(activeMeans, "omitnan");
out = struct();
out.max_imbalance = max(abs(err));
out.rms_imbalance = sqrt(mean(err.^2, "omitnan"));
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

function value = meanWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask)
    value = mean(y(mask), "omitnan");
else
    value = NaN;
end
end

function peak = remainingPhasePeak(logs, startTime, endTime)
peak = -inf;
for phase = [1, 3]
    [t, values] = signalSeries(logs, "IL" + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        peak = max(peak, max(abs(values(mask))));
    end
end
if isinf(peak)
    peak = NaN;
end
end

function peak = maxPhaseCurrent(logs, startTime, endTime)
peak = -inf;
for phase = 1:4
    [t, values] = signalSeries(logs, "IL" + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        peak = max(peak, max(abs(values(mask))));
    end
end
if isinf(peak)
    peak = NaN;
end
end

function usage = trimUsage(logs, prefix, limitValue, startTime, endTime)
if limitValue <= 0
    usage = 0;
    return;
end
peak = 0;
for phase = 1:4
    peak = max(peak, maxOptionalSignal(logs, prefix + phase, startTime, endTime));
end
usage = peak / limitValue;
end

function peak = maxOptionalSignal(logs, name, startTime, endTime)
if isnan(startTime)
    startTime = 0;
end
sig = optionalSignal(logs, name);
if isempty(sig)
    peak = 0;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime;
if any(mask)
    peak = max(abs(values(mask)));
else
    peak = 0;
end
end

function absTime = timeFromUs(spec, timeUs)
if isnan(timeUs)
    absTime = NaN;
else
    absTime = spec.t_load_step + timeUs * 1e-6;
end
end

function t = residualEvalTime(spec, metrics, commitAbsTime)
if ~isnan(commitAbsTime)
    t = commitAbsTime;
elseif ~isnan(metrics.disabled_phase_drain_done_us)
    t = spec.t_load_step + metrics.disabled_phase_drain_done_us * 1e-6;
else
    t = spec.stop_time - 1e-9;
end
end

function text = residualCheckText(metrics)
if isnan(metrics.residual_current_phase2_A) || isnan(metrics.residual_current_phase4_A) || ...
        isnan(metrics.residual_current_threshold_A) || metrics.residual_current_threshold_A <= 0
    text = "na";
    return;
end
residualMax = max(abs([metrics.residual_current_phase2_A, metrics.residual_current_phase4_A]));
if residualMax <= metrics.residual_current_threshold_A
    text = "pass";
else
    text = "fail";
end
end

function [time, values] = signalSeries(logs, name)
sig = optionalSignal(logs, name);
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

function present = hasGotoTag(modelName, tagName)
try
    present = ~isempty(find_system(modelName, "FindAll", "on", ...
        "Type", "Block", "GotoTag", char(tagName)));
catch
    try
        blocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on");
        present = false;
        for idx = 1:numel(blocks)
            try
                if strcmp(get_param(blocks{idx}, "GotoTag"), char(tagName))
                    present = true;
                    return;
                end
            catch
            end
        end
    catch
        present = false;
    end
end
end

function rows = appendRow(rows, row)
if isempty(rows)
    rows = row;
else
    rows = [rows; row]; %#ok<AGROW>
end
end

function columns = metricColumns()
columns = {'variant','success','N_active_initial','N_active_final', ...
    'target_active_phase_set','actual_active_phase_set_final', ...
    'shed_request_count','shed_accept_count','shed_commit_count', ...
    'shed_reject_count','fallback_4ph_count','shed_request_time_us', ...
    'load_share_transfer_start_us','load_share_transfer_done_us', ...
    'disabled_phase_drain_done_us','shed_commit_time_us', ...
    'order_relock_done_us','a_S_enable_time_us','peak_overshoot_mV', ...
    'peak_undershoot_mV','final_Vout_error_mV','Vout_ripple_pp_mV', ...
    'settling_time_us','IL1_at_commit_A','IL2_at_commit_A', ...
    'IL3_at_commit_A','IL4_at_commit_A','residual_current_phase2_A', ...
    'residual_current_phase4_A','residual_current_threshold_A', ...
    'residual_current_check','remaining_phase_current_peak_A', ...
    'current_limit_hit','real_max_current_imbalance_A', ...
    'real_rms_current_imbalance_A','sensed_max_current_imbalance_A', ...
    'sensed_rms_current_imbalance_A','phase_order_error_rate_pre_shed', ...
    'phase_order_error_rate_during_transfer', ...
    'phase_order_error_rate_during_commit', ...
    'phase_order_error_rate_post_shed','REQ_count','accepted_REQ_count', ...
    'dropped_REQ_count','inactive_phase_REQ_count','REQ_reject_count', ...
    'Ton_trim_usage','post_shed_aS_mode','Lambda_trim_usage', ...
    'shed_state_final','fallback_reason','classification_hint'};
end

function prefix = filePrefixForVariant(variant)
variant = string(variant);
if variant == "S1-R0"
    prefix = "e040_s1_r0_fixed4";
elseif variant == "S1-R1"
    prefix = "e040_s1_r1_immediate_shed";
elseif variant == "S1-R2"
    prefix = "e040_s1_r2_transfer_drain";
elseif variant == "S1-R3"
    prefix = "e040_s1_r3_commit_relock";
else
    prefix = "e040_s1_unknown";
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

function text = truncateText(text, maxLen)
text = string(text);
if strlength(text) > maxLen
    text = extractBefore(text, maxLen) + "...";
end
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
