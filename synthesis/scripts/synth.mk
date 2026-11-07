# Technology-mapped synthesis (Yosys + ABC, SKY130 HD). Included by the top-level Makefile.
#   make fetch_lib   download the SKY130 HD liberty and verify its sha256 (needs internet)
#   make synth       generic + SKY130-mapped synthesis of sha256_core, reports in synth/reports/
#   make gls         zero-delay gate-level simulation of the mapped netlist with the core testbench
# Run inside Ubuntu (WSL2). Needs: yosys curl sha256sum sed.

CLK_PS     ?= 10000
LIB_NAME   := sky130_fd_sc_hd__tt_025C_1v80.lib
LIB_URL    := https://raw.githubusercontent.com/The-OpenROAD-Project/OpenROAD-flow-scripts/master/flow/platforms/sky130hd/lib/$(LIB_NAME)
LIB_SHA256 := ec0e1067a35c8bf20b11e58d1e8ac53326067e4dac84a125cc1b917a3518d0d9
LIB        := synth/lib/$(LIB_NAME)
LIB_DU     := build/sky130_hd_tt_dontuse.lib

.PHONY: fetch_lib synth gls

fetch_lib: $(LIB)

$(LIB):
	mkdir -p synth/lib
	curl -fsSL -o $@.tmp $(LIB_URL)
	echo "$(LIB_SHA256)  $@.tmp" | sha256sum -c - || { rm -f $@.tmp; echo "sha256 mismatch: upstream file changed or download corrupt"; exit 1; }
	mv $@.tmp $@

# Same liberty with `dont_use : true;` added to the cells listed in synth/dont_use.txt
# (Yosys 0.33 has no -dont_use option for dfflibmap/abc, so the attribute is put in the file).
$(LIB_DU): $(LIB) synth/dont_use.txt
	mkdir -p build
	sed 's|.*|/^[[:space:]]*cell ("&") {$$/a\\        dont_use : true;|' synth/dont_use.txt > build/dont_use.sed
	sed -f build/dont_use.sed $(LIB) > $@
	@test "$$(grep -c 'dont_use : true' $@)" = "$$(wc -l < synth/dont_use.txt)" || { echo "dont_use annotation count mismatch"; exit 1; }

synth: $(LIB_DU) $(CORE_RTL) synth/synth.ys.in synth/abc.constr
	mkdir -p build synth/reports
	sed -e 's|@CLK_PS@|$(CLK_PS)|g' -e 's|@LIB@|$(LIB_DU)|g' synth/synth.ys.in > build/synth.ys
	yosys -l build/yosys_sky130.log build/synth.ys > /dev/null
	cp build/yosys_sky130.log synth/reports/yosys_sky130.log
	grep "ABC: Path" build/yosys_sky130.log | sed 's/^ABC: //' > synth/reports/abc_critical_path.rpt
	synth/summarize.sh build/yosys_sky130.log $(LIB) $(CLK_PS) | tee synth/reports/summary.txt
	@for c in $$(cat synth/dont_use.txt); do ! grep -q "$$c" build/sha256_core_netlist.v || { echo "dont_use cell used: $$c"; exit 1; }; done; echo "dont_use check: none of the $$(wc -l < synth/dont_use.txt) excluded cells appear in the netlist"

# Zero-delay functional check of the mapped netlist: liberty cell functions are read by Yosys,
# the netlist is flattened to plain Verilog and the SAME core testbench is run on it.
gls: synth build/core_vectors.txt
	yosys -q -p "read_liberty -ignore_miss_func $(LIB_DU); read_verilog build/sha256_core_netlist.v; hierarchy -top sha256_core; flatten; opt_clean; write_verilog -noattr build/sha256_core_gls.v" 2> /dev/null
	iverilog -g2012 -Wno-timescale -o build/tb_gls.vvp $(CORE_TB) build/sha256_core_gls.v
	vvp build/tb_gls.vvp | tee build/tb_gls.log
	@grep -q "TB_RESULT: PASS" build/tb_gls.log
