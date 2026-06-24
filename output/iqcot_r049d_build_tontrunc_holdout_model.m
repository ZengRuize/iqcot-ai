function modelFile = iqcot_r049d_build_tontrunc_holdout_model()
%IQCOT_R049D_BUILD_TONTRUNC_HOLDOUT_MODEL Build the R049D hold-out model copy.
%
% R049D must not modify the completed R049C model.  This helper creates a new
% derived .slx copy that preserves the R049C command-path Ton-truncation
% mechanism, then uses the copy for the 40A->10A hold-out validation.

srcRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_pr_ecb_control_r049c_tontrunc";
dstModelName = "four_phase_iek_pr_ecb_control_r049d_tontrunc_holdout";

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(srcRoot, dstModelName + ".slx");

if ~exist(srcModel, "file")
    error("R049C Ton-truncation model not found: %s", srcModel);
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

save_system(dstModelName, modelFile);
fprintf("R049D_TONTRUNC_HOLDOUT_MODEL=%s\n", modelFile);
end

function closeIfLoaded(modelName)
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
end
