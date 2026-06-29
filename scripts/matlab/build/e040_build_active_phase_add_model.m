function modelFile = e040_build_active_phase_add_model(variant)
%e040_build_active_phase_add_model Build minimal E040-A active-phase add models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "D0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
modelName = e040ModelName(variant);
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
addCurrentSenseLogs(modelName);
addE040ActivePhaseSupervisor(modelName);
addRequiredAuditLogs(modelName);
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.52e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E040_%s_DERIVED_MODEL=%s\n", variant, modelFile);
end

function modelName = e040ModelName(variant)
if variant == "D0"
    modelName = "E040A_D0_fixed2_iqcot_20260629";
elseif variant == "D1"
    modelName = "E040A_D1_immed_add_iqcot_20260629";
elseif variant == "D2"
    modelName = "E040A_D2_guard_add_as_iqcot_20260629";
elseif variant == "D3"
    modelName = "E040A_D3_guard_add_conf_iqcot_20260629";
else
    error("Unknown E040-A variant: %s", variant);
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
set_param(ccsPath, "Name", "E040_Load_Current_Source");
ccsPath = modelName + "/E040_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E040_LoadCurrentStep";
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

function addCurrentSenseLogs(modelName)
for phase = 1:4
    fromBlock = modelName + "/E040_IL_Sense_From" + phase;
    gainBlock = modelName + "/E040_IL_Sense_Gain_Block" + phase;
    termBlock = modelName + "/E040_IL_Sense_Term" + phase;
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(gainBlock);
    deleteBlockIfExists(fromBlock);

    y = 980 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "IL" + phase, "Position", [3520 y 3580 y+28]);
    add_block("simulink/Math Operations/Gain", gainBlock, ...
        "Gain", "E040_IL_Sense_Gain" + phase, ...
        "Position", [3640 y 3725 y+28]);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [3820 y+2 3840 y+26]);
    connectBlocks(fromBlock, 1, gainBlock, 1);
    connectBlocks(gainBlock, 1, termBlock, 1);
    markBlockOutport(gainBlock, 1, "IL_sense" + phase);
end
end

function addE040ActivePhaseSupervisor(modelName)
ctrlBlock = modelName + "/E040_A_ActivePhaseSupervisor";
deleteBlockIfExists(ctrlBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", ctrlBlock, ...
    "Position", [3920 980 4300 1270]);
setE040SupervisorScript(ctrlBlock);

clockBlock = modelName + "/E040_A_Supervisor_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3540 1340 3580 1370]);

constNames = [
    "E040_LoadStep_Time", "E040_Variant_Mode", "E040_I_Add_High", "E040_Dwell_Time", ...
    "E040_New_Phase_Ramp_Time", "E040_Vref", "E040_Severe_Overshoot_Band", ...
    "E040_Current_Limit_A", "E040_TonDiff_Enable", "E040_K_T", ...
    "E040_Fallback_K_T", "E040_T_Trim_Max", "E040_Current_Deadband", ...
    "E040_Sense_Confidence", "E040_Calibration_Enable", ...
    "E040_V_Error_Budget", "E040_V_Error_Hard_Limit", "E040_Min_Scale"];
for idx = 1:numel(constNames)
    block = modelName + "/" + constNames(idx);
    ensureConstantBlock(block, constNames(idx), [3520 1110+34*idx 3760 1132+34*idx]);
end

rawReqTags = ["tr1", "tr2", "tr3", "tr4"];
oldReqFromBlocks = ["From23", "From24", "From25", "From26"];
for phase = 1:4
    rawReqFrom = modelName + "/E040_Raw_REQ_From" + phase;
    deleteBlockIfExists(rawReqFrom);
    add_block("simulink/Signal Routing/From", rawReqFrom, ...
        "GotoTag", rawReqTags(phase), "Position", [3540 900+45*phase 3600 928+45*phase]);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 1);
    deleteBlockIfExists(modelName + "/" + oldReqFromBlocks(phase));
    connectBlocks(rawReqFrom, 1, ctrlBlock, phase);
    connectBlocks(ctrlBlock, phase, modelName + "/COT_Cell_1Phase" + phase, 1);
    markBlockOutport(rawReqFrom, 1, "REQ_raw" + phase);
    markBlockOutport(ctrlBlock, phase, "REQ" + phase);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, ctrlBlock, 4 + phase);
    connectBlocks(ctrlBlock, 4 + phase, modelName + "/COT_Cell_1Phase" + phase, 3);
    markBlockOutport(modelName + "/IQCOT_Ton_Adapter", phase, "Ton_raw" + phase);
    markBlockOutport(ctrlBlock, 4 + phase, "Ton_cmd" + phase);

    connectBlocks(modelName + "/E040_IL_Sense_Gain_Block" + phase, 1, ctrlBlock, 8 + phase);
end

connectBlocks(modelName + "/Voltage Measurement", 1, ctrlBlock, 13);
connectBlocks(modelName + "/E040_LoadCurrentStep", 1, ctrlBlock, 14);
connectBlocks(clockBlock, 1, ctrlBlock, 15);
for idx = 1:numel(constNames)
    connectBlocks(modelName + "/" + constNames(idx), 1, ctrlBlock, 15 + idx);
end

addSupervisorLog(modelName, ctrlBlock, 9, "active_phase_set", [4380 980 4400 1000]);
addSupervisorLog(modelName, ctrlBlock, 10, "N_active", [4380 1010 4400 1030]);
addSupervisorLog(modelName, ctrlBlock, 11, "phase_add_request", [4380 1040 4400 1060]);
addSupervisorLog(modelName, ctrlBlock, 12, "phase_add_accept", [4380 1070 4400 1090]);
addSupervisorLog(modelName, ctrlBlock, 13, "phase_add_reject", [4380 1100 4400 1120]);
addSupervisorLog(modelName, ctrlBlock, 14, "phase_shed_request", [4380 1130 4400 1150]);
addSupervisorLog(modelName, ctrlBlock, 15, "phase_shed_accept", [4380 1160 4400 1180]);
addSupervisorLog(modelName, ctrlBlock, 16, "new_phase_ramp_state", [4380 1190 4400 1210]);
addSupervisorLog(modelName, ctrlBlock, 17, "residual_current_i", [4380 1220 4400 1240]);
addSupervisorLog(modelName, ctrlBlock, 18, "dwell_timer", [4380 1250 4400 1270]);
addSupervisorLog(modelName, ctrlBlock, 19, "protect_state", [4380 1280 4400 1300]);
addSupervisorLog(modelName, ctrlBlock, 20, "reentry_state", [4380 1310 4400 1330]);
addSupervisorLog(modelName, ctrlBlock, 21, "balance_recovery_state", [4380 1340 4400 1360]);
addSupervisorLog(modelName, ctrlBlock, 22, "sense_confidence", [4380 1370 4400 1390]);
addSupervisorLog(modelName, ctrlBlock, 23, "calibration_enable", [4380 1400 4400 1420]);
addSupervisorLog(modelName, ctrlBlock, 24, "a_S_mode", [4380 1430 4400 1450]);
addSupervisorLog(modelName, ctrlBlock, 25, "fallback_count", [4380 1460 4400 1480]);
addSupervisorLog(modelName, ctrlBlock, 26, "guard_clamp_count", [4380 1490 4400 1510]);
for phase = 1:4
    addSupervisorLog(modelName, ctrlBlock, 26 + phase, "Ton_trim" + phase, ...
        [4380 1520+30*phase 4400 1540+30*phase]);
end
end

function addRequiredAuditLogs(modelName)
markBlockOutport(modelName + "/Voltage Measurement", 1, "Vout");
markBlockOutport(modelName + "/PhaseScheduler_4Phase", 5, "phase_idx");
for phase = 1:4
    markBlockOutport(modelName + "/IL_Measurement" + phase, 1, "IL" + phase);
    markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 1, "QH" + phase);
    markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 2, "QL" + phase);
end
addFromLog(modelName, "Lambda_i", "Lambda_i", [3720 620 3795 648]);
addFromLog(modelName, "A_iqcot", "area_int_i", [3720 665 3795 693]);
end

function addFromLog(modelName, tagName, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E040_Log_" + safeName + "_From";
termBlock = modelName + "/E040_Log_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(fromBlock);
add_block("simulink/Signal Routing/From", fromBlock, ...
    "GotoTag", tagName, "Position", position);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
connectBlocks(fromBlock, 1, termBlock, 1);
markBlockOutport(fromBlock, 1, signalName);
end

function addSupervisorLog(modelName, srcBlock, outPort, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
termBlock = modelName + "/E040_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
add_block("simulink/Sinks/Terminator", termBlock, "Position", position);
connectBlocks(srcBlock, outPort, termBlock, 1);
markBlockOutport(srcBlock, outPort, signalName);
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E040_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 735 3760 765]);

for phase = 1:4
    estimator = modelName + "/E040_TonActual" + phase;
    termBlock = modelName + "/E040_TonActual" + phase + "_Term";
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estimator);

    y = 740 + 70 * phase;
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

function setE040SupervisorScript(blockPath)
script = [
"function [req1o,req2o,req3o,req4o,ton1o,ton2o,ton3o,ton4o,active_phase_set,N_active,phase_add_request,phase_add_accept,phase_add_reject,phase_shed_request,phase_shed_accept,new_phase_ramp_state,residual_current_i,dwell_timer,protect_state,reentry_state,balance_recovery_state,sense_confidence_o,calibration_enable_o,a_S_mode,fallback_count_o,guard_clamp_count_o,trim1,trim2,trim3,trim4] = e040_supervisor(req1,req2,req3,req4,ton1,ton2,ton3,ton4,il1,il2,il3,il4,vout,iload,t,t_step,variant_mode,I_add_high,dwell_time,new_phase_ramp_time,Vref,severe_overshoot_band,current_limit_A,TonDiff_enable,K_T,fallback_K_T,T_trim_max,current_deadband,sense_confidence,calibration_enable,Verr_budget,Verr_hard,min_scale)"
"%#codegen"
"req = [req1, req2, req3, req4] > 0.5;"
"tons = [ton1, ton2, ton3, ton4];"
"ils = [il1, il2, il3, il4];"
"phase_shed_request = 0.0;"
"phase_shed_accept = 0.0;"
"protect_state = 0.0;"
"phase_add_request = double((variant_mode > 0.5) && (iload > I_add_high));"
"if phase_add_request > 0.5"
"    dwell_timer = max(0.0, t - t_step);"
"else"
"    dwell_timer = 0.0;"
"end"
"overshoot_ok = vout <= (Vref + severe_overshoot_band);"
"current_ok = (current_limit_A <= 0.0) || (max(abs(ils)) <= current_limit_A);"
"dwell_ok = dwell_timer >= dwell_time;"
"if variant_mode < 0.5"
"    allow_add = false;"
"    add_time = t_step;"
"elseif variant_mode < 1.5"
"    allow_add = phase_add_request > 0.5;"
"    add_time = t_step;"
"else"
"    allow_add = (phase_add_request > 0.5) && overshoot_ok && current_ok && dwell_ok;"
"    add_time = t_step + dwell_time;"
"end"
"phase_add_accept = double(allow_add);"
"phase_add_reject = double((phase_add_request > 0.5) && ~allow_add);"
"if phase_add_accept > 0.5"
"    if new_phase_ramp_time > 0.0"
"        ramp = min(max((t - add_time) / new_phase_ramp_time, 0.0), 1.0);"
"    else"
"        ramp = 1.0;"
"    end"
"else"
"    ramp = 0.0;"
"end"
"new_phase_ramp_state = ramp;"
"active3 = double(phase_add_accept > 0.5);"
"active4 = active3;"
"active_phase_set = [1.0, 1.0, active3, active4];"
"N_active = 2.0 + active3 + active4;"
"if phase_add_accept > 0.5"
"    req_out = [req(1), req(2), req(3) && active3 > 0.5, req(4) && active4 > 0.5];"
"else"
"    req_out = [req(1) || req(3), req(2) || req(4), false, false];"
"end"
"ton_base = [ton1, ton2, ton3 * ramp, ton4 * ramp];"
"reentry_state = double(phase_add_accept > 0.5 && ramp >= 0.999);"
"balance_enable = (TonDiff_enable > 0.5) && (reentry_state > 0.5);"
"a_S_mode = 0.0;"
"fallback_flag = 0.0;"
"guard_clamp = 0.0;"
"trim = [0.0, 0.0, 0.0, 0.0];"
"if balance_enable"
"    active_mask = active_phase_set > 0.5;"
"    low_confidence = (variant_mode >= 2.5) && (sense_confidence < 0.5);"
"    K_eff = K_T;"
"    if low_confidence"
"        K_eff = fallback_K_T;"
"        fallback_flag = 1.0;"
"        a_S_mode = 1.0;"
"    elseif calibration_enable > 0.5"
"        a_S_mode = 2.0;"
"    else"
"        K_eff = fallback_K_T;"
"        fallback_flag = 1.0;"
"        a_S_mode = 1.0;"
"    end"
"    denom = max(sum(double(active_mask)), 1.0);"
"    avg_i = sum(ils .* double(active_mask)) / denom;"
"    err = (ils - avg_i) .* double(active_mask);"
"    raw = -K_eff .* err;"
"    if max(abs(err)) < current_deadband"
"        raw = [0.0, 0.0, 0.0, 0.0];"
"    end"
"    trim = min(max(raw, -T_trim_max), T_trim_max);"
"    trim_mean = sum(trim .* double(active_mask)) / denom;"
"    trim = (trim - trim_mean) .* double(active_mask);"
"    max_trim = max(abs(trim));"
"    if T_trim_max <= 0.0"
"        trim = [0.0, 0.0, 0.0, 0.0];"
"    elseif max_trim > T_trim_max"
"        trim = trim .* (T_trim_max / max_trim);"
"        guard_clamp = 1.0;"
"    end"
"    ev = abs(vout - Vref);"
"    denom_v = max(Verr_hard - Verr_budget, 1.0e-9);"
"    voltage_scale = 1.0 - max(ev - Verr_budget, 0.0) / denom_v;"
"    voltage_scale = min(max(voltage_scale, min_scale), 1.0);"
"    if voltage_scale < 0.999"
"        guard_clamp = 1.0;"
"    end"
"    trim = voltage_scale .* trim;"
"end"
"ton_out = max([0.0, 0.0, 0.0, 0.0], ton_base + trim);"
"req1o = req_out(1); req2o = req_out(2); req3o = req_out(3); req4o = req_out(4);"
"ton1o = ton_out(1); ton2o = ton_out(2); ton3o = ton_out(3); ton4o = ton_out(4);"
"residual_current_i = ils .* (1.0 - active_phase_set);"
"balance_recovery_state = double(balance_enable);"
"sense_confidence_o = sense_confidence;"
"calibration_enable_o = calibration_enable;"
"fallback_count_o = fallback_flag;"
"guard_clamp_count_o = guard_clamp;"
"trim1 = trim(1); trim2 = trim(2); trim3 = trim(3); trim4 = trim(4);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["req1", "req2", "req3", "req4", "ton1", "ton2", "ton3", "ton4", ...
    "il1", "il2", "il3", "il4", "vout", "iload", "t", "t_step", "variant_mode", ...
    "I_add_high", "dwell_time", "new_phase_ramp_time", "Vref", ...
    "severe_overshoot_band", "current_limit_A", "TonDiff_enable", "K_T", ...
    "fallback_K_T", "T_trim_max", "current_deadband", "sense_confidence", ...
    "calibration_enable", "Verr_budget", "Verr_hard", "min_scale", ...
    "req1o", "req2o", "req3o", "req4o", "ton1o", "ton2o", "ton3o", ...
    "ton4o", "active_phase_set", "N_active", "phase_add_request", ...
    "phase_add_accept", "phase_add_reject", "phase_shed_request", ...
    "phase_shed_accept", "new_phase_ramp_state", "residual_current_i", ...
    "dwell_timer", "protect_state", "reentry_state", "balance_recovery_state", ...
    "sense_confidence_o", "calibration_enable_o", "a_S_mode", ...
    "fallback_count_o", "guard_clamp_count_o", "trim1", "trim2", "trim3", "trim4"], ...
    ["req1", "req2", "req3", "req4", "req1o", "req2o", "req3o", "req4o"]);
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
if contains(string(blockPath), "ActivePhaseSupervisor")
    try
        chart.UpdateMethod = "INHERITED";
    catch
    end
    try
        set_param(blockPath, "SampleTime", "-1");
    catch
    end
    try
        set_param(blockPath, "SystemSampleTime", "-1");
    catch
    end
else
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
