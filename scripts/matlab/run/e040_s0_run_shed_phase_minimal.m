function rows = e040_s0_run_shed_phase_minimal(variants)
%E040_S0_RUN_SHED_PHASE_MINIMAL Run only the minimal E040-S0 shed-phase chunk.

if nargin < 1
    variants = ["S0", "S1", "S2", "S3"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E040_active_phase_add_shed", ...
    "S0_shed_phase_minimal");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e040_s0_metrics.csv");
summaryPath = fullfile(experimentRoot, "e040_s0_research_summary.md");
auditPath = fullfile(experimentRoot, "e040_s0_waveform_audit.md");

rows = table();
residualThreshold = NaN;
thresholdDetail = "pending S0 waveform-derived threshold";
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    if ~isnan(residualThreshold)
        spec.residual_current_threshold_A = residualThreshold;
        spec.residual_threshold_detail = thresholdDetail;
    end
    modelFile = "";
    auditCsv = fullfile(experimentRoot, spec.file_prefix + "_scheduler_audit.csv");
    try
        modelFile = e040_s0_build_shed_phase_model(spec.short_variant);
        [~, modelName] = fileparts(modelFile);
        load_system(modelFile);
        cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

        out = runCase(modelName, spec);
        logs = out.logsout;
        if spec.short_variant == "S0"
            [residualThreshold, thresholdDetail] = selectResidualThreshold(logs, spec);
            spec.residual_current_threshold_A = residualThreshold;
            spec.residual_threshold_detail = thresholdDetail;
        elseif isnan(spec.residual_current_threshold_A)
            spec.residual_current_threshold_A = 6.0;
            spec.residual_threshold_detail = "fallback threshold because S0 was not run first";
        end

        [metrics, auditRows] = collectMetrics(logs, spec);
        writetable(auditRows, auditCsv);
        row = rowFromMetrics(spec, metrics, true, "", modelFile, auditCsv);
        exportWaveSample(logs, spec, fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv"));
        writeVariantReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, row, auditCsv);
    catch ME
        details = errorDetails(ME);
        row = failureRow(spec, details, modelFile, auditCsv);
        writeFailureReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, details);
    end

    if isempty(rows)
        rows = row;
    else
        rows = [rows; row]; %#ok<AGROW>
    end
end

rows = finalizeRows(rows);
writetable(rows, metricsCsv);
[classification, detail] = classifyRows(rows);
writeSummary(summaryPath, rows, classification, detail, metricsCsv);
writeWaveformAudit(auditPath, rows, classification, experimentRoot);

fprintf("E040_S0_METRICS=%s\n", metricsCsv);
fprintf("E040_S0_SUMMARY=%s\n", summaryPath);
fprintf("E040_S0_WAVEFORM_AUDIT=%s\n", auditPath);
disp(rows);
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
spec.dwell_time_s = 3.0e-6;
spec.post_reentry_shed_delay_s = 1.0e-6;
spec.order_relock_window_s = 2.0e-6;
spec.severe_overshoot_band_V = 20e-3;
spec.residual_current_threshold_A = NaN;
spec.residual_threshold_detail = "not selected yet";
spec.T_trim_max_s = 25e-9;
spec.K_T = 2.2e-9;
spec.fallback_K_T = 1.0e-10;
spec.current_deadband_A = 0.15;
spec.sense_confidence = 1.0;
spec.calibration_enable = 1.0;
spec.v_error_budget = 15e-3;
spec.v_error_hard_limit = 60e-3;
spec.min_scale = 0.25;
spec.ton_diff_enable = 0.0;
spec.variant_mode = 0.0;
spec.expected_pre_phases = [1, 2, 3, 4];
spec.expected_post_phases = [1, 3];

if variant == "S0"
    spec.variant = "S0_fixed_four_phase_reference";
    spec.file_prefix = "e040_s0_s0_fixed4";
    spec.report_title = "E040-S0 S0 Fixed Four-Phase Reference";
elseif variant == "S1"
    spec.variant = "S1_immediate_four_to_two_shed";
    spec.file_prefix = "e040_s0_s1_immediate_shed";
    spec.report_title = "E040-S0 S1 Immediate Shed";
    spec.variant_mode = 1.0;
    spec.dwell_time_s = 0.0;
    spec.post_reentry_shed_delay_s = 0.0;
    spec.order_relock_window_s = 0.0;
elseif variant == "S2"
    spec.variant = "S2_guarded_shed_dwell_lockout";
    spec.file_prefix = "e040_s0_s2_guarded_shed";
    spec.report_title = "E040-S0 S2 Guarded Shed With Dwell/Lockout";
    spec.variant_mode = 2.0;
elseif variant == "S3"
    spec.variant = "S3_guarded_shed_residual_relock_aS";
    spec.file_prefix = "e040_s0_s3_residual_as";
    spec.report_title = "E040-S0 S3 Guarded Shed With Residual/Relock/a_S";
    spec.variant_mode = 3.0;
    spec.ton_diff_enable = 1.0;
else
    error("Unknown E040-S0 variant: %s", variant);
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
if isnan(spec.residual_current_threshold_A)
    residualThreshold = 0.0;
else
    residualThreshold = spec.residual_current_threshold_A;
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
in = in.setVariable("E040_Residual_Current_Threshold", residualThreshold);
in = in.setVariable("E040_Order_Relock_Window", spec.order_relock_window_s);
out = sim(in);
end

function [threshold, detail] = selectResidualThreshold(logs, spec)
[t2, il2] = signalSeries(logs, "IL2");
[t4, il4] = signalSeries(logs, "IL4");
startTime = spec.t_load_step + spec.dwell_time_s + spec.post_reentry_shed_delay_s;
endTime = startTime + 8e-6;
grid = unique([t2(:); t4(:)]);
mask = grid >= startTime & grid <= endTime;
grid = grid(mask);
if isempty(grid)
    threshold = 6.0;
    detail = "fallback 6 A because the S0 residual-current guard window was empty";
    return;
end
residual = abs([interp1(t2, il2, grid, "linear", "extrap"); ...
    interp1(t4, il4, grid, "linear", "extrap")]);
envelope95 = percentileValue(residual(:), 0.95);
threshold = envelope95 + 0.25;
detail = sprintf("95th percentile of abs(IL2,IL4) over %.3f-%.3f us after step plus 0.25 A; envelope95=%.6g A", ...
    1e6 * (startTime - spec.t_load_step), 1e6 * (endTime - spec.t_load_step), envelope95);
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
metrics.settling_time_us = settlingTimeUs(tV, vout, spec);
metrics.final_Vout_error_mV = 1e3 * mean(vout(finalMask) - spec.vref, "omitnan");
metrics.Vout_ripple_pp_mV = 1e3 * (max(vout(evalMask)) - min(vout(evalMask)));

[tN, nActive] = signalSeries(logs, "N_active");
metrics.N_active_initial = meanWindow(tN, nActive, spec.t_load_step - 8e-6, spec.t_load_step - 1e-6);
metrics.N_active_final = meanWindow(tN, nActive, finalStart, spec.stop_time);
metrics.active_phase_transition_time_us = transitionDownTimeUs(tN, nActive, spec.t_load_step, 2.5);
metrics.shed_accept_time_us = firstHighTimeUs(logs, "phase_shed_accept", spec.t_load_step, spec.stop_time);
metrics.phase_shed_request_count = countRisingEdges(logs, "phase_shed_request", spec.t_load_step, spec.stop_time);
metrics.phase_shed_accept_count = countRisingEdges(logs, "phase_shed_accept", spec.t_load_step, spec.stop_time);
metrics.phase_shed_reject_count = countRisingEdges(logs, "phase_shed_reject", spec.t_load_step, spec.stop_time);

metrics.current_limit_hit = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time) >= spec.current_limit_guard_A || ...
    maxOptionalSignal(logs, "current_limit_hit", spec.t_load_step, spec.stop_time) > 0.5;

activeMask = finalActiveMask(logs, finalStart, spec.stop_time);
realMetrics = currentMetrics(logs, "IL", activeMask, evalStart, spec.stop_time);
sensedMetrics = currentMetrics(logs, "IL_sense", activeMask, evalStart, spec.stop_time);
metrics.real_max_current_imbalance_A = realMetrics.max_imbalance;
metrics.real_rms_current_imbalance_A = realMetrics.rms_imbalance;
metrics.sensed_max_current_imbalance_A = sensedMetrics.max_imbalance;
metrics.sensed_rms_current_imbalance_A = sensedMetrics.rms_imbalance;

metrics.residual_current_threshold_A = spec.residual_current_threshold_A;
[metrics.residual_current_at_shed_phase2_A, metrics.residual_current_at_shed_phase4_A] = ...
    residualAtShed(logs, spec, metrics.shed_accept_time_us);
if isnan(metrics.shed_accept_time_us)
    metrics.residual_current_check = NaN;
else
    residualMax = max(abs([metrics.residual_current_at_shed_phase2_A, metrics.residual_current_at_shed_phase4_A]));
    metrics.residual_current_check = double(residualMax <= metrics.residual_current_threshold_A);
end

auditRows = schedulerAudit(logs, spec, metrics.shed_accept_time_us);
metrics.REQ_count = rawReqCount(logs, spec.t_load_step, spec.stop_time);
metrics.accepted_REQ_count = height(auditRows);
metrics.dropped_REQ_count = max(0, metrics.REQ_count - metrics.accepted_REQ_count);
metrics.inactive_phase_REQ_count = inactiveAcceptedReqCount(auditRows);
metrics.REQ_reject_count = max(metrics.dropped_REQ_count, ...
    countRisingEdges(logs, "REQ_reject_reason", spec.t_load_step, spec.stop_time));
metrics.phase_spacing_std_ns = phaseSpacingStdNs(auditRows.time_s);
[metrics.phase_order_error_rate, metrics.phase_order_error_rate_pre_shed, ...
    metrics.phase_order_error_rate_during_shed, metrics.phase_order_error_rate_post_shed] = ...
    phaseOrderMetrics(auditRows, spec, metrics.shed_accept_time_us);

metrics.Ton_trim_usage = trimUsage(logs, "Ton_trim", spec.T_trim_max_s, evalStart, spec.stop_time);
metrics.Lambda_trim_usage = 0.0;
metrics.a_S_enable_time_us = firstHighTimeUs(logs, "a_S_enable_after_shed", spec.t_load_step, spec.stop_time);
metrics.fallback_count = sumOptionalSignal(logs, "fallback_count", spec.t_load_step, spec.stop_time);
metrics.guard_clamp_count = sumOptionalSignal(logs, "guard_clamp_count", spec.t_load_step, spec.stop_time);
end

function auditRows = schedulerAudit(logs, spec, shedAcceptTimeUs)
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
timeUs = 1e6 * (eventTimes - spec.t_load_step);
logicalSlot = zeros(count, 1);
physicalPhase = eventPhases(:);
activeSet = strings(count, 1);
reqIn = zeros(count, 1);
reqAccept = ones(count, 1);
reqRejectReason = zeros(count, 1);
phaseIdxBefore = zeros(count, 1);
phaseIdxAfter = zeros(count, 1);
shedState = zeros(count, 1);
window = strings(count, 1);
for idx = 1:count
    t = eventTimes(idx);
    logicalSlot(idx) = valueAtOptional(logs, "logical_slot", t, 0);
    activeSet(idx) = activeSetString(logs, t);
    reqIn(idx) = anyRawReqAt(logs, t);
    reqRejectReason(idx) = valueAtOptional(logs, "REQ_reject_reason", t, 0);
    phaseIdxBefore(idx) = valueAtOptional(logs, "phase_idx", max(t - 1e-9, 0), NaN);
    phaseIdxAfter(idx) = valueAtOptional(logs, "phase_idx", min(t + 1e-9, spec.stop_time), NaN);
    shedState(idx) = valueAtOptional(logs, "shed_state", t, 0);
    window(idx) = windowName(t, spec, shedAcceptTimeUs);
end
auditRows = table(eventIndex, eventTimes(:), timeUs(:), logicalSlot, physicalPhase, ...
    activeSet, reqIn, reqAccept, reqRejectReason, phaseIdxBefore, phaseIdxAfter, shedState, window, ...
    'VariableNames', {'event_index','time_s','time_after_step_us','logical_slot', ...
    'physical_phase','active_phase_set','REQ_in','REQ_accept','REQ_reject_reason', ...
    'phase_idx_before','phase_idx_after','shed_state','window'});
end

function name = windowName(t, spec, shedAcceptTimeUs)
if isnan(shedAcceptTimeUs)
    name = "pre_shed";
    return;
end
shedTime = spec.t_load_step + shedAcceptTimeUs * 1e-6;
duringEnd = shedTime + max(spec.order_relock_window_s, 0);
if t < shedTime
    name = "pre_shed";
elseif t < duringEnd
    name = "during_shed";
else
    name = "post_shed";
end
end

function [overall, preRate, duringRate, postRate] = phaseOrderMetrics(auditRows, spec, shedAcceptTimeUs)
if height(auditRows) < 2
    overall = NaN; preRate = NaN; duringRate = NaN; postRate = NaN;
    return;
end
if isnan(shedAcceptTimeUs)
    preRate = orderErrorRate(auditRows.physical_phase, spec.expected_pre_phases);
    duringRate = NaN;
    postRate = NaN;
    overall = preRate;
    return;
end
preRows = auditRows(auditRows.window == "pre_shed", :);
duringRows = auditRows(auditRows.window == "during_shed", :);
postRows = auditRows(auditRows.window == "post_shed", :);
preRate = orderErrorRate(preRows.physical_phase, spec.expected_pre_phases);
duringRate = orderErrorRate(duringRows.physical_phase, spec.expected_post_phases);
postRate = orderErrorRate(postRows.physical_phase, spec.expected_post_phases);
if ~isnan(postRate)
    overall = postRate;
else
    overall = orderErrorRate(auditRows.physical_phase, spec.expected_post_phases);
end
end

function rate = orderErrorRate(eventPhases, expectedPhases)
eventPhases = eventPhases(:);
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
    expected = expectedPhases(nextIdx);
    errors = errors + double(eventPhases(idx) ~= expected);
    checks = checks + 1;
end
rate = errors / max(checks, 1);
end

function count = inactiveAcceptedReqCount(auditRows)
count = 0;
for idx = 1:height(auditRows)
    activeText = char(auditRows.active_phase_set(idx));
    phase = auditRows.physical_phase(idx);
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

function value = anyRawReqAt(logs, t)
value = 0;
for phase = 1:4
    value = max(value, valueAtOptional(logs, "REQ_raw" + phase, t, 0));
end
value = double(value > 0.5);
end

function value = valueAtOptional(logs, name, t, defaultValue)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = defaultValue;
    return;
end
time = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
value = interp1(time, data, t, "previous", "extrap");
if isnan(value)
    value = defaultValue;
end
end

function text = activeSetString(logs, t)
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

function valueUs = transitionDownTimeUs(t, y, startTime, threshold)
mask = t >= startTime & y <= threshold;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
else
    valueUs = NaN;
end
end

function [phase2, phase4] = residualAtShed(logs, spec, shedAcceptTimeUs)
if isnan(shedAcceptTimeUs)
    phase2 = NaN;
    phase4 = NaN;
    return;
end
tShed = spec.t_load_step + shedAcceptTimeUs * 1e-6;
phase2 = valueAtOptional(logs, "IL2", tShed, NaN);
phase4 = valueAtOptional(logs, "IL4", tShed, NaN);
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

function stdNs = phaseSpacingStdNs(eventTimes)
if numel(eventTimes) < 3
    stdNs = NaN;
else
    stdNs = 1e9 * std(diff(eventTimes));
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

function total = sumOptionalSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    total = 0;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime;
if any(mask)
    total = sum(values(mask) > 0.5);
else
    total = 0;
end
end

function valueUs = firstHighTimeUs(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    valueUs = NaN;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime & values > 0.5;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
else
    valueUs = NaN;
end
end

function rows = finalizeRows(rows)
for idx = 1:height(rows)
    if ~rows.success(idx)
        rows.classification_hint(idx) = "implementation_issue";
    elseif rows.variant(idx) == "S0"
        rows.classification_hint(idx) = "fixed_four_phase_reference";
    elseif rows.phase_shed_accept_count(idx) < 1 || rows.N_active_final(idx) > 2.5
        rows.classification_hint(idx) = "shed_not_accepted";
    elseif rows.current_limit_hit(idx)
        rows.classification_hint(idx) = "current_limit_hit";
    elseif rows.dropped_REQ_count(idx) > 0
        rows.classification_hint(idx) = "dropped_req";
    elseif rows.inactive_phase_REQ_count(idx) > 0
        rows.classification_hint(idx) = "inactive_phase_req";
    elseif rows.residual_current_check(idx) == 0
        rows.classification_hint(idx) = "residual_current_violation";
    elseif rows.phase_order_error_rate_post_shed(idx) > 0
        rows.classification_hint(idx) = "post_shed_phase_order_error";
    else
        rows.classification_hint(idx) = "local_shed_integrity_pass";
    end
end
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile, auditCsv)
row = table( ...
    string(spec.short_variant), success, string(errorMessage), string(spec.variant), ...
    string(modelFile), string(auditCsv), string(spec.residual_threshold_detail), ...
    m.N_active_initial, m.N_active_final, ...
    m.phase_shed_request_count, m.phase_shed_accept_count, m.phase_shed_reject_count, ...
    m.active_phase_transition_time_us, m.shed_accept_time_us, ...
    m.peak_overshoot_mV, m.peak_undershoot_mV, m.settling_time_us, ...
    m.final_Vout_error_mV, m.Vout_ripple_pp_mV, ...
    m.real_max_current_imbalance_A, m.real_rms_current_imbalance_A, ...
    m.sensed_max_current_imbalance_A, m.sensed_rms_current_imbalance_A, ...
    m.residual_current_at_shed_phase2_A, m.residual_current_at_shed_phase4_A, ...
    m.residual_current_threshold_A, m.residual_current_check, ...
    m.phase_order_error_rate, m.phase_order_error_rate_pre_shed, ...
    m.phase_order_error_rate_during_shed, m.phase_order_error_rate_post_shed, ...
    m.phase_spacing_std_ns, m.REQ_count, m.accepted_REQ_count, ...
    m.dropped_REQ_count, m.inactive_phase_REQ_count, m.REQ_reject_count, ...
    m.current_limit_hit, m.Ton_trim_usage, m.Lambda_trim_usage, ...
    m.a_S_enable_time_us, m.fallback_count, m.guard_clamp_count, ...
    "pending", ...
    'VariableNames', {'variant','success','error_message','variant_description', ...
    'model_file','scheduler_audit_csv','residual_threshold_detail', ...
    'N_active_initial','N_active_final', ...
    'phase_shed_request_count','phase_shed_accept_count','phase_shed_reject_count', ...
    'active_phase_transition_time_us','shed_accept_time_us', ...
    'peak_overshoot_mV','peak_undershoot_mV','settling_time_us', ...
    'final_Vout_error_mV','Vout_ripple_pp_mV', ...
    'real_max_current_imbalance_A','real_rms_current_imbalance_A', ...
    'sensed_max_current_imbalance_A','sensed_rms_current_imbalance_A', ...
    'residual_current_at_shed_phase2_A','residual_current_at_shed_phase4_A', ...
    'residual_current_threshold_A','residual_current_check', ...
    'phase_order_error_rate','phase_order_error_rate_pre_shed', ...
    'phase_order_error_rate_during_shed','phase_order_error_rate_post_shed', ...
    'phase_spacing_std_ns','REQ_count','accepted_REQ_count', ...
    'dropped_REQ_count','inactive_phase_REQ_count','REQ_reject_count', ...
    'current_limit_hit','Ton_trim_usage','Lambda_trim_usage', ...
    'a_S_enable_time_us','fallback_count','guard_clamp_count', ...
    'classification_hint'});
end

function row = failureRow(spec, errorMessage, modelFile, auditCsv)
emptyMetrics = struct( ...
    "N_active_initial", NaN, "N_active_final", NaN, ...
    "phase_shed_request_count", NaN, "phase_shed_accept_count", NaN, ...
    "phase_shed_reject_count", NaN, "active_phase_transition_time_us", NaN, ...
    "shed_accept_time_us", NaN, "peak_overshoot_mV", NaN, ...
    "peak_undershoot_mV", NaN, "settling_time_us", NaN, ...
    "final_Vout_error_mV", NaN, "Vout_ripple_pp_mV", NaN, ...
    "real_max_current_imbalance_A", NaN, "real_rms_current_imbalance_A", NaN, ...
    "sensed_max_current_imbalance_A", NaN, "sensed_rms_current_imbalance_A", NaN, ...
    "residual_current_at_shed_phase2_A", NaN, ...
    "residual_current_at_shed_phase4_A", NaN, ...
    "residual_current_threshold_A", spec.residual_current_threshold_A, ...
    "residual_current_check", NaN, ...
    "phase_order_error_rate", NaN, "phase_order_error_rate_pre_shed", NaN, ...
    "phase_order_error_rate_during_shed", NaN, "phase_order_error_rate_post_shed", NaN, ...
    "phase_spacing_std_ns", NaN, "REQ_count", NaN, "accepted_REQ_count", NaN, ...
    "dropped_REQ_count", NaN, "inactive_phase_REQ_count", NaN, "REQ_reject_count", NaN, ...
    "current_limit_hit", false, "Ton_trim_usage", NaN, "Lambda_trim_usage", NaN, ...
    "a_S_enable_time_us", NaN, "fallback_count", NaN, "guard_clamp_count", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage, modelFile, auditCsv);
end

function [classification, detail] = classifyRows(rows)
if any(~rows.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E040-S0 variant failed before reliable metrics were produced.";
    return;
end
needed = ["S0", "S1", "S2", "S3"];
for idx = 1:numel(needed)
    if ~any(rows.variant == needed(idx))
        classification = "IMPLEMENTATION_ISSUE";
        detail = "Missing required E040-S0 variant " + needed(idx) + ".";
        return;
    end
end
s0 = rows(rows.variant == "S0", :);
s3 = rows(rows.variant == "S3", :);
integrity = s3.phase_shed_accept_count >= 1 && s3.N_active_final <= 2.5 && ...
    s3.dropped_REQ_count == 0 && s3.inactive_phase_REQ_count == 0 && ...
    s3.phase_order_error_rate_post_shed == 0 && ~s3.current_limit_hit && ...
    s3.residual_current_check == 1;
voltageOk = s3.peak_overshoot_mV <= s0.peak_overshoot_mV + 5.0 && ...
    s3.peak_undershoot_mV <= s0.peak_undershoot_mV + 5.0 && ...
    abs(s3.final_Vout_error_mV) <= abs(s0.final_Vout_error_mV) + 20.0;
currentOk = s3.real_max_current_imbalance_A <= max(s0.real_max_current_imbalance_A + 1.0, 1.0);
if integrity && voltageOk && currentOk
    classification = "MODEL_CONFIRMED";
    detail = "Guarded residual-qualified S3 shed preserved local 4->2 event integrity and stayed within S0 voltage/current bounds.";
elseif integrity
    classification = "MODEL_REVISED";
    detail = "S3 preserved shed event integrity, but voltage or current-sharing recovery still needs tuning before broader shed claims.";
elseif any(rows.phase_shed_accept_count(rows.variant ~= "S0") >= 1)
    classification = "MODEL_REVISED";
    detail = "At least one shed transition occurred, but the guarded S3 minimum pass criteria were not all satisfied.";
else
    classification = "CLAIM_DOWNGRADED";
    detail = "No tested shed-phase variant produced an interpretable accepted 4->2 transition.";
end
end

function exportWaveSample(logs, spec, csvPath)
[t, vout] = signalSeries(logs, "Vout");
[ti, iload] = signalSeries(logs, "Iload");
[tn, nActive] = signalSeries(logs, "N_active");
timeGrid = unique([t(:); ti(:); tn(:)]);
maxRows = 25000;
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
    [tp, il] = signalSeries(logs, "IL" + phase);
    out.("IL" + phase) = interp1(tp, il, timeGrid, "linear", "extrap");
    [tq, qh] = signalSeries(logs, "QH" + phase);
    out.("QH" + phase) = interp1(tq, qh, timeGrid, "previous", "extrap");
    out.("REQ_accept" + phase) = interpOptionalSignal(logs, "REQ_accept" + phase, timeGrid);
end
for name = ["phase_shed_request", "phase_shed_accept", "phase_shed_reject", ...
        "shed_state", "shed_lockout_state", "residual_current_check", ...
        "order_relock_state", "a_S_enable_after_shed", "a_S_mode"]
    out.(name) = interpOptionalSignal(logs, name, timeGrid);
end
writetable(out, csvPath);
end

function values = interpOptionalSignal(logs, name, timeGrid)
sig = optionalSignal(logs, name);
if isempty(sig)
    values = NaN(size(timeGrid));
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
values = interp1(t, data, timeGrid, "previous", "extrap");
end

function writeVariantReport(reportPath, modelFile, spec, row, auditCsv)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "S0 tests whether a mild external `40A -> 20A` load drop can shed from four phases to the corrected two-phase `[1,3]` mapping without REQ loss, inactive-phase requests, residual-current violation, or post-shed order error. The supervisor never commands gates or load-current slew.\n\n");
fprintf(fid, "## Model Copy Path\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Scheduler Audit CSV\n\n`%s`\n\n", slashPath(auditCsv));
fprintf(fid, "## Residual Threshold\n\n`%.6g A`\n\n%s\n\n", ...
    spec.residual_current_threshold_A, spec.residual_threshold_detail);
fprintf(fid, "## Key Parameters\n\n");
fprintf(fid, "- `I_shed_low = %.6g A`\n", spec.I_shed_low_A);
fprintf(fid, "- `dwell_time = %.6g us`\n", 1e6 * spec.dwell_time_s);
fprintf(fid, "- `post_reentry_shed_delay = %.6g us`\n", 1e6 * spec.post_reentry_shed_delay_s);
fprintf(fid, "- `order_relock_window = %.6g us`\n", 1e6 * spec.order_relock_window_s);
fprintf(fid, "- `active Lambda = disabled`\n\n");
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
fprintf(fid, "- Error: `%s`\n", message);
end

function writeSummary(summaryPath, rows, classification, detail, metricsCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S0 Minimal Shed-Phase Summary\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Local derived-Simulink validation for `40A -> 20A`, `4 -> 2` active-phase shed only. Baseline source: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`.\n\n");
fprintf(fid, "## Design Under Test\n\n");
fprintf(fid, "Four-phase events are preserved before shed. After shed, accepted events are remapped onto physical phases `[1,3]`. S3 gates shed by dwell, post-reentry delay, residual-current threshold, order relock, and delayed a_S enable. Active Lambda remains disabled.\n\n");
fprintf(fid, "## Metrics CSV\n\n`%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Interpretation\n\n");
writeInterpretation(fid, rows);
fprintf(fid, "## Classification\n\n`%s`\n\n%s\n\n", classification, detail);
fprintf(fid, "## Claim Boundary\n\n");
if classification == "MODEL_CONFIRMED"
    fprintf(fid, "Allowed claim: in the local ideal IQCOT derived model, a residual-qualified guarded shed can perform the mild `40A -> 20A`, `4 -> 2` transition while preserving REQ integrity and post-shed two-phase order. This remains Simulink-only evidence.\n\n");
else
    fprintf(fid, "S0 does not yet support broad shed claims. Active-phase shedding still requires revised lockout, residual-current qualification, order relock, or recovery gating before expansion.\n\n");
end
fprintf(fid, "Forbidden claims remain: broad active-phase robustness, arbitrary 1/2/4 scheduling, severe shed behavior, active Lambda, efficiency gain, hardware, HIL, board-level, or silicon validation.\n");
end

function writeWaveformAudit(auditPath, rows, classification, experimentRoot)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-S0 Waveform And Scheduler Audit\n\n");
fprintf(fid, "Date: %s\n\n", reportDate());
fprintf(fid, "## Signal Boundary\n\n");
fprintf(fid, "The run requires voltage/load/current/gate logs plus `REQ_raw1..4`, `REQ_accept1..4`, `phase_idx`, `logical_slot`, `physical_phase_selected`, `active_phase_set`, `N_active`, shed-state, residual-current, order-relock, and delayed a_S logs.\n\n");
if any(~rows.success)
    fprintf(fid, "At least one variant failed, so signal completeness is not fully established. See per-variant reports.\n\n");
else
    fprintf(fid, "All variants produced metric rows and per-variant scheduler audit CSV files.\n\n");
end
fprintf(fid, "## Residual Threshold\n\n");
if any(rows.variant == "S0")
    s0 = rows(rows.variant == "S0", :);
    fprintf(fid, "Threshold selected from S0 fixed-four-phase waveform: `%.6g A`.\n\n%s\n\n", ...
        s0.residual_current_threshold_A(1), s0.residual_threshold_detail(1));
end
fprintf(fid, "## Metrics Snapshot\n\n");
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Scheduler Audit Files\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), slashPath(rows.scheduler_audit_csv(idx)));
end
fprintf(fid, "\n## Wave Samples\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), ...
        slashPath(fullfile(experimentRoot, filePrefixForVariant(rows.variant(idx)) + "_wave_sample.csv")));
end
fprintf(fid, "\n## Classification\n\n`%s`\n", classification);
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | N init | N final | Shed accept | Overshoot mV | Undershoot mV | Final err mV | Resid p2 A | Resid p4 A | Resid pass | Post order err | Dropped REQ | Inactive REQ | a_S us | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.N_active_initial(idx), ...
        rows.N_active_final(idx), rows.phase_shed_accept_count(idx), ...
        rows.peak_overshoot_mV(idx), rows.peak_undershoot_mV(idx), ...
        rows.final_Vout_error_mV(idx), rows.residual_current_at_shed_phase2_A(idx), ...
        rows.residual_current_at_shed_phase4_A(idx), rows.residual_current_check(idx), ...
        rows.phase_order_error_rate_post_shed(idx), rows.dropped_REQ_count(idx), ...
        rows.inactive_phase_REQ_count(idx), rows.a_S_enable_time_us(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function writeInterpretation(fid, rows)
if any(~rows.success)
    fprintf(fid, "The run is not fully interpretable because at least one row failed.\n\n");
    return;
end
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: N_final `%.6g`, shed_accept `%.6g`, dropped_REQ `%.6g`, inactive_REQ `%.6g`, residual_pass `%.6g`, post_order_error `%.6g`, hint `%s`.\n", ...
        rows.variant(idx), rows.N_active_final(idx), rows.phase_shed_accept_count(idx), ...
        rows.dropped_REQ_count(idx), rows.inactive_phase_REQ_count(idx), ...
        rows.residual_current_check(idx), rows.phase_order_error_rate_post_shed(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function prefix = filePrefixForVariant(variant)
variant = string(variant);
if variant == "S0"
    prefix = "e040_s0_s0_fixed4";
elseif variant == "S1"
    prefix = "e040_s0_s1_immediate_shed";
elseif variant == "S2"
    prefix = "e040_s0_s2_guarded_shed";
elseif variant == "S3"
    prefix = "e040_s0_s3_residual_as";
else
    prefix = "e040_s0_unknown";
end
end

function text = reportDate()
text = char(datetime("today", "Format", "yyyy-MM-dd"));
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

function value = percentileValue(values, fraction)
values = sort(values(~isnan(values)));
if isempty(values)
    value = NaN;
    return;
end
idx = max(1, min(numel(values), ceil(fraction * numel(values))));
value = values(idx);
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
