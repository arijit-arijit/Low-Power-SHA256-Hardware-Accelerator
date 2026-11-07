#!/bin/sh
# Collect the headline numbers of a `make synth` run from the tool outputs. Nothing is computed
# or estimated here; every value is copied from a Yosys report or log line.
# usage: synth/summarize.sh <yosys.log> <lib> <clk_ps>
LOG=$1; LIB=$2; CLK_PS=$3
G=synth/reports/stat_generic.rpt
T=synth/reports/stat_sky130.rpt
echo "== SHA-256 core synthesis summary =="
echo "yosys        : $(yosys -V)"
echo "liberty      : $(basename "$LIB")  sha256 $(sha256sum "$LIB" | cut -d' ' -f1)"
echo "ABC target   : -D $CLK_PS ps (synthesis target, not an OpenSTA constraint)"
echo
echo "-- GENERIC synthesis (technology independent, no area unit) --"
grep -E "Number of cells|_DFF|_SDFF" "$G" | sed 's/^ */  /'
echo
echo "-- SKY130 HD mapped (tt_025C_1v80) --"
grep -E "Number of cells|Chip area" "$T" | sed 's/^ */  /'
echo "  flip-flops (dfxtp_1): $(grep -E 'sky130_fd_sc_hd__df' "$T" | awk '{s+=$2} END{print s+0}')"
echo
echo "-- ABC delay ESTIMATE (no wires, no clock skew; NOT static timing analysis) --"
grep "WireLoad" "$LOG" | tail -1 | sed 's/^ABC: */  /; s/ *$//'
echo "  target $CLK_PS ps -> $(grep 'WireLoad' "$LOG" | tail -1 | sed -E 's/.*Delay = *([0-9.]+) ps.*/\1/' | awk -v t="$CLK_PS" '{ if ($1 > t) print "estimate EXCEEDS target"; else print "estimate within target" }')"
