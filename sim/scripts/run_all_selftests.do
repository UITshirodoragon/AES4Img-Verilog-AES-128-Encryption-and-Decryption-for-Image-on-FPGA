# Run after modelsim_compile_functional.do
set tests {tb_aes128_core_wrapper_selftest tb_sram_arbiter_selftest tb_image_loader_selftest tb_aes_sram_dma_320x240_selftest tb_vga_timing_waveform tb_system_smoke_small tb_uart_rx_packet_256_selftest tb_uart_sram_packet_writer_selftest}
foreach t $tests {
    puts "========== RUN $t =========="
    vsim -quiet work.$t
    run -all
    quit -sim
}
