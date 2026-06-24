function modelFile = iqcot_r049c_build_tontrunc_model()
%IQCOT_R049C_BUILD_TONTRUNC_MODEL Build a minimal Ton-truncation derived copy.
%
% R049C derives a new model from the R049A PR-ECB scaffold and inserts exactly
% one new protection action:
%
%   if t_load_step <= t <= t_load_step + Tton_trunc_window
%      and Vout > Vo_ref + Vton_trunc_ov
%   then Ton_iqcot_i -> Tton_trunc_min
%
% This is a command-path Ton truncation test.  It does not edit raw .slx XML,
% does not modify the original or earlier derived models, and does not replace
% the IQCOT request generator or gate-driver subsystem.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control";
dstModelName = "four_phase_iek_pr_ecb_control_r049c_tontrunc";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049A scaffold not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

insertTonTruncation(dstModelName);
replaceProtectionLogs(dstModelName);

save_system(dstModelName, modelFile);
fprintf("R049C_TONTRUNC_MODEL=%s\n", modelFile);
end

function insertTonTruncation(modelName)
globalFlag = addGlobalTonTruncFlag(modelName);

adapter = modelName + "/IQCOT_Ton_Adapter";
adapterPorts = get_param(adapter, "PortHandles");

for phase = 1:4
    cot = modelName + "/COT_Cell_1Phase" + phase;
    cotPorts = get_param(cot, "PortHandles");
    in3 = cotPorts.Inport(3);
    oldLine = get_param(in3, "Line");
    if oldLine == -1
        error("COT phase %d Ton input has no line.", phase);
    end
    delete_line(oldLine);

    switchPath = modelName + "/R049C_Ton_Switch" + phase;
    minPath = modelName + "/R049C_Ton_Min" + phase;
    deleteBlockIfExists(switchPath);
    deleteBlockIfExists(minPath);

    x = 760;
    y = 780 + (phase - 1) * 80;
    add_block("simulink/Sources/Constant", minPath, ...
        "Position", [x y x+90 y+24], ...
        "Value", "Tton_trunc_min");
    add_block("simulink/Signal Routing/Switch", switchPath, ...
        "Position", [x+150 y-10 x+210 y+55], ...
        "Criteria", "u2 ~= 0");

    add_line(modelName, getBlockName(minPath) + "/1", ...
        getBlockName(switchPath) + "/1", "autorouting", "on");
    add_line(modelName, getBlockName(globalFlag) + "/1", ...
        getBlockName(switchPath) + "/2", "autorouting", "on");
    add_line(modelName, "IQCOT_Ton_Adapter/" + phase, ...
        getBlockName(switchPath) + "/3", "autorouting", "on");
    add_line(modelName, getBlockName(switchPath) + "/1", ...
        "COT_Cell_1Phase" + phase + "/3", "autorouting", "on");

    markPort(adapterPorts.Outport(phase), "ton_iqcot_raw" + phase);
    markBlockOutport(switchPath, 1, "ton_cmd_trunc" + phase);
end
end

function globalFlag = addGlobalTonTruncFlag(modelName)
clkPath = modelName + "/R049C_Clock";
afterPath = modelName + "/R049C_After_LoadStep";
beforePath = modelName + "/R049C_Before_Trunc_Window_End";
endPath = modelName + "/R049C_Trunc_Window_End";
ovThrPath = modelName + "/R049C_OV_Threshold";
ovPath = modelName + "/R049C_OV_For_TonTrunc";
andPath = modelName + "/R049C_TonTrunc_Global";

for p = [clkPath, afterPath, beforePath, endPath, ovThrPath, ovPath, andPath]
    deleteBlockIfExists(p);
end

add_block("simulink/Sources/Clock", clkPath, ...
    "Position", [1180 40 1230 65]);
add_block("simulink/Logic and Bit Operations/Relational Operator", afterPath, ...
    "Position", [1320 20 1375 55], ...
    "Operator", ">=");
add_block("simulink/Sources/Constant", endPath, ...
    "Position", [1180 95 1340 125], ...
    "Value", "t_load_step + Tton_trunc_window");
add_block("simulink/Logic and Bit Operations/Relational Operator", beforePath, ...
    "Position", [1385 82 1440 117], ...
    "Operator", "<=");
add_block("simulink/Sources/Constant", ovThrPath, ...
    "Position", [1180 165 1340 195], ...
    "Value", "Vo_ref + Vton_trunc_ov");
add_block("simulink/Logic and Bit Operations/Relational Operator", ovPath, ...
    "Position", [1385 142 1440 197], ...
    "Operator", ">");
add_block("simulink/Logic and Bit Operations/Logical Operator", andPath, ...
    "Position", [1500 70 1560 160], ...
    "Operator", "AND", ...
    "Inputs", "3");

add_line(modelName, "R049C_Clock/1", "R049C_After_LoadStep/1", "autorouting", "on");
add_line(modelName, "R049C_Clock/1", "R049C_Before_Trunc_Window_End/1", "autorouting", "on");
add_line(modelName, "R049C_Trunc_Window_End/1", "R049C_Before_Trunc_Window_End/2", "autorouting", "on");
add_line(modelName, "Voltage Measurement/1", "R049C_OV_For_TonTrunc/1", "autorouting", "on");
add_line(modelName, "R049C_OV_Threshold/1", "R049C_OV_For_TonTrunc/2", "autorouting", "on");
add_line(modelName, "R049C_After_LoadStep/1", "R049C_TonTrunc_Global/1", "autorouting", "on");
add_line(modelName, "R049C_Before_Trunc_Window_End/1", "R049C_TonTrunc_Global/2", "autorouting", "on");
add_line(modelName, "R049C_OV_For_TonTrunc/1", "R049C_TonTrunc_Global/3", "autorouting", "on");

markBlockOutport(ovPath, 1, "ton_trunc_ov_raw");
globalFlag = andPath;
end

function replaceProtectionLogs(modelName)
for blockName = ["R049_protect_state_stub", "R049_protect_state_stub_Term", ...
        "R049_ton_truncate_stub1", "R049_ton_truncate_stub1_Term", ...
        "R049_ton_truncate_stub2", "R049_ton_truncate_stub2_Term", ...
        "R049_ton_truncate_stub3", "R049_ton_truncate_stub3_Term", ...
        "R049_ton_truncate_stub4", "R049_ton_truncate_stub4_Term"]
    deleteBlockIfExists(modelName + "/" + blockName);
end

addLoggedBoolFanout(modelName, "R049C_TonTrunc_Global", ...
    "ton_trunc_global", "ton_trunc_global", 1680, 0);
addLoggedBoolFanout(modelName, "R049C_TonTrunc_Global", ...
    "protect_state", "protect_state", 1680, 40);
for phase = 1:4
    y = 160 + (phase - 1) * 170;
    addLoggedBoolFanout(modelName, "R049C_TonTrunc_Global", ...
        "ton_truncate" + phase, "ton_truncate" + phase, 1680, y);
end
end

function addLoggedBoolFanout(modelName, srcBlockName, blockStem, signalName, x, y)
convPath = modelName + "/R049C_" + blockStem + "_double";
termPath = modelName + "/R049C_" + blockStem + "_Term";
deleteBlockIfExists(termPath);
deleteBlockIfExists(convPath);

add_block("simulink/Signal Attributes/Data Type Conversion", convPath, ...
    "Position", [x y x+70 y+24], ...
    "OutDataTypeStr", "double");
add_block("simulink/Sinks/Terminator", termPath, ...
    "Position", [x+145 y+2 x+175 y+22]);

add_line(modelName, srcBlockName + "/1", getBlockName(convPath) + "/1", "autorouting", "on");
add_line(modelName, getBlockName(convPath) + "/1", getBlockName(termPath) + "/1", "autorouting", "on");
markBlockOutport(convPath, 1, signalName);
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber
    error("Missing outport %d on %s", outportNumber, blockPath);
end
markPort(ports.Outport(outportNumber), signalName);
end

function markPort(portHandle, signalName)
lineHandle = get_param(portHandle, "Line");
if lineHandle == -1
    error("Cannot mark unconnected port.");
end
set_param(lineHandle, "Name", char(signalName));
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end

function name = getBlockName(blockPath)
parts = split(string(blockPath), "/");
name = char(parts(end));
end
