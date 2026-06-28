function modelFile = iqcot_build_ideal_digital_iqcot_model()
%IQCOT_BUILD_IDEAL_DIGITAL_IQCOT_MODEL Build a non-destructive IQCOT copy.
% The source .slx is copied first. The copy replaces IEK_Area_Request with
% an ideal sampled IQCOT event kernel:
%   A[k+1] = max(A_lower, A[k] + Ts_ctrl * (vc - Ri*iL_selected))
%   REQ_iqcot = A[k+1] >= Lambda_i
% and resets only on the accepted global trigger.

projectRoot = "E:\Desktop\codex";
dstRoot = fullfile(projectRoot, "output", "simulink_ideal_iqcot");
if ~exist(dstRoot, "dir")
    mkdir(dstRoot);
end

srcModel = chooseSourceModel(projectRoot);
modelName = "four_phase_ideal_digital_iqcot";
modelFile = fullfile(dstRoot, modelName + ".slx");
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(dstRoot);

initPath = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
if isfile(initPath)
    evalin("base", sprintf("run('%s')", escapeForEval(initPath)));
end

load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

deleteBlockIfExists(modelName + "/IEK_Area_Request");
deleteBlockIfExists(modelName + "/Ideal_Digital_IQCOT_Request");
deleteBlockIfExists(modelName + "/IdealIQCOT_Enable_Constant");
deleteBlocksByPrefix(modelName, "IdealIQCOT_Log_");

iqcotPath = modelName + "/Ideal_Digital_IQCOT_Request";
add_block("simulink/Ports & Subsystems/Subsystem", iqcotPath, ...
    "Position", [340 1040 680 1280]);
buildIdealIQCOTSubsystem(iqcotPath);

add_block("simulink/Sources/Constant", modelName + "/IdealIQCOT_Enable_Constant", ...
    "Value", "IdealIQCOT_Enable", "Position", [170 1248 245 1278]);

connectBlocks(modelName + "/Sum", 1, iqcotPath, 1);
connectBlocks(modelName + "/IL_Measurement1", 1, iqcotPath, 2);
connectBlocks(modelName + "/IL_Measurement2", 1, iqcotPath, 3);
connectBlocks(modelName + "/IL_Measurement3", 1, iqcotPath, 4);
connectBlocks(modelName + "/IL_Measurement4", 1, iqcotPath, 5);
connectBlocks(modelName + "/PhaseScheduler_4Phase", 5, iqcotPath, 6);
connectBlocks(modelName + "/From17", 1, iqcotPath, 7);
connectBlocks(modelName + "/IdealIQCOT_Enable_Constant", 1, iqcotPath, 8);

gotoReq = modelName + "/Goto14";
disconnectInport(gotoReq, 1);
connectBlocks(iqcotPath, 1, gotoReq, 1);

logNames = ["A_iqcot", "Lambda_i", "h_iqcot", "IL_sel", "vc_ctrl"];
for idx = 1:numel(logNames)
    gotoPath = modelName + "/IdealIQCOT_Log_" + logNames(idx);
    add_block("simulink/Signal Routing/Goto", gotoPath, ...
        "GotoTag", char(logNames(idx)), ...
        "TagVisibility", "local", ...
        "Position", [760 1070 + 38 * idx 850 1092 + 38 * idx]);
    connectBlocks(iqcotPath, idx + 1, gotoPath, 1);
end

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.5e-3", ...
    "MaxStep", "max_step_cont");

instrumentSignals(modelName);
save_system(modelName, modelFile);
fprintf("IDEAL_DIGITAL_IQCOT_MODEL=%s\n", modelFile);
end

function srcModel = chooseSourceModel(projectRoot)
candidates = [
    fullfile(projectRoot, "output", "simulink_iek", "four_phase_iek_area.slx")
    fullfile(projectRoot, "four_phase_iek_area.slx")
    "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs\four_phase.slx"
    ];
for idx = 1:numel(candidates)
    if isfile(candidates(idx))
        srcModel = candidates(idx);
        fprintf("IDEAL_IQCOT_SOURCE_MODEL=%s\n", srcModel);
        return;
    end
end
error("No source model found for ideal digital IQCOT build.");
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end

function buildIdealIQCOTSubsystem(sys)
open_system(sys);
deleteBlockIfExists(sys + "/In1");
deleteBlockIfExists(sys + "/Out1");

inNames = ["e_v", "IL1", "IL2", "IL3", "IL4", "phase_idx", "tr_reset", "enable"];
for idx = 1:numel(inNames)
    y = 32 + 42 * (idx - 1);
    add_block("simulink/Ports & Subsystems/In1", sys + "/" + inNames(idx), ...
        "Port", num2str(idx), "Position", [25 y 55 y + 18]);
    xZoh = 90;
    xDtc = 165;
    srcName = inNames(idx);
    if inNames(idx) == "phase_idx" || inNames(idx) == "tr_reset"
        add_block("simulink/Discrete/Memory", sys + "/" + inNames(idx) + "_Memory", ...
            "InitialCondition", "0", "Position", [82 y-5 122 y + 23]);
        add_line(sys, inNames(idx) + "/1", inNames(idx) + "_Memory/1", "autorouting", "on");
        srcName = inNames(idx) + "_Memory";
        xZoh = 150;
        xDtc = 225;
    end
    add_block("simulink/Discrete/Zero-Order Hold", sys + "/" + inNames(idx) + "_ZOH", ...
        "SampleTime", "Ts_ctrl", "Position", [xZoh y-4 xZoh+50 y + 22]);
    add_block("simulink/Signal Attributes/Data Type Conversion", sys + "/" + inNames(idx) + "_double", ...
        "OutDataTypeStr", "double", "Position", [xDtc y-4 xDtc+50 y + 22]);
    add_line(sys, srcName + "/1", inNames(idx) + "_ZOH/1", "autorouting", "on");
    add_line(sys, inNames(idx) + "_ZOH/1", inNames(idx) + "_double/1", "autorouting", "on");
end

paramNames = ["Ts_ctrl", "Lambda0_iqcot", "Lambda_m2", "rho_cmd", ...
    "Ri_iqcot", "Kvc_iqcot", "Vc_bias_iqcot", "kappa_cmd", ...
    "A_init", "A_lower", "A_upper"];
for idx = 1:numel(paramNames)
    y = 30 + 32 * (idx - 1);
    add_block("simulink/Sources/Constant", sys + "/" + paramNames(idx), ...
        "Value", char(paramNames(idx)), "Position", [190 y 285 y + 20]);
end

core = sys + "/IQCOT_Event_Core";
add_block("simulink/User-Defined Functions/MATLAB Function", core, ...
    "Position", [380 80 610 360]);
setIQCOTCoreScript(core);

for idx = 1:numel(inNames)
    add_line(sys, inNames(idx) + "_double/1", "IQCOT_Event_Core/" + idx, "autorouting", "on");
end
for idx = 1:numel(paramNames)
    add_line(sys, paramNames(idx) + "/1", "IQCOT_Event_Core/" + (numel(inNames) + idx), ...
        "autorouting", "on");
end

outNames = ["REQ_iqcot", "A_iqcot", "Lambda_i", "h_iqcot", "IL_sel", "vc_ctrl"];
for idx = 1:numel(outNames)
    y = 95 + 42 * (idx - 1);
    add_block("simulink/Ports & Subsystems/Out1", sys + "/" + outNames(idx), ...
        "Port", num2str(idx), "Position", [705 y 735 y + 18]);
    add_line(sys, "IQCOT_Event_Core/" + idx, outNames(idx) + "/1", "autorouting", "on");
end
close_system(sys);
end

function setIQCOTCoreScript(blockPath)
script = [
"function [REQ_iqcot,A_iqcot,Lambda_i,h_iqcot,IL_sel,vc_ctrl] = IQCOT_Event_Core(e_v,IL1,IL2,IL3,IL4,phase_idx,tr_reset,enable,Ts_ctrl_in,Lambda0_in,Lambda_m2_in,rho_cmd_in,Ri_in,Kvc_in,Vc_bias_in,kappa_cmd_in,A_init_in,A_lower_in,A_upper_in)"
"%#codegen"
"REQ_iqcot = 0.0;"
"A_iqcot = 0.0;"
"Lambda_i = 0.0;"
"h_iqcot = 0.0;"
"IL_sel = 0.0;"
"vc_ctrl = 0.0;"
"persistent Astate reset_prev phase_prev"
"if isempty(Astate)"
"    Astate = double(A_init_in);"
"end"
"if isempty(reset_prev)"
"    reset_prev = 0.0;"
"end"
"if isempty(phase_prev)"
"    phase_prev = 0.0;"
"end"
"p = floor(double(phase_idx));"
"p = mod(p, 4);"
"if p == 0"
"    IL_sel = IL1;"
"elseif p == 1"
"    IL_sel = IL2;"
"elseif p == 2"
"    IL_sel = IL3;"
"else"
"    IL_sel = IL4;"
"end"
"Ri_eff = Ri_in * exp(kappa_cmd_in);"
"vc_ctrl = Vc_bias_in + Kvc_in * e_v;"
"h_iqcot = vc_ctrl - Ri_eff * IL_sel;"
"Lambda_i = Lambda0_in * (1 + rho_cmd_in) + Lambda_m2_in * cos(pi * p);"
"if Lambda_i < eps"
"    Lambda_i = eps;"
"end"
"A_update = Astate + Ts_ctrl_in * h_iqcot;"
"if A_update < A_lower_in"
"    A_update = A_lower_in;"
"end"
"if A_update > A_upper_in"
"    A_update = A_upper_in;"
"end"
"REQ_iqcot = double((enable > 0.5) && (A_update >= Lambda_i));"
"A_iqcot = A_update;"
"reset_rise = (tr_reset > 0.5) && (reset_prev <= 0.5);"
"phase_change = (p ~= phase_prev);"
"if enable <= 0.5"
"    Astate = A_init_in;"
"elseif reset_rise || phase_change"
"    Astate = A_init_in;"
"else"
"    Astate = A_update;"
"end"
"reset_prev = double(tr_reset);"
"phase_prev = p;"
];

rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
dataNames = ["e_v", "IL1", "IL2", "IL3", "IL4", "phase_idx", "tr_reset", "enable", ...
    "Ts_ctrl_in", "Lambda0_in", "Lambda_m2_in", "rho_cmd_in", "Ri_in", ...
    "Kvc_in", "Vc_bias_in", "kappa_cmd_in", "A_init_in", "A_lower_in", "A_upper_in", ...
    "REQ_iqcot", "A_iqcot", "Lambda_i", "h_iqcot", "IL_sel", "vc_ctrl"];
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        data.Props.Type.Primitive = "double";
        data.Props.Array.Size = "1";
    end
end
end

function instrumentSignals(model)
tryMarkBlockOutport(model + "/Voltage Measurement", 1, "Vout");
tryMarkBlockOutport(model + "/Sum", 1, "e_v");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 1, "REQ_iqcot");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 2, "A_iqcot");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 3, "Lambda_i");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 4, "h_iqcot");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 5, "IL_sel");
tryMarkBlockOutport(model + "/Ideal_Digital_IQCOT_Request", 6, "vc_ctrl");
tryMarkBlockOutport(model + "/PhaseScheduler_4Phase", 5, "phase_idx");
tryMarkBlockOutport(model + "/From17", 1, "tr_reset");
tryMarkBlockOutport(model + "/From18", 1, "tr");
tryMarkGotoInput(model + "/Goto15", "Allow");
for phase = 1:4
    tryMarkBlockOutport(model + "/IL_Measurement" + phase, 1, "IL" + phase);
    tryMarkBlockOutport(model + "/From" + (26 + phase), 1, "IL_sample" + phase);
    tryMarkBlockOutport(model + "/GateDriver_1Phase" + phase, 1, "QH" + phase);
    tryMarkBlockOutport(model + "/GateDriver_1Phase" + phase, 2, "QL" + phase);
    tryMarkBlockOutport(model + "/Voltage Measurement" + phase, 1, "SW" + phase);
    tryMarkBlockOutport(model + "/IQCOT_Ton_Adapter", phase, "Ton_iqcot" + phase);
    tryMarkGotoInput(model + "/Goto" + (17 + phase), "tr" + phase);
end
end

function tryMarkBlockOutport(blockPath, portNumber, signalName)
try
    ports = get_param(blockPath, "PortHandles");
    portHandle = ports.Outport(portNumber);
    lineHandle = get_param(portHandle, "Line");
    if lineHandle ~= -1
        set_param(lineHandle, "Name", char(signalName));
    end
    Simulink.sdi.markSignalForStreaming(portHandle, "on");
catch
end
end

function tryMarkGotoInput(gotoPath, signalName)
try
    ports = get_param(gotoPath, "PortHandles");
    lineHandle = get_param(ports.Inport(1), "Line");
    if lineHandle == -1
        return;
    end
    set_param(lineHandle, "Name", char(signalName));
    srcPort = get_param(lineHandle, "SrcPortHandle");
    Simulink.sdi.markSignalForStreaming(srcPort, "on");
catch
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

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function deleteBlocksByPrefix(model, prefix)
blocks = find_system(model, "SearchDepth", 1, "Type", "Block");
for idx = 1:numel(blocks)
    name = string(get_param(blocks{idx}, "Name"));
    if startsWith(name, prefix)
        delete_block(blocks{idx});
    end
end
end
