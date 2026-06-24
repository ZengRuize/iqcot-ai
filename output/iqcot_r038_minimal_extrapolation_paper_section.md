### R038 minimal extrapolation validation

To test whether the R037 short-horizon `r_hat` interface overfits the observed
folded-band anchors, R038 executes nine additional derived-Simulink
delayed-reference cases around the local boundaries. Around `tau_AI=1.25us`,
the `42/44us` left-neighbor probes remain worse than the previously validated
`46us` folded commit. Around `tau_AI=1.75us`, the `52/56us` probes remain worse
than `54us`. Around the center pocket, `46us@1.5us` triggers a skip event and
`54us@1.5us` has longer settling, so the existing `50us` anchor remains the
better local candidate.

The only boundary that changes is `tau_AI=2.0us`. The new `44/48us` probes are
near-tied with the old dense-inclusive `30us` fallback; `48us` is lower than
`30us` by approximately `0.020` score in the current objective.
This does not justify replacing the dense fallback globally. The safer wording
is that R038 turns the `tau_AI=2us` rule from a hard `30us` fallback into a
local `30/44/48us` foldback near-tie band that still requires `B_epsilon^sw`
projection and further validation before deployment.
