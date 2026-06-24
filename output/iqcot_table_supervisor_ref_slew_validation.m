function rows = iqcot_table_supervisor_ref_slew_validation(runSimulink, tauAiUs)
%IQCOT_TABLE_SUPERVISOR_REF_SLEW_VALIDATION Table-in-loop IQCOT validation.
%
% Default usage:
%   iqcot_table_supervisor_ref_slew_validation(false)
%
% Switching validation:
%   iqcot_table_supervisor_ref_slew_validation(true, [0 1 5])
%
% The script uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or edit the SLX file.  AI is represented as a table-driven
% supervisory layer that selects T_slew; FPGA latency is emulated by delaying
% the Iph_ref timeseries start by tau_AI for table policies.

clc;

if nargin < 1 || isempty(runSimulink)
    runSimulink = false;
end
if nargin < 2 || isempty(tauAiUs)
    tauAiUs = [0 0.5 1 2 5];
end
setappdata(0, "iqcot_table_supervisor_run_simulink", runSimulink);
setappdata(0, "iqcot_table_supervisor_tau_ai_us", tauAiUs);

initRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
run(fullfile(initRoot, "init_four_phase_cot_sync.m"));

% The init script may clear caller variables, so define paths after it.
runSimulink = getappdata(0, "iqcot_table_supervisor_run_simulink");
tauAiUs = getappdata(0, "iqcot_table_supervisor_tau_ai_us");
rmappdata(0, "iqcot_table_supervisor_run_simulink");
rmappdata(0, "iqcot_table_supervisor_tau_ai_us");
srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
modelRoot = "E:\Desktop\codex\output\simulink_iek";
outputRoot = "E:\Desktop\codex\output";
figureRoot = fullfile(outputRoot, "figures");
if ~exist(figureRoot, "dir")
    mkdir(figureRoot);
end
addpath(outputRoot);
addpath(srcRoot);

% Simulink variable resolution can depend on the base workspace even when
% this runner is called as a function. Mirror init-script variables so the
% derived SLX sees the same parameter set used by the original sweep script.
localVars = whos;
for varIdx = 1:numel(localVars)
    varName = localVars(varIdx).name;
    if varName ~= "localVars" && varName ~= "varIdx"
        assignin("base", varName, eval(varName));
    end
end

model = "four_phase_iek_dynamic_load_refslew";
modelFile = fullfile(modelRoot, model + ".slx");
if ~exist(modelFile, "file")
    error("Derived model not found: %s", modelFile);
end

trainingPath = fullfile(outputRoot, "iqcot_ai_supervisor_training_targets.csv");
training = readtable(trainingPath);
plan = buildPlan(training, tauAiUs);
outputSuffix = makeTauOutputSuffix(tauAiUs);

planPath = fullfile(outputRoot, "iqcot_table_supervisor_validation_plan_matlab" + outputSuffix + ".csv");
writetable(plan, planPath);

if ~runSimulink
    writeDryRunReport(plan, planPath, outputRoot);
    fprintf("TABLE_SUPERVISOR_PLAN=%s\n", planPath);
    fprintf("Dry run only. To run delayed switching validation, call:\n");
    fprintf("  iqcot_table_supervisor_ref_slew_validation(true, [0 1 5])\n");
    rows = plan;
    return;
end

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
cd(modelRoot);

load_system(modelFile);
modelCleanup = onCleanup(@() close_system(model, 0));
instrumentSignals(model);

common = struct();
common.lambdaArea = 6e-10;
common.vAreaBias = 2e-3;
common.riArea = 0.5e-3;
common.tStep = 0.45e-3;
common.stopTime = 0.60e-3;
common.postSteadyWindow = 20e-6;
common.preSteadyWindow = 50e-6;
common.maxStep = "5e-9";
common.fastTss = 5e-9;
if exist("Vo_ref", "var")
    common.voRef = Vo_ref;
else
    common.voRef = evalin("base", "Vo_ref");
end
if exist("Tslot", "var")
    common.expectedSlot = Tslot;
else
    common.expectedSlot = evalin("base", "Tslot");
end

baseLoadA = 40;
rows = table();
for k = 1:height(plan)
    spec = makeSpec(baseLoadA, plan.target_load_A(k), ...
        plan.selected_ref_slew_us(k), plan.ref_start_delay_us_for_simulink(k), common);
    fprintf("Table supervisor case: %s, %.1f A -> %.6g A, slew %.3f us, delay %.3f us\n", ...
        string(plan.policy(k)), baseLoadA, spec.load_A, spec.ref_slew_us, spec.ref_start_delay_us);
    try
        out = runDelayedSlewCase(model, spec, common);
        logs = out.logsout;
        baseMetrics = preStepMetrics(logs, common, baseLoadA);
        metrics = transientMetrics(logs, spec, common, baseMetrics);
        rows = [rows; rowFromMetrics(plan(k, :), spec, metrics)]; %#ok<AGROW>
    catch ME
        detailedMessage = compactErrorReport(ME);
        rows = [rows; failureRow(plan(k, :), spec, detailedMessage)]; %#ok<AGROW>
        warning("iqcot:TableSupervisorCaseFailed", "Case failed: %s", detailedMessage);
    end
end

resultPath = fullfile(outputRoot, "iqcot_table_supervisor_validation_results" + outputSuffix + ".csv");
policyPath = fullfile(outputRoot, "iqcot_table_supervisor_validation_policy_eval" + outputSuffix + ".csv");
reportPath = fullfile(outputRoot, "iqcot_table_supervisor_validation_switching_report" + outputSuffix + ".md");
figurePath = fullfile(figureRoot, "fig27_table_supervisor_delayed_switching" + outputSuffix + ".png");
writetable(rows, resultPath);
policyEval = summarizePolicies(rows);
writetable(policyEval, policyPath);
writeSwitchingReport(rows, policyEval, resultPath, policyPath, reportPath);
makePolicyPlot(policyEval, figurePath);

fprintf("TABLE_SUPERVISOR_RESULTS=%s\n", resultPath);
fprintf("TABLE_SUPERVISOR_POLICY_EVAL=%s\n", policyPath);
fprintf("TABLE_SUPERVISOR_SWITCHING_REPORT=%s\n", reportPath);
fprintf("TABLE_SUPERVISOR_FIGURE=%s\n", figurePath);
end

function suffix = makeTauOutputSuffix(tauAiUs)
tauAiUs = sort(tauAiUs(:).');
if isscalar(tauAiUs) && abs(tauAiUs - 5) < 1e-12
    suffix = "";
    return;
end
parts = strings(1, numel(tauAiUs));
for idx = 1:numel(tauAiUs)
    token = erase(string(sprintf("%.6g", tauAiUs(idx))), "+");
    token = replace(token, ".", "p");
    parts(idx) = token;
end
suffix = "_tau" + strjoin(parts, "_") + "us";
end

function plan = buildPlan(training, tauAiUs)
policies = {
    "fixed_40us_precommitted", "fixed", NaN, 40, "precommitted", "base";
    "fixed_80us_precommitted", "fixed", NaN, 80, "precommitted", "base";
    "oracle_base_table", "table", 0.00, NaN, "commit_after_tau_ai", "base";
    "table_settle005", "table", 0.05, NaN, "commit_after_tau_ai", "settle005";
    "table_settle010", "table", 0.10, NaN, "commit_after_tau_ai", "settle010";
};
targets = [20 10 1e-3];
eventPeriodUs = 0.5;

policy = strings(0, 1);
policyKind = strings(0, 1);
objectiveAlpha = [];
targetLoad = [];
loadDrop = [];
selectedSlew = [];
tauAi = [];
delayEvents = [];
eventPeriod = [];
refStartDelay = [];
delayMode = strings(0, 1);
objectiveLabel = strings(0, 1);

for p = 1:size(policies, 1)
    for t = 1:numel(targets)
        target = targets(t);
        if policies{p, 2} == "fixed"
            slew = policies{p, 4};
        else
            slew = lookupTrainingSlew(training, target, policies{p, 3});
        end
        for d = 1:numel(tauAiUs)
            tau = tauAiUs(d);
            policy(end + 1, 1) = policies{p, 1}; %#ok<AGROW>
            policyKind(end + 1, 1) = policies{p, 2}; %#ok<AGROW>
            objectiveAlpha(end + 1, 1) = policies{p, 3}; %#ok<AGROW>
            targetLoad(end + 1, 1) = target; %#ok<AGROW>
            loadDrop(end + 1, 1) = 40 - target; %#ok<AGROW>
            selectedSlew(end + 1, 1) = slew; %#ok<AGROW>
            tauAi(end + 1, 1) = tau; %#ok<AGROW>
            delayEvents(end + 1, 1) = ceil(tau / eventPeriodUs - 1e-12); %#ok<AGROW>
            eventPeriod(end + 1, 1) = eventPeriodUs; %#ok<AGROW>
            if policies{p, 5} == "precommitted"
                refStartDelay(end + 1, 1) = 0; %#ok<AGROW>
            else
                refStartDelay(end + 1, 1) = tau; %#ok<AGROW>
            end
            delayMode(end + 1, 1) = policies{p, 5}; %#ok<AGROW>
            objectiveLabel(end + 1, 1) = policies{p, 6}; %#ok<AGROW>
        end
    end
end

plan = table(policy, policyKind, objectiveAlpha, targetLoad, loadDrop, ...
    selectedSlew, tauAi, delayEvents, eventPeriod, refStartDelay, delayMode, objectiveLabel, ...
    'VariableNames', {'policy','policy_kind','objective_alpha_settle', ...
    'target_load_A','load_drop_A','selected_ref_slew_us','tau_ai_us', ...
    'delay_events','event_period_us_assumed','ref_start_delay_us_for_simulink', ...
    'delay_mode','objective_label'});
end

function slew = lookupTrainingSlew(training, targetLoadA, alpha)
mask = abs(training.target_load_A - targetLoadA) < 1e-9 ...
    & abs(training.objective_alpha_settle - alpha) < 1e-12 ...
    & abs(training.tau_ai_us) < 1e-12;
if ~any(mask)
    error("Missing training label for target %.6g A alpha %.3f.", targetLoadA, alpha);
end
idx = find(mask, 1, "first");
slew = training.selected_ref_slew_us(idx);
end

function spec = makeSpec(baseLoadA, targetLoadA, slewUs, delayUs, common)
spec = struct();
spec.controller_mode = "table_supervisor_refslew";
spec.base_load_A = baseLoadA;
spec.load_A = targetLoadA;
spec.effective_load_A = max(targetLoadA, 1e-3);
spec.Rload = common.voRef / spec.effective_load_A;
spec.Iph_initial = baseLoadA / 4;
spec.Iph_final = targetLoadA / 4;
spec.Iph = spec.Iph_final;
spec.ref_slew_us = slewUs;
spec.ref_slew_s = slewUs * 1e-6;
spec.ref_start_delay_us = delayUs;
spec.ref_start_delay_s = delayUs * 1e-6;
spec.Lambda_area = common.lambdaArea;
spec.Lambda_vec = common.lambdaArea * ones(1, 4);
spec.Ton_trim_vec = zeros(1, 4);
spec.Varea_bias = common.vAreaBias;
spec.Ri_area = common.riArea;
end

function out = runDelayedSlewCase(model, spec, common)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    "StopTime", num2str(common.stopTime, "%.15g"), ...
    "MaxStep", char(common.maxStep), ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on");
in = in.setVariable("Tss", common.fastTss);
in = in.setVariable("Iload_initial", spec.base_load_A);
in = in.setVariable("Iload_final", spec.load_A);
in = in.setVariable("t_load_step", common.tStep);
in = in.setVariable("Rload", 1e6);
in = in.setVariable("Iout", spec.base_load_A);
in = in.setVariable("Iph", spec.Iph);
in = in.setVariable("Iph_ref_ts", makeDelayedIphRefTimeseries(spec, common));
in = in.setVariable("Lambda_area", spec.Lambda_area);
in = in.setVariable("Lambda_m2", 0);
for phase = 1:4
    in = in.setVariable("Lambda" + phase, spec.Lambda_vec(phase));
    in = in.setVariable("Ton_trim" + phase, spec.Ton_trim_vec(phase));
end
in = in.setVariable("Varea_bias", spec.Varea_bias);
in = in.setVariable("Ri_area", spec.Ri_area);
in = in.setVariable("Iqcot_enable", 0);
in = in.setVariable("Kiqcot", 0);
out = sim(in);
end

function ts = makeDelayedIphRefTimeseries(spec, common)
slew = max(spec.ref_slew_s, common.fastTss);
start = common.tStep + max(spec.ref_start_delay_s, 0);
finish = start + slew;
if spec.ref_start_delay_s <= 0
    t = [0; common.tStep; finish; common.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
else
    t = [0; common.tStep; start; finish; common.stopTime];
    y = [spec.Iph_initial; spec.Iph_initial; spec.Iph_initial; spec.Iph_final; spec.Iph_final];
end
ts = timeseries(y, t);
ts.Name = "Iph_ref_ts";
end

function metrics = preStepMetrics(logs, common, loadA)
steadyStart = common.tStep - common.preSteadyWindow;
metrics = steadyMetrics(logs, steadyStart, common.tStep, loadA);
end

function metrics = steadyMetrics(logs, steadyStart, steadyEnd, loadA)
metrics = struct();
metrics.vout = windowValues(logs, "vout", steadyStart, steadyEnd);
metrics.vout_mean_V = mean(metrics.vout);
metrics.il_mean_A = zeros(1, 4);
for phase = 1:4
    il = windowValues(logs, "il" + phase, steadyStart, steadyEnd);
    metrics.il_mean_A(phase) = mean(il);
end
metrics.il_total_mean_A = sum(metrics.il_mean_A);
metrics.load_error_A = metrics.il_total_mean_A - loadA;
end

function metrics = transientMetrics(logs, spec, common, baseMetrics)
voutSeries = logs.get("vout").Values;
timeAbs = voutSeries.Time;
vout = squeeze(double(voutSeries.Data));
maskPost = timeAbs >= common.tStep;
time = timeAbs(maskPost) - common.tStep;
vout = vout(maskPost);

metrics = struct();
metrics.vout_initial_V = baseMetrics.vout_mean_V;
metrics.vout_peak_V = max(vout);
metrics.vout_min_V = min(vout);
metrics.overshoot_mV = 1e3 * (metrics.vout_peak_V - common.voRef);
metrics.undershoot_mV = 1e3 * (common.voRef - metrics.vout_min_V);
metrics.t_peak_us = 1e6 * time(find(vout == metrics.vout_peak_V, 1, "first"));
metrics.settle_time_us = settleTimeUs(time, vout, common.voRef, 2e-3);

allEdgesAbs = allGateEdges(logs, common.tStep);
allEdges = allEdgesAbs - common.tStep;
metrics.first_gate_edge_us = NaN;
metrics.max_gate_gap_us = NaN;
metrics.skip_count_est = NaN;
if ~isempty(allEdges)
    metrics.first_gate_edge_us = 1e6 * allEdges(1);
    gaps = diff(allEdges);
    if ~isempty(gaps)
        metrics.max_gate_gap_us = 1e6 * max(gaps);
        metrics.skip_count_est = max(0, round(max(gaps) / common.expectedSlot) - 1);
    else
        metrics.skip_count_est = max(0, round(allEdges(1) / common.expectedSlot) - 1);
    end
end

steadyStart = common.stopTime - common.postSteadyWindow;
metrics.final = steadyMetrics(logs, steadyStart, common.stopTime, spec.load_A);
metrics.final_vout_error_mV = 1e3 * (metrics.final.vout_mean_V - common.voRef);
metrics.il_phase_imbalance_A = max(metrics.final.il_mean_A) - min(metrics.final.il_mean_A);
metrics.il_m2_projection_A = dot(metrics.final.il_mean_A - mean(metrics.final.il_mean_A), [1 -1 1 -1]) / 4;
metrics.phase_spacing = phaseSpacingMetrics(logs, steadyStart);

metrics.base_score = abs(metrics.final_vout_error_mV) + metrics.undershoot_mV ...
    + 0.02 * metrics.phase_spacing.std_ns + 2.0 * metrics.skip_count_est;
metrics.score_settle005 = metrics.base_score + 0.05 * metrics.settle_time_us;
metrics.score_settle010 = metrics.base_score + 0.10 * metrics.settle_time_us;
end

function row = rowFromMetrics(planRow, spec, m)
row = table( ...
    true, "", string(planRow.policy), string(planRow.policy_kind), ...
    planRow.objective_alpha_settle, planRow.target_load_A, spec.ref_slew_us, ...
    planRow.tau_ai_us, planRow.delay_events, spec.ref_start_delay_us, ...
    m.vout_initial_V, m.vout_peak_V, m.vout_min_V, m.overshoot_mV, m.undershoot_mV, ...
    m.t_peak_us, m.settle_time_us, m.first_gate_edge_us, m.max_gate_gap_us, m.skip_count_est, ...
    m.final_vout_error_mV, ...
    m.final.il_mean_A(1), m.final.il_mean_A(2), m.final.il_mean_A(3), m.final.il_mean_A(4), ...
    m.final.il_total_mean_A, m.final.load_error_A, m.il_phase_imbalance_A, m.il_m2_projection_A, ...
    m.phase_spacing.mean_ns, m.phase_spacing.std_ns, m.phase_spacing.sequence_error_fraction, ...
    m.base_score, m.score_settle005, m.score_settle010, ...
    'VariableNames', resultVariableNames());
end

function row = failureRow(planRow, spec, message)
row = table( ...
    false, string(message), string(planRow.policy), string(planRow.policy_kind), ...
    planRow.objective_alpha_settle, planRow.target_load_A, spec.ref_slew_us, ...
    planRow.tau_ai_us, planRow.delay_events, spec.ref_start_delay_us, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN, ...
    'VariableNames', resultVariableNames());
end

function message = compactErrorReport(ME)
message = string(getReport(ME, "extended", "hyperlinks", "off"));
message = regexprep(message, "\s+", " ");
message = extractBefore(message + " ", min(strlength(message) + 1, 1800));
message = strtrim(message);
end

function names = resultVariableNames()
names = {'success','error_message','policy','policy_kind','objective_alpha_settle', ...
    'target_load_A','selected_ref_slew_us','tau_ai_us','delay_events','ref_start_delay_us', ...
    'vout_initial_V','vout_peak_V','vout_min_V','overshoot_mV','undershoot_mV', ...
    't_peak_us','settle_time_us','first_gate_edge_us','max_gate_gap_us','skip_count_est', ...
    'final_vout_error_mV', ...
    'final_il1_mean_A','final_il2_mean_A','final_il3_mean_A','final_il4_mean_A', ...
    'final_il_total_mean_A','final_load_error_A','final_il_phase_imbalance_A','final_il_m2_projection_A', ...
    'final_phase_spacing_mean_ns','final_phase_spacing_std_ns','final_phase_sequence_error_fraction', ...
    'base_score','score_settle005','score_settle010'};
end

function values = windowValues(logs, signalName, startTime, endTime)
series = logs.get(char(signalName)).Values;
mask = series.Time >= startTime & series.Time <= endTime;
values = squeeze(double(series.Data(mask)));
end

function tSettle = settleTimeUs(time, signal, ref, band)
tSettle = NaN;
outside = abs(signal - ref) > band;
if ~any(outside)
    tSettle = 0;
    return;
end
lastOutside = find(outside, 1, "last");
if lastOutside < numel(time)
    tSettle = 1e6 * time(lastOutside + 1);
end
end

function allTimes = allGateEdges(logs, startTime)
allTimes = [];
for phase = 1:4
    allTimes = [allTimes; edgeTimes(logs, "qh" + phase, startTime)]; %#ok<AGROW>
end
allTimes = sort(allTimes);
end

function times = edgeTimes(logs, signalName, startTime)
series = logs.get(char(signalName)).Values;
mask = series.Time >= startTime;
time = series.Time(mask);
values = squeeze(double(series.Data(mask)));
times = time(find(diff(values > 0.5) > 0) + 1);
end

function spacing = phaseSpacingMetrics(logs, steadyStart)
allTimes = [];
allPhases = [];
for phase = 1:4
    t = edgeTimes(logs, "qh" + phase, steadyStart);
    allTimes = [allTimes; t(:)]; %#ok<AGROW>
    allPhases = [allPhases; phase * ones(numel(t), 1)]; %#ok<AGROW>
end
[allTimes, order] = sort(allTimes);
allPhases = allPhases(order);
spacing = struct("mean_ns", NaN, "std_ns", NaN, "sequence_error_fraction", NaN);
if numel(allTimes) < 6
    return;
end
dt = diff(allTimes);
spacing.mean_ns = 1e9 * mean(dt);
spacing.std_ns = 1e9 * std(dt);
expectedNext = mod(allPhases(1:end-1), 4) + 1;
spacing.sequence_error_fraction = mean(allPhases(2:end) ~= expectedNext);
end

function instrumentSignals(model)
signalSpecs = {
    "33",  1, "vout";
    "219", 1, "trigger";
    "78",  1, "qh1";
    "99",  1, "qh2";
    "120", 1, "qh3";
    "141", 1, "qh4";
};
for k = 1:size(signalSpecs, 1)
    blockPath = Simulink.ID.getFullName(model + ":" + signalSpecs{k, 1});
    instrumentBlockPort(blockPath, signalSpecs{k, 2}, signalSpecs{k, 3});
end
for phase = 1:4
    instrumentBlockPort(model + "/IL_Measurement" + phase, 1, "il" + phase);
end
end

function instrumentBlockPort(blockPath, portNumber, signalName)
ports = get_param(blockPath, "PortHandles");
portHandle = ports.Outport(portNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function policyEval = summarizePolicies(rows)
valid = rows(rows.success, :);
policyEval = table();
if isempty(valid)
    return;
end
policies = unique(valid.policy, "stable");
for k = 1:numel(policies)
    r = valid(valid.policy == policies(k), :);
    policyEval = [policyEval; table( ... %#ok<AGROW>
        policies(k), ...
        mean(r.undershoot_mV), max(r.undershoot_mV), mean(abs(r.final_vout_error_mV)), ...
        mean(r.skip_count_est), mean(r.settle_time_us, "omitnan"), ...
        mean(r.final_phase_spacing_std_ns, "omitnan"), ...
        mean(r.base_score, "omitnan"), mean(r.score_settle005, "omitnan"), ...
        mean(r.score_settle010, "omitnan"), ...
        'VariableNames', {'policy','mean_undershoot_mV','max_undershoot_mV', ...
        'mean_abs_final_vout_error_mV','mean_skip_count','mean_settle_time_us', ...
        'mean_phase_spacing_std_ns','mean_base_score','mean_score_settle005','mean_score_settle010'})];
end
end

function writeDryRunReport(plan, planPath, outputRoot)
reportPath = fullfile(outputRoot, "iqcot_table_supervisor_validation_matlab_dryrun.md");
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# MATLAB table-supervisor validation dry run\n\n");
fprintf(fid, "Plan CSV: `%s`.\n\n", strrep(planPath, "\", "/"));
fprintf(fid, "Rows: `%d`.\n\n", height(plan));
fprintf(fid, "This dry run did not execute Simulink. It verified the policy matrix and the delayed reference-start values that will be injected through `Iph_ref_ts`.\n\n");
fprintf(fid, "Boundary: delayed `Iph_ref_ts` emulates parameter commit latency. It is not a neural-network-in-the-loop or hardware result.\n");
end

function writeSwitchingReport(~, policyEval, resultPath, policyPath, reportPath)
fid = fopen(reportPath, "w", "n", "UTF-8");
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, "# Delayed table-supervisor switching validation\n\n");
fprintf(fid, "- Result CSV: `%s`\n", strrep(resultPath, "\", "/"));
fprintf(fid, "- Policy CSV: `%s`\n\n", strrep(policyPath, "\", "/"));
fprintf(fid, "This run uses the derived Simulink model and delayed `Iph_ref_ts` profiles. AI remains a supervisory parameter scheduler and does not replace the IQCOT inner loop.\n\n");
if isempty(policyEval)
    fprintf(fid, "No successful policy rows were produced.\n");
    return;
end
fprintf(fid, "## Policy summary\n\n");
fprintf(fid, "| Policy | mean base | mean score 0.05 | mean score 0.10 | mean undershoot mV | mean settle us |\n");
fprintf(fid, "|---|---:|---:|---:|---:|---:|\n");
for k = 1:height(policyEval)
    fprintf(fid, "| `%s` | %.3f | %.3f | %.3f | %.3f | %.3f |\n", ...
        policyEval.policy(k), policyEval.mean_base_score(k), ...
        policyEval.mean_score_settle005(k), policyEval.mean_score_settle010(k), ...
        policyEval.mean_undershoot_mV(k), policyEval.mean_settle_time_us(k));
end
fprintf(fid, "\nBoundary: these are switching-level delayed-reference results, not hardware validation and not proof of global T_slew optimality.\n");
end

function makePolicyPlot(policyEval, figurePath)
if isempty(policyEval)
    return;
end
fig = figure(Visible="off", Position=[100 100 1100 560]);
cleanup = onCleanup(@() close(fig));
x = categorical(policyEval.policy);
x = reordercats(x, cellstr(policyEval.policy));
bar(x, [policyEval.mean_base_score policyEval.mean_score_settle005 policyEval.mean_score_settle010]);
grid on;
ylabel("Mean score");
legend("base", "score+0.05Tsettle", "score+0.10Tsettle", Location="best");
title("Delayed table-supervisor switching validation");
xtickangle(25);
exportgraphics(fig, figurePath, Resolution=180);
end
