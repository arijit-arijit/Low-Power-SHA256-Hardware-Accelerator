# Publication audit

## Collected
576 files copied from the original project by `assemble_repo.sh`, 0 missing, 375 MB before pruning (oversized timing `max.rpt`/`min.rpt` reports). Originals untouched. RTL in the Windows repo and the OpenLane worktree compared: identical for all six files.

## Verified against evidence
| Claim | Status |
|---|---|
| A: 6572 generic / 8871 mapped / 67457.1968 µm² / 1322 FF / 11884.06 ps | VERIFIED |
| "7169 generic cells" | CONTRADICTED (actual 6572); not used |
| C: −23.50% delay, +5.76% area vs A | VERIFIED |
| Z_13p50 setup +0.0274, hold +0.0502, area 134637, 0 antenna/DRC/LVS/slew/cap | VERIFIED (metrics.csv) |
| 566.06 Mbit/s; 15.29 nJ; 67 cycles | VERIFIED (arithmetic + log) |
| 16.90 mW | VERIFIED (power.rpt, 1.69e-02 W) |
| 20-block gate-level PASS | VERIFIED (pw_sim.log) and 20/20 golden independently recomputed |
| −0.27 ns discrepancy | EXPLAINED (13.2 ns implementation SDC; −0.273 = 0.0274 − 0.3); original log not recovered |
| E2 pre-route STA | UNVERIFIED (not found) |
| E2 better than C post-route | UNVERIFIED; ABC estimate shows E2 slower than C |
| Verilator lint log | UNVERIFIED (not found) |

## Excluded
VCD/ODB/SPEF files, raw run directories, `.git`, Blender files, duplicate images.

## Remaining before publishing
1. Run the prune command and confirm the repo size.
2. Decide headline run: Z_13p50 (fastest, +0.027 ns) vs Z_13p60 (+0.127 ns).
3. Confirm license, repo name and AI-assistance wording.
4. Optionally locate S2-vs-E2 evidence; otherwise leave `docs/optimization.md` as is.
5. Nothing has been pushed.

## Readiness
Documents and results are consistent with recovered evidence. Ready for local review; not ready to claim an E2-vs-C improvement or a measured "low-power" benefit.
