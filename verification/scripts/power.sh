#!/usr/bin/env bash
# usage: power.sh <run_dir> <label>
set -e
RUN=$(realpath "$1"); L=$2
cd ~/pd/wt_e2; mkdir -p build/power/$L
LIBDIR=$(ls -d ~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/verilog | head -1)
LIB=$(ls ~/.volare/volare/sky130/versions/*/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib | head -1)
NL=$RUN/final/nl/sha256_core.nl.v
sed -e "s#build/tb_sha256_core.vcd#build/power/$L/gl.vcd#" \
    -e 's#\$dumpvars(0, tb_sha256_core)#$dumpvars(0, tb_sha256_core.dut)#' \
    tb/tb_sha256_core.sv > build/power/$L/tb_gl.sv
nice -n 19 iverilog -g2012 -DFUNCTIONAL "-DUNIT_DELAY=#0" -Wno-timescale -o build/power/$L/gl.vvp \
  build/power/$L/tb_gl.sv $NL $LIBDIR/primitives.v $LIBDIR/sky130_fd_sc_hd.v
nice -n 19 vvp build/power/$L/gl.vvp > build/power/$L/gl_sim.log 2>&1
echo "[$L] $(grep -E 'TB_RESULT' build/power/$L/gl_sim.log)"
cat > build/power/$L/power.tcl <<EOF
read_liberty $LIB
read_verilog $NL
link_design sha256_core
read_sdc $RUN/final/sdc/sha256_core.sdc
read_spef $RUN/final/spef/nom/sha256_core.nom.spef
read_vcd -scope tb_sha256_core/dut build/power/$L/gl.vcd
report_power
EOF
nice -n 19 /home/arijit/OpenSTA/build/sta -no_splash -exit build/power/$L/power.tcl > build/power/$L/power.rpt 2>&1
echo "[$L] $(grep -E '^Total' build/power/$L/power.rpt) | $(grep -E 'Annotated' build/power/$L/power.rpt)"
rm -f build/power/$L/gl.vcd   # 43 MB, regenerable
