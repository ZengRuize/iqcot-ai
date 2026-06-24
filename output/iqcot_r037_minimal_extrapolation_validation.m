function rows = iqcot_r037_minimal_extrapolation_validation(runSimulink, maxCases, startRow)
%IQCOT_R037_MINIMAL_EXTRAPOLATION_VALIDATION Run/dry-run R037 boundary cases.
%
% Default dry run:
%   iqcot_r037_minimal_extrapolation_validation(false)
%
% Full derived-Simulink validation:
%   iqcot_r037_minimal_extrapolation_validation(true)
%
% Chunked validation:
%   iqcot_r037_minimal_extrapolation_validation(true, 3, 1)
%   iqcot_r037_minimal_extrapolation_validation(true, 3, 4)
%   iqcot_r037_minimal_extrapolation_validation(true, 3, 7)
%
% This wrapper reuses the R027 delayed-reference runner with planMode
% "r037_minimal_extrapolation". It reads:
%   E:/Desktop/codex/output/iqcot_r037_minimal_extrapolation_validation_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop. R037/R038
% results are derived-Simulink boundary checks, not hardware validation and
% not proof of global T_slew optimality.

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
    runSimulink, "r037_minimal_extrapolation", maxCases, startRow);
end
