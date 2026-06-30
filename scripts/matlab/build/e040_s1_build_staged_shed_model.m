function modelFile = e040_s1_build_staged_shed_model(variant)
%e040_s1_build_staged_shed_model Build E040-S1 staged shed-handoff models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "S1-R0";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
modelName = e040S1ModelName(variant);
modelFile = fullfile(derivedRoot, modelName + ".slx");
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");

if ~isfile(baselineModel)
    error("Baseline model not found: %s", baselineModel);
end
if ~exist(derivedRoot, "dir")
    mkdir(derivedRoot);
end
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

if bdIsLoaded(modelName)
    close_system(modelName, 0);
end
copyfile(baselineModel, modelFile, "f");

load_system(modelFile);
cleanup = onCleanup(@() close_system(modelName, 0));

replaceStaticLoadWithCurrentSource(modelName);
addCurrentSenseLogs(modelName);
addE040StagedShedSupervisor(modelName);
addPhaseGateEnableMasks(modelName);
addRequiredAuditLogs(modelName);
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.52e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E040_S1_%s_DERIVED_MODEL=%s\n", erase(variant, "-"), modelFile);
end

function modelName = e040S1ModelName(variant)
if variant == "S1-R0"
    modelName = "E040S1_R0_fixed4_iqcot_20260630";
elseif variant == "S1-R1"
    modelName = "E040S1_R1_immed_shed_iqcot_20260630";
elseif variant == "S1-R2"
    modelName = "E040S1_R2_transfer_drain_iqcot_20260630";
elseif variant == "S1-R3"
    modelName = "E040S1_R3_commit_relock_iqcot_20260630";
else
    error("Unknown E040-S1 variant: %s", variant);
end
end

function replaceStaticLoadWithCurrentSource(modelName)
load_system("spsControlledCurrentSourceLib");
oldLoad = modelName + "/Series RLC Branch8";
if isempty(find_system(modelName, "SearchDepth", 1, "Name", "Series RLC Branch8"))
    error("Expected static load block not found: %s", oldLoad);
end
oldPosition = get_param(oldLoad, "Position");
replace_block(modelName, "SearchDepth", 1, "Name", "Series RLC Branch8", ...
    "spsControlledCurrentSourceLib/Controlled Current Source", "noprompt");
ccs = find_system(modelName, "SearchDepth", 1, "MaskType", "Controlled Current Source");
if isempty(ccs)
    error("Controlled Current Source replacement failed.");
end
ccsPath = string(ccs{1});
set_param(ccsPath, "Name", "E040_Load_Current_Source");
ccsPath = modelName + "/E040_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E040_LoadCurrentStep";
deleteBlockIfExists(stepBlock);
stepPosition = [oldPosition(1)-260 oldPosition(2)+30 oldPosition(1)-170 oldPosition(2)+60];
add_block("simulink/Sources/Step", stepBlock, ...
    "Position", stepPosition, ...
    "Time", "t_load_step", ...
    "Before", "Iload_initial", ...
    "After", "Iload_final", ...
    "SampleTime", "0");
connectBlocks(stepBlock, 1, ccsPath, 1);
markBlockOutport(stepBlock, 1, "Iload");
end

function addCurrentSenseLogs(modelName)
for phase = 1:4
    fromBlock = modelName + "/E040_IL_Sense_From" + phase;
    gainBlock = modelName + "/E040_IL_Sense_Gain_Block" + phase;
    termBlock = modelName + "/E040_IL_Sense_Term" + phase;
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(gainBlock);
    deleteBlockIfExists(fromBlock);

    y = 980 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "IL" + phase, "Position", [3520 y 3580 y+28]);
    add_block("simulink/Math Operations/Gain", gainBlock, ...
        "Gain", "E040_IL_Sense_Gain" + phase, ...
        "Position", [3640 y 3725 y+28]);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [3820 y+2 3840 y+26]);
    connectBlocks(fromBlock, 1, gainBlock, 1);
    connectBlocks(gainBlock, 1, termBlock, 1);
    markBlockOutport(gainBlock, 1, "IL_sense" + phase);
end
end

function addE040StagedShedSupervisor(modelName)
ctrlBlock = modelName + "/E040_S1_StagedShedSupervisor";
deleteBlockIfExists(ctrlBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", ctrlBlock, ...
    "Position", [3920 980 4300 1270]);
setE040SupervisorScript(ctrlBlock);

clockBlock = modelName + "/E040_S1_Supervisor_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3540 1340 3580 1370]);

constNames = [
    "E040_LoadStep_Time", "E040_Variant_Mode", "E040_I_Shed_Low", "E040_Dwell_Time", ...
    "E040_Post_Reentry_Shed_Delay", "E040_Vref", "E040_Severe_Overshoot_Band", ...
    "E040_Current_Limit_A", "E040_TonDiff_Enable", "E040_K_T", ...
    "E040_Fallback_K_T", "E040_T_Trim_Max", "E040_Current_Deadband", ...
    "E040_Sense_Confidence", "E040_Calibration_Enable", ...
    "E040_V_Error_Budget", "E040_V_Error_Hard_Limit", "E040_Min_Scale", ...
    "E040_Residual_Current_Threshold", "E040_Order_Relock_Window", ...
    "E040_Shed_Transfer_Rate", "E040_Shed_Transfer_Window", ...
    "E040_Max_Transfer_Ton_Trim", "E040_Remaining_Phase_Current_Limit", ...
    "E040_Disabled_Phase_Drain_Timeout", "E040_Shed_Undershoot_Budget", ...
    "E040_Post_Shed_AS_Delay", "E040_Shed_Fallback_Enable", ...
    "E040_Shed_Commit_Boundary_Policy"];
for idx = 1:numel(constNames)
    block = modelName + "/" + constNames(idx);
    ensureConstantBlock(block, constNames(idx), [3520 1110+34*idx 3760 1132+34*idx]);
end

rawReqTags = ["tr1", "tr2", "tr3", "tr4"];
oldReqFromBlocks = ["From23", "From24", "From25", "From26"];
for phase = 1:4
    rawReqFrom = modelName + "/E040_Raw_REQ_From" + phase;
    deleteBlockIfExists(rawReqFrom);
    add_block("simulink/Signal Routing/From", rawReqFrom, ...
        "GotoTag", rawReqTags(phase), "Position", [3540 900+45*phase 3600 928+45*phase]);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 1);
    deleteBlockIfExists(modelName + "/" + oldReqFromBlocks(phase));
    connectBlocks(rawReqFrom, 1, ctrlBlock, phase);
    connectBlocks(ctrlBlock, phase, modelName + "/COT_Cell_1Phase" + phase, 1);
    markBlockOutport(rawReqFrom, 1, "REQ_raw" + phase);
    markBlockOutport(ctrlBlock, phase, "REQ" + phase);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, ctrlBlock, 4 + phase);
    connectBlocks(ctrlBlock, 4 + phase, modelName + "/COT_Cell_1Phase" + phase, 3);
    markBlockOutport(modelName + "/IQCOT_Ton_Adapter", phase, "Ton_raw" + phase);
    markBlockOutport(ctrlBlock, 4 + phase, "Ton_cmd" + phase);

    connectBlocks(modelName + "/E040_IL_Sense_Gain_Block" + phase, 1, ctrlBlock, 8 + phase);
end

connectBlocks(modelName + "/Voltage Measurement", 1, ctrlBlock, 13);
connectBlocks(modelName + "/E040_LoadCurrentStep", 1, ctrlBlock, 14);
connectBlocks(clockBlock, 1, ctrlBlock, 15);
for idx = 1:numel(constNames)
    connectBlocks(modelName + "/" + constNames(idx), 1, ctrlBlock, 15 + idx);
end

addSupervisorLog(modelName, ctrlBlock, 9, "active_phase_set", [4380 980 4400 1000]);
addSupervisorLog(modelName, ctrlBlock, 10, "N_active", [4380 1010 4400 1030]);
addSupervisorLog(modelName, ctrlBlock, 11, "phase_shed_request", [4380 1040 4400 1060]);
addSupervisorLog(modelName, ctrlBlock, 12, "phase_shed_accept", [4380 1070 4400 1090]);
addSupervisorLog(modelName, ctrlBlock, 13, "phase_shed_reject", [4380 1100 4400 1120]);
addSupervisorLog(modelName, ctrlBlock, 14, "phase_add_request", [4380 1130 4400 1150]);
addSupervisorLog(modelName, ctrlBlock, 15, "shed_state", [4380 1160 4400 1180]);
addSupervisorLog(modelName, ctrlBlock, 16, "shed_lockout_state", [4380 1190 4400 1210]);
addSupervisorLog(modelName, ctrlBlock, 17, "residual_current_i", [4380 1220 4400 1240]);
addSupervisorLog(modelName, ctrlBlock, 18, "residual_current_threshold", [4380 1250 4400 1270]);
addSupervisorLog(modelName, ctrlBlock, 19, "residual_current_check", [4380 1280 4400 1300]);
addSupervisorLog(modelName, ctrlBlock, 20, "dwell_timer", [4380 1310 4400 1330]);
addSupervisorLog(modelName, ctrlBlock, 21, "post_reentry_shed_delay_timer", [4380 1340 4400 1360]);
addSupervisorLog(modelName, ctrlBlock, 22, "protect_state", [4380 1370 4400 1390]);
addSupervisorLog(modelName, ctrlBlock, 23, "reentry_state", [4380 1400 4400 1420]);
addSupervisorLog(modelName, ctrlBlock, 24, "balance_recovery_state", [4380 1430 4400 1450]);
addSupervisorLog(modelName, ctrlBlock, 25, "sense_confidence", [4380 1460 4400 1480]);
addSupervisorLog(modelName, ctrlBlock, 26, "calibration_enable", [4380 1490 4400 1510]);
addSupervisorLog(modelName, ctrlBlock, 27, "a_S_mode", [4380 1520 4400 1540]);
addSupervisorLog(modelName, ctrlBlock, 28, "fallback_count", [4380 1550 4400 1570]);
addSupervisorLog(modelName, ctrlBlock, 29, "guard_clamp_count", [4380 1580 4400 1600]);
for phase = 1:4
    addSupervisorLog(modelName, ctrlBlock, 29 + phase, "Ton_trim" + phase, ...
        [4380 1520+30*phase 4400 1540+30*phase]);
end
for phase = 1:4
    addSupervisorLog(modelName, ctrlBlock, 33 + phase, "REQ_accept" + phase, ...
        [4620 1520+30*phase 4640 1540+30*phase]);
end
auditSignals = [
    "REQ_reject_reason", "logical_slot", "physical_phase_selected", ...
    "phase_shed_reject_reason", ...
    "order_relock_state", "order_relock_window_done", ...
    "phase_order_error_rate_window", "a_S_enable_after_shed", "current_limit_hit"];
for idx = 1:numel(auditSignals)
    addSupervisorLog(modelName, ctrlBlock, 37 + idx, auditSignals(idx), ...
        [4620 1660+30*idx 4640 1680+30*idx]);
end
extraSignals = [
    "shed_transfer_progress", "disabled_phase_current_sum", ...
    "commit_armed", "commit_done", "shed_commit_count", ...
    "fallback_4ph_triggered", "fallback_reason", "fallback_4ph_count", ...
    "residual_current_phase2_A", "residual_current_phase4_A", ...
    "Ton_trim_usage", "Lambda_trim_usage"];
for idx = 1:numel(extraSignals)
    addSupervisorLog(modelName, ctrlBlock, 46 + idx, extraSignals(idx), ...
        [4880 1660+30*idx 4900 1680+30*idx]);
end
for phase = 1:4
    addSupervisorLog(modelName, ctrlBlock, 58 + phase, "phase_gate_enable" + phase, ...
        [5140 1660+30*phase 5160 1680+30*phase]);
end
end

function addPhaseGateEnableMasks(modelName)
ctrlBlock = modelName + "/E040_S1_StagedShedSupervisor";
for phase = 1:4
    insertGateMask(modelName, ctrlBlock, phase, "QH", 1, 58 + phase, ...
        [1760 160+45*phase 1810 190+45*phase]);
    insertGateMask(modelName, ctrlBlock, phase, "QL", 2, 58 + phase, ...
        [1760 420+45*phase 1810 450+45*phase]);
end
end

function insertGateMask(modelName, ctrlBlock, phase, gateKind, gatePort, enablePort, position)
gotoBlock = find_system(modelName, "SearchDepth", 1, "BlockType", "Goto", ...
    "GotoTag", gateKind + phase);
if isempty(gotoBlock)
    error("Expected %s%d Goto block not found.", gateKind, phase);
end
gotoBlock = string(gotoBlock{1});
maskBlock = modelName + "/E040_" + gateKind + phase + "_GateMask";
deleteBlockIfExists(maskBlock);
add_block("simulink/Math Operations/Product", maskBlock, ...
    "Inputs", "**", "Position", position);

gotoPorts = get_param(gotoBlock, "PortHandles");
lineHandle = get_param(gotoPorts.Inport(1), "Line");
if lineHandle ~= -1
    delete_line(lineHandle);
end

connectBlocks(modelName + "/GateDriver_1Phase" + phase, gatePort, maskBlock, 1);
connectBlocks(ctrlBlock, enablePort, maskBlock, 2);
connectBlocks(maskBlock, 1, gotoBlock, 1);
markBlockOutport(maskBlock, 1, gateKind + phase);
end

function addRequiredAuditLogs(modelName)
markBlockOutport(modelName + "/Voltage Measurement", 1, "Vout");
markBlockOutport(modelName + "/PhaseScheduler_4Phase", 5, "phase_idx");
for phase = 1:4
    markBlockOutport(modelName + "/IL_Measurement" + phase, 1, "IL" + phase);
    qhMask = modelName + "/E040_QH" + phase + "_GateMask";
    qlMask = modelName + "/E040_QL" + phase + "_GateMask";
    if blockExists(qhMask)
        markBlockOutport(qhMask, 1, "QH" + phase);
    else
        markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 1, "QH" + phase);
    end
    if blockExists(qlMask)
        markBlockOutport(qlMask, 1, "QL" + phase);
    else
        markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 2, "QL" + phase);
    end
end
addFromLog(modelName, "Lambda_i", "Lambda_i", [3720 620 3795 648]);
addFromLog(modelName, "A_iqcot", "area_int_i", [3720 665 3795 693]);
end

function addFromLog(modelName, tagName, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E040_Log_" + safeName + "_From";
termBlock = modelName + "/E040_Log_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(fromBlock);
add_block("simulink/Signal Routing/From", fromBlock, ...
    "GotoTag", tagName, "Position", position);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
connectBlocks(fromBlock, 1, termBlock, 1);
markBlockOutport(fromBlock, 1, signalName);
end

function addSupervisorLog(modelName, srcBlock, outPort, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
termBlock = modelName + "/E040_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
add_block("simulink/Sinks/Terminator", termBlock, "Position", position);
connectBlocks(srcBlock, outPort, termBlock, 1);
markBlockOutport(srcBlock, outPort, signalName);
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E040_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 735 3760 765]);

for phase = 1:4
    estimator = modelName + "/E040_TonActual" + phase;
    termBlock = modelName + "/E040_TonActual" + phase + "_Term";
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estimator);

    y = 740 + 70 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", estimator, ...
        "Position", [3840 y 4020 y+50]);
    setTonActualScript(estimator);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [4140 y+12 4160 y+38]);

    connectBlocks(modelName + "/GateDriver_1Phase" + phase, 1, estimator, 1);
    connectBlocks(clockBlock, 1, estimator, 2);
    connectBlocks(estimator, 1, termBlock, 1);
    markBlockOutport(estimator, 1, "Ton_actual" + phase);
end
end

function setE040SupervisorScript(blockPath)
script = [
"function [req1o,req2o,req3o,req4o,ton1o,ton2o,ton3o,ton4o,active_phase_set,N_active,phase_shed_request,phase_shed_accept,phase_shed_reject,phase_add_request,shed_state,shed_lockout_state,residual_current_i,residual_current_threshold_o,residual_current_check,dwell_timer,post_reentry_shed_delay_timer,protect_state,reentry_state,balance_recovery_state,sense_confidence_o,calibration_enable_o,a_S_mode,fallback_count_o,guard_clamp_count_o,trim1,trim2,trim3,trim4,REQ_accept1,REQ_accept2,REQ_accept3,REQ_accept4,REQ_reject_reason,logical_slot,physical_phase_selected,phase_shed_reject_reason,order_relock_state,order_relock_window_done,phase_order_error_rate_window,a_S_enable_after_shed,current_limit_hit,shed_transfer_progress,disabled_phase_current_sum,commit_armed,commit_done,shed_commit_count,fallback_4ph_triggered,fallback_reason,fallback_4ph_count,residual_current_phase2_A,residual_current_phase4_A,Ton_trim_usage,Lambda_trim_usage,phase_gate_enable1,phase_gate_enable2,phase_gate_enable3,phase_gate_enable4] = e040_s1_supervisor(req1,req2,req3,req4,ton1,ton2,ton3,ton4,il1,il2,il3,il4,vout,iload,t,t_step,variant_mode,I_shed_low,dwell_time,post_reentry_shed_delay,Vref,severe_overshoot_band,current_limit_A,TonDiff_enable,K_T,fallback_K_T,T_trim_Max,current_deadband,sense_confidence,calibration_enable,Verr_budget,Verr_hard,min_scale,residual_current_threshold,order_relock_window,shed_transfer_rate,shed_transfer_window,max_transfer_Ton_trim,remaining_phase_current_limit_guard,disabled_phase_drain_timeout,shed_undershoot_budget,post_shed_aS_delay,shed_fallback_enable,shed_commit_boundary_policy)"
"%#codegen"
"req = [req1, req2, req3, req4] > 0.5;"
"tons = [ton1, ton2, ton3, ton4];"
"ils = [il1, il2, il3, il4];"
"phase_add_request = 0.0;"
"protect_state = 0.0;"
"reentry_state = 1.0;"
"sense_confidence_o = sense_confidence;"
"calibration_enable_o = calibration_enable;"
"residual_current_threshold_o = residual_current_threshold;"
"residual_current_phase2_A = il2;"
"residual_current_phase4_A = il4;"
"residual_current_i = [0.0, il2, 0.0, il4];"
"disabled_phase_current_sum = abs(il2) + abs(il4);"
"residual_ok = (residual_current_threshold > 0.0) && (abs(il2) <= residual_current_threshold) && (abs(il4) <= residual_current_threshold);"
"residual_current_check = double(residual_ok);"
"age = max(0.0, t - t_step);"
"request_active = (variant_mode > 0.5) && (iload < I_shed_low) && (t >= t_step);"
"phase_shed_request = double(request_active);"
"if request_active"
"    dwell_timer = age;"
"    post_reentry_shed_delay_timer = age;"
"else"
"    dwell_timer = 0.0;"
"    post_reentry_shed_delay_timer = 0.0;"
"end"
"transfer_window = max(shed_transfer_window, 1.0e-9);"
"drain_timeout = max(disabled_phase_drain_timeout, 0.0);"
"drain_deadline_age = transfer_window + drain_timeout;"
"post_transfer_age = max(0.0, age - transfer_window);"
"shed_transfer_progress = 0.0;"
"if request_active"
"    shed_transfer_progress = min(max(age / transfer_window, 0.0), 1.0);"
"end"
"phase2_drained = request_active && (variant_mode >= 2.0) && (shed_transfer_progress >= 0.5) && (residual_current_threshold > 0.0) && (abs(il2) <= residual_current_threshold);"
"phase4_drained = request_active && (variant_mode >= 2.0) && (shed_transfer_progress >= 0.5) && (residual_current_threshold > 0.0) && (abs(il4) <= residual_current_threshold);"
"current_limit_hit = double((current_limit_A > 0.0) && (max(abs(ils)) >= current_limit_A));"
"remaining_peak = max(abs(il1), abs(il3));"
"remaining_headroom_ok = (remaining_phase_current_limit_guard <= 0.0) || (remaining_peak < remaining_phase_current_limit_guard);"
"voltage_ok = (vout >= (Vref - shed_undershoot_budget)) && (vout <= (Vref + severe_overshoot_band));"
"drain_time_ok = (drain_timeout <= 0.0) || (age <= drain_deadline_age);"
"drain_timeout_fail = request_active && (variant_mode >= 3.0) && (age > drain_deadline_age) && ~residual_ok;"
"hard_guard_fail = request_active && (shed_fallback_enable > 0.5) && ((vout < Vref - shed_undershoot_budget) || current_limit_hit > 0.5 || ~remaining_headroom_ok || drain_timeout_fail);"
"fallback_4ph_triggered = double(hard_guard_fail);"
"fallback_4ph_count = fallback_4ph_triggered;"
"fallback_count_o = fallback_4ph_triggered;"
"fallback_reason = 0.0;"
"if hard_guard_fail"
"    if vout < Vref - shed_undershoot_budget"
"        fallback_reason = 1.0;"
"    elseif current_limit_hit > 0.5"
"        fallback_reason = 2.0;"
"    elseif drain_timeout_fail"
"        fallback_reason = 3.0;"
"    elseif ~remaining_headroom_ok"
"        fallback_reason = 5.0;"
"    else"
"        fallback_reason = 6.0;"
"    end"
"end"
"immediate_shed = request_active && (variant_mode >= 1.0) && (variant_mode < 2.0);"
"allow_commit_variant = variant_mode >= 3.0;"
"commit_ready = request_active && allow_commit_variant && (age >= transfer_window) && residual_ok && remaining_headroom_ok && voltage_ok && drain_time_ok && ~hard_guard_fail;"
"commit_hold = request_active && allow_commit_variant && (age >= transfer_window) && remaining_headroom_ok && voltage_ok && ~hard_guard_fail;"
"commit_armed = double(commit_ready || commit_hold || immediate_shed);"
"commit_done = double(commit_hold || immediate_shed);"
"shed_commit_count = commit_done;"
"commit_age = post_transfer_age;"
"order_relock_done = (commit_done > 0.5) && (commit_age >= max(order_relock_window, 0.0));"
"order_relock_window_done = double(order_relock_done);"
"a_S_enable_after_shed = double((variant_mode >= 4.0) && (TonDiff_enable > 0.5) && (commit_done > 0.5) && order_relock_done && residual_ok && voltage_ok && (commit_age >= max(post_shed_aS_delay, 0.0)));"
"balance_enable = a_S_enable_after_shed > 0.5;"
"phase_shed_accept = commit_done;"
"phase_shed_reject = double(request_active && commit_done < 0.5);"
"phase_shed_reject_reason = 0.0;"
"if phase_shed_reject > 0.5"
"    if hard_guard_fail"
"        phase_shed_reject_reason = fallback_reason;"
"    elseif age < transfer_window"
"        phase_shed_reject_reason = 2.0;"
"    elseif ~residual_ok"
"        phase_shed_reject_reason = 3.0;"
"    elseif ~remaining_headroom_ok"
"        phase_shed_reject_reason = 5.0;"
"    else"
"        phase_shed_reject_reason = 1.0;"
"    end"
"end"
"if ~request_active"
"    shed_state = 0.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 0.0;"
"elseif hard_guard_fail"
"    shed_state = 9.0;"
"    shed_lockout_state = 1.0;"
"    order_relock_state = 0.0;"
"elseif age < 1.0e-7"
"    shed_state = 1.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 1.0;"
"elseif age < transfer_window"
"    shed_state = 2.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 1.0;"
"elseif immediate_shed"
"    shed_state = 5.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 2.0;"
"elseif age >= transfer_window && (~residual_ok || ~remaining_headroom_ok || ~voltage_ok)"
"    shed_state = 3.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 1.0;"
"elseif variant_mode < 3.0"
"    shed_state = 3.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 1.0;"
"elseif commit_done < 0.5"
"    shed_state = 4.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 1.0;"
"elseif commit_age < 5.0e-8"
"    shed_state = 5.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 2.0;"
"elseif ~order_relock_done"
"    shed_state = 6.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 2.0;"
"elseif balance_enable"
"    shed_state = 7.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 3.0;"
"else"
"    shed_state = 8.0;"
"    shed_lockout_state = 0.0;"
"    order_relock_state = 3.0;"
"end"
"trim = [0.0, 0.0, 0.0, 0.0];"
"if request_active && ~hard_guard_fail && (variant_mode >= 2.0) && (commit_done < 0.5)"
"    p = shed_transfer_progress;"
"    transfer_trim = min(max_transfer_Ton_trim, T_trim_Max);"
"    if transfer_trim < 0.0"
"        transfer_trim = 0.0;"
"    end"
"    trim = [p * transfer_trim, -p * transfer_trim, p * transfer_trim, -p * transfer_trim];"
"end"
"REQ_reject_reason = 0.0;"
"if hard_guard_fail"
"    active_phase_set = [1.0, 1.0, 1.0, 1.0];"
"    N_active = 4.0;"
"    req_out = req;"
"    ton_base = tons;"
"elseif commit_done > 0.5"
"    active_phase_set = [1.0, 0.0, 1.0, 0.0];"
"    N_active = 2.0;"
"    req_out = [req(1) || req(3), false, req(2) || req(4), false];"
"    ton_base = [ton1, 0.0, ton3, 0.0];"
"elseif request_active && (variant_mode >= 2.0) && (age >= transfer_window)"
"    active_phase_set = [1.0, 1.0, 1.0, 1.0];"
"    N_active = 4.0;"
"    req_out = [req(1) || req(3), false, req(2) || req(4), false];"
"    ton_base = [ton1, 0.0, ton3, 0.0];"
"elseif request_active && (variant_mode >= 2.0) && (phase2_drained || phase4_drained)"
"    active_phase_set = [1.0, 1.0, 1.0, 1.0];"
"    N_active = 4.0;"
"    req_out = req;"
"    ton_base = tons;"
"    if phase2_drained"
"        req_out(3) = req_out(3) || req(2);"
"        req_out(2) = false;"
"        ton_base(2) = 0.0;"
"    end"
"    if phase4_drained"
"        req_out(3) = req_out(3) || req(4);"
"        req_out(4) = false;"
"        ton_base(4) = 0.0;"
"    end"
"else"
"    active_phase_set = [1.0, 1.0, 1.0, 1.0];"
"    N_active = 4.0;"
"    req_out = req;"
"    ton_base = tons;"
"end"
"if any(req) && ~any(req_out) && REQ_reject_reason == 0.0"
"    REQ_reject_reason = 1.0;"
"end"
"if req_out(1)"
"    logical_slot = 1.0; physical_phase_selected = 1.0;"
"elseif req_out(2)"
"    logical_slot = 2.0; physical_phase_selected = 2.0;"
"elseif req_out(3)"
"    if commit_done > 0.5"
"        logical_slot = 2.0;"
"    else"
"        logical_slot = 3.0;"
"    end"
"    physical_phase_selected = 3.0;"
"elseif req_out(4)"
"    logical_slot = 4.0; physical_phase_selected = 4.0;"
"else"
"    logical_slot = 0.0; physical_phase_selected = 0.0;"
"end"
"a_S_mode = 0.0;"
"guard_clamp = 0.0;"
"if balance_enable"
"    active_mask = active_phase_set > 0.5;"
"    K_eff = fallback_K_T;"
"    a_S_mode = 1.0;"
"    denom = max(sum(double(active_mask)), 1.0);"
"    avg_i = sum(ils .* double(active_mask)) / denom;"
"    err = (ils - avg_i) .* double(active_mask);"
"    raw = -K_eff .* err;"
"    if max(abs(err)) < current_deadband"
"        raw = [0.0, 0.0, 0.0, 0.0];"
"    end"
"    trim_as = min(max(raw, -T_trim_Max), T_trim_Max);"
"    trim_mean = sum(trim_as .* double(active_mask)) / denom;"
"    trim_as = (trim_as - trim_mean) .* double(active_mask);"
"    trim = trim + trim_as;"
"end"
"ton_out = max([0.0, 0.0, 0.0, 0.0], ton_base + trim);"
"phase_order_error_rate_window = 0.0;"
"balance_recovery_state = double(balance_enable);"
"Ton_trim_usage = 0.0;"
"if T_trim_Max > 0.0"
"    Ton_trim_usage = max(abs(trim)) / T_trim_Max;"
"end"
"Lambda_trim_usage = 0.0;"
"gate_enable = [1.0, 1.0, 1.0, 1.0];"
"if phase2_drained"
"    gate_enable(2) = 0.0;"
"end"
"if phase4_drained"
"    gate_enable(4) = 0.0;"
"end"
"if (commit_done > 0.5) || immediate_shed"
"    gate_enable = [1.0, 0.0, 1.0, 0.0];"
"end"
"if hard_guard_fail"
"    gate_enable = [1.0, 1.0, 1.0, 1.0];"
"end"
"req1o = req_out(1); req2o = req_out(2); req3o = req_out(3); req4o = req_out(4);"
"ton1o = ton_out(1); ton2o = ton_out(2); ton3o = ton_out(3); ton4o = ton_out(4);"
"guard_clamp_count_o = guard_clamp;"
"trim1 = trim(1); trim2 = trim(2); trim3 = trim(3); trim4 = trim(4);"
"REQ_accept1 = req_out(1); REQ_accept2 = req_out(2); REQ_accept3 = req_out(3); REQ_accept4 = req_out(4);"
"phase_gate_enable1 = gate_enable(1); phase_gate_enable2 = gate_enable(2); phase_gate_enable3 = gate_enable(3); phase_gate_enable4 = gate_enable(4);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["req1", "req2", "req3", "req4", "ton1", "ton2", "ton3", "ton4", ...
    "il1", "il2", "il3", "il4", "vout", "iload", "t", "t_step", "variant_mode", ...
    "I_shed_low", "dwell_time", "post_reentry_shed_delay", "Vref", ...
    "severe_overshoot_band", "current_limit_A", "TonDiff_enable", "K_T", ...
    "fallback_K_T", "T_trim_Max", "current_deadband", "sense_confidence", ...
    "calibration_enable", "Verr_budget", "Verr_hard", "min_scale", ...
    "residual_current_threshold", "order_relock_window", "shed_transfer_rate", ...
    "shed_transfer_window", "max_transfer_Ton_trim", ...
    "remaining_phase_current_limit_guard", "disabled_phase_drain_timeout", ...
    "shed_undershoot_budget", "post_shed_aS_delay", "shed_fallback_enable", ...
    "shed_commit_boundary_policy", ...
    "req1o", "req2o", "req3o", "req4o", "ton1o", "ton2o", "ton3o", ...
    "ton4o", "active_phase_set", "N_active", "phase_shed_request", ...
    "phase_shed_accept", "phase_shed_reject", "phase_add_request", ...
    "shed_state", "shed_lockout_state", "residual_current_i", ...
    "residual_current_threshold_o", "residual_current_check", "dwell_timer", ...
    "post_reentry_shed_delay_timer", "protect_state", "reentry_state", ...
    "balance_recovery_state", "sense_confidence_o", "calibration_enable_o", "a_S_mode", ...
    "fallback_count_o", "guard_clamp_count_o", "trim1", "trim2", "trim3", "trim4", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4", ...
    "REQ_reject_reason", "logical_slot", "physical_phase_selected", ...
    "phase_shed_reject_reason", "order_relock_state", "order_relock_window_done", ...
    "phase_order_error_rate_window", "a_S_enable_after_shed", "current_limit_hit", ...
    "shed_transfer_progress", "disabled_phase_current_sum", "commit_armed", ...
    "commit_done", "shed_commit_count", "fallback_4ph_triggered", ...
    "fallback_reason", "fallback_4ph_count", "residual_current_phase2_A", ...
    "residual_current_phase4_A", "Ton_trim_usage", "Lambda_trim_usage", ...
    "phase_gate_enable1", "phase_gate_enable2", "phase_gate_enable3", ...
    "phase_gate_enable4"], ...
    ["req1", "req2", "req3", "req4", "req1o", "req2o", "req3o", "req4o", ...
    "REQ_accept1", "REQ_accept2", "REQ_accept3", "REQ_accept4"]);
end

function setTonActualScript(blockPath)
script = [
"function Ton_actual = ton_actual_estimator(qh, t)"
"%#codegen"
"persistent q_prev t_rise last_width"
"if isempty(q_prev)"
"    q_prev = 0.0;"
"end"
"if isempty(t_rise)"
"    t_rise = 0.0;"
"end"
"if isempty(last_width)"
"    last_width = 0.0;"
"end"
"is_high = double(qh > 0.5);"
"if is_high > 0.5 && q_prev <= 0.5"
"    t_rise = t;"
"elseif is_high <= 0.5 && q_prev > 0.5"
"    last_width = max(0.0, t - t_rise);"
"end"
"Ton_actual = last_width;"
"q_prev = is_high;"
];
setChartScriptAndTypes(blockPath, script, ["qh", "t", "Ton_actual"], "qh");
end

function setChartScriptAndTypes(blockPath, script, dataNames, booleanNames)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
if contains(string(blockPath), "ActivePhaseSupervisor") || ...
        contains(string(blockPath), "ShedPhaseSupervisor") || ...
        contains(string(blockPath), "StagedShedSupervisor")
    try
        chart.UpdateMethod = "INHERITED";
    catch
    end
    try
        set_param(blockPath, "SampleTime", "-1");
    catch
    end
    try
        set_param(blockPath, "SystemSampleTime", "-1");
    catch
    end
else
    try
        chart.UpdateMethod = "DISCRETE";
        chart.SampleTime = "Ts_ctrl";
    catch
        try
            set_param(blockPath, "SampleTime", "Ts_ctrl");
        catch
        end
    end
    try
        set_param(blockPath, "SystemSampleTime", "Ts_ctrl");
    catch
    end
end
setChartDataTypes(chart, dataNames, booleanNames);
end

function setChartDataTypes(chart, dataNames, booleanNames)
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        if any(dataNames(idx) == booleanNames)
            data.Props.Type.Primitive = "boolean";
        else
            data.Props.Type.Primitive = "double";
        end
    end
end
end

function connectBlocks(srcBlock, srcPort, dstBlock, dstPort)
srcPorts = get_param(srcBlock, "PortHandles");
dstPorts = get_param(dstBlock, "PortHandles");
disconnectInport(dstBlock, dstPort);
srcParent = get_param(srcBlock, "Parent");
dstParent = get_param(dstBlock, "Parent");
if ~strcmp(srcParent, dstParent)
    error("Cannot connect blocks in different parent systems: %s -> %s", srcBlock, dstBlock);
end
add_line(srcParent, srcPorts.Outport(srcPort), dstPorts.Inport(dstPort), "autorouting", "on");
end

function disconnectInport(blockPath, portNumber)
ports = get_param(blockPath, "PortHandles");
lineHandle = get_param(ports.Inport(portNumber), "Line");
if lineHandle ~= -1
    delete_line(lineHandle);
end
end

function markBlockOutport(blockPath, portNumber, signalName)
ports = get_param(blockPath, "PortHandles");
portHandle = ports.Outport(portNumber);
lineHandle = get_param(portHandle, "Line");
if lineHandle ~= -1
    set_param(lineHandle, "Name", char(signalName));
end
Simulink.sdi.markSignalForStreaming(portHandle, "on");
end

function exists = blockExists(blockPath)
try
    get_param(blockPath, "Handle");
    exists = true;
catch
    exists = false;
end
end

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function ensureConstantBlock(blockPath, value, position)
try
    get_param(blockPath, "Handle");
    set_param(blockPath, "Value", value);
catch
    add_block("simulink/Sources/Constant", blockPath, ...
        "Value", value, "Position", position);
end
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end
