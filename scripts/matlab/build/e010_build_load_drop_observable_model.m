function modelFile = e010_build_load_drop_observable_model(variant)
%E010_BUILD_LOAD_DROP_OBSERVABLE_MODEL Build A0 observable load-drop model.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "A0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
if variant == "A0"
    modelName = "E010_A0_load_drop_observable_from_ideal_iqcot_20260628";
elseif variant == "A1"
    modelName = "E010_A1_ton_trunc_from_ideal_iqcot_20260628";
elseif variant == "A2"
    modelName = "E010_A2_ton_trunc_pulse_inhibit_from_ideal_iqcot_20260628";
elseif variant == "A3"
    modelName = "E010_A3_guarded_reentry_from_ideal_iqcot_20260628";
elseif variant == "A4"
    modelName = "E010_A4_ai_table_aO_from_ideal_iqcot_20260628";
else
    error("Unknown E010 variant: %s", variant);
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
if variant == "A1" || variant == "A2" || variant == "A3" || variant == "A4"
    addTonTruncation(modelName);
end
if variant == "A2" || variant == "A3" || variant == "A4"
    addPulseInhibit(modelName);
end
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.54e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E010_%s_DERIVED_MODEL=%s\n", variant, modelFile);
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
set_param(ccsPath, "Name", "E010_Load_Current_Source");
ccsPath = modelName + "/E010_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E010_LoadCurrentStep";
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
constBlock = modelName + "/E010_ActivePhaseSet";
termBlock = modelName + "/E010_ActivePhaseSet_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(constBlock);
add_block("simulink/Sources/Constant", constBlock, ...
    "Value", "[1 1 1 1]", "Position", [3720 520 3820 550]);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [3900 522 3920 548]);
connectBlocks(constBlock, 1, termBlock, 1);
markBlockOutport(constBlock, 1, "active_phase_set");
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E010_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 620 3760 650]);

for phase = 1:4
    estimator = modelName + "/E010_TonActual" + phase;
    termBlock = modelName + "/E010_TonActual" + phase + "_Term";
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

function addTonTruncation(modelName)
clockBlock = modelName + "/E010_TonTrunc_Clock";
enableBlock = modelName + "/E010_TonTrunc_Enable";
tstepBlock = modelName + "/E010_TonTrunc_LoadStepTime";
windowBlock = modelName + "/E010_TonTrunc_Window";
tminBlock = modelName + "/E010_TonTrunc_Min";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(tminBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [3680 900 3720 930]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010_TonTrunc_Enable", "Position", [3680 950 3775 975]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [3680 995 3775 1020]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "Tton_trunc_window", "Position", [3680 1040 3775 1065]);
add_block("simulink/Sources/Constant", tminBlock, ...
    "Value", "Tton_trunc_min", "Position", [3680 1085 3775 1110]);

for phase = 1:4
    truncBlock = modelName + "/E010_TonTrunc" + phase;
    activeTerm = modelName + "/E010_TonTrunc" + phase + "_Active_Term";
    deleteBlockIfExists(activeTerm);
    deleteBlockIfExists(truncBlock);

    y = 880 + 80 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", truncBlock, ...
        "Position", [3920 y 4120 y+58]);
    setTonTruncScript(truncBlock);
    add_block("simulink/Sinks/Terminator", activeTerm, ...
        "Position", [4245 y+33 4265 y+55]);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, truncBlock, 1);
    connectBlocks(clockBlock, 1, truncBlock, 2);
    connectBlocks(tstepBlock, 1, truncBlock, 3);
    connectBlocks(windowBlock, 1, truncBlock, 4);
    connectBlocks(tminBlock, 1, truncBlock, 5);
    connectBlocks(enableBlock, 1, truncBlock, 6);
    connectBlocks(truncBlock, 1, modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(truncBlock, 2, activeTerm, 1);
    markBlockOutport(truncBlock, 1, "Ton_cmd_trunc" + phase);
    markBlockOutport(truncBlock, 2, "ton_trunc_active" + phase);
end
end

function addPulseInhibit(modelName)
clockBlock = modelName + "/E010_PulseInhibit_Clock";
enableBlock = modelName + "/E010_PulseInhibit_Enable";
tstepBlock = modelName + "/E010_PulseInhibit_LoadStepTime";
windowBlock = modelName + "/E010_PulseInhibit_Time";
countBlock = modelName + "/E010_PulseInhibit_Count";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(countBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [1650 900 1690 930]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010_PulseInhibit_Enable", "Position", [1650 950 1765 975]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [1650 995 1765 1020]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E010_PulseInhibit_Time", "Position", [1650 1040 1765 1065]);
add_block("simulink/Sources/Constant", countBlock, ...
    "Value", "E010_PulseInhibit_Count", "Position", [1650 1085 1765 1110]);
voutBlock = modelName + "/E010_PulseInhibit_Vout";
vrefBlock = modelName + "/E010_PulseInhibit_Vref";
bandBlock = modelName + "/E010_PulseInhibit_ReentryBand";
guardBlock = modelName + "/E010_PulseInhibit_ReentryGuard";
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(guardBlock);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [1650 1130 1700 1158]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E010_Vref", "Position", [1650 1175 1765 1200]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E010_Reentry_Band_Down", "Position", [1650 1220 1765 1245]);
add_block("simulink/Sources/Constant", guardBlock, ...
    "Value", "E010_ReentryGuard_Enable", "Position", [1650 1265 1765 1290]);

fromBlocks = ["From23", "From24", "From25", "From26"];
for phase = 1:4
    inhibitBlock = modelName + "/E010_PulseInhibit" + phase;
    activeTerm = modelName + "/E010_PulseInhibit" + phase + "_Active_Term";
    countTerm = modelName + "/E010_PulseInhibit" + phase + "_Count_Term";
    deleteBlockIfExists(activeTerm);
    deleteBlockIfExists(countTerm);
    deleteBlockIfExists(inhibitBlock);

    y = 935 + 245 * (phase - 1);
    add_block("simulink/User-Defined Functions/MATLAB Function", inhibitBlock, ...
        "Position", [2030 y 2220 y+70]);
    setPulseInhibitScript(inhibitBlock);
    add_block("simulink/Sinks/Terminator", activeTerm, ...
        "Position", [2350 y+35 2370 y+57]);
    add_block("simulink/Sinks/Terminator", countTerm, ...
        "Position", [2350 y+65 2370 y+87]);

    cotBlock = modelName + "/COT_Cell_1Phase" + phase;
    disconnectInport(cotBlock, 1);
    connectBlocks(modelName + "/" + fromBlocks(phase), 1, inhibitBlock, 1);
    connectBlocks(clockBlock, 1, inhibitBlock, 2);
    connectBlocks(tstepBlock, 1, inhibitBlock, 3);
    connectBlocks(windowBlock, 1, inhibitBlock, 4);
    connectBlocks(countBlock, 1, inhibitBlock, 5);
    connectBlocks(enableBlock, 1, inhibitBlock, 6);
    connectBlocks(voutBlock, 1, inhibitBlock, 7);
    connectBlocks(vrefBlock, 1, inhibitBlock, 8);
    connectBlocks(bandBlock, 1, inhibitBlock, 9);
    connectBlocks(guardBlock, 1, inhibitBlock, 10);
    connectBlocks(inhibitBlock, 1, cotBlock, 1);
    connectBlocks(inhibitBlock, 2, activeTerm, 1);
    connectBlocks(inhibitBlock, 3, countTerm, 1);
    markBlockOutport(inhibitBlock, 1, "tr_after_inhibit" + phase);
    markBlockOutport(inhibitBlock, 2, "pulse_inhibit_active" + phase);
    markBlockOutport(inhibitBlock, 3, "pulse_inhibit_count" + phase);
end
end

function setPulseInhibitScript(blockPath)
script = [
"function [tr_out,inhibit_active,inhibit_count] = pulse_inhibit(tr_in,t,t_step,t_window,count_max,enable,vout,vref,reentry_band,guard_enable)"
"%#codegen"
"is_high = logical(tr_in);"
"in_window = (enable > 0.5) && (t >= t_step) && (t <= (t_step + t_window));"
"guard_ok = (guard_enable <= 0.5) || (vout >= (vref + reentry_band));"
"inhibit_active = is_high && in_window && (count_max > 0.0) && guard_ok;"
"if inhibit_active"
"    tr_out = false;"
"else"
"    tr_out = tr_in;"
"end"
"inhibit_count = double(inhibit_active);"
];

rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
dataNames = ["tr_in", "t", "t_step", "t_window", "count_max", "enable", ...
    "vout", "vref", "reentry_band", "guard_enable", ...
    "tr_out", "inhibit_active", "inhibit_count"];
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        if any(dataNames(idx) == ["tr_in", "tr_out", "inhibit_active"])
            data.Props.Type.Primitive = "boolean";
        else
            data.Props.Type.Primitive = "double";
        end
        data.Props.Array.Size = "1";
    end
end
end

function setTonTruncScript(blockPath)
script = [
"function [ton_out,trunc_active] = ton_trunc(ton_in,t,t_step,t_window,t_min,enable)"
"%#codegen"
"active = (enable > 0.5) && (t >= t_step) && (t <= (t_step + t_window));"
"trunc_active = double(active);"
"if active"
"    ton_out = min(ton_in, t_min);"
"else"
"    ton_out = ton_in;"
"end"
];

rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
dataNames = ["ton_in", "t", "t_step", "t_window", "t_min", "enable", "ton_out", "trunc_active"];
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        data.Props.Type.Primitive = "double";
        data.Props.Array.Size = "1";
    end
end
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
dataNames = ["qh", "t", "Ton_actual"];
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        if dataNames(idx) == "qh"
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
if srcParent ~= dstParent
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

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end
