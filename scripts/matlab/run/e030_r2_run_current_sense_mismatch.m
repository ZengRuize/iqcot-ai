function rows = e030_r2_run_current_sense_mismatch(variants)
%E030_R2_RUN_CURRENT_SENSE_MISMATCH Run E030-R2 current-sense mismatch confirmation.

if nargin < 1
    variants = ["R2-C0", "R2-C1", "R2-C4a", "R2-C4c"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E030_balance_recovery", "R2_current_sense_mismatch");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e030_r2_metrics.csv");
summaryPath = fullfile(experimentRoot, "e030_r2_research_summary.md");
auditPath = fullfile(experimentRoot, "e030_r2_waveform_audit.md");

rows = table();
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    modelFile = "";
    try
        modelFile = e030_r2_build_current_sense_mismatch_model(spec.short_variant);
        [~, modelName] = fileparts(modelFile);
        load_system(modelFile);
        cleanup = onCleanup(@() close_system(modelName, 0)); %#ok<NASGU>

        out = runCase(modelName, spec);
        logs = out.logsout;
        metrics = collectMetrics(logs, spec);
        row = rowFromMetrics(spec, metrics, true, "", modelFile);
        triggerCsv = fullfile(experimentRoot, spec.file_prefix + "_phase_triggers.csv");
        exportPhaseTriggers(logs, spec, triggerCsv);
        writeVariantReport(fullfile(experimentRoot, spec.file_prefix + "_report.md"), ...
            modelFile, spec, row, triggerCsv);
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
[classification, detail, bestVariant] = classifyRows(rows);
writeSummary(summaryPath, rows, classification, detail, bestVariant, metricsCsv);
writeWaveformAudit(auditPath, rows);

fprintf("E030_R2_METRICS=%s\n", metricsCsv);
fprintf("E030_R2_SUMMARY=%s\n", summaryPath);
fprintf("E030_R2_WAVEFORM_AUDIT=%s\n", auditPath);
disp(rows);
end

function spec = variantSpec(variant)
variant = string(variant);
spec = struct();
spec.short_variant = variant;
spec.load_A = 40;
spec.t_load_step = 0.0;
spec.stop_time = 0.64e-3;
spec.eval_start = 0.45e-3;
spec.eval_end = 0.62e-3;
spec.final_window_start = 0.60e-3;
spec.final_window_end = 0.62e-3;
spec.max_step = "5e-9";
spec.vref = 1.0;
spec.dcr_nominal = 0.01;
spec.dcr_pattern = [1.00, 1.00, 1.00, 1.00] * spec.dcr_nominal;
spec.sense_gain_pattern = [1.05, 0.95, 1.05, 0.95];
spec.K_T = 0.0;
spec.T_trim_max = 25e-9;
spec.current_deadband_A = 0.15;
spec.projection_mode = 0.0;
spec.v_error_budget = 15e-3;
spec.v_error_hard_limit = 60e-3;
spec.min_scale = 0.25;
spec.ripple_budget = 8e-3;
spec.ripple_hard_limit = 18e-3;
spec.ripple_window = 20e-6;
spec.current_imbalance_budget_A = 0.5;
spec.phase_spacing_budget_ns = 120;
spec.ripple_budget_mV = 18;
spec.frequency_budget_low_Hz = 0.25e6;
spec.frequency_budget_high_Hz = 2.5e6;
spec.ton_enable = 0;

if variant == "R2-C0"
    spec.variant = "R2_C0_iqcot_current_sense_mismatch";
    spec.file_prefix = "e030_r2_c0_current_sense_mismatch";
    spec.report_title = "E030-R2 C0 Current-Sense Mismatch Baseline";
elseif variant == "R2-C1"
    spec.variant = "R2_C1_ton_diff_reference";
    spec.file_prefix = "e030_r2_c1_ton_diff_reference";
    spec.report_title = "E030-R2 C1 Ton-Diff Reference";
    spec.ton_enable = 1;
    spec.K_T = 5e-9;
    spec.projection_mode = 0.0;
elseif variant == "R2-C4a"
    spec.variant = "R2_C4a_reduced_KT_projection";
    spec.file_prefix = "e030_r2_c4a_reduced_KT";
    spec.report_title = "E030-R2 C4a Reduced-KT Projection";
    spec.ton_enable = 1;
    spec.K_T = 2.2e-9;
    spec.projection_mode = 1.0;
elseif variant == "R2-C4c"
    spec.variant = "R2_C4c_voltage_error_aware_projection";
    spec.file_prefix = "e030_r2_c4c_voltage_aware";
    spec.report_title = "E030-R2 C4c Voltage-Aware Projection";
    spec.ton_enable = 1;
    spec.K_T = 5e-9;
    spec.T_trim_max = 25e-9;
    spec.projection_mode = 3.0;
else
    error("Unknown E030-R2 variant: %s", variant);
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
in = in.setVariable("Iload_initial", spec.load_A);
in = in.setVariable("Iload_final", spec.load_A);
in = in.setVariable("t_load_step", spec.t_load_step);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.load_A);
in = in.setVariable("Iph", spec.load_A / 4);
for phase = 1:4
    in = in.setVariable("DCR_L" + phase, spec.dcr_pattern(phase));
    in = in.setVariable("E030_R2_IL_Sense_Gain" + phase, spec.sense_gain_pattern(phase));
end
in = in.setVariable("E030_R2_TonDiff_Enable", spec.ton_enable);
in = in.setVariable("E030_R2_K_T", spec.K_T);
in = in.setVariable("E030_R2_T_Trim_Max", spec.T_trim_max);
in = in.setVariable("E030_R2_Current_Deadband", spec.current_deadband_A);
in = in.setVariable("E030_R2_Projection_Mode", spec.projection_mode);
in = in.setVariable("E030_R2_Vref", spec.vref);
in = in.setVariable("E030_R2_V_Error_Budget", spec.v_error_budget);
in = in.setVariable("E030_R2_V_Error_Hard_Limit", spec.v_error_hard_limit);
in = in.setVariable("E030_R2_Min_Scale", spec.min_scale);
in = in.setVariable("E030_R2_Ripple_Budget", spec.ripple_budget);
in = in.setVariable("E030_R2_Ripple_Hard_Limit", spec.ripple_hard_limit);
in = in.setVariable("E030_R2_Ripple_Window", spec.ripple_window);
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
metrics = struct();
[tV, vout] = signalSeries(logs, "Vout");
evalMaskV = tV >= spec.eval_start & tV <= spec.eval_end;
finalMaskV = tV >= spec.final_window_start & tV <= spec.final_window_end;
if any(evalMaskV)
    metrics.Vout_ripple_pp_mV = 1e3 * (max(vout(evalMaskV)) - min(vout(evalMaskV)));
else
    metrics.Vout_ripple_pp_mV = NaN;
end
if any(finalMaskV)
    metrics.final_Vout_error_mV = 1e3 * mean(vout(finalMaskV) - spec.vref);
else
    metrics.final_Vout_error_mV = NaN;
end

realMetrics = currentMetrics(logs, "IL", spec.eval_start, spec.eval_end);
sensedMetrics = currentMetrics(logs, "IL_sense", spec.eval_start, spec.eval_end);
metrics.real_IL_mean = realMetrics.mean;
metrics.sensed_IL_mean = sensedMetrics.mean;
metrics.max_real_current_imbalance_A = realMetrics.max_imbalance;
metrics.rms_real_current_imbalance_A = realMetrics.rms_imbalance;
metrics.max_sensed_current_imbalance_A = sensedMetrics.max_imbalance;
metrics.rms_sensed_current_imbalance_A = sensedMetrics.rms_imbalance;

[eventTimes, eventPhases] = phaseEvents(logs, spec.eval_start, spec.eval_end);
metrics.phase_spacing_std_ns = phaseSpacingStdNs(eventTimes);
metrics.phase_order_error_rate = phaseOrderErrorRate(eventPhases);
metrics.effective_switching_frequency_Hz = effectiveFrequency(logs, spec.eval_start, spec.eval_end);
metrics.Ton_trim_usage = trimUsage(logs, "Ton_trim", spec.T_trim_max, spec.eval_start, spec.eval_end);
metrics.Lambda_trim_usage = trimUsage(logs, "Lambda_trim", 1.0, spec.eval_start, spec.eval_end);
metrics.guard_clamp_count = sumOptionalSignal(logs, "ton_trim_clamp_count", spec.eval_start, spec.eval_end);
metrics.fallback_count = sumOptionalSignal(logs, "ton_fallback_count", spec.eval_start, spec.eval_end);
metrics.REQ_count = reqCount(logs, spec.eval_start, spec.eval_end);
metrics.phase_event_count = numel(eventTimes);
metrics.projection_scale_min = optionalMinSignal(logs, "ton_projection_scale", spec.eval_start, spec.eval_end);
end

function out = currentMetrics(logs, prefix, startTime, endTime)
means = zeros(1, 4);
for phase = 1:4
    [t, il] = signalSeries(logs, prefix + phase);
    mask = t >= startTime & t <= endTime;
    if any(mask)
        means(phase) = mean(il(mask));
    else
        means(phase) = NaN;
    end
end
err = means - mean(means, "omitnan");
out = struct();
out.mean = means;
out.max_imbalance = max(abs(err));
out.rms_imbalance = sqrt(mean(err.^2, "omitnan"));
end

function valueUs = settlingTimeUs(t, y, startTime, band)
valueUs = NaN;
if isempty(t)
    return;
end
for idx = 1:numel(t)
    if t(idx) >= startTime && all(y(idx:end) <= band)
        valueUs = 1e6 * (t(idx) - startTime);
        return;
    end
end
end

function [eventTimes, eventPhases] = phaseEvents(logs, startTime, endTime)
eventTimes = [];
eventPhases = [];
for phase = 1:4
    [t, values] = signalSeries(logs, "QH" + phase);
    edges = t(find(diff(values > 0.5) > 0) + 1);
    edges = edges(edges >= startTime & edges <= endTime);
    eventTimes = [eventTimes; edges(:)]; %#ok<AGROW>
    eventPhases = [eventPhases; phase * ones(numel(edges), 1)]; %#ok<AGROW>
end
[eventTimes, order] = sort(eventTimes);
eventPhases = eventPhases(order);
end

function total = reqCount(logs, startTime, endTime)
total = 0;
for phase = 1:4
    [t, values] = signalSeries(logs, "REQ" + phase);
    edges = t(find(diff(values > 0.5) > 0) + 1);
    total = total + sum(edges >= startTime & edges <= endTime);
end
end

function stdNs = phaseSpacingStdNs(eventTimes)
if numel(eventTimes) < 3
    stdNs = NaN;
else
    stdNs = 1e9 * std(diff(eventTimes));
end
end

function rate = phaseOrderErrorRate(eventPhases)
if numel(eventPhases) < 2
    rate = NaN;
    return;
end
errors = 0;
for idx = 2:numel(eventPhases)
    expected = eventPhases(idx - 1) + 1;
    if expected > 4
        expected = 1;
    end
    if eventPhases(idx) ~= expected
        errors = errors + 1;
    end
end
rate = errors / (numel(eventPhases) - 1);
end

function freq = effectiveFrequency(logs, startTime, endTime)
count = 0;
for phase = 1:4
    [t, values] = signalSeries(logs, "QH" + phase);
    edges = t(find(diff(values > 0.5) > 0) + 1);
    count = count + sum(edges >= startTime & edges <= endTime);
end
duration = endTime - startTime;
if duration <= 0
    freq = NaN;
else
    freq = count / duration / 4;
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

function value = optionalMinSignal(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    value = NaN;
    return;
end
t = sig.Values.Time(:);
values = squeeze(double(sig.Values.Data));
values = values(:);
mask = t >= startTime & t <= endTime;
if any(mask)
    value = min(values(mask));
else
    value = NaN;
end
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = table( ...
    string(spec.short_variant), success, string(errorMessage), string(spec.variant), string(modelFile), ...
    spec.K_T, spec.T_trim_max, spec.projection_mode, ...
    spec.sense_gain_pattern(1), spec.sense_gain_pattern(2), spec.sense_gain_pattern(3), spec.sense_gain_pattern(4), ...
    m.max_real_current_imbalance_A, m.rms_real_current_imbalance_A, ...
    m.max_sensed_current_imbalance_A, m.rms_sensed_current_imbalance_A, ...
    m.real_IL_mean(1), m.real_IL_mean(2), m.real_IL_mean(3), m.real_IL_mean(4), ...
    m.sensed_IL_mean(1), m.sensed_IL_mean(2), m.sensed_IL_mean(3), m.sensed_IL_mean(4), ...
    m.Vout_ripple_pp_mV, m.final_Vout_error_mV, m.effective_switching_frequency_Hz, ...
    m.phase_spacing_std_ns, m.phase_order_error_rate, m.Ton_trim_usage, m.Lambda_trim_usage, ...
    m.guard_clamp_count, m.fallback_count, m.REQ_count, NaN, ...
    NaN, NaN, NaN, string("pending"), m.phase_event_count, m.projection_scale_min, ...
    'VariableNames', {'variant','success','error_message','variant_description','model_file', ...
    'K_T','T_trim_max','projection_mode', ...
    'sense_gain1','sense_gain2','sense_gain3','sense_gain4', ...
    'max_real_current_imbalance_A','rms_real_current_imbalance_A', ...
    'max_sensed_current_imbalance_A','rms_sensed_current_imbalance_A', ...
    'mean_real_IL1_A','mean_real_IL2_A','mean_real_IL3_A','mean_real_IL4_A', ...
    'mean_sensed_IL1_A','mean_sensed_IL2_A','mean_sensed_IL3_A','mean_sensed_IL4_A', ...
    'Vout_ripple_pp_mV','final_Vout_error_mV','effective_switching_frequency_Hz', ...
    'phase_spacing_std_ns','phase_order_error_rate','Ton_trim_usage','Lambda_trim_usage', ...
    'guard_clamp_count','fallback_count','REQ_count','dropped_REQ_count', ...
    'score','score_real','score_sensed','classification_hint','phase_event_count','projection_scale_min'});
end

function row = failureRow(spec, errorMessage, modelFile)
emptyMetrics = struct( ...
    "max_real_current_imbalance_A", NaN, ...
    "rms_real_current_imbalance_A", NaN, ...
    "max_sensed_current_imbalance_A", NaN, ...
    "rms_sensed_current_imbalance_A", NaN, ...
    "real_IL_mean", NaN(1,4), ...
    "sensed_IL_mean", NaN(1,4), ...
    "phase_spacing_std_ns", NaN, ...
    "phase_order_error_rate", NaN, ...
    "Vout_ripple_pp_mV", NaN, ...
    "effective_switching_frequency_Hz", NaN, ...
    "Ton_trim_usage", NaN, ...
    "Lambda_trim_usage", NaN, ...
    "final_Vout_error_mV", NaN, ...
    "guard_clamp_count", NaN, ...
    "fallback_count", NaN, ...
    "REQ_count", NaN, ...
    "phase_event_count", NaN, ...
    "projection_scale_min", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage, modelFile);
end

function rows = finalizeRows(rows)
if isempty(rows)
    return;
end
c0 = rows(rows.variant == "R2-C0" & rows.success, :);
c1 = rows(rows.variant == "R2-C1" & rows.success, :);
if isempty(c0)
    baselineReq = NaN;
    baselineRealImbalance = 1.0;
    baselineSensedImbalance = 1.0;
else
    baselineReq = c0.REQ_count(1);
    baselineRealImbalance = max(c0.max_real_current_imbalance_A(1), 1.0e-9);
    baselineSensedImbalance = max(c0.max_sensed_current_imbalance_A(1), 1.0e-9);
end
if isempty(c1)
    c1FinalAbs = 60;
    c1TonUsage = 1;
else
    c1FinalAbs = max(abs(c1.final_Vout_error_mV(1)), 1.0);
    c1TonUsage = c1.Ton_trim_usage(1);
end
for idx = 1:height(rows)
    if rows.success(idx)
        rows.dropped_REQ_count(idx) = max(0, baselineReq - rows.REQ_count(idx));
        normRealI = rows.max_real_current_imbalance_A(idx) / baselineRealImbalance;
        normSensedI = rows.max_sensed_current_imbalance_A(idx) / baselineSensedImbalance;
        normV = abs(rows.final_Vout_error_mV(idx)) / 60.0;
        normR = rows.Vout_ripple_pp_mV(idx) / 16.0;
        normT = rows.Ton_trim_usage(idx);
        normP = rows.phase_spacing_std_ns(idx) / 50.0;
        rows.score_real(idx) = 0.40 * normRealI + 0.20 * normV + ...
            0.15 * normR + 0.15 * normT + 0.10 * normP;
        rows.score_sensed(idx) = 0.40 * normSensedI + 0.20 * normV + ...
            0.15 * normR + 0.15 * normT + 0.10 * normP;
        rows.score(idx) = rows.score_real(idx);
        if rows.variant(idx) == "R2-C0"
            rows.classification_hint(idx) = "baseline";
        elseif rows.variant(idx) == "R2-C1"
            rows.classification_hint(idx) = "ton_diff_reference";
        elseif startsWith(rows.variant(idx), "R2-C4")
            improvesRealI = rows.max_real_current_imbalance_A(idx) < baselineRealImbalance;
            c1Now = rows(rows.variant == "R2-C1" & rows.success, :);
            if isempty(c1Now)
                c1RealScore = Inf;
            else
                c1RealScore = c1Now.score_real(1);
            end
            sensedRealDivergence = rows.max_sensed_current_imbalance_A(idx) < baselineSensedImbalance && ...
                rows.max_real_current_imbalance_A(idx) > baselineRealImbalance + 1.0e-3;
            lowerTrim = rows.Ton_trim_usage(idx) < c1TonUsage - 1.0e-3;
            lowerVerr = abs(rows.final_Vout_error_mV(idx)) < c1FinalAbs - 0.1;
            rhythmOk = rows.phase_order_error_rate(idx) == 0 && rows.dropped_REQ_count(idx) == 0;
            rippleOk = rows.Vout_ripple_pp_mV(idx) <= 18.0;
            if sensedRealDivergence
                rows.classification_hint(idx) = "sensed_real_divergence";
            elseif improvesRealI && lowerTrim && lowerVerr && rhythmOk && rippleOk && ...
                    rows.score_real(idx) < c1RealScore
                rows.classification_hint(idx) = "real_pareto_candidate";
            else
                rows.classification_hint(idx) = "tradeoff_or_guard_issue";
            end
        end
    else
        rows.classification_hint(idx) = "implementation_issue";
    end
end
end

function [classification, detail, bestVariant] = classifyRows(rows)
bestVariant = "";
if any(~rows.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E030-R2 variant failed before reliable metrics were produced.";
    return;
end
needed = ["R2-C0", "R2-C1", "R2-C4a", "R2-C4c"];
for idx = 1:numel(needed)
    if ~any(rows.variant == needed(idx))
        classification = "IMPLEMENTATION_ISSUE";
        detail = "Missing required E030-R2 variant " + needed(idx) + ".";
        return;
    end
end
c0 = rows(rows.variant == "R2-C0", :);
c1 = rows(rows.variant == "R2-C1", :);
c4 = rows(startsWith(rows.variant, "R2-C4"), :);
if any(c4.classification_hint == "sensed_real_divergence")
    classification = "MODEL_REVISED";
    detail = "At least one projected variant improves the controller-observed score without a matching real-current Pareto advantage; add a sensing-confidence or calibration-aware guard before E040.";
    return;
end
eligible = c4(c4.classification_hint == "real_pareto_candidate", :);
if ~isempty(eligible)
    [~, bestIdx] = min(eligible.score_real);
    best = eligible(bestIdx, :);
    bestVariant = best.variant(1);
    if best.score_real(1) < c1.score_real(1)
        classification = "MODEL_CONFIRMED";
        detail = "A projected a_S variant shows a local real-current Pareto advantage under current-sense gain mismatch, with lower real score than the Ton_diff reference and no REQ or phase-order loss.";
    else
        classification = "MODEL_REVISED";
        detail = "A projected variant satisfies guard checks but its real-current score does not clearly beat C1; the result remains a projection trade-off.";
    end
elseif any(c4.max_real_current_imbalance_A < c0.max_real_current_imbalance_A)
    classification = "MODEL_REVISED";
    detail = "Projected variants improve real current sharing versus C0 but do not satisfy all Pareto guard checks against C1, or require sensing-confidence guard logic.";
else
    classification = "CLAIM_DOWNGRADED";
    detail = "Projected variants do not improve real current sharing versus the current-sense-mismatch baseline.";
end
end

function exportPhaseTriggers(logs, spec, csvPath)
[times, phases] = phaseEvents(logs, spec.eval_start, spec.eval_end);
maxRows = min(numel(times), 2000);
times = times(1:maxRows);
phases = phases(1:maxRows);
out = table(1e6 * (times - spec.eval_start), phases, ...
    'VariableNames', {'time_after_eval_start_us', 'phase'});
if isempty(out)
    out = table([], [], 'VariableNames', {'time_after_eval_start_us', 'phase'});
end
writetable(out, csvPath);
end

function writeVariantReport(reportPath, modelFile, spec, row, triggerCsv)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "This run tests fixed-four-phase `a_S` projection under current-sense gain mismatch at fixed external `40A`. The power-stage DCR is nominal. The controller sees biased `IL_sense_i`, while metrics also report real `IL_i`. No neural AI and no direct gate command are used.\n\n");
fprintf(fid, "## Model Copy Path\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Controller Variant\n\n`%s`\n\n", spec.variant);
fprintf(fid, "## Projection Parameters\n\n");
fprintf(fid, "- `K_T = %.6g`\n", spec.K_T);
fprintf(fid, "- `T_trim_max = %.6g ns`\n", 1e9 * spec.T_trim_max);
fprintf(fid, "- `projection_mode = %.6g`\n", spec.projection_mode);
fprintf(fid, "- `sense_gain_pattern = [%.3g %.3g %.3g %.3g]`\n", spec.sense_gain_pattern);
fprintf(fid, "- `V_error_budget = %.6g mV`\n", 1e3 * spec.v_error_budget);
fprintf(fid, "- `ripple_budget = %.6g mV`\n\n", 1e3 * spec.ripple_budget);
fprintf(fid, "## Metrics\n\n");
writeMetricsMarkdownTable(fid, row);
fprintf(fid, "Phase trigger CSV: `%s`\n\n", slashPath(triggerCsv));
fprintf(fid, "## Per-Run Classification Hint\n\n`%s`\n", row.classification_hint(1));
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "The derived model or run failed before interpretable E030-R2 metrics were produced.\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Baseline path: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n");
fprintf(fid, "- Variant: `%s`\n", spec.variant);
fprintf(fid, "- Error: `%s`\n", message);
end

function writeSummary(summaryPath, rows, classification, detail, bestVariant, metricsCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E030-R2 Current-Sense Mismatch Research Summary\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "R2 tests whether the R1-C4a/R1-C4c `a_S` projection trade-off remains meaningful when the controller sees biased phase-current measurements. Real `IL_i` and sensed `IL_sense_i` are reported separately.\n\n");
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Model Copy Paths\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.variant(idx), slashPath(rows.model_file(idx)));
end
fprintf(fid, "\n## External Load And Mismatch\n\n");
fprintf(fid, "Fixed external `40A` current sink; nominal power-stage DCR; current-sense gain pattern `[+5%% -5%% +5%% -5%%]`. Load current and sensing mismatch are validation inputs, not AI actions.\n\n");
fprintf(fid, "## Controller Variants Compared\n\n`R2-C0`, `R2-C1`, `R2-C4a`, `R2-C4c`.\n\n");
fprintf(fid, "## Scores\n\n");
fprintf(fid, "Lower is better. Both scores use weights `wI=0.40`, `wV=0.20`, `wR=0.15`, `wT=0.15`, `wP=0.10`.\n\n");
fprintf(fid, "```text\n");
fprintf(fid, "score_real = 0.40 * real_current_imbalance / C0_real_current_imbalance\n");
fprintf(fid, "      + 0.20 * abs(final_Vout_error_mV) / 60\n");
fprintf(fid, "      + 0.15 * Vout_ripple_pp_mV / 16\n");
fprintf(fid, "      + 0.15 * Ton_trim_usage\n");
fprintf(fid, "      + 0.10 * phase_spacing_std_ns / 50\n\n");
fprintf(fid, "score_sensed uses sensed_current_imbalance in the first term.\n");
fprintf(fid, "```\n\n");
fprintf(fid, "## Metrics Table\n\nMetrics CSV: `%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Best Retuned Candidate\n\n");
if strlength(bestVariant) > 0
    fprintf(fid, "`%s`\n\n", bestVariant);
else
    fprintf(fid, "No C4 retuned variant satisfied all Pareto guard checks.\n\n");
end
fprintf(fid, "## Interpretation\n\n");
writeInterpretation(fid, rows);
fprintf(fid, "## Failure Or Trade-Off Analysis\n\n%s\n\n", detail);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "## Claim Boundary\n\n");
fprintf(fid, "This is derived-Simulink evidence only. It does not prove hardware, HIL, board-level, silicon, broad mismatch robustness, active Lambda control, or active-phase add/shed behavior.\n\n");
fprintf(fid, "## Next Smallest Useful Experiment\n\n");
if classification == "IMPLEMENTATION_ISSUE"
    fprintf(fid, "Fix R2 current-sense injection/logging/postprocess and rerun the minimal confirmation chunk.\n");
elseif classification == "MODEL_REVISED"
    fprintf(fid, "Add or refine a current-sense-confidence / calibration-aware guard before E040.\n");
elseif classification == "MODEL_CONFIRMED"
    fprintf(fid, "Freeze the local `a_S` selector with C4a as conservative voltage-safe mode and C4c as stronger sharing mode; keep Lambda active-control claims disabled.\n");
else
    fprintf(fid, "Downgrade projected-balancer claims and keep PIS-IEK primarily as actuator-classification theory.\n");
end
end

function writeWaveformAudit(auditPath, rows)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E030-R2 Waveform Audit\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Audit for R2 current-sense mismatch: fixed `40A`, nominal DCR, current-sense gains `[1.05 0.95 1.05 0.95]`, variants R2-C0/R2-C1/R2-C4a/R2-C4c.\n\n");
fprintf(fid, "## Required Signals\n\n");
fprintf(fid, "- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`\n");
fprintf(fid, "- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`\n");
fprintf(fid, "- `IL_sense1..IL_sense4` for controller-observed current imbalance\n");
fprintf(fid, "- `Ton_trim1..4`, `ton_projection_scale` where applicable\n");
fprintf(fid, "- `active_phase_set`, `guard_clamp_count`, `fallback_count`\n\n");
fprintf(fid, "## REQ Count Audit\n\n");
fprintf(fid, "| Variant | REQ count | Dropped REQ vs C0 | Phase order error |\n");
fprintf(fid, "|---|---:|---:|---:|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %.6g | %.6g | %.6g |\n", rows.variant(idx), ...
        rows.REQ_count(idx), rows.dropped_REQ_count(idx), rows.phase_order_error_rate(idx));
end
fprintf(fid, "\n## Generated Phase Trigger Tables\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `experiments/E030_balance_recovery/R2_current_sense_mismatch/%s_phase_triggers.csv`\n", ...
        rows.variant(idx), filePrefixForVariant(rows.variant(idx)));
end
fprintf(fid, "\n## Lambda Boundary\n\n");
fprintf(fid, "R2 does not implement active Lambda actuation. No active Lambda claim is allowed from this run.\n");
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | Real max imb A | Sensed max imb A | Ripple mV | Final Vout err mV | Ton usage | REQ count | Dropped REQ | Phase std ns | Order err | Score real | Score sensed | Hint |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %s |\n", ...
        rows.variant(idx), rows.success(idx), rows.max_real_current_imbalance_A(idx), ...
        rows.max_sensed_current_imbalance_A(idx), rows.Vout_ripple_pp_mV(idx), ...
        rows.final_Vout_error_mV(idx), rows.Ton_trim_usage(idx), ...
        rows.REQ_count(idx), rows.dropped_REQ_count(idx), rows.phase_spacing_std_ns(idx), ...
        rows.phase_order_error_rate(idx), rows.score_real(idx), rows.score_sensed(idx), rows.classification_hint(idx));
end
fprintf(fid, "\n");
end

function writeInterpretation(fid, rows)
if any(~rows.success)
    fprintf(fid, "At least one row failed; do not interpret partial R2 metrics as controller evidence.\n\n");
    return;
end
c0 = rows(rows.variant == "R2-C0", :);
c1 = rows(rows.variant == "R2-C1", :);
if isempty(c0) || isempty(c1)
    fprintf(fid, "Partial E030-R2 execution: R2-C0 present = `%d`, R2-C1 present = `%d`. Full C1-relative real/sensed interpretation is deferred until the required variant set completes.\n\n", ...
        ~isempty(c0), ~isempty(c1));
    return;
end
fprintf(fid, "R2-C0 real max imbalance is `%.6g A` and sensed max imbalance is `%.6g A`. R2-C1 Ton_diff reference gives real max imbalance `%.6g A`, sensed max imbalance `%.6g A`, Ton usage `%.6g`, and final Vout error `%.6g mV`.\n\n", ...
    c0.max_real_current_imbalance_A(1), c0.max_sensed_current_imbalance_A(1), ...
    c1.max_real_current_imbalance_A(1), c1.max_sensed_current_imbalance_A(1), ...
    c1.Ton_trim_usage(1), c1.final_Vout_error_mV(1));
fprintf(fid, "| Variant | Real imb reduction vs C0 A | Sensed imb reduction vs C0 A | Real score delta vs C1 | Sensed score delta vs C1 | Ton usage delta vs C1 | Final-error magnitude delta vs C1 mV |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|\n");
for idx = 1:height(rows)
    if rows.variant(idx) == "R2-C0" || rows.variant(idx) == "R2-C1"
        continue;
    end
    fprintf(fid, "| %s | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n", rows.variant(idx), ...
        c0.max_real_current_imbalance_A(1) - rows.max_real_current_imbalance_A(idx), ...
        c0.max_sensed_current_imbalance_A(1) - rows.max_sensed_current_imbalance_A(idx), ...
        rows.score_real(idx) - c1.score_real(1), ...
        rows.score_sensed(idx) - c1.score_sensed(1), ...
        rows.Ton_trim_usage(idx) - c1.Ton_trim_usage(1), ...
        abs(rows.final_Vout_error_mV(idx)) - abs(c1.final_Vout_error_mV(1)));
end
fprintf(fid, "\n");
end

function prefix = filePrefixForVariant(variant)
variant = string(variant);
if variant == "R2-C0"
    prefix = "e030_r2_c0_current_sense_mismatch";
elseif variant == "R2-C1"
    prefix = "e030_r2_c1_ton_diff_reference";
elseif variant == "R2-C4a"
    prefix = "e030_r2_c4a_reduced_KT";
elseif variant == "R2-C4c"
    prefix = "e030_r2_c4c_voltage_aware";
else
    prefix = "e030_r2_unknown";
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
