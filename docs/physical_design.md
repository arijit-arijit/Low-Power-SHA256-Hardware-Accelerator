# Physical design (OpenLane 2.3.10 / OpenROAD, SKY130 HD)
Config: 900x900 µm die, synthesis AREA 0 strategy, heuristic diode insertion (threshold 60), slew margin 60%, placement hold margin 0.05, global-route hold margin 0.025.

Stages completed for `Z_13p50/60/70` (same layout): floorplan, power grid, placement, CTS, global/detailed route (DRC iterations 3414 -> 1074 -> 926 -> 24 -> 0), STA, IR drop, Magic + KLayout DRC, Netgen LVS, GDS stream-out.

| Metric (Z_13p50) | Value |
|---|---|
| Instances | 30,858 |
| Std-cell area | 134,637 µm² |
| Utilization | 17.3% |
| Wirelength | 513,467 (OpenLane units) |
| Route DRC / Magic DRC / KLayout DRC | 0 / 0 / 0 |
| LVS errors | 0 |
| Antenna violating nets | 0 (2 diodes inserted) |
| Slew / cap violations | 0 / 0 |

Layout images: `images/physical_design/`, `images/chip_render/` (3D renders are visualizations, not signoff artifacts).
