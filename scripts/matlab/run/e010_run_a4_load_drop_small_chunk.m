function rows = e010_run_a4_load_drop_small_chunk(baseLoadA, targetLoadA)
%E010_RUN_A4_LOAD_DROP_SMALL_CHUNK Run the first E010 AI/table-selected a_O case.

if nargin < 1
    baseLoadA = 40;
end
if nargin < 2
    targetLoadA = 10;
end
rows = e010_run_a0_load_drop_small_chunk("A4", baseLoadA, targetLoadA);
end
