# ModelSim-Altera functional compile script
# Run from project root: vsim -do sim/scripts/modelsim_compile_functional.do
transcript on
if {[file exists work]} {vdel -lib work -all}
vlib work

# AES core
vlog -work work rtl/aes_core/AddRoundKey.v
vlog -work work rtl/aes_core/rcon_gen.v
vlog -work work rtl/aes_core/Sbox_8bits.v
vlog -work work rtl/aes_core/KeyExpansion.v
vlog -work work rtl/aes_core/SubBytes.v
vlog -work work rtl/aes_core/ShiftRows.v
vlog -work work rtl/aes_core/Mix_Single_Column.v
vlog -work work rtl/aes_core/MixColumns.v
vlog -work work rtl/aes_core/Inv_Sbox_8bits.v
vlog -work work rtl/aes_core/InvKeyExpansion.v
vlog -work work rtl/aes_core/InvSubBytes.v
vlog -work work rtl/aes_core/InvShiftRows.v
vlog -work work rtl/aes_core/Inv_Mix_Single_Column.v
vlog -work work rtl/aes_core/Inv_MixColumns.v
vlog -work work rtl/aes_core/aes_encryption_core.v
vlog -work work rtl/aes_core/aes_decryption_core.v
vlog -work work rtl/aes_core/aes128_core_wrapper.v

# Control/DMA/SRAM
vlog -work work rtl/control/button_edge.v
vlog -work work rtl/control/input_control.v
vlog -work work rtl/dma/image_loader_320x240.v
vlog -work work rtl/dma/aes_sram_dma_320x240.v
vlog -work work rtl/sram/sram_arbiter.v
vlog -work work rtl/sram/sram_arbiter_3m.v
vlog -work work rtl/sram/sram_phy_async16.v
vlog -work work rtl/rom/image_rom_320x240_rgb565.v

# UART image loader
vlog -work work rtl/uart/baud_rate_gen.v
vlog -work work rtl/uart/uart_rx.v
vlog -work work rtl/uart/uart_tx.v
vlog -work work rtl/uart/uart_controller.v
vlog -work work rtl/uart/uart_rx_packet_256.v
vlog -work work rtl/uart/uart_sram_packet_writer_320x240.v
vlog -work work rtl/uart/uart_image_loader_320x240.v

# VGA
vlog -work work rtl/vga/font_rom_8x8.v
vlog -work work rtl/vga/text_dashboard.v
vlog -work work rtl/vga/vga_timing_640x480.v
vlog -work work rtl/vga/vga_sram_reader.v
vlog -work work rtl/vga/vga_quadrant_renderer_320x240.v
vlog -work work rtl/vga/vga_system_640x480.v

# Top/control variants
vlog -work work rtl/control/aes_image_demo_controller.v
vlog -work work rtl/control/aes_image_demo_controller_uart.v
vlog -work work rtl/top.v
vlog -work work rtl/top_de.v

# Simulation models and testbenches
vlog -work work sim/models/aes_mock_core.v
vlog -work work sim/models/sram_model_async16.v
vlog -work work sim/tb/tb_aes128_core_wrapper_selftest.v
vlog -work work sim/tb/tb_sram_arbiter_selftest.v
vlog -work work sim/tb/tb_image_loader_selftest.v
vlog -work work sim/tb/tb_aes_sram_dma_320x240_selftest.v
vlog -work work sim/tb/tb_vga_timing_waveform.v
vlog -work work sim/tb/tb_system_smoke_small.v
vlog -work work sim/tb/tb_uart_rx_packet_256_selftest.v
vlog -work work sim/tb/tb_uart_sram_packet_writer_selftest.v

puts "Compile complete. Use sim/scripts/run_all_selftests.do to run tests."
