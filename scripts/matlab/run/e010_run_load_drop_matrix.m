function allRows = e010_run_load_drop_matrix(cases, variants)
%E010_RUN_LOAD_DROP_MATRIX Run selected E010 load-drop cases.

if nargin < 1 || isempty(cases)
    cases = [
        40 20
        40 10
        40 1
        120 40
        120 10
    ];
end
if nargin < 2 || isempty(variants)
    variants = ["A0", "A1", "A2", "A3", "A4"];
end

allRows = table();
for caseIdx = 1:size(cases, 1)
    baseLoadA = cases(caseIdx, 1);
    targetLoadA = cases(caseIdx, 2);
    for variantIdx = 1:numel(variants)
        variant = variants(variantIdx);
        fprintf("E010_MATRIX_RUNNING variant=%s case=%.6gA_to_%.6gA\n", ...
            variant, baseLoadA, targetLoadA);
        row = e010_run_a0_load_drop_small_chunk(variant, baseLoadA, targetLoadA);
        allRows = [allRows; row]; %#ok<AGROW>
    end
end

projectRoot = "E:\Desktop\codex";
experimentRoot = fullfile(projectRoot, "experiments", "E010_load_drop_overshoot");
matrixCsv = fullfile(experimentRoot, "e010_load_drop_matrix_metrics.csv");
writetable(allRows, matrixCsv);
fprintf("E010_MATRIX_METRICS=%s\n", matrixCsv);
end
