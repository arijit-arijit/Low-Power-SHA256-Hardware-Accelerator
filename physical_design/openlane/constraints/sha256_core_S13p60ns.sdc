# 10 ns clock constraint
create_clock -name clk -period 13.600 [get_ports clk]

# Assumed clock uncertainty
set_clock_uncertainty 0.250 [get_clocks clk]

# Assumed interface delays: 2 ns
set_input_delay 2.000 -clock clk [all_inputs -no_clocks]
set_output_delay 2.000 -clock clk [all_outputs]
