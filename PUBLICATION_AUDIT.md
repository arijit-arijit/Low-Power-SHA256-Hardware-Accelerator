# Publication audit

Status: the repository is public on GitHub (default branch `main`) and contains the RTL, verification files, synthesis and physical-design artifacts, results and documentation.

## Evidence summary
| Claim | Status | Evidence |
|---|---|---|
| Synthesis A/B/C/E2 numbers | VERIFIED | `synthesis/reports/*/summary.txt` (Yosys 0.33, SKY130 HD tt_025C_1v80) |
| "7169 generic cells" | CONTRADICTED, not used | design A reports 6572 |
| C vs A: -23.50% ABC delay estimate, +5.76% area | VERIFIED | arithmetic from the summaries |
| E2 is faster than C | NOT SUPPORTED | ABC estimate: E2 9,972 ps vs C 9,091 ps; no post-route comparison located |
| Z_13p60: setup +0.127 ns, hold +0.050 ns, area 134,637 µm² | VERIFIED | `metrics.csv`, 9-corner post-route STA |
| Z_13p50: setup +0.027 ns, hold +0.050 ns | VERIFIED | same |
| DRC / LVS / antenna / slew / cap | VERIFIED: all 0 | `metrics.csv`; zero antenna violations was reached with 10,255 `diode_2` cells (8,453 from the heuristic pass) |
| Power 16.8 / 16.9 mW | VERIFIED as simulation-based | `power.rpt`, `pw_sim.log` |
| 20-block gate-level run | VERIFIED | `pw_sim.log`: PASS, 67 cycles/block; digests also recomputed independently |
| RTL unit and core tests | VERIFIED | `verification/results/functional_logs/` and `make_test_*.log` |
| Z runs are one physical implementation | VERIFIED | identical netlist, ODB and DEF SHA-256; GDS equivalent under `strmcmp`, not byte-identical |
| -0.27 ns max_ss discrepancy | EXPLAINED | same layout checked at the 13.2 ns implementation SDC: 0.0274 - 0.3 = -0.273 ns; the original log was not recovered |

## Known limitations
- Block-level core only: no padding, multi-block control or IV selection.
- Low power was an original design objective, but lower power was not demonstrated. Power is simulation-based (zero-delay, one workload, one corner), no baseline power was measured, and the optimization campaign primarily evaluated timing and area rather than a controlled power-reduction strategy. The reported power characterizes this implementation only; it does not establish an improvement over an alternative.
- The Z_13p50 setup margin is 0.027 ns. The layout fails at its 13.2 ns implementation clock (-0.273 ns).
- Post-route area is about 1.9x synthesis area. The 10,255 antenna diodes are about 19% of it (see `docs/physical_design.md`); the remainder is only partly itemised. Zero antenna violations was bought with area.
- No pre-route STA exists for the final RTL (E2).
- Golden digests for the gate-level test were produced by this project's RTL simulation, then independently recomputed once.
- No formal verification or coverage closure.

## Missing deliverables
- `images/physical_design/floorplan.png`: not included. The early floorplan database shows only the die boundary, so it adds no information. `placement.png` (Z_13p50 detailed placement) is included.
- Original log that printed the -0.27 ns figure.

## Not done / not claimed
No silicon fabrication or measurement. No post-route comparison between designs C and E2.
