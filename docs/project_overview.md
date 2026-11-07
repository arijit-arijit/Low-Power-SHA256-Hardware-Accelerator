# Project overview
Goal: a synthesizable iterative SHA-256 compression core taken from RTL to a SKY130 layout, with measured (not assumed) PPA.

**Interface contract.** Inputs: `clk, rst_n, start, block[511:0]` (already padded), `h_in[255:0]` (chaining value). Outputs: `busy, done, digest[255:0]` = `h_in` + compression result. Padding, length encoding, multi-block chaining and IV selection are the caller's job. Not implemented: arbitrary-length messages in hardware.

**Flow.** RTL -> Icarus/Verilator simulation -> Yosys+ABC synthesis -> OpenSTA -> OpenLane 2 (OpenROAD floorplan, place, CTS, route) -> Magic/KLayout DRC -> Netgen LVS -> GDS -> gate-level simulation with VCD-based power.

**Design lineage.** A (pre-CSA) -> B (CSA) -> C (+prefix digest adder) -> E2 (+prefix round adders, final RTL).
