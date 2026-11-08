# Physical design (OpenLane 2.3.10 / OpenROAD, SKY130 HD)
Config: 900x900 µm die, synthesis AREA 0 strategy, heuristic diode insertion (threshold 60), slew margin 60%, placement hold margin 0.05, global-route hold margin 0.025.

Stages completed for `Z_13p50/60/70` (same layout): floorplan, power grid, placement, CTS, global/detailed route (DRC iterations 3414 -> 1074 -> 926 -> 24 -> 0), STA, IR drop, Magic + KLayout DRC, Netgen LVS, GDS stream-out.

## Run equivalence

`Z_13p50`, `Z_13p60` and `Z_13p70` use the same OpenLane configuration and implementation SDC (13.2 ns); they differ only in the signoff SDC. SHA-256 of the final artifacts is identical for all three runs (hashes recorded by the project owner with `sha256sum`):

| Artifact | SHA-256 (all three runs) |
|---|---|
| final netlist | `c074f8bb91c27f4328ac53ba51272325a1ac9561c10cf24e09a5c70fd1e536ce` |
| OpenROAD database (ODB) | `749b444230c15b3c6f7df34e1fbb791b21666aed7e4317ceca172571da9f840b` |
| DEF | `ec7e32eb8c6688130c5d2d24d5465381a8ec9a0f6a14552abc3c3259fc882570` |

The stream-out **GDS files are not byte-identical** across the runs (their SHA-256 values differ). Layout equivalence was checked separately with KLayout `strmcmp --terse`: Z_13p50 against Z_13p60, and Z_13p50 against Z_13p70, using the Magic stream-out GDS files. Both comparisons exited with code 0, meaning no layout differences were reported. So the GDS files are equivalent according to `strmcmp` but not byte-identical; the byte differences are not explained by that check, and the exact cause (for example stream-out metadata) has not been established. `physical_design/final_layout/` holds the Z_13p50 GDS. The `strmcmp` results were recorded by the project owner and the comparison output was not saved as a log in this repository.

| Metric (Z_13p50) | Value |
|---|---|
| Instances | 30,858 |
| Std-cell area | 134,637 µm² |
| Utilization | 17.3% |
| Wirelength | 513,467 (OpenLane units) |
| Route DRC / Magic DRC / KLayout DRC | 0 / 0 / 0 |
| LVS errors | 0 |
| Antenna violating nets | 0 |
| Antenna diode cells (`sky130_fd_sc_hd__diode_2`) | 10,255 total, of which 8,453 inserted by the heuristic diode pass (`search13_report.txt`); a different metric from violating nets. The metrics key `antenna_diodes_count = 2` is not used |
| Hold buffers / timing-repair buffers / clock buffers | 235 / 1,349 / 377 |
| Sequential cells | 1,322 |
| Die / core area | 810,000 / 778,377 µm² |
| Slew / cap violations | 0 / 0 |

Area note: at 2.5024 µm² per `diode_2` (from `search13_report.txt`), the 10,255 antenna diodes account for about 25,662 µm², roughly 19% of the 134,637 µm² standard-cell area. The 235 hold-repair cells (10.0096 µm² each) account for about 2,352 µm² (1.7%). These are arithmetic from the recorded per-cell areas; the rest of the growth over the 71,715 µm² synthesis area (timing-repair and clock buffers, tap cells) has not been itemised.

Layout images: `images/physical_design/`, `images/chip_render/` (3D renders are visualizations, not signoff artifacts).
