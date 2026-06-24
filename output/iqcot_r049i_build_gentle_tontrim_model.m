function modelFile = iqcot_r049i_build_gentle_tontrim_model()
%IQCOT_R049I_BUILD_GENTLE_TONTRIM_MODEL Build gentle phase-selective copy.
%
% R049I copies the completed R049G repaired phase-selective model into a new
% derived `.slx` file.  It does not edit raw `.slx` XML and does not modify the
% original model, R048, or completed R049A-H derived models.
%
% The R049I action is parameter-only in the runner:
%
%   A0: same-model no trim, disabled negative window.
%   A2: early_window AND qh_i, but with a gentler Ton floor selected from the
%       R049G baseline Ton trace audit rather than hard 5 ns.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049g_phase_selective_tontrunc";
dstModelName = "four_phase_iek_pr_ecb_control_r049i_gentle_tontrim";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049G repaired phase-selective model not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

verifyInheritedR049GStructure(dstModelName);

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049I_GENTLE_TONTRIM_MODEL=%s\n", modelFile);
end

function verifyInheritedR049GStructure(modelName)
afterPath = modelName + "/R049C_After_LoadStep";
ports = get_param(afterPath, "PortHandles");
if numel(ports.Inport) < 2
    error("Expected two input ports on %s.", afterPath);
end
line2 = get_param(ports.Inport(2), "Line");
if line2 == -1
    error("R049I inherited model is missing R049C_After_LoadStep/2 lower-bound connection.");
end
src = get_param(line2, "SrcBlockHandle");
srcName = string(getfullname(src));
if ~contains(srcName, "R049G_LoadStep_Time")
    error("Unexpected R049C_After_LoadStep/2 source: %s", srcName);
end

for phase = 1:4
    guardPath = modelName + "/R049G_PhaseSelective_TonTrunc" + phase;
    switchPath = modelName + "/R049C_Ton_Switch" + phase;
    guardPorts = get_param(guardPath, "PortHandles");
    switchPorts = get_param(switchPath, "PortHandles");
    if isempty(guardPorts.Outport) || numel(switchPorts.Inport) < 2
        error("Missing inherited guard or Ton switch ports for phase %d.", phase);
    end
    controlLine = get_param(switchPorts.Inport(2), "Line");
    if controlLine == -1
        error("R049C_Ton_Switch%d control input is unconnected.", phase);
    end
    controlSrc = get_param(controlLine, "SrcBlockHandle");
    if string(getfullname(controlSrc)) ~= guardPath
        error("R049C_Ton_Switch%d is not driven by inherited phase-selective guard.", phase);
    end
end
end

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
