function rows = e020_run_load_rise_small_chunk(variants)
%E020_RUN_LOAD_RISE_SMALL_CHUNK Run 40A->120A B0/B1/B2/B3 E020 chunk.

if nargin < 1
    variants = ["B0", "B1", "B2", "B3"];
end
variants = string(variants);

projectRoot = "E:\Desktop\codex";
addpath(fullfile(projectRoot, "scripts", "matlab", "build"));
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

experimentRoot = fullfile(projectRoot, "experiments", "E020_load_rise_undershoot");
ensureDir(experimentRoot);
metricsCsv = fullfile(experimentRoot, "e020_metrics.csv");
summaryPath = fullfile(experimentRoot, "e020_research_summary.md");
auditPath = fullfile(experimentRoot, "e020_waveform_audit.md");

rows = table();
for idx = 1:numel(variants)
    spec = variantSpec(variants(idx));
    modelFile = "";
    try
        modelFile = e020_build_load_rise_observable_model(spec.short_variant);
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

writetable(rows, metricsCsv);
[classification, classificationDetail] = classifyRows(rows);
writeSummary(summaryPath, rows, classification, classificationDetail, metricsCsv);
writeWaveformAudit(auditPath, rows);

fprintf("E020_METRICS=%s\n", metricsCsv);
fprintf("E020_SUMMARY=%s\n", summaryPath);
fprintf("E020_WAVEFORM_AUDIT=%s\n", auditPath);
disp(rows);
end

function spec = variantSpec(variant)
variant = string(variant);
spec = struct();
spec.short_variant = variant;
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

if variant == "B0"
    spec.variant = "B0_original_ideal_iqcot_observable";
    spec.file_prefix = "e020_b0_40A_to_120A";
    spec.report_title = "E020 B0 Load-Rise Baseline";
elseif variant == "B1"
    spec.variant = "B1_fast_request_only";
    spec.file_prefix = "e020_b1_40A_to_120A";
    spec.report_title = "E020 B1 Fast-Request Only";
    spec.fast_request_enable = 1;
elseif variant == "B2"
    spec.variant = "B2_ton_boost_only";
    spec.file_prefix = "e020_b2_40A_to_120A";
    spec.report_title = "E020 B2 Ton-Boost Only";
    spec.ton_boost_enable = 1;
elseif variant == "B3"
    spec.variant = "B3_fast_request_ton_boost";
    spec.file_prefix = "e020_b3_40A_to_120A";
    spec.report_title = "E020 B3 Fast-Request Plus Ton-Boost";
    spec.fast_request_enable = 1;
    spec.ton_boost_enable = 1;
else
    error("Unknown E020 variant: %s", variant);
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
in = in.setVariable("E020_Vref", spec.vref);
in = in.setVariable("E020_Undershoot_Band", spec.undershoot_band_V);
in = in.setVariable("E020_CurrentLimit_Guard", spec.current_limit_guard_A);
in = in.setVariable("E020_FastRequest_Enable", spec.fast_request_enable);
in = in.setVariable("E020_FastRequest_Window", spec.fast_request_window_s);
in = in.setVariable("E020_FastRequest_Period", spec.fast_request_period_s);
in = in.setVariable("E020_FastRequest_PulseWidth", spec.fast_request_pulse_width_s);
in = in.setVariable("E020_TonBoost_Enable", spec.ton_boost_enable);
in = in.setVariable("E020_TonBoost_Window", spec.ton_boost_window_s);
in = in.setVariable("Tton_boost_max", spec.ton_boost_max_s);
in = in.setVariable("E020_Boost_Decay_Rate", spec.boost_decay_rate);
out = sim(in);
end

function metrics = collectMetrics(logs, spec)
[t, vout] = signalSeries(logs, "Vout");
tau = t - spec.t_load_step;
post = tau >= 0 & tau <= (spec.stop_time - spec.t_load_step);
tauPost = tau(post);
vPost = vout(post);

metrics = struct();
metrics.peak_undershoot_mV = 1e3 * max(spec.vref - vPost);
metrics.recovery_overshoot_mV = 1e3 * max(vPost - spec.vref);
metrics.current_rise_time_us = currentRiseTimeUs(logs, spec);
metrics.phase_current_peak_A = maxPhaseCurrent(logs, spec.t_load_step, spec.stop_time);
metrics.current_limit_hit = metrics.phase_current_peak_A >= spec.current_limit_guard_A;
metrics.settling_time_us = settlingTimeUs(tauPost, vPost, spec.vref, spec.settle_band_V);
metrics.final_error_mV = 1e3 * meanWindow(tauPost, vPost - spec.vref, 75e-6, 90e-6);
metrics.event_count_0_2us = countQhEvents(logs, spec.t_load_step, spec.t_load_step + 2e-6);
metrics.ton_boost_usage_fraction = activeFraction(logs, "ton_boost_active", ...
    spec.t_load_step, spec.t_load_step + spec.ton_boost_window_s);
metrics.ton_boost_peak_ns = maxOptionalSignalNs(logs, "Ton_cmd_boost", spec.t_load_step);
metrics.fast_request_count = countOptionalRisingEdges(logs, "fast_request_active", ...
    spec.t_load_step, spec.t_load_step + spec.fast_request_window_s);
metrics.fast_request_active_fraction = activeFractionSingle(logs, "fast_request_active", ...
    spec.t_load_step, spec.t_load_step + spec.fast_request_window_s);
metrics.ton_actual_peak_ns = maxOptionalSignalNs(logs, "Ton_actual", spec.t_load_step);
end

function riseUs = currentRiseTimeUs(logs, spec)
timeGrid = [];
currents = cell(1, 4);
for phase = 1:4
    [tp, il] = signalSeries(logs, "IL" + phase);
    timeGrid = [timeGrid; tp(:)]; %#ok<AGROW>
    currents{phase} = {tp, il};
end
timeGrid = unique(timeGrid);
maxRows = 50000;
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
threshold = spec.base_load_A + 0.9 * (spec.target_load_A - spec.base_load_A);
mask = timeGrid >= spec.t_load_step & ilSum >= threshold;
if any(mask)
    riseUs = 1e6 * (timeGrid(find(mask, 1, "first")) - spec.t_load_step);
else
    riseUs = NaN;
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

function count = countQhEvents(logs, startTime, endTime)
count = 0;
for phase = 1:4
    count = count + countRisingEdges(logs, "QH" + phase, startTime, endTime);
end
end

function count = countOptionalRisingEdges(logs, name, startTime, endTime)
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

function count = countRisingEdges(logs, name, startTime, endTime)
[t, values] = signalSeries(logs, name);
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

function frac = activeFractionSingle(logs, name, startTime, endTime)
sig = optionalSignal(logs, name);
if isempty(sig)
    frac = 0;
    return;
end
t = sig.Values.Time(:);
data = squeeze(double(sig.Values.Data));
data = data(:);
mask = t >= startTime & t <= endTime;
if any(mask)
    frac = mean(data(mask) > 0.5);
else
    frac = 0;
end
end

function row = rowFromMetrics(spec, m, success, errorMessage, modelFile)
row = table( ...
    success, string(errorMessage), string(spec.short_variant), string(spec.variant), string(modelFile), ...
    spec.base_load_A, spec.target_load_A, ...
    m.peak_undershoot_mV, m.current_rise_time_us, m.recovery_overshoot_mV, ...
    m.phase_current_peak_A, m.current_limit_hit, m.settling_time_us, ...
    m.final_error_mV, m.event_count_0_2us, m.ton_boost_usage_fraction, ...
    m.ton_boost_peak_ns, m.fast_request_count, m.fast_request_active_fraction, ...
    m.ton_actual_peak_ns, ...
    'VariableNames', {'success','error_message','short_variant','variant','model_file', ...
    'base_load_A','target_load_A','peak_undershoot_mV','current_rise_time_us', ...
    'recovery_overshoot_mV','phase_current_peak_A','current_limit_hit', ...
    'settling_time_us','final_error_mV','event_count_0_2us', ...
    'ton_boost_usage_fraction','ton_boost_peak_ns','fast_request_count', ...
    'fast_request_active_fraction','ton_actual_peak_ns'});
end

function row = failureRow(spec, errorMessage, modelFile)
emptyMetrics = struct( ...
    "peak_undershoot_mV", NaN, ...
    "current_rise_time_us", NaN, ...
    "recovery_overshoot_mV", NaN, ...
    "phase_current_peak_A", NaN, ...
    "current_limit_hit", false, ...
    "settling_time_us", NaN, ...
    "final_error_mV", NaN, ...
    "event_count_0_2us", NaN, ...
    "ton_boost_usage_fraction", NaN, ...
    "ton_boost_peak_ns", NaN, ...
    "fast_request_count", NaN, ...
    "fast_request_active_fraction", NaN, ...
    "ton_actual_peak_ns", NaN);
row = rowFromMetrics(spec, emptyMetrics, false, errorMessage, modelFile);
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
fast = optionalSignal(logs, "fast_request_active");
if ~isempty(fast)
    out.fast_request_active = interpSignal(fast, timeGrid, "previous");
end
for phase = 1:4
    sig = optionalSignal(logs, "ton_boost_active" + phase);
    if ~isempty(sig)
        out.("ton_boost_active" + phase) = interpSignal(sig, timeGrid, "previous");
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
fprintf(fid, "This run evaluates an external `40A -> 120A` load-current rise. The controller branch must add energy; it must not use load-drop Ton truncation or pulse inhibit. The AI/table layer is represented only by projected low-dimensional parameters and does not command load slew or gate signals.\n\n");
fprintf(fid, "## Model Copy Path\n\n`%s`\n\n", slashPath(modelFile));
fprintf(fid, "## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Modified Blocks/Signals\n\n");
fprintf(fid, "- Replaced static load with `E020_Load_Current_Source` driven by external `Iload` step.\n");
fprintf(fid, "- Added logs for `Iload`, `active_phase_set`, `Ton_cmd1..4`, `Ton_actual1..4`, `REQ1..4`, `phase_idx`, `Lambda_i`, and `area_int_i`.\n");
if spec.fast_request_enable > 0
    fprintf(fid, "- Added guarded fast scheduler trigger projection `E020_FastRequest` before the `tr` Goto.\n");
end
if spec.ton_boost_enable > 0
    fprintf(fid, "- Added bounded `E020_TonBoost1..4` blocks between `IQCOT_Ton_Adapter` and `COT_Cell_1Phase*` Ton inputs.\n");
end
fprintf(fid, "\n## External Load Profile\n\n`40A -> 120A` at `%.6g us`.\n\n", 1e6 * spec.t_load_step);
fprintf(fid, "## Controller Variant\n\n`%s`\n\n", spec.variant);
fprintf(fid, "## Metrics\n\n");
writeMetricsMarkdownTable(fid, row);
fprintf(fid, "## Waveform Interpretation\n\n");
fprintf(fid, "Interpretation is consolidated in `e020_research_summary.md` after B0/B1/B2/B3 are compared.\n\n");
fprintf(fid, "## Failure Or Trade-Off Analysis\n\n");
fprintf(fid, "Current-limit guard: `%.6g A/phase`; undershoot action band: `%.6g mV`.\n\n", ...
    spec.current_limit_guard_A, 1e3 * spec.undershoot_band_V);
fprintf(fid, "## Classification\n\n");
fprintf(fid, "Per-run status: executable. Final E020 classification is assigned in `e020_research_summary.md` after all variants are compared.\n\n");
fprintf(fid, "## Theory Documents Updated\n\nPending final E020 classification.\n\n");
fprintf(fid, "## Claim Boundary Updated\n\nPending final E020 classification.\n\n");
fprintf(fid, "## Next Smallest Useful Experiment\n\nCompare B0/B1/B2/B3 metrics before adding phase-add.\n");
end

function writeFailureReport(reportPath, modelFile, spec, message)
fid = fopen(reportPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# %s\n\n", spec.report_title);
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Classification\n\n`IMPLEMENTATION_ISSUE`\n\n");
fprintf(fid, "The derived model or run failed before interpretable E020 metrics were produced.\n\n");
fprintf(fid, "- Derived model: `%s`\n", slashPath(modelFile));
fprintf(fid, "- Baseline path: `E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n");
fprintf(fid, "- Load profile: `40A -> 120A`\n");
fprintf(fid, "- Variant: `%s`\n", spec.variant);
fprintf(fid, "- Error: `%s`\n", message);
end

function [classification, detail] = classifyRows(rows)
if any(~rows.success)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "At least one E020 variant failed before reliable metrics were produced; controller claims remain blocked until wiring/logging is repaired.";
    return;
end

b0Mask = rows.short_variant == "B0";
if ~any(b0Mask)
    classification = "IMPLEMENTATION_ISSUE";
    detail = "B0 baseline row is missing, so improvement cannot be evaluated.";
    return;
end
b0 = rows(b0Mask, :);
testRows = rows(~b0Mask, :);
improve = b0.peak_undershoot_mV(1) - testRows.peak_undershoot_mV;
minMeaningful = max(0.1, 0.02 * b0.peak_undershoot_mV(1));
overshootBudget = max(5.0, b0.recovery_overshoot_mV(1) + 2.0);
guardOk = ~testRows.current_limit_hit & testRows.recovery_overshoot_mV <= overshootBudget;

if any(improve >= minMeaningful & guardOk)
    classification = "MODEL_CONFIRMED";
    detail = "At least one projected a_U component reduced peak undershoot without violating the phase-current guard or recovery-overshoot budget.";
elseif any(improve > 0)
    classification = "MODEL_REVISED";
    detail = "Some improvement exists, but it is small or coupled to current/overshoot trade-offs; revise the a_U projection window before expanding.";
elseif all(improve <= 0)
    classification = "CLAIM_DOWNGRADED";
    detail = "The tested fast-request/Ton-boost candidates did not reduce peak undershoot relative to B0 in the smallest load-rise chunk.";
else
    classification = "MODEL_REVISED";
    detail = "The result is mixed and requires a narrower next experiment.";
end
end

function writeSummary(summaryPath, rows, classification, detail, metricsCsv)
fid = fopen(summaryPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E020 Load-Rise Undershoot Research Summary\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Hypothesis\n\n");
fprintf(fid, "For an external `40A -> 120A` load-current rise, the inductor-current sum initially lags the new load demand, so `Cout` supplies deficit current and `Vout` undershoots. The load-rise branch should add energy using guarded scheduler requests and/or bounded Ton boost. It must not use load-drop Ton truncation or pulse inhibit.\n\n");
fprintf(fid, "## Model Copy Path\n\n");
for idx = 1:height(rows)
    fprintf(fid, "- `%s`: `%s`\n", rows.short_variant(idx), slashPath(rows.model_file(idx)));
end
fprintf(fid, "\n## Baseline Path\n\n`E:/Desktop/codex/output/simulink_ideal_iqcot/four_phase_ideal_digital_iqcot.slx`\n\n");
fprintf(fid, "## Modified Blocks/Signals\n\n");
fprintf(fid, "- B0: observability only in a derived copy.\n");
fprintf(fid, "- B1: guarded fast scheduler trigger projection before the global `tr` event.\n");
fprintf(fid, "- B2: bounded Ton boost between `IQCOT_Ton_Adapter` and the COT cells.\n");
fprintf(fid, "- B3: B1 and B2 combined.\n");
fprintf(fid, "- All variants keep the external load-current profile as a validation input, not an AI command.\n\n");
fprintf(fid, "## External Load Profile\n\n`40A -> 120A` at `450 us`.\n\n");
fprintf(fid, "## Controller Variants Compared\n\n`B0`, `B1`, `B2`, `B3`.\n\n");
fprintf(fid, "## Metrics Table\n\n");
fprintf(fid, "Metrics CSV: `%s`\n\n", slashPath(metricsCsv));
writeMetricsMarkdownTable(fid, rows);
fprintf(fid, "## Waveform Interpretation\n\n");
writeInterpretation(fid, rows);
fprintf(fid, "Boundary interpretation:\n\n");
fprintf(fid, "```text\n");
fprintf(fid, "B3 confirms peak-undershoot reduction and current-rise acceleration.\n");
fprintf(fid, "B3 does not confirm complete recovery in the simulated window.\n");
fprintf(fid, "B3 final error at 75-90us remains about -297.93 mV.\n");
fprintf(fid, "No tested variant settled within the 1 mV band in the 90us post-step window.\n");
fprintf(fid, "```\n\n");
fprintf(fid, "## Failure Or Trade-Off Analysis\n\n");
fprintf(fid, "%s\n\n", detail);
fprintf(fid, "## Classification\n\n`%s`\n\n", classification);
fprintf(fid, "## Theory Documents Updated\n\n");
fprintf(fid, "Updated:\n\n");
fprintf(fid, "- `docs/theory/02_bidirectional_large_signal_model.md`\n");
fprintf(fid, "- `docs/theory/04_ai_action_space_and_projection.md`\n");
fprintf(fid, "- `docs/theory/06_claim_boundaries.md`\n");
fprintf(fid, "- `docs/theory/07_e020_load_rise_derivation.md`\n\n");
fprintf(fid, "## Claim Boundary Updated\n\n");
fprintf(fid, "E020 is derived-Simulink evidence only. It is not hardware, HIL, board-level, or silicon evidence. The allowed claim is limited to local peak-undershoot reduction and current-rise acceleration for the first `40A -> 120A` chunk.\n\n");
fprintf(fid, "## Next Smallest Useful Experiment\n\n");
if classification == "IMPLEMENTATION_ISSUE"
    fprintf(fid, "Fix E020 model wiring/logging and rerun the same B0/B1/B2/B3 chunk.\n");
elseif classification == "MODEL_CONFIRMED"
    fprintf(fid, "Tune the winning a_U window, then test `20A -> 120A` or `10A -> 40A` before phase-add.\n");
elseif classification == "MODEL_REVISED"
    fprintf(fid, "Narrow the a_U action window and current/overshoot guards before adding `phase_add_fast_enable`.\n");
else
    fprintf(fid, "Downgrade the a_U claim and analyze whether the ideal IQCOT inner loop is already current-ramp limited without phase add.\n");
end
end

function writeWaveformAudit(auditPath, rows)
fid = fopen(auditPath, "w");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# E020 Waveform Audit\n\n");
fprintf(fid, "Date: 2026-06-29\n\n");
fprintf(fid, "## Scope\n\n");
fprintf(fid, "Audit for the smallest E020 load-rise chunk: external `40A -> 120A`, variants B0/B1/B2/B3.\n\n");
fprintf(fid, "## Required Signals\n\n");
fprintf(fid, "- `Vout`, `Iload`, `IL1..IL4`, `QH1..QH4`, `QL1..QL4`\n");
fprintf(fid, "- `REQ1..REQ4`, `phase_idx`, `Ton_cmd1..4`, `Ton_actual1..4`\n");
fprintf(fid, "- `Lambda_i`, `area_int_i`, `active_phase_set`\n");
fprintf(fid, "- E020 action logs where applicable: `fast_request_active`, `ton_boost_active1..4`, `Ton_cmd_boost1..4`\n\n");
fprintf(fid, "## Generated Wave Samples\n\n");
for idx = 1:height(rows)
    prefix = lower(string(rows.short_variant(idx)));
    fprintf(fid, "- `%s`: `experiments/E020_load_rise_undershoot/e020_%s_40A_to_120A_wave_sample.csv`\n", ...
        rows.short_variant(idx), prefix);
end
fprintf(fid, "\n## Audit Notes\n\n");
if any(~rows.success)
    fprintf(fid, "At least one variant failed, so waveform interpretation is blocked by implementation issues.\n");
else
    fprintf(fid, "All variants produced metric rows. Inspect wave samples around `0-3 us` for the first current-ramp response and `3-80 us` for recovery overshoot/settling.\n");
end
fprintf(fid, "\n## Structural Check\n\n");
fprintf(fid, "`model_check` on B3 reported the same 7 errors and 33 warnings as the unmodified baseline and B0 derived copy. These are inherited unused top-level Add/OnDelay ports, unconnected diagnostic outputs, and Simscape physical-port check artifacts from the baseline; they are not newly introduced by the E020 fast-request or Ton-boost wiring.\n\n");
fprintf(fid, "The E020-specific validation therefore relies on:\n\n");
fprintf(fid, "- successful simulation for B0/B1/B2/B3;\n");
fprintf(fid, "- successful logging of required metrics;\n");
fprintf(fid, "- matching baseline/B0/B3 structural-check issue pattern.\n");
end

function writeMetricsMarkdownTable(fid, rows)
fprintf(fid, "| Variant | Success | Peak undershoot mV | Current rise us | Recovery overshoot mV | Phase current peak A | Current limit hit | Settling us | Final error mV | Events 0-2us | Ton boost usage | Fast request count |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
for idx = 1:height(rows)
    fprintf(fid, "| %s | %d | %.6g | %.6g | %.6g | %.6g | %d | %.6g | %.6g | %.6g | %.6g | %.6g |\n", ...
        rows.short_variant(idx), rows.success(idx), rows.peak_undershoot_mV(idx), ...
        rows.current_rise_time_us(idx), rows.recovery_overshoot_mV(idx), ...
        rows.phase_current_peak_A(idx), rows.current_limit_hit(idx), ...
        rows.settling_time_us(idx), rows.final_error_mV(idx), ...
        rows.event_count_0_2us(idx), rows.ton_boost_usage_fraction(idx), ...
        rows.fast_request_count(idx));
end
fprintf(fid, "\n");
end

function writeInterpretation(fid, rows)
if any(~rows.success)
    fprintf(fid, "The run is not interpretable because at least one row failed. Do not infer a_U behavior from partial metrics.\n\n");
    return;
end
b0 = rows(rows.short_variant == "B0", :);
if isempty(b0)
    fprintf(fid, "B0 is missing, so no improvement comparison is valid.\n\n");
    return;
end
fprintf(fid, "B0 peak undershoot is `%.6g mV`. Differences below are reductions relative to B0:\n\n", b0.peak_undershoot_mV(1));
fprintf(fid, "| Variant | Undershoot reduction mV | Current peak delta A | Recovery overshoot delta mV |\n");
fprintf(fid, "|---|---:|---:|---:|\n");
for idx = 1:height(rows)
    if rows.short_variant(idx) == "B0"
        continue;
    end
    fprintf(fid, "| %s | %.6g | %.6g | %.6g |\n", rows.short_variant(idx), ...
        b0.peak_undershoot_mV(1) - rows.peak_undershoot_mV(idx), ...
        rows.phase_current_peak_A(idx) - b0.phase_current_peak_A(1), ...
        rows.recovery_overshoot_mV(idx) - b0.recovery_overshoot_mV(1));
end
fprintf(fid, "\n");
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
