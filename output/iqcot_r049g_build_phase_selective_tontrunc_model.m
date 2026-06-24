function modelFile = iqcot_r049g_build_phase_selective_tontrunc_model()
%IQCOT_R049G_BUILD_PHASE_SELECTIVE_TONTRUNC_MODEL Build active-HS-only copy.
%
% R049G copies the completed R049F trigger-timing diagnostic model, repairs the
% early-window lower-bound connection, then changes the Ton switch control from
% a global early window to a per-phase active-HS guard:
%
%   ton_truncate_i = early_window AND qh_i
%
% This keeps the intended load-step-synchronous early timing but prevents
% global all-phase Ton-min truncation.  No raw .slx XML is edited.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049f_early_tontrunc";
dstModelName = "four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049F early Ton-truncation model not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

repairLoadStepLowerBound(dstModelName);
insertPhaseSelectiveGuards(dstModelName);

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049G_PHASE_SELECTIVE_TONTRUNC_MODEL=%s\n", modelFile);
end

function repairLoadStepLowerBound(modelName)
% R049F removed the over-voltage input from R049C_TonTrunc_Global, exposing a
% latent R049C builder issue: R049C_After_LoadStep input 2 was unconnected.
% Without this repair, the "early" window starts at t=0 instead of t_load_step.
afterPath = modelName + "/R049C_After_LoadStep";
stepConstPath = modelName + "/R049G_LoadStep_Time";

deleteBlockIfExists(stepConstPath);
add_block("simulink/Sources/Constant", stepConstPath, ...
    "Position", [1245 28 1300 52], ...
    "Value", "t_load_step");

ports = get_param(afterPath, "PortHandles");
if numel(ports.Inport) < 2
    error("Expected two input ports on %s.", afterPath);
end
line2 = get_param(ports.Inport(2), "Line");
if line2 ~= -1
    delete_line(line2);
end
add_line(modelName, "R049G_LoadStep_Time/1", ...
    "R049C_After_LoadStep/2", "autorouting", "on");
end

function insertPhaseSelectiveGuards(modelName)
for phase = 1:4
    andPath = modelName + "/R049G_PhaseSelective_TonTrunc" + phase;
    memPath = modelName + "/R049G_QH_Memory" + phase;
    convPath = modelName + "/R049G_ton_truncate" + phase + "_double";
    termPath = modelName + "/R049G_ton_truncate" + phase + "_Term";
    oldConvPath = modelName + "/R049C_ton_truncate" + phase + "_double";
    oldTermPath = modelName + "/R049C_ton_truncate" + phase + "_Term";
    deleteBlockIfExists(oldTermPath);
    deleteBlockIfExists(oldConvPath);
    deleteBlockIfExists(termPath);
    deleteBlockIfExists(convPath);
    deleteBlockIfExists(memPath);
    deleteBlockIfExists(andPath);

    swPath = modelName + "/R049C_Ton_Switch" + phase;
    swPorts = get_param(swPath, "PortHandles");
    controlLine = get_param(swPorts.Inport(2), "Line");
    if controlLine ~= -1
        delete_line(controlLine);
    end

    y = 780 + (phase - 1) * 80;
    add_block("simulink/Logic and Bit Operations/Logical Operator", andPath, ...
        "Position", [1000 y-12 1060 y+42], ...
        "Operator", "AND", ...
        "Inputs", "2");
    add_block("simulink/Discrete/Memory", memPath, ...
        "Position", [885 y+20 945 y+50], ...
        "InitialCondition", "0");
    add_block("simulink/Signal Attributes/Data Type Conversion", convPath, ...
        "Position", [1105 y-5 1175 y+19], ...
        "OutDataTypeStr", "double");
    add_block("simulink/Sinks/Terminator", termPath, ...
        "Position", [1210 y-3 1240 y+17]);

    add_line(modelName, "R049C_TonTrunc_Global/1", ...
        getBlockName(andPath) + "/1", "autorouting", "on");
    add_line(modelName, "GateDriver_1Phase" + phase + "/1", ...
        getBlockName(memPath) + "/1", "autorouting", "on");
    add_line(modelName, getBlockName(memPath) + "/1", ...
        getBlockName(andPath) + "/2", "autorouting", "on");
    add_line(modelName, getBlockName(andPath) + "/1", ...
        "R049C_Ton_Switch" + phase + "/2", "autorouting", "on");
    add_line(modelName, getBlockName(andPath) + "/1", ...
        getBlockName(convPath) + "/1", "autorouting", "on");
    add_line(modelName, getBlockName(convPath) + "/1", ...
        getBlockName(termPath) + "/1", "autorouting", "on");

    markBlockOutport(andPath, 1, "phase_select_ton_trunc_raw" + phase);
    markBlockOutport(convPath, 1, "ton_truncate" + phase);
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
