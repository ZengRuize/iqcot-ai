# Git Workflow

Date: 2026-07-01

Project policy:

1. Use one branch per research task.
2. Use atomic commits.
3. Commit Markdown/CSV evidence files.
4. Do not commit temporary MATLAB cache files.
5. Do not commit large derived `.slx` models unless explicitly required.
6. Record local derived model paths in Markdown evidence files.
7. Every experiment must have hypothesis, metrics CSV, summary Markdown, and classification.
8. Every claim expansion must update the claim boundary register.

## Branch Naming

Use the `codex/` prefix for Codex-created research branches unless the user asks for a different prefix.

Examples:

```text
codex/rigorous-iqcot-review-git-managed
codex/e020-settling-audit
codex/manuscript-evidence-package
```

## Commit Scope

Use focused documentation commits:

```text
docs: add rigorous IQCOT expert review package
docs: add research progress and git workflow tracking
docs: align IQCOT framing and claim boundaries
```

Do not stage unrelated dirty files from previous tasks.

## Files To Avoid

Do not commit:

```text
*.asv
*.autosave
*.slxc
*.mex*
*.log
*.tmp
*.bak
*_autosave*
slprj/
MATLAB temporary folders
large derived .slx files unless explicitly required
```

If a derived `.slx` is needed for traceability, record its path in Markdown evidence first and only commit the model when the user explicitly asks.
