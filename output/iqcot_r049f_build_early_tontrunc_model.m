function modelFile = iqcot_r049f_build_early_tontrunc_model()
%IQCOT_R049F_BUILD_EARLY_TONTRUNC_MODEL Build the R049F trigger-timing copy.
%
% R049F diagnoses whether the R049E failure came from late over-voltage
% triggering.  It copies the completed R049E model, then reconfigures the
% existing Ton-truncation global flag from:
%
%   after_load_step AND before_window_end AND over_voltage
%
% to:
%
%   after_load_step AND before_window_end
%
% A0 rows disable the action by using a negative window.  A2 rows use a short
% load-step-synchronous window.  No raw .slx XML is edited.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049e_tontrunc_holdout";
dstModelName = "four_phase_iek_pr_ecb_control_r049f_early_tontrunc";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049E Ton-truncation hold-out model not found: %s", srcModel);
end

closeIfLoaded(srcModelName);
closeIfLoaded(dstModelName);
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(srcRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

globalPath = dstModelName + "/R049C_TonTrunc_Global";
ports = get_param(globalPath, "PortHandles");
if numel(ports.Inport) >= 3
    line3 = get_param(ports.Inport(3), "Line");
    if line3 ~= -1
        delete_line(line3);
    end
end
set_param(globalPath, "Inputs", "2");

deleteBlockIfExists(dstModelName + "/R049C_OV_For_TonTrunc");
deleteBlockIfExists(dstModelName + "/R049C_OV_Threshold");

ports = get_param(globalPath, "PortHandles");
lineOut = get_param(ports.Outport(1), "Line");
if lineOut ~= -1
    set_param(lineOut, "Name", "early_ton_trunc_global_raw");
end

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

save_system(dstModelName, modelFile);
fprintf("R049F_EARLY_TONTRUNC_MODEL=%s\n", modelFile);
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
