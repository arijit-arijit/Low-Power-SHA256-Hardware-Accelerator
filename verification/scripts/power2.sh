#!/usr/bin/env bash
# usage: power2.sh <run_dir> <label> <period_ns>
set -e
RUN=$(realpath "$1"); L=$2; T=$3
cd ~/pd/wt_e2; mkdir -p build/power/$L
LIBDIR=$(ls -d ~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/verilog | head -1)
LIB=$(ls ~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib | head -1)
NL=$RUN/final/nl/sha256_core.nl.v
HALF=$(awk -v t=$T 'BEGIN{printf "%.4f", t/2}')
nice -n 19 iverilog -g2012 -DFUNCTIONAL "-DUNIT_DELAY=#0" -Wno-timescale -o build/power/$L/pw.vvp tb/tb_sha256_power.sv $NL $LIBDIR/primitives.v $LIBDIR/sky130_fd_sc_hd.v
nice -n 19 vvp build/power/$L/pw.vvp +CHECK +HALF=$HALF +VCD=build/power/$L/pw.vcd > build/power/$L/pw_sim.log 2>&1
grep -E 'TB_RESULT|cycles per block' build/power/$L/pw_sim.log | sed "s/^/[$L] /"
cat > build/power/$L/power.tcl <<EOT
read_liberty $LIB
read_verilog $NL
link_design sha256_core
read_sdc $RUN/final/sdc/sha256_core.sdc
read_spef $RUN/final/spef/nom/sha256_core.nom.spef
read_vcd -scope tb_sha256_power/dut build/power/$L/pw.vcd
report_power
EOT
nice -n 19 /home/arijit/OpenSTA/build/sta -no_splash -exit build/power/$L/power.tcl > build/power/$L/power.rpt 2>&1
grep -E 'vcd period|Annotated' build/power/$L/power.rpt | sed "s/^/[$L] /"
grep -E '^(Sequential|Combinational|Clock|Total)' build/power/$L/power.rpt | sed "s/^/[$L] /"
awk -v t=$T -v l=$L '/^Total/{p=$5} END{printf "[%s] SUSTAINED %.2f mW at %.1f ns | energy per block (67 cycles) = %.2f nJ\n", l, p*1e3, t, p*67*t}' build/power/$L/power.rpt
rm -f build/power/$L/pw.vcd
