function outputs = e001_audit_baseline_model()
%E001_AUDIT_BASELINE_MODEL Read-only audit of the ideal IQCOT baseline.
% This script loads and inspects the baseline model but never saves it.

projectRoot = "E:\Desktop\codex";
modelName = "four_phase_ideal_digital_iqcot";
baselineModel = fullfile(projectRoot, "output", "simulink_ideal_iqcot", modelName + ".slx");
initScript = fullfile(projectRoot, "output", "iqcot_init_ideal_digital_iqcot_params.m");
auditRoot = fullfile(projectRoot, "experiments", "E001_baseline_audit");
ensureDir(auditRoot);

if ~isfile(baselineModel)
    error("Baseline model not found: %s", baselineModel);
end
if isfile(initScript)
    evalin("base", sprintf("run('%s')", escapeForEval(initScript)));
end

load_system(baselineModel);
cleanup = onCleanup(@() close_system(modelName, 0));

updateStatus = "PASS";
updateMessage = "";
try
    set_param(modelName, "SimulationCommand", "update");
catch ME
    updateStatus = "FAIL";
    updateMessage = string(ME.message);
end

configCsv = fullfile(auditRoot, "e001_model_config.csv");
signalCsv = fullfile(auditRoot, "e001_required_signal_audit.csv");
lineCsv = fullfile(auditRoot, "e001_named_lines.csv");
blockCsv = fullfile(auditRoot, "e001_relevant_blocks.csv");
paramCsv = fullfile(auditRoot, "e001_parameter_snapshot.csv");
workspaceCsv = fullfile(auditRoot, "e001_init_workspace_snapshot.csv");

writetable(collectModelConfig(modelName, baselineModel, initScript, updateStatus, updateMessage), configCsv);

lineTable = collectNamedLines(modelName);
writetable(lineTable, lineCsv);

signalTable = auditRequiredSignals(lineTable);
writetable(signalTable, signalCsv);

blockTable = collectRelevantBlocks(modelName);
writetable(blockTable, blockCsv);

paramTable = collectParameterSnapshot(blockTable);
writetable(paramTable, paramCsv);

workspaceTable = collectWorkspaceSnapshot();
writetable(workspaceTable, workspaceCsv);

outputs = struct( ...
    "configCsv", configCsv, ...
    "signalCsv", signalCsv, ...
    "lineCsv", lineCsv, ...
    "blockCsv", blockCsv, ...
    "paramCsv", paramCsv, ...
    "workspaceCsv", workspaceCsv, ...
    "updateStatus", updateStatus, ...
    "updateMessage", updateMessage);

fprintf("E001_MODEL_CONFIG=%s\n", configCsv);
fprintf("E001_REQUIRED_SIGNAL_AUDIT=%s\n", signalCsv);
fprintf("E001_NAMED_LINES=%s\n", lineCsv);
fprintf("E001_RELEVANT_BLOCKS=%s\n", blockCsv);
fprintf("E001_PARAMETER_SNAPSHOT=%s\n", paramCsv);
fprintf("E001_INIT_WORKSPACE_SNAPSHOT=%s\n", workspaceCsv);
fprintf("E001_UPDATE_STATUS=%s\n", updateStatus);
if strlength(updateMessage) > 0
    fprintf("E001_UPDATE_MESSAGE=%s\n", updateMessage);
end
end

function tableOut = collectModelConfig(modelName, baselineModel, initScript, updateStatus, updateMessage)
params = ["Solver", "SolverType", "FixedStep", "MaxStep", "StopTime", ...
    "SignalLogging", "SignalLoggingName", "ReturnWorkspaceOutputs", ...
    "SaveFormat", "LoadExternalInput"];
values = strings(numel(params), 1);
for idx = 1:numel(params)
    values(idx) = safeGetParam(modelName, params(idx));
end
tableOut = table( ...
    ["baseline_model"; "init_script"; "update_status"; "update_message"; params(:)], ...
    [slashPath(baselineModel); slashPath(initScript); updateStatus; updateMessage; values], ...
    'VariableNames', {'field', 'value'});
end

function lineTable = collectNamedLines(modelName)
lines = find_system(modelName, "FindAll", "on", "Type", "line");
rows = cell(numel(lines), 8);
for idx = 1:numel(lines)
    line = lines(idx);
    name = string(get_param(line, "Name"));
    [srcBlock, srcPort, srcPortHandle] = portSource(line);
    lineLogging = safeGetParam(line, "DataLogging");
    portLogging = "";
    if ~isempty(srcPortHandle) && srcPortHandle ~= -1
        portLogging = safeGetParam(srcPortHandle, "DataLogging");
    end
    rows{idx, 1} = char(cleanText(name));
    rows{idx, 2} = char(cleanText(lineLogging));
    rows{idx, 3} = char(cleanText(portLogging));
    rows{idx, 4} = char(cleanText(safeGetParam(line, "TestPoint")));
    rows{idx, 5} = char(cleanText(srcBlock));
    rows{idx, 6} = char(cleanText(srcPort));
    rows{idx, 7} = char(cleanText(lineDestinations(line)));
    rows{idx, 8} = char(cleanText(safeGetParam(line, "SegmentType")));
end
lineTable = cell2table(rows, 'VariableNames', ...
    {'signal_name', 'line_data_logging', 'source_port_data_logging', 'test_point', 'source_block', 'source_port', 'destinations', 'segment_type'});
lineTable = lineTable(strlength(string(lineTable.signal_name)) > 0 | ...
    string(lineTable.line_data_logging) == "on" | string(lineTable.source_port_data_logging) == "on", :);
lineTable = sortrows(lineTable, "signal_name");
end

function signalTable = auditRequiredSignals(lineTable)
specs = {
    'Vout', {'Vout'}, 'direct output-voltage log';
    'Iload', {'Iload','I_load','LoadCurrent','load_current','Iout'}, 'required for load-step validation';
    'IL1', {'IL1'}, 'phase current';
    'IL2', {'IL2'}, 'phase current';
    'IL3', {'IL3'}, 'phase current';
    'IL4', {'IL4'}, 'phase current';
    'QH1', {'QH1'}, 'high-side gate';
    'QH2', {'QH2'}, 'high-side gate';
    'QH3', {'QH3'}, 'high-side gate';
    'QH4', {'QH4'}, 'high-side gate';
    'QL1', {'QL1'}, 'low-side gate';
    'QL2', {'QL2'}, 'low-side gate';
    'QL3', {'QL3'}, 'low-side gate';
    'QL4', {'QL4'}, 'low-side gate';
    'REQ1', {'REQ1','REQ_iqcot','tr1'}, 'per-phase request absent; global request / accepted trigger available';
    'REQ2', {'REQ2','REQ_iqcot','tr2'}, 'per-phase request absent; global request / accepted trigger available';
    'REQ3', {'REQ3','REQ_iqcot','tr3'}, 'per-phase request absent; global request / accepted trigger available';
    'REQ4', {'REQ4','REQ_iqcot','tr4'}, 'per-phase request absent; global request / accepted trigger available';
    'phase_idx', {'phase_idx'}, 'scheduler phase index';
    'Ton_cmd_i', {'Ton_cmd_i','Ton_iqcot1','Ton_iqcot2','Ton_iqcot3','Ton_iqcot4'}, 'commanded Ton proxy currently named Ton_iqcot1..4';
    'Ton_actual_i', {'Ton_actual_i','Ton_actual1','Ton_actual2','Ton_actual3','Ton_actual4'}, 'missing explicit measured pulse width';
    'Lambda_i', {'Lambda_i'}, 'IQCOT event threshold';
    'area_int_i', {'area_int_i','A_iqcot'}, 'area integrator proxy currently named A_iqcot';
    'active_phase_set', {'active_phase_set','phase_en1','phase_en2','phase_en3','phase_en4'}, 'fixed four-phase model has phase enables but no active set bus'
    };

rows = cell(size(specs, 1), 7);
names = string(lineTable.signal_name);
for idx = 1:size(specs, 1)
    required = string(specs{idx, 1});
    alternatives = string(specs{idx, 2});
    matchMask = false(size(names));
    for altIdx = 1:numel(alternatives)
        matchMask = matchMask | names == alternatives(altIdx);
    end
    matches = lineTable(matchMask, :);
    exactMask = names == required;
    exactRows = lineTable(exactMask, :);
    present = ~isempty(exactRows) || ~isempty(matches);
    logged = false;
    if ~isempty(matches)
        logged = any(string(matches.line_data_logging) == "on" | string(matches.source_port_data_logging) == "on");
    end
    if isempty(matches)
        matchedNames = "";
        sourceBlocks = "";
    else
        matchedNames = strjoin(unique(string(matches.signal_name)), "; ");
        sourceBlocks = strjoin(unique(string(matches.source_block)), "; ");
    end
    if isempty(exactRows) && ~isempty(matches)
        status = "MAPPED_PROXY";
    elseif present && logged
        status = "PRESENT_LOGGED";
    elseif present
        status = "PRESENT_NOT_LOGGED";
    else
        status = "MISSING";
    end
    rows(idx, :) = {char(required), char(status), present, logged, char(matchedNames), char(sourceBlocks), specs{idx, 3}};
end
signalTable = cell2table(rows, 'VariableNames', ...
    {'required_signal', 'status', 'present', 'logged', 'matched_signal_names', 'source_blocks', 'notes'});
end

function blockTable = collectRelevantBlocks(modelName)
blocks = find_system(modelName, "LookUnderMasks", "all", "FollowLinks", "on", "Type", "Block");
keys = ["mosfet", "inductor", "capacitor", "current", "load", "cot", "iqcot", ...
    "phase", "gate", "scheduler", "voltage", "sum", "source", "ton"];
rows = {};
for idx = 1:numel(blocks)
    path = string(blocks{idx});
    name = string(get_param(blocks{idx}, "Name"));
    blockType = string(get_param(blocks{idx}, "BlockType"));
    maskType = string(safeGetParam(blocks{idx}, "MaskType"));
    haystack = lower(path + " " + name + " " + blockType + " " + maskType);
    if any(contains(haystack, keys))
        rows(end + 1, :) = {char(path), char(name), char(blockType), char(maskType), char(safeGetParam(blocks{idx}, "ReferenceBlock"))}; %#ok<AGROW>
    end
end
blockTable = cell2table(rows, 'VariableNames', {'block_path', 'name', 'block_type', 'mask_type', 'reference_block'});
blockTable = sortrows(blockTable, "block_path");
end

function paramTable = collectParameterSnapshot(blockTable)
paramNames = ["Ron", "Rd", "Vfd", "Rs", "Cs", "R", "Resistance", "Inductance", ...
    "L", "Capacitance", "C", "ESR", "SampleTime", "DelayLength", "InitialCondition", ...
    "Gain", "Value", "Threshold", "Ton", "Tdead", "Tblank", "Vhys"];
rows = {};
for idx = 1:height(blockTable)
    blockPath = string(blockTable.block_path(idx));
    objectParameters = [];
    try
        objectParameters = get_param(blockPath, "ObjectParameters");
    catch
    end
    if isempty(objectParameters)
        continue;
    end
    fields = string(fieldnames(objectParameters));
    for pIdx = 1:numel(paramNames)
        p = paramNames(pIdx);
        if any(fields == p)
            value = safeGetParam(blockPath, p);
            rows(end + 1, :) = {char(blockPath), char(blockTable.block_type(idx)), char(blockTable.mask_type(idx)), char(p), char(value), classifyParamValue(value)}; %#ok<AGROW>
        end
    end
end
if isempty(rows)
    paramTable = cell2table(cell(0, 6), 'VariableNames', ...
        {'block_path', 'block_type', 'mask_type', 'parameter', 'value', 'value_class'});
else
    paramTable = cell2table(rows, 'VariableNames', ...
        {'block_path', 'block_type', 'mask_type', 'parameter', 'value', 'value_class'});
    paramTable = sortrows(paramTable, ["parameter", "block_path"]);
end
end

function workspaceTable = collectWorkspaceSnapshot()
names = ["Ron_HS", "Ron_LS", "Rd", "Vfd", "Rs", "Cs", "L", "DCR_L", ...
    "Cout", "ESR", "fsw", "Ton", "Tdead", "Tblank", "Vhys", ...
    "Ts_ctrl", "Lambda0_iqcot", "Lambda_m2", "rho_cmd", "Ri_iqcot", ...
    "Kvc_iqcot", "Vc_bias_iqcot", "kappa_cmd", "Kiqcot", "Iqcot_enable"];
rows = cell(numel(names), 3);
for idx = 1:numel(names)
    name = names(idx);
    existsValue = evalin("base", sprintf("exist('%s','var')", name)) == 1;
    if existsValue
        value = evalin("base", name);
        valueString = valueToString(value);
    else
        valueString = "<missing>";
    end
    rows(idx, :) = {char(name), existsValue, char(valueString)};
end
workspaceTable = cell2table(rows, 'VariableNames', {'variable', 'exists', 'value'});
end

function valueClass = classifyParamValue(value)
txt = strtrim(string(value));
if strlength(txt) == 0
    valueClass = "empty";
elseif ~isnan(str2double(txt))
    valueClass = "numeric_literal";
elseif startsWith(txt, "[") || startsWith(txt, "{")
    valueClass = "literal_expression";
else
    valueClass = "variable_or_expression";
end
valueClass = char(valueClass);
end

function [srcBlock, srcPort, srcPortHandle] = portSource(line)
srcBlock = "";
srcPort = "";
srcPortHandle = -1;
try
    srcPortHandle = get_param(line, "SrcPortHandle");
    if srcPortHandle ~= -1
        srcBlockHandle = get_param(srcPortHandle, "ParentHandle");
        srcBlock = string(getfullname(srcBlockHandle));
        srcPort = string(get_param(srcPortHandle, "PortNumber"));
    end
catch
end
end

function destinations = lineDestinations(line)
destinations = "";
try
    dstPorts = get_param(line, "DstPortHandle");
    parts = strings(0, 1);
    for idx = 1:numel(dstPorts)
        if dstPorts(idx) ~= -1
            blockHandle = get_param(dstPorts(idx), "ParentHandle");
            parts(end + 1) = string(getfullname(blockHandle)) + ":" + string(get_param(dstPorts(idx), "PortNumber")); %#ok<AGROW>
        end
    end
    destinations = strjoin(parts, "; ");
catch
end
end

function value = safeGetParam(target, paramName)
try
    value = string(get_param(target, char(paramName)));
catch
    value = "";
end
end

function out = cleanText(value)
out = string(value);
out = replace(out, newline, " ");
out = replace(out, sprintf('\r'), " ");
out = replace(out, sprintf('\n'), " ");
out = regexprep(out, "\s+", " ");
out = strtrim(out);
end

function txt = valueToString(value)
if isnumeric(value) || islogical(value)
    if isscalar(value)
        txt = string(value);
    else
        txt = mat2str(value);
    end
elseif isstring(value)
    txt = strjoin(value, ", ");
elseif ischar(value)
    txt = string(value);
else
    txt = string(class(value));
end
end

function out = slashPath(pathValue)
out = string(strrep(char(pathValue), "\", "/"));
end

function escaped = escapeForEval(pathValue)
escaped = strrep(char(pathValue), "'", "''");
end

function ensureDir(pathValue)
if ~exist(pathValue, "dir")
    mkdir(pathValue);
end
end
