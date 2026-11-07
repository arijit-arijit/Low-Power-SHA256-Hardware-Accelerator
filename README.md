# Low-Power SHA-256 Hardware Accelerator

A hardware implementation of the SHA-256 compression algorithm using SystemVerilog, followed by synthesis, timing analysis and physical design using the SKY130 technology.

The project explores RTL optimization, verification and ASIC implementation using an open-source EDA toolchain.

## Chip Layout

<p align="center">
  <img src="images/chip_render/elevated.png" width="75%" alt="3D SHA-256 chip render">
</p>

<p align="center">
  <img src="images/physical_design/Z_13p60_2d_zoom.png" width="75%" alt="SHA-256 physical layout close-up">
</p>

## Architecture

The accelerator uses an iterative architecture, performing one SHA-256 compression round per clock cycle.

Main RTL modules:

- `sha256_core.sv` – Top-level module.
- `sha256_ctrl.sv` – Controller and FSM.
- `sha256_round.sv` – SHA-256 round operations.
- `sha256_msg_sched.sv` – Message schedule generation.
- `sha256_k_rom.sv` – SHA-256 round constants.
- `prefix_add32.sv` – 32-bit prefix adder.

The core accepts a pre-padded 512-bit message block and a 256-bit initial chaining value. Message padding and block sequencing are handled externally.

## Implementation Results

The design was synthesized using Yosys and ABC and taken through the OpenLane 2 physical-design flow using the SKY130 HD library.

The following are the two final candidates:

| Metric | Z_13p60 | Z_13p50 |
|---|---:|---:|
| Signoff clock | 13.6 ns | 13.5 ns |
| Setup slack | +0.127 ns | +0.027 ns |
| Hold slack | +0.050 ns | +0.050 ns |
| Cell area | 134,637 µm² | 134,637 µm² |
| Sustained power | 16.8 mW | 16.9 mW |
| Energy per block | 15.31 nJ | 15.29 nJ |
| Antenna nets | 0 | 0 |
| DRC / LVS | 0 / 0 | 0 / 0 |

Z_13p60 is the primary candidate because it has a larger setup margin. Z_13p50 provides slightly higher throughput at a tighter timing margin.

The reported throughput is approximately 561.9 Mbit/s for Z_13p60.

The timing results are specific to their stated signoff constraints. The implemented layout has a reported negative setup slack of approximately -0.273 ns when checked at its 13.2 ns implementation constraint.

Power values are simulation-based estimates, not measurements from fabricated silicon.

## Verification

The design was tested using SystemVerilog testbenches and a C-based SHA-256 reference model.

Verification includes:

- Individual RTL module testing.
- SHA-256 core testing.
- Message scheduler testing.
- Controller and datapath testing.
- Gate-level functional verification.

The final gate-level check matched 20 out of 20 tested block digests against independently recomputed SHA-256 results.

## Tools Used

- SystemVerilog
- Icarus Verilog
- Yosys
- ABC
- OpenSTA
- OpenLane 2
- OpenROAD
- SKY130 HD PDK
- Magic
- Netgen
- KLayout
- GTKWave

## Repository Structure

```text
rtl/              SystemVerilog source files
verification/     Testbenches, vectors and reference model
synthesis/        Synthesis scripts, reports and netlists
physical_design/  OpenLane configurations and physical-design results
results/          PPA comparison and final results
images/            Architecture and chip layout images
docs/               Project documentation
scripts/            Utility scripts
```

## Running Verification

From the project root:

```bash
cd verification/scripts
make test
```

The synthesis and physical-design flows require the corresponding EDA tools and SKY130 PDK. Refer to `docs/references/tool_versions.md` for tool versions.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
