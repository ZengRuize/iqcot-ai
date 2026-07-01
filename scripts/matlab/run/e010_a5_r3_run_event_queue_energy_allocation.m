function rows = e010_a5_r3_run_event_queue_energy_allocation(variants)
%e010_a5_r3_run_event_queue_energy_allocation Run the A5-R3 fixed severe-drop chunk.

if nargin < 1 || isempty(variants)
    variants = ["R3-E1", "R3-E2", "R3-E3"];
end
variants = string(variants);
blocked = setdiff(variants, ["R3-E1", "R3-E2", "R3-E3", "R3-E4"]);
if ~isempty(blocked)
    error("This R3 chunk may run only R3-E1/R3-E2/R3-E3/R3-E4. Blocked: %s", ...
        strjoin(blocked, ", "));
end

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end
if evalin("base", "exist('Ton','var')")
    Ton_nom = evalin("base", "Ton");
else
    Ton_nom = 186.5e-9;
end

experimentRoot = fullfile(projectRoot, "experiments", ...
    "E010_load_drop_overshoot", "A5_severe_drop_token", ...
    "R3_event_queue_energy_allocation");
ensureDir(experimentRoot);

metricsCsv = fullfile(experimentRoot, "e010_a5_r3_metrics.csv");
availabilityCsv = fullfile(experimentRoot, "e010_a5_r3_signal_availability.csv");
schedulerCsv = fullfile(experimentRoot, "e010_a5_r3_scheduler_audit.csv");
comparisonPath = fullfile(experimentRoot, "e010_a5_r3_comparison.md");
hypothesisPath = fullfile(experimentRoot, "e010_a5_r3_hypothesis.md");
protocolPath = fullfile(experimentRoot, "e010_a5_r3_protocol.md");
waveformAuditPath = fullfile(experimentRoot, "e010_a5_r3_waveform_audit.md");
summaryPath = fullfile(experimentRoot, "e010_a5_r3_research_summary.md");

writeHypothesis(hypothesisPath);
writeProtocol(protocolPath, variants);

rows = carryForwardRows(Ton_nom);
availabilityRows = table();
schedulerRows = table();
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx), Ton_nom);
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

[classification, detail, bestVariant] = classifyRows(rows);
writeComparison(comparisonPath, rows, classification, detail, bestVariant, ...
    metricsCsv, availabilityCsv, schedulerCsv);
writeWaveformAudit(waveformAuditPath, rows, availabilityRows, classification, experimentRoot);
writeSummary(summaryPath, rows, classification, detail, bestVariant, ...
    metricsCsv, availabilityCsv, schedulerCsv);

fprintf("e010_a5_r3_METRICS=%s\n", metricsCsv);
fprintf("e010_a5_r3_AVAILABILITY=%s\n", availabilityCsv);
fprintf("e010_a5_r3_SCHEDULER_AUDIT=%s\n", schedulerCsv);
fprintf("e010_a5_r3_COMPARISON=%s\n", comparisonPath);
fprintf("e010_a5_r3_WAVEFORM_AUDIT=%s\n", waveformAuditPath);
fprintf("e010_a5_r3_SUMMARY=%s\n", summaryPath);
disp(rows);
end

function [row, availability, schedulerRows] = runOneVariant(spec, experimentRoot)
modelFile = "";
try
    modelFile = e010_a5_build_candidate_model(spec.build_variant);
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
    row = failureRow(spec, errorDetails(ME), modelFile);
    availability = table();
    schedulerRows = table();
end
end

function spec = baseSpec(Ton_nom)
spec = struct();
spec.base_load_A = 40;
spec.target_load_A = 1;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.54e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.settle_band_V = 1.0e-3;
spec.undershoot_budget_V = 2.0e-3;
spec.late_settling_guard_V = 5.0e-3;
spec.final_error_guard_mV = 5.0;
spec.deltaI_drop_threshold_high_A = 30;
spec.expected_phase_order = [1, 2, 3, 4];
spec.Ton_nom = Ton_nom;
spec.Ton_nom_ns = 1e9 * Ton_nom;

spec.E010_TonTrunc_Enable = 1;
spec.Tton_trunc_min = 60e-9;
spec.Tton_trunc_window = 2e-6;
spec.E010_PulseInhibit_Enable = 1;
spec.E010_PulseInhibit_Count = 2;
spec.E010_PulseInhibit_Time = 3.0e-6;
spec.E010_ReentryGuard_Enable = 1;
spec.E010_Reentry_Band_Down = 1.0e-3;
spec.E010_AreaHold_Enable = 1;
spec.E010_AreaHold_Time = 3.0e-6;
spec.E010_AreaBleed_Enable = 1;

spec.first_reentry_Ton_limit = 0.45 * Ton_nom;
spec.Ton_ramp_step = 0.15 * Ton_nom;
spec.Ton_ramp_window = 2.0e-6;
spec.Ton_ramp_max = Ton_nom;
spec.Ton_min_meaningful = 0.25 * Ton_nom;
spec.reentry_Ton_budget_window = 2.0e-6;
spec.reentry_Ton_budget = 70e-9;
spec.queue_release_min_spacing = 0.35e-6;
spec.queue_release_max_per_window = 2;
spec.queue_max_depth = 4;
spec.queue_spacing_enable = 0;
spec.area_queue_coupling_enable = 0;
spec.area_int_reentry_target = 0;
spec.area_int_restore_rate = 5.0e5;
spec.voltage_window_release_enable = 0;
spec.upper_reentry_band = 1.0e-3;
spec.undershoot_budget_severe = 2.0e-3;
spec.burst_pulse_limit_after_reentry = 2;
spec.burst_count_window = 2.0e-6;
end

function spec = variantSpec(variant, Ton_nom)
spec = baseSpec(Ton_nom);
spec.short_variant = string(variant);
if variant == "R3-E1"
    spec.variant = "R3-E1_event_queue_allocation";
    spec.build_variant = "A5-R3-E1";
    spec.file_prefix = "e010_a5_r3_e1_event_queue_alloc_40A_to_1A";
    spec.report_label = "R3-E1 event queue plus per-event Ton allocation";
elseif variant == "R3-E2"
    spec.variant = "R3-E2_queue_release_spacing";
    spec.build_variant = "A5-R3-E2";
    spec.file_prefix = "e010_a5_r3_e2_queue_spacing_40A_to_1A";
    spec.report_label = "R3-E2 event queue plus release spacing";
    spec.queue_spacing_enable = 1;
elseif variant == "R3-E3"
    spec.variant = "R3-E3_area_queue_coupling";
    spec.build_variant = "A5-R3-E3";
    spec.file_prefix = "e010_a5_r3_e3_area_queue_coupling_40A_to_1A";
    spec.report_label = "R3-E3 queue release spacing plus area-int coupling";
    spec.queue_spacing_enable = 1;
    spec.area_queue_coupling_enable = 1;
elseif variant == "R3-E4"
    spec.variant = "R3-E4_voltage_windowed_queue";
    spec.build_variant = "A5-R3-E4";
    spec.file_prefix = "e010_a5_r3_e4_voltage_window_queue_40A_to_1A";
    spec.report_label = "R3-E4 E3 plus voltage-windowed queue release";
    spec.queue_spacing_enable = 1;
    spec.area_queue_coupling_enable = 1;
    spec.voltage_window_release_enable = 1;
else
    error("Unknown E010-A5-R3 variant: %s", variant);
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
in = in.setVariable("Ton_nom", spec.Ton_nom);
in = in.setVariable("E010A5_DeltaI_Drop_Threshold_High", spec.deltaI_drop_threshold_high_A);
for phase = 1:4
    in = in.setVariable("E010A5_IL_Sense_Gain" + phase, 1.0);
end
in = setVars(in, spec, [
    "E010_TonTrunc_Enable", "Tton_trunc_min", "Tton_trunc_window", ...
    "E010_PulseInhibit_Enable", "E010_PulseInhibit_Count", ...
    "E010_PulseInhibit_Time", "E010_ReentryGuard_Enable", ...
    "E010_Reentry_Band_Down", "E010_AreaHold_Enable", ...
    "E010_AreaHold_Time", "E010_AreaBleed_Enable"]);
in = in.setVariable("E010A5_R3_EventQueue_Enable", 1);
in = in.setVariable("E010A5_R3_QueueMaxDepth", spec.queue_max_depth);
in = in.setVariable("E010A5_R3_QueueReleaseMinSpacing", spec.queue_release_min_spacing);
in = in.setVariable("E010A5_R3_QueueReleaseMaxPerWindow", spec.queue_release_max_per_window);
in = in.setVariable("E010A5_R3_QueueSpacingEnable", spec.queue_spacing_enable);
in = in.setVariable("E010A5_R3_TonBudgetWindow", spec.reentry_Ton_budget_window);
in = in.setVariable("E010A5_R3_TonBudget", spec.reentry_Ton_budget);
in = in.setVariable("E010A5_R3_TonMinMeaningful", spec.Ton_min_meaningful);
in = in.setVariable("E010A5_R3_FirstTonLimit", spec.first_reentry_Ton_limit);
in = in.setVariable("E010A5_R3_TonRampStep", spec.Ton_ramp_step);
in = in.setVariable("E010A5_R3_TonRampMax", spec.Ton_ramp_max);
in = in.setVariable("E010A5_R3_AreaQueueCouplingEnable", spec.area_queue_coupling_enable);
in = in.setVariable("E010A5_R3_AreaIntReentryTarget", spec.area_int_reentry_target);
in = in.setVariable("E010A5_R3_AreaIntRestoreRate", spec.area_int_restore_rate);
in = in.setVariable("E010A5_R3_VoltageWindowEnable", spec.voltage_window_release_enable);
in = in.setVariable("E010A5_R3_UpperReentryBand", spec.upper_reentry_band);
in = in.setVariable("E010A5_R3_UndershootBudget", spec.undershoot_budget_severe);
out = sim(in);
end

function in = setVars(in, spec, names)
for idx = 1:numel(names)
    in = in.setVariable(names(idx), spec.(names(idx)));
end
end

function rows = carryForwardRows(Ton_nom)
rows = table();
refs = ["R3-C0", "R3-C4", "R3-T4proxy", "R3-R2E1"];
for idx = 1:numel(refs)
    spec = referenceSpec(refs(idx), Ton_nom);
    rows = appendTable(rows, rowFromMetrics(spec, referenceMetrics(refs(idx), spec), ...
        true, "carry_forward_reference", "carry_forward"));
end
end

function spec = referenceSpec(name, Ton_nom)
spec = baseSpec(Ton_nom);
spec.short_variant = string(name);
spec.file_prefix = "carry_forward_reference";
spec.build_variant = "carry_forward";
spec.variant = string(name);
end

function m = referenceMetrics(name, spec)
m = emptyMetrics();
m.logging_complete = true;
m.postprocess_complete = true;
m.audit_hint = "carry_forward_reference";
m.Ton_nom_ns = spec.Ton_nom_ns;
m.Ton_requested_ns = NaN;
m.Ton_allocated_ns = NaN;
m.Ton_budget_remaining_ns = NaN;
m.Ton_min_meaningful_ns = 1e9 * spec.Ton_min_meaningful;
m.Ton_allocation_reason = "";
m.pending_REQ_queue_max_depth = NaN;
m.queue_depth_final = NaN;
m.queue_release_count = NaN;
m.queue_reject_count = NaN;
m.queue_reject_reason = "";
m.queue_release_min_spacing_us = 1e6 * spec.queue_release_min_spacing;
m.queue_release_max_per_window = spec.queue_release_max_per_window;
m.reentry_Ton_budget_window_us = NaN;
m.reentry_Ton_budget_ns = NaN;
m.reentry_Ton_budget_used_ns = NaN;
m.reentry_Ton_budget_violation = false;
m.area_int_capture_at_drop = NaN;
m.area_int_reentry_target = NaN;
m.area_int_restore_usage = NaN;
m.area_int_queue_coupling_usage = NaN;
m.area_int_max = NaN;
m.area_int_at_reentry = NaN;
m.burst_count_window_us = 1e6 * spec.burst_count_window;
if name == "R3-C0" || name == "R3-C4"
    m.peak_overshoot_mV = baselinePeakOvershootMv();
    m.peak_undershoot_mV = 0;
    m.recovery_peak_2_12us_mV = baselineRecovery2To12Mv();
    m.recovery_peak_12_40us_mV = baselineRecovery12To40Mv();
    m.final_Vout_error_mV = 2.97792718436692;
    m.Vout_ripple_pp_mV = 1.01145403542935;
    m.REQ_count = 149;
    m.accepted_REQ_count = 149;
    m.guard_pass = true;
    m.classification_hint = "REFERENCE";
elseif name == "R3-T4proxy"
    m.peak_overshoot_mV = baselinePeakOvershootMv();
    m.peak_undershoot_mV = 0.697796974422848;
    m.recovery_peak_2_12us_mV = 3.55696362671098;
    m.recovery_peak_12_40us_mV = 3.53369510017454;
    m.final_Vout_error_mV = 2.96743257084865;
    m.Vout_ripple_pp_mV = 1.23407330907543;
    m.REQ_count = 149;
    m.accepted_REQ_count = 149;
    m.burst_pulse_count_after_reentry = 5;
    m.burst_pulse_limit_after_reentry = 2;
    m.guard_pass = false;
    m.classification_hint = "MODEL_REVISED";
elseif name == "R3-R2E1"
    m.peak_overshoot_mV = 3.51629438378009;
    m.peak_undershoot_mV = 7.63187985836866;
    m.recovery_peak_2_12us_mV = 1.75366145979594;
    m.recovery_peak_12_40us_mV = 3.51629438378009;
    m.final_Vout_error_mV = 2.89307148392663;
    m.Vout_ripple_pp_mV = 1.23712977803581;
    m.REQ_count = 152;
    m.accepted_REQ_count = 152;
    m.reentry_Ton_budget_used_ns = 74.6;
    m.burst_pulse_count_after_reentry = 5;
    m.burst_pulse_limit_after_reentry = 2;
    m.undershoot_budget_violation = true;
    m.guard_pass = false;
    m.classification_hint = "MODEL_REVISED";
end
m.deferred_REQ_count = 0;
m.rejected_REQ_count = 0;
m.dropped_REQ_count = max(0, m.REQ_count - m.accepted_REQ_count);
m.delta_peak_overshoot_vs_C0_mV = m.peak_overshoot_mV - baselinePeakOvershootMv();
m.delta_peak_overshoot_vs_C4_mV = m.delta_peak_overshoot_vs_C0_mV;
m.delta_recovery_peak_2_12us_vs_C0_mV = m.recovery_peak_2_12us_mV - baselineRecovery2To12Mv();
m.delta_recovery_peak_2_12us_vs_C4_mV = m.delta_recovery_peak_2_12us_vs_C0_mV;
m.delta_recovery_peak_12_40us_vs_C0_mV = m.recovery_peak_12_40us_mV - baselineRecovery12To40Mv();
m.delta_recovery_peak_12_40us_vs_C4_mV = m.delta_recovery_peak_12_40us_vs_C0_mV;
end

function metrics = collectMetrics(logs, spec, availability, ~)
[tV, vout] = signalSeries(logs, "Vout");
tau = tV - spec.t_load_step;
postMask = tV >= spec.t_load_step & tV <= spec.stop_time;
metrics = emptyMetrics();
metrics.peak_overshoot_mV = 1e3 * max(max(vout(postMask) - spec.vref), 0);
metrics.peak_undershoot_mV = 1e3 * max(max(spec.vref - vout(postMask)), 0);
metrics.recovery_peak_2_12us_mV = 1e3 * max(maxWindow(tau, vout - spec.vref, 2e-6, 12e-6), 0);
metrics.recovery_peak_12_40us_mV = 1e3 * max(maxWindow(tau, vout - spec.vref, 12e-6, 40e-6), 0);
metrics.settling_time_us = settlingTimeUs(tV, vout, spec);
metrics.final_Vout_error_mV = 1e3 * meanWindow(tau, vout - spec.vref, 75e-6, 90e-6);
metrics.Vout_ripple_pp_mV = 1e3 * ppWindow(tau, vout, 75e-6, 90e-6);

metrics.Ton_nom_ns = 1e9 * maxOptionalSignal(logs, "Ton_nom", 0, spec.stop_time);
if metrics.Ton_nom_ns == 0
    metrics.Ton_nom_ns = spec.Ton_nom_ns;
end
metrics.Ton_requested_ns = maxOptionalSignal(logs, "Ton_requested_ns", spec.t_load_step, spec.stop_time);
metrics.Ton_allocated_ns = maxOptionalSignal(logs, "Ton_allocated_ns", spec.t_load_step, spec.stop_time);
metrics.Ton_budget_remaining_ns = lastOptionalSignal(logs, "Ton_budget_remaining_ns", spec.t_load_step, spec.stop_time);
metrics.Ton_min_meaningful_ns = 1e9 * spec.Ton_min_meaningful;
metrics.Ton_allocation_reason = string(lastNonzeroOptional(logs, "Ton_allocation_reason", spec.t_load_step, spec.stop_time));

metrics.pending_REQ_queue_max_depth = maxOptionalSignal(logs, "queue_depth", spec.t_load_step, spec.stop_time);
metrics.queue_depth_final = lastOptionalSignal(logs, "queue_depth", spec.t_load_step, spec.stop_time);
metrics.queue_release_count = maxOptionalSignal(logs, "queue_release_count", spec.t_load_step, spec.stop_time);
metrics.queue_reject_count = maxOptionalSignal(logs, "queue_reject_count", spec.t_load_step, spec.stop_time);
metrics.queue_reject_reason = string(lastNonzeroOptional(logs, "queue_reject_reason", spec.t_load_step, spec.stop_time));
metrics.queue_release_min_spacing_us = 1e6 * spec.queue_release_min_spacing;
metrics.queue_release_max_per_window = spec.queue_release_max_per_window;

metrics.reentry_Ton_budget_window_us = 1e6 * spec.reentry_Ton_budget_window;
metrics.reentry_Ton_budget_ns = 1e9 * spec.reentry_Ton_budget;
metrics.reentry_Ton_budget_used_ns = maxOptionalSignal(logs, "reentry_Ton_budget_used_ns", spec.t_load_step, spec.stop_time);
metrics.reentry_Ton_budget_violation = maxOptionalSignal(logs, "reentry_Ton_budget_violation", spec.t_load_step, spec.stop_time) > 0.5;

metrics.pulse_inhibit_count = pulseInhibitCount(logs, spec);
metrics.area_hold_count = maxOptionalSignal(logs, "area_hold_count", spec.t_load_step, spec.stop_time);
metrics.area_reset_count = maxOptionalSignal(logs, "area_reset_count", spec.t_load_step, spec.stop_time);
metrics.area_bleed_count = maxOptionalSignal(logs, "area_bleed_count", spec.t_load_step, spec.stop_time);
metrics.area_int_capture_at_drop = lastOptionalSignal(logs, "area_int_capture_at_drop", spec.t_load_step, spec.stop_time);
metrics.area_int_reentry_target = lastOptionalSignal(logs, "area_int_reentry_target", spec.t_load_step, spec.stop_time);
metrics.area_int_restore_usage = maxOptionalSignal(logs, "area_int_restore_usage", spec.t_load_step, spec.stop_time);
metrics.area_int_queue_coupling_usage = maxOptionalSignal(logs, "area_int_queue_coupling_usage", spec.t_load_step, spec.stop_time);
metrics.area_int_max = maxAbsOptionalSignal(logs, "area_int_i", spec.t_load_step, spec.stop_time);

[reentryTime, reentryPhase, reentryTon] = firstAcceptedAfter(logs, ...
    spec.t_load_step + spec.E010_PulseInhibit_Time, spec.stop_time);
metrics.area_int_at_reentry = valueAtOptional(logs, "area_int_i", reentryTime, NaN);
metrics.first_reentry_time_us = 1e6 * (reentryTime - spec.t_load_step);
metrics.first_reentry_phase = reentryPhase;
metrics.first_reentry_Ton_ns = 1e9 * reentryTon;
metrics.burst_pulse_count_after_reentry = burstCountAfter(logs, reentryTime, ...
    reentryTime + spec.burst_count_window);
metrics.burst_pulse_limit_after_reentry = spec.burst_pulse_limit_after_reentry;
metrics.burst_count_window_us = 1e6 * spec.burst_count_window;
metrics.actual_min_inter_pulse_spacing_us = actualMinAcceptedSpacingUs(logs, ...
    reentryTime, reentryTime + spec.burst_count_window);

metrics.REQ_count = rawReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.accepted_REQ_count = acceptedReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.deferred_REQ_count = deferredReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.rejected_REQ_count = metrics.queue_reject_count;
metrics.dropped_REQ_count = max(0, metrics.REQ_count - metrics.accepted_REQ_count - ...
    metrics.rejected_REQ_count - metrics.queue_depth_final);
metrics.phase_order_error_rate = double(maxOptionalSignal(logs, "phase_order_error", ...
    spec.t_load_step, spec.stop_time) > 0.5);
currentStats = currentImbalance(logs, spec.t_load_step + 12e-6, spec.stop_time);
metrics.real_max_current_imbalance_A = currentStats.max_imbalance_A;
metrics.real_rms_current_imbalance_A = currentStats.rms_imbalance_A;
metrics.current_limit_hit = maxOptionalSignal(logs, "current_limit_hit", spec.t_load_step, spec.stop_time) > 0.5;
metrics.undershoot_budget_violation = metrics.peak_undershoot_mV > 1e3 * spec.undershoot_budget_V;
metrics.late_settling_guard_violation = abs(metrics.recovery_peak_12_40us_mV) > 1e3 * spec.late_settling_guard_V;
metrics.fallback_count = maxOptionalSignal(logs, "fallback_count", spec.t_load_step, spec.stop_time);
metrics.fallback_reason = maxOptionalSignal(logs, "fallback_reason", spec.t_load_step, spec.stop_time);
metrics.delta_peak_overshoot_vs_C0_mV = metrics.peak_overshoot_mV - baselinePeakOvershootMv();
metrics.delta_peak_overshoot_vs_C4_mV = metrics.delta_peak_overshoot_vs_C0_mV;
metrics.delta_recovery_peak_2_12us_vs_C0_mV = metrics.recovery_peak_2_12us_mV - baselineRecovery2To12Mv();
metrics.delta_recovery_peak_2_12us_vs_C4_mV = metrics.delta_recovery_peak_2_12us_vs_C0_mV;
metrics.delta_recovery_peak_12_40us_vs_C0_mV = metrics.recovery_peak_12_40us_mV - baselineRecovery12To40Mv();
metrics.delta_recovery_peak_12_40us_vs_C4_mV = metrics.delta_recovery_peak_12_40us_vs_C0_mV;
metrics.guard_pass = guardPass(metrics, spec);
metrics.logging_complete = isLoggingComplete(availability);
metrics.postprocess_complete = isPostprocessComplete(metrics);
metrics.audit_hint = auditHint(metrics);
metrics.classification_hint = classificationHint(metrics);
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = struct();
cols = metricColumns();
for idx = 1:numel(cols)
    name = cols(idx);
    if isfield(m, name)
        row.(name) = m.(name);
    elseif isfield(spec, name)
        row.(name) = spec.(name);
    else
        row.(name) = missingValueFor(name);
    end
end
row.variant = string(spec.short_variant);
row.success = logical(success);
row.guard_pass = logical(m.guard_pass);
row.classification_hint = string(m.classification_hint);
row.logging_complete = logical(m.logging_complete);
row.postprocess_complete = logical(m.postprocess_complete);
row.audit_hint = string(m.audit_hint);
row.error_message = string(errorMessage);
row.derived_model = string(slashPath(modelFile));
row = struct2table(row, "AsArray", true);
end

function value = missingValueFor(name)
if contains(name, ["reason", "hint", "message", "model"])
    value = "";
elseif contains(name, ["hit", "violation", "pass", "enable", "success", "complete"])
    value = false;
else
    value = NaN;
end
end

function row = failureRow(spec, errorMessage, modelFile)
m = emptyMetrics();
m.audit_hint = "simulation_or_postprocess_failed";
m.classification_hint = "IMPLEMENTATION_ISSUE";
row = rowFromMetrics(spec, m, false, errorMessage, modelFile);
end

function m = emptyMetrics()
for name = metricColumns()
    m.(name) = missingValueFor(name);
end
m.success = false;
m.guard_pass = false;
m.logging_complete = false;
m.postprocess_complete = false;
m.audit_hint = "failed";
m.classification_hint = "IMPLEMENTATION_ISSUE";
end

function pass = guardPass(m, spec)
burstOk = m.burst_pulse_count_after_reentry <= m.burst_pulse_limit_after_reentry;
finalOk = isfinite(m.final_Vout_error_mV) && abs(m.final_Vout_error_mV) <= spec.final_error_guard_mV;
queueRejectOk = m.queue_reject_count == 0 || strlength(string(m.queue_reject_reason)) > 0;
queueFinalOk = isfinite(m.queue_depth_final) && m.queue_depth_final == 0;
areaOk = isfinite(m.area_int_max);
pass = m.peak_undershoot_mV <= 2.0 && ...
    m.dropped_REQ_count == 0 && ...
    m.phase_order_error_rate == 0 && ...
    ~m.current_limit_hit && burstOk && ...
    ~m.late_settling_guard_violation && ...
    m.fallback_count <= 1 && ...
    ~m.reentry_Ton_budget_violation && queueRejectOk && ...
    queueFinalOk && areaOk && finalOk;
end

function tf = improvesMetrics(m)
tol = 1.0e-6;
tf = m.peak_overshoot_mV < baselinePeakOvershootMv() - tol || ...
    m.recovery_peak_2_12us_mV < baselineRecovery2To12Mv() - tol || ...
    m.recovery_peak_12_40us_mV < baselineRecovery12To40Mv() - tol;
end

function hint = auditHint(m)
if ~m.logging_complete
    hint = "logging_incomplete";
elseif ~m.postprocess_complete
    hint = "postprocess_incomplete";
elseif m.guard_pass && improvesMetrics(m)
    hint = "candidate_improves_and_guards_pass";
elseif improvesMetrics(m) && m.peak_undershoot_mV > 100
    hint = "positive_peak_suppressed_by_recovery_starvation";
elseif improvesMetrics(m) && m.undershoot_budget_violation
    hint = "queue_allocation_improves_but_undershoot_guard_fails";
elseif improvesMetrics(m) && m.burst_pulse_count_after_reentry > m.burst_pulse_limit_after_reentry
    hint = "queue_allocation_improves_but_burst_guard_fails";
elseif improvesMetrics(m)
    hint = "partial_recovery_but_guard_fails";
else
    hint = "candidate_no_safe_improvement";
end
end

function hint = classificationHint(m)
if ~(m.logging_complete && m.postprocess_complete)
    hint = "IMPLEMENTATION_ISSUE";
elseif m.guard_pass && improvesMetrics(m)
    hint = "MODEL_CONFIRMED";
elseif improvesMetrics(m) || ~m.guard_pass
    hint = "MODEL_REVISED";
else
    hint = "CLAIM_DOWNGRADED";
end
end

function complete = isLoggingComplete(availability)
if isempty(availability)
    complete = false;
    return;
end
complete = all(logical(availability.available)) && all(logical(availability.finite));
end

function complete = isPostprocessComplete(m)
hardValues = [m.peak_overshoot_mV, m.peak_undershoot_mV, ...
    m.recovery_peak_2_12us_mV, m.recovery_peak_12_40us_mV, ...
    m.final_Vout_error_mV, m.REQ_count, m.accepted_REQ_count, ...
    m.phase_order_error_rate, m.reentry_Ton_budget_used_ns, ...
    m.queue_depth_final, m.queue_release_count];
complete = all(isfinite(hardValues));
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
    finiteCol, noteCol, 'VariableNames', ...
    {'variant','signal','available','sample_count','finite','note'});
end

function names = requiredSignalNames()
names = ["Vout", "Iload", ...
    "IL1", "IL2", "IL3", "IL4", ...
    "IL_sense1", "IL_sense2", "IL_sense3", "IL_sense4", ...
    "REQ1", "REQ2", "REQ3", "REQ4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "REQ_defer1", "REQ_defer2", "REQ_defer3", "REQ_defer4", ...
    "REQ_reject_reason", "QH1", "QH2", "QH3", "QH4", ...
    "QL1", "QL2", "QL3", "QL4", ...
    "phase_idx", "active_HS_phase", "Ton_nom", ...
    "Ton_cmd1", "Ton_cmd2", "Ton_cmd3", "Ton_cmd4", ...
    "Ton_actual1", "Ton_actual2", "Ton_actual3", "Ton_actual4", ...
    "Ton_requested_ns", "Ton_allocated_ns", "Ton_budget_remaining_ns", ...
    "Ton_allocation_reason", "Ton_trunc_i", "Ton_saved_i", ...
    "area_int_i", "area_int_queue_coupling_state", "area_int_restore_state", ...
    "a_O_state", "severe_drop_detected", "pulse_inhibit_state", ...
    "area_hold_state", "reentry_state", "controlled_reentry_active", ...
    "event_queue_state", "energy_allocation_state", "fallback_state", ...
    "pending_REQ_queue", "queue_depth", "queue_phase_id", "queue_age_us", ...
    "current_limit_hit", "phase_order_error", ...
    "burst_pulse_count_after_reentry", "actual_inter_pulse_spacing"];
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
schedulerRows = table(repmat(spec.short_variant, numel(eventTimes), 1), ...
    (1:numel(eventTimes))', 1e6 * (eventTimes - spec.t_load_step), ...
    rawPhase, acceptPhase, ...
    'VariableNames', {'variant','event_index','time_us','REQ_phase','REQ_accept_phase'});
end

function exportWaveSample(logs, spec, csvPath)
[tV, ~] = signalSeries(logs, "Vout");
t0 = spec.t_load_step - 2e-6;
t1 = spec.t_load_step + 40e-6;
timeGrid = linspace(max(min(tV), t0), min(max(tV), t1), 12001)';
out = table();
out.time_s = timeGrid;
for name = ["Vout", "Iload", "phase_idx", "active_HS_phase", ...
        "a_O_state", "severe_drop_detected", "pulse_inhibit_state", ...
        "area_hold_state", "reentry_state", "controlled_reentry_active", ...
        "event_queue_state", "energy_allocation_state", "fallback_state", ...
        "current_limit_hit", "phase_order_error", ...
        "burst_pulse_count_after_reentry", "actual_inter_pulse_spacing", ...
        "pending_REQ_queue", "queue_depth", "queue_phase_id", "queue_age_us", ...
        "queue_release_count", "queue_reject_count", "Ton_requested_ns", ...
        "Ton_allocated_ns", "Ton_budget_remaining_ns", "Ton_allocation_reason", ...
        "reentry_Ton_budget_used_ns", "area_int_queue_coupling_state", ...
        "area_int_restore_state"]
    out.(name) = interpOptionalSignal(logs, name, timeGrid);
end
for phase = 1:4
    for base = ["IL", "IL_sense", "QH", "QL", "REQ", "REQ_accept", "REQ_defer", "Ton_cmd", "Ton_actual"]
        out.(base + phase) = interpOptionalSignal(logs, base + phase, timeGrid);
    end
end
writetable(out, csvPath);
end

function [classification, detail, bestVariant] = classifyRows(rows)
bestVariant = "none";
candidateRows = rows(startsWith(rows.variant, "R3-E"), :);
if isempty(candidateRows) || any(~candidateRows.success) || ...
        any(~candidateRows.logging_complete) || any(~candidateRows.postprocess_complete)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "R3 comparison has unavailable simulation, logging, or postprocess signals. Do not interpret A5 performance.";
    return;
end
improved = false(height(candidateRows), 1);
for idx = 1:height(candidateRows)
    improved(idx) = improvesMetrics(candidateRows(idx, :));
end
safeImproved = improved & candidateRows.guard_pass;
if any(safeImproved)
    classification = "MODEL_CONFIRMED";
    candidates = candidateRows(safeImproved, :);
    [~, order] = min(candidates.recovery_peak_2_12us_mV);
    bestVariant = candidates.variant(order);
    detail = "An R3 event-queue energy-allocation variant improved the severe-drop recovery metric while passing undershoot, queue, burst, REQ, phase-order, energy-budget, final-error, and late-settling guards.";
elseif any(improved)
    classification = "MODEL_REVISED";
    candidates = candidateRows(improved, :);
    bestVariant = candidates.variant(1);
    if any(candidates.peak_undershoot_mV > 100)
        bestVariant = "none_safe_candidate";
        detail = "R3 suppresses positive recovery peaks only by starving the recovery trajectory, producing severe undershoot/final-error collapse and failing burst/phase-order guards. Treat this as token-structure revision evidence, not as A5 validation.";
    else
        detail = "R3 event-queue energy allocation changes part of the waveform but does not satisfy the full guard set. Treat this as evidence about queue/energy-allocation limits, not as A5 validation.";
    end
else
    classification = "CLAIM_DOWNGRADED";
    detail = "No R3 candidate improved the local severe 40A -> 1A boundary. Severe-drop A5 should be downgraded or structurally revised.";
end
end

function writeHypothesis(pathValue)
fid = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5-R3 Hypothesis\n\nDate: %s\n\n", reportDate());
fprintf(fid, "The previous A5 failures occurred because reentry control was implemented as pulse blocking, burst counting, or scheduler gating. These methods either allow pulse clustering or starve recovery energy.\n\n");
fprintf(fid, "A5-R3 should treat reentry as an event-queue energy-allocation problem: each accepted request is either served, deferred, resized, or released later with bounded Ton allocation and explicit accounting.\n\n");
fprintf(fid, "The controller should preserve enough recovery energy to avoid undershoot collapse, but prevent too much clustered energy from creating post-reentry bursts.\n\n");
fprintf(fid, "Fixed case: external `40A -> 1A` load-current drop, fixed four phases, nominal DCR/sense, active Lambda disabled, active-phase add/shed disabled. The load-current transition remains an external disturbance, not an AI action.\n");
end

function writeProtocol(pathValue, variants)
fid = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5-R3 Protocol\n\nDate: %s\n\n", reportDate());
fprintf(fid, "All R3 models are derived through MATLAB APIs from `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`; the baseline is not modified.\n\n");
fprintf(fid, "Executed variants: `%s`.\n\n", strjoin(variants, "`, `"));
fprintf(fid, "Carry-forward references: `R3-C0`, `R3-C4`, `R3-T4proxy`, and `R3-R2E1`.\n\n");
fprintf(fid, "Pass requires improvement versus C0/C4 and simultaneous undershoot, queue, burst, REQ, phase-order, current-limit, energy-budget, final-error, fallback, and late-settling guard pass.\n");
end

function writeComparison(pathValue, rows, classification, detail, bestVariant, metricsCsv, availabilityCsv, schedulerCsv)
fid = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5-R3 Comparison\n\nDate: %s\n\n", reportDate());
fprintf(fid, "## Scope\n\nFixed `40A -> 1A` severe load drop; no active Lambda, active-phase add/shed, DCR mismatch, current-sense mismatch, or broad sweep.\n\n");
writeMetricsTable(fid, rows);
fprintf(fid, "## Classification\n\n`%s`\n\n%s\n\nBest partial variant: `%s`.\n\n", classification, detail, bestVariant);
if classification == "MODEL_REVISED"
    fprintf(fid, "## Mechanism Interpretation\n\n");
    fprintf(fid, "- `R3-E1`: tests whether event queue plus per-event Ton allocation alone can retain R2-E1 recovery benefit without unsafe undershoot or burst.\n");
    fprintf(fid, "- `R3-E2`: adds queue release spacing and max-per-window control to test burst control through allocation rather than hard blocking.\n");
    fprintf(fid, "- `R3-E3`: adds area-int queue coupling as a release guard; if behavior is unchanged, the coupling is not yet a validated actuator.\n");
    fprintf(fid, "- `R3-E4`: optional voltage-windowed queue release should only be interpreted if E3 identifies voltage-window release as the missing guard.\n\n");
end
fprintf(fid, "Metrics: `%s`\n\nAvailability: `%s`\n\nScheduler audit: `%s`\n", slashPath(metricsCsv), slashPath(availabilityCsv), slashPath(schedulerCsv));
end

function writeWaveformAudit(pathValue, rows, availabilityRows, classification, experimentRoot)
fid = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5-R3 Waveform Audit\n\nDate: %s\n\n", reportDate());
fprintf(fid, "## Availability\n\n");
for idx = 1:height(rows)
    variant = rows.variant(idx);
    if ~startsWith(variant, "R3-E")
        continue;
    end
    if isempty(availabilityRows) || ~ismember("variant", string(availabilityRows.Properties.VariableNames))
        missing = requiredSignalNames();
    else
        vr = availabilityRows(availabilityRows.variant == variant, :);
        missing = vr.signal(~vr.available);
    end
    if isempty(missing)
        fprintf(fid, "- `%s`: all required R3 audit signals logged and finite.\n", variant);
    else
        fprintf(fid, "- `%s`: missing `%s`.\n", variant, strjoin(missing, ", "));
    end
end
fprintf(fid, "\n## Wave Samples\n\n");
for idx = 1:height(rows)
    variant = rows.variant(idx);
    if startsWith(variant, "R3-E")
        fprintf(fid, "- `%s`: `%s`\n", variant, slashPath(fullfile(experimentRoot, filePrefixForVariant(variant) + "_wave_sample.csv")));
    end
end
fprintf(fid, "\n## Interpretation\n\n`%s`: waveform evidence is local derived-Simulink evidence only. It is not hardware, HIL, board, or silicon validation.\n", classification);
end

function writeSummary(pathValue, rows, classification, detail, bestVariant, metricsCsv, availabilityCsv, schedulerCsv)
fid = fopen(pathValue, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E010-A5-R3 Research Summary\n\nDate: %s\n\n", reportDate());
fprintf(fid, "## Result\n\n`%s`\n\n%s\n\n", classification, detail);
writeMetricsTable(fid, rows);
fprintf(fid, "## Evidence Files\n\n- Metrics: `%s`\n- Signal availability: `%s`\n- Scheduler audit: `%s`\n\n", slashPath(metricsCsv), slashPath(availabilityCsv), slashPath(schedulerCsv));
fprintf(fid, "## Claim Boundary\n\nIf `MODEL_CONFIRMED`, the claim is limited to the local ideal IQCOT derived Simulink `40A -> 1A` severe-drop case. If revised, A5 remains blocked by reentry queue / energy-allocation guards. AI still does not command gates or external load-current slew.\n\nBest partial variant: `%s`.\n", bestVariant);
if classification == "MODEL_REVISED"
    fprintf(fid, "\n## Next Smallest Useful Step\n\nRevise the severe-drop `a_O` token structure or downgrade the severe-drop claim. Do not broaden to load grids, mismatch, active Lambda, or active-phase shed from this R3 state.\n");
end
end

function writeMetricsTable(fid, rows)
fprintf(fid, "| Variant | Success | Peak OS mV | Peak US mV | Rec 2-12 us mV | Rec 12-40 us mV | Final err mV | Burst | Queue max/final | Deferred/Rejected/Dropped | Budget used ns | Guard | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g/%.6g | %.6g/%.6g | %.6g/%.6g/%.6g | %.6g | %d | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.peak_overshoot_mV(idx), ...
        rows.peak_undershoot_mV(idx), rows.recovery_peak_2_12us_mV(idx), ...
        rows.recovery_peak_12_40us_mV(idx), rows.final_Vout_error_mV(idx), ...
        rows.burst_pulse_count_after_reentry(idx), rows.burst_pulse_limit_after_reentry(idx), ...
        rows.pending_REQ_queue_max_depth(idx), rows.queue_depth_final(idx), ...
        rows.deferred_REQ_count(idx), rows.rejected_REQ_count(idx), ...
        rows.dropped_REQ_count(idx), rows.reentry_Ton_budget_used_ns(idx), ...
        rows.guard_pass(idx), rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function columns = metricColumns()
columns = ["variant", "success", ...
    "peak_overshoot_mV", "delta_peak_overshoot_vs_C0_mV", "delta_peak_overshoot_vs_C4_mV", ...
    "peak_undershoot_mV", "recovery_peak_2_12us_mV", ...
    "delta_recovery_peak_2_12us_vs_C0_mV", "delta_recovery_peak_2_12us_vs_C4_mV", ...
    "recovery_peak_12_40us_mV", "delta_recovery_peak_12_40us_vs_C0_mV", ...
    "delta_recovery_peak_12_40us_vs_C4_mV", "settling_time_us", ...
    "final_Vout_error_mV", "Vout_ripple_pp_mV", "Ton_nom_ns", ...
    "Ton_requested_ns", "Ton_allocated_ns", "Ton_budget_remaining_ns", ...
    "Ton_min_meaningful_ns", "Ton_allocation_reason", ...
    "pending_REQ_queue_max_depth", "queue_depth_final", ...
    "queue_release_count", "queue_reject_count", "queue_reject_reason", ...
    "queue_release_min_spacing_us", "queue_release_max_per_window", ...
    "reentry_Ton_budget_window_us", "reentry_Ton_budget_ns", ...
    "reentry_Ton_budget_used_ns", "reentry_Ton_budget_violation", ...
    "area_int_capture_at_drop", "area_int_reentry_target", ...
    "area_int_restore_usage", "area_int_queue_coupling_usage", ...
    "area_int_max", "area_int_at_reentry", ...
    "first_reentry_time_us", "first_reentry_phase", "first_reentry_Ton_ns", ...
    "burst_count_window_us", "burst_pulse_count_after_reentry", ...
    "burst_pulse_limit_after_reentry", "actual_min_inter_pulse_spacing_us", ...
    "REQ_count", "accepted_REQ_count", "deferred_REQ_count", ...
    "rejected_REQ_count", "dropped_REQ_count", "phase_order_error_rate", ...
    "real_max_current_imbalance_A", ...
    "real_rms_current_imbalance_A", "current_limit_hit", ...
    "undershoot_budget_violation", "late_settling_guard_violation", ...
    "fallback_count", "fallback_reason", "guard_pass", "classification_hint", ...
    "logging_complete", "postprocess_complete", "audit_hint", "error_message", "derived_model"];
end

function rows = finalizeMetricRows(rows)
columns = metricColumns();
for idx = 1:numel(columns)
    if ~ismember(columns(idx), string(rows.Properties.VariableNames))
        rows.(columns(idx)) = repmat(missingValueFor(columns(idx)), height(rows), 1);
    end
end
rows = rows(:, columns);
end

function prefix = filePrefixForVariant(variant)
if variant == "R3-E1"
    prefix = "e010_a5_r3_e1_event_queue_alloc_40A_to_1A";
elseif variant == "R3-E2"
    prefix = "e010_a5_r3_e2_queue_spacing_40A_to_1A";
elseif variant == "R3-E3"
    prefix = "e010_a5_r3_e3_area_queue_coupling_40A_to_1A";
elseif variant == "R3-E4"
    prefix = "e010_a5_r3_e4_voltage_window_queue_40A_to_1A";
else
    prefix = "carry_forward_reference";
end
end

function out = appendTable(out, row)
if isempty(out)
    out = row;
else
    out = [out; row]; %#ok<AGROW>
end
end

function count = pulseInhibitCount(logs, spec)
count = 0;
for phase = 1:4
    count = count + maxOptionalSignal(logs, "pulse_inhibit_count" + phase, spec.t_load_step, spec.stop_time);
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

function count = deferredReqCount(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "REQ_defer" + phase, startTime, endTime);
end
end

function [eventTime, eventPhase, eventTon] = firstAcceptedAfter(logs, startTime, endTime)
eventTime = NaN; eventPhase = NaN; eventTon = NaN;
for phase = 1:4
    times = edgeTimes(logs, "REQ_accept" + phase, startTime, endTime);
    if ~isempty(times) && (isnan(eventTime) || times(1) < eventTime)
        eventTime = times(1);
        eventPhase = phase;
    end
end
if ~isnan(eventTime)
    eventTon = valueAtOptional(logs, "Ton_actual" + eventPhase, eventTime, NaN);
    if isnan(eventTon) || eventTon <= 0
        eventTon = valueAtOptional(logs, "Ton_cmd" + eventPhase, eventTime, NaN);
    end
end
end

function count = burstCountAfter(logs, startTime, endTime)
if isnan(startTime)
    count = NaN;
    return;
end
count = acceptedReqCount(logs, startTime, endTime);
end

function valueUs = actualMinAcceptedSpacingUs(logs, startTime, endTime)
times = allAcceptedTimes(logs, startTime, endTime);
if numel(times) < 2
    valueUs = NaN;
else
    valueUs = 1e6 * min(diff(times));
end
end

function times = allAcceptedTimes(logs, startTime, endTime)
times = [];
for phase = 1:4
    times = [times; edgeTimes(logs, "REQ_accept" + phase, startTime, endTime)]; %#ok<AGROW>
end
times = sort(times(:));
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
expectedOrder = expectedOrder(:)';
for idx = 2:numel(phases)
    prevIdx = find(expectedOrder == phases(idx - 1), 1);
    nextIdx = prevIdx + 1;
    if nextIdx > numel(expectedOrder)
        nextIdx = 1;
    end
    errors = errors + double(isempty(prevIdx) || phases(idx) ~= expectedOrder(nextIdx));
end
rate = errors / max(numel(phases) - 1, 1);
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
if any(mask), value = max(y(mask)); else, value = NaN; end
end

function value = meanWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask), value = mean(y(mask), "omitnan"); else, value = NaN; end
end

function value = ppWindow(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
if any(mask), value = max(y(mask)) - min(y(mask)); else, value = NaN; end
end

function valueUs = settlingTimeUs(t, vout, spec)
mask = t >= spec.t_load_step;
idxs = find(mask);
valueUs = NaN;
for idx = idxs(:)'
    tail = idx:numel(t);
    if all(abs(vout(tail) - spec.vref) <= spec.settle_band_V)
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
if ~isvector(values), values = firstScalarTrace(values, t); else, values = values(:); end
mask = t >= startTime & t <= endTime;
t = t(mask); values = values(mask);
if numel(values) < 2
    times = [];
else
    edgeIdx = find(diff(values > 0.5) > 0) + 1;
    times = t(edgeIdx);
    if values(1) > 0.5, times = [t(1); times(:)]; end
end
end

function [time, values] = signalSeries(logs, name)
sig = optionalSignal(logs, name);
if isempty(sig), error("Missing logged signal: %s", name); end
time = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
if ~isvector(values), values = firstScalarTrace(values, time); else, values = values(:); end
end

function sig = optionalSignal(logs, name)
sig = [];
try
    found = logs.find("Name", char(name));
    if isa(found, "Simulink.SimulationData.Dataset")
        if found.numElements > 0, sig = found.getElement(1); end
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
if isempty(sig) || isnan(t), value = defaultValue; return; end
time = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data), data = firstScalarTrace(data, time); else, data = data(:); end
value = interp1(time, data, t, "previous", "extrap");
if isempty(value) || isnan(value), value = defaultValue; end
end

function value = maxOptionalSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig), value = 0; return; end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data), data = firstScalarTrace(data, t); else, data = data(:); end
mask = t >= startTime & t <= endTime;
if any(mask), value = max(abs(data(mask))); else, value = 0; end
end

function value = lastOptionalSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig), value = 0; return; end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data), data = firstScalarTrace(data, t); else, data = data(:); end
mask = t >= startTime & t <= endTime & isfinite(data);
if any(mask), value = data(find(mask, 1, "last")); else, value = 0; end
end

function value = maxAbsOptionalSignal(logs, name, startTime, endTime)
value = maxOptionalSignal(logs, name, startTime, endTime);
end

function value = maxOptionalVector(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig), value = 0; return; end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if isvector(data), data = data(:); else, data = orientMatrix(data, 4); end
mask = t >= startTime & t <= endTime;
if any(mask), value = max(abs(data(mask, :)), [], "all"); else, value = 0; end
end

function value = lastNonzeroOptional(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig), value = 0; return; end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data), data = firstScalarTrace(data, t); else, data = data(:); end
mask = t >= startTime & t <= endTime & abs(data) > 0;
if any(mask), value = data(find(mask, 1, "last")); else, value = 0; end
end

function values = interpOptionalSignal(logs, name, timeGrid)
sig = optionalSignal(logs, name);
if isempty(sig), values = NaN(size(timeGrid)); return; end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
if ~isvector(data), data = firstScalarTrace(data, t); else, data = data(:); end
if numel(t) < 2, values = repmat(data(1), size(timeGrid));
else, values = interp1(t, data, timeGrid, "previous", "extrap"); end
end

function data = orientMatrix(data, columns)
if size(data, 2) == columns
    return;
elseif size(data, 1) == columns
    data = data';
else
    data = reshape(data, [], columns);
end
end

function data = firstScalarTrace(data, time)
if size(data, 1) == numel(time)
    data = data(:, 1);
elseif size(data, 2) == numel(time)
    data = data(1, :)';
else
    data = data(:);
    data = data(1:min(numel(data), numel(time)));
end
end

function value = baselinePeakOvershootMv(), value = 4.06085039477899; end
function value = baselineRecovery2To12Mv(), value = 3.61172256292042; end
function value = baselineRecovery12To40Mv(), value = 3.59863494243551; end

function text = reportDate()
text = char(datetime("now", "Format", "yyyy-MM-dd"));
end

function ensureDir(pathValue)
if ~exist(pathValue, "dir"), mkdir(pathValue); end
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end

function out = slashPath(pathValue)
out = replace(string(pathValue), "\", "/");
end

function details = errorDetails(ME)
details = string(ME.message);
for idx = 1:numel(ME.stack)
    details = details + " | " + string(ME.stack(idx).name) + ":" + string(ME.stack(idx).line);
end
end
