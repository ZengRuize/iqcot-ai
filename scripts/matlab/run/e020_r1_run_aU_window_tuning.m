function rows = e020_r1_run_aU_window_tuning(variants)
%E020_R1_RUN_AU_WINDOW_TUNING Run focused E020-R1 a_U window tuning.
% Fixed case: external 40A->120A load rise, four phases, no Lambda/phase add.

if nargin < 1
    variants = ["R1-U1", "R1-U2", "R1-U3", "R1-U4"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E020_load_rise_undershoot", "R1_aU_window_tuning");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e020_r1_metrics.csv");
summaryPath = fullfile(experimentRoot, "e020_r1_research_summary.md");
auditPath = fullfile(experimentRoot, "e020_r1_waveform_audit.md");
variantConfigCsv = fullfile(experimentRoot, "e020_r1_variant_config.csv");
signalAvailabilityCsv = fullfile(experimentRoot, "e020_r1_signal_availability.csv");
schedulerAuditCsv = fullfile(experimentRoot, "e020_r1_scheduler_audit.csv");

baselineAudit = auditBaseline(projectRoot);
writeVariantConfig(variantConfigCsv, variants);
reference = referenceRows(projectRoot);
rows = reference;
signalRows = table();
schedulerRows = table();

for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    modelFile = "";
    try
        modelFile = e020_build_load_rise_observable_model(spec.build_variant);
        [~, modelName] = fileparts(modelFile);
        load_system(modelFile);
        cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

        out = runCase(modelName, spec);
        logs = out.logsout;
        metrics = collectMetrics(logs, spec);
        row = rowFromMetrics(spec, metrics, true, "", modelFile);
        signalRows = appendTable(signalRows, signalAvailabilityRows(logs, spec));
        schedulerRows = appendTable(schedulerRows, schedulerAuditRows(logs, spec));
        exportWaveSample(logs, spec, fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv"));
        writeVariantReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, row);
    catch ME
        details = errorDetails(ME);
        row = failureRow(spec, details, modelFile);
        writeFailureReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, details);
    end

    rows = [rows; row]; %#ok<AGROW>
end

rows = addDeltaColumns(rows);
rows = addClassificationHints(rows);
writetable(rows, metricsCsv);
if ~isempty(signalRows)
    writetable(signalRows, signalAvailabilityCsv);
end
if ~isempty(schedulerRows)
    writetable(schedulerRows, schedulerAuditCsv);
end
[classification, detail, bestVariant] = classifyRows(rows);
writeWaveformAudit(auditPath, rows);
writeSummary(summaryPath, rows, classification, detail, bestVariant, metricsCsv, ...
    baselineAudit, variantConfigCsv, signalAvailabilityCsv, schedulerAuditCsv);

fprintf("E020_R1_METRICS=%s\n", metricsCsv);
fprintf("E020_R1_SUMMARY=%s\n", summaryPath);
fprintf("E020_R1_WAVEFORM_AUDIT=%s\n", auditPath);
fprintf("E020_R1_VARIANT_CONFIG=%s\n", variantConfigCsv);
fprintf("E020_R1_SIGNAL_AVAILABILITY=%s\n", signalAvailabilityCsv);
fprintf("E020_R1_SCHEDULER_AUDIT=%s\n", schedulerAuditCsv);
disp(rows);
end

function audit = auditBaseline(projectRoot)
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
[~, modelName] = fileparts(baselineModel);
audit = struct("baseline_model", string(baselineModel), "exists", isfile(baselineModel), ...
    "solver", "", "stop_time", "", "max_step", "", "signal_logging", "", ...
    "required_top_blocks_present", false, "saved", false);
if ~audit.exists
    return;
end
load_system(baselineModel);
cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>
audit.solver = string(get_param(modelName, "Solver"));
audit.stop_time = string(get_param(modelName, "StopTime"));
audit.max_step = string(get_param(modelName, "MaxStep"));
audit.signal_logging = string(get_param(modelName, "SignalLogging"));
required = ["Ideal_Digital_IQCOT_Request", "PhaseScheduler_4Phase", ...
    "IQCOT_Ton_Adapter", "COT_Cell_1Phase1", "COT_Cell_1Phase2", ...
    "COT_Cell_1Phase3", "COT_Cell_1Phase4"];
present = true;
for idx = 1:numel(required)
    present = present && ~isempty(find_system(modelName, "SearchDepth", 1, "Name", char(required(idx))));
end
audit.required_top_blocks_present = present;
audit.saved = false;
end

function rows = referenceRows(projectRoot)
baseSpec = baseSpecTemplate();
oldMetrics = readtable(fullfile(projectRoot, "experiments", "E020_load_rise_undershoot", "e020_metrics.csv"));

b0 = baseSpec;
b0.variant = "R1-B0";
b0.build_variant = "B0";
b0.file_prefix = "e020_r1_b0_reference";
b0.report_title = "E020-R1 B0 Carry-Forward Reference";
b0.ton_boost_enable = 0;
b0.fast_request_enable = 0;
b0.ton_boost_gain = 0;
b0.ton_boost_decay_policy = "none";
b0.model_file = string(oldMetrics.model_file(oldMetrics.short_variant == "B0"));
b0.wave_sample = fullfile(projectRoot, "experiments", "E020_load_rise_undershoot", "e020_b0_40A_to_120A_wave_sample.csv");

b3 = baseSpec;
b3.variant = "R1-B3";
b3.build_variant = "B3";
b3.file_prefix = "e020_r1_b3_reference";
b3.report_title = "E020-R1 B3 Carry-Forward Reference";
b3.fast_request_enable = 1;
b3.ton_boost_enable = 1;
b3.ton_boost_gain = 1.0;
b3.ton_boost_decay_policy = "B3_exponential_5e5_1ps";
b3.model_file = string(oldMetrics.model_file(oldMetrics.short_variant == "B3"));
b3.wave_sample = fullfile(projectRoot, "experiments", "E020_load_rise_undershoot", "e020_b3_40A_to_120A_wave_sample.csv");

rows = [referenceRow(projectRoot, oldMetrics, b0, "B0"); ...
    referenceRow(projectRoot, oldMetrics, b3, "B3")];
end

function writeVariantConfig(csvPath, variants)
rows = table();

b0 = baseSpecTemplate();
b0.variant = "R1-B0";
b0.fast_request_enable = 0;
b0.ton_boost_enable = 0;
b0.ton_boost_gain = 0;
b0.ton_boost_decay_policy = "none";
rows = appendTable(rows, variantConfigRow(b0, "carry_forward_B0"));

b3 = baseSpecTemplate();
b3.variant = "R1-B3";
b3.fast_request_enable = 1;
b3.ton_boost_enable = 1;
b3.ton_boost_gain = 1.0;
b3.ton_boost_decay_policy = "B3_exponential_5e5_1ps";
rows = appendTable(rows, variantConfigRow(b3, "carry_forward_B3"));

for idx = 1:numel(variants)
    rows = appendTable(rows, variantConfigRow(variantSpec(variants(idx)), "new_R1_run"));
end
writetable(rows, csvPath);
end

function row = variantConfigRow(spec, role)
fallbackPolicy = "window_end";
if spec.late_recovery_guard_enable > 0
    fallbackPolicy = "window_end_or_late_guard";
end
row = table(string(spec.variant), string(role), spec.fast_request_enable, ...
    1e6 * spec.fast_request_window_s, 1e9 * spec.fast_request_period_s, ...
    1e9 * spec.fast_request_pulse_width_s, spec.ton_boost_enable, ...
    spec.ton_boost_gain, 1e6 * spec.ton_boost_window_s, ...
    1e9 * spec.ton_boost_max_s, string(spec.ton_boost_decay_policy), ...
    spec.boost_decay_rate, spec.late_recovery_guard_enable, string(fallbackPolicy), ...
    "B3 settings recovered from scripts/matlab/run/e020_run_load_rise_small_chunk.m and scripts/matlab/build/e020_build_load_rise_observable_model.m", ...
    'VariableNames', {'variant','role','fast_req_enable','fast_req_window_us', ...
    'fast_req_period_ns','fast_req_pulse_width_ns','Ton_boost_enable', ...
    'Ton_boost_gain','Ton_boost_window_us','Tton_boost_max_ns', ...
    'Ton_boost_decay_policy','boost_decay_rate_1ps', ...
    'late_recovery_guard_enable','fallback_to_nominal_policy','source_note'});
end

function row = referenceRow(projectRoot, oldMetrics, spec, oldVariant)
old = oldMetrics(oldMetrics.short_variant == oldVariant, :);
wave = readtable(spec.wave_sample);
tauUs = wave.time_after_step_us;
vout = wave.Vout;
ilSum = wave.IL1 + wave.IL2 + wave.IL3 + wave.IL4;
metrics = emptyMetrics();
metrics.peak_undershoot_mV = old.peak_undershoot_mV(1);
metrics.recovery_overshoot_mV = old.recovery_overshoot_mV(1);
metrics.recovery_peak_2_12us_mV = windowMaxMv(tauUs, vout, spec.vref, 2, 12);
metrics.recovery_peak_12_40us_mV = windowMaxMv(tauUs, vout, spec.vref, 12, 40);
metrics.current_rise_50pct_us = currentRiseFromWave(tauUs, ilSum, spec, 0.5);
metrics.current_rise_90pct_us = old.current_rise_time_us(1);
metrics.settling_time_1mV_us = old.settling_time_us(1);
metrics.settled_within_90us = ~isnan(metrics.settling_time_1mV_us) && metrics.settling_time_1mV_us <= 90;
metrics.final_Vout_error_mV = old.final_error_mV(1);
metrics.phase_current_peak_A = old.phase_current_peak_A(1);
metrics.phase_current_peak_limit_A = spec.current_limit_guard_A;
metrics.current_limit_hit = old.current_limit_hit(1) > 0;
metrics.events_0_2us = old.event_count_0_2us(1);
metrics.events_2_12us = NaN;
metrics.events_12_40us = NaN;
metrics.Ton_boost_count = 0;
if oldVariant == "B3"
    metrics.Ton_boost_count = NaN;
end
metrics.Ton_boost_usage = old.ton_boost_usage_fraction(1);
metrics.Ton_boost_gain = spec.ton_boost_gain;
metrics.Ton_boost_window_us = 1e6 * spec.ton_boost_window_s;
metrics.Ton_boost_decay_policy = spec.ton_boost_decay_policy;
metrics.Ton_boost_decay_done_time_us = NaN;
metrics.fast_req_count = old.fast_request_count(1);
metrics.fast_req_window_us = 1e6 * spec.fast_request_window_s;
metrics.fast_req_reject_count = NaN;
metrics.fast_req_reject_reason = "carry_forward";
metrics.fallback_to_nominal_time_us = NaN;
metrics.late_recovery_guard_enable = spec.late_recovery_guard_enable > 0;
metrics.late_recovery_guard_trigger_count = 0;
metrics.late_recovery_guard_trigger_reason = "disabled";
metrics.REQ_count = NaN;
metrics.accepted_REQ_count = NaN;
metrics.dropped_REQ_count = NaN;
metrics.phase_order_error_rate = NaN;
metrics.Vout_ripple_pp_mV = ripplePpMv(tauUs, vout, 70, 90);
metrics.real_max_current_imbalance_A = maxImbalanceFromWave(wave);
metrics.real_rms_current_imbalance_A = rmsImbalanceFromWave(wave);
metrics.guard_pass = ~metrics.current_limit_hit;
metrics.classification_hint = "carry_forward_reference";
row = rowFromMetrics(spec, metrics, true, "carry-forward reference", spec.model_file);
row.model_file = string(old.model_file(1));
row.error_message = "carry-forward reference from " + slashPath(fullfile(projectRoot, "experiments", "E020_load_rise_undershoot", "e020_metrics.csv"));
end

function spec = variantSpec(variant)
spec = baseSpecTemplate();
spec.variant = string(variant);
spec.build_variant = string(variant);
spec.file_prefix = lower(regexprep(char(variant), "[^0-9A-Za-z]+", "_"));
spec.report_title = "E020-R1 " + string(variant) + " a_U Window Tuning";
spec.fast_request_enable = 1;
spec.ton_boost_enable = 1;
spec.ton_boost_gain = 1.0;
spec.ton_boost_decay_policy = "B3_exponential_5e5_1ps";

if variant == "R1-U1"
    spec.ton_boost_window_s = 1.5e-6;
    spec.ton_boost_max_s = 260e-9;
    spec.boost_decay_rate = 5.0e5;
    spec.ton_boost_decay_policy = "short_window_B3_exponential";
elseif variant == "R1-U2"
    spec.ton_boost_window_s = 1.5e-6;
    spec.ton_boost_gain = 0.75;
    spec.ton_boost_max_s = 245e-9;
    spec.boost_decay_rate = 5.0e5;
    spec.ton_boost_decay_policy = "short_window_0p75_gain_exponential";
elseif variant == "R1-U3"
    spec.fast_request_window_s = 1.5e-6;
    spec.ton_boost_window_s = 3.0e-6;
    spec.ton_boost_max_s = 260e-9;
    spec.boost_decay_rate = 1.0e6;
    spec.ton_boost_decay_policy = "strong_initial_exponential_decay_1e6_1ps";
elseif variant == "R1-U4"
    spec.fast_request_window_s = 1.5e-6;
    spec.ton_boost_window_s = 3.0e-6;
    spec.ton_boost_max_s = 260e-9;
    spec.boost_decay_rate = 1.0e6;
    spec.late_recovery_guard_enable = 1;
    spec.ton_boost_decay_policy = "U3_plus_late_recovery_guard";
else
    error("Unknown E020-R1 variant: %s", variant);
end
end

function spec = baseSpecTemplate()
spec = struct();
spec.variant = "";
spec.build_variant = "";
spec.file_prefix = "";
spec.report_title = "";
spec.base_load_A = 40;
spec.target_load_A = 120;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.54e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.settle_band_V = 1.0e-3;
spec.current_limit_guard_A = 55;
spec.undershoot_band_V = 0.2e-3;
spec.fast_request_window_s = 3.0e-6;
spec.fast_request_period_s = 160e-9;
spec.fast_request_pulse_width_s = 25e-9;
spec.ton_boost_window_s = 3.0e-6;
spec.ton_boost_max_s = 260e-9;
spec.boost_decay_rate = 5.0e5;
spec.fast_request_enable = 0;
spec.ton_boost_enable = 0;
spec.ton_boost_gain = 0;
spec.ton_boost_decay_policy = "none";
spec.late_recovery_guard_enable = 0;
spec.model_file = "";
spec.wave_sample = "";
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
in = in.setVariable("E020_Vref", spec.vref);
in = in.setVariable("E020_Undershoot_Band", spec.undershoot_band_V);
in = in.setVariable("E020_Settling_Band", spec.settle_band_V);
in = in.setVariable("E020_CurrentLimit_Guard", spec.current_limit_guard_A);
in = in.setVariable("E020_FastRequest_Enable", spec.fast_request_enable);
in = in.setVariable("E020_FastRequest_Window", spec.fast_request_window_s);
in = in.setVariable("E020_FastRequest_Period", spec.fast_request_period_s);
in = in.setVariable("E020_FastRequest_PulseWidth", spec.fast_request_pulse_width_s);
in = in.setVariable("E020_TonBoost_Enable", spec.ton_boost_enable);
in = in.setVariable("E020_TonBoost_Window", spec.ton_boost_window_s);
in = in.setVariable("Tton_boost_max", spec.ton_boost_max_s);
in = in.setVariable("E020_Boost_Decay_Rate", spec.boost_decay_rate);
in = in.setVariable("E020_LateRecoveryGuard_Enable", spec.late_recovery_guard_enable);
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
[t, vout] = signalSeries(logs, "Vout");
tau = t - spec.t_load_step;
post = tau >= 0 & tau <= (spec.stop_time - spec.t_load_step);
tauPost = tau(post);
vPost = vout(post);

metrics = emptyMetrics();
metrics.peak_undershoot_mV = 1e3 * max(spec.vref - vPost);
metrics.recovery_overshoot_mV = 1e3 * max(vPost - spec.vref);
metrics.recovery_peak_2_12us_mV = 1e3 * maxWindow(tauPost, vPost - spec.vref, 2e-6, 12e-6);
metrics.recovery_peak_12_40us_mV = 1e3 * maxWindow(tauPost, vPost - spec.vref, 12e-6, 40e-6);
metrics.current_rise_50pct_us = currentRiseTimeUs(logs, spec, 0.5);
metrics.current_rise_90pct_us = currentRiseTimeUs(logs, spec, 0.9);
metrics.settling_time_1mV_us = settlingTimeUs(tauPost, vPost, spec.vref, spec.settle_band_V);
metrics.settled_within_90us = ~isnan(metrics.settling_time_1mV_us) && metrics.settling_time_1mV_us <= 90;
metrics.final_Vout_error_mV = 1e3 * meanWindow(tauPost, vPost - spec.vref, 75e-6, 90e-6);
metrics.phase_current_peak_A = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time);
metrics.phase_current_peak_limit_A = spec.current_limit_guard_A;
metrics.current_limit_hit = metrics.phase_current_peak_A > spec.current_limit_guard_A || ...
    maxOptionalSignal(logs, "current_limit_hit", spec.t_load_step, spec.stop_time) > 0.5;
metrics.events_0_2us = countQhEvents(logs, spec.t_load_step, spec.t_load_step + 2e-6);
metrics.events_2_12us = countQhEvents(logs, spec.t_load_step + 2e-6, spec.t_load_step + 12e-6);
metrics.events_12_40us = countQhEvents(logs, spec.t_load_step + 12e-6, spec.t_load_step + 40e-6);
metrics.Ton_boost_count = 0;
for phase = 1:4
    metrics.Ton_boost_count = metrics.Ton_boost_count + countRisingEdges(logs, "ton_boost_active" + phase, spec.t_load_step, spec.stop_time);
end
metrics.Ton_boost_usage = activeFraction(logs, "ton_boost_active", ...
    spec.t_load_step, spec.t_load_step + spec.ton_boost_window_s);
metrics.Ton_boost_gain = spec.ton_boost_gain;
metrics.Ton_boost_window_us = 1e6 * spec.ton_boost_window_s;
metrics.Ton_boost_decay_policy = spec.ton_boost_decay_policy;
metrics.Ton_boost_decay_done_time_us = decayDoneTimeUs(logs, spec);
metrics.fast_req_count = countRisingEdges(logs, "fast_request_active", spec.t_load_step, spec.t_load_step + spec.fast_request_window_s);
metrics.fast_req_window_us = 1e6 * spec.fast_request_window_s;
[metrics.fast_req_reject_count, metrics.fast_req_reject_reason] = fastRequestRejectAudit(logs, spec);
metrics.fallback_to_nominal_time_us = firstHighTimeUs(logs, "fallback_to_nominal_state", spec.t_load_step, spec.stop_time);
metrics.late_recovery_guard_enable = spec.late_recovery_guard_enable > 0;
metrics.late_recovery_guard_trigger_count = countRisingEdges(logs, "late_recovery_guard_state", spec.t_load_step, spec.stop_time);
metrics.late_recovery_guard_trigger_reason = lateGuardReason(logs, spec);
metrics.REQ_count = countReq(logs, "REQ", spec.t_load_step, spec.stop_time);
metrics.accepted_REQ_count = countReq(logs, "REQ_accept", spec.t_load_step, spec.stop_time);
metrics.dropped_REQ_count = max(0, metrics.REQ_count - metrics.accepted_REQ_count);
metrics.phase_order_error_rate = phaseOrderErrorRate(logs, spec);
metrics.Vout_ripple_pp_mV = 1e3 * peakToPeakWindow(tauPost, vPost, 70e-6, 90e-6);
[metrics.real_max_current_imbalance_A, metrics.real_rms_current_imbalance_A] = currentImbalance(logs, spec);

boostStuck = ~isnan(metrics.fallback_to_nominal_time_us) && ...
    metrics.fallback_to_nominal_time_us > metrics.Ton_boost_window_us + 0.5;
metrics.guard_pass = ~metrics.current_limit_hit && metrics.dropped_REQ_count == 0 && ...
    metrics.phase_order_error_rate == 0 && metrics.phase_current_peak_A <= spec.current_limit_guard_A && ...
    ~boostStuck;
metrics.classification_hint = "pending";
end

function metrics = emptyMetrics()
metrics = struct( ...
    "peak_undershoot_mV", NaN, ...
    "recovery_overshoot_mV", NaN, ...
    "recovery_peak_2_12us_mV", NaN, ...
    "recovery_peak_12_40us_mV", NaN, ...
    "current_rise_50pct_us", NaN, ...
    "current_rise_90pct_us", NaN, ...
    "settling_time_1mV_us", NaN, ...
    "settled_within_90us", false, ...
    "final_Vout_error_mV", NaN, ...
    "phase_current_peak_A", NaN, ...
    "phase_current_peak_limit_A", 55, ...
    "current_limit_hit", false, ...
    "events_0_2us", NaN, ...
    "events_2_12us", NaN, ...
    "events_12_40us", NaN, ...
    "Ton_boost_count", NaN, ...
    "Ton_boost_usage", NaN, ...
    "Ton_boost_gain", NaN, ...
    "Ton_boost_window_us", NaN, ...
    "Ton_boost_decay_policy", "NaN", ...
    "Ton_boost_decay_done_time_us", NaN, ...
    "fast_req_count", NaN, ...
    "fast_req_window_us", NaN, ...
    "fast_req_reject_count", NaN, ...
    "fast_req_reject_reason", "NaN", ...
    "fallback_to_nominal_time_us", NaN, ...
    "late_recovery_guard_enable", false, ...
    "late_recovery_guard_trigger_count", NaN, ...
    "late_recovery_guard_trigger_reason", "NaN", ...
    "REQ_count", NaN, ...
    "accepted_REQ_count", NaN, ...
    "dropped_REQ_count", NaN, ...
    "phase_order_error_rate", NaN, ...
    "Vout_ripple_pp_mV", NaN, ...
    "real_max_current_imbalance_A", NaN, ...
    "real_rms_current_imbalance_A", NaN, ...
    "guard_pass", false, ...
    "classification_hint", "NaN");
end

function rows = addDeltaColumns(rows)
b0 = rows(rows.variant == "R1-B0", :);
b3 = rows(rows.variant == "R1-B3", :);
if isempty(b0) || isempty(b3)
    return;
end
rows.delta_peak_undershoot_vs_B0_mV = rows.peak_undershoot_mV - b0.peak_undershoot_mV(1);
rows.delta_peak_undershoot_vs_B3_mV = rows.peak_undershoot_mV - b3.peak_undershoot_mV(1);
rows.delta_current_rise_90pct_vs_B0_us = rows.current_rise_90pct_us - b0.current_rise_90pct_us(1);
rows.delta_current_rise_90pct_vs_B3_us = rows.current_rise_90pct_us - b3.current_rise_90pct_us(1);
rows.delta_final_error_vs_B3_mV = rows.final_Vout_error_mV - b3.final_Vout_error_mV(1);

desiredOrder = ["variant", "success", ...
    "peak_undershoot_mV", "delta_peak_undershoot_vs_B0_mV", "delta_peak_undershoot_vs_B3_mV", ...
    "recovery_overshoot_mV", "recovery_peak_2_12us_mV", "recovery_peak_12_40us_mV", ...
    "current_rise_50pct_us", "current_rise_90pct_us", ...
    "delta_current_rise_90pct_vs_B0_us", "delta_current_rise_90pct_vs_B3_us", ...
    "settling_time_1mV_us", "settled_within_90us", "final_Vout_error_mV", ...
    "delta_final_error_vs_B3_mV", "phase_current_peak_A", "phase_current_peak_limit_A", ...
    "current_limit_hit", "events_0_2us", "events_2_12us", "events_12_40us", ...
    "Ton_boost_count", "Ton_boost_usage", "Ton_boost_gain", "Ton_boost_window_us", ...
    "Ton_boost_decay_policy", "Ton_boost_decay_done_time_us", "fast_req_count", ...
    "fast_req_window_us", "fast_req_reject_count", "fast_req_reject_reason", ...
    "fallback_to_nominal_time_us", "late_recovery_guard_enable", ...
    "late_recovery_guard_trigger_count", "late_recovery_guard_trigger_reason", ...
    "REQ_count", "accepted_REQ_count", "dropped_REQ_count", "phase_order_error_rate", ...
    "Vout_ripple_pp_mV", "real_max_current_imbalance_A", "real_rms_current_imbalance_A", ...
    "guard_pass", "classification_hint", "error_message", "model_file"];
rows = rows(:, desiredOrder);
end

function rows = addClassificationHints(rows)
b0 = rows(rows.variant == "R1-B0", :);
b3 = rows(rows.variant == "R1-B3", :);
if isempty(b0) || isempty(b3)
    rows.classification_hint(:) = "implementation_missing_reference";
    return;
end
for idx = 1:height(rows)
    if startsWith(rows.variant(idx), "R1-B")
        rows.classification_hint(idx) = "carry_forward_reference";
        continue;
    end
    if ~rows.success(idx)
        rows.classification_hint(idx) = "implementation_issue";
    elseif ~rows.guard_pass(idx)
        rows.classification_hint(idx) = "guard_fail";
    elseif rows.peak_undershoot_mV(idx) >= b0.peak_undershoot_mV(1) || ...
            rows.current_rise_90pct_us(idx) >= b0.current_rise_90pct_us(1)
        rows.classification_hint(idx) = "early_benefit_lost";
    elseif abs(rows.final_Vout_error_mV(idx)) < abs(b3.final_Vout_error_mV(1)) || ...
            rows.settled_within_90us(idx)
        rows.classification_hint(idx) = "candidate_model_confirmed";
    else
        rows.classification_hint(idx) = "late_recovery_not_improved";
    end
end
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = table( ...
    string(spec.variant), success, ...
    m.peak_undershoot_mV, NaN, NaN, ...
    m.recovery_overshoot_mV, m.recovery_peak_2_12us_mV, m.recovery_peak_12_40us_mV, ...
    m.current_rise_50pct_us, m.current_rise_90pct_us, NaN, NaN, ...
    m.settling_time_1mV_us, m.settled_within_90us, m.final_Vout_error_mV, NaN, ...
    m.phase_current_peak_A, m.phase_current_peak_limit_A, m.current_limit_hit, ...
    m.events_0_2us, m.events_2_12us, m.events_12_40us, ...
    m.Ton_boost_count, m.Ton_boost_usage, m.Ton_boost_gain, m.Ton_boost_window_us, string(m.Ton_boost_decay_policy), ...
    m.Ton_boost_decay_done_time_us, m.fast_req_count, m.fast_req_window_us, ...
    m.fast_req_reject_count, string(m.fast_req_reject_reason), m.fallback_to_nominal_time_us, ...
    m.late_recovery_guard_enable, m.late_recovery_guard_trigger_count, string(m.late_recovery_guard_trigger_reason), ...
    m.REQ_count, m.accepted_REQ_count, m.dropped_REQ_count, m.phase_order_error_rate, ...
    m.Vout_ripple_pp_mV, m.real_max_current_imbalance_A, m.real_rms_current_imbalance_A, ...
    m.guard_pass, string(m.classification_hint), string(errorMessage), string(modelFile), ...
    'VariableNames', {'variant','success','peak_undershoot_mV', ...
    'delta_peak_undershoot_vs_B0_mV','delta_peak_undershoot_vs_B3_mV', ...
    'recovery_overshoot_mV','recovery_peak_2_12us_mV','recovery_peak_12_40us_mV', ...
    'current_rise_50pct_us','current_rise_90pct_us', ...
    'delta_current_rise_90pct_vs_B0_us','delta_current_rise_90pct_vs_B3_us', ...
    'settling_time_1mV_us','settled_within_90us','final_Vout_error_mV', ...
    'delta_final_error_vs_B3_mV','phase_current_peak_A','phase_current_peak_limit_A', ...
    'current_limit_hit','events_0_2us','events_2_12us','events_12_40us', ...
    'Ton_boost_count','Ton_boost_usage','Ton_boost_gain','Ton_boost_window_us', ...
    'Ton_boost_decay_policy','Ton_boost_decay_done_time_us','fast_req_count', ...
    'fast_req_window_us','fast_req_reject_count','fast_req_reject_reason', ...
    'fallback_to_nominal_time_us','late_recovery_guard_enable', ...
    'late_recovery_guard_trigger_count','late_recovery_guard_trigger_reason', ...
    'REQ_count','accepted_REQ_count','dropped_REQ_count','phase_order_error_rate', ...
    'Vout_ripple_pp_mV','real_max_current_imbalance_A','real_rms_current_imbalance_A', ...
    'guard_pass','classification_hint','error_message','model_file'});
end

function row = failureRow(spec, errorMessage, modelFile)
m = emptyMetrics();
m.phase_current_peak_limit_A = spec.current_limit_guard_A;
m.Ton_boost_gain = spec.ton_boost_gain;
m.Ton_boost_window_us = 1e6 * spec.ton_boost_window_s;
m.Ton_boost_decay_policy = spec.ton_boost_decay_policy;
m.fast_req_window_us = 1e6 * spec.fast_request_window_s;
m.late_recovery_guard_enable = spec.late_recovery_guard_enable > 0;
m.classification_hint = "implementation_issue";
row = rowFromMetrics(spec, m, false, errorMessage, modelFile);
end

function [classification, detail, bestVariant] = classifyRows(rows)
bestVariant = "";
tested = rows(startsWith(rows.variant, "R1-U"), :);
if isempty(tested) || any(~tested.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one R1 simulated variant failed, so a_U window performance is not interpretable.";
    return;
end
b3 = rows(rows.variant == "R1-B3", :);
if isempty(b3)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "The R1-B3 carry-forward reference is missing.";
    return;
end
confirmed = tested(tested.classification_hint == "candidate_model_confirmed", :);
if ~isempty(confirmed)
    [~, pick] = min(abs(confirmed.final_Vout_error_mV));
    bestVariant = confirmed.variant(pick);
    classification = "MODEL_CONFIRMED";
    detail = "An R1 candidate preserved early undershoot/current-rise improvement and improved final-error or settling evidence without guard violations.";
elseif any(tested.guard_pass & tested.peak_undershoot_mV < rows.peak_undershoot_mV(rows.variant == "R1-B0") & ...
        tested.current_rise_90pct_us < rows.current_rise_90pct_us(rows.variant == "R1-B0"))
    [~, pick] = min(tested.peak_undershoot_mV);
    bestVariant = tested.variant(pick);
    classification = "MODEL_REVISED";
    detail = "R1 preserves the local early a_U benefit but does not improve the unresolved late final-error behavior versus B3.";
elseif all(~tested.guard_pass)
    classification = "MODEL_REVISED";
    detail = "All R1 candidates violate at least one guard; revise Ton decay/fallback timing before interpreting performance.";
else
    classification = "CLAIM_DOWNGRADED";
    detail = "The tested R1 window tuning did not preserve the already-confirmed early a_U benefit in this fixed 40A->120A case.";
end
end

function writeVariantReport(reportPath, modelFile, spec, row)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-07-01\n\n");
fprintf(fid, "## Model Copy\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Fixed Case\n\nExternal load-current disturbance: `40A -> 120A`; fixed four phases; active Lambda and active-phase add/shed disabled.\n\n");
fprintf(fid, "## a_U Settings\n\n");
fprintf(fid, "- fast request window: `%.6g us`\n", 1e6 * spec.fast_request_window_s);
fprintf(fid, "- Ton boost window: `%.6g us`\n", 1e6 * spec.ton_boost_window_s);
fprintf(fid, "- Ton boost max: `%.6g ns`\n", 1e9 * spec.ton_boost_max_s);
fprintf(fid, "- Ton boost gain label: `%.6g`\n", spec.ton_boost_gain);
fprintf(fid, "- decay policy: `%s`\n", spec.ton_boost_decay_policy);
fprintf(fid, "- late recovery guard enable: `%d`\n\n", spec.late_recovery_guard_enable > 0);
fprintf(fid, "## Metrics\n\n");
writeMetricsTable(fid, row);
fprintf(fid, "## Interpretation\n\n");
fprintf(fid, "This per-variant report is local to the fixed R1 case. Final classification is assigned in `e020_r1_research_summary.md` after comparing U1/U2/U3 against carry-forward B0/B3.\n");
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-07-01\n\n");
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Error: `%s`\n", message);
end

function writeSummary(summaryPath, rows, classification, detail, bestVariant, metricsCsv, ...
    audit, variantConfigCsv, signalAvailabilityCsv, schedulerAuditCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E020-R1 a_U Window Tuning Research Summary\n\n");
fprintf(fid, "Date: 2026-07-01\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "The first E020 chunk confirmed early load-rise benefit from fast request plus Ton boost, but B3 did not demonstrate full `120A` recovery or `1 mV` settling. R1 tests whether a shorter or more strongly decayed Ton-boost window preserves early benefit while improving late final-error behavior.\n\n");
fprintf(fid, "## Baseline Audit\n\n");
fprintf(fid, "- baseline: `%s`\n", slashPath(audit.baseline_model));
fprintf(fid, "- exists: `%d`\n", audit.exists);
fprintf(fid, "- solver: `%s`\n", audit.solver);
fprintf(fid, "- stop time: `%s`\n", audit.stop_time);
fprintf(fid, "- max step: `%s`\n", audit.max_step);
fprintf(fid, "- required IQCOT blocks present: `%d`\n", audit.required_top_blocks_present);
fprintf(fid, "- saved during audit: `%d`\n\n", audit.saved);
fprintf(fid, "## Fixed Case\n\n");
fprintf(fid, "`40A -> 120A` external load-current rise, fixed four phases, nominal DCR/current sensing, active Lambda disabled, active-phase add/shed disabled.\n\n");
fprintf(fid, "## Metrics CSV\n\n`%s`\n\n", slashPath(metricsCsv));
fprintf(fid, "Additional evidence CSVs:\n\n");
fprintf(fid, "- variant config: `%s`\n", slashPath(variantConfigCsv));
fprintf(fid, "- signal availability: `%s`\n", slashPath(signalAvailabilityCsv));
fprintf(fid, "- scheduler audit: `%s`\n\n", slashPath(schedulerAuditCsv));
fprintf(fid, "## Metrics Table\n\n");
writeMetricsTable(fid, rows);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "%s\n\n", detail);
if strlength(bestVariant) > 0
    best = rows(rows.variant == bestVariant, :);
    fprintf(fid, "Best R1 variant: `%s`.\n\n", bestVariant);
    fprintf(fid, "- peak undershoot: `%.6g mV`\n", best.peak_undershoot_mV(1));
    fprintf(fid, "- 90%% current-rise time: `%.6g us`\n", best.current_rise_90pct_us(1));
    fprintf(fid, "- final Vout error: `%.6g mV`\n", best.final_Vout_error_mV(1));
    fprintf(fid, "- guard pass: `%d`\n\n", best.guard_pass(1));
    if bestVariant == "R1-U1"
        finalDelta = best.delta_final_error_vs_B3_mV(1);
        fprintf(fid, "The final-error improvement versus B3 is only `%+.6g mV` toward zero, and no R1 variant settled within the `1 mV` band in the `90 us` post-step window. The confirmation is therefore a narrow local window-tuning confirmation, not a full `120A` recovery confirmation.\n\n", finalDelta);
    end
end
fprintf(fid, "## Claim Boundary\n\n");
if classification == "MODEL_CONFIRMED"
    fprintf(fid, "Allowed local claim: in the local ideal IQCOT derived Simulink model, the selected safety-projected `a_U` load-rise token preserves the tested early undershoot/current-rise benefit and improves late final-error or settling evidence without current-limit, REQ, phase-order, or boost-window guard violations.\n\n");
else
    fprintf(fid, "Allowed claim remains limited: E020 confirms local early load-rise benefit for peak undershoot and current-rise, but full `120A` late recovery remains unresolved.\n\n");
end
fprintf(fid, "Forbidden claims remain: broad load-rise robustness, active Lambda validation, active-phase add/shed during this load-rise, DCR/current-sense mismatch robustness, hardware/HIL/board/silicon validation, AI direct gate control, or AI control of external load-current slew.\n\n");
fprintf(fid, "## Next Smallest Useful Step\n\n");
if classification == "MODEL_CONFIRMED"
    fprintf(fid, "Freeze the local `a_U` window-tuned claim boundary and update manuscript figures.\n");
elseif classification == "MODEL_REVISED"
    fprintf(fid, "Revise Ton decay/fallback timing or keep `a_U` claim limited to early peak/current-rise benefit.\n");
else
    fprintf(fid, "Fix implementation/logging before interpreting `a_U` performance.\n");
end
end

function writeWaveformAudit(auditPath, rows)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E020-R1 Waveform Audit\n\n");
fprintf(fid, "Date: 2026-07-01\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Fixed external `40A -> 120A` load-current rise. `R1-B0` and `R1-B3` are carry-forward references; `R1-U1/U2/U3/U4` are newly simulated derived models.\n\n");
fprintf(fid, "## Signal Availability\n\n");
fprintf(fid, "- Direct or baseline logged: `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`, `Lambda_i`, `area_int_i`, `active_phase_set`.\n");
fprintf(fid, "- R1 added logs: `IL_sense1..4`, `REQ_accept1..4`, `REQ_reject_reason`, `current_limit_hit`, `phase_current_peak`, `current_rise_target_state`, `late_recovery_guard_state`, `Vout_error`, `Vout_error_slope`, `settling_band_state`, `phase_order_error`.\n");
fprintf(fid, "- Ton boost logs: `ton_boost_active1..4`, `Ton_cmd_boost1..4`, `Ton_boost_state`, `Ton_boost_gain`, `Ton_boost_window`, `Ton_boost_decay_state`, `fallback_to_nominal_state`.\n");
fprintf(fid, "- Fast request logs: `fast_request_active`, `fast_request_count`, `fast_req_state`, `fast_req_reject_reason`.\n");
fprintf(fid, "- Derived in postprocess: `Ton_nom` from `Ton_cmd1..4`, `phase_order_error_rate` from accepted-event sequence, `fast_req_count` from fast-request active edges, and current-imbalance metrics from `IL1..IL4`.\n\n");
fprintf(fid, "## Unavailable Or Proxy Signals\n\n");
fprintf(fid, "- Exact signal name `fast_req_count` is reported as a metric derived from logged `fast_request_count` and `fast_request_active`.\n");
fprintf(fid, "- `REQ_count` and `accepted_REQ_count` are equal in this fixed four-phase R1 model because no add/shed supervisor rejects scheduler outputs; `dropped_REQ_count` is therefore an integrity check, not a separate rejection mechanism.\n");
fprintf(fid, "- The pass/fail phase-order guard uses event-sequence postprocess. The sampled `phase_order_error` signal is retained only as a model diagnostic.\n\n");
fprintf(fid, "## Derived Models\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), slashPath(rows.model_file(idx)));
end
end

function writeMetricsTable(fid, rows)
fprintf(fid, "| Variant | Success | Peak undershoot mV | Rise90 us | Final err mV | Peak current A | Guard | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %d | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.peak_undershoot_mV(idx), ...
        rows.current_rise_90pct_us(idx), rows.final_Vout_error_mV(idx), ...
        rows.phase_current_peak_A(idx), rows.guard_pass(idx), rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function exportWaveSample(logs, spec, csvPath)
[t, vout] = signalSeries(logs, "Vout");
[ti, iload] = signalSeries(logs, "Iload");
timeGrid = unique([t(:); ti(:)]);
maxRows = 30000;
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
    out.("REQ_accept" + phase) = interpOptionalSignal(logs, "REQ_accept" + phase, timeGrid, "previous");
    out.("ton_boost_active" + phase) = interpOptionalSignal(logs, "ton_boost_active" + phase, timeGrid, "previous");
end
out.fast_request_active = interpOptionalSignal(logs, "fast_request_active", timeGrid, "previous");
out.Ton_boost_gain = interpOptionalSignal(logs, "Ton_boost_gain", timeGrid, "linear");
out.fallback_to_nominal_state = interpOptionalSignal(logs, "fallback_to_nominal_state", timeGrid, "previous");
out.current_limit_hit = interpOptionalSignal(logs, "current_limit_hit", timeGrid, "previous");
out.current_rise_target_state = interpOptionalSignal(logs, "current_rise_target_state", timeGrid, "previous");
out.Vout_error = interpOptionalSignal(logs, "Vout_error", timeGrid, "linear");
out.Vout_error_slope = interpOptionalSignal(logs, "Vout_error_slope", timeGrid, "linear");
writetable(out, csvPath);
end

function rows = signalAvailabilityRows(logs, spec)
names = requiredSignalNames();
rows = table();
for idx = 1:numel(names)
    name = names(idx);
    available = false;
    source = "logsout";
    if name == "Ton_nom"
        available = all(arrayfun(@(p) ~isempty(optionalSignal(logs, "Ton_cmd" + p)), 1:4));
        source = "derived_from_Ton_cmd1_4";
    elseif name == "fast_req_count"
        available = ~isempty(optionalSignal(logs, "fast_request_count")) || ...
            ~isempty(optionalSignal(logs, "fast_request_active"));
        source = "fast_request_count_or_active_edges";
    elseif name == "phase_current_peak"
        available = ~isempty(optionalSignal(logs, "phase_current_peak"));
        source = "R1_diagnostic";
    else
        available = ~isempty(optionalSignal(logs, name));
    end
    row = table(string(spec.variant), string(name), available, string(source), ...
        'VariableNames', {'variant','signal','available','source'});
    rows = appendTable(rows, row);
end
end

function names = requiredSignalNames()
names = ["Vout", "Iload", "IL1", "IL2", "IL3", "IL4", ...
    "IL_sense1", "IL_sense2", "IL_sense3", "IL_sense4", ...
    "REQ1", "REQ2", "REQ3", "REQ4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "REQ_reject_reason", "QH1", "QH2", "QH3", "QH4", ...
    "QL1", "QL2", "QL3", "QL4", "phase_idx", "phase_order_error", ...
    "Ton_nom", "Ton_cmd1", "Ton_cmd2", "Ton_cmd3", "Ton_cmd4", ...
    "Ton_actual1", "Ton_actual2", "Ton_actual3", "Ton_actual4", ...
    "Ton_boost_state", "Ton_boost_gain", "Ton_boost_window", ...
    "Ton_boost_decay_state", "fallback_to_nominal_state", ...
    "fast_req_state", "fast_req_count", "fast_req_reject_reason", ...
    "current_limit_hit", "phase_current_peak", "current_rise_target_state", ...
    "late_recovery_guard_state", "Vout_error", "Vout_error_slope", ...
    "settling_band_state"];
end

function rows = schedulerAuditRows(logs, spec)
eventTimes = [];
eventPhases = [];
for phase = 1:4
    times = edgeTimes(logs, "REQ_accept" + phase, spec.t_load_step, spec.stop_time);
    eventTimes = [eventTimes; times(:)]; %#ok<AGROW>
    eventPhases = [eventPhases; phase * ones(numel(times), 1)]; %#ok<AGROW>
end
rows = table();
if isempty(eventTimes)
    return;
end
[eventTimes, order] = sort(eventTimes);
eventPhases = eventPhases(order);
for idx = 1:numel(eventTimes)
    t = eventTimes(idx);
    expected = NaN;
    orderError = 0;
    if idx > 1
        expected = mod(eventPhases(idx - 1), 4) + 1;
        orderError = double(eventPhases(idx) ~= expected);
    end
    row = table(string(spec.variant), idx, 1e6 * (t - spec.t_load_step), ...
        eventPhases(idx), expected, orderError, ...
        valueAtOptional(logs, "phase_idx", t, NaN), ...
        valueAtOptional(logs, "REQ_reject_reason", t, 0), ...
        valueAtOptional(logs, "phase_order_error", t, 0), ...
        'VariableNames', {'variant','event_index','time_after_step_us', ...
        'REQ_accept_phase','expected_phase','phase_order_error_event', ...
        'phase_idx_sample','REQ_reject_reason_sample','phase_order_error_sample'});
    rows = appendTable(rows, row);
end
end

function riseUs = currentRiseTimeUs(logs, spec, fraction)
[timeGrid, ilSum] = currentSumGrid(logs);
threshold = spec.base_load_A + fraction * (spec.target_load_A - spec.base_load_A);
mask = timeGrid >= spec.t_load_step & ilSum >= threshold;
if any(mask)
    riseUs = 1e6 * (timeGrid(find(mask, 1, "first")) - spec.t_load_step);
else
    riseUs = NaN;
end
end

function [timeGrid, ilSum] = currentSumGrid(logs)
timeGrid = [];
currents = cell(1, 4);
for phase = 1:4
    [tp, il] = signalSeries(logs, "IL" + phase);
    timeGrid = [timeGrid; tp(:)]; %#ok<AGROW>
    currents{phase} = {tp, il};
end
timeGrid = unique(timeGrid);
maxRows = 60000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
ilSum = zeros(size(timeGrid));
for phase = 1:4
    tp = currents{phase}{1};
    il = currents{phase}{2};
    ilSum = ilSum + interp1(tp, il, timeGrid, "linear", "extrap");
end
end

function settlingUs = settlingTimeUs(tau, vout, vref, band)
err = abs(vout - vref);
settlingUs = NaN;
for idx = 1:numel(tau)
    if tau(idx) >= 0 && all(err(idx:end) <= band)
        settlingUs = 1e6 * tau(idx);
        return;
    end
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

function value = maxWindow(t, y, startTime, endTime)
vals = windowValues(t, y, startTime, endTime);
if isempty(vals)
    value = NaN;
else
    value = max(vals);
end
end

function vals = windowValues(t, y, startTime, endTime)
mask = t >= startTime & t <= endTime;
vals = y(mask);
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

function count = countReq(logs, prefix, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, prefix + phase, startTime, endTime);
end
end

function count = countQhEvents(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "QH" + phase, startTime, endTime);
end
end

function count = countRisingEdges(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    count = 0;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime;
values = values(mask);
if numel(values) < 2
    count = double(~isempty(values) && values(1) > 0.5);
else
    count = sum(diff(values > 0.5) > 0);
    if values(1) > 0.5
        count = count + 1;
    end
end
end

function value = maxOptionalSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = 0;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime;
if any(mask)
    value = max(values(mask));
else
    value = 0;
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
    frac = 0;
else
    frac = mean(vals > 0.5);
end
end

function [count, reason] = fastRequestRejectAudit(logs, spec)
sig = optionalSignal(logs, "fast_req_reject_reason");
count = 0;
reason = "none";
if isempty(sig)
    reason = "unavailable";
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= spec.t_load_step & t <= spec.t_load_step + spec.fast_request_window_s;
critical = values(mask) == 4;
if any(critical)
    count = countRisingEdges(logs, "fast_req_reject_reason", spec.t_load_step, spec.t_load_step + spec.fast_request_window_s);
    reason = "current_limit_guard";
end
end

function reason = lateGuardReason(logs, spec)
if spec.late_recovery_guard_enable <= 0
    reason = "disabled";
    return;
end
if countRisingEdges(logs, "late_recovery_guard_state", spec.t_load_step, spec.stop_time) > 0
    reason = "current_rise_or_error_slope";
else
    reason = "not_triggered";
end
end

function timeUs = firstHighTimeUs(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
timeUs = NaN;
if isempty(sig)
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime & values > 0.5;
if any(mask)
    timeUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
end
end

function timeUs = decayDoneTimeUs(logs, spec)
sig = optionalSignal(logs, "Ton_boost_gain");
timeUs = NaN;
if isempty(sig)
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= spec.t_load_step & t <= spec.stop_time & values <= 0.1;
afterActive = t >= spec.t_load_step + 0.05e-6;
mask = mask & afterActive;
if any(mask)
    timeUs = 1e6 * (t(find(mask, 1, "first")) - spec.t_load_step);
else
    timeUs = firstHighTimeUs(logs, "fallback_to_nominal_state", spec.t_load_step, spec.stop_time);
end
end

function rate = phaseOrderErrorRate(logs, spec)
eventTimes = [];
eventPhases = [];
for phase = 1:4
    times = edgeTimes(logs, "REQ_accept" + phase, spec.t_load_step, spec.stop_time);
    eventTimes = [eventTimes; times(:)]; %#ok<AGROW>
    eventPhases = [eventPhases; phase * ones(numel(times), 1)]; %#ok<AGROW>
end
if numel(eventTimes) < 2
    rate = 0;
    return;
end
[eventTimes, order] = sort(eventTimes); %#ok<ASGLU>
eventPhases = eventPhases(order);
errors = 0;
checks = 0;
for idx = 2:numel(eventPhases)
    expected = mod(eventPhases(idx - 1), 4) + 1;
    if eventPhases(idx) ~= expected
        errors = errors + 1;
    end
    checks = checks + 1;
end
rate = errors / max(checks, 1);
end

function times = edgeTimes(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
times = zeros(0, 1);
if isempty(sig)
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:) > 0.5;
mask = t >= startTime & t <= endTime;
t = t(mask);
values = values(mask);
if isempty(values)
    return;
end
rise = [values(1); diff(values) > 0];
times = t(rise > 0);
end

function value = valueAtOptional(logs, name, sampleTime, defaultValue)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = defaultValue;
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
if isempty(t)
    value = defaultValue;
else
    value = interp1(t, data, sampleTime, "previous", "extrap");
end
end

function value = peakToPeakWindow(t, y, startTime, endTime)
vals = windowValues(t, y, startTime, endTime);
if isempty(vals)
    value = NaN;
else
    value = max(vals) - min(vals);
end
end

function [maxImb, rmsImb] = currentImbalance(logs, spec)
timeGrid = [];
currents = cell(1, 4);
for phase = 1:4
    [tp, il] = signalSeries(logs, "IL" + phase);
    mask = tp >= spec.t_load_step & tp <= spec.stop_time;
    timeGrid = [timeGrid; tp(mask)]; %#ok<AGROW>
    currents{phase} = {tp, il};
end
timeGrid = unique(timeGrid);
if isempty(timeGrid)
    maxImb = NaN;
    rmsImb = NaN;
    return;
end
maxRows = 50000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
vals = zeros(numel(timeGrid), 4);
for phase = 1:4
    tp = currents{phase}{1};
    il = currents{phase}{2};
    vals(:, phase) = interp1(tp, il, timeGrid, "linear", "extrap");
end
spread = max(vals, [], 2) - min(vals, [], 2);
maxImb = max(spread);
rmsImb = sqrt(mean((vals - mean(vals, 2)).^2, "all"));
end

function value = windowMaxMv(tauUs, vout, vref, startUs, endUs)
mask = tauUs >= startUs & tauUs <= endUs;
if any(mask)
    value = 1e3 * max(vout(mask) - vref);
else
    value = NaN;
end
end

function riseUs = currentRiseFromWave(tauUs, ilSum, spec, fraction)
threshold = spec.base_load_A + fraction * (spec.target_load_A - spec.base_load_A);
mask = tauUs >= 0 & ilSum >= threshold;
if any(mask)
    riseUs = tauUs(find(mask, 1, "first"));
else
    riseUs = NaN;
end
end

function value = ripplePpMv(tauUs, vout, startUs, endUs)
mask = tauUs >= startUs & tauUs <= endUs;
if any(mask)
    value = 1e3 * (max(vout(mask)) - min(vout(mask)));
else
    value = NaN;
end
end

function value = maxImbalanceFromWave(wave)
vals = [wave.IL1, wave.IL2, wave.IL3, wave.IL4];
spread = max(vals, [], 2) - min(vals, [], 2);
value = max(spread);
end

function value = rmsImbalanceFromWave(wave)
vals = [wave.IL1, wave.IL2, wave.IL3, wave.IL4];
value = sqrt(mean((vals - mean(vals, 2)).^2, "all"));
end

function values = interpOptionalSignal(logs, name, timeGrid, method)
sig = optionalSignal(logs, name);
if isempty(sig)
    values = NaN(size(timeGrid));
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
values = interp1(t, data, timeGrid, method, "extrap");
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
    if isa(found, "Simulink.SimulationData.Dataset")
        if found.numElements > 0
            sig = found.getElement(1);
        end
    elseif ~isempty(found)
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

function out = appendTable(base, row)
if isempty(base)
    out = row;
else
    out = [base; row]; %#ok<AGROW>
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
