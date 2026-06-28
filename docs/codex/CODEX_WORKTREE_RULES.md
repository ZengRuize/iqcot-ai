# Codex Worktree Rules

## Current Research Entry Points

Use these directories for future work:

```text
docs/theory/
docs/validation/
docs/codex/
models/baseline/
models/derived/
scripts/matlab/build/
scripts/matlab/run/
scripts/matlab/postprocess/
scripts/python/postprocess/
scripts/python/reports/
experiments/
results/current/
papers/current/
```

Use these for historical evidence:

```text
legacy/
results/archive/
papers/archive/
```

## Cleanup Policy

Do not delete historical material unless the user explicitly asks. Move or copy old R0XX reports, sweep outputs, old manuscripts, and temporary logs into `legacy/`, `results/archive/`, or `papers/archive/`.

When a file is already tracked or modified, prefer copying it into an archive mirror instead of moving it. When a file is untracked and clearly temporary, it may be moved into the archive to reduce clutter.

## Current Focus

Future research focuses on:

```text
Bidirectional large-signal voltage regulation
+ PIS-IEK small-signal current-sharing / phase-recovery model
+ active-phase add/shed hybrid event management
+ AI/table supervisor with safety projection
```

Do not frame external load-current slew rate as an AI-controlled variable. It is an observed disturbance descriptor.

## Artifact Placement

- Theory updates: `docs/theory/`
- Validation protocol and metrics: `docs/validation/`
- Codex operating rules: `docs/codex/`
- Derived Simulink models: `models/derived/`
- MATLAB build scripts: `scripts/matlab/build/`
- MATLAB run scripts: `scripts/matlab/run/`
- MATLAB postprocess scripts: `scripts/matlab/postprocess/`
- Python postprocess scripts: `scripts/python/postprocess/`
- Python report scripts: `scripts/python/reports/`
- Current experiment outputs: `experiments/E###_*/`
- Latest cross-experiment summary: `results/current/latest_summary.md`
