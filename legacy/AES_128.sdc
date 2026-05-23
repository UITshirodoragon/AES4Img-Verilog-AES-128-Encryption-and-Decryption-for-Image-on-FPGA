create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]
create_generated_clock -name CLK_25 -source [get_ports {CLOCK_50}] -divide_by 2 [get_registers {*|clk_25}]
derive_clock_uncertainty
