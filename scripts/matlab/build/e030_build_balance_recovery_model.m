function modelFile = e030_build_balance_recovery_model(variant)
%E030_BUILD_BALANCE_RECOVERY_MODEL Build E030 DCR-mismatch balance models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "C0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
if variant == "C0"
    modelName = "E030_C0_dcr_obs_iqcot_20260629";
elseif variant == "C1"
    modelName = "E030_C1_tondiff_iqcot_20260629";
elseif variant == "C2"
    modelName = "E030_C2_lambdadiff_iqcot_20260629";
elseif variant == "C3"
    modelName = "E030_C3_ton_lambda_iqcot_20260629";
elseif variant == "C4"
    modelName = "E030_C4_pisiek_proj_iqcot_20260629";
else
    error("Unknown E030 variant: %s", variant);
end
modelFile = fullfile(derivedRoot, modelName + ".slx");
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");

if ~isfile(baselineModel)
    error("Baseline model not found: %s", baselineModel);
end
if ~exist(derivedRoot, "dir")
    mkdir(derivedRoot);
end
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
copyfile(baselineModel, modelFile, "f");

load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

replaceStaticLoadWithCurrentSource(modelName);
addActivePhaseSetLog(modelName);
addRequiredAuditLogs(modelName);
markTonCommandLogs(modelName);

if variant == "C2" || variant == "C3" || variant == "C4"
    addLambdaDiffController(modelName);
end
if variant == "C1" || variant == "C3" || variant == "C4"
    addTonDiffController(modelName);
end

addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.64e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E030_%s_DERIVED_MODEL=%s\n", variant, modelFile);
end

function replaceStaticLoadWithCurrentSource(modelName)
load_system("spsControlledCurrentSourceLib");
oldLoad = modelName + "/Series RLC Branch8";
if isempty(find_system(modelName, "SearchDepth", 1, "Name", "Series RLC Branch8"))
    error("Expected static load block not found: %s", oldLoad);
end
oldPosition = get_param(oldLoad, "Position");
replace_block(modelName, "SearchDepth", 1, "Name", "Series RLC Branch8", ...
    "spsControlledCurrentSourceLib/Controlled Current Source", "noprompt");
ccs = find_system(modelName, "SearchDepth", 1, "MaskType", "Controlled Current Source");
if isempty(ccs)
    error("Controlled Current Source replacement failed.");
end
ccsPath = string(ccs{1});
set_param(ccsPath, "Name", "E030_Load_Current_Source");
ccsPath = modelName + "/E030_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E030_LoadCurrentStep";
deleteBlockIfExists(stepBlock);
stepPosition = [oldPosition(1)-260 oldPosition(2)+30 oldPosition(1)-170 oldPosition(2)+60];
add_block("simulink/Sources/Step", stepBlock, ...
    "Position", stepPosition, ...
    "Time", "t_load_step", ...
    "Before", "Iload_initial", ...
    "After", "Iload_final", ...
    "SampleTime", "0");
connectBlocks(stepBlock, 1, ccsPath, 1);
markBlockOutport(stepBlock, 1, "Iload");
end

function addActivePhaseSetLog(modelName)
constBlock = modelName + "/E030_ActivePhaseSet";
termBlock = modelName + "/E030_ActivePhaseSet_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(constBlock);
add_block("simulink/Sources/Constant", constBlock, ...
    "Value", "[1 1 1 1]", "Position", [3720 520 3820 550]);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [3900 522 3920 548]);
connectBlocks(constBlock, 1, termBlock, 1);
markBlockOutport(constBlock, 1, "active_phase_set");
end

function addRequiredAuditLogs(modelName)
markBlockOutport(modelName + "/PhaseScheduler_4Phase", 5, "phase_idx");
addFromLog(modelName, "tr1", "REQ1", [3720 700 3780 728]);
addFromLog(modelName, "tr2", "REQ2", [3720 745 3780 773]);
addFromLog(modelName, "tr3", "REQ3", [3720 790 3780 818]);
addFromLog(modelName, "tr4", "REQ4", [3720 835 3780 863]);
addFromLog(modelName, "Lambda_i", "Lambda_i", [3720 880 3795 908]);
addFromLog(modelName, "A_iqcot", "area_int_i", [3720 925 3795 953]);
end

function addFromLog(modelName, tagName, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E030_Log_" + safeName + "_From";
termBlock = modelName + "/E030_Log_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(fromBlock);
add_block("simulink/Signal Routing/From", fromBlock, ...
    "GotoTag", tagName, "Position", position);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
connectBlocks(fromBlock, 1, termBlock, 1);
markBlockOutport(fromBlock, 1, signalName);
end

function markTonCommandLogs(modelName)
for phase = 1:4
    markBlockOutport(modelName + "/IQCOT_Ton_Adapter", phase, "Ton_cmd" + phase);
end
end

function addTonDiffController(modelName)
ctrlBlock = modelName + "/E030_TonDiff_Controller";
deleteBlockIfExists(ctrlBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", ctrlBlock, ...
    "Position", [3920 1010 4200 1160]);
setTonDiffScript(ctrlBlock);

consts = [
    "E030_TonDiff_Enable", "E030_K_T", "E030_T_Trim_Max", ...
    "E030_Current_Deadband", "E030_PIS_Project_Enable"];
for idx = 1:numel(consts)
    block = modelName + "/" + consts(idx);
    ensureConstantBlock(block, consts(idx), [3600 955+45*idx 3745 980+45*idx]);
end

for phase = 1:4
    ilBlock = modelName + "/E030_TonDiff_IL" + phase;
    deleteBlockIfExists(ilBlock);
    add_block("simulink/Signal Routing/From", ilBlock, ...
        "GotoTag", "IL" + phase, "Position", [3600 745+45*phase 3660 773+45*phase]);
end

for phase = 1:4
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, ctrlBlock, phase);
    connectBlocks(modelName + "/E030_TonDiff_IL" + phase, 1, ctrlBlock, 4 + phase);
end
for idx = 1:numel(consts)
    connectBlocks(modelName + "/" + consts(idx), 1, ctrlBlock, 8 + idx);
end

for phase = 1:4
    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(ctrlBlock, phase, modelName + "/COT_Cell_1Phase" + phase, 3);
    markBlockOutport(ctrlBlock, phase, "Ton_cmd_balanced" + phase);
end

for phase = 1:4
    addTermAndLog(modelName, ctrlBlock, 4 + phase, "Ton_trim" + phase, ...
        [4310 1030+35*phase 4330 1050+35*phase]);
end
addTermAndLog(modelName, ctrlBlock, 9, "ton_trim_clamp_count", [4310 1200 4330 1220]);
addTermAndLog(modelName, ctrlBlock, 10, "ton_fallback_count", [4310 1240 4330 1260]);
end

function addLambdaDiffController(modelName)
ctrlBlock = modelName + "/E030_LambdaDiff_Controller";
deleteBlockIfExists(ctrlBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", ctrlBlock, ...
    "Position", [2050 1010 2360 1170]);
setLambdaDiffScript(ctrlBlock);

clockBlock = modelName + "/E030_LambdaDiff_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [1670 1225 1710 1255]);

consts = [
    "E030_LambdaDiff_Enable", "E030_Nominal_Phase_Spacing", ...
    "E030_Phase_Spacing_Tolerance", "E030_Lambda_Trim_Max", ...
    "E030_K_Lambda", "E030_PIS_Project_Enable"];
for idx = 1:numel(consts)
    block = modelName + "/" + consts(idx);
    ensureConstantBlock(block, consts(idx), [1660 1260+45*idx 1845 1285+45*idx]);
end

fromBlocks = ["From23", "From24", "From25", "From26"];
for phase = 1:4
    connectBlocks(modelName + "/" + fromBlocks(phase), 1, ctrlBlock, phase);
end
connectBlocks(clockBlock, 1, ctrlBlock, 5);
for idx = 1:numel(consts)
    connectBlocks(modelName + "/" + consts(idx), 1, ctrlBlock, 5 + idx);
end

for phase = 1:4
    addTermAndLog(modelName, ctrlBlock, phase, "REQ_projected" + phase, ...
        [2470 900+30*phase 2490 920+30*phase]);
end

for phase = 1:4
    addTermAndLog(modelName, ctrlBlock, 4 + phase, "Lambda_trim" + phase, ...
        [2470 1030+35*phase 2490 1050+35*phase]);
end
addTermAndLog(modelName, ctrlBlock, 9, "lambda_trim_clamp_count", [2470 1200 2490 1220]);
addTermAndLog(modelName, ctrlBlock, 10, "lambda_fallback_count", [2470 1240 2490 1260]);
end

function addTermAndLog(modelName, srcBlock, outPort, signalName, position)
termBlock = modelName + "/E030_" + signalName + "_Term";
deleteBlockIfExists(termBlock);
add_block("simulink/Sinks/Terminator", termBlock, "Position", position);
connectBlocks(srcBlock, outPort, termBlock, 1);
markBlockOutport(srcBlock, outPort, signalName);
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E030_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 620 3760 650]);

for phase = 1:4
    estimator = modelName + "/E030_TonActual" + phase;
    termBlock = modelName + "/E030_TonActual" + phase + "_Term";
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estimator);

    y = 610 + 70 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", estimator, ...
        "Position", [3840 y 4020 y+50]);
    setTonActualScript(estimator);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [4140 y+12 4160 y+38]);

    connectBlocks(modelName + "/GateDriver_1Phase" + phase, 1, estimator, 1);
    connectBlocks(clockBlock, 1, estimator, 2);
    connectBlocks(estimator, 1, termBlock, 1);
    markBlockOutport(estimator, 1, "Ton_actual" + phase);
end
end

function setTonDiffScript(blockPath)
script = [
"function [ton1o,ton2o,ton3o,ton4o,trim1,trim2,trim3,trim4,clamp_count,fallback_count] = ton_diff(ton1,ton2,ton3,ton4,il1,il2,il3,il4,enable,K_T,T_trim_max,deadband,projected)"
"%#codegen"
"tons = [ton1, ton2, ton3, ton4];"
"ils = [il1, il2, il3, il4];"
"avg = mean(ils);"
"err = ils - avg;"
"raw = -K_T .* err;"
"if enable <= 0.5"
"    trim = zeros(1,4);"
"    clamp_count = 0.0;"
"    fallback_count = 0.0;"
"else"
"    if projected > 0.5 && max(abs(err)) < deadband"
"        raw = zeros(1,4);"
"    end"
"    trim = min(max(raw, -T_trim_max), T_trim_max);"
"    clamp_count = double(any(abs(raw) > T_trim_max));"
"    trim = trim - mean(trim);"
"    fallback_count = 0.0;"
"end"
"outs = max(0.0, tons + trim);"
"ton1o = outs(1); ton2o = outs(2); ton3o = outs(3); ton4o = outs(4);"
"trim1 = trim(1); trim2 = trim(2); trim3 = trim(3); trim4 = trim(4);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton1", "ton2", "ton3", "ton4", "il1", "il2", "il3", "il4", ...
    "enable", "K_T", "T_trim_max", "deadband", "projected", ...
    "ton1o", "ton2o", "ton3o", "ton4o", "trim1", "trim2", "trim3", "trim4", ...
    "clamp_count", "fallback_count"], strings(0, 1));
end

function setLambdaDiffScript(blockPath)
script = [
"function [tr1o,tr2o,tr3o,tr4o,lam1,lam2,lam3,lam4,clamp_count,fallback_count] = lambda_diff(tr1,tr2,tr3,tr4,t,enable,nominal_spacing,tolerance,lambda_max,K_lambda,projected)"
"%#codegen"
"persistent last_any"
"if isempty(last_any)"
"    last_any = -1.0;"
"end"
"tr = [logical(tr1), logical(tr2), logical(tr3), logical(tr4)];"
"out = tr;"
"trim = zeros(1,4);"
"clamp_count = 0.0;"
"fallback_count = 0.0;"
"if enable > 0.5"
"    for idx = 1:4"
"        if tr(idx)"
"            if last_any < 0.0"
"                spacing = nominal_spacing;"
"            else"
"                spacing = t - last_any;"
"            end"
"            err = spacing - nominal_spacing;"
"            raw = -K_lambda * err;"
"            trim(idx) = min(max(raw, -lambda_max), lambda_max);"
"            if abs(raw) > lambda_max || abs(err) > tolerance"
"                clamp_count = clamp_count + 1.0;"
"            end"
"            last_any = t;"
"        end"
"    end"
"    trim = trim - mean(trim);"
"    if projected > 0.5 && clamp_count > 0.5"
"        trim = zeros(1,4);"
"        fallback_count = 1.0;"
"    end"
"else"
"    for idx = 1:4"
"        if tr(idx)"
"            last_any = t;"
"        end"
"    end"
"end"
"tr1o = out(1); tr2o = out(2); tr3o = out(3); tr4o = out(4);"
"lam1 = trim(1); lam2 = trim(2); lam3 = trim(3); lam4 = trim(4);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["tr1", "tr2", "tr3", "tr4", "t", "enable", "nominal_spacing", ...
    "tolerance", "lambda_max", "K_lambda", "projected", ...
    "tr1o", "tr2o", "tr3o", "tr4o", "lam1", "lam2", "lam3", "lam4", ...
    "clamp_count", "fallback_count"], ...
    ["tr1", "tr2", "tr3", "tr4", "tr1o", "tr2o", "tr3o", "tr4o"]);
end

function setTonActualScript(blockPath)
script = [
"function Ton_actual = ton_actual_estimator(qh, t)"
"%#codegen"
"persistent q_prev t_rise last_width"
"if isempty(q_prev)"
"    q_prev = 0.0;"
"end"
"if isempty(t_rise)"
"    t_rise = 0.0;"
"end"
"if isempty(last_width)"
"    last_width = 0.0;"
"end"
"is_high = double(qh > 0.5);"
"if is_high > 0.5 && q_prev <= 0.5"
"    t_rise = t;"
"elseif is_high <= 0.5 && q_prev > 0.5"
"    last_width = max(0.0, t - t_rise);"
"end"
"Ton_actual = last_width;"
"q_prev = is_high;"
];

rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
try
    chart.UpdateMethod = "DISCRETE";
    chart.SampleTime = "Ts_ctrl";
catch
    try
        set_param(blockPath, "SampleTime", "Ts_ctrl");
    catch
    end
end
try
    set_param(blockPath, "SystemSampleTime", "Ts_ctrl");
catch
end
setChartDataTypes(chart, ["qh", "t", "Ton_actual"], "qh");
end

function setChartScriptAndTypes(blockPath, script, dataNames, booleanNames)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
setChartDiscreteSampleTime(blockPath, chart);
setChartDataTypes(chart, dataNames, booleanNames);
end

function setChartDiscreteSampleTime(blockPath, chart)
try
    chart.UpdateMethod = "DISCRETE";
    chart.SampleTime = "Ts_ctrl";
catch
    try
        set_param(blockPath, "SampleTime", "Ts_ctrl");
    catch
    end
end
try
    set_param(blockPath, "SystemSampleTime", "Ts_ctrl");
catch
end
end

function setChartDataTypes(chart, dataNames, booleanNames)
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        if any(dataNames(idx) == booleanNames)
            data.Props.Type.Primitive = "boolean";
        else
            data.Props.Type.Primitive = "double";
        end
        data.Props.Array.Size = "1";
    end
end
end

function connectBlocks(srcBlock, srcPort, dstBlock, dstPort)
srcPorts = get_param(srcBlock, "PortHandles");
dstPorts = get_param(dstBlock, "PortHandles");
disconnectInport(dstBlock, dstPort);
srcParent = get_param(srcBlock, "Parent");
dstParent = get_param(dstBlock, "Parent");
if ~strcmp(srcParent, dstParent)
    error("Cannot connect blocks in different parent systems: %s -> %s", srcBlock, dstBlock);
end
add_line(srcParent, srcPorts.Outport(srcPort), dstPorts.Inport(dstPort), "autorouting", "on");
end

function disconnectInport(blockPath, portNumber)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(portNumber), "Line");
if lineHandle ~= -1
    delete_line(lineHandle);
end
end

function markBlockOutport(blockPath, portNumber, signalName)
ports = get_param(blockPath, "PortHandles");
portHandle = ports.Outport(portNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function ensureConstantBlock(blockPath, value, position)
try
    get_param(blockPath, "Handle");
    set_param(blockPath, "Value", value);
catch
    add_block("simulink/Sources/Constant", blockPath, ...
        "Value", value, "Position", position);
end
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end
