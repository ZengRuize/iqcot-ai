function modelFile = iqcot_r049n_build_independent_clock_reentry_model()
%IQCOT_R049N_BUILD_INDEPENDENT_CLOCK_REENTRY_MODEL Build independent-clock reentry copy.
%
% R049N copies the repaired R049L derived model, removes the downstream-qh1
% release latch, and inserts an independent upstream timer / predicted-slot
% one-shot gate:
%
%   release_clock = t >= t_load_step + Tphase_release_delay
%   one_shot_done = first release_clock event during inhibit_raw
%   allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
%
% The release clock is generated outside the request/scheduler path, so it
% keeps evolving while request-path inhibition is active.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry";
dstModelName = "four_phase_iek_pr_ecb_control_r049n_independent_clock_reentry";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    addpath("E:\Desktop\codex\output");
    iqcot_r049l_repair_build_controlled_reentry_model();
end
if ~exist(srcModel, "file")
    error("R049L repair model not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

insertIndependentClockReentryGate(dstModelName);

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049N_INDEPENDENT_CLOCK_REENTRY_MODEL=%s\n", modelFile);
end

function insertIndependentClockReentryGate(modelName)
logicSrc = findExistingAllowSource(modelName);

deletePrefixedTopLevelBlocks(modelName, "R049L_");
deletePrefixedTopLevelBlocks(modelName, "R049N_");

xB = 1180;
yB = 240;

clockPath = modelName + "/R049N_Clock";
startConstPath = modelName + "/R049N_Inhibit_Start";
endConstPath = modelName + "/R049N_Inhibit_End";
afterStartPath = modelName + "/R049N_After_Inhibit_Start";
beforeEndPath = modelName + "/R049N_Before_Inhibit_End";
inhibitRawPath = modelName + "/R049N_Inhibit_Raw";
notInhibitRawPath = modelName + "/R049N_Not_Inhibit_Raw";

releaseConstPath = modelName + "/R049N_Release_Time";
releaseClockPath = modelName + "/R049N_After_Release_Time";
releaseSetAndPath = modelName + "/R049N_Release_Set_And";

srOrPath = modelName + "/R049N_SR_Or";
srAndPath = modelName + "/R049N_SR_And";
srStatePath = modelName + "/R049N_SR_State";

gateOrPath = modelName + "/R049N_Gate_Or";
gateAndPath = modelName + "/R049N_Gate_And";

add_block("simulink/Sources/Clock", clockPath, ...
    "Position", [xB yB xB+50 yB+25]);
add_block("simulink/Sources/Constant", startConstPath, ...
    "Position", [xB yB+50 xB+210 yB+80], ...
    "Value", "t_load_step + Tpost_inhibit_delay");
add_block("simulink/Sources/Constant", endConstPath, ...
    "Position", [xB yB+88 xB+250 yB+118], ...
    "Value", "t_load_step + Tpost_inhibit_delay + Tpost_inhibit_window");
add_block("simulink/Logic and Bit Operations/Relational Operator", afterStartPath, ...
    "Position", [xB+120 yB+5 xB+175 yB+40], ...
    "Operator", ">=");
add_block("simulink/Logic and Bit Operations/Relational Operator", beforeEndPath, ...
    "Position", [xB+120 yB+55 xB+175 yB+90], ...
    "Operator", "<=");
add_block("simulink/Logic and Bit Operations/Logical Operator", inhibitRawPath, ...
    "Position", [xB+205 yB+20 xB+265 yB+65], ...
    "Operator", "AND", "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", notInhibitRawPath, ...
    "Position", [xB+300 yB+25 xB+360 yB+55], ...
    "Operator", "NOT", "Inputs", "1");

add_block("simulink/Sources/Constant", releaseConstPath, ...
    "Position", [xB yB+142 xB+245 yB+172], ...
    "Value", "t_load_step + Tphase_release_delay");
add_block("simulink/Logic and Bit Operations/Relational Operator", releaseClockPath, ...
    "Position", [xB+285 yB+125 xB+345 yB+160], ...
    "Operator", ">=");
add_block("simulink/Logic and Bit Operations/Logical Operator", releaseSetAndPath, ...
    "Position", [xB+390 yB+115 xB+450 yB+155], ...
    "Operator", "AND", "Inputs", "2");

add_block("simulink/Logic and Bit Operations/Logical Operator", srOrPath, ...
    "Position", [xB+500 yB+120 xB+560 yB+180], ...
    "Operator", "OR", "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", srAndPath, ...
    "Position", [xB+675 yB+120 xB+735 yB+180], ...
    "Operator", "AND", "Inputs", "2");
add_block("simulink/Discrete/Unit Delay", srStatePath, ...
    "Position", [xB+790 yB+135 xB+840 yB+165], ...
    "SampleTime", "Ts_ctrl");

add_block("simulink/Logic and Bit Operations/Logical Operator", gateOrPath, ...
    "Position", [xB+690 yB+55 xB+750 yB+110], ...
    "Operator", "OR", "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", gateAndPath, ...
    "Position", [xB+880 yB+70 xB+940 yB+130], ...
    "Operator", "AND", "Inputs", "2");

safeAddLine(modelName, "R049N_Clock/1", "R049N_After_Inhibit_Start/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Inhibit_Start/1", "R049N_After_Inhibit_Start/2", "autorouting", "on");
safeAddLine(modelName, "R049N_Clock/1", "R049N_Before_Inhibit_End/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Inhibit_End/1", "R049N_Before_Inhibit_End/2", "autorouting", "on");
safeAddLine(modelName, "R049N_After_Inhibit_Start/1", "R049N_Inhibit_Raw/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Before_Inhibit_End/1", "R049N_Inhibit_Raw/2", "autorouting", "on");
safeAddLine(modelName, "R049N_Inhibit_Raw/1", "R049N_Not_Inhibit_Raw/1", "autorouting", "on");

safeAddLine(modelName, "R049N_Clock/1", "R049N_After_Release_Time/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Release_Time/1", "R049N_After_Release_Time/2", "autorouting", "on");
safeAddLine(modelName, "R049N_After_Release_Time/1", "R049N_Release_Set_And/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Inhibit_Raw/1", "R049N_Release_Set_And/2", "autorouting", "on");

safeAddLine(modelName, "R049N_Release_Set_And/1", "R049N_SR_Or/1", "autorouting", "on");
safeAddLine(modelName, "R049N_SR_State/1", "R049N_SR_Or/2", "autorouting", "on");
safeAddLine(modelName, "R049N_SR_Or/1", "R049N_SR_And/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Inhibit_Raw/1", "R049N_SR_And/2", "autorouting", "on");
safeAddLine(modelName, "R049N_SR_And/1", "R049N_SR_State/1", "autorouting", "on");

safeAddLine(modelName, portRef(logicSrc), "R049N_Gate_And/1", "autorouting", "on");
safeAddLine(modelName, "R049N_Not_Inhibit_Raw/1", "R049N_Gate_Or/1", "autorouting", "on");
safeAddLine(modelName, "R049N_SR_State/1", "R049N_Gate_Or/2", "autorouting", "on");
safeAddLine(modelName, "R049N_Gate_Or/1", "R049N_Gate_And/2", "autorouting", "on");
safeAddLine(modelName, "R049N_Gate_And/1", "Goto16/1", "autorouting", "on");

addLoggedBoolFanout(modelName, "R049N_SR_State", "one_shot_done", "one_shot_done", 1810, 300);
addLoggedBoolFanout(modelName, "R049N_Inhibit_Raw", "inhibit_raw", "inhibit_raw", 1810, 345);
addLoggedBoolFanout(modelName, "R049N_Gate_And", "allow_controlled", "allow_controlled_reentry", 1810, 390);
addLoggedBoolFanout(modelName, "R049N_After_Release_Time", "release_clock", "release_clock", 1810, 435);

markBlockOutport(notInhibitRawPath, 1, "not_inhibit_raw");
end

function logicSrc = findExistingAllowSource(modelName)
oldGate = modelName + "/R049L_Gate_And";
if getSimulinkBlockHandle(oldGate) ~= -1
    logicSrc = sourceToInport(oldGate, 1);
    return;
end

logicPath = findAllowLogic(modelName);
ports = get_param(logicPath, "PortHandles");
lineHandle = get_param(ports.Outport(1), "Line");
if lineHandle ~= -1
    delete_line(lineHandle);
end
logicSrc.block = logicPath;
logicSrc.port = 1;
end

function src = sourceToInport(blockPath, inportNumber)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1
    error("No line connected to %s inport %d.", blockPath, inportNumber);
end
srcPort = get_param(lineHandle, "SrcPortHandle");
if srcPort == -1
    error("No source connected to %s inport %d.", blockPath, inportNumber);
end
src.block = string(getfullname(get_param(srcPort, "Parent")));
src.port = get_param(srcPort, "PortNumber");
end

function ref = portRef(src)
[~, blockName] = fileparts(src.block);
ref = blockName + "/" + string(src.port);
end

function logicPath = findAllowLogic(modelName)
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
    dst = get_param(lineHandle, "DstBlockHandle");
    if iscell(dst)
        dst = cell2mat(dst);
    end
    for j = 1:numel(dst)
        if string(getfullname(dst(j))) == modelName + "/Goto16"
            logicPath = string(logicBlocks{k});
            return;
        end
    end
end
error("Could not find top-level allow logic driving Goto16.");
end

function deletePrefixedTopLevelBlocks(modelName, prefix)
blocks = find_system(modelName, "SearchDepth", 1, "Type", "Block");
for k = 1:numel(blocks)
    name = string(get_param(blocks{k}, "Name"));
    if startsWith(name, prefix)
        deleteBlockIfExists(string(blocks{k}));
    end
end
end

function addLoggedBoolFanout(modelName, srcBlockName, blockStem, signalName, x, y)
convPath = modelName + "/R049N_" + blockStem + "_double";
termPath = modelName + "/R049N_" + blockStem + "_Term";
deleteBlockIfExists(termPath);
deleteBlockIfExists(convPath);

add_block("simulink/Signal Attributes/Data Type Conversion", convPath, ...
    "Position", [x y x+70 y+24], ...
    "OutDataTypeStr", "double");
add_block("simulink/Sinks/Terminator", termPath, ...
    "Position", [x+145 y+2 x+175 y+22]);

safeAddLine(modelName, srcBlockName + "/1", getBlockName(convPath) + "/1", "autorouting", "on");
safeAddLine(modelName, getBlockName(convPath) + "/1", getBlockName(termPath) + "/1", "autorouting", "on");
markBlockOutport(convPath, 1, signalName);
end

function safeAddLine(modelName, src, dst, varargin)
deleteLineToDst(modelName, dst);
add_line(modelName, src, dst, varargin{:});
end

function deleteLineToDst(modelName, dst)
parts = split(string(dst), "/");
if numel(parts) ~= 2
    return;
end
blockPath = modelName + "/" + parts(1);
portNumber = str2double(parts(2));
if isnan(portNumber) || getSimulinkBlockHandle(blockPath) == -1
    return;
end
ports = get_param(blockPath, "PortHandles");
if numel(ports.Inport) < portNumber
    return;
end
lineHandle = get_param(ports.Inport(portNumber), "Line");
if lineHandle ~= -1
    delete_line(lineHandle);
end
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber
    error("Missing outport %d on %s", outportNumber, blockPath);
end
portHandle = ports.Outport(outportNumber);
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

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end

function name = getBlockName(blockPath)
parts = split(string(blockPath), "/");
name = char(parts(end));
end
