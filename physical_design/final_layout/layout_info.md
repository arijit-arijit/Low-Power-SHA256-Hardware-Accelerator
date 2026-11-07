# Final layout
Source run: `Z_13p50` (identical layout to Z_13p60/Z_13p70). Files expected in this folder after running `assemble_repo.sh`: GDS (Magic stream-out ~33.9 MB, KLayout ~18.1 MB), DEF (~17 MB), LEF. All are under GitHub's 100 MiB per-file limit; consider a Release asset if the repo should stay small.
Layout plots: `images/physical_design/`. 3D renders: `images/chip_render/` (visualizations only).
Layout checks: Magic DRC 0, KLayout DRC 0, Netgen LVS 0 errors (see `physical_design/reports/`).
