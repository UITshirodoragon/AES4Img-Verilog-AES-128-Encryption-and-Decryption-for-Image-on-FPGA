# Timing simulation template after Quartus compilation.
# Adjust paths to your generated .vo/.sdo files.
# Example:
# vlib work
# vlog -work work simulation/modelsim/top.vo
# vlog -work work sim/models/sram_model_async16.v
# vlog -work work sim/tb/<your_timing_tb>.v
# vsim -t 1ps -L cycloneii_ver -sdftyp /dut=simulation/modelsim/top_v.sdo work.<your_timing_tb>
# add wave *
# run -all
puts "Template only: set .vo/.sdo paths from Quartus EDA Netlist Writer."
