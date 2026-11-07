# Low-Power SHA-256 Hardware Accelerator — RTL, PPA Exploration and SKY130 ASIC Implementation

An iterative, **block-level** SHA-256 compression core written in SystemVerilog, verified against known-answer vectors and a C reference model, synthesized with Yosys/ABC, and taken through a complete OpenLane 2 / OpenROAD flow on the SKY130 HD library, ending in a DRC-, LVS- and antenna-clean layout.

> **Scope, stated plainly.** The core accepts one **already-padded 512-bit block** plus a 256-bit chaining value (`h_in`). It does **not** pad messages, sequence multiple blocks, or supply the initial hash values; the caller does. "Low-power" in the title describes the project goal. Measured power is a **simulation-based estimate** (see below) and no silicon was fabricated or measured.

## Headline results (all from tool output; see `results/` and `docs/`)

| Item | Value | Source / method |
|---|---|---|
| Architecture | 1 round/clock, 67 cycles per block | gate-level sim log |
| Post-route area (std-cell) | 134,637 µm² | OpenLane `design__instance__area__stdcell` |
| Signoff clock (best run, `Z_13p50`) | 13.5 ns (74.07 MHz) | 9-corner post-route STA |
| Worst setup / hold slack | +0.027 ns / +0.050 ns | `max_ss_100C_1v60` / `min_ff_n40C_1v95` |
| Throughput | 566.06 Mbit/s | 512 b / (67 x 13.5 ns) |
| Power | 16.9 mW | OpenSTA `read_vcd`, nom SPEF, tt/1.8 V/25 °C, 20 blocks |
| Energy per block | 15.29 nJ | 16.9 mW x 67 x 13.5 ns |
| DRC / LVS / antenna | 0 / 0 / 0 | Magic + KLayout / Netgen / OpenROAD |
| Gate-level functional check | 20/20 blocks PASS | `pw_sim.log` |

**Timing margin caveat.** `Z_13p50` closes with only +0.027 ns of setup slack. The same layout evaluated against the 13.2 ns *implementation* constraint fails by −0.273 ns. `Z_13p60` (+0.127 ns) is the more conservative signoff point. Details in `docs/timing_analysis.md`.

## Design lineage (pre-layout synthesis, Yosys 0.33 + ABC, SKY130 HD tt_025C_1v80)

| Design | Change | Area (µm²) | ABC delay estimate (ps) |
|---|---|---|---|
| A | pre-CSA baseline | 67,457.2 | 11,884.06 |
| B | carry-save adders | 71,315.9 | 10,057.63 |
| C | + Sklansky prefix adder (digest accumulate) | 71,343.4 | 9,091.20 |
| E2 | + prefix adders on round `a_next`/`e_next` (final RTL) | 71,715.0 | 9,972.04 |

C improves the ABC delay estimate by 23.50% versus A for +5.76% area. **E2 has a worse ABC estimate than C.** E2 is the final RTL, but the evidence for why it was chosen over C is incomplete; see `docs/optimization.md`. ABC numbers are estimates, not static timing analysis.

## Repository layout

```
rtl/               six synthesizable SystemVerilog modules
verification/      testbenches, vectors, C reference model, logs, power flow
synthesis/         Yosys/ABC scripts, constraints, reports, netlist
physical_design/   OpenLane configs, SDC, per-run reports, final layout files
results/           CSV summaries and final_results.md
images/            diagrams, charts, layout plots, 3D renders
docs/              architecture, RTL, verification, synthesis, timing, PD, power, limitations
scripts/           helper scripts
```

## Reproduce

```bash
cd verification/scripts && make test        # unit + core tests (Icarus Verilog)
bash ../../scripts/run_all_tests.sh         # same, logged to verification/results/
bash ../../scripts/generate_ppa_summary.sh  # re-derive tables from metrics files
```
Synthesis and OpenLane flows need Yosys 0.33, OpenSTA, OpenLane 2.3.10 and the SKY130 PDK; see `docs/references/tool_versions.md`.

## Honest notes

* Golden digests for the 20-block power test were produced by this project's RTL simulation, then independently confirmed with a separate SHA-256 implementation during publication review.
* Post-route area is about 1.9x synthesis area; the breakdown (timing-repair buffers, tap/fill, clock tree) has not been itemised here.
* Die is 900x900 µm at 17.3% utilization, chosen to ease routing/timing, not to minimise area.
* Parts of this project were developed with AI assistance.

## License
MIT. See `LICENSE`.
