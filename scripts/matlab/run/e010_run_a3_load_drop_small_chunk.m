function rows = e010_run_a3_load_drop_small_chunk(baseLoadA, targetLoadA)
%E010_RUN_A3_LOAD_DROP_SMALL_CHUNK Run the first E010 guarded-reentry case.

if nargin < 1
    baseLoadA = 40;
end
if nargin < 2
    targetLoadA = 10;
end
rows = e010_run_a0_load_drop_small_chunk("A3", baseLoadA, targetLoadA);
end
