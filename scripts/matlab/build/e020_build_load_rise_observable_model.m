function modelFile = e020_build_load_rise_observable_model(variant)
%E020_BUILD_LOAD_RISE_OBSERVABLE_MODEL Build E020 load-rise derived models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "B0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
if variant == "B0"
    modelName = "E020_B0_load_rise_observable_from_ideal_iqcot_20260629";
elseif variant == "B1"
    modelName = "E020_B1_fast_request_from_ideal_iqcot_20260629";
elseif variant == "B2"
    modelName = "E020_B2_ton_boost_from_ideal_iqcot_20260629";
elseif variant == "B3"
    modelName = "E020_B3_fast_request_ton_boost_from_ideal_iqcot_20260629";
else
    error("Unknown E020 variant: %s", variant);
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
if variant == "B1" || variant == "B3"
    addFastRequest(modelName);
end
if variant == "B2" || variant == "B3"
    addTonBoost(modelName);
end
markTonCommandLogs(modelName);
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.54e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E020_%s_DERIVED_MODEL=%s\n", variant, modelFile);
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
set_param(ccsPath, "Name", "E020_Load_Current_Source");
ccsPath = modelName + "/E020_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E020_LoadCurrentStep";
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
constBlock = modelName + "/E020_ActivePhaseSet";
termBlock = modelName + "/E020_ActivePhaseSet_Term";
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
fromBlock = modelName + "/E020_Log_" + safeName + "_From";
termBlock = modelName + "/E020_Log_" + safeName + "_Term";
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

function addFastRequest(modelName)
clockBlock = modelName + "/E020_FastRequest_Clock";
enableBlock = modelName + "/E020_FastRequest_Enable";
tstepBlock = modelName + "/E020_FastRequest_LoadStepTime";
windowBlock = modelName + "/E020_FastRequest_Window";
periodBlock = modelName + "/E020_FastRequest_Period";
pulseWidthBlock = modelName + "/E020_FastRequest_PulseWidth";
voutBlock = modelName + "/E020_FastRequest_Vout";
vrefBlock = modelName + "/E020_FastRequest_Vref";
bandBlock = modelName + "/E020_FastRequest_UndershootBand";
limitBlock = modelName + "/E020_FastRequest_CurrentLimit";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(periodBlock);
deleteBlockIfExists(pulseWidthBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(limitBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [-1110 2210 -1070 2240]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E020_FastRequest_Enable", "Position", [-1110 2260 -990 2285]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [-1110 2305 -990 2330]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E020_FastRequest_Window", "Position", [-1110 2350 -990 2375]);
add_block("simulink/Sources/Constant", periodBlock, ...
    "Value", "E020_FastRequest_Period", "Position", [-1110 2395 -990 2420]);
add_block("simulink/Sources/Constant", pulseWidthBlock, ...
    "Value", "E020_FastRequest_PulseWidth", "Position", [-1110 2440 -990 2465]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [-1110 2485 -1050 2513]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E020_Vref", "Position", [-1110 2530 -990 2555]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E020_Undershoot_Band", "Position", [-1110 2575 -990 2600]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E020_CurrentLimit_Guard", "Position", [-1110 2620 -990 2645]);

ilBlocks = strings(1, 4);
for phase = 1:4
    ilBlocks(phase) = modelName + "/E020_FastRequest_IL" + phase;
    deleteBlockIfExists(ilBlocks(phase));
    y = 2665 + 45 * (phase - 1);
    add_block("simulink/Signal Routing/From", ilBlocks(phase), ...
        "GotoTag", "IL" + phase, "Position", [-1110 y -1050 y+28]);
end

fastBlock = modelName + "/E020_FastRequest";
activeTerm = modelName + "/E020_FastRequest_Active_Term";
countTerm = modelName + "/E020_FastRequest_Count_Term";
deleteBlockIfExists(activeTerm);
deleteBlockIfExists(countTerm);
deleteBlockIfExists(fastBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", fastBlock, ...
    "Position", [-760 2100 -560 2205]);
setFastRequestScript(fastBlock);
add_block("simulink/Sinks/Terminator", activeTerm, ...
    "Position", [-430 2150 -410 2175]);
add_block("simulink/Sinks/Terminator", countTerm, ...
    "Position", [-430 2190 -410 2215]);

detectBlock = findDetectRiseBlock(modelName);
gotoTr = modelName + "/Goto17";
set_param(gotoTr, "Position", [-500 2105 -460 2135]);
disconnectInport(gotoTr, 1);
connectBlocks(detectBlock, 1, fastBlock, 1);
connectBlocks(clockBlock, 1, fastBlock, 2);
connectBlocks(tstepBlock, 1, fastBlock, 3);
connectBlocks(windowBlock, 1, fastBlock, 4);
connectBlocks(periodBlock, 1, fastBlock, 5);
connectBlocks(pulseWidthBlock, 1, fastBlock, 6);
connectBlocks(enableBlock, 1, fastBlock, 7);
connectBlocks(voutBlock, 1, fastBlock, 8);
connectBlocks(vrefBlock, 1, fastBlock, 9);
connectBlocks(bandBlock, 1, fastBlock, 10);
connectBlocks(limitBlock, 1, fastBlock, 11);
for phase = 1:4
    connectBlocks(ilBlocks(phase), 1, fastBlock, 11 + phase);
end
connectBlocks(fastBlock, 1, gotoTr, 1);
connectBlocks(fastBlock, 2, activeTerm, 1);
connectBlocks(fastBlock, 3, countTerm, 1);
markBlockOutport(fastBlock, 1, "tr_fast_projected");
markBlockOutport(fastBlock, 2, "fast_request_active");
markBlockOutport(fastBlock, 3, "fast_request_count");
end

function addTonBoost(modelName)
clockBlock = modelName + "/E020_TonBoost_Clock";
enableBlock = modelName + "/E020_TonBoost_Enable";
tstepBlock = modelName + "/E020_TonBoost_LoadStepTime";
windowBlock = modelName + "/E020_TonBoost_Window";
tmaxBlock = modelName + "/E020_TonBoost_Max";
decayBlock = modelName + "/E020_TonBoost_DecayRate";
voutBlock = modelName + "/E020_TonBoost_Vout";
vrefBlock = modelName + "/E020_TonBoost_Vref";
bandBlock = modelName + "/E020_TonBoost_UndershootBand";
limitBlock = modelName + "/E020_TonBoost_CurrentLimit";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(tmaxBlock);
deleteBlockIfExists(decayBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(limitBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [3680 900 3720 930]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E020_TonBoost_Enable", "Position", [3680 950 3795 975]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [3680 995 3795 1020]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E020_TonBoost_Window", "Position", [3680 1040 3795 1065]);
add_block("simulink/Sources/Constant", tmaxBlock, ...
    "Value", "Tton_boost_max", "Position", [3680 1085 3795 1110]);
add_block("simulink/Sources/Constant", decayBlock, ...
    "Value", "E020_Boost_Decay_Rate", "Position", [3680 1130 3795 1155]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [3680 1175 3735 1203]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E020_Vref", "Position", [3680 1220 3795 1245]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E020_Undershoot_Band", "Position", [3680 1265 3795 1290]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E020_CurrentLimit_Guard", "Position", [3680 1310 3795 1335]);

    for phase = 1:4
        ilBlock = modelName + "/E020_TonBoost_IL" + phase;
        boostBlock = modelName + "/E020_TonBoost" + phase;
        activeTerm = modelName + "/E020_TonBoost" + phase + "_Active_Term";
        deleteBlockIfExists(activeTerm);
        deleteBlockIfExists(boostBlock);
        deleteBlockIfExists(ilBlock);

        y = 870 + 105 * phase;
        add_block("simulink/Signal Routing/From", ilBlock, ...
            "GotoTag", "IL" + phase, "Position", [3830 y+85 3885 y+113]);
        add_block("simulink/User-Defined Functions/MATLAB Function", boostBlock, ...
            "Position", [3920 y 4150 y+80]);
        setTonBoostScript(boostBlock);
        add_block("simulink/Sinks/Terminator", activeTerm, ...
            "Position", [4265 y+45 4285 y+70]);

        disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
        connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, boostBlock, 1);
        connectBlocks(clockBlock, 1, boostBlock, 2);
        connectBlocks(tstepBlock, 1, boostBlock, 3);
        connectBlocks(windowBlock, 1, boostBlock, 4);
        connectBlocks(tmaxBlock, 1, boostBlock, 5);
        connectBlocks(decayBlock, 1, boostBlock, 6);
        connectBlocks(enableBlock, 1, boostBlock, 7);
        connectBlocks(voutBlock, 1, boostBlock, 8);
        connectBlocks(vrefBlock, 1, boostBlock, 9);
        connectBlocks(bandBlock, 1, boostBlock, 10);
        connectBlocks(ilBlock, 1, boostBlock, 11);
        connectBlocks(limitBlock, 1, boostBlock, 12);
        connectBlocks(boostBlock, 1, modelName + "/COT_Cell_1Phase" + phase, 3);
        connectBlocks(boostBlock, 2, activeTerm, 1);
        markBlockOutport(boostBlock, 1, "Ton_cmd_boost" + phase);
        markBlockOutport(boostBlock, 2, "ton_boost_active" + phase);
    end
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E020_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 620 3760 650]);

for phase = 1:4
    estimator = modelName + "/E020_TonActual" + phase;
    termBlock = modelName + "/E020_TonActual" + phase + "_Term";
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

function setFastRequestScript(blockPath)
script = [
"function [tr_out,fast_active,fast_count] = fast_request(tr_in,t,t_step,t_window,period,pulse_width,enable,vout,vref,band,current_limit,il1,il2,il3,il4)"
"%#codegen"
"base_tr = logical(tr_in);"
"age = t - t_step;"
"in_window = (enable > 0.5) && (age >= 0.0) && (age <= t_window);"
"deficit = vout <= (vref - band);"
"iph_peak = max(max(abs(il1), abs(il2)), max(abs(il3), abs(il4)));"
"guard_ok = (current_limit <= 0.0) || (iph_peak <= current_limit);"
"pulse = false;"
"if in_window && deficit && guard_ok && (period > 0.0) && (pulse_width > 0.0)"
"    slot = age - floor(age / period) * period;"
"    pulse = slot <= min(pulse_width, period);"
"end"
"tr_out = base_tr || pulse;"
"fast_active = double(pulse && ~base_tr);"
"fast_count = fast_active;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["tr_in", "t", "t_step", "t_window", "period", "pulse_width", "enable", ...
    "vout", "vref", "band", "current_limit", "il1", "il2", "il3", "il4", ...
    "tr_out", "fast_active", "fast_count"], ...
    ["tr_in", "tr_out"]);
end

function setTonBoostScript(blockPath)
script = [
"function [ton_out,boost_active] = ton_boost(ton_in,t,t_step,t_window,t_max,decay_rate,enable,vout,vref,band,il_i,current_limit)"
"%#codegen"
"age = t - t_step;"
"in_window = (enable > 0.5) && (age >= 0.0) && (age <= t_window);"
"deficit = vout <= (vref - band);"
"guard_ok = (current_limit <= 0.0) || (abs(il_i) <= current_limit);"
"active = in_window && deficit && guard_ok && (t_max > ton_in);"
"if active"
"    decay = exp(-max(decay_rate, 0.0) * max(age, 0.0));"
"    target = ton_in + (t_max - ton_in) * decay;"
"    ton_out = min(max(target, ton_in), t_max);"
"else"
"    ton_out = ton_in;"
"end"
"boost_active = double(active);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton_in", "t", "t_step", "t_window", "t_max", "decay_rate", "enable", ...
    "vout", "vref", "band", "il_i", "current_limit", "ton_out", "boost_active"], ...
    strings(0, 1));
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
setChartDataTypes(chart, dataNames, booleanNames);
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

function blockPath = findDetectRiseBlock(modelName)
matches = find_system(modelName, "SearchDepth", 1, ...
    "ReferenceBlock", "simulink/Logic and Bit Operations/Detect Rise Positive");
if isempty(matches)
    matches = find_system(modelName, "SearchDepth", 1, ...
        "Name", sprintf("Detect Rise\nPositive"));
end
if isempty(matches)
    error("Detect Rise Positive block not found.");
end
blockPath = string(matches{1});
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

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end
