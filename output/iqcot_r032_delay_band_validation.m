function rows = iqcot_r032_delay_band_validation(runSimulink, maxCases, startRow)
%IQCOT_R032_DELAY_BAND_VALIDATION Run or dry-run R032 delay-band cases.
%
% Default dry run:
%   iqcot_r032_delay_band_validation(false)
%
% Full derived-Simulink validation:
%   iqcot_r032_delay_band_validation(true)
%
% Chunked validation, ordered by the R032 plan CSV:
%   iqcot_r032_delay_band_validation(true, 8, 1)
%   iqcot_r032_delay_band_validation(true, 8, 9)
%   iqcot_r032_delay_band_validation(true, 15, 17)
%
% Priority-1 block only (20A / score_settle005 probes):
%   iqcot_r032_delay_band_validation(true, 15, 17)
%
% This wrapper reuses the R027 delayed-reference runner with planMode
% "r032_delay_band". It reads:
%   E:/Desktop/codex/output/iqcot_r032_next_validation_plan.csv
%
% It uses only the derived model:
%   E:/Desktop/codex/output/simulink_iek/four_phase_iek_dynamic_load_refslew.slx
%
% It does not save or directly edit any SLX file. AI remains represented as
% a supervisory T_slew scheduler; IQCOT remains the inner loop. R032 results
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
    runSimulink, "r032_delay_band", maxCases, startRow);
end
