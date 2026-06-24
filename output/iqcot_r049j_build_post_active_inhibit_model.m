function modelFile = iqcot_r049j_build_post_active_inhibit_model()
%IQCOT_R049J_BUILD_POST_ACTIVE_INHIBIT_MODEL Build deferred pulse-inhibit copy.
%
% R049J copies the completed R049I model into a new derived `.slx` file and
% inserts one request-path action:
%
%   allow_to_scheduler = existing_allow AND NOT(post_active_inhibit)
%
% where post_active_inhibit is a load-step-relative window.  The runner selects
% the window so that A2 starts after the current active-HS pulse's natural end
% in the R049I/R049G baseline trace.  This action gates future scheduler
% requests; it does not change COT-cell Ton and does not truncate an already
% active high-side pulse.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049i_gentle_tontrim";
dstModelName = "four_phase_iek_pr_ecb_control_r049j_post_active_inhibit";

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

insertPostActiveInhibitGate(dstModelName);

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049J_POST_ACTIVE_INHIBIT_MODEL=%s\n", modelFile);
end

function insertPostActiveInhibitGate(modelName)
logicPath = findAllowLogic(modelName);
set_param(logicPath, "Inputs", "3");

if ~isempty(getLineToInport(logicPath, 3))
    deleteLineToInport(logicPath, 3);
end

clockPath = modelName + "/R049J_Clock";
startConstPath = modelName + "/R049J_Inhibit_Start";
endConstPath = modelName + "/R049J_Inhibit_End";
afterPath = modelName + "/R049J_After_Inhibit_Start";
beforePath = modelName + "/R049J_Before_Inhibit_End";
inhibitPath = modelName + "/R049J_PostActive_Inhibit";
notInhibitPath = modelName + "/R049J_Not_PostActive_Inhibit";

for p = [clockPath, startConstPath, endConstPath, afterPath, beforePath, inhibitPath, notInhibitPath]
    deleteBlockIfExists(p);
end

add_block("simulink/Sources/Clock", clockPath, ...
    "Position", [1180 250 1230 275]);
add_block("simulink/Sources/Constant", startConstPath, ...
    "Position", [1180 310 1390 340], ...
    "Value", "t_load_step + Tpost_inhibit_delay");
add_block("simulink/Sources/Constant", endConstPath, ...
    "Position", [1180 370 1445 400], ...
    "Value", "t_load_step + Tpost_inhibit_delay + Tpost_inhibit_window");
add_block("simulink/Logic and Bit Operations/Relational Operator", afterPath, ...
    "Position", [1475 270 1530 305], ...
    "Operator", ">=");
add_block("simulink/Logic and Bit Operations/Relational Operator", beforePath, ...
    "Position", [1475 350 1530 385], ...
    "Operator", "<=");
add_block("simulink/Logic and Bit Operations/Logical Operator", inhibitPath, ...
    "Position", [1585 292 1645 362], ...
    "Operator", "AND", ...
    "Inputs", "2");
add_block("simulink/Logic and Bit Operations/Logical Operator", notInhibitPath, ...
    "Position", [1695 315 1755 345], ...
    "Operator", "NOT", ...
    "Inputs", "1");

add_line(modelName, "R049J_Clock/1", "R049J_After_Inhibit_Start/1", "autorouting", "on");
add_line(modelName, "R049J_Inhibit_Start/1", "R049J_After_Inhibit_Start/2", "autorouting", "on");
add_line(modelName, "R049J_Clock/1", "R049J_Before_Inhibit_End/1", "autorouting", "on");
add_line(modelName, "R049J_Inhibit_End/1", "R049J_Before_Inhibit_End/2", "autorouting", "on");
add_line(modelName, "R049J_After_Inhibit_Start/1", "R049J_PostActive_Inhibit/1", "autorouting", "on");
add_line(modelName, "R049J_Before_Inhibit_End/1", "R049J_PostActive_Inhibit/2", "autorouting", "on");
add_line(modelName, "R049J_PostActive_Inhibit/1", "R049J_Not_PostActive_Inhibit/1", "autorouting", "on");
add_line(modelName, "R049J_Not_PostActive_Inhibit/1", getBlockName(logicPath) + "/3", "autorouting", "on");

addLoggedBoolFanout(modelName, "R049J_PostActive_Inhibit", "post_active_inhibit", "post_active_inhibit", 1810, 300);
addLoggedBoolFanout(modelName, "R049J_PostActive_Inhibit", "protect_state", "protect_state", 1810, 345);
for phase = 1:4
    y = 410 + (phase - 1) * 40;
    addLoggedBoolFanout(modelName, "R049J_PostActive_Inhibit", ...
        "pulse_inhibit" + phase, "pulse_inhibit" + phase, 1810, y);
end
markBlockOutport(notInhibitPath, 1, "not_post_active_inhibit");
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
convPath = modelName + "/R049J_" + blockStem + "_double";
termPath = modelName + "/R049J_" + blockStem + "_Term";
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
portHandle = ports.Outport(outportNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
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
