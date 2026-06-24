function rows = iqcot_dynamic_ref_slew_fine_sweep()
%IQCOT_DYNAMIC_REF_SLEW_FINE_SWEEP Run R024 local validation of R023 candidates.
%
% This wrapper intentionally reuses iqcot_dynamic_ref_slew_sweep so that the
% derived Simulink model construction, instrumentation, and metric extraction
% stay identical to the dense/long reference-slew runs.  It only adds a local
% grid around the continuous-landscape hypotheses from R023.

fineSlewTimesUs = [32 34 35 36 38 62 64 66 68 70 84 86 88 90 92];
rows = iqcot_dynamic_ref_slew_sweep(fineSlewTimesUs, "fine");
end

