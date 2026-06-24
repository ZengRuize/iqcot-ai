function modelFile = iqcot_build_iek_perphase_model()
%IQCOT_BUILD_IEK_PERPHASE_MODEL Build a per-phase IEK request copy.
% This copy implements an event integrand close to the IQCOT form:
%   h_i = Varea_bias + e_v + Ri_area * (Iph - IL_i)
% and compares the selected phase area with Lambda_i.

srcRoot = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
dstRoot = "E:\Desktop\codex\output\simulink_iek";
if ~exist(dstRoot, "dir")
    mkdir(dstRoot);
end

srcModel = fullfile(srcRoot, "four_phase.slx");
modelName = "four_phase_iek_perphase";
modelFile = fullfile(dstRoot, modelName + ".slx");
copyfile(srcModel, modelFile);

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder));
cd(dstRoot);
load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

reqPath = modelName + "/IEK_PerPhase_Request";
if ~isempty(find_system(modelName, "SearchDepth", 1, "Name", "IEK_PerPhase_Request"))
    delete_block(reqPath);
end

add_block("simulink/Ports & Subsystems/Subsystem", reqPath, ...
    "Position", [340 1050 690 1320]);
buildPerPhaseSubsystem(reqPath);

connect_blocks(modelName + "/Sum", 1, reqPath, 1);
connect_blocks(modelName + "/From17", 1, reqPath, 2);
connect_blocks(modelName + "/PhaseScheduler_4Phase", 5, reqPath, 3);
for phase = 1:4
    connect_blocks(modelName + "/IL_Measurement" + phase, 1, reqPath, 3 + phase);
end

gotoReq = modelName + "/Goto14";
gotoPorts = get_param(gotoReq, "PortHandles");
oldLine = get_param(gotoPorts.Inport(1), "Line");
if oldLine ~= -1
    delete_line(oldLine);
end
connect_blocks(reqPath, 1, gotoReq, 1);
set_param(modelName + "/Relay", "Commented", "through");

save_system(modelName, modelFile);
fprintf("IEK_PERPHASE_MODEL=%s\n", modelFile);
end

function buildPerPhaseSubsystem(reqPath)
open_system(reqPath);
delete_block_if_exists(reqPath + "/In1");
delete_block_if_exists(reqPath + "/Out1");

add_block("simulink/Ports & Subsystems/In1", reqPath + "/e_v", ...
    "Position", [25 35 55 55], "Port", "1");
add_block("simulink/Ports & Subsystems/In1", reqPath + "/tr_reset", ...
    "Position", [25 90 55 110], "Port", "2");
add_block("simulink/Ports & Subsystems/In1", reqPath + "/phase_idx", ...
    "Position", [25 145 55 165], "Port", "3");
for phase = 1:4
    y = 210 + (phase - 1) * 70;
    add_block("simulink/Ports & Subsystems/In1", reqPath + "/IL" + phase, ...
        "Position", [25 y 55 y+20], "Port", num2str(3 + phase));
end

add_block("simulink/Discrete/Memory", reqPath + "/Reset_Memory", ...
    "Position", [85 82 125 118], "InitialCondition", "0");
add_block("simulink/Discrete/Memory", reqPath + "/PhaseIdx_Memory", ...
    "Position", [85 137 125 173], "InitialCondition", "0");

add_block("simulink/Signal Routing/Multiport Switch", reqPath + "/Selected_REQ", ...
    "Position", [760 170 820 290], "Inputs", "4", ...
    "DataPortOrder", "Zero-based contiguous", "DiagnosticForDefault", "None");
add_block("simulink/Ports & Subsystems/Out1", reqPath + "/REQ_iek", ...
    "Position", [875 220 905 240], "Port", "1");

add_line(reqPath, "tr_reset/1", "Reset_Memory/1", "autorouting", "on");
add_line(reqPath, "phase_idx/1", "PhaseIdx_Memory/1", "autorouting", "on");
add_line(reqPath, "PhaseIdx_Memory/1", "Selected_REQ/1", "autorouting", "on");
add_line(reqPath, "Selected_REQ/1", "REQ_iek/1", "autorouting", "on");

for phase = 1:4
    y = 210 + (phase - 1) * 70;
    suffix = num2str(phase);
    patternSign = "+";
    if phase == 2 || phase == 4
        patternSign = "-";
    end

    add_block("simulink/Sources/Constant", reqPath + "/Iph" + suffix, ...
        "Position", [95 y-2 135 y+22], "Value", "Iph");
    add_block("simulink/Math Operations/Sum", reqPath + "/Ierr" + suffix, ...
        "Position", [165 y-5 190 y+25], "Inputs", "+-");
    add_block("simulink/Math Operations/Gain", reqPath + "/Ri_area" + suffix, ...
        "Position", [220 y-5 285 y+25], "Gain", "Ri_area");
    add_block("simulink/Sources/Constant", reqPath + "/Vbias" + suffix, ...
        "Position", [220 y-42 285 y-18], "Value", "Varea_bias");
    add_block("simulink/Math Operations/Sum", reqPath + "/h_i" + suffix, ...
        "Position", [330 y-15 360 y+35], "Inputs", "+++");
    add_block("simulink/Continuous/Integrator", reqPath + "/Area" + suffix, ...
        "Position", [400 y-5 440 y+25], "InitialCondition", "0", "ExternalReset", "rising");
    add_block("simulink/Sources/Constant", reqPath + "/Lambda" + suffix, ...
        "Position", [475 y+30 565 y+54], "Value", "Lambda_area " + patternSign + " Lambda_m2");
    add_block("simulink/Logic and Bit Operations/Relational Operator", reqPath + "/Area_ge_Lambda" + suffix, ...
        "Position", [600 y-5 650 y+35], "Operator", ">=", "OutDataTypeStr", "boolean");

    add_line(reqPath, "Iph" + suffix + "/1", "Ierr" + suffix + "/1", "autorouting", "on");
    add_line(reqPath, "IL" + suffix + "/1", "Ierr" + suffix + "/2", "autorouting", "on");
    add_line(reqPath, "Ierr" + suffix + "/1", "Ri_area" + suffix + "/1", "autorouting", "on");
    add_line(reqPath, "e_v/1", "h_i" + suffix + "/1", "autorouting", "on");
    add_line(reqPath, "Ri_area" + suffix + "/1", "h_i" + suffix + "/2", "autorouting", "on");
    add_line(reqPath, "Vbias" + suffix + "/1", "h_i" + suffix + "/3", "autorouting", "on");
    add_line(reqPath, "h_i" + suffix + "/1", "Area" + suffix + "/1", "autorouting", "on");
    add_line(reqPath, "Reset_Memory/1", "Area" + suffix + "/2", "autorouting", "on");
    add_line(reqPath, "Area" + suffix + "/1", "Area_ge_Lambda" + suffix + "/1", "autorouting", "on");
    add_line(reqPath, "Lambda" + suffix + "/1", "Area_ge_Lambda" + suffix + "/2", "autorouting", "on");
    add_line(reqPath, "Area_ge_Lambda" + suffix + "/1", "Selected_REQ/" + num2str(phase + 1), "autorouting", "on");
end
close_system(reqPath);
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
