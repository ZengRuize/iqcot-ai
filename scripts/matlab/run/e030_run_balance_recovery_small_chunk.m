function rows = e030_run_balance_recovery_small_chunk(variants)
%E030_RUN_BALANCE_RECOVERY_SMALL_CHUNK Run C0-C4 DCR mismatch E030 chunk.

if nargin < 1
    variants = ["C0", "C1", "C2", "C3", "C4"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E030_balance_recovery");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e030_metrics.csv");
summaryPath = fullfile(experimentRoot, "e030_research_summary.md");
auditPath = fullfile(experimentRoot, "e030_waveform_audit.md");

rows = table();
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    modelFile = "";
    try
        modelFile = e030_build_balance_recovery_model(spec.short_variant);
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

writetable(rows, metricsCsv);
[classification, classificationDetail] = classifyRows(rows);
writeSummary(summaryPath, rows, classification, classificationDetail, metricsCsv);
writeWaveformAudit(auditPath, rows);

fprintf("E030_METRICS=%s\n", metricsCsv);
fprintf("E030_SUMMARY=%s\n", summaryPath);
fprintf("E030_WAVEFORM_AUDIT=%s\n", auditPath);
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
spec.dcr_pattern = [1.10, 0.90, 1.10, 0.90] * spec.dcr_nominal;
spec.K_T = 5e-9;
spec.K_T_projected = 3e-9;
spec.T_trim_max = 25e-9;
spec.current_deadband_A = 0.15;
spec.lambda_trim_max = 6e-11;
spec.K_Lambda = 1.2e-3;
spec.nominal_phase_spacing = 480e-9;
spec.phase_spacing_tolerance = 80e-9;
spec.current_imbalance_budget_A = 0.5;
spec.phase_spacing_budget_ns = 120;
spec.ripple_budget_mV = 5;
spec.frequency_budget_low_Hz = 0.25e6;
spec.frequency_budget_high_Hz = 2.5e6;
spec.ton_enable = 0;
spec.lambda_enable = 0;
spec.projected_enable = 0;
spec.K_T_effective = spec.K_T;

if variant == "C0"
    spec.variant = "C0_original_iqcot_dcr_mismatch";
    spec.file_prefix = "e030_c0_dcr_mismatch";
    spec.report_title = "E030 C0 DCR-Mismatch Baseline";
elseif variant == "C1"
    spec.variant = "C1_ton_diff_only";
    spec.file_prefix = "e030_c1_ton_diff";
    spec.report_title = "E030 C1 Ton-Diff Only";
    spec.ton_enable = 1;
elseif variant == "C2"
    spec.variant = "C2_lambda_diff_only";
    spec.file_prefix = "e030_c2_lambda_diff";
    spec.report_title = "E030 C2 Lambda-Diff Only";
    spec.lambda_enable = 1;
elseif variant == "C3"
    spec.variant = "C3_ton_diff_lambda_diff";
    spec.file_prefix = "e030_c3_ton_lambda_diff";
    spec.report_title = "E030 C3 Ton-Diff Plus Lambda-Diff";
    spec.ton_enable = 1;
    spec.lambda_enable = 1;
elseif variant == "C4"
    spec.variant = "C4_pis_iek_projected_balancer";
    spec.file_prefix = "e030_c4_pis_iek_projected";
    spec.report_title = "E030 C4 PIS-IEK Projected Balancer";
    spec.ton_enable = 1;
    spec.lambda_enable = 1;
    spec.projected_enable = 1;
    spec.K_T_effective = spec.K_T_projected;
else
    error("Unknown E030 variant: %s", variant);
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
end
in = in.setVariable("E030_TonDiff_Enable", spec.ton_enable);
in = in.setVariable("E030_K_T", spec.K_T_effective);
in = in.setVariable("E030_T_Trim_Max", spec.T_trim_max);
in = in.setVariable("E030_Current_Deadband", spec.current_deadband_A);
in = in.setVariable("E030_LambdaDiff_Enable", spec.lambda_enable);
in = in.setVariable("E030_Nominal_Phase_Spacing", spec.nominal_phase_spacing);
in = in.setVariable("E030_Phase_Spacing_Tolerance", spec.phase_spacing_tolerance);
in = in.setVariable("E030_Lambda_Trim_Max", spec.lambda_trim_max);
in = in.setVariable("E030_K_Lambda", spec.K_Lambda);
in = in.setVariable("E030_PIS_Project_Enable", spec.projected_enable);
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
metrics = struct();
[tV, vout] = signalSeries(logs, "Vout");
evalMaskV = tV >= spec.eval_start & tV <= spec.eval_end;
finalMaskV = tV >= spec.final_window_start & tV <= spec.final_window_end;
if any(evalMaskV)
    metrics.output_ripple_mV = 1e3 * (max(vout(evalMaskV)) - min(vout(evalMaskV)));
else
    metrics.output_ripple_mV = NaN;
end
if any(finalMaskV)
    metrics.final_vout_error_mV = 1e3 * mean(vout(finalMaskV) - spec.vref);
else
    metrics.final_vout_error_mV = NaN;
end

ilMean = zeros(1, 4);
ilRms = zeros(1, 4);
timeGrid = [];
currents = cell(1, 4);
for phase = 1:4
    [t, il] = signalSeries(logs, "IL" + phase);
    mask = t >= spec.eval_start & t <= spec.eval_end;
    ilMean(phase) = mean(il(mask));
    ilRms(phase) = rms(il(mask));
    timeGrid = [timeGrid; t(mask)]; %#ok<AGROW>
    currents{phase} = {t, il};
end
metrics.IL_mean = ilMean;
metrics.IL_rms = ilRms;
avgMean = mean(ilMean);
meanErr = ilMean - avgMean;
metrics.max_current_imbalance_A = max(abs(meanErr));
metrics.rms_current_imbalance_A = sqrt(mean(meanErr.^2));

timeGrid = unique(timeGrid);
maxRows = 50000;
if numel(timeGrid) > maxRows
    pick = unique(round(linspace(1, numel(timeGrid), maxRows)));
    timeGrid = timeGrid(pick);
end
instImbalance = zeros(size(timeGrid));
for idx = 1:numel(timeGrid)
    vals = zeros(1, 4);
    for phase = 1:4
        tp = currents{phase}{1};
        il = currents{phase}{2};
        vals(phase) = interp1(tp, il, timeGrid(idx), "linear", "extrap");
    end
    instImbalance(idx) = max(abs(vals - mean(vals)));
end
metrics.current_imbalance_settling_us = settlingTimeUs(timeGrid, instImbalance, ...
    spec.eval_start, spec.current_imbalance_budget_A);

[eventTimes, eventPhases] = phaseEvents(logs, spec.eval_start, spec.eval_end);
metrics.phase_spacing_std_ns = phaseSpacingStdNs(eventTimes);
metrics.phase_order_error_rate = phaseOrderErrorRate(eventPhases);
metrics.effective_switching_frequency_Hz = effectiveFrequency(logs, spec.eval_start, spec.eval_end);
metrics.ton_trim_usage = trimUsage(logs, "Ton_trim", spec.T_trim_max, spec.eval_start, spec.eval_end);
metrics.lambda_trim_usage = trimUsage(logs, "Lambda_trim", spec.lambda_trim_max, spec.eval_start, spec.eval_end);
metrics.guard_clamp_count = sumOptionalSignal(logs, "ton_trim_clamp_count", spec.eval_start, spec.eval_end) + ...
    sumOptionalSignal(logs, "lambda_trim_clamp_count", spec.eval_start, spec.eval_end);
metrics.fallback_count = sumOptionalSignal(logs, "ton_fallback_count", spec.eval_start, spec.eval_end) + ...
    sumOptionalSignal(logs, "lambda_fallback_count", spec.eval_start, spec.eval_end);
metrics.event_count = numel(eventTimes);
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

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = table( ...
    success, string(errorMessage), string(spec.short_variant), string(spec.variant), string(modelFile), ...
    spec.load_A, spec.dcr_pattern(1), spec.dcr_pattern(2), spec.dcr_pattern(3), spec.dcr_pattern(4), ...
    m.max_current_imbalance_A, m.rms_current_imbalance_A, m.phase_spacing_std_ns, ...
    m.output_ripple_mV, m.effective_switching_frequency_Hz, m.ton_trim_usage, ...
    m.lambda_trim_usage, m.current_imbalance_settling_us, m.final_vout_error_mV, ...
    m.guard_clamp_count, m.fallback_count, ...
    m.IL_mean(1), m.IL_mean(2), m.IL_mean(3), m.IL_mean(4), ...
    m.IL_rms(1), m.IL_rms(2), m.IL_rms(3), m.IL_rms(4), ...
    m.phase_order_error_rate, m.event_count, ...
    'VariableNames', {'success','error_message','short_variant','variant','model_file', ...
    'load_A','DCR_L1','DCR_L2','DCR_L3','DCR_L4', ...
    'max_current_imbalance_A','rms_current_imbalance_A','phase_spacing_std_ns', ...
    'output_ripple_mV','effective_switching_frequency_Hz','ton_trim_usage', ...
    'lambda_trim_usage','current_imbalance_settling_us','final_vout_error_mV', ...
    'guard_clamp_count','fallback_count', ...
    'IL1_mean_A','IL2_mean_A','IL3_mean_A','IL4_mean_A', ...
    'IL1_rms_A','IL2_rms_A','IL3_rms_A','IL4_rms_A', ...
    'phase_order_error_rate','phase_event_count'});
end

function row = failureRow(spec, errorMessage, modelFile)
emptyMetrics = struct( ...
    "max_current_imbalance_A", NaN, ...
    "rms_current_imbalance_A", NaN, ...
    "phase_spacing_std_ns", NaN, ...
    "output_ripple_mV", NaN, ...
    "effective_switching_frequency_Hz", NaN, ...
    "ton_trim_usage", NaN, ...
    "lambda_trim_usage", NaN, ...
    "current_imbalance_settling_us", NaN, ...
    "final_vout_error_mV", NaN, ...
    "guard_clamp_count", NaN, ...
    "fallback_count", NaN, ...
    "IL_mean", NaN(1,4), ...
    "IL_rms", NaN(1,4), ...
    "phase_order_error_rate", NaN, ...
    "event_count", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage, modelFile);
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
fprintf(fid, "This run evaluates fixed-four-phase current sharing under one external DCR mismatch pattern at `40A`. The mismatch is a plant perturbation, not an AI action. No neural AI and no direct gate command are used.\n\n");
fprintf(fid, "## Model Copy Path\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Modified Blocks/Signals\n\n");
fprintf(fid, "- Replaced static load with `E030_Load_Current_Source` driven as a constant external `40A` current sink.\n");
fprintf(fid, "- DCR mismatch is injected through `SimulationInput` variables `DCR_L1..4`.\n");
if spec.ton_enable > 0
    fprintf(fid, "- Added zero-mean `Ton_diff` controller between `IQCOT_Ton_Adapter` and COT-cell Ton inputs.\n");
end
if spec.lambda_enable > 0
    fprintf(fid, "- Added bounded `Lambda_diff` event-spacing proxy before COT-cell trigger inputs.\n");
end
fprintf(fid, "\n## External Load Profile\n\nConstant `40A`; no AI-controlled load slew.\n\n");
fprintf(fid, "## Controller Variant\n\n`%s`\n\n", spec.variant);
fprintf(fid, "## Metrics\n\n");
writeMetricsMarkdownTable(fid, row);
fprintf(fid, "Phase trigger CSV: `%s`\n\n", slashPath(triggerCsv));
fprintf(fid, "## Classification\n\nPer-run status only. Final E030 classification is assigned in `e030_research_summary.md` after C0-C4 are compared.\n");
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "The derived model or run failed before interpretable E030 metrics were produced.\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Baseline path: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n");
fprintf(fid, "- Variant: `%s`\n", spec.variant);
fprintf(fid, "- Error: `%s`\n", message);
end

function [classification, detail] = classifyRows(rows)
if any(~rows.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E030 variant failed before reliable metrics were produced.";
    return;
end
needed = ["C0", "C1", "C2", "C3", "C4"];
for idx = 1:numel(needed)
    if ~any(rows.short_variant == needed(idx))
        classification = "IMPLEMENTATION_ISSUE";
        detail = "Missing required E030 variant " + needed(idx) + ".";
        return;
    end
end
c0 = rows(rows.short_variant == "C0", :);
c1 = rows(rows.short_variant == "C1", :);
c2 = rows(rows.short_variant == "C2", :);
c4 = rows(rows.short_variant == "C4", :);

improveC4 = c0.max_current_imbalance_A(1) - c4.max_current_imbalance_A(1);
bestSimple = min([c1.max_current_imbalance_A(1), c2.max_current_imbalance_A(1)]);
beatsSimple = c4.max_current_imbalance_A(1) <= bestSimple + 0.05;
spacingOk = c4.phase_spacing_std_ns(1) <= max(c0.phase_spacing_std_ns(1) + 50, 150);
rippleOk = c4.output_ripple_mV(1) <= max(c0.output_ripple_mV(1) + 1.0, 5.0);
freqOk = c4.effective_switching_frequency_Hz(1) >= 0.25e6 && c4.effective_switching_frequency_Hz(1) <= 2.5e6;
finalOk = abs(c4.final_vout_error_mV(1)) <= max(abs(c0.final_vout_error_mV(1)) + 1.0, 5.0);

if improveC4 > 0.1 && beatsSimple && spacingOk && rippleOk && freqOk && finalOk
    classification = "MODEL_CONFIRMED";
    detail = "C4 improved current sharing against C0 and stayed within local phase-spacing, ripple, frequency, and final-error budgets.";
elseif improveC4 > 0 || c1.max_current_imbalance_A(1) < c0.max_current_imbalance_A(1)
    classification = "MODEL_REVISED";
    detail = "Ton_diff or C4 improved current sharing, but the result needs a narrower projection or trim budget before claiming robust balance recovery.";
else
    classification = "CLAIM_DOWNGRADED";
    detail = "The first projected balancer did not improve current sharing relative to the DCR-mismatch baseline.";
end
end

function writeSummary(summaryPath, rows, classification, detail, metricsCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E030 Balance-Recovery Research Summary\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "PIS-IEK predicts `Ton_diff` as the dominant DC current-sharing actuator and `Lambda_diff` as a phase-spacing/ripple-recovery actuator. This first chunk tests one DCR mismatch pattern at fixed `40A` load.\n\n");
fprintf(fid, "## Model Copy Path\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.short_variant(idx), slashPath(rows.model_file(idx)));
end
fprintf(fid, "\n## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Modified Blocks/Signals\n\n");
fprintf(fid, "- C0: observability plus DCR mismatch injected through variables.\n");
fprintf(fid, "- C1: zero-mean `Ton_diff` current-sharing trim.\n");
fprintf(fid, "- C2: bounded `Lambda_diff` event-spacing proxy.\n");
fprintf(fid, "- C3: C1 and C2 combined.\n");
fprintf(fid, "- C4: conservative PIS-IEK projected balancer.\n\n");
fprintf(fid, "## External Load Profile\n\nConstant `40A`; load current remains an external validation input.\n\n");
fprintf(fid, "## Controller Variants Compared\n\n`C0`, `C1`, `C2`, `C3`, `C4`.\n\n");
fprintf(fid, "## Metrics Table\n\nMetrics CSV: `%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Waveform Interpretation\n\n");
writeInterpretation(fid, rows);
fprintf(fid, "## Failure Or Trade-Off Analysis\n\n%s\n\n", detail);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "## Theory Documents Updated\n\nUpdate `docs/theory/03_pis_iek_small_signal_model.md`, `docs/theory/04_ai_action_space_and_projection.md`, and `docs/theory/06_claim_boundaries.md` after reviewing this classification.\n\n");
fprintf(fid, "## Claim Boundary Updated\n\nUntil claim-boundary documents are updated, treat this as E030 derived-Simulink evidence only. It is not hardware, HIL, board-level, or silicon evidence.\n\n");
fprintf(fid, "## Next Smallest Useful Experiment\n\n");
if classification == "IMPLEMENTATION_ISSUE"
    fprintf(fid, "Fix E030 wiring/logging and rerun C0-C4.\n");
elseif classification == "MODEL_CONFIRMED"
    fprintf(fid, "Repeat with one additional mismatch family, preferably current-sense gain +/-5%% or DCR +/-5%%.\n");
elseif classification == "MODEL_REVISED"
    fprintf(fid, "Retune `T_trim_max`, `K_T`, and the Lambda event-spacing proxy before broad mismatch grids.\n");
else
    fprintf(fid, "Downgrade the controller claim and keep PIS-IEK as actuator-classification evidence until a revised balancer is available.\n");
end
end

function writeWaveformAudit(auditPath, rows)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E030 Waveform Audit\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Audit for the smallest E030 DCR-mismatch chunk: fixed `40A`, alternating DCR +/-10%%, variants C0-C4.\n\n");
fprintf(fid, "## Required Signals\n\n");
fprintf(fid, "- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`\n");
fprintf(fid, "- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`\n");
fprintf(fid, "- `Ton_trim1..4`, `Lambda_trim1..4` where applicable\n");
fprintf(fid, "- `active_phase_set`, `guard_clamp_count`, `fallback_count`\n\n");
fprintf(fid, "## Generated Phase Trigger Tables\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `experiments/E030_balance_recovery/%s`\n", ...
        rows.short_variant(idx), triggerFileName(rows.short_variant(idx)));
end
fprintf(fid, "\n## Structural Check Note\n\n");
fprintf(fid, "Run `model_check` on the derived C4 model and compare with the baseline/B0 pattern before broadening E030. Known inherited baseline warnings may include unused diagnostic outputs and Simscape physical-port check artifacts.\n");
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | Max imbalance A | RMS imbalance A | Phase spacing std ns | Ripple mV | Eff. fsw Hz | Ton usage | Lambda usage | Settling us | Final Vout err mV | Clamp | Fallback | Order error |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g | %.6g |\n", ...
        rows.short_variant(idx), rows.success(idx), rows.max_current_imbalance_A(idx), ...
        rows.rms_current_imbalance_A(idx), rows.phase_spacing_std_ns(idx), ...
        rows.output_ripple_mV(idx), rows.effective_switching_frequency_Hz(idx), ...
        rows.ton_trim_usage(idx), rows.lambda_trim_usage(idx), ...
        rows.current_imbalance_settling_us(idx), rows.final_vout_error_mV(idx), ...
        rows.guard_clamp_count(idx), rows.fallback_count(idx), rows.phase_order_error_rate(idx));
end
fprintf(fid, "\n");
end

function writeInterpretation(fid, rows)
if any(~rows.success)
    fprintf(fid, "At least one row failed; do not interpret partial E030 metrics as controller evidence.\n\n");
    return;
end
c0 = rows(rows.short_variant == "C0", :);
if isempty(c0)
    fprintf(fid, "C0 is missing, so no improvement comparison is valid.\n\n");
    return;
end
fprintf(fid, "C0 max current imbalance is `%.6g A`. Reductions relative to C0:\n\n", c0.max_current_imbalance_A(1));
fprintf(fid, "| Variant | Imbalance reduction A | Phase-spacing std delta ns | Ripple delta mV |\n");
fprintf(fid, "|---|---:|---:|---:|\n");
for idx = 1:height(rows)
    if rows.short_variant(idx) == "C0"
        continue;
    end
    fprintf(fid, "| %s | %.6g | %.6g | %.6g |\n", rows.short_variant(idx), ...
        c0.max_current_imbalance_A(1) - rows.max_current_imbalance_A(idx), ...
        rows.phase_spacing_std_ns(idx) - c0.phase_spacing_std_ns(1), ...
        rows.output_ripple_mV(idx) - c0.output_ripple_mV(1));
end
fprintf(fid, "\n");
end

function name = triggerFileName(shortVariant)
shortVariant = string(shortVariant);
if shortVariant == "C0"
    name = "e030_c0_dcr_mismatch_phase_triggers.csv";
elseif shortVariant == "C1"
    name = "e030_c1_ton_diff_phase_triggers.csv";
elseif shortVariant == "C2"
    name = "e030_c2_lambda_diff_phase_triggers.csv";
elseif shortVariant == "C3"
    name = "e030_c3_ton_lambda_diff_phase_triggers.csv";
elseif shortVariant == "C4"
    name = "e030_c4_pis_iek_projected_phase_triggers.csv";
else
    name = "e030_unknown_phase_triggers.csv";
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
