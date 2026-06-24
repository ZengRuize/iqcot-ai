function modelFile = iqcot_build_iek_perphase_trim_model()
%IQCOT_BUILD_IEK_PERPHASE_TRIM_MODEL Build a per-phase IEK copy with direct trims.
%
% The source model is already a derived Simulink copy, not the user's
% original four_phase.slx.  This script creates another copy that exposes
% Lambda1..Lambda4 and Ton_trim1..Ton_trim4 as workspace variables for
% finite-difference Jacobian validation.

modelRoot = "E:\Desktop\codex\output\simulink_iek";
srcModel = fullfile(modelRoot, "four_phase_iek_perphase.slx");
modelName = "four_phase_iek_perphase_trim";
modelFile = fullfile(modelRoot, modelName + ".slx");

copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(modelRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

% Expose the four area thresholds independently.
for phase = 1:4
    set_param(modelName + "/IEK_PerPhase_Request/Lambda" + phase, ...
        "Value", "Lambda" + phase);
end

% Add direct per-phase on-time trim constants into the existing IQCOT adapter.
adapter = modelName + "/IQCOT_Ton_Adapter";
for phase = 1:4
    trimName = "Ton_trim" + phase;
    trimPath = adapter + "/" + trimName;
    sumPath = adapter + "/Ton_Sum" + phase;
    if isempty(find_system(adapter, "SearchDepth", 1, "Name", trimName))
        y0 = 30 + (phase - 1) * 130;
        add_block("simulink/Sources/Constant", trimPath, ...
            "Position", [425 y0+55 500 y0+85], ...
            "Value", trimName);
    else
        set_param(trimPath, "Value", trimName);
    end
    set_param(sumPath, "Inputs", "+++");
    connectToPort(trimPath, 1, sumPath, 3);
end

save_system(modelName, modelFile);
fprintf("IEK_PERPHASE_TRIM_MODEL=%s\n", modelFile);
end

function connectToPort(srcBlock, srcPort, dstBlock, dstPort)
srcPorts = get_param(srcBlock, "PortHandles");
dstPorts = get_param(dstBlock, "PortHandles");
dstLine = get_param(dstPorts.Inport(dstPort), "Line");
if dstLine ~= -1
    srcHandle = get_param(dstLine, "SrcBlockHandle");
    if srcHandle == get_param(srcBlock, "Handle")
        return;
    end
    delete_line(dstLine);
end
srcParent = get_param(srcBlock, "Parent");
dstParent = get_param(dstBlock, "Parent");
if srcParent ~= dstParent
    error("Cannot connect blocks in different parent systems: %s -> %s", srcBlock, dstBlock);
end
add_line(srcParent, srcPorts.Outport(srcPort), dstPorts.Inport(dstPort), "autorouting", "on");
end
