# Power analysis
Method: gate-level zero-delay simulation of the post-route netlist (20 chained blocks) -> VCD -> OpenSTA `read_vcd` with nominal SPEF, tt_025C_1v80 liberty, report_power.

| Run | Total | Sequential | Combinational |
|---|---|---|---|
| Z_13p50 | 16.9 mW | 6.48 mW | 4.50 mW |
| Z_13p60 | 16.8 mW | 6.46 mW | 4.47 mW |
| Z_13p70 | 16.8 mW | 6.44 mW | 4.43 mW |

Internal 10.0 mW, switching 6.83 mW, leakage 86 nW (Z_13p50). The remaining ~35% outside sequential/combinational is the clock network group.

OpenLane's vectorless estimate is 65.3 mW (default activity), roughly 4x the vector-based value; they are not comparable. Energy per block 15.29 nJ = 16.9 mW x 67 x 13.5 ns.

**Limits:** simulation-based, single workload (random data), no glitching (zero-delay), single PVT corner. Not silicon-measured. No baseline power was measured, so the design is **not** claimed to be lower power than any alternative.
