%% IQCOT ideal digital request parameters
% Run the inherited four-phase Buck initialization first so the copied
% power stage, scheduler, gate drivers, COT cells, and Ton adapter keep the
% same source-of-truth variables as the validated source model.

iqcot_project_root = "E:\Desktop\codex";
iqcot_source_root = "E:\Desktop\4cot\versions\v0027_20260611_135822_iqcot_optimized_final_cn_docs";
iqcot_source_init = fullfile(iqcot_source_root, "init_four_phase_cot_sync.m");
if isfile(iqcot_source_init)
    run(iqcot_source_init);
end

%% Ideal digital IQCOT parameters
% The guidance seed CT=1 nF gives Lambda0=20 ns, which is too large for the
% already-validated 2 MHz global event cadence in this model. The first
% build therefore keeps VTH/gm but selects CT=15 pF so Lambda0=3e-10 V*s,
% matching the existing area-model validation scale.
Ts_ctrl = 40e-9;
Tblank = 480e-9;

CT_iqcot = 15e-12;
VTH_iqcot = 20e-3;
gm_iqcot = 1e-3;
Lambda0_iqcot = CT_iqcot * VTH_iqcot / gm_iqcot;

Ri_iqcot = 0.5e-3;
Kvc_iqcot = 1.0;
Vc_bias_iqcot = 5.6e-3;

Lambda_m2 = 0;
rho_cmd = 0;
kappa_cmd = 0;

A_init = 0;
A_lower = 0;
A_upper = inf;

IdealIQCOT_Enable = 1;
IdealIQCOT_UseNonnegativeAccumulator = 1;
IdealIQCOT_UseADCQuantization = 0;

% Keep the existing Ton adapter present but neutral for first validation.
Kiqcot = 0;
Iqcot_enable = 1;
