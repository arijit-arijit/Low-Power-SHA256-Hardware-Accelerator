# Final results (every number traces to a saved tool output)

## Post-route (OpenLane 2.3.10, SKY130 HD, one layout, three signoff clocks)
| Run | Signoff clock | Setup ws | Hold ws | Area µm² | Throughput | Power | Energy/block |
|---|---|---|---|---|---|---|---|
| Z_13p50 | 13.5 ns | +0.0274 | +0.0502 | 134,637 | 566.06 Mbit/s | 16.9 mW | 15.29 nJ |
| Z_13p60 | 13.6 ns | +0.1274 | +0.0502 | 134,637 | 561.9 Mbit/s | 16.8 mW | 15.31 nJ |
| Z_13p70 | 13.7 ns | +0.2274 | +0.0502 | 134,637 | 557.8 Mbit/s | 16.8 mW | 15.42 nJ |

All: 67 cycles/block, 0 DRC (Magic, KLayout), 0 LVS errors, 0 antenna violations, 0 slew/cap violations, 20-block gate-level PASS.
The same layout at 13.2 ns fails setup (−0.273 ns).

## Synthesis (pre-layout)
See `ppa_comparison.csv`. A -> C: −23.50% ABC delay estimate, +5.76% area. E2 final: 71,715 µm², 9,972 ps estimate.

Throughput = 512 bit / (67 x clock). Energy = power x 67 x clock; computed from power rounded to 3 digits.
