function rows = iqcot_r034_transition_pocket_validation(runSimulink, maxCases, startRow)
%IQCOT_R034_TRANSITION_POCKET_VALIDATION Run/dry-run R034 transition-pocket cases.
%
% Default dry run:
%   iqcot_r034_transition_pocket_validation(false)
%
% Full derived-Simulink validation:
%   iqcot_r034_transition_pocket_validation(true)
%
% Chunked validation:
%   iqcot_r034_transition_pocket_validation(true, 5, 1)
%   iqcot_r034_transition_pocket_validation(true, 5, 6)
%   iqcot_r034_transition_pocket_validation(true, 5, 11)
%   iqcot_r034_transition_pocket_validation(true, 5, 16)
%
% This wrapper reuses the R027 delayed-reference runner with planMode
% "r034_transition_pocket". It reads:
%   E:/Desktop/codex/output/iqcot_r034_transition_pocket_validation_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop. R034 results
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
    runSimulink, "r034_transition_pocket", maxCases, startRow);
end
