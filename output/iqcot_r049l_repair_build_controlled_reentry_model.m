function modelFile = iqcot_r049l_repair_build_controlled_reentry_model()
%IQCOT_R049L_REPAIR_BUILD_CONTROLLED_REENTRY_MODEL Build phase-boundary one-shot controlled-reentry copy.
%
% R049L repair: copies R049I model, inserts phase-boundary one-shot state-machine:
%
%   allow_to_scheduler = existing_allow AND (NOT(inhibit_raw) OR one_shot_done)
%
% where inhibit_raw starts at t_load_step + Tpost_inhibit_delay,
% one_shot_done latches high on first qh1 rising edge after inhibit starts.
% This is a phase-boundary controlled reentry, not raw req_global edge.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049i_gentle_tontrim";
dstModelName = "four_phase_iek_pr_ecb_control_r049l_repair_controlled_reentry";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049I gentle Ton-trim model not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

insertOneShotReentryGate(dstModelName);

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049L_REPAIR_CONTROLLED_REENTRY_MODEL=%s\n", modelFile);
end

function insertOneShotReentryGate(modelName)
% Find the Logic block driving Goto16
logicPath = findAllowLogic(modelName);

% Disconnect its output from Goto16
ports = get_param(logicPath, "PortHandles");
logicLine = get_param(ports.Outport(1), "Line");
if logicLine ~= -1
    delete_line(logicLine);
end

% Find qh1 source from Phase1 subsystem outport
qh1Src = findQh1Source(modelName);

% --- Build one-shot gate chain ---
xB = 1180;
yB = 240;

% inhibit_raw = (t >= t_load_step + Tpost_inhibit_delay) AND
%               (t <= t_load_step + Tpost_inhibit_delay + Tpost_inhibit_window)
clockPath = modelName + "/R049L_Clock";
startConstPath = modelName + "/R049L_Inhibit_Start";
endConstPath = modelName + "/R049L_Inhibit_End";
afterStartPath = modelName + "/R049L_After_Inhibit_Start";
beforeEndPath = modelName + "/R049L_Before_Inhibit_End";
inhibitRawPath = modelName + "/R049L_Inhibit_Raw";
notInhibitRawPath = modelName + "/R049L_Not_Inhibit_Raw";

% Edge detection on qh1
qhDelayPath = modelName + "/R049L_Qh1_Delay";
notQhDelayPath = modelName + "/R049L_Not_Qh1_Delay";
qhRisePath = modelName + "/R049L_Qh1_Rise";

% SR latch using basic blocks: next_state = (S OR state) AND inhibit_raw.
% This latches one-shot release only inside the inhibit window and resets after it.
qh1SetAndPath = modelName + "/R049L_Qh1_Set_And";
srOrPath = modelName + "/R049L_SR_Or";
srAndPath = modelName + "/R049L_SR_And";
srStatePath = modelName + "/R049L_SR_State";

% Gate output
gateOrPath = modelName + "/R049L_Gate_Or";
gateAndPath = modelName + "/R049L_Gate_And";

% Delete leftover blocks
blockPaths = [gateAndPath, gateOrPath, modelName + "/R049L_SR_NotR", srStatePath, srAndPath, srOrPath, qh1SetAndPath, ...
    qhRisePath, notQhDelayPath, qhDelayPath, ...
    notInhibitRawPath, inhibitRawPath, beforeEndPath, afterStartPath, endConstPath, startConstPath, clockPath];
for p = blockPaths
    deleteBlockIfExists(p);
end

% --- Add blocks ---
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

% S_effective = qh1_rise AND inhibit_raw
add_block("simulink/Logic and Bit Operations/Logical Operator", qh1SetAndPath, ...
    "Position", [xB+260 yB+100 xB+320 yB+130], ...
    "Operator", "AND", "Inputs", "2");

% qh1 edge detector
add_block("simulink/Discrete/Unit Delay", qhDelayPath, ...
    "Position", [xB yB+100 xB+50 yB+130], ...
    "SampleTime", "Ts_ctrl");
add_block("simulink/Logic and Bit Operations/Logical Operator", notQhDelayPath, ...
    "Position", [xB+80 yB+100 xB+140 yB+130], ...
    "Operator", "NOT", "Inputs", "1");
add_block("simulink/Logic and Bit Operations/Logical Operator", qhRisePath, ...
    "Position", [xB+170 yB+100 xB+230 yB+130], ...
    "Operator", "AND", "Inputs", "2");

% SR latch: next_state = (S OR state) AND inhibit_raw
% S = qh1_rise AND inhibit_raw
add_block("simulink/Logic and Bit Operations/Logical Operator", srOrPath, ...
    "Position", [xB+270 yB+140 xB+330 yB+200], ...
    "Operator", "OR", "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", srAndPath, ...
    "Position", [xB+470 yB+140 xB+530 yB+200], ...
    "Operator", "AND", "Inputs", "2");
add_block("simulink/Discrete/Unit Delay", srStatePath, ...
    "Position", [xB+580 yB+155 xB+630 yB+185], ...
    "SampleTime", "Ts_ctrl");

% Final gate
add_block("simulink/Logic and Bit Operations/Logical Operator", gateOrPath, ...
    "Position", [xB+690 yB+60 xB+750 yB+125], ...
    "Operator", "OR", "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", gateAndPath, ...
    "Position", [xB+800 yB+70 xB+860 yB+130], ...
    "Operator", "AND", "Inputs", "2");

% --- Wire inhibit_raw chain ---
add_line(modelName, "R049L_Clock/1", "R049L_After_Inhibit_Start/1", "autorouting", "on");
add_line(modelName, "R049L_Inhibit_Start/1", "R049L_After_Inhibit_Start/2", "autorouting", "on");
add_line(modelName, "R049L_Clock/1", "R049L_Before_Inhibit_End/1", "autorouting", "on");
add_line(modelName, "R049L_Inhibit_End/1", "R049L_Before_Inhibit_End/2", "autorouting", "on");
add_line(modelName, "R049L_After_Inhibit_Start/1", "R049L_Inhibit_Raw/1", "autorouting", "on");
add_line(modelName, "R049L_Before_Inhibit_End/1", "R049L_Inhibit_Raw/2", "autorouting", "on");
add_line(modelName, "R049L_Inhibit_Raw/1", "R049L_Not_Inhibit_Raw/1", "autorouting", "on");

% --- Wire qh1 edge detector ---
[~, qh1Block] = fileparts(qh1Src.block);
add_line(modelName, strcat(qh1Block, "/", num2str(qh1Src.port)), ...
    "R049L_Qh1_Delay/1", "autorouting", "on");
add_line(modelName, "R049L_Qh1_Delay/1", "R049L_Not_Qh1_Delay/1", "autorouting", "on");
add_line(modelName, "R049L_Not_Qh1_Delay/1", "R049L_Qh1_Rise/2", "autorouting", "on");
add_line(modelName, strcat(qh1Block, "/", num2str(qh1Src.port)), ...
    "R049L_Qh1_Rise/1", "autorouting", "on");

% --- Wire SR latch ---
% S signal: qh1_rise AND inhibit_raw -> we combine these at the SR_Or input
% First combine S = qh1_rise AND inhibit_raw using an implicit junction
% Simpler: wire qh1_rise -> SR_Or/1, state_feedback -> SR_Or/2
% Wire S_effective = qh1_rise AND inhibit_raw
add_line(modelName, "R049L_Qh1_Rise/1", "R049L_Qh1_Set_And/1", "autorouting", "on");
add_line(modelName, "R049L_Inhibit_Raw/1", "R049L_Qh1_Set_And/2", "autorouting", "on");
add_line(modelName, "R049L_Qh1_Set_And/1", "R049L_SR_Or/1", "autorouting", "on");
add_line(modelName, "R049L_SR_State/1", "R049L_SR_Or/2", "autorouting", "on");
add_line(modelName, "R049L_SR_Or/1", "R049L_SR_And/1", "autorouting", "on");
add_line(modelName, "R049L_Inhibit_Raw/1", "R049L_SR_And/2", "autorouting", "on");
add_line(modelName, "R049L_SR_And/1", "R049L_SR_State/1", "autorouting", "on");

% --- Wire final gate ---
[~, logicBlk] = fileparts(logicPath);
logicSrc = strcat(logicBlk, "/1");
add_line(modelName, logicSrc, "R049L_Gate_And/1", "autorouting", "on");
add_line(modelName, "R049L_Not_Inhibit_Raw/1", "R049L_Gate_Or/1", "autorouting", "on");
add_line(modelName, "R049L_SR_State/1", "R049L_Gate_Or/2", "autorouting", "on");
add_line(modelName, "R049L_Gate_Or/1", "R049L_Gate_And/2", "autorouting", "on");
add_line(modelName, "R049L_Gate_And/1", "Goto16/1", "autorouting", "on");

% --- Logging fanouts ---
addLoggedBoolFanout(modelName, "R049L_SR_State", "one_shot_done", "one_shot_done", 1810, 300);
addLoggedBoolFanout(modelName, "R049L_Inhibit_Raw", "inhibit_raw", "inhibit_raw", 1810, 345);
addLoggedBoolFanout(modelName, "R049L_Gate_And", "allow_controlled", "allow_controlled_reentry", 1810, 390);

markBlockOutport(notInhibitRawPath, 1, "not_inhibit_raw");
end

function src = findQh1Source(modelName)
% Find qh1 source from the existing top-level gate-driver signal.
% R049I/R049K use GateDriver_1Phase1 rather than a Phase1 subsystem.

lines = find_system(modelName, "SearchDepth", 1, "FindAll", "on", "Type", "Line");
for j = 1:numel(lines)
    try
        name = get_param(lines(j), "Name");
        if strcmpi(strtrim(name), "qh1")
            srcPort = get_param(lines(j), "SrcPortHandle");
            if srcPort == -1
                continue;
            end
            src.block = getfullname(get_param(srcPort, "Parent"));
            src.port = get_param(srcPort, "PortNumber");
            return;
        end
    catch
    end
end

gateDriverPath = modelName + "/GateDriver_1Phase1";
if getSimulinkBlockHandle(gateDriverPath) ~= -1
    ports = get_param(gateDriverPath, "PortHandles");
    if ~isempty(ports.Outport)
        src.block = gateDriverPath;
        src.port = 1;
        return;
    end
end

error("Could not locate qh1 source for R049L phase-boundary trigger.");
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

function addLoggedBoolFanout(modelName, srcBlockName, blockStem, signalName, x, y)
convPath = modelName + "/R049L_" + blockStem + "_double";
termPath = modelName + "/R049L_" + blockStem + "_Term";
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
