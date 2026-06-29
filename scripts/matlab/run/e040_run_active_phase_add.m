function rows = e040_run_active_phase_add(variants)
%e040_run_active_phase_add Run the minimal E040-A 2->4 add-phase chunk.

if nargin < 1
    variants = ["D0", "D1", "D2", "D3"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E040_active_phase_add_shed");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e040_metrics.csv");
summaryPath = fullfile(experimentRoot, "e040_research_summary.md");
auditPath = fullfile(experimentRoot, "e040_waveform_audit.md");

rows = table();
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    modelFile = "";
    try
        modelFile = e040_build_active_phase_add_model(spec.short_variant);
        [~, modelName] = fileparts(modelFile);
        load_system(modelFile);
        cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

        out = runCase(modelName, spec);
        logs = out.logsout;
        metrics = collectMetrics(logs, spec);
        row = rowFromMetrics(spec, metrics, true, "", modelFile);
        exportWaveSample(logs, spec, fullfile(experimentRoot, spec.file_prefix + "_wave_sample.csv"));
        writeVariantReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, row);
    catch ME
        details = errorDetails(ME);
        row = failureRow(spec, details, modelFile);
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
writeWaveformAudit(auditPath, rows, classification);

fprintf("E040_METRICS=%s\n", metricsCsv);
fprintf("E040_SUMMARY=%s\n", summaryPath);
fprintf("E040_WAVEFORM_AUDIT=%s\n", auditPath);
disp(rows);
end

function spec = variantSpec(variant)
variant = string(variant);
spec = struct();
spec.short_variant = variant;
spec.base_load_A = 20;
spec.target_load_A = 40;
spec.t_load_step = 0.45e-3;
spec.stop_time = 0.52e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.settle_band_V = 1.0e-3;
spec.current_limit_guard_A = 55;
spec.I_add_high_A = 30;
spec.dwell_time_s = 2.0e-6;
spec.new_phase_ramp_time_s = 4.0e-6;
spec.severe_overshoot_band_V = 20e-3;
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
spec.residual_current_threshold_A = 0.0;

if variant == "D0"
    spec.variant = "D0_fixed_two_phase_no_add";
    spec.file_prefix = "e040_d0_fixed_two_phase";
    spec.report_title = "E040-A D0 Fixed Two-Phase Reference";
elseif variant == "D1"
    spec.variant = "D1_immediate_two_to_four_add";
    spec.file_prefix = "e040_d1_immediate_add";
    spec.report_title = "E040-A D1 Immediate Add";
    spec.variant_mode = 1.0;
    spec.dwell_time_s = 0.0;
    spec.new_phase_ramp_time_s = 0.0;
elseif variant == "D2"
    spec.variant = "D2_guarded_add_with_frozen_aS";
    spec.file_prefix = "e040_d2_guarded_add_as";
    spec.report_title = "E040-A D2 Guarded Add With Frozen a_S";
    spec.variant_mode = 2.0;
    spec.ton_diff_enable = 1.0;
elseif variant == "D3"
    spec.variant = "D3_guarded_add_with_confidence_check";
    spec.file_prefix = "e040_d3_guarded_add_confidence";
    spec.report_title = "E040-A D3 Guarded Add With Confidence Check";
    spec.variant_mode = 3.0;
    spec.ton_diff_enable = 1.0;
else
    error("Unknown E040-A variant: %s", variant);
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
in = in.setVariable("Iout", spec.target_load_A);
in = in.setVariable("Iph", spec.target_load_A / 4);
for phase = 1:4
    in = in.setVariable("DCR_L" + phase, 0.01);
    in = in.setVariable("E040_IL_Sense_Gain" + phase, 1.0);
end
in = in.setVariable("E040_Variant_Mode", spec.variant_mode);
in = in.setVariable("E040_LoadStep_Time", spec.t_load_step);
in = in.setVariable("E040_I_Add_High", spec.I_add_high_A);
in = in.setVariable("E040_Dwell_Time", spec.dwell_time_s);
in = in.setVariable("E040_New_Phase_Ramp_Time", spec.new_phase_ramp_time_s);
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
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
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
metrics.active_phase_transition_time_us = transitionTimeUs(tN, nActive, spec.t_load_step, 3.5);
metrics.phase_add_accept_count = countRisingEdges(logs, "phase_add_accept", spec.t_load_step, spec.stop_time);
metrics.phase_shed_accept_count = countRisingEdges(logs, "phase_shed_accept", spec.t_load_step, spec.stop_time);
metrics.phase_add_reject_count = countRisingEdges(logs, "phase_add_reject", spec.t_load_step, spec.stop_time);
metrics.phase_shed_reject_count = countRisingEdges(logs, "phase_shed_request", spec.t_load_step, spec.stop_time);

activeMask = finalActiveMask(logs, finalStart, spec.stop_time);
metrics.current_limit_hit = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time) >= spec.current_limit_guard_A;
metrics.new_phase_current_ramp_time_us = newPhaseRampTimeUs(logs, spec);
metrics.new_phase_current_overshoot_A = newPhaseOvershootA(logs, spec);
metrics.residual_current_at_shed_A = NaN;
metrics.residual_current_threshold_A = spec.residual_current_threshold_A;

realMetrics = currentMetrics(logs, "IL", activeMask, evalStart, spec.stop_time);
sensedMetrics = currentMetrics(logs, "IL_sense", activeMask, evalStart, spec.stop_time);
metrics.real_max_current_imbalance_A = realMetrics.max_imbalance;
metrics.real_rms_current_imbalance_A = realMetrics.rms_imbalance;
metrics.sensed_max_current_imbalance_A = sensedMetrics.max_imbalance;
metrics.sensed_rms_current_imbalance_A = sensedMetrics.rms_imbalance;

[eventTimes, eventPhases] = phaseEvents(logs, activeMask, evalStart, spec.stop_time);
metrics.phase_spacing_std_ns = phaseSpacingStdNs(eventTimes);
metrics.phase_order_error_rate = phaseOrderErrorRate(eventPhases, find(activeMask));
metrics.REQ_count = reqCount(logs, activeMask, evalStart, spec.stop_time, "REQ");
metrics.raw_REQ_count = reqCount(logs, activeMask, evalStart, spec.stop_time, "REQ_raw");
metrics.dropped_REQ_count = max(0, metrics.raw_REQ_count - metrics.REQ_count);
metrics.Ton_trim_usage = trimUsage(logs, "Ton_trim", spec.T_trim_max_s, evalStart, spec.stop_time);
metrics.Lambda_trim_usage = 0.0;
metrics.fallback_count = sumOptionalSignal(logs, "fallback_count", evalStart, spec.stop_time);
metrics.guard_clamp_count = sumOptionalSignal(logs, "guard_clamp_count", evalStart, spec.stop_time);
end

function mask = finalActiveMask(logs, startTime, endTime)
sig = logs.get("active_phase_set");
if isempty(sig)
    mask = [true, true, true, true];
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = orientMatrix(data, 4);
timeMask = t >= startTime & t <= endTime;
if any(timeMask)
    vals = mean(data(timeMask, :), 1, "omitnan");
else
    vals = data(end, :);
end
mask = vals > 0.5;
if ~any(mask)
    mask = [true, true, false, false];
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

function valueUs = transitionTimeUs(t, y, startTime, threshold)
mask = t >= startTime & y >= threshold;
if any(mask)
    valueUs = 1e6 * (t(find(mask, 1, "first")) - startTime);
else
    valueUs = NaN;
end
end

function valueUs = newPhaseRampTimeUs(logs, spec)
[tN, nActive] = signalSeries(logs, "N_active");
transitionTime = transitionTimeUs(tN, nActive, spec.t_load_step, 3.5);
if isnan(transitionTime)
    valueUs = NaN;
    return;
end
acceptTime = spec.t_load_step + transitionTime * 1e-6;
target = 0.9 * spec.target_load_A / 4;
[t3, il3] = signalSeries(logs, "IL3");
[t4, il4] = signalSeries(logs, "IL4");
timeGrid = unique([t3(:); t4(:)]);
mask = timeGrid >= acceptTime & timeGrid <= spec.stop_time;
timeGrid = timeGrid(mask);
if isempty(timeGrid)
    valueUs = NaN;
    return;
end
newCurrent = 0.5 * (interp1(t3, il3, timeGrid, "linear", "extrap") + ...
    interp1(t4, il4, timeGrid, "linear", "extrap"));
hit = newCurrent >= target;
if any(hit)
    valueUs = 1e6 * (timeGrid(find(hit, 1, "first")) - acceptTime);
else
    valueUs = NaN;
end
end

function overshoot = newPhaseOvershootA(logs, spec)
[t3, il3] = signalSeries(logs, "IL3");
[t4, il4] = signalSeries(logs, "IL4");
target = spec.target_load_A / 4;
mask3 = t3 >= spec.t_load_step & t3 <= spec.stop_time;
mask4 = t4 >= spec.t_load_step & t4 <= spec.stop_time;
peak = max([max(il3(mask3)), max(il4(mask4))]);
overshoot = peak - target;
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

function [eventTimes, eventPhases] = phaseEvents(logs, activeMask, startTime, endTime)
eventTimes = [];
eventPhases = [];
for phase = 1:4
    if ~activeMask(phase)
        continue;
    end
    [t, values] = signalSeries(logs, "QH" + phase);
    edges = t(find(diff(values > 0.5) > 0) + 1);
    edges = edges(edges >= startTime & edges <= endTime);
    eventTimes = [eventTimes; edges(:)]; %#ok<AGROW>
    eventPhases = [eventPhases; phase * ones(numel(edges), 1)]; %#ok<AGROW>
end
[eventTimes, order] = sort(eventTimes);
eventPhases = eventPhases(order);
end

function stdNs = phaseSpacingStdNs(eventTimes)
if numel(eventTimes) < 3
    stdNs = NaN;
else
    stdNs = 1e9 * std(diff(eventTimes));
end
end

function rate = phaseOrderErrorRate(eventPhases, activePhases)
if numel(eventPhases) < 2 || isempty(activePhases)
    rate = NaN;
    return;
end
errors = 0;
for idx = 2:numel(eventPhases)
    prevIdx = find(activePhases == eventPhases(idx - 1), 1);
    if isempty(prevIdx)
        errors = errors + 1;
        continue;
    end
    nextIdx = prevIdx + 1;
    if nextIdx > numel(activePhases)
        nextIdx = 1;
    end
    expected = activePhases(nextIdx);
    if eventPhases(idx) ~= expected
        errors = errors + 1;
    end
end
rate = errors / (numel(eventPhases) - 1);
end

function count = reqCount(logs, activeMask, startTime, endTime, prefix)
count = 0;
for phase = 1:4
    if ~activeMask(phase)
        continue;
    end
    count = count + countRisingEdges(logs, prefix + phase, startTime, endTime);
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
    count = 0;
else
    count = sum(diff(values > 0.5) > 0);
    if values(1) > 0.5
        count = count + 1;
    end
end
end

function usage = trimUsage(logs, prefix, limitValue, startTime, endTime)
if limitValue <= 0
    usage = 0;
    return;
end
peak = 0;
for phase = 1:4
    sig = optionalSignal(logs, prefix + phase);
    if isempty(sig)
        continue;
    end
    t = sig.Values.Time(:);
    values = squeeze(double(sig.Values.Data));
    values = values(:);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        peak = max(peak, max(abs(values(mask))));
    end
end
usage = peak / limitValue;
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

function rows = finalizeRows(rows)
for idx = 1:height(rows)
    if ~rows.success(idx)
        rows.classification_hint(idx) = "implementation_issue";
    elseif rows.variant(idx) == "D0"
        rows.classification_hint(idx) = "fixed_two_phase_reference";
    elseif rows.phase_add_accept_count(idx) < 1 || rows.N_active_final(idx) < 3.5
        rows.classification_hint(idx) = "add_not_accepted";
    elseif rows.phase_shed_accept_count(idx) > 0
        rows.classification_hint(idx) = "unexpected_shed";
    elseif rows.current_limit_hit(idx)
        rows.classification_hint(idx) = "current_limit_hit";
    elseif rows.dropped_REQ_count(idx) > 0
        rows.classification_hint(idx) = "dropped_req";
    elseif rows.phase_order_error_rate(idx) > 0
        rows.classification_hint(idx) = "phase_order_error";
    elseif rows.real_max_current_imbalance_A(idx) > 1.0
        rows.classification_hint(idx) = "post_add_imbalance_high";
    else
        rows.classification_hint(idx) = "guarded_add_clean";
    end
end
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = table( ...
    string(spec.short_variant), success, string(errorMessage), string(spec.variant), string(modelFile), ...
    m.peak_overshoot_mV, m.peak_undershoot_mV, m.settling_time_us, ...
    m.final_Vout_error_mV, m.Vout_ripple_pp_mV, ...
    m.active_phase_transition_time_us, m.N_active_initial, m.N_active_final, ...
    m.phase_add_accept_count, m.phase_shed_accept_count, ...
    m.phase_add_reject_count, m.phase_shed_reject_count, ...
    m.new_phase_current_ramp_time_us, m.new_phase_current_overshoot_A, ...
    m.residual_current_at_shed_A, m.residual_current_threshold_A, ...
    m.real_max_current_imbalance_A, m.real_rms_current_imbalance_A, ...
    m.sensed_max_current_imbalance_A, m.sensed_rms_current_imbalance_A, ...
    m.phase_spacing_std_ns, m.phase_order_error_rate, ...
    m.REQ_count, m.dropped_REQ_count, m.current_limit_hit, ...
    m.Ton_trim_usage, m.Lambda_trim_usage, m.fallback_count, m.guard_clamp_count, ...
    "pending", ...
    'VariableNames', {'variant','success','error_message','variant_description','model_file', ...
    'peak_overshoot_mV','peak_undershoot_mV','settling_time_us', ...
    'final_Vout_error_mV','Vout_ripple_pp_mV', ...
    'active_phase_transition_time_us','N_active_initial','N_active_final', ...
    'phase_add_accept_count','phase_shed_accept_count', ...
    'phase_add_reject_count','phase_shed_reject_count', ...
    'new_phase_current_ramp_time_us','new_phase_current_overshoot_A', ...
    'residual_current_at_shed_A','residual_current_threshold_A', ...
    'real_max_current_imbalance_A','real_rms_current_imbalance_A', ...
    'sensed_max_current_imbalance_A','sensed_rms_current_imbalance_A', ...
    'phase_spacing_std_ns','phase_order_error_rate', ...
    'REQ_count','dropped_REQ_count','current_limit_hit', ...
    'Ton_trim_usage','Lambda_trim_usage','fallback_count','guard_clamp_count', ...
    'classification_hint'});
end

function row = failureRow(spec, errorMessage, modelFile)
emptyMetrics = struct( ...
    "peak_overshoot_mV", NaN, ...
    "peak_undershoot_mV", NaN, ...
    "settling_time_us", NaN, ...
    "final_Vout_error_mV", NaN, ...
    "Vout_ripple_pp_mV", NaN, ...
    "active_phase_transition_time_us", NaN, ...
    "N_active_initial", NaN, ...
    "N_active_final", NaN, ...
    "phase_add_accept_count", NaN, ...
    "phase_shed_accept_count", NaN, ...
    "phase_add_reject_count", NaN, ...
    "phase_shed_reject_count", NaN, ...
    "new_phase_current_ramp_time_us", NaN, ...
    "new_phase_current_overshoot_A", NaN, ...
    "residual_current_at_shed_A", NaN, ...
    "residual_current_threshold_A", spec.residual_current_threshold_A, ...
    "real_max_current_imbalance_A", NaN, ...
    "real_rms_current_imbalance_A", NaN, ...
    "sensed_max_current_imbalance_A", NaN, ...
    "sensed_rms_current_imbalance_A", NaN, ...
    "phase_spacing_std_ns", NaN, ...
    "phase_order_error_rate", NaN, ...
    "REQ_count", NaN, ...
    "dropped_REQ_count", NaN, ...
    "current_limit_hit", false, ...
    "Ton_trim_usage", NaN, ...
    "Lambda_trim_usage", NaN, ...
    "fallback_count", NaN, ...
    "guard_clamp_count", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage, modelFile);
end

function [classification, detail] = classifyRows(rows)
if any(~rows.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E040-A variant failed before reliable metrics were produced.";
    return;
end
needed = ["D0", "D1", "D2", "D3"];
for idx = 1:numel(needed)
    if ~any(rows.variant == needed(idx))
        classification = "IMPLEMENTATION_ISSUE";
        detail = "Missing required E040-A variant " + needed(idx) + ".";
        return;
    end
end
tested = rows(rows.variant ~= "D0", :);
accepted = tested.phase_add_accept_count >= 1 & tested.N_active_final >= 3.5;
integrity = tested.dropped_REQ_count == 0 & tested.phase_order_error_rate == 0 & ...
    tested.phase_shed_accept_count == 0 & ~tested.current_limit_hit;
boundedCurrent = tested.real_max_current_imbalance_A <= 1.0;
boundedVoltage = tested.peak_undershoot_mV < 250 & tested.peak_overshoot_mV < 50;
if all(accepted & integrity & boundedCurrent & boundedVoltage)
    classification = "MODEL_CONFIRMED";
    detail = "D1-D3 all accepted the 2->4 add transition and preserved voltage, current, REQ, phase-order, and current-limit guards in the local derived model.";
elseif any(accepted & integrity)
    classification = "MODEL_REVISED";
    detail = "At least one add transition worked, but dwell/ramp/current-sharing/voltage guards require retuning before broad E040 or E040-S.";
elseif any(accepted)
    classification = "MODEL_REVISED";
    detail = "The active-phase transition occurred but failed at least one integrity or bound check.";
else
    classification = "CLAIM_DOWNGRADED";
    detail = "No tested E040-A add-phase variant produced an interpretable accepted 2->4 transition.";
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
end
for name = ["phase_add_request", "phase_add_accept", "phase_add_reject", ...
        "new_phase_ramp_state", "balance_recovery_state", "a_S_mode"]
    sig = optionalSignal(logs, name);
    if ~isempty(sig)
        out.(name) = interpSignal(sig, timeGrid, "previous");
    end
end
writetable(out, csvPath);
end

function values = interpSignal(sig, timeGrid, method)
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
values = interp1(t, data, timeGrid, method, "extrap");
end

function writeVariantReport(reportPath, modelFile, spec, row)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "This run evaluates the E040-A `20A -> 40A` external load-current rise with initial two active phases and a local active-phase add policy. The supervisor gates IQCOT request/Ton parameter paths and never commands QH/QL gates or external load slew.\n\n");
fprintf(fid, "## Model Copy Path\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Variant\n\n`%s`\n\n", spec.variant);
fprintf(fid, "## Key Parameters\n\n");
fprintf(fid, "- `I_add_high = %.6g A`\n", spec.I_add_high_A);
fprintf(fid, "- `dwell_time = %.6g us`\n", 1e6 * spec.dwell_time_s);
fprintf(fid, "- `new_phase_ramp_time = %.6g us`\n", 1e6 * spec.new_phase_ramp_time_s);
fprintf(fid, "- `current_limit_guard = %.6g A/phase`\n", spec.current_limit_guard_A);
fprintf(fid, "- `active Lambda = disabled`\n\n");
fprintf(fid, "## Metrics\n\n");
writeMetricsMarkdownTable(fid, row);
fprintf(fid, "## Per-Run Classification Hint\n\n`%s`\n", row.classification_hint(1));
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "The derived model or run failed before interpretable E040-A metrics were produced.\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Baseline path: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n");
fprintf(fid, "- Variant: `%s`\n", spec.variant);
fprintf(fid, "- Error: `%s`\n", message);
end

function writeSummary(summaryPath, rows, classification, detail, metricsCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040 Active-Phase Research Summary\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "E040-A tests whether a local guarded active-phase add transition can move from two to four active phases during a moderate external `20A -> 40A` load-current rise without voltage disruption, REQ loss, phase-order error, current-limit hit, or post-add current-sharing instability.\n\n");
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Model Copy Paths\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), slashPath(rows.model_file(idx)));
end
fprintf(fid, "\n## External Load And Active-Phase Case\n\n");
fprintf(fid, "`20A -> 40A`, initial active phases `2`, target active phases `4`, nominal DCR, nominal current-sense gains, active Lambda disabled.\n\n");
fprintf(fid, "## Frozen a_S Selector\n\n");
fprintf(fid, "The E030-R3 local guarded selector is used after add/reentry. In this first nominal-sensing chunk, calibrated `C4a`-like Ton-difference recovery is allowed only after the add ramp reaches reentry completion. Active Lambda remains disabled.\n\n");
fprintf(fid, "## Metrics Table\n\nMetrics CSV: `%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Interpretation\n\n");
writeInterpretation(fid, rows);
fprintf(fid, "## Failure Or Trade-Off Analysis\n\n%s\n\n", detail);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "## Claim Boundary\n\n");
fprintf(fid, "This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad active-phase robustness, E040-S shed behavior, active Lambda control, global efficiency improvement, or severe load-rise recovery.\n\n");
fprintf(fid, "## Next Smallest Useful Experiment\n\n");
if classification == "MODEL_CONFIRMED"
    fprintf(fid, "Audit the waveform samples, then prepare E040-S only after explicitly accepting this E040-A classification.\n");
elseif classification == "MODEL_REVISED"
    fprintf(fid, "Retune dwell/ramp/current-sharing guard parameters and rerun the same E040-A chunk before E040-S.\n");
elseif classification == "IMPLEMENTATION_ISSUE"
    fprintf(fid, "Fix active-phase supervisor wiring/logging/postprocess and rerun D0-D3.\n");
else
    fprintf(fid, "Downgrade active-phase add claims and revisit the hybrid event model before running shed validation.\n");
end
end

function writeWaveformAudit(auditPath, rows, classification)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E040-A Waveform Audit\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Audit for the minimal E040-A add-phase chunk: `20A -> 40A`, `2 -> 4` active phases, D0/D1/D2/D3, nominal sensing, active Lambda disabled.\n\n");
fprintf(fid, "## Required Signal Status\n\n");
if any(~rows.success)
    fprintf(fid, "At least one variant failed, so signal status is incomplete. See per-variant reports for implementation errors.\n\n");
else
    fprintf(fid, "All variants produced metric rows with required voltage, current, REQ, phase, Ton, active-phase, guard, and selector logs.\n\n");
end
fprintf(fid, "| Variant | Success | N initial | N final | Add accepts | Dropped REQ | Phase-order error | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.N_active_initial(idx), ...
        rows.N_active_final(idx), rows.phase_add_accept_count(idx), ...
        rows.dropped_REQ_count(idx), rows.phase_order_error_rate(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n## Generated Wave Samples\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `experiments/E040_active_phase_add_shed/%s_wave_sample.csv`\n", ...
        rows.variant(idx), filePrefixForVariant(rows.variant(idx)));
end
fprintf(fid, "\n## Lambda Boundary\n\n");
fprintf(fid, "Active Lambda control is disabled. `Lambda_trim_usage` must remain zero; any Lambda signal is audit-only.\n\n");
fprintf(fid, "## Classification\n\n`%s`\n", classification);
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | N init | N final | Add accepts | Overshoot mV | Undershoot mV | Final err mV | Real imb A | Phase err | Dropped REQ | Current limit | Ton usage | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %d | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.N_active_initial(idx), ...
        rows.N_active_final(idx), rows.phase_add_accept_count(idx), ...
        rows.peak_overshoot_mV(idx), rows.peak_undershoot_mV(idx), ...
        rows.final_Vout_error_mV(idx), rows.real_max_current_imbalance_A(idx), ...
        rows.phase_order_error_rate(idx), rows.dropped_REQ_count(idx), ...
        rows.current_limit_hit(idx), rows.Ton_trim_usage(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function writeInterpretation(fid, rows)
if any(~rows.success)
    fprintf(fid, "The run is not fully interpretable because at least one row failed.\n\n");
    return;
end
d0 = rows(rows.variant == "D0", :);
if ~isempty(d0)
    fprintf(fid, "D0 is the fixed two-phase reference with final `N_active = %.6g`.\n\n", d0.N_active_final(1));
end
for idx = 1:height(rows)
    if rows.variant(idx) == "D0"
        continue;
    end
    fprintf(fid, "- `%s`: final `N_active = %.6g`, add accepts = %.6g, dropped REQ = %.6g, phase-order error = %.6g, hint = `%s`.\n", ...
        rows.variant(idx), rows.N_active_final(idx), rows.phase_add_accept_count(idx), ...
        rows.dropped_REQ_count(idx), rows.phase_order_error_rate(idx), ...
        rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function prefix = filePrefixForVariant(variant)
variant = string(variant);
if variant == "D0"
    prefix = "e040_d0_fixed_two_phase";
elseif variant == "D1"
    prefix = "e040_d1_immediate_add";
elseif variant == "D2"
    prefix = "e040_d2_guarded_add_as";
elseif variant == "D3"
    prefix = "e040_d3_guarded_add_confidence";
else
    prefix = "e040_unknown";
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
