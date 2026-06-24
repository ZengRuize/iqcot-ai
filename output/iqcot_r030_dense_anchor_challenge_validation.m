function rows = iqcot_r030_dense_anchor_challenge_validation(runSimulink, maxCases, startRow)
%IQCOT_R030_DENSE_ANCHOR_CHALLENGE_VALIDATION Run or dry-run R030 challenge cases.
%
% Default dry run:
%   iqcot_r030_dense_anchor_challenge_validation(false)
%
% Full derived-Simulink challenge validation:
%   iqcot_r030_dense_anchor_challenge_validation(true)
%
% Chunked validation:
%   iqcot_r030_dense_anchor_challenge_validation(true, 10, 11)
%
% This wrapper reuses the R027 table-in-loop runner with planMode
% "r030_challenge".  It reads:
%   E:/Desktop/codex/output/iqcot_r030_dense_anchor_challenge_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file.  AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop.

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
    runSimulink, "r030_challenge", maxCases, startRow);
end
