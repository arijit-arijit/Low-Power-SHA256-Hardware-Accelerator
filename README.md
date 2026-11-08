# Low-Power SHA-256 Hardware Accelerator

A hardware implementation of the SHA-256 compression algorithm using **Verilog and SystemVerilog**, developed and taken through synthesis, timing analysis and physical design using the **SKY130 HD** technology.

Low power was an original design objective. However, the completed work does not demonstrate lower power compared with a baseline or alternative implementation.

## Chip Layout

<p align="center">
  <img src="images/chip_render/elevated.png" width="75%" alt="3D SHA-256 chip render">
</p>

<p align="center">
  <img src="images/physical_design/Z_13p60_2d_zoom.png" width="75%" alt="SHA-256 physical layout close-up">
</p>

## Architecture

The accelerator uses an iterative architecture, performing one SHA-256 compression round per clock cycle.

**Main RTL modules:**
- `sha256_core.sv` – Top-level module.
- `sha256_ctrl.sv` – Controller and FSM.
- `sha256_round.sv` – SHA-256 round operations.
- `sha256_msg_sched.sv` – Message schedule generation.
- `sha256_k_rom.sv` – Round constants.
- `prefix_add32.sv` – 32-bit prefix adder.

The core accepts a pre-padded 512-bit message block and a 256-bit initial chaining value. Padding and multi-block sequencing are handled externally.

![Architecture](images/architecture/top_level_architecture.png)

**Module hierarchy:** [View diagram](images/rtl/module_hierarchy.png)

**Latency:** 67 clock cycles per 512-bit block.

## Synthesis and Optimization

Pre-layout synthesis using Yosys 0.33 and ABC with the SKY130 HD library:

| Design | Optimization | Area (µm²) | ABC delay estimate |
|---|---|---:|---:|
| A | Baseline | 67,457 | 11,884 ps |
| B | Carry-save adders | 71,316 | 10,058 ps |
| C | Prefix adder in digest accumulation | 71,343 | 9,091 ps |
| E2 | Prefix adders in round datapath | 71,715 | 9,972 ps |

The A-to-C implementation reduced the ABC delay estimate by **23.5%**, with a **5.8% increase in area**. These are synthesis estimates, not post-route timing results. E2 is the final RTL taken through physical design.

![Synthesis comparison](images/synthesis/synthesis_comparison.png)

## Physical Design Results

The final design was implemented using **OpenLane 2, OpenROAD and SKY130 HD**.

Two final candidates:

| Metric | Z_13p60 | Z_13p50 |
|---|---:|---:|
| Signoff clock | 13.6 ns | 13.5 ns |
| Setup slack | +0.127 ns | +0.027 ns |
| Hold slack | +0.050 ns | +0.050 ns |
| Cell area | 134,637 µm² | 134,637 µm² |
| Power estimate | 16.8 mW | 16.9 mW |
| Energy per block | 15.31 nJ | 15.29 nJ |
| Antenna-violating nets | 0 | 0 |
| DRC / LVS errors | 0 / 0 | 0 / 0 |

Z_13p60 is the primary candidate because it provides greater setup margin.

Reported throughput: **561.9 Mbit/s** at the 13.6 ns signoff clock.

![Setup slack](images/timing/setup_slack_by_signoff_clock.png)

The implemented layout has approximately -0.273 ns setup slack when checked against its 13.2 ns implementation constraint. Signoff results use their stated constraints.

**Power limitation:** Power figures are simulation-based estimates from a post-route netlist, using 20 blocks and zero-delay gate-level simulation with nominal SPEF at tt / 1.8 V / 25 °C. No baseline power measurement was performed, so a power improvement has not been established.

### Physical Design Views

![Placement](images/physical_design/placement.png)

- [Full layout](images/physical_design/Z_13p60_2d_full.png)
- [Routing layers](images/physical_design/Z_13p60_2d_metals.png)

The final layout has a 900 × 900 µm die and 17.3% utilization.

## Verification

Verification was performed using SystemVerilog testbenches and a C-based SHA-256 reference model.

- K-constant ROM: 385 checks.
- Message scheduler: 406 checks.
- Controller: 777 checks.
- Core: 751 checks.
- Prefix adder: 200,000 random vectors plus directed tests.
- Known-answer tests: 0, 3, 55, 56, 64 and 119-byte messages.
- Gate-level verification: 20 out of 20 block digests matched independently computed reference results.

All reported test groups passed.

### Run Verification

From the repository root:

```bash
bash scripts/run_all_tests.sh
```

Requirements: `make`, `gcc`, `iverilog` and `verilator`.

## Tools Used

- Verilog / SystemVerilog
- Icarus Verilog and Verilator
- Yosys and ABC
- OpenSTA
- OpenLane 2 and OpenROAD
- SKY130 HD PDK
- Magic, Netgen and KLayout

## Repository Structure

```text
rtl/              RTL source files
verification/     Testbenches, vectors and logs
synthesis/        Synthesis scripts and reports
physical_design/  Physical-design files and final layout
results/          PPA, timing, power and area results
images/           Architecture, chip and layout images
docs/             Detailed project documentation
scripts/           Verification and utility scripts
```

## Limitations

- Block-level compression core; no hardware message padding or multi-block sequencing.
- Initial chaining value is supplied externally.
- Lower power than a baseline was not demonstrated.
- The final RTL's ABC delay estimate is slower than intermediate design C.
- Physical-design area is relatively large due to the chosen die size and implementation overhead.

For detailed methodology, results and limitations, see the [documentation](docs/).

## License

MIT License. See [LICENSE](LICENSE).
