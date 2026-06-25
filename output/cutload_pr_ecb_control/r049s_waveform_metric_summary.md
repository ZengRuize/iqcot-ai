# R049S PR-ECB Release-Event Boundary Waveform Audit
Date: 2026-06-25

## Baseline check

Baseline: `PASS`.

## Windowed pair deltas
| Controller | Window | Peak improvement | Undershoot improvement | one-shot us |
|---|---|---:|---:|---:|
| `A2_1p615` | `early_local_peak` | `0.0000 mV` | `-0.2929 mV` | `1.6550` |
| `A2_1p615` | `recovery_peak` | `0.1244 mV` | `-0.7873 mV` | `1.6550` |
| `A2_1p615` | `late_settling` | `0.0354 mV` | `0.0492 mV` | `1.6550` |
| `A2_1p616` | `early_local_peak` | `0.0000 mV` | `-0.4331 mV` | `1.6950` |
| `A2_1p616` | `recovery_peak` | `0.1365 mV` | `-1.1109 mV` | `1.6950` |
| `A2_1p616` | `late_settling` | `-0.0666 mV` | `0.0596 mV` | `1.6950` |
| `A2_1p620` | `early_local_peak` | `0.0000 mV` | `-0.4331 mV` | `1.6950` |
| `A2_1p620` | `recovery_peak` | `0.1365 mV` | `-1.1109 mV` | `1.6950` |
| `A2_1p620` | `late_settling` | `-0.0666 mV` | `0.0596 mV` | `1.6950` |
| `A2_1p625` | `early_local_peak` | `0.0000 mV` | `-0.4331 mV` | `1.6950` |
| `A2_1p625` | `recovery_peak` | `0.1365 mV` | `-1.1109 mV` | `1.6950` |
| `A2_1p625` | `late_settling` | `-0.0666 mV` | `0.0596 mV` | `1.6950` |
| `A2_1p630` | `early_local_peak` | `0.0000 mV` | `-0.4331 mV` | `1.6950` |
| `A2_1p630` | `recovery_peak` | `0.1365 mV` | `-1.1109 mV` | `1.6950` |
| `A2_1p630` | `late_settling` | `-0.0666 mV` | `0.0596 mV` | `1.6950` |

## Decision
```text
MODEL_REVISED
```

## Interpretation
The one-shot event jumps between the `1.615us` and `1.616us` release-delay settings.  This confirms that the binary release delay is quantized by the controller sample/update event, not a smooth waveform-control knob.
