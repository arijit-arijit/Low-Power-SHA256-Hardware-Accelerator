# Final layout

| File | Producer | Size |
|---|---|---|
| `sha256_core_Z_13p50.gds` | Magic stream-out | ~33.9 MB |
| `sha256_core_Z_13p50.klayout.gds` | KLayout stream-out | ~18.1 MB |
| `sha256_core_Z_13p50.def` | OpenROAD final DEF | ~17.2 MB |
| `sha256_core_Z_13p50.lef` | abstract LEF | ~0.26 MB |

These files come from OpenLane run `Z_13p50` (SKY130 HD, 900 x 900 µm die). Magic DRC 0, KLayout DRC 0, Netgen LVS 0 errors, 0 antenna violations (reports under `physical_design/reports/`).

Z_13p60 and Z_13p70 are separate OpenLane runs of the same configuration signed off at 13.6 ns and 13.7 ns. Their GDS files are not included here.

Layout plots: `images/physical_design/`. 3D renders: `images/chip_render/` (visualizations only, not signoff artifacts).
