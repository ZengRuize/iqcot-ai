# Codex Output Protocol for IQCOT Research Rounds

Every IQCOT research round should use the following final-output template. Keep claims tied to evidence strength, state what was not touched, and include the exact GitHub sync result.

# Codex Round Output

## 1. Task Metadata

- Task ID:
- Task name:
- Repository:
- Branch:
- Commit SHA:
- Date:
- Codex environment:
- MATLAB/Simulink used: yes/no
- Original .slx modified: yes/no
- Derived .slx used: yes/no

## 2. Objective

Use 3-5 sentences to state the round objective.
Declare exactly which category the round belongs to:

- PIS-IEK model consolidation
- actuator separation
- digital implementation budget
- PR-ECB minimal validation
- AI supervisor interface
- active-set add/shed
- literature / paper writing
- repository hygiene

## 3. Hypothesis Block

Model version:
Hypothesis:
Expected improvement:
Expected failure mode:
Metrics:
Claim boundary if successful:
Claim boundary if unsuccessful:

## 4. Files Inspected

List the key files read in this round.

## 5. Files Changed

| Path | Change type | Purpose |
|---|---|---|

## 6. Data / Figures Generated

If data was generated, use:

| File | Rows / size | Meaning | Used for claim |
|---|---:|---|---|

If no new data was generated, write:

No new simulation data generated in this round.

## 7. Key Results

Each result must include:

- numerical result if available
- baseline
- metric meaning
- whether it supports the hypothesis

Do not only write "the effect improved."

## 8. Result Classification

Choose exactly one:

MODEL_CONFIRMED
MODEL_REVISED
IMPLEMENTATION_ISSUE
CLAIM_DOWNGRADED

Explain why.

## 9. Claim Impact

| Claim ID / topic | Previous status | New status | Reason |
|---|---|---|---|
| PIS-IEK | | | |
| Ton_diff / Lambda_diff | | | |
| digital budget | | | |
| PR-ECB | | | |
| AI supervisor | | | |
| active-set model | | | |

If a topic is not touched, write `not touched`.

## 10. Forbidden Claims Check

Confirm each line:

- Did not claim inventing IQCOT.
- Did not claim hardware/HIL validation.
- Did not claim AI replaces IQCOT inner loop.
- Did not claim AI directly controls gate pulses.
- Did not claim PR-ECB universally predicts first peak.
- Did not claim Lambda_diff is strong DC current-sharing actuator.
- Did not claim active-set PIS-IEK is fully validated.
- Did not modify original `.slx`.

## 11. Limitations

State the round limitations, for example:

- derived-Simulink only
- no hardware validation
- no full matrix
- no neural AI-in-loop
- limited load-drop cases
- no active-set validation

## 12. Updated Research State

Strongest paper-ready line:
Exploratory line:
Downgraded line:
Next evidence gap:

## 13. Next Minimal Task

Recommend only one next task.

Recommended next task:
Why this is the smallest useful next step:
Expected output files:
Expected decision type:

## 14. Exact Next Prompt Draft

Write the next prompt so the user can copy it directly into Codex.

## 15. GitHub Sync

Branch:
Commit SHA:
Commit message:
Files pushed:
