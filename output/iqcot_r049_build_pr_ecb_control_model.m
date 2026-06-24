function modelFile = iqcot_r049_build_pr_ecb_control_model()
%IQCOT_R049_BUILD_PR_ECB_CONTROL_MODEL Build the first PR-ECB control scaffold.
%
% R049A creates a derived copy of the already-derived
% four_phase_iek_dynamic_load_refslew.slx model.  It does not modify the
% original user model or the R048 source model.  The copy persists logging taps
% needed for the next smallest PR-ECB cut-load validation chunk and adds
% no-op protection-token placeholders.  These placeholders are intentionally
% disconnected from the plant/control path; they document and log the future
% interface without claiming protection performance.

srcRoot = "E:\Desktop\codex\output\simulink_iek";
dstRoot = "E:\Desktop\codex\output\cutload_pr_ecb_control";
srcModelName = "four_phase_iek_dynamic_load_refslew";
dstModelName = "four_phase_iek_pr_ecb_control";

if ~exist(dstRoot, "dir")
    mkdir(dstRoot);
end

srcModel = fullfile(srcRoot, srcModelName + ".slx");
modelFile = fullfile(dstRoot, dstModelName + ".slx");

if bdIsLoaded(dstModelName)
    close_system(dstModelName, 0);
end
copyfile(srcModel, modelFile, "f");

oldFolder = pwd;
folderCleanup = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
cd(dstRoot);

load_system(modelFile);
cleanup = onCleanup(@() close_system(dstModelName, 0)); %#ok<NASGU>

set_param(dstModelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "MaxStep", "max_step_cont");

% Persist the core R048 logging surface.
markBlockOutport(dstModelName + "/Voltage Measurement", 1, "vout");
markInportLine(dstModelName + "/Goto14", 1, "req_global");
markBlockOutport(dstModelName + "/PhaseScheduler_4Phase", 5, "phase_idx");

for phase = 1:4
    markBlockOutport(dstModelName + "/IL_Measurement" + phase, 1, "il" + phase);
    markBlockOutport(dstModelName + "/GateDriver_1Phase" + phase, 1, "qh" + phase);
    markBlockOutport(dstModelName + "/GateDriver_1Phase" + phase, 2, "ql" + phase);
    markBlockOutport(dstModelName + "/IQCOT_Ton_Adapter", phase, "ton_iqcot" + phase);

    % Expose currently-unused COT diagnostics through terminators so they can
    % be streamed by logsout without changing control behavior.
    exposeAndLogOutport( ...
        dstModelName + "/COT_Cell_1Phase" + phase, 2, ...
        dstModelName + "/R049_TonDone_Term" + phase, ...
        "ton_done" + phase, phase, 0);
    exposeAndLogOutport( ...
        dstModelName + "/COT_Cell_1Phase" + phase, 3, ...
        dstModelName + "/R049_NQmin_Term" + phase, ...
        "nqmin" + phase, phase, 1);
    exposeAndLogOutport( ...
        dstModelName + "/COT_Cell_1Phase" + phase, 4, ...
        dstModelName + "/R049_CurrentLimit_Term" + phase, ...
        "current_limit" + phase, phase, 2);
end

% Add no-op protection-token placeholders for the future PR-ECB protector.
% They are logged but not connected into the plant or IQCOT inner loop.
addLoggedConstant(dstModelName, "R049_protect_state_stub", "0", "protect_state", 1420, 40);
addLoggedConstant(dstModelName, "R049_rp_stub", "0", "r_p", 1420, 90);
for phase = 1:4
    yBase = 160 + (phase - 1) * 170;
    addLoggedConstant(dstModelName, "R049_ton_truncate_stub" + phase, "0", ...
        "ton_truncate" + phase, 1420, yBase);
    addLoggedConstant(dstModelName, "R049_pulse_inhibit_stub" + phase, "0", ...
        "pulse_inhibit" + phase, 1420, yBase + 40);
    addLoggedConstant(dstModelName, "R049_hold_int_stub" + phase, "0", ...
        "hold_int" + phase, 1420, yBase + 80);
    addLoggedConstant(dstModelName, "R049_reset_int_stub" + phase, "0", ...
        "reset_int" + phase, 1420, yBase + 120);
end

save_system(dstModelName, modelFile);
fprintf("R049_PR_ECB_CONTROL_MODEL=%s\n", modelFile);
end

function markBlockOutport(blockPath, outportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Outport) < outportNumber
    error("Missing outport %d on %s", outportNumber, blockPath);
end
portHandle = ports.Outport(outportNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle == -1
    error("Outport %d on %s has no line to log", outportNumber, blockPath);
end
markPort(portHandle, signalName);
end

function markInportLine(blockPath, inportNumber, signalName)
ports = get_param(blockPath, "PortHandles");
if numel(ports.Inport) < inportNumber
    error("Missing inport %d on %s", inportNumber, blockPath);
end
lineHandle = get_param(ports.Inport(inportNumber), "Line");
if lineHandle == -1
    error("Inport %d on %s has no incoming line to log", inportNumber, blockPath);
end
srcPortHandle = get_param(lineHandle, "SrcPortHandle");
markPort(srcPortHandle, signalName);
end

function exposeAndLogOutport(srcBlock, srcPort, termPath, signalName, phase, slot)
ports = get_param(srcBlock, "PortHandles");
if numel(ports.Outport) < srcPort
    error("Missing outport %d on %s", srcPort, srcBlock);
end
lineHandle = get_param(ports.Outport(srcPort), "Line");
if lineHandle == -1
    parent = get_param(srcBlock, "Parent");
    if isempty(find_system(parent, "SearchDepth", 1, "Name", getBlockName(termPath)))
        x0 = 1040 + slot * 120;
        y0 = 860 + (phase - 1) * 130;
        add_block("simulink/Sinks/Terminator", termPath, ...
            "Position", [x0 y0 x0+30 y0+20]);
    end
    termPorts = get_param(termPath, "PortHandles");
    add_line(parent, ports.Outport(srcPort), termPorts.Inport(1), "autorouting", "on");
end
markPort(ports.Outport(srcPort), signalName);
end

function addLoggedConstant(modelName, constName, value, signalName, x, y)
constPath = modelName + "/" + constName;
termPath = modelName + "/" + constName + "_Term";
deleteBlockIfExists(termPath);
deleteBlockIfExists(constPath);

add_block("simulink/Sources/Constant", constPath, ...
    "Position", [x y x+70 y+24], ...
    "Value", value);
add_block("simulink/Sinks/Terminator", termPath, ...
    "Position", [x+150 y+2 x+180 y+22]);
add_line(modelName, constName + "/1", constName + "_Term/1", "autorouting", "on");

ports = get_param(constPath, "PortHandles");
markPort(ports.Outport(1), signalName);
end

function markPort(portHandle, signalName)
lineHandle = get_param(portHandle, "Line");
set_param(lineHandle, "Name", char(signalName));
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function name = getBlockName(blockPath)
parts = split(string(blockPath), "/");
name = char(parts(end));
end
