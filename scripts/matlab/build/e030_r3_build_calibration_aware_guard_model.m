function modelFile = e030_r3_build_calibration_aware_guard_model(variant)
%e030_r3_build_calibration_aware_guard_model Build E030-R3 current-sense mismatch models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "R3-C0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
modelName = r3ModelName(variant);
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
addCurrentSenseMismatchLogs(modelName);
markTonCommandLogs(modelName);

if variant ~= "R3-C0"
    addR3TonProjectionController(modelName);
end

addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.64e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E030_%s_DERIVED_MODEL=%s\n", erase(variant, "-"), modelFile);
end

function modelName = r3ModelName(variant)
if variant == "R3-C0"
    modelName = "E030_R3_C0_cal_guard_from_ideal_iqcot_20260629";
elseif variant == "R3-C1low"
    modelName = "E030_R3_C1low_cal_guard_from_ideal_iqcot_20260629";
elseif variant == "R3-C4a_conf"
    modelName = "E030_R3_C4a_conf_cal_guard_from_ideal_iqcot_20260629";
elseif variant == "R3-C4a_cal"
    modelName = "E030_R3_C4a_cal_from_ideal_iqcot_20260629";
elseif variant == "R3-C4c_cal"
    modelName = "E030_R3_C4c_cal_from_ideal_iqcot_20260629";
else
    error("Unknown E030-R3 variant: %s", variant);
end
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
set_param(ccsPath, "Name", "E030_R3_Load_Current_Source");
ccsPath = modelName + "/E030_R3_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E030_R3_LoadCurrentStep";
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
constBlock = modelName + "/E030_R3_ActivePhaseSet";
termBlock = modelName + "/E030_R3_ActivePhaseSet_Term";
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

function addCurrentSenseMismatchLogs(modelName)
for phase = 1:4
    fromBlock = modelName + "/E030_R3_IL_Sense_From" + phase;
    gainBlock = modelName + "/E030_R3_IL_Sense_Gain_Block" + phase;
    estBlock = modelName + "/E030_R3_IL_Est_Gain_Block" + phase;
    termBlock = modelName + "/E030_R3_IL_Est_Term" + phase;
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estBlock);
    deleteBlockIfExists(gainBlock);
    deleteBlockIfExists(fromBlock);

    y = 980 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "IL" + phase, "Position", [3520 y 3580 y+28]);
    add_block("simulink/Math Operations/Gain", gainBlock, ...
        "Gain", "E030_R3_IL_Sense_Gain" + phase, ...
        "Position", [3640 y 3725 y+28]);
    add_block("simulink/Math Operations/Gain", estBlock, ...
        "Gain", "1 / E030_R3_IL_Ghat" + phase, ...
        "Position", [3770 y 3865 y+28]);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [3940 y+2 3960 y+26]);
    connectBlocks(fromBlock, 1, gainBlock, 1);
    connectBlocks(gainBlock, 1, estBlock, 1);
    connectBlocks(estBlock, 1, termBlock, 1);
    markBlockOutport(gainBlock, 1, "IL_sense" + phase);
    markBlockOutport(estBlock, 1, "IL_est" + phase);
end
end

function addFromLog(modelName, tagName, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E030_R3_Log_" + safeName + "_From";
termBlock = modelName + "/E030_R3_Log_" + safeName + "_Term";
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

function addR3TonProjectionController(modelName)
ctrlBlock = modelName + "/E030_R3_TonProjection_Controller";
deleteBlockIfExists(ctrlBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", ctrlBlock, ...
    "Position", [3920 1010 4240 1195]);
setR3TonProjectionScript(ctrlBlock);

clockBlock = modelName + "/E030_R3_TonProjection_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3600 1180 3640 1210]);

consts = [
    "E030_R3_TonDiff_Enable", "E030_R3_K_T", "E030_R3_T_Trim_Max", ...
    "E030_R3_Current_Deadband", "E030_R3_Projection_Mode", "E030_R3_Vref", ...
    "E030_R3_V_Error_Budget", "E030_R3_V_Error_Hard_Limit", ...
    "E030_R3_Min_Scale", "E030_R3_Ripple_Budget", ...
    "E030_R3_Ripple_Hard_Limit", "E030_R3_Ripple_Window", ...
    "E030_R3_Fallback_K_T", "E030_R3_Calibration_Enable", ...
    "E030_R3_Current_Sense_Mismatch_Flag", "E030_R3_Sense_Confidence", ...
    "E030_R3_IL_Ghat1", "E030_R3_IL_Ghat2", ...
    "E030_R3_IL_Ghat3", "E030_R3_IL_Ghat4"];
for idx = 1:numel(consts)
    block = modelName + "/" + consts(idx);
    ensureConstantBlock(block, consts(idx), [3560 960+36*idx 3770 982+36*idx]);
end

for phase = 1:4
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, ctrlBlock, phase);
    connectBlocks(modelName + "/E030_R3_IL_Sense_Gain_Block" + phase, 1, ctrlBlock, 4 + phase);
end
connectBlocks(modelName + "/Voltage Measurement", 1, ctrlBlock, 9);
connectBlocks(clockBlock, 1, ctrlBlock, 10);
for idx = 1:numel(consts)
    connectBlocks(modelName + "/" + consts(idx), 1, ctrlBlock, 10 + idx);
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
addTermAndLog(modelName, ctrlBlock, 11, "ton_projection_scale", [4310 1280 4330 1300]);
addTermAndLog(modelName, ctrlBlock, 12, "ton_voltage_scale", [4310 1320 4330 1340]);
addTermAndLog(modelName, ctrlBlock, 13, "ton_ripple_scale", [4310 1360 4330 1380]);
end

function addTermAndLog(modelName, srcBlock, outPort, signalName, position)
termBlock = modelName + "/E030_R3_" + signalName + "_Term";
deleteBlockIfExists(termBlock);
add_block("simulink/Sinks/Terminator", termBlock, "Position", position);
connectBlocks(srcBlock, outPort, termBlock, 1);
markBlockOutport(srcBlock, outPort, signalName);
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E030_R3_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 620 3760 650]);

for phase = 1:4
    estimator = modelName + "/E030_R3_TonActual" + phase;
    termBlock = modelName + "/E030_R3_TonActual" + phase + "_Term";
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

function setR3TonProjectionScript(blockPath)
script = [
"function [ton1o,ton2o,ton3o,ton4o,trim1,trim2,trim3,trim4,clamp_flag,fallback_flag,scale,voltage_scale,ripple_scale] = R3_ton_projector(ton1,ton2,ton3,ton4,il1,il2,il3,il4,vout,t,enable,K_T,T_trim_max,deadband,mode,Vref,Verr_budget,Verr_hard,min_scale,ripple_budget,ripple_hard,ripple_window,fallback_K_T,calibration_enable,current_sense_mismatch_flag,sense_confidence,ghat1,ghat2,ghat3,ghat4)"
"%#codegen"
"persistent vmin vmax t_reset"
"if isempty(vmin)"
"    vmin = vout;"
"    vmax = vout;"
"    t_reset = t;"
"end"
"if ripple_window <= 0.0 || t < t_reset || (t - t_reset) >= ripple_window"
"    vmin = vout;"
"    vmax = vout;"
"    t_reset = t;"
"else"
"    vmin = min(vmin, vout);"
"    vmax = max(vmax, vout);"
"end"
"tons = [ton1, ton2, ton3, ton4];"
"ils_sensed = [il1, il2, il3, il4];"
"ghat = [ghat1, ghat2, ghat3, ghat4];"
"ghat = max(abs(ghat), 1.0e-9);"
"if calibration_enable > 0.5"
"    ils = ils_sensed ./ ghat;"
"else"
"    ils = ils_sensed;"
"end"
"low_confidence = (sense_confidence < 0.5) || (calibration_enable <= 0.5 && current_sense_mismatch_flag > 0.5);"
"K_eff = K_T;"
"if low_confidence"
"    K_eff = fallback_K_T;"
"end"
"avg = mean(ils);"
"err = ils - avg;"
"raw = -K_eff .* err;"
"if max(abs(err)) < deadband"
"    raw = zeros(1,4);"
"end"
"trim = min(max(raw, -T_trim_max), T_trim_max);"
"trim = trim - mean(trim);"
"max_trim = max(abs(trim));"
"if T_trim_max <= 0.0"
"    trim = zeros(1,4);"
"elseif max_trim > T_trim_max"
"    trim = trim .* (T_trim_max / max_trim);"
"end"
"voltage_scale = 1.0;"
"ripple_scale = 1.0;"
"if enable > 0.5"
"    if mode >= 2.5 && mode < 3.5"
"        ev = abs(vout - Vref);"
"        denom_v = max(Verr_hard - Verr_budget, 1.0e-9);"
"        voltage_scale = 1.0 - max(ev - Verr_budget, 0.0) / denom_v;"
"        voltage_scale = min(max(voltage_scale, min_scale), 1.0);"
"    elseif mode >= 3.5 && mode < 4.5"
"        ripple_est = max(vmax - vmin, 0.0);"
"        denom_r = max(ripple_hard - ripple_budget, 1.0e-9);"
"        ripple_scale = 1.0 - max(ripple_est - ripple_budget, 0.0) / denom_r;"
"        ripple_scale = min(max(ripple_scale, min_scale), 1.0);"
"    end"
"    scale = min(voltage_scale, ripple_scale);"
"    trim = scale .* trim;"
"    clamp_flag = double(any(abs(raw) > T_trim_max) || max_trim > T_trim_max || scale < 0.999);"
"    fallback_flag = double(low_confidence || scale <= (min_scale + 1.0e-9));"
"else"
"    trim = zeros(1,4);"
"    scale = 1.0;"
"    clamp_flag = 0.0;"
"    fallback_flag = 0.0;"
"end"
"outs = max(0.0, tons + trim);"
"ton1o = outs(1); ton2o = outs(2); ton3o = outs(3); ton4o = outs(4);"
"trim1 = trim(1); trim2 = trim(2); trim3 = trim(3); trim4 = trim(4);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton1", "ton2", "ton3", "ton4", "il1", "il2", "il3", "il4", ...
    "vout", "t", "enable", "K_T", "T_trim_max", "deadband", "mode", ...
    "Vref", "Verr_budget", "Verr_hard", "min_scale", "ripple_budget", ...
    "ripple_hard", "ripple_window", "fallback_K_T", "calibration_enable", ...
    "current_sense_mismatch_flag", "sense_confidence", "ghat1", "ghat2", ...
    "ghat3", "ghat4", "ton1o", "ton2o", "ton3o", "ton4o", ...
    "trim1", "trim2", "trim3", "trim4", "clamp_flag", "fallback_flag", ...
    "scale", "voltage_scale", "ripple_scale"], strings(0, 1));
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
setChartScriptAndTypes(blockPath, script, ["qh", "t", "Ton_actual"], "qh");
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
