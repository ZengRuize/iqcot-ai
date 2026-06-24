function rows = iqcot_r036_dense_paired_boundary_validation(runSimulink, maxCases, startRow)
%IQCOT_R036_DENSE_PAIRED_BOUNDARY_VALIDATION Run/dry-run R036 dense-pair cases.
%
% Default dry run:
%   iqcot_r036_dense_paired_boundary_validation(false)
%
% Full derived-Simulink validation:
%   iqcot_r036_dense_paired_boundary_validation(true)
%
% This wrapper reuses the R027 delayed-reference runner with planMode
% "r036_dense_pair". It reads:
%   E:/Desktop/codex/output/iqcot_r036_dense_paired_boundary_validation_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop. R036 results
% are derived-Simulink dense-paired boundary checks, not hardware validation
% and not proof of global T_slew optimality.

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
    runSimulink, "r036_dense_pair", maxCases, startRow);
end
