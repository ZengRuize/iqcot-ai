function modelFile = iqcot_r049b_build_ovskip_model()
%IQCOT_R049B_BUILD_OVSKIP_MODEL Build a minimal over-voltage skip derived copy.
%
% R049B derives a new model from the R049A PR-ECB scaffold and inserts exactly
% one minimal protection action:
%
%   Allow = GlobalReady && REQ && (Vout <= Vo_ref + Vov_skip)
%
% This is a simple over-voltage skip gate.  It does not truncate an already
% active high-side pulse, does not replace the IQCOT area-event request
% generator, and does not edit any raw .slx XML.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control";
dstModelName = "four_phase_iek_pr_ecb_control_r049b_ovskip";

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

insertOvSkipGate(dstModelName);
replaceProtectionLogs(dstModelName);
markAllowAfterOvSkip(dstModelName);

save_system(dstModelName, modelFile);
fprintf("R049B_OVSKIP_MODEL=%s\n", modelFile);
end

function insertOvSkipGate(modelName)
logicPath = findTopLogic(modelName);
set_param(logicPath, "Inputs", "3");

% The third input is the new permissive signal:
%   Voltage Measurement <= Vo_ref + Vov_skip.
% Use the actual measured-voltage block output rather than the legacy Vout
% GotoTag, because R049B validation compares against the logged
% Voltage Measurement signal.
notOvPath = modelName + "/R049B_Not_OV_Skip";
if ~isempty(getLineToInport(logicPath, 3))
    deleteLineToInport(logicPath, 3);
end
deleteBlockIfExists(notOvPath);

thrPath = modelName + "/R049B_OV_Threshold";
deleteBlockIfExists(thrPath);

add_block("simulink/Sources/Constant", thrPath, ...
    "Position", [700 130 810 160], ...
    "Value", "Vo_ref + Vov_skip");
add_block("simulink/Logic and Bit Operations/Relational Operator", notOvPath, ...
    "Position", [850 92 900 148], ...
    "Operator", "<=");

add_line(modelName, "Voltage Measurement/1", "R049B_Not_OV_Skip/1", "autorouting", "on");
add_line(modelName, "R049B_OV_Threshold/1", "R049B_Not_OV_Skip/2", "autorouting", "on");
add_line(modelName, "R049B_Not_OV_Skip/1", getBlockName(logicPath) + "/3", "autorouting", "on");

% Keep the permissive comparator observable.
markBlockOutport(notOvPath, 1, "not_ov_skip");
end

function replaceProtectionLogs(modelName)
% Replace R049A no-op protect/pulse-inhibit placeholders with the real
% over-voltage flag.  Ton truncation / hold / reset placeholders remain zero
% because R049B deliberately implements only simple OV skip.
for blockName = ["R049_protect_state_stub", "R049_protect_state_stub_Term", ...
        "R049_pulse_inhibit_stub1", "R049_pulse_inhibit_stub1_Term", ...
        "R049_pulse_inhibit_stub2", "R049_pulse_inhibit_stub2_Term", ...
        "R049_pulse_inhibit_stub3", "R049_pulse_inhibit_stub3_Term", ...
        "R049_pulse_inhibit_stub4", "R049_pulse_inhibit_stub4_Term"]
    deleteBlockIfExists(modelName + "/" + blockName);
end

thrPath = modelName + "/R049B_OV_Threshold_Log";
ovPath = modelName + "/R049B_OV_Skip_Flag";
deleteBlockIfExists(thrPath);
deleteBlockIfExists(ovPath);

add_block("simulink/Sources/Constant", thrPath, ...
    "Position", [1420 85 1530 115], ...
    "Value", "Vo_ref + Vov_skip");
add_block("simulink/Logic and Bit Operations/Relational Operator", ovPath, ...
    "Position", [1580 52 1630 108], ...
    "Operator", ">");
add_line(modelName, "Voltage Measurement/1", "R049B_OV_Skip_Flag/1", "autorouting", "on");
add_line(modelName, "R049B_OV_Threshold_Log/1", "R049B_OV_Skip_Flag/2", "autorouting", "on");

addLoggedBoolFanout(modelName, "R049B_OV_Skip_Flag", "ov_skip", "ov_skip", 1700, 80);
addLoggedBoolFanout(modelName, "R049B_OV_Skip_Flag", "protect_state", "protect_state", 1700, 35);
for phase = 1:4
    y = 160 + (phase - 1) * 170 + 40;
    addLoggedBoolFanout(modelName, "R049B_OV_Skip_Flag", ...
        "pulse_inhibit" + phase, "pulse_inhibit" + phase, 1700, y);
end
end

function markAllowAfterOvSkip(modelName)
allowGoto = modelName + "/Goto16";
ports = get_param(allowGoto, "PortHandles");
lineHandle = get_param(ports.Inport(1), "Line");
if lineHandle == -1
    error("Goto16 has no incoming Allow line.");
end
srcPort = get_param(lineHandle, "SrcPortHandle");
markPort(srcPort, "allow_after_ovskip");
end

function logicPath = findTopLogic(modelName)
logicBlocks = find_system(modelName, "SearchDepth", 1, "BlockType", "Logic");
for k = 1:numel(logicBlocks)
    ports = get_param(logicBlocks{k}, "PortHandles");
    if isempty(ports.Outport)
        continue;
    end
    lineHandle = get_param(ports.Outport(1), "Line");
    if lineHandle == -1
        continue;
    end
    dstBlocks = get_param(lineHandle, "DstBlockHandle");
    for j = 1:numel(dstBlocks)
        if strcmp(getfullname(dstBlocks(j)), modelName + "/Goto16")
            logicPath = string(logicBlocks{k});
            return;
        end
    end
end
error("Could not find top-level Allow logic feeding Goto16.");
end

function addLoggedBoolFanout(modelName, srcBlockName, blockStem, signalName, x, y)
convPath = modelName + "/R049B_" + blockStem + "_double";
termPath = modelName + "/R049B_" + blockStem + "_Term";
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

function lineHandle = getLineToInport(blockPath, inportNumber)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Inport) < inportNumber
    lineHandle = [];
    return;
end
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1
    lineHandle = [];
end
end

function deleteLineToInport(blockPath, inportNumber)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(inportNumber), "Line");
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

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end

function name = getBlockName(blockPath)
parts = split(string(blockPath), "/");
name = char(parts(end));
end
