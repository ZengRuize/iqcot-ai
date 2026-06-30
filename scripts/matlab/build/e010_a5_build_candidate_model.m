function modelFile = e010_a5_build_candidate_model(variant)
%E010_A5_BUILD_CANDIDATE_MODEL Build A5-T1/T2/T3/T4 candidate models.
% The ideal IQCOT baseline is copied first. Candidate edits are confined to
% projected Ton scheduling, REQ acceptance, and IQCOT request enable gating.

if nargin < 1
    variant = "A5-T1";
end
variant = string(variant);

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", ...
    "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
dateTag = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));

if variant == "A5-T1"
    modelName = "E010A5_T1_severe_ton_trunc_40A_1A_" + dateTag;
elseif variant == "A5-T2"
    modelName = "E010A5_T2_trunc_one_inhibit_40A_1A_" + dateTag;
elseif variant == "A5-T3"
    modelName = "E010A5_T3_trunc_multi_area_hold_40A_1A_" + dateTag;
elseif variant == "A5-T4"
    modelName = "E010A5_T4_full_severe_token_40A_1A_" + dateTag;
elseif variant == "A5-T4-R1a"
    modelName = "E010A5_T4_R1a_burst_limiter_40A_1A_" + dateTag;
elseif variant == "A5-T4-R1b"
    modelName = "E010A5_T4_R1b_burst_area_clamp_40A_1A_" + dateTag;
elseif variant == "A5-T4-R1c"
    modelName = "E010A5_T4_R1c_burst_clamp_ton_ramp_40A_1A_" + dateTag;
elseif variant == "A5-R2-E1"
    modelName = "E010A5_R2_E1_energy_ton_ramp_40A_1A_" + dateTag;
elseif variant == "A5-R2-E2"
    modelName = "E010A5_R2_E2_energy_area_preload_40A_1A_" + dateTag;
elseif variant == "A5-R2-E3"
    modelName = "E010A5_R2_E3_scheduler_release_40A_1A_" + dateTag;
elseif variant == "A5-R2-E4"
    modelName = "E010A5_R2_E4_voltage_window_release_40A_1A_" + dateTag;
else
    error("Unknown E010-A5 candidate variant: %s", variant);
end
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
addFixedFourPhaseLog(modelName);
addCurrentSenseLogs(modelName);
addRequiredBaseLogs(modelName);
addActiveHsPhaseLog(modelName);
addCurrentLimitLog(modelName);

addTonTruncation(modelName);
if variant == "A5-T1"
    addAcceptedReqPassthroughLogs(modelName);
    addScalarConstantLog(modelName, "pulse_inhibit_state", "0", [3720 1295 3830 1325]);
else
    addPulseInhibit(modelName);
end
addAreaHoldEnableProjection(modelName);
if startsWith(variant, "A5-T4-R1")
    addR1ControlledReentryBurstLimiter(modelName);
    if variant == "A5-T4-R1c"
        addR1RecoveryTonRamp(modelName);
    else
        addScalarConstantLog(modelName, "recovery_Ton_ramp_usage", "0", ...
            [4080 2045 4260 2075]);
    end
elseif startsWith(variant, "A5-R2")
    addR2EnergyShaping(modelName);
    if variant == "A5-R2-E3" || variant == "A5-R2-E4"
        addR2SchedulerReleaseGate(modelName);
    else
        addScalarConstantLog(modelName, "scheduler_release_gate_active", "0", ...
            [4080 2310 4260 2340]);
    end
end

addReqRejectReasonLog(modelName);
addPhaseOrderErrorLog(modelName);
addSevereDropDetector(modelName, variant);
addAuditStateConstants(modelName, variant);
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.54e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E010_A5_%s_DERIVED_MODEL=%s\n", erase(variant, "-"), modelFile);
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
set_param(ccsPath, "Name", "E010A5_Load_Current_Source");
ccsPath = modelName + "/E010A5_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E010A5_LoadCurrentStep";
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

function addFixedFourPhaseLog(modelName)
addVectorConstantLog(modelName, "active_phase_set", "[1 1 1 1]", [3720 520 3835 550]);
end

function addCurrentSenseLogs(modelName)
for phase = 1:4
    fromBlock = modelName + "/E010A5_IL_Sense_From" + phase;
    gainBlock = modelName + "/E010A5_IL_Sense_Gain_Block" + phase;
    termBlock = modelName + "/E010A5_IL_Sense_Term" + phase;
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(gainBlock);
    deleteBlockIfExists(fromBlock);

    y = 560 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "IL" + phase, "Position", [3720 y 3780 y+28]);
    add_block("simulink/Math Operations/Gain", gainBlock, ...
        "Gain", "E010A5_IL_Sense_Gain" + phase, ...
        "Position", [3840 y 3930 y+28]);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [4020 y+2 4040 y+26]);
    connectBlocks(fromBlock, 1, gainBlock, 1);
    connectBlocks(gainBlock, 1, termBlock, 1);
    markBlockOutport(gainBlock, 1, "IL_sense" + phase);
end
end

function addRequiredBaseLogs(modelName)
markBlockOutport(modelName + "/Voltage Measurement", 1, "Vout");
markBlockOutport(modelName + "/PhaseScheduler_4Phase", 5, "phase_idx");
for phase = 1:4
    markBlockOutport(modelName + "/IL_Measurement" + phase, 1, "IL" + phase);
    markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 1, "QH" + phase);
    markBlockOutport(modelName + "/GateDriver_1Phase" + phase, 2, "QL" + phase);
    addFromLog(modelName, "tr" + phase, "REQ" + phase, ...
        [3720 760 + 45 * phase 3780 788 + 45 * phase]);
end
addFromLog(modelName, "Lambda_i", "Lambda_i", [3720 990 3795 1018]);
addFromLog(modelName, "A_iqcot", "area_int_i", [3720 1035 3795 1063]);
end

function addActiveHsPhaseLog(modelName)
block = modelName + "/E010A5_ActiveHSPhase";
termBlock = modelName + "/E010A5_ActiveHSPhase_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(block);
add_block("simulink/User-Defined Functions/MATLAB Function", block, ...
    "Position", [4080 560 4275 635]);
setActiveHsPhaseScript(block);
for phase = 1:4
    connectBlocks(modelName + "/GateDriver_1Phase" + phase, 1, block, phase);
end
add_block("simulink/Sinks/Terminator", termBlock, "Position", [4380 590 4400 615]);
connectBlocks(block, 1, termBlock, 1);
markBlockOutport(block, 1, "active_HS_phase");
end

function addCurrentLimitLog(modelName)
block = modelName + "/E010A5_CurrentLimitHit";
termBlock = modelName + "/E010A5_CurrentLimitHit_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(block);
add_block("simulink/User-Defined Functions/MATLAB Function", block, ...
    "Position", [4080 670 4275 745]);
setAnyFourScript(block, "current_limit_hit");
for phase = 1:4
    connectBlocks(modelName + "/COT_Cell_1Phase" + phase, 4, block, phase);
end
add_block("simulink/Sinks/Terminator", termBlock, "Position", [4380 700 4400 725]);
connectBlocks(block, 1, termBlock, 1);
markBlockOutport(block, 1, "current_limit_hit");
end

function markTonCommandLogs(modelName)
for phase = 1:4
    markBlockOutport(modelName + "/IQCOT_Ton_Adapter", phase, "Ton_cmd" + phase);
end
end

function addAcceptedReqPassthroughLogs(modelName)
for phase = 1:4
    fromBlock = modelName + "/E010A5_REQAccept_From" + phase;
    gotoBlock = modelName + "/E010A5_REQAccept_Goto" + phase;
    termBlock = modelName + "/E010A5_REQAccept_Term" + phase;
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(gotoBlock);
    deleteBlockIfExists(fromBlock);
    y = 760 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "tr" + phase, "Position", [4080 y 4140 y+28]);
    add_block("simulink/Signal Routing/Goto", gotoBlock, ...
        "GotoTag", "REQ_accept" + phase, "Position", [4240 y 4290 y+28]);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [4380 y+2 4400 y+26]);
    connectBlocks(fromBlock, 1, gotoBlock, 1);
    connectBlocks(fromBlock, 1, termBlock, 1);
    markBlockOutport(fromBlock, 1, "REQ_accept" + phase);
end
end

function addNoopTonTruncLogs(modelName)
addVectorConstantLog(modelName, "Ton_trunc_i", "[0 0 0 0]", [3720 1095 3835 1125]);
addVectorConstantLog(modelName, "Ton_saved_i", "[0 0 0 0]", [3720 1140 3835 1170]);
end

function addTonTruncation(modelName)
clockBlock = modelName + "/E010A5_TonTrunc_Clock";
enableBlock = modelName + "/E010A5_TonTrunc_Enable";
tstepBlock = modelName + "/E010A5_TonTrunc_LoadStepTime";
windowBlock = modelName + "/E010A5_TonTrunc_Window";
tminBlock = modelName + "/E010A5_TonTrunc_Min";
activeMux = modelName + "/E010A5_TonTrunc_Mux";
savedMux = modelName + "/E010A5_TonSaved_Mux";
activeTerm = modelName + "/E010A5_TonTrunc_Term";
savedTerm = modelName + "/E010A5_TonSaved_Term";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(tminBlock);
deleteBlockIfExists(activeTerm);
deleteBlockIfExists(savedTerm);
deleteBlockIfExists(activeMux);
deleteBlockIfExists(savedMux);

add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 1210 3760 1240]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010_TonTrunc_Enable", "Position", [3720 1260 3850 1285]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [3720 1305 3850 1330]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "Tton_trunc_window", "Position", [3720 1350 3850 1375]);
add_block("simulink/Sources/Constant", tminBlock, ...
    "Value", "Tton_trunc_min", "Position", [3720 1395 3850 1420]);
add_block("simulink/Signal Routing/Mux", activeMux, ...
    "Inputs", "4", "Position", [4310 1240 4340 1360]);
add_block("simulink/Signal Routing/Mux", savedMux, ...
    "Inputs", "4", "Position", [4310 1390 4340 1510]);
add_block("simulink/Sinks/Terminator", activeTerm, ...
    "Position", [4440 1290 4460 1315]);
add_block("simulink/Sinks/Terminator", savedTerm, ...
    "Position", [4440 1440 4460 1465]);

for phase = 1:4
    truncBlock = modelName + "/E010A5_TonTrunc" + phase;
    deleteBlockIfExists(truncBlock);
    y = 1190 + 85 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", truncBlock, ...
        "Position", [3920 y 4160 y+68]);
    setTonTruncScript(truncBlock);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, truncBlock, 1);
    connectBlocks(clockBlock, 1, truncBlock, 2);
    connectBlocks(tstepBlock, 1, truncBlock, 3);
    connectBlocks(windowBlock, 1, truncBlock, 4);
    connectBlocks(tminBlock, 1, truncBlock, 5);
    connectBlocks(enableBlock, 1, truncBlock, 6);
    connectBlocks(truncBlock, 1, modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(truncBlock, 2, activeMux, phase);
    connectBlocks(truncBlock, 3, savedMux, phase);
    markBlockOutport(truncBlock, 1, "Ton_cmd" + phase);
end
connectBlocks(activeMux, 1, activeTerm, 1);
connectBlocks(savedMux, 1, savedTerm, 1);
markBlockOutport(activeMux, 1, "Ton_trunc_i");
markBlockOutport(savedMux, 1, "Ton_saved_i");
end

function addPulseInhibit(modelName)
clockBlock = modelName + "/E010A5_PulseInhibit_Clock";
enableBlock = modelName + "/E010A5_PulseInhibit_Enable";
tstepBlock = modelName + "/E010A5_PulseInhibit_LoadStepTime";
windowBlock = modelName + "/E010A5_PulseInhibit_Time";
countBlock = modelName + "/E010A5_PulseInhibit_Count";
voutBlock = modelName + "/E010A5_PulseInhibit_Vout";
vrefBlock = modelName + "/E010A5_PulseInhibit_Vref";
bandBlock = modelName + "/E010A5_PulseInhibit_ReentryBand";
guardBlock = modelName + "/E010A5_PulseInhibit_ReentryGuard";
stateBlock = modelName + "/E010A5_PulseInhibitState";
stateTerm = modelName + "/E010A5_PulseInhibitState_Term";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(countBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(guardBlock);
deleteBlockIfExists(stateTerm);
deleteBlockIfExists(stateBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [1680 900 1720 930]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010_PulseInhibit_Enable", "Position", [1680 950 1815 975]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [1680 995 1815 1020]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E010_PulseInhibit_Time", "Position", [1680 1040 1815 1065]);
add_block("simulink/Sources/Constant", countBlock, ...
    "Value", "E010_PulseInhibit_Count", "Position", [1680 1085 1815 1110]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [1680 1130 1735 1158]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E010_Vref", "Position", [1680 1175 1815 1200]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E010_Reentry_Band_Down", "Position", [1680 1220 1815 1245]);
add_block("simulink/Sources/Constant", guardBlock, ...
    "Value", "E010_ReentryGuard_Enable", "Position", [1680 1265 1815 1290]);
add_block("simulink/User-Defined Functions/MATLAB Function", stateBlock, ...
    "Position", [2380 1240 2560 1310]);
setAnyFourScript(stateBlock, "pulse_inhibit_state");
add_block("simulink/Sinks/Terminator", stateTerm, ...
    "Position", [2670 1260 2690 1285]);

fromBlocks = ["From23", "From24", "From25", "From26"];
for phase = 1:4
    inhibitBlock = modelName + "/E010A5_PulseInhibit" + phase;
    countTerm = modelName + "/E010A5_PulseInhibit" + phase + "_Count_Term";
    deleteBlockIfExists(countTerm);
    deleteBlockIfExists(inhibitBlock);

    y = 900 + 140 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", inhibitBlock, ...
        "Position", [2020 y 2240 y+80]);
    setPulseInhibitScript(inhibitBlock);
    add_block("simulink/Sinks/Terminator", countTerm, ...
        "Position", [2350 y+54 2370 y+78]);

    cotBlock = modelName + "/COT_Cell_1Phase" + phase;
    disconnectInport(cotBlock, 1);
    connectBlocks(modelName + "/" + fromBlocks(phase), 1, inhibitBlock, 1);
    connectBlocks(clockBlock, 1, inhibitBlock, 2);
    connectBlocks(tstepBlock, 1, inhibitBlock, 3);
    connectBlocks(windowBlock, 1, inhibitBlock, 4);
    connectBlocks(countBlock, 1, inhibitBlock, 5);
    connectBlocks(enableBlock, 1, inhibitBlock, 6);
    connectBlocks(voutBlock, 1, inhibitBlock, 7);
    connectBlocks(vrefBlock, 1, inhibitBlock, 8);
    connectBlocks(bandBlock, 1, inhibitBlock, 9);
    connectBlocks(guardBlock, 1, inhibitBlock, 10);
    connectBlocks(inhibitBlock, 1, cotBlock, 1);
    connectBlocks(inhibitBlock, 2, stateBlock, phase);
    connectBlocks(inhibitBlock, 3, countTerm, 1);
    markBlockOutport(inhibitBlock, 1, "REQ_accept" + phase);
    markBlockOutport(inhibitBlock, 3, "pulse_inhibit_count" + phase);
    gotoBlock = modelName + "/E010A5_REQAccept_Goto" + phase;
    deleteBlockIfExists(gotoBlock);
    add_block("simulink/Signal Routing/Goto", gotoBlock, ...
        "GotoTag", "REQ_accept" + phase, "Position", [2350 y+12 2410 y+40]);
    connectBlocks(inhibitBlock, 1, gotoBlock, 1);
end
connectBlocks(stateBlock, 1, stateTerm, 1);
markBlockOutport(stateBlock, 1, "pulse_inhibit_state");
end

function addAreaHoldEnableProjection(modelName)
clockBlock = modelName + "/E010A5_AreaHold_Clock";
holdEnableBlock = modelName + "/E010A5_AreaHold_Enable";
tstepBlock = modelName + "/E010A5_AreaHold_LoadStepTime";
timeBlock = modelName + "/E010A5_AreaHold_Time";
voutBlock = modelName + "/E010A5_AreaHold_Vout";
vrefBlock = modelName + "/E010A5_AreaHold_Vref";
bandBlock = modelName + "/E010A5_AreaHold_ReentryBand";
bleedBlock = modelName + "/E010A5_AreaBleed_Enable";
gateBlock = modelName + "/E010A5_AreaHold_EnableProjection";
stateTerm = modelName + "/E010A5_AreaHold_State_Term";
countTerm = modelName + "/E010A5_AreaHold_Count_Term";
resetTerm = modelName + "/E010A5_AreaHold_Reset_Term";
bleedTerm = modelName + "/E010A5_AreaHold_Bleed_Term";
reentryTerm = modelName + "/E010A5_Reentry_State_Term";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(holdEnableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(timeBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(bleedBlock);
deleteBlockIfExists(gateBlock);
deleteBlockIfExists(stateTerm);
deleteBlockIfExists(countTerm);
deleteBlockIfExists(resetTerm);
deleteBlockIfExists(bleedTerm);
deleteBlockIfExists(reentryTerm);

add_block("simulink/Sources/Clock", clockBlock, "Position", [1680 1500 1720 1530]);
add_block("simulink/Sources/Constant", holdEnableBlock, ...
    "Value", "E010_AreaHold_Enable", "Position", [1680 1545 1835 1570]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [1680 1590 1835 1615]);
add_block("simulink/Sources/Constant", timeBlock, ...
    "Value", "E010_AreaHold_Time", "Position", [1680 1635 1835 1660]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [1680 1680 1735 1708]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E010_Vref", "Position", [1680 1725 1835 1750]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E010_Reentry_Band_Down", "Position", [1680 1770 1835 1795]);
add_block("simulink/Sources/Constant", bleedBlock, ...
    "Value", "E010_AreaBleed_Enable", "Position", [1680 1815 1835 1840]);
add_block("simulink/User-Defined Functions/MATLAB Function", gateBlock, ...
    "Position", [2020 1510 2285 1645]);
setAreaHoldEnableScript(gateBlock);

add_block("simulink/Sinks/Terminator", stateTerm, "Position", [2410 1540 2430 1565]);
add_block("simulink/Sinks/Terminator", countTerm, "Position", [2410 1575 2430 1600]);
add_block("simulink/Sinks/Terminator", resetTerm, "Position", [2410 1610 2430 1635]);
add_block("simulink/Sinks/Terminator", bleedTerm, "Position", [2410 1645 2430 1670]);
add_block("simulink/Sinks/Terminator", reentryTerm, "Position", [2410 1680 2430 1705]);

iqcotBlock = modelName + "/Ideal_Digital_IQCOT_Request";
enableBlock = modelName + "/IdealIQCOT_Enable_Constant";
disconnectInport(iqcotBlock, 8);
connectBlocks(enableBlock, 1, gateBlock, 1);
connectBlocks(clockBlock, 1, gateBlock, 2);
connectBlocks(tstepBlock, 1, gateBlock, 3);
connectBlocks(timeBlock, 1, gateBlock, 4);
connectBlocks(holdEnableBlock, 1, gateBlock, 5);
connectBlocks(voutBlock, 1, gateBlock, 6);
connectBlocks(vrefBlock, 1, gateBlock, 7);
connectBlocks(bandBlock, 1, gateBlock, 8);
connectBlocks(bleedBlock, 1, gateBlock, 9);
connectBlocks(gateBlock, 1, iqcotBlock, 8);
connectBlocks(gateBlock, 2, stateTerm, 1);
connectBlocks(gateBlock, 3, countTerm, 1);
connectBlocks(gateBlock, 4, resetTerm, 1);
connectBlocks(gateBlock, 5, bleedTerm, 1);
connectBlocks(gateBlock, 6, reentryTerm, 1);

markBlockOutport(gateBlock, 2, "area_hold_state");
markBlockOutport(gateBlock, 3, "area_hold_count");
markBlockOutport(gateBlock, 4, "area_reset_count");
markBlockOutport(gateBlock, 5, "area_bleed_count");
markBlockOutport(gateBlock, 6, "reentry_state");
end

function addR1ControlledReentryBurstLimiter(modelName)
clockBlock = modelName + "/E010A5_R1_BurstLimiter_Clock";
enableBlock = modelName + "/E010A5_R1_BurstLimiter_Enable";
tstepBlock = modelName + "/E010A5_R1_BurstLimiter_LoadStepTime";
windowBlock = modelName + "/E010A5_R1_BurstWindow";
limitBlock = modelName + "/E010A5_R1_BurstLimit";
spacingBlock = modelName + "/E010A5_R1_MinInterPulseSpacing";
areaClampBlock = modelName + "/E010A5_R1_AreaClampEnable";
limiterBlock = modelName + "/E010A5_R1_ControlledReentryBurstLimiter";
signalTerm = modelName + "/E010A5_R1_BurstLimiter_Term";
ctrlTerm = modelName + "/E010A5_R1_ControlledReentry_Term";
stateTerm = modelName + "/E010A5_R1_BurstLimiterState_Term";
areaClampTerm = modelName + "/E010A5_R1_AreaClamp_Term";
clampCountTerm = modelName + "/E010A5_R1_ClampCount_Term";
releaseTerm = modelName + "/E010A5_R1_ReleaseCount_Term";
fallbackTerm = modelName + "/E010A5_R1_FallbackReason_Term";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(limitBlock);
deleteBlockIfExists(spacingBlock);
deleteBlockIfExists(areaClampBlock);
deleteBlockIfExists(limiterBlock);
deleteBlockIfExists(signalTerm);
deleteBlockIfExists(ctrlTerm);
deleteBlockIfExists(stateTerm);
deleteBlockIfExists(areaClampTerm);
deleteBlockIfExists(clampCountTerm);
deleteBlockIfExists(releaseTerm);
deleteBlockIfExists(fallbackTerm);

add_block("simulink/Sources/Clock", clockBlock, "Position", [1680 1990 1720 2020]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010A5_R1_BurstLimiter_Enable", ...
    "Position", [1680 2035 1860 2060]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [1680 2080 1860 2105]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E010A5_R1_BurstWindow", ...
    "Position", [1680 2125 1860 2150]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E010A5_R1_BurstLimit", ...
    "Position", [1680 2170 1860 2195]);
add_block("simulink/Sources/Constant", spacingBlock, ...
    "Value", "E010A5_R1_MinInterPulseSpacing", ...
    "Position", [1680 2215 1860 2240]);
add_block("simulink/Sources/Constant", areaClampBlock, ...
    "Value", "E010A5_R1_AreaClamp_Enable", ...
    "Position", [1680 2260 1860 2285]);
add_block("simulink/User-Defined Functions/MATLAB Function", limiterBlock, ...
    "Position", [2180 1995 2535 2145]);
setR1BurstLimiterScript(limiterBlock);

add_block("simulink/Sinks/Terminator", signalTerm, ...
    "Position", [2710 1995 2730 2020]);
add_block("simulink/Sinks/Terminator", ctrlTerm, ...
    "Position", [2710 2030 2730 2055]);
add_block("simulink/Sinks/Terminator", stateTerm, ...
    "Position", [2710 2065 2730 2090]);
add_block("simulink/Sinks/Terminator", areaClampTerm, ...
    "Position", [2710 2100 2730 2125]);
add_block("simulink/Sinks/Terminator", clampCountTerm, ...
    "Position", [2710 2135 2730 2160]);
add_block("simulink/Sinks/Terminator", releaseTerm, ...
    "Position", [2710 2170 2730 2195]);
add_block("simulink/Sinks/Terminator", fallbackTerm, ...
    "Position", [2710 2205 2730 2230]);

iqcotBlock = modelName + "/Ideal_Digital_IQCOT_Request";
areaHoldBlock = modelName + "/E010A5_AreaHold_EnableProjection";
disconnectInport(iqcotBlock, 8);
connectBlocks(areaHoldBlock, 1, limiterBlock, 1);
connectBlocks(clockBlock, 1, limiterBlock, 2);
connectBlocks(tstepBlock, 1, limiterBlock, 3);
connectBlocks(enableBlock, 1, limiterBlock, 4);
connectBlocks(windowBlock, 1, limiterBlock, 5);
connectBlocks(limitBlock, 1, limiterBlock, 6);
connectBlocks(spacingBlock, 1, limiterBlock, 7);
connectBlocks(areaClampBlock, 1, limiterBlock, 8);

for phase = 1:4
    fromBlock = modelName + "/E010A5_R1_REQAccept_Delay_From" + phase;
    delayBlock = modelName + "/E010A5_R1_REQAccept_Delay" + phase;
    deleteBlockIfExists(delayBlock);
    deleteBlockIfExists(fromBlock);
    y = 1980 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "REQ_accept" + phase, "Position", [1885 y 1955 y+28]);
    add_block("simulink/Discrete/Unit Delay", delayBlock, ...
        "SampleTime", "Tss", "InitialCondition", "0", ...
        "Position", [2020 y 2075 y+28]);
    connectBlocks(fromBlock, 1, delayBlock, 1);
    connectBlocks(delayBlock, 1, limiterBlock, 8 + phase);
end

connectBlocks(limiterBlock, 1, iqcotBlock, 8);
connectBlocks(limiterBlock, 1, signalTerm, 1);
connectBlocks(limiterBlock, 2, ctrlTerm, 1);
connectBlocks(limiterBlock, 3, stateTerm, 1);
connectBlocks(limiterBlock, 4, areaClampTerm, 1);
connectBlocks(limiterBlock, 5, clampCountTerm, 1);
connectBlocks(limiterBlock, 6, releaseTerm, 1);
connectBlocks(limiterBlock, 7, fallbackTerm, 1);

markBlockOutport(limiterBlock, 2, "controlled_reentry_active");
markBlockOutport(limiterBlock, 3, "burst_limiter_state");
markBlockOutport(limiterBlock, 4, "area_int_reentry_clamp");
markBlockOutport(limiterBlock, 5, "burst_limiter_clamp_count");
markBlockOutport(limiterBlock, 6, "burst_limiter_release_count");
markBlockOutport(limiterBlock, 7, "burst_limiter_fallback_reason");

for phase = 1:4
    gateBlock = modelName + "/E010A5_R1_FinalReqGate" + phase;
    deleteBlockIfExists(gateBlock);
    y = 2380 + 90 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", gateBlock, ...
        "Position", [2540 y 2710 y+55]);
    setR1FinalReqGateScript(gateBlock);
    pulseBlock = modelName + "/E010A5_PulseInhibit" + phase;
    cotBlock = modelName + "/COT_Cell_1Phase" + phase;
    gotoBlock = modelName + "/E010A5_REQAccept_Goto" + phase;
    disconnectInport(cotBlock, 1);
    disconnectInport(gotoBlock, 1);
    connectBlocks(pulseBlock, 1, gateBlock, 1);
    connectBlocks(limiterBlock, 1, gateBlock, 2);
    connectBlocks(gateBlock, 1, cotBlock, 1);
    connectBlocks(gateBlock, 1, gotoBlock, 1);
    markBlockOutport(gateBlock, 1, "REQ_accept" + phase);
end
end

function addR1RecoveryTonRamp(modelName)
clockBlock = modelName + "/E010A5_R1_TonRamp_Clock";
enableBlock = modelName + "/E010A5_R1_TonRamp_Enable";
tstepBlock = modelName + "/E010A5_R1_TonRamp_LoadStepTime";
startBlock = modelName + "/E010A5_R1_TonRamp_StartDelay";
windowBlock = modelName + "/E010A5_R1_TonRamp_Window";
limitBlock = modelName + "/E010A5_R1_FirstReentryTonLimit";
usageMux = modelName + "/E010A5_R1_TonRampUsage_Mux";
usageTerm = modelName + "/E010A5_R1_TonRampUsage_Term";
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(startBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(limitBlock);
deleteBlockIfExists(usageMux);
deleteBlockIfExists(usageTerm);

add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 2210 3760 2240]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010A5_R1_TonRamp_Enable", "Position", [3720 2255 3890 2280]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [3720 2300 3890 2325]);
add_block("simulink/Sources/Constant", startBlock, ...
    "Value", "E010A5_R1_TonRamp_StartDelay", "Position", [3720 2345 3890 2370]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E010A5_R1_TonRamp_Window", "Position", [3720 2390 3890 2415]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E010A5_R1_FirstReentryTonLimit", "Position", [3720 2435 3890 2460]);
add_block("simulink/Signal Routing/Mux", usageMux, ...
    "Inputs", "4", "Position", [4310 2235 4340 2355]);
add_block("simulink/Sinks/Terminator", usageTerm, ...
    "Position", [4440 2285 4460 2310]);

for phase = 1:4
    rampBlock = modelName + "/E010A5_R1_TonRamp" + phase;
    rampTerm = modelName + "/E010A5_R1_TonRamp" + phase + "_Term";
    deleteBlockIfExists(rampTerm);
    deleteBlockIfExists(rampBlock);
    y = 2185 + 85 * phase;
    add_block("simulink/User-Defined Functions/MATLAB Function", rampBlock, ...
        "Position", [3920 y 4160 y+68]);
    setR1TonRampScript(rampBlock);

    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(modelName + "/E010A5_TonTrunc" + phase, 1, rampBlock, 1);
    connectBlocks(clockBlock, 1, rampBlock, 2);
    connectBlocks(tstepBlock, 1, rampBlock, 3);
    connectBlocks(startBlock, 1, rampBlock, 4);
    connectBlocks(windowBlock, 1, rampBlock, 5);
    connectBlocks(limitBlock, 1, rampBlock, 6);
    connectBlocks(enableBlock, 1, rampBlock, 7);
    connectBlocks(rampBlock, 1, modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(rampBlock, 2, usageMux, phase);
    add_block("simulink/Sinks/Terminator", rampTerm, ...
        "Position", [4240 y+20 4260 y+45]);
    connectBlocks(rampBlock, 2, rampTerm, 1);
    markBlockOutport(rampBlock, 1, "Ton_cmd" + phase);
end
connectBlocks(usageMux, 1, usageTerm, 1);
markBlockOutport(usageMux, 1, "recovery_Ton_ramp_usage");
end

function addR2EnergyShaping(modelName)
clockBlock = modelName + "/E010A5_R2_Energy_Clock";
enableBlock = modelName + "/E010A5_R2_Energy_Enable";
tstepBlock = modelName + "/E010A5_R2_LoadStepTime";
budgetWindowBlock = modelName + "/E010A5_R2_BudgetWindow";
budgetBlock = modelName + "/E010A5_R2_TonBudget";
firstLimitBlock = modelName + "/E010A5_R2_FirstTonLimit";
secondLimitBlock = modelName + "/E010A5_R2_SecondTonLimit";
stepBlock = modelName + "/E010A5_R2_TonRampStep";
rampWindowBlock = modelName + "/E010A5_R2_TonRampWindow";
maxTonBlock = modelName + "/E010A5_R2_TonRampMax";
softEnableBlock = modelName + "/E010A5_R2_SoftPreloadEnable";
preloadTargetBlock = modelName + "/E010A5_R2_PreloadTarget";
restoreRateBlock = modelName + "/E010A5_R2_RestoreRate";
schedulerEnableBlock = modelName + "/E010A5_R2_SchedulerReleaseEnable";
releaseInitialBlock = modelName + "/E010A5_R2_ReleaseInitial";
releaseRateBlock = modelName + "/E010A5_R2_ReleaseRate";
releaseWindowBlock = modelName + "/E010A5_R2_ReleaseWindow";
voltageEnableBlock = modelName + "/E010A5_R2_VoltageWindowEnable";
voutBlock = modelName + "/E010A5_R2_Vout";
vrefBlock = modelName + "/E010A5_R2_Vref";
upperBandBlock = modelName + "/E010A5_R2_UpperBand";
undershootBlock = modelName + "/E010A5_R2_UndershootBudget";
energyBlock = modelName + "/E010A5_R2_EnergyShaper";
usageMux = modelName + "/E010A5_R2_TonRampUsage_Mux";
limitMux = modelName + "/E010A5_R2_TonRampLimit_Mux";
usageTerm = modelName + "/E010A5_R2_TonRampUsage_Term";
limitTerm = modelName + "/E010A5_R2_TonRampLimit_Term";
releaseGoto = modelName + "/E010A5_R2_ReleaseFraction_Goto";
voltageGoto = modelName + "/E010A5_R2_VoltageState_Goto";

blocks = [clockBlock, enableBlock, tstepBlock, budgetWindowBlock, budgetBlock, ...
    firstLimitBlock, secondLimitBlock, stepBlock, rampWindowBlock, maxTonBlock, ...
    softEnableBlock, preloadTargetBlock, restoreRateBlock, schedulerEnableBlock, ...
    releaseInitialBlock, releaseRateBlock, releaseWindowBlock, voltageEnableBlock, ...
    voutBlock, vrefBlock, upperBandBlock, undershootBlock, energyBlock, usageMux, ...
    limitMux, usageTerm, limitTerm, releaseGoto, voltageGoto];
for idx = 1:numel(blocks)
    deleteBlockIfExists(blocks(idx));
end
for phase = 1:4
    deleteBlockIfExists(modelName + "/E010A5_R2_REQAccept_From" + phase);
    deleteBlockIfExists(modelName + "/E010A5_R2_REQAccept_Delay" + phase);
end

add_block("simulink/Sources/Clock", clockBlock, "Position", [1680 2680 1720 2710]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E010A5_R2_EnergyShaper_Enable", "Position", [1680 2725 1870 2750]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [1680 2770 1870 2795]);
add_block("simulink/Sources/Constant", budgetWindowBlock, ...
    "Value", "E010A5_R2_BudgetWindow", "Position", [1680 2815 1870 2840]);
add_block("simulink/Sources/Constant", budgetBlock, ...
    "Value", "E010A5_R2_TonBudget", "Position", [1680 2860 1870 2885]);
add_block("simulink/Sources/Constant", firstLimitBlock, ...
    "Value", "E010A5_R2_FirstTonLimit", "Position", [1680 2905 1870 2930]);
add_block("simulink/Sources/Constant", secondLimitBlock, ...
    "Value", "E010A5_R2_SecondTonLimit", "Position", [1680 2950 1870 2975]);
add_block("simulink/Sources/Constant", stepBlock, ...
    "Value", "E010A5_R2_TonRampStep", "Position", [1680 2995 1870 3020]);
add_block("simulink/Sources/Constant", rampWindowBlock, ...
    "Value", "E010A5_R2_TonRampWindow", "Position", [1680 3040 1870 3065]);
add_block("simulink/Sources/Constant", maxTonBlock, ...
    "Value", "E010A5_R2_TonRampMax", "Position", [1680 3085 1870 3110]);
add_block("simulink/Sources/Constant", softEnableBlock, ...
    "Value", "E010A5_R2_SoftPreloadEnable", "Position", [1680 3130 1870 3155]);
add_block("simulink/Sources/Constant", preloadTargetBlock, ...
    "Value", "E010A5_R2_PreloadTarget", "Position", [1680 3175 1870 3200]);
add_block("simulink/Sources/Constant", restoreRateBlock, ...
    "Value", "E010A5_R2_RestoreRate", "Position", [1680 3220 1870 3245]);
add_block("simulink/Sources/Constant", schedulerEnableBlock, ...
    "Value", "E010A5_R2_SchedulerReleaseEnable", "Position", [1680 3265 1870 3290]);
add_block("simulink/Sources/Constant", releaseInitialBlock, ...
    "Value", "E010A5_R2_ReleaseInitial", "Position", [1680 3310 1870 3335]);
add_block("simulink/Sources/Constant", releaseRateBlock, ...
    "Value", "E010A5_R2_ReleaseRate", "Position", [1680 3355 1870 3380]);
add_block("simulink/Sources/Constant", releaseWindowBlock, ...
    "Value", "E010A5_R2_ReleaseWindow", "Position", [1680 3400 1870 3425]);
add_block("simulink/Sources/Constant", voltageEnableBlock, ...
    "Value", "E010A5_R2_VoltageWindowEnable", "Position", [1680 3445 1870 3470]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [1680 3490 1740 3518]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E010_Vref", "Position", [1680 3535 1870 3560]);
add_block("simulink/Sources/Constant", upperBandBlock, ...
    "Value", "E010A5_R2_UpperReentryBand", "Position", [1680 3580 1870 3605]);
add_block("simulink/Sources/Constant", undershootBlock, ...
    "Value", "E010A5_R2_UndershootBudget", "Position", [1680 3625 1870 3650]);

add_block("simulink/User-Defined Functions/MATLAB Function", energyBlock, ...
    "Position", [2400 2680 2800 3040]);
setR2EnergyShaperScript(energyBlock);
add_block("simulink/Signal Routing/Mux", usageMux, ...
    "Inputs", "4", "Position", [3030 2820 3060 2940]);
add_block("simulink/Signal Routing/Mux", limitMux, ...
    "Inputs", "4", "Position", [3030 2980 3060 3100]);
add_block("simulink/Sinks/Terminator", usageTerm, ...
    "Position", [3160 2865 3180 2890]);
add_block("simulink/Sinks/Terminator", limitTerm, ...
    "Position", [3160 3025 3180 3050]);
add_block("simulink/Signal Routing/Goto", releaseGoto, ...
    "GotoTag", "E010A5_R2_scheduler_release_fraction", ...
    "Position", [3180 3285 3295 3315]);
add_block("simulink/Signal Routing/Goto", voltageGoto, ...
    "GotoTag", "E010A5_R2_voltage_window_state", ...
    "Position", [3180 3375 3295 3405]);

for phase = 1:4
    connectBlocks(modelName + "/E010A5_TonTrunc" + phase, 1, energyBlock, phase);
end
connectBlocks(clockBlock, 1, energyBlock, 5);
connectBlocks(tstepBlock, 1, energyBlock, 6);
connectBlocks(enableBlock, 1, energyBlock, 7);
connectBlocks(budgetWindowBlock, 1, energyBlock, 8);
connectBlocks(budgetBlock, 1, energyBlock, 9);
connectBlocks(firstLimitBlock, 1, energyBlock, 10);
connectBlocks(secondLimitBlock, 1, energyBlock, 11);
connectBlocks(stepBlock, 1, energyBlock, 12);
connectBlocks(rampWindowBlock, 1, energyBlock, 13);
connectBlocks(maxTonBlock, 1, energyBlock, 14);
connectBlocks(softEnableBlock, 1, energyBlock, 15);
connectBlocks(preloadTargetBlock, 1, energyBlock, 16);
connectBlocks(restoreRateBlock, 1, energyBlock, 17);
connectBlocks(schedulerEnableBlock, 1, energyBlock, 18);
connectBlocks(releaseInitialBlock, 1, energyBlock, 19);
connectBlocks(releaseRateBlock, 1, energyBlock, 20);
connectBlocks(releaseWindowBlock, 1, energyBlock, 21);
connectBlocks(voltageEnableBlock, 1, energyBlock, 22);
connectBlocks(voutBlock, 1, energyBlock, 23);
connectBlocks(vrefBlock, 1, energyBlock, 24);
connectBlocks(upperBandBlock, 1, energyBlock, 25);
connectBlocks(undershootBlock, 1, energyBlock, 26);

for phase = 1:4
    fromBlock = modelName + "/E010A5_R2_REQAccept_From" + phase;
    delayBlock = modelName + "/E010A5_R2_REQAccept_Delay" + phase;
    y = 3660 + 45 * phase;
    add_block("simulink/Signal Routing/From", fromBlock, ...
        "GotoTag", "REQ_accept" + phase, "Position", [1970 y 2040 y+28]);
    add_block("simulink/Discrete/Unit Delay", delayBlock, ...
        "SampleTime", "Tss", "InitialCondition", "0", ...
        "Position", [2105 y 2160 y+28]);
    connectBlocks(fromBlock, 1, delayBlock, 1);
    connectBlocks(delayBlock, 1, energyBlock, 26 + phase);
end

for phase = 1:4
    disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(energyBlock, phase, modelName + "/COT_Cell_1Phase" + phase, 3);
    connectBlocks(energyBlock, 4 + phase, usageMux, phase);
    connectBlocks(energyBlock, 8 + phase, limitMux, phase);
    markBlockOutport(energyBlock, phase, "Ton_cmd" + phase);
end
connectBlocks(usageMux, 1, usageTerm, 1);
connectBlocks(limitMux, 1, limitTerm, 1);
markBlockOutport(usageMux, 1, "Ton_ramp_usage");
markBlockOutport(limitMux, 1, "Ton_ramp_limit_i");

r2Scalar = [
    "Ton_ramp_state", "energy_budget_state", "reentry_energy_budget_used", ...
    "reentry_energy_budget_remaining", "reentry_energy_budget_violation", ...
    "area_int_soft_preload_state", "area_int_soft_preload_count", ...
    "area_int_restore_state", "scheduler_release_state", ...
    "scheduler_release_fraction", "scheduler_release_guard_violation", ...
    "voltage_window_release_state", "voltage_window_release_violation", ...
    "controlled_reentry_active"];
for idx = 1:numel(r2Scalar)
    portNo = 12 + idx;
    termBlock = modelName + "/E010A5_R2_" + r2Scalar(idx) + "_Term";
    deleteBlockIfExists(termBlock);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [3180 3115 + 30 * idx 3200 3140 + 30 * idx]);
    connectBlocks(energyBlock, portNo, termBlock, 1);
    markBlockOutport(energyBlock, portNo, r2Scalar(idx));
end
connectBlocks(energyBlock, 22, releaseGoto, 1);
connectBlocks(energyBlock, 24, voltageGoto, 1);

addScalarConstantLog(modelName, "Ton_nom", "Ton_nom", [4080 2220 4210 2250]);
addScalarConstantLog(modelName, "burst_limiter_state", "0", [4080 2265 4210 2295]);
addScalarConstantLog(modelName, "area_int_reentry_clamp", "0", [4080 2355 4210 2385]);
addScalarConstantLog(modelName, "burst_limiter_clamp_count", "0", [4080 2400 4210 2430]);
addScalarConstantLog(modelName, "burst_limiter_release_count", "0", [4080 2445 4210 2475]);
addScalarConstantLog(modelName, "burst_limiter_fallback_reason", "0", [4080 2490 4210 2520]);
addScalarConstantLog(modelName, "recovery_Ton_ramp_usage", "0", [4080 2535 4210 2565]);
end

function addR2SchedulerReleaseGate(modelName)
releaseBlock = modelName + "/E010A5_R2_ReleaseFraction_From";
voltageBlock = modelName + "/E010A5_R2_VoltageState_From";
gateMux = modelName + "/E010A5_R2_SchedulerGate_Mux";
gateTerm = modelName + "/E010A5_R2_SchedulerGate_Term";
deleteBlockIfExists(releaseBlock);
deleteBlockIfExists(voltageBlock);
deleteBlockIfExists(gateMux);
deleteBlockIfExists(gateTerm);
add_block("simulink/Signal Routing/From", releaseBlock, ...
    "GotoTag", "E010A5_R2_scheduler_release_fraction", ...
    "Position", [2180 4070 2290 4098]);
add_block("simulink/Signal Routing/From", voltageBlock, ...
    "GotoTag", "E010A5_R2_voltage_window_state", ...
    "Position", [2180 4125 2290 4153]);
add_block("simulink/Signal Routing/Mux", gateMux, ...
    "Inputs", "4", "Position", [2910 4130 2940 4250]);
add_block("simulink/Sinks/Terminator", gateTerm, ...
    "Position", [3040 4175 3060 4200]);

for phase = 1:4
    gateBlock = modelName + "/E010A5_R2_FinalReqGate" + phase;
    activeTerm = modelName + "/E010A5_R2_FinalReqGate" + phase + "_Active_Term";
    phaseRankBlock = modelName + "/E010A5_R2_FinalReqGate" + phase + "_Rank";
    enableBlock = modelName + "/E010A5_R2_FinalReqGate" + phase + "_Enable";
    voltageEnableBlock = modelName + "/E010A5_R2_FinalReqGate" + phase + "_VoltageEnable";
    deleteBlockIfExists(activeTerm);
    deleteBlockIfExists(phaseRankBlock);
    deleteBlockIfExists(enableBlock);
    deleteBlockIfExists(voltageEnableBlock);
    deleteBlockIfExists(gateBlock);
    y = 3900 + 110 * phase;
    add_block("simulink/Sources/Constant", phaseRankBlock, ...
        "Value", num2str(phase), "Position", [2180 y 2240 y+25]);
    add_block("simulink/Sources/Constant", enableBlock, ...
        "Value", "E010A5_R2_SchedulerGateEnable", "Position", [2180 y+35 2360 y+60]);
    add_block("simulink/Sources/Constant", voltageEnableBlock, ...
        "Value", "E010A5_R2_VoltageWindowEnable", "Position", [2180 y+70 2360 y+95]);
    add_block("simulink/User-Defined Functions/MATLAB Function", gateBlock, ...
        "Position", [2520 y 2760 y+90]);
    setR2FinalReqGateScript(gateBlock);
    add_block("simulink/Sinks/Terminator", activeTerm, ...
        "Position", [2860 y+50 2880 y+75]);

    pulseBlock = modelName + "/E010A5_PulseInhibit" + phase;
    cotBlock = modelName + "/COT_Cell_1Phase" + phase;
    gotoBlock = modelName + "/E010A5_REQAccept_Goto" + phase;
    disconnectInport(cotBlock, 1);
    disconnectInport(gotoBlock, 1);
    connectBlocks(pulseBlock, 1, gateBlock, 1);
    connectBlocks(releaseBlock, 1, gateBlock, 2);
    connectBlocks(voltageBlock, 1, gateBlock, 3);
    connectBlocks(phaseRankBlock, 1, gateBlock, 4);
    connectBlocks(enableBlock, 1, gateBlock, 5);
    connectBlocks(voltageEnableBlock, 1, gateBlock, 6);
    connectBlocks(gateBlock, 1, cotBlock, 1);
    connectBlocks(gateBlock, 1, gotoBlock, 1);
    connectBlocks(gateBlock, 3, activeTerm, 1);
    connectBlocks(gateBlock, 3, gateMux, phase);
    markBlockOutport(gateBlock, 1, "REQ_accept" + phase);
end
connectBlocks(gateMux, 1, gateTerm, 1);
markBlockOutport(gateMux, 1, "scheduler_release_gate_active");
end

function addReqRejectReasonLog(modelName)
block = modelName + "/E010A5_REQRejectReason";
termBlock = modelName + "/E010A5_REQRejectReason_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(block);
add_block("simulink/User-Defined Functions/MATLAB Function", block, ...
    "Position", [4080 970 4320 1060]);
setReqRejectScript(block);
for phase = 1:4
    addFromLog(modelName, "tr" + phase, "E010A5_REQReject_Raw" + phase, ...
        [3860 840 + 30 * phase 3920 868 + 30 * phase], false);
    connectBlocks(modelName + "/E010A5_Log_E010A5_REQReject_Raw" + phase + "_From", ...
        1, block, phase);
    addFromLog(modelName, "REQ_accept" + phase, "E010A5_REQReject_Accept" + phase, ...
        [3860 990 + 30 * phase 3920 1018 + 30 * phase], false);
    connectBlocks(modelName + "/E010A5_Log_E010A5_REQReject_Accept" + phase + "_From", ...
        1, block, 4 + phase);
end
add_block("simulink/Sinks/Terminator", termBlock, "Position", [4410 1000 4430 1025]);
connectBlocks(block, 1, termBlock, 1);
markBlockOutport(block, 1, "REQ_reject_reason");
end

function addPhaseOrderErrorLog(modelName)
block = modelName + "/E010A5_PhaseOrderError";
termBlock = modelName + "/E010A5_PhaseOrderError_Term";
clockBlock = modelName + "/E010A5_PhaseOrder_Clock";
tstepBlock = modelName + "/E010A5_PhaseOrder_LoadStepTime";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(block);
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(tstepBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [4080 1105 4120 1135]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [4080 1150 4205 1175]);
add_block("simulink/User-Defined Functions/MATLAB Function", block, ...
    "Position", [4280 1085 4495 1190]);
setPhaseOrderScript(block);
for phase = 1:4
    addFromLog(modelName, "REQ_accept" + phase, "E010A5_Order_Accept" + phase, ...
        [4080 1190 + 30 * phase 4160 1218 + 30 * phase], false);
    connectBlocks(modelName + "/E010A5_Log_E010A5_Order_Accept" + phase + "_From", ...
        1, block, phase);
end
connectBlocks(clockBlock, 1, block, 5);
connectBlocks(tstepBlock, 1, block, 6);
add_block("simulink/Sinks/Terminator", termBlock, "Position", [4590 1125 4610 1150]);
connectBlocks(block, 1, termBlock, 1);
markBlockOutport(block, 1, "phase_order_error");
end

function addSevereDropDetector(modelName, variant)
block = modelName + "/E010A5_SevereDropDetector";
termBlock = modelName + "/E010A5_SevereDropDetector_Term";
clockBlock = modelName + "/E010A5_SevereDropDetector_Clock";
thresholdBlock = modelName + "/E010A5_SevereDropThreshold";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(block);
deleteBlockIfExists(clockBlock);
deleteBlockIfExists(thresholdBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [4080 1450 4120 1480]);
add_block("simulink/Sources/Constant", thresholdBlock, ...
    "Value", "E010A5_DeltaI_Drop_Threshold_High", ...
    "Position", [4080 1495 4270 1520]);
add_block("simulink/User-Defined Functions/MATLAB Function", block, ...
    "Position", [4350 1430 4565 1525]);
setSevereDropScript(block);
connectBlocks(modelName + "/E010A5_LoadCurrentStep", 1, block, 1);
connectBlocks(clockBlock, 1, block, 2);
connectBlocks(thresholdBlock, 1, block, 3);
add_block("simulink/Sinks/Terminator", termBlock, "Position", [4665 1460 4685 1485]);
connectBlocks(block, 1, termBlock, 1);
markBlockOutport(block, 1, "severe_drop_detected");

addScalarConstantLog(modelName, "a_O_state", candidateStateCode(variant), ...
    [4080 1535 4210 1565]);
end

function addAuditStateConstants(modelName, variant)
unusedVariant = variant; %#ok<NASGU>
addScalarConstantLog(modelName, "fallback_state", "0", [4080 1670 4210 1700]);
addScalarConstantLog(modelName, "burst_pulse_count_after_reentry", "0", [4080 1715 4300 1745]);
addScalarConstantLog(modelName, "fallback_count", "0", [4080 1895 4210 1925]);
addScalarConstantLog(modelName, "fallback_reason", "0", [4080 1940 4210 1970]);
end

function value = candidateStateCode(variant)
variant = string(variant);
if variant == "A5-T1"
    value = "51";
elseif variant == "A5-T2"
    value = "52";
elseif variant == "A5-T3"
    value = "53";
elseif variant == "A5-T4"
    value = "54";
elseif variant == "A5-T4-R1a"
    value = "61";
elseif variant == "A5-T4-R1b"
    value = "62";
elseif variant == "A5-T4-R1c"
    value = "63";
elseif variant == "A5-R2-E1"
    value = "71";
elseif variant == "A5-R2-E2"
    value = "72";
elseif variant == "A5-R2-E3"
    value = "73";
elseif variant == "A5-R2-E4"
    value = "74";
else
    value = "50";
end
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E010A5_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 1990 3760 2020]);

for phase = 1:4
    estimator = modelName + "/E010A5_TonActual" + phase;
    termBlock = modelName + "/E010A5_TonActual" + phase + "_Term";
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estimator);

    y = 1980 + 70 * phase;
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

function addFromLog(modelName, tagName, signalName, position, streamSignal)
if nargin < 5
    streamSignal = true;
end
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E010A5_Log_" + safeName + "_From";
termBlock = modelName + "/E010A5_Log_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(fromBlock);
add_block("simulink/Signal Routing/From", fromBlock, ...
    "GotoTag", tagName, "Position", position);
if streamSignal
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
    connectBlocks(fromBlock, 1, termBlock, 1);
    markBlockOutport(fromBlock, 1, signalName);
end
end

function addScalarConstantLog(modelName, signalName, value, position)
addVectorConstantLog(modelName, signalName, value, position);
end

function addVectorConstantLog(modelName, signalName, value, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
constBlock = modelName + "/E010A5_" + safeName;
termBlock = modelName + "/E010A5_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(constBlock);
add_block("simulink/Sources/Constant", constBlock, ...
    "Value", value, "Position", position);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
connectBlocks(constBlock, 1, termBlock, 1);
markBlockOutport(constBlock, 1, signalName);
end

function setPulseInhibitScript(blockPath)
script = [
"function [tr_out,inhibit_active,inhibit_count] = pulse_inhibit(tr_in,t,t_step,t_window,count_max,enable,vout,vref,reentry_band,guard_enable)"
"%#codegen"
"is_high = logical(tr_in);"
"in_window = (enable > 0.5) && (t >= t_step) && (t <= (t_step + t_window));"
"guard_ok = (guard_enable <= 0.5) || (vout >= (vref + reentry_band));"
"inhibit_active = is_high && in_window && (count_max > 0.0) && guard_ok;"
"if inhibit_active"
"    tr_out = false;"
"else"
"    tr_out = tr_in;"
"end"
"inhibit_count = double(inhibit_active);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["tr_in", "t", "t_step", "t_window", "count_max", "enable", ...
    "vout", "vref", "reentry_band", "guard_enable", ...
    "tr_out", "inhibit_active", "inhibit_count"], ...
    ["tr_in", "tr_out", "inhibit_active"]);
end

function setAreaHoldEnableScript(blockPath)
script = [
"function [enable_out,hold_state,hold_count,reset_count,bleed_count,reentry_state] = area_hold_enable(enable_in,t,t_step,t_hold,hold_enable,vout,vref,reentry_band,bleed_enable)"
"%#codegen"
"persistent was_hold reset_seen"
"if isempty(was_hold)"
"    was_hold = false;"
"end"
"if isempty(reset_seen)"
"    reset_seen = 0.0;"
"end"
"if t < t_step"
"    was_hold = false;"
"    reset_seen = 0.0;"
"end"
"in_window = (hold_enable > 0.5) && (t >= t_step) && (t <= (t_step + t_hold));"
"release_not_safe = vout >= (vref + reentry_band);"
"hold = in_window && release_not_safe;"
"enable_out = double(enable_in > 0.5);"
"if hold"
"    enable_out = 0.0;"
"end"
"hold_state = double(hold);"
"hold_count = double(hold);"
"bleed_count = double(hold && (bleed_enable > 0.5));"
"release_edge = (~hold) && was_hold;"
"if release_edge"
"    reset_seen = reset_seen + 1.0;"
"end"
"reset_count = reset_seen;"
"reentry_state = double((hold_enable > 0.5) && (t > t_step) && ~hold);"
"was_hold = hold;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["enable_in", "t", "t_step", "t_hold", "hold_enable", "vout", ...
    "vref", "reentry_band", "bleed_enable", "enable_out", ...
    "hold_state", "hold_count", "reset_count", "bleed_count", ...
    "reentry_state"], strings(0, 1));
setDiscreteSampleTime(blockPath);
end

function setTonTruncScript(blockPath)
script = [
"function [ton_out,trunc_active,ton_saved] = ton_trunc(ton_in,t,t_step,t_window,t_min,enable)"
"%#codegen"
"active = (enable > 0.5) && (t >= t_step) && (t <= (t_step + t_window));"
"if active"
"    ton_out = min(ton_in, t_min);"
"else"
"    ton_out = ton_in;"
"end"
"trunc_active = double(active);"
"ton_saved = max(ton_in - ton_out, 0.0);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton_in", "t", "t_step", "t_window", "t_min", "enable", ...
    "ton_out", "trunc_active", "ton_saved"], strings(0, 1));
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
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if ~isempty(chart)
    try
        chart.UpdateMethod = "DISCRETE";
        chart.SampleTime = "Ts_ctrl";
    catch
        try
            set_param(blockPath, "SampleTime", "Ts_ctrl");
        catch
        end
    end
end
try
    set_param(blockPath, "SystemSampleTime", "Ts_ctrl");
catch
end
end

function setR1BurstLimiterScript(blockPath)
script = [
"function [enable_out,controlled_active,burst_state,area_clamp_active,clamp_count,release_count,fallback_reason] = r1_burst_limiter(enable_in,t,t_step,enable,burst_window,burst_limit,min_spacing,area_clamp_enable,a1,a2,a3,a4)"
"%#codegen"
"persistent prev count first_time last_time clamp_seen release_seen"
"if isempty(prev)"
"    prev = [false,false,false,false];"
"end"
"if isempty(count)"
"    count = 0.0;"
"end"
"if isempty(first_time)"
"    first_time = -1.0;"
"end"
"if isempty(last_time)"
"    last_time = -1.0;"
"end"
"if isempty(clamp_seen)"
"    clamp_seen = 0.0;"
"end"
"if isempty(release_seen)"
"    release_seen = 0.0;"
"end"
"if t < t_step"
"    prev = [false,false,false,false];"
"    count = 0.0;"
"    first_time = -1.0;"
"    last_time = -1.0;"
"    clamp_seen = 0.0;"
"    release_seen = 0.0;"
"end"
"acc = [a1,a2,a3,a4] > 0.5;"
"rise = acc & ~prev;"
"if (enable > 0.5) && (t >= t_step)"
"    for idx = 1:4"
"        if rise(idx)"
"            if count < 0.5"
"                first_time = t;"
"            end"
"            count = count + 1.0;"
"            last_time = t;"
"        end"
"    end"
"end"
"controlled_active = double((enable > 0.5) && (t >= t_step) && (count > 0.5));"
"in_burst_window = (first_time >= 0.0) && (t < first_time + max(burst_window, 0.0));"
"limit_hold = in_burst_window && (count >= max(burst_limit, 0.0));"
"spacing_hold = (last_time >= 0.0) && ((t - last_time) < max(min_spacing, 0.0));"
"hold = (enable > 0.5) && (t >= t_step) && (limit_hold || spacing_hold);"
"enable_out = double(enable_in > 0.5);"
"if hold"
"    enable_out = 0.0;"
"end"
"if limit_hold"
"    burst_state = 2.0;"
"elseif spacing_hold"
"    burst_state = 1.0;"
"elseif (first_time >= 0.0) && (t >= first_time + max(burst_window, 0.0))"
"    burst_state = 3.0;"
"else"
"    burst_state = 0.0;"
"end"
"area_clamp_active = double(hold && (area_clamp_enable > 0.5));"
"if area_clamp_active > 0.5"
"    clamp_seen = 1.0;"
"end"
"if (first_time >= 0.0) && (t >= first_time + max(burst_window, 0.0))"
"    release_seen = 1.0;"
"end"
"clamp_count = clamp_seen;"
"release_count = release_seen;"
"fallback_reason = 0.0;"
"prev = acc;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["enable_in", "t", "t_step", "enable", "burst_window", ...
    "burst_limit", "min_spacing", "area_clamp_enable", ...
    "a1", "a2", "a3", "a4", "enable_out", ...
    "controlled_active", "burst_state", "area_clamp_active", ...
    "clamp_count", "release_count", "fallback_reason"], ...
    ["a1", "a2", "a3", "a4"]);
setFastSampleTime(blockPath);
end

function setR1TonRampScript(blockPath)
script = [
"function [ton_out,ramp_usage] = r1_ton_ramp(ton_in,t,t_step,start_delay,ramp_window,first_limit,enable)"
"%#codegen"
"age = t - (t_step + max(start_delay, 0.0));"
"active = (enable > 0.5) && (age >= 0.0) && (age <= max(ramp_window, 0.0));"
"if active"
"    if ramp_window > 0.0"
"        alpha = min(max(age / ramp_window, 0.0), 1.0);"
"    else"
"        alpha = 1.0;"
"    end"
"    ton_limit = first_limit + alpha * max(ton_in - first_limit, 0.0);"
"    ton_out = min(ton_in, ton_limit);"
"else"
"    ton_out = ton_in;"
"end"
"ramp_usage = max(ton_in - ton_out, 0.0);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton_in", "t", "t_step", "start_delay", "ramp_window", ...
    "first_limit", "enable", "ton_out", "ramp_usage"], strings(0, 1));
setFastSampleTime(blockPath);
end

function setR1FinalReqGateScript(blockPath)
script = [
"function req_out = r1_final_req_gate(req_in, enable_in)"
"%#codegen"
"req_out = (req_in > 0.5) && (enable_in > 0.5);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["req_in", "enable_in", "req_out"], ["req_in", "req_out"]);
setFastSampleTime(blockPath);
end

function setR2EnergyShaperScript(blockPath)
script = [
"function [ton1o,ton2o,ton3o,ton4o,u1,u2,u3,u4,l1,l2,l3,l4,ton_state,budget_state,budget_used,budget_remaining,budget_violation,soft_state,soft_count,restore_state,sched_state,sched_fraction,sched_guard_violation,voltage_state,voltage_violation,controlled_active] = r2_energy_shaper(ton1,ton2,ton3,ton4,t,t_step,enable,budget_window,ton_budget,first_lim,second_lim,ton_step,ramp_window,max_ton,soft_enable,preload_target,restore_rate,sched_enable,release_initial,release_rate,release_window,voltage_enable,vout,vref,upper_band,undershoot_budget,req1,req2,req3,req4)"
"%#codegen"
"persistent prev_req count used first_time soft_seen"
"if isempty(prev_req)"
"    prev_req = [false,false,false,false];"
"end"
"if isempty(count)"
"    count = 0.0;"
"end"
"if isempty(used)"
"    used = 0.0;"
"end"
"if isempty(first_time)"
"    first_time = -1.0;"
"end"
"if isempty(soft_seen)"
"    soft_seen = 0.0;"
"end"
"if t < t_step"
"    prev_req = [false,false,false,false];"
"    count = 0.0;"
"    used = 0.0;"
"    first_time = -1.0;"
"    soft_seen = 0.0;"
"end"
"tons = [ton1,ton2,ton3,ton4];"
"req = [req1,req2,req3,req4] > 0.5;"
"rise = req & ~prev_req;"
"active = (enable > 0.5) && (t >= t_step);"
"if active && (first_time < 0.0) && any(rise)"
"    first_time = t;"
"end"
"if first_time >= 0.0"
"    age = max(t - first_time, 0.0);"
"else"
"    age = 0.0;"
"end"
"in_window = active && (first_time >= 0.0) && (age <= max(budget_window, 0.0));"
"if voltage_enable > 0.5"
"    if vout < vref - max(undershoot_budget, 0.0)"
"        voltage_state = 2.0;"
"    elseif vout > vref + max(upper_band, 0.0)"
"        voltage_state = 3.0;"
"    else"
"        voltage_state = 1.0;"
"    end"
"else"
"    voltage_state = 0.0;"
"end"
"if (sched_enable > 0.5) && in_window"
"    sched_fraction = min(1.0, max(0.0, release_initial) + max(age, 0.0) * max(release_rate, 0.0));"
"    if age > max(release_window, 0.0)"
"        sched_fraction = 1.0;"
"    end"
"    sched_state = 1.0 + double(sched_fraction >= 0.999);"
"else"
"    sched_fraction = 1.0;"
"    sched_state = 0.0;"
"end"
"if ramp_window > 0.0"
"    alpha = min(max(age / ramp_window, 0.0), 1.0);"
"else"
"    alpha = 1.0;"
"end"
"base_limit = first_lim + alpha * max(max_ton - first_lim, 0.0);"
"event_limit = first_lim;"
"if count >= 0.5"
"    event_limit = second_lim;"
"end"
"if count >= 1.5"
"    event_limit = second_lim + (count - 1.0) * max(ton_step, 0.0);"
"end"
"limit = min(max_ton, max(first_lim, min(base_limit, event_limit)));"
"if sched_enable > 0.5"
"    limit = max(first_lim, limit * max(sched_fraction, 0.25));"
"end"
"if voltage_state == 2.0"
"    limit = max_ton;"
"elseif voltage_state == 3.0"
"    limit = min(limit, first_lim);"
"end"
"outs = tons;"
"limits = max_ton * ones(1,4);"
"if in_window"
"    limits = limit * ones(1,4);"
"    for idx = 1:4"
"        if rise(idx)"
"            remaining = max(ton_budget - used, 0.0);"
"            allowed = min(tons(idx), limit);"
"            if remaining > 0.0"
"                allowed = min(allowed, remaining);"
"                allowed = max(allowed, min(first_lim, remaining));"
"            else"
"                allowed = min(allowed, first_lim);"
"            end"
"            outs(idx) = allowed;"
"            used = used + max(allowed, 0.0);"
"            count = count + 1.0;"
"        else"
"            outs(idx) = min(tons(idx), limit);"
"        end"
"    end"
"end"
"budget_remaining = max(ton_budget - used, 0.0);"
"budget_violation = double(in_window && (used > ton_budget + 1.0e-12));"
"budget_used = used;"
"if ~active"
"    ton_state = 0.0;"
"elseif in_window"
"    ton_state = 1.0;"
"else"
"    ton_state = 2.0;"
"end"
"if ~active"
"    budget_state = 0.0;"
"elseif budget_violation > 0.5"
"    budget_state = 3.0;"
"elseif in_window"
"    budget_state = 1.0;"
"else"
"    budget_state = 2.0;"
"end"
"soft_state = double(in_window && (soft_enable > 0.5));"
"if soft_state > 0.5"
"    soft_seen = 1.0;"
"end"
"soft_count = soft_seen;"
"restore_state = double((soft_seen > 0.5) && (restore_rate >= 0.0));"
"sched_guard_violation = double((sched_enable > 0.5) && in_window && sched_fraction < 0.249);"
"voltage_violation = double((voltage_enable > 0.5) && (voltage_state == 3.0));"
"controlled_active = double(in_window);"
"u = max(tons - outs, 0.0);"
"ton1o = outs(1); ton2o = outs(2); ton3o = outs(3); ton4o = outs(4);"
"u1 = u(1); u2 = u(2); u3 = u(3); u4 = u(4);"
"l1 = limits(1); l2 = limits(2); l3 = limits(3); l4 = limits(4);"
"prev_req = req;"
"unused_preload = preload_target; %#ok<NASGU>"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton1", "ton2", "ton3", "ton4", "t", "t_step", "enable", ...
    "budget_window", "ton_budget", "first_lim", "second_lim", ...
    "ton_step", "ramp_window", "max_ton", "soft_enable", ...
    "preload_target", "restore_rate", "sched_enable", "release_initial", ...
    "release_rate", "release_window", "voltage_enable", "vout", "vref", ...
    "upper_band", "undershoot_budget", "req1", "req2", "req3", "req4", ...
    "ton1o", "ton2o", "ton3o", "ton4o", "u1", "u2", "u3", "u4", ...
    "l1", "l2", "l3", "l4", "ton_state", "budget_state", ...
    "budget_used", "budget_remaining", "budget_violation", "soft_state", ...
    "soft_count", "restore_state", "sched_state", "sched_fraction", ...
    "sched_guard_violation", "voltage_state", "voltage_violation", ...
    "controlled_active"], ["req1", "req2", "req3", "req4"]);
setFastSampleTime(blockPath);
end

function setR2FinalReqGateScript(blockPath)
script = [
"function [req_out,reject_reason,gate_active] = r2_final_req_gate(req_in,sched_fraction,voltage_state,phase_rank,enable,voltage_enable)"
"%#codegen"
"gate_active = double(enable > 0.5);"
"allow_count = ceil(4.0 * min(max(sched_fraction, 0.0), 1.0));"
"allow_count = max(1.0, min(4.0, allow_count));"
"allow = (enable <= 0.5) || (phase_rank <= allow_count);"
"if (voltage_enable > 0.5) && (voltage_state == 2.0)"
"    allow = true;"
"end"
"req_out = (req_in > 0.5) && allow;"
"if (req_in > 0.5) && ~allow"
"    reject_reason = 4.0;"
"else"
"    reject_reason = 0.0;"
"end"
];
setChartScriptAndTypes(blockPath, script, ...
    ["req_in", "sched_fraction", "voltage_state", "phase_rank", ...
    "enable", "voltage_enable", "req_out", "reject_reason", ...
    "gate_active"], ["req_in", "req_out"]);
setFastSampleTime(blockPath);
end

function setActiveHsPhaseScript(blockPath)
script = [
"function active_phase = active_hs_phase(qh1,qh2,qh3,qh4)"
"%#codegen"
"qh = [qh1, qh2, qh3, qh4] > 0.5;"
"active_phase = 0.0;"
"for idx = 1:4"
"    if qh(idx)"
"        active_phase = double(idx);"
"        return;"
"    end"
"end"
];
setChartScriptAndTypes(blockPath, script, ...
    ["qh1", "qh2", "qh3", "qh4", "active_phase"], ...
    ["qh1", "qh2", "qh3", "qh4"]);
end

function setAnyFourScript(blockPath, outputName)
script = [
"function y = any_four(u1,u2,u3,u4)"
"%#codegen"
"y = double((u1 > 0.5) || (u2 > 0.5) || (u3 > 0.5) || (u4 > 0.5));"
];
setChartScriptAndTypes(blockPath, script, ...
    ["u1", "u2", "u3", "u4", "y"], ["u1", "u2", "u3", "u4"]);
unusedOutput = outputName; %#ok<NASGU>
end

function setReqRejectScript(blockPath)
script = [
"function reason = req_reject_reason(r1,r2,r3,r4,a1,a2,a3,a4)"
"%#codegen"
"raw = (r1 > 0.5) || (r2 > 0.5) || (r3 > 0.5) || (r4 > 0.5);"
"acc = (a1 > 0.5) || (a2 > 0.5) || (a3 > 0.5) || (a4 > 0.5);"
"if raw && ~acc"
"    reason = 1.0;"
"else"
"    reason = 0.0;"
"end"
];
setChartScriptAndTypes(blockPath, script, ...
    ["r1", "r2", "r3", "r4", "a1", "a2", "a3", "a4", "reason"], ...
    ["r1", "r2", "r3", "r4", "a1", "a2", "a3", "a4"]);
end

function setPhaseOrderScript(blockPath)
script = [
"function err = phase_order_error(a1,a2,a3,a4,t,t_step)"
"%#codegen"
"persistent prev expected"
"if isempty(prev)"
"    prev = [false,false,false,false];"
"end"
"if isempty(expected)"
"    expected = 0.0;"
"end"
"acc = [a1,a2,a3,a4] > 0.5;"
"rise = acc & ~prev;"
"err = 0.0;"
"if t < t_step"
"    expected = 0.0;"
"else"
"    for idx = 1:4"
"        if rise(idx)"
"            if expected > 0.5 && double(idx) ~= expected"
"                err = 1.0;"
"            end"
"            expected = double(idx + 1);"
"            if expected > 4.0"
"                expected = 1.0;"
"            end"
"        end"
"    end"
"end"
"prev = acc;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["a1", "a2", "a3", "a4", "t", "t_step", "err"], ...
    ["a1", "a2", "a3", "a4"]);
setDiscreteSampleTime(blockPath);
end

function setSevereDropScript(blockPath)
script = [
"function detected = severe_drop_detector(iload,t,threshold)"
"%#codegen"
"persistent initial_load latched"
"if isempty(initial_load)"
"    initial_load = iload;"
"end"
"if isempty(latched)"
"    latched = false;"
"end"
"if t < 1.0e-9"
"    initial_load = iload;"
"    latched = false;"
"end"
"if (initial_load - iload) >= threshold"
"    latched = true;"
"end"
"detected = double(latched);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["iload", "t", "threshold", "detected"], strings(0, 1));
setDiscreteSampleTime(blockPath);
end

function setChartScriptAndTypes(blockPath, script, dataNames, booleanNames)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
for idx = 1:numel(dataNames)
    data = chart.find("-isa", "Stateflow.Data", "Name", char(dataNames(idx)));
    if ~isempty(data)
        data.Props.Type.Method = "Built-in";
        if any(dataNames(idx) == booleanNames)
            data.Props.Type.Primitive = "boolean";
        else
            data.Props.Type.Primitive = "double";
        end
        data.Props.Array.Size = "1";
    end
end
end

function setDiscreteSampleTime(blockPath)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if ~isempty(chart)
    try
        chart.UpdateMethod = "DISCRETE";
        chart.SampleTime = "Ts_ctrl";
    catch
        try
            set_param(blockPath, "SampleTime", "Ts_ctrl");
        catch
        end
    end
end
try
    set_param(blockPath, "SystemSampleTime", "Ts_ctrl");
catch
end
end

function setFastSampleTime(blockPath)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if ~isempty(chart)
    try
        chart.UpdateMethod = "DISCRETE";
        chart.SampleTime = "Tss";
    catch
        try
            set_param(blockPath, "SampleTime", "Tss");
        catch
        end
    end
end
try
    set_param(blockPath, "SystemSampleTime", "Tss");
catch
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

function deleteBlockIfExists(blockPath)
try
    get_param(blockPath, "Handle");
    delete_block(blockPath);
catch
end
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end
