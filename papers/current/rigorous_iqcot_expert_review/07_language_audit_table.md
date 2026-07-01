# Language Audit Table

Date: 2026-07-01
Branch: codex/rigorous-iqcot-review-git-managed

Search command:

```text
rg -n -i "IQCOT cannot|cannot distinguish|cannot respond|AI fixes|AI.*control.*gate|AI.*controls.*converter|AI.*solves|solve[s]? load transient|fixes IQCOT|cannot regulate" docs papers results experiments -g "*.md"
```

Canonical replacement wording:

```text
IQCOT naturally responds through variable-frequency event generation. The proposed supervisor does not replace this inner loop; it only selects bounded supervisory actions under safety projection.
```

| Risky Wording | Why It Is Wrong | Replacement Wording | Files Updated |
|---|---|---|---|
| `IQCOT cannot distinguish load-rise/load-drop` | It incorrectly implies the deterministic inner loop lacks basic response; branch distinction belongs to supervisory action selection | Load-rise and load-drop are separated at the supervisory-action level because enhancement actions have opposite energy effects | No direct current hit found in current target docs |
| `IQCOT cannot respond to dynamic load` | It denies IQCOT variable-frequency voltage regulation | IQCOT naturally responds through variable-frequency event generation; the supervisor adds bounded enhancements | No direct current hit found in current target docs |
| `AI fixes IQCOT regulation` | It frames the work as repairing a basic IQCOT defect | The contribution is safety-projected supervisory action-token selection around IQCOT | New review package and summary updates |
| `AI controls converter` | It can be read as direct gate or power-stage control | AI/table supervisor proposes low-dimensional tokens; only projected parameters reach IQCOT scheduling | Existing hit in `docs/ai_control_oriented_model_innovation_20260624.md` is already negated as "not that AI directly controls the converter"; no edit made to avoid unrelated legacy churn |
| `AI solves load transient` | It overclaims global transient solution | Local derived-Simulink evidence supports specific bounded mechanisms and explicit unresolved boundaries | New claim strategy and boundary register |
| `A5 solves severe 40A -> 1A` | A5 is frozen as `MODEL_REVISED` boundary evidence | Severe `40A -> 1A` remains unresolved under projected scheduling tokens | Claim boundary updates |
| `E020 solves full 120A recovery` | E020/R1 improve early behavior but no 1 mV settling was shown | `a_U` is locally confirmed for early load-rise dynamic regulation, not complete 120A settling | Claim boundary updates |

## Audit Interpretation

Most current high-risk phrases appear inside forbidden-claim lists or negated statements. Those are acceptable because they explicitly prevent overclaiming. The new review package adds a positive canonical framing so future manuscript edits can avoid ambiguous negative phrasing.
