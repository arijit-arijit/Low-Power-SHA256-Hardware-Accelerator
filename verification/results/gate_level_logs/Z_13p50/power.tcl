read_liberty /home/arijit/.volare/volare/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
read_verilog /home/arijit/pd/wt_e2/pd/openlane/runs/Z_13p50/final/nl/sha256_core.nl.v
link_design sha256_core
read_sdc /home/arijit/pd/wt_e2/pd/openlane/runs/Z_13p50/final/sdc/sha256_core.sdc
read_spef /home/arijit/pd/wt_e2/pd/openlane/runs/Z_13p50/final/spef/nom/sha256_core.nom.spef
read_vcd -scope tb_sha256_power/dut build/power/Z_13p50/pw.vcd
report_power
