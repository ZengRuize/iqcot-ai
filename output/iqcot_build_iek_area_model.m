function modelFile = iqcot_build_iek_area_model()
%IQCOT_BUILD_IEK_AREA_MODEL Build a non-destructive IEK request variant.
% The original user model is copied first. The copy replaces the hysteretic
% Relay request with an area-integral request while preserving global
% blanking, rise detection, phase scheduler, COT cells, and power stage.

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
dstRoot = "E:\Desktop\codex\output\simulink_iek";
if ~exist(dstRoot, "dir")
    mkdir(dstRoot);
end

srcModel = fullfile(srcRoot, "four_phase.slx");
modelName = "four_phase_iek_area";
modelFile = fullfile(dstRoot, modelName + ".slx");
copyfile(srcModel, modelFile);

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(dstRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

areaPath = modelName + "/IEK_Area_Request";
if ~isempty(find_system(modelName, "SearchDepth", 1, "Name", "IEK_Area_Request"))
    delete_block(areaPath);
end

add_block("simulink/Ports & Subsystems/Subsystem", areaPath, ...
    "Position", [360 1110 620 1260]);
buildAreaSubsystem(areaPath);

% Branch the existing error signal into the area request.
connect_blocks(modelName + "/Sum", 1, areaPath, 1);

% Reset the area integrator on the actual accepted trigger, not on raw REQ.
connect_blocks(modelName + "/From17", 1, areaPath, 2);

% Use the scheduler state as a phase-index proxy for differential threshold.
connect_blocks(modelName + "/PhaseScheduler_4Phase", 5, areaPath, 3);

% Replace Relay -> REQ Goto with AreaRequest -> REQ Goto.
gotoReq = modelName + "/Goto14";
gotoPorts = get_param(gotoReq, "PortHandles");
oldLine = get_param(gotoPorts.Inport(1), "Line");
if oldLine ~= -1
    delete_line(oldLine);
end
connect_blocks(areaPath, 1, gotoReq, 1);

% Keep the original Relay block in place but disconnected for comparison.
set_param(modelName + "/Relay", "Commented", "through");

save_system(modelName, modelFile);
fprintf("IEK_AREA_MODEL=%s\n", modelFile);
end

function buildAreaSubsystem(areaPath)
open_system(areaPath);
delete_block_if_exists(areaPath + "/In1");
delete_block_if_exists(areaPath + "/Out1");

add_block("simulink/Ports & Subsystems/In1", areaPath + "/e_v", ...
    "Position", [25 35 55 55], "Port", "1");
add_block("simulink/Ports & Subsystems/In1", areaPath + "/tr_reset", ...
    "Position", [25 95 55 115], "Port", "2");
add_block("simulink/Ports & Subsystems/In1", areaPath + "/phase_idx", ...
    "Position", [25 155 55 175], "Port", "3");

add_block("simulink/Discrete/Memory", areaPath + "/Reset_Memory", ...
    "Position", [92 88 132 122], "InitialCondition", "0");
add_block("simulink/Discrete/Memory", areaPath + "/PhaseIdx_Memory", ...
    "Position", [92 148 132 182], "InitialCondition", "0");

add_block("simulink/Discontinuities/Saturation", areaPath + "/Positive_Error", ...
    "Position", [95 28 170 62], "LowerLimit", "0", "UpperLimit", "inf");
add_block("simulink/Continuous/Integrator", areaPath + "/Area_Integrator", ...
    "Position", [205 30 245 60], "InitialCondition", "0", "ExternalReset", "rising");

add_block("simulink/User-Defined Functions/Fcn", areaPath + "/Lambda_m2_selector", ...
    "Position", [175 145 350 185], ...
    "Expr", "Lambda_area + Lambda_m2*cos(3.141592653589793*u)");

add_block("simulink/Logic and Bit Operations/Relational Operator", areaPath + "/Area_ge_Lambda", ...
    "Position", [310 70 355 110], "Operator", ">=", "OutDataTypeStr", "boolean");
add_block("simulink/Ports & Subsystems/Out1", areaPath + "/REQ_area", ...
    "Position", [410 82 440 102], "Port", "1");

add_line(areaPath, "e_v/1", "Positive_Error/1", "autorouting", "on");
add_line(areaPath, "Positive_Error/1", "Area_Integrator/1", "autorouting", "on");
add_line(areaPath, "tr_reset/1", "Reset_Memory/1", "autorouting", "on");
add_line(areaPath, "Reset_Memory/1", "Area_Integrator/2", "autorouting", "on");
add_line(areaPath, "phase_idx/1", "PhaseIdx_Memory/1", "autorouting", "on");
add_line(areaPath, "PhaseIdx_Memory/1", "Lambda_m2_selector/1", "autorouting", "on");
add_line(areaPath, "Area_Integrator/1", "Area_ge_Lambda/1", "autorouting", "on");
add_line(areaPath, "Lambda_m2_selector/1", "Area_ge_Lambda/2", "autorouting", "on");
add_line(areaPath, "Area_ge_Lambda/1", "REQ_area/1", "autorouting", "on");
close_system(areaPath);
end

function connect_blocks(srcBlock, srcPort, dstBlock, dstPort)
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

function delete_block_if_exists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end
