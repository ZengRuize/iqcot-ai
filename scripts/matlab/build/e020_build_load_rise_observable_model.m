function modelFile = e020_build_load_rise_observable_model(variant)
%E020_BUILD_LOAD_RISE_OBSERVABLE_MODEL Build E020 load-rise derived models.
% The baseline model is copied first. All edits are applied only to the copy.

if nargin < 1
    variant = "B0";
end
variant = string(variant);
isR1Variant = startsWith(variant, "R1-");

projectRoot = "E:\Desktop\codex";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", "four_phase_ideal_digital_iqcot.slx");
derivedRoot = fullfile(projectRoot, "models", "derived");
if variant == "B0"
    modelName = "E020_B0_load_rise_observable_from_ideal_iqcot_20260629";
elseif variant == "B1"
    modelName = "E020_B1_fast_request_from_ideal_iqcot_20260629";
elseif variant == "B2"
    modelName = "E020_B2_ton_boost_from_ideal_iqcot_20260629";
elseif variant == "B3"
    modelName = "E020_B3_fast_request_ton_boost_from_ideal_iqcot_20260629";
elseif isR1Variant
    safeVariant = regexprep(char(variant), "[^0-9A-Za-z]+", "_");
    modelName = "E020_" + string(safeVariant) + "_aU_window_from_ideal_iqcot_" + string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
else
    error("Unknown E020 variant: %s", variant);
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
addActivePhaseSetLog(modelName);
addRequiredAuditLogs(modelName);
if isR1Variant
    addR1DiagnosticLogs(modelName);
end
if variant == "B1" || variant == "B3" || isR1Variant
    addFastRequest(modelName);
end
if variant == "B2" || variant == "B3" || isR1Variant
    addTonBoost(modelName);
end
markTonCommandLogs(modelName);
addTonActualEstimators(modelName);

set_param(modelName, ...
    "SignalLogging", "on", ...
    "SignalLoggingName", "logsout", ...
    "ReturnWorkspaceOutputs", "on", ...
    "StopTime", "0.54e-3", ...
    "MaxStep", "5e-9");

save_system(modelName, modelFile);
fprintf("E020_%s_DERIVED_MODEL=%s\n", variant, modelFile);
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
set_param(ccsPath, "Name", "E020_Load_Current_Source");
ccsPath = modelName + "/E020_Load_Current_Source";
set_param(ccsPath, "Position", oldPosition, "Source_Type", "DC", ...
    "Amplitude", "0", "Measurements", "None");

stepBlock = modelName + "/E020_LoadCurrentStep";
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

function addActivePhaseSetLog(modelName)
constBlock = modelName + "/E020_ActivePhaseSet";
termBlock = modelName + "/E020_ActivePhaseSet_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(constBlock);
add_block("simulink/Sources/Constant", constBlock, ...
    "Value", "[1 1 1 1]", "Position", [3720 520 3820 550]);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [3900 522 3920 548]);
connectBlocks(constBlock, 1, termBlock, 1);
markBlockOutport(constBlock, 1, "active_phase_set");
end

function addRequiredAuditLogs(modelName)
markBlockOutport(modelName + "/PhaseScheduler_4Phase", 5, "phase_idx");
addFromLog(modelName, "tr1", "REQ1", [3720 700 3780 728]);
addFromLog(modelName, "tr2", "REQ2", [3720 745 3780 773]);
addFromLog(modelName, "tr3", "REQ3", [3720 790 3780 818]);
addFromLog(modelName, "tr4", "REQ4", [3720 835 3780 863]);
addFromLog(modelName, "Lambda_i", "Lambda_i", [3720 880 3795 908]);
addFromLog(modelName, "A_iqcot", "area_int_i", [3720 925 3795 953]);
end

function addR1DiagnosticLogs(modelName)
for phase = 1:4
    addFromLog(modelName, "tr" + phase, "REQ_accept" + phase, [4330 690 + 45 * phase 4405 718 + 45 * phase]);
    addFromLog(modelName, "IL" + phase, "IL_sense" + phase, [4330 900 + 45 * phase 4405 928 + 45 * phase]);
end

clockBlock = modelName + "/E020_R1_Diag_Clock";
voutBlock = modelName + "/E020_R1_Diag_Vout";
vrefBlock = modelName + "/E020_R1_Diag_Vref";
tstepBlock = modelName + "/E020_R1_Diag_LoadStepTime";
targetBlock = modelName + "/E020_R1_Diag_TargetLoad";
limitBlock = modelName + "/E020_R1_Diag_CurrentLimit";
settleBlock = modelName + "/E020_R1_Diag_SettlingBand";
lateGuardEnableBlock = modelName + "/E020_R1_Diag_LateGuardEnable";
diagBlock = modelName + "/E020_R1_Diagnostic";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(targetBlock);
deleteBlockIfExists(limitBlock);
deleteBlockIfExists(settleBlock);
deleteBlockIfExists(lateGuardEnableBlock);
deleteBlockIfExists(diagBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [4310 1120 4350 1150]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [4310 1165 4365 1193]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E020_Vref", "Position", [4310 1210 4425 1235]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [4310 1255 4425 1280]);
add_block("simulink/Sources/Constant", targetBlock, ...
    "Value", "Iload_final", "Position", [4310 1300 4425 1325]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E020_CurrentLimit_Guard", "Position", [4310 1345 4425 1370]);
add_block("simulink/Sources/Constant", settleBlock, ...
    "Value", "E020_Settling_Band", "Position", [4310 1390 4425 1415]);
add_block("simulink/Sources/Constant", lateGuardEnableBlock, ...
    "Value", "E020_LateRecoveryGuard_Enable", "Position", [4310 1435 4425 1460]);

ilBlocks = strings(1, 4);
for phase = 1:4
    ilBlocks(phase) = modelName + "/E020_R1_Diag_IL" + phase;
    deleteBlockIfExists(ilBlocks(phase));
    y = 1480 + 45 * (phase - 1);
    add_block("simulink/Signal Routing/From", ilBlocks(phase), ...
        "GotoTag", "IL" + phase, "Position", [4310 y 4365 y+28]);
end

add_block("simulink/User-Defined Functions/MATLAB Function", diagBlock, ...
    "Position", [4565 1190 4820 1370]);
setR1DiagnosticScript(diagBlock);
connectBlocks(clockBlock, 1, diagBlock, 1);
connectBlocks(voutBlock, 1, diagBlock, 2);
connectBlocks(vrefBlock, 1, diagBlock, 3);
connectBlocks(tstepBlock, 1, diagBlock, 4);
connectBlocks(targetBlock, 1, diagBlock, 5);
connectBlocks(limitBlock, 1, diagBlock, 6);
connectBlocks(settleBlock, 1, diagBlock, 7);
connectBlocks(lateGuardEnableBlock, 1, diagBlock, 8);
for phase = 1:4
    connectBlocks(ilBlocks(phase), 1, diagBlock, 8 + phase);
end

names = ["current_limit_hit", "phase_current_peak", "current_rise_target_state", ...
    "late_recovery_guard_state", "Vout_error", "Vout_error_slope", ...
    "settling_band_state", "phase_order_error", "REQ_reject_reason"];
for idx = 1:numel(names)
    termBlock = modelName + "/E020_R1_Diag_" + names(idx) + "_Term";
    deleteBlockIfExists(termBlock);
    y = 1190 + 32 * (idx - 1);
    add_block("simulink/Sinks/Terminator", termBlock, ...
        "Position", [4930 y+5 4950 y+25]);
    connectBlocks(diagBlock, idx, termBlock, 1);
    markBlockOutport(diagBlock, idx, names(idx));
end
end

function addFromLog(modelName, tagName, signalName, position)
safeName = regexprep(signalName, "[^0-9A-Za-z_]", "_");
fromBlock = modelName + "/E020_Log_" + safeName + "_From";
termBlock = modelName + "/E020_Log_" + safeName + "_Term";
deleteBlockIfExists(termBlock);
deleteBlockIfExists(fromBlock);
add_block("simulink/Signal Routing/From", fromBlock, ...
    "GotoTag", tagName, "Position", position);
add_block("simulink/Sinks/Terminator", termBlock, ...
    "Position", [position(3)+90 position(2)+2 position(3)+110 position(4)-2]);
connectBlocks(fromBlock, 1, termBlock, 1);
markBlockOutport(fromBlock, 1, signalName);
end

function markTonCommandLogs(modelName)
for phase = 1:4
    markBlockOutport(modelName + "/IQCOT_Ton_Adapter", phase, "Ton_cmd" + phase);
end
end

function addFastRequest(modelName)
clockBlock = modelName + "/E020_FastRequest_Clock";
enableBlock = modelName + "/E020_FastRequest_Enable";
tstepBlock = modelName + "/E020_FastRequest_LoadStepTime";
windowBlock = modelName + "/E020_FastRequest_Window";
periodBlock = modelName + "/E020_FastRequest_Period";
pulseWidthBlock = modelName + "/E020_FastRequest_PulseWidth";
voutBlock = modelName + "/E020_FastRequest_Vout";
vrefBlock = modelName + "/E020_FastRequest_Vref";
bandBlock = modelName + "/E020_FastRequest_UndershootBand";
limitBlock = modelName + "/E020_FastRequest_CurrentLimit";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(periodBlock);
deleteBlockIfExists(pulseWidthBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(limitBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [-1110 2210 -1070 2240]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E020_FastRequest_Enable", "Position", [-1110 2260 -990 2285]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [-1110 2305 -990 2330]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E020_FastRequest_Window", "Position", [-1110 2350 -990 2375]);
add_block("simulink/Sources/Constant", periodBlock, ...
    "Value", "E020_FastRequest_Period", "Position", [-1110 2395 -990 2420]);
add_block("simulink/Sources/Constant", pulseWidthBlock, ...
    "Value", "E020_FastRequest_PulseWidth", "Position", [-1110 2440 -990 2465]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [-1110 2485 -1050 2513]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E020_Vref", "Position", [-1110 2530 -990 2555]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E020_Undershoot_Band", "Position", [-1110 2575 -990 2600]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E020_CurrentLimit_Guard", "Position", [-1110 2620 -990 2645]);

ilBlocks = strings(1, 4);
for phase = 1:4
    ilBlocks(phase) = modelName + "/E020_FastRequest_IL" + phase;
    deleteBlockIfExists(ilBlocks(phase));
    y = 2665 + 45 * (phase - 1);
    add_block("simulink/Signal Routing/From", ilBlocks(phase), ...
        "GotoTag", "IL" + phase, "Position", [-1110 y -1050 y+28]);
end

fastBlock = modelName + "/E020_FastRequest";
activeTerm = modelName + "/E020_FastRequest_Active_Term";
countTerm = modelName + "/E020_FastRequest_Count_Term";
rejectTerm = modelName + "/E020_FastRequest_Reject_Term";
stateTerm = modelName + "/E020_FastRequest_State_Term";
deleteBlockIfExists(activeTerm);
deleteBlockIfExists(countTerm);
deleteBlockIfExists(rejectTerm);
deleteBlockIfExists(stateTerm);
deleteBlockIfExists(fastBlock);
add_block("simulink/User-Defined Functions/MATLAB Function", fastBlock, ...
    "Position", [-760 2100 -560 2205]);
setFastRequestScript(fastBlock);
add_block("simulink/Sinks/Terminator", activeTerm, ...
    "Position", [-430 2150 -410 2175]);
add_block("simulink/Sinks/Terminator", countTerm, ...
    "Position", [-430 2190 -410 2215]);
add_block("simulink/Sinks/Terminator", rejectTerm, ...
    "Position", [-430 2230 -410 2255]);
add_block("simulink/Sinks/Terminator", stateTerm, ...
    "Position", [-430 2270 -410 2295]);

detectBlock = findDetectRiseBlock(modelName);
gotoTr = modelName + "/Goto17";
set_param(gotoTr, "Position", [-500 2105 -460 2135]);
disconnectInport(gotoTr, 1);
connectBlocks(detectBlock, 1, fastBlock, 1);
connectBlocks(clockBlock, 1, fastBlock, 2);
connectBlocks(tstepBlock, 1, fastBlock, 3);
connectBlocks(windowBlock, 1, fastBlock, 4);
connectBlocks(periodBlock, 1, fastBlock, 5);
connectBlocks(pulseWidthBlock, 1, fastBlock, 6);
connectBlocks(enableBlock, 1, fastBlock, 7);
connectBlocks(voutBlock, 1, fastBlock, 8);
connectBlocks(vrefBlock, 1, fastBlock, 9);
connectBlocks(bandBlock, 1, fastBlock, 10);
connectBlocks(limitBlock, 1, fastBlock, 11);
for phase = 1:4
    connectBlocks(ilBlocks(phase), 1, fastBlock, 11 + phase);
end
connectBlocks(fastBlock, 1, gotoTr, 1);
connectBlocks(fastBlock, 2, activeTerm, 1);
connectBlocks(fastBlock, 3, countTerm, 1);
connectBlocks(fastBlock, 4, rejectTerm, 1);
connectBlocks(fastBlock, 5, stateTerm, 1);
markBlockOutport(fastBlock, 1, "tr_fast_projected");
markBlockOutport(fastBlock, 2, "fast_request_active");
markBlockOutport(fastBlock, 3, "fast_request_count");
markBlockOutport(fastBlock, 4, "fast_req_reject_reason");
markBlockOutport(fastBlock, 5, "fast_req_state");
end

function addTonBoost(modelName)
clockBlock = modelName + "/E020_TonBoost_Clock";
enableBlock = modelName + "/E020_TonBoost_Enable";
tstepBlock = modelName + "/E020_TonBoost_LoadStepTime";
windowBlock = modelName + "/E020_TonBoost_Window";
tmaxBlock = modelName + "/E020_TonBoost_Max";
decayBlock = modelName + "/E020_TonBoost_DecayRate";
voutBlock = modelName + "/E020_TonBoost_Vout";
vrefBlock = modelName + "/E020_TonBoost_Vref";
bandBlock = modelName + "/E020_TonBoost_UndershootBand";
limitBlock = modelName + "/E020_TonBoost_CurrentLimit";
targetBlock = modelName + "/E020_TonBoost_TargetLoad";
settleBlock = modelName + "/E020_TonBoost_SettlingBand";
lateGuardEnableBlock = modelName + "/E020_TonBoost_LateGuardEnable";

deleteBlockIfExists(clockBlock);
deleteBlockIfExists(enableBlock);
deleteBlockIfExists(tstepBlock);
deleteBlockIfExists(windowBlock);
deleteBlockIfExists(tmaxBlock);
deleteBlockIfExists(decayBlock);
deleteBlockIfExists(voutBlock);
deleteBlockIfExists(vrefBlock);
deleteBlockIfExists(bandBlock);
deleteBlockIfExists(limitBlock);
deleteBlockIfExists(targetBlock);
deleteBlockIfExists(settleBlock);
deleteBlockIfExists(lateGuardEnableBlock);

add_block("simulink/Sources/Clock", clockBlock, "Position", [3680 900 3720 930]);
add_block("simulink/Sources/Constant", enableBlock, ...
    "Value", "E020_TonBoost_Enable", "Position", [3680 950 3795 975]);
add_block("simulink/Sources/Constant", tstepBlock, ...
    "Value", "t_load_step", "Position", [3680 995 3795 1020]);
add_block("simulink/Sources/Constant", windowBlock, ...
    "Value", "E020_TonBoost_Window", "Position", [3680 1040 3795 1065]);
add_block("simulink/Sources/Constant", tmaxBlock, ...
    "Value", "Tton_boost_max", "Position", [3680 1085 3795 1110]);
add_block("simulink/Sources/Constant", decayBlock, ...
    "Value", "E020_Boost_Decay_Rate", "Position", [3680 1130 3795 1155]);
add_block("simulink/Signal Routing/From", voutBlock, ...
    "GotoTag", "Vout", "Position", [3680 1175 3735 1203]);
add_block("simulink/Sources/Constant", vrefBlock, ...
    "Value", "E020_Vref", "Position", [3680 1220 3795 1245]);
add_block("simulink/Sources/Constant", bandBlock, ...
    "Value", "E020_Undershoot_Band", "Position", [3680 1265 3795 1290]);
add_block("simulink/Sources/Constant", limitBlock, ...
    "Value", "E020_CurrentLimit_Guard", "Position", [3680 1310 3795 1335]);
add_block("simulink/Sources/Constant", targetBlock, ...
    "Value", "Iload_final", "Position", [3680 1355 3795 1380]);
add_block("simulink/Sources/Constant", settleBlock, ...
    "Value", "E020_Settling_Band", "Position", [3680 1400 3795 1425]);
add_block("simulink/Sources/Constant", lateGuardEnableBlock, ...
    "Value", "E020_LateRecoveryGuard_Enable", "Position", [3680 1445 3795 1470]);

sumIlBlocks = strings(1, 4);
for phase = 1:4
    sumIlBlocks(phase) = modelName + "/E020_TonBoost_SumIL" + phase;
    deleteBlockIfExists(sumIlBlocks(phase));
    ySum = 1490 + 45 * (phase - 1);
    add_block("simulink/Signal Routing/From", sumIlBlocks(phase), ...
        "GotoTag", "IL" + phase, "Position", [3680 ySum 3735 ySum+28]);
end

    for phase = 1:4
        ilBlock = modelName + "/E020_TonBoost_IL" + phase;
        boostBlock = modelName + "/E020_TonBoost" + phase;
        activeTerm = modelName + "/E020_TonBoost" + phase + "_Active_Term";
        stateTerm = modelName + "/E020_TonBoost" + phase + "_State_Term";
        gainTerm = modelName + "/E020_TonBoost" + phase + "_Gain_Term";
        windowTerm = modelName + "/E020_TonBoost" + phase + "_Window_Term";
        decayTerm = modelName + "/E020_TonBoost" + phase + "_Decay_Term";
        fallbackTerm = modelName + "/E020_TonBoost" + phase + "_Fallback_Term";
        deleteBlockIfExists(activeTerm);
        deleteBlockIfExists(stateTerm);
        deleteBlockIfExists(gainTerm);
        deleteBlockIfExists(windowTerm);
        deleteBlockIfExists(decayTerm);
        deleteBlockIfExists(fallbackTerm);
        deleteBlockIfExists(boostBlock);
        deleteBlockIfExists(ilBlock);

        y = 870 + 105 * phase;
        add_block("simulink/Signal Routing/From", ilBlock, ...
            "GotoTag", "IL" + phase, "Position", [3830 y+85 3885 y+113]);
        add_block("simulink/User-Defined Functions/MATLAB Function", boostBlock, ...
            "Position", [3920 y 4150 y+110]);
        setTonBoostScript(boostBlock);
        add_block("simulink/Sinks/Terminator", activeTerm, ...
            "Position", [4265 y+45 4285 y+70]);
        add_block("simulink/Sinks/Terminator", stateTerm, ...
            "Position", [4265 y+75 4285 y+100]);
        add_block("simulink/Sinks/Terminator", gainTerm, ...
            "Position", [4265 y+105 4285 y+130]);
        add_block("simulink/Sinks/Terminator", windowTerm, ...
            "Position", [4265 y+135 4285 y+160]);
        add_block("simulink/Sinks/Terminator", decayTerm, ...
            "Position", [4265 y+165 4285 y+190]);
        add_block("simulink/Sinks/Terminator", fallbackTerm, ...
            "Position", [4265 y+195 4285 y+220]);

        disconnectInport(modelName + "/COT_Cell_1Phase" + phase, 3);
        connectBlocks(modelName + "/IQCOT_Ton_Adapter", phase, boostBlock, 1);
        connectBlocks(clockBlock, 1, boostBlock, 2);
        connectBlocks(tstepBlock, 1, boostBlock, 3);
        connectBlocks(windowBlock, 1, boostBlock, 4);
        connectBlocks(tmaxBlock, 1, boostBlock, 5);
        connectBlocks(decayBlock, 1, boostBlock, 6);
        connectBlocks(enableBlock, 1, boostBlock, 7);
        connectBlocks(voutBlock, 1, boostBlock, 8);
        connectBlocks(vrefBlock, 1, boostBlock, 9);
        connectBlocks(bandBlock, 1, boostBlock, 10);
        connectBlocks(ilBlock, 1, boostBlock, 11);
        connectBlocks(limitBlock, 1, boostBlock, 12);
        connectBlocks(lateGuardEnableBlock, 1, boostBlock, 13);
        connectBlocks(targetBlock, 1, boostBlock, 14);
        connectBlocks(settleBlock, 1, boostBlock, 15);
        for sumPhase = 1:4
            connectBlocks(sumIlBlocks(sumPhase), 1, boostBlock, 15 + sumPhase);
        end
        connectBlocks(boostBlock, 1, modelName + "/COT_Cell_1Phase" + phase, 3);
        connectBlocks(boostBlock, 2, activeTerm, 1);
        connectBlocks(boostBlock, 3, stateTerm, 1);
        connectBlocks(boostBlock, 4, gainTerm, 1);
        connectBlocks(boostBlock, 5, windowTerm, 1);
        connectBlocks(boostBlock, 6, decayTerm, 1);
        connectBlocks(boostBlock, 7, fallbackTerm, 1);
        markBlockOutport(boostBlock, 1, "Ton_cmd_boost" + phase);
        markBlockOutport(boostBlock, 2, "ton_boost_active" + phase);
        if phase == 1
            markBlockOutport(boostBlock, 3, "Ton_boost_state");
            markBlockOutport(boostBlock, 4, "Ton_boost_gain");
            markBlockOutport(boostBlock, 5, "Ton_boost_window");
            markBlockOutport(boostBlock, 6, "Ton_boost_decay_state");
            markBlockOutport(boostBlock, 7, "fallback_to_nominal_state");
        else
            markBlockOutport(boostBlock, 3, "Ton_boost_state_p" + phase);
            markBlockOutport(boostBlock, 4, "Ton_boost_gain_p" + phase);
            markBlockOutport(boostBlock, 5, "Ton_boost_window_p" + phase);
            markBlockOutport(boostBlock, 6, "Ton_boost_decay_state_p" + phase);
            markBlockOutport(boostBlock, 7, "fallback_to_nominal_state_p" + phase);
        end
    end
end

function addTonActualEstimators(modelName)
clockBlock = modelName + "/E020_TonActual_Clock";
deleteBlockIfExists(clockBlock);
add_block("simulink/Sources/Clock", clockBlock, "Position", [3720 620 3760 650]);

for phase = 1:4
    estimator = modelName + "/E020_TonActual" + phase;
    termBlock = modelName + "/E020_TonActual" + phase + "_Term";
    deleteBlockIfExists(termBlock);
    deleteBlockIfExists(estimator);

    y = 610 + 70 * phase;
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

function setR1DiagnosticScript(blockPath)
script = [
"function [current_limit_hit,phase_current_peak,current_rise_target_state,late_recovery_guard_state,Vout_error,Vout_error_slope,settling_band_state,phase_order_error,REQ_reject_reason] = r1_diag(t,vout,vref,t_step,target_load,current_limit,settle_band,late_guard_enable,il1,il2,il3,il4)"
"%#codegen"
"persistent prev_t prev_error"
"if isempty(prev_t)"
"    prev_t = t;"
"end"
"if isempty(prev_error)"
"    prev_error = vout - vref;"
"end"
"Vout_error = vout - vref;"
"dt = max(t - prev_t, eps);"
"Vout_error_slope = (Vout_error - prev_error) / dt;"
"phase_current_peak = max(max(abs(il1), abs(il2)), max(abs(il3), abs(il4)));"
"current_limit_hit = double((current_limit > 0.0) && (phase_current_peak > current_limit));"
"current_rise_target_state = double((t >= t_step) && ((il1 + il2 + il3 + il4) >= 0.9 * target_load));"
"settling_band_state = double(abs(Vout_error) <= settle_band);"
"slope_release = (Vout_error < 0.0) && (Vout_error_slope > 0.0);"
"band_release = abs(Vout_error) <= max(5.0 * settle_band, settle_band);"
"late_recovery_guard_state = double((late_guard_enable > 0.5) && (t >= t_step) && (current_rise_target_state > 0.5 || slope_release || band_release));"
"phase_order_error = 0.0;"
"REQ_reject_reason = 0.0;"
"prev_t = t;"
"prev_error = Vout_error;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["t", "vout", "vref", "t_step", "target_load", "current_limit", ...
    "settle_band", "late_guard_enable", "il1", "il2", "il3", "il4", ...
    "current_limit_hit", "phase_current_peak", "current_rise_target_state", ...
    "late_recovery_guard_state", "Vout_error", "Vout_error_slope", ...
    "settling_band_state", "phase_order_error", "REQ_reject_reason"], ...
    strings(0, 1));
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

function setFastRequestScript(blockPath)
script = [
"function [tr_out,fast_active,fast_count,fast_reject_reason,fast_state] = fast_request(tr_in,t,t_step,t_window,period,pulse_width,enable,vout,vref,band,current_limit,il1,il2,il3,il4)"
"%#codegen"
"base_tr = logical(tr_in);"
"age = t - t_step;"
"in_window = (enable > 0.5) && (age >= 0.0) && (age <= t_window);"
"deficit = vout <= (vref - band);"
"iph_peak = max(max(abs(il1), abs(il2)), max(abs(il3), abs(il4)));"
"guard_ok = (current_limit <= 0.0) || (iph_peak <= current_limit);"
"pulse = false;"
"if in_window && deficit && guard_ok && (period > 0.0) && (pulse_width > 0.0)"
"    slot = age - floor(age / period) * period;"
"    pulse = slot <= min(pulse_width, period);"
"end"
"fast_reject_reason = 0.0;"
"if enable <= 0.5"
"    fast_reject_reason = 1.0;"
"elseif age < 0.0 || age > t_window"
"    fast_reject_reason = 2.0;"
"elseif ~deficit"
"    fast_reject_reason = 3.0;"
"elseif ~guard_ok"
"    fast_reject_reason = 4.0;"
"elseif period <= 0.0 || pulse_width <= 0.0"
"    fast_reject_reason = 5.0;"
"end"
"tr_out = base_tr || pulse;"
"fast_active = double(pulse && ~base_tr);"
"fast_count = fast_active;"
"fast_state = double(in_window && deficit && guard_ok);"
];
setChartScriptAndTypes(blockPath, script, ...
    ["tr_in", "t", "t_step", "t_window", "period", "pulse_width", "enable", ...
    "vout", "vref", "band", "current_limit", "il1", "il2", "il3", "il4", ...
    "tr_out", "fast_active", "fast_count", "fast_reject_reason", "fast_state"], ...
    ["tr_in", "tr_out"]);
end

function setTonBoostScript(blockPath)
script = [
"function [ton_out,boost_active,boost_state,boost_gain,boost_window,boost_decay_state,fallback_state] = ton_boost(ton_in,t,t_step,t_window,t_max,decay_rate,enable,vout,vref,band,il_i,current_limit,late_guard_enable,target_load,settle_band,il1,il2,il3,il4)"
"%#codegen"
"persistent prev_t prev_error"
"if isempty(prev_t)"
"    prev_t = t;"
"end"
"if isempty(prev_error)"
"    prev_error = vout - vref;"
"end"
"age = t - t_step;"
"in_window = (enable > 0.5) && (age >= 0.0) && (age <= t_window);"
"deficit = vout <= (vref - band);"
"guard_ok = (current_limit <= 0.0) || (abs(il_i) <= current_limit);"
"verr = vout - vref;"
"dt = max(t - prev_t, eps);"
"verr_slope = (verr - prev_error) / dt;"
"current_target_reached = (t >= t_step) && ((il1 + il2 + il3 + il4) >= 0.9 * target_load);"
"slope_release = (verr < 0.0) && (verr_slope > 0.0);"
"band_release = abs(verr) <= max(5.0 * settle_band, settle_band);"
"late_guard = (late_guard_enable > 0.5) && (t >= t_step) && (current_target_reached || slope_release || band_release);"
"active = in_window && deficit && guard_ok && ~late_guard && (t_max > ton_in);"
"boost_window = t_window;"
"boost_gain = 0.0;"
"boost_decay_state = 0.0;"
"if active"
"    decay = exp(-max(decay_rate, 0.0) * max(age, 0.0));"
"    target = ton_in + (t_max - ton_in) * decay;"
"    ton_out = min(max(target, ton_in), t_max);"
"    boost_gain = decay;"
"    boost_decay_state = double(decay < 0.1);"
"else"
"    ton_out = ton_in;"
"end"
"boost_active = double(active);"
"boost_state = double(in_window && deficit && guard_ok && ~late_guard);"
"fallback_state = double((t >= t_step) && ((~active && age > t_window) || late_guard));"
"prev_t = t;"
"prev_error = verr;"
];
setChartScriptAndTypes(blockPath, script, ...
    ["ton_in", "t", "t_step", "t_window", "t_max", "decay_rate", "enable", ...
    "vout", "vref", "band", "il_i", "current_limit", "ton_out", "boost_active", ...
    "late_guard_enable", "target_load", "settle_band", "il1", "il2", "il3", "il4", ...
    "boost_state", "boost_gain", "boost_window", "boost_decay_state", "fallback_state"], ...
    strings(0, 1));
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

rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
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
setChartDataTypes(chart, ["qh", "t", "Ton_actual"], "qh");
end

function setChartScriptAndTypes(blockPath, script, dataNames, booleanNames)
rt = sfroot;
chart = rt.find("-isa", "Stateflow.EMChart", "Path", char(blockPath));
if isempty(chart)
    error("Could not find MATLAB Function chart for %s", blockPath);
end
chart.Script = strjoin(script, newline);
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
        data.Props.Array.Size = "1";
    end
end
end

function blockPath = findDetectRiseBlock(modelName)
matches = find_system(modelName, "SearchDepth", 1, ...
    "ReferenceBlock", "simulink/Logic and Bit Operations/Detect Rise Positive");
if isempty(matches)
    matches = find_system(modelName, "SearchDepth", 1, ...
        "Name", sprintf("Detect Rise\nPositive"));
end
if isempty(matches)
    error("Detect Rise Positive block not found.");
end
blockPath = string(matches{1});
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
