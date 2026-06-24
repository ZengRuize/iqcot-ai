function rows = iqcot_r031_minimal_validation(runSimulink, maxCases, startRow)
%IQCOT_R031_MINIMAL_VALIDATION Run or dry-run R031 minimal held-out cases.
%
% Default dry run:
%   iqcot_r031_minimal_validation(false)
%
% Full derived-Simulink validation:
%   iqcot_r031_minimal_validation(true)
%
% Chunked validation:
%   iqcot_r031_minimal_validation(true, 8, 1)
%   iqcot_r031_minimal_validation(true, 8, 9)
%   iqcot_r031_minimal_validation(true, 6, 17)
%
% This wrapper reuses the R027 delayed-reference runner with planMode
% "r031_minimal". It reads:
%   E:/Desktop/codex/output/iqcot_r031_minimal_validation_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop. R031 results
% are derived-Simulink validation candidates, not hardware validation and not
% proof of global T_slew optimality.

if nargin < 1 || isempty(runSimulink)
    runSimulink = false;
end
if nargin < 2
    maxCases = [];
end
if nargin < 3 || isempty(startRow)
    startRow = 1;
end

rows = iqcot_r027_proxy_table_in_loop_validation( ...
    runSimulink, "r031_minimal", maxCases, startRow);
end
