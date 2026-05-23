# Interactive waveform for AES DMA unit test
vsim work.tb_aes_sram_dma_320x240_selftest
add wave -divider CLOCK_RESET
add wave sim:/tb_aes_sram_dma_320x240_selftest/clk
add wave sim:/tb_aes_sram_dma_320x240_selftest/reset_n
add wave -divider DMA
add wave sim:/tb_aes_sram_dma_320x240_selftest/dut/state
add wave sim:/tb_aes_sram_dma_320x240_selftest/dut/block_idx
add wave sim:/tb_aes_sram_dma_320x240_selftest/dut/pixel_idx
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_req
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_we
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_rd
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_addr
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_wdata
add wave sim:/tb_aes_sram_dma_320x240_selftest/sram_rdata
add wave -divider AES_MOCK
add wave sim:/tb_aes_sram_dma_320x240_selftest/aes_start
add wave sim:/tb_aes_sram_dma_320x240_selftest/aes_done
add wave sim:/tb_aes_sram_dma_320x240_selftest/aes_block_in
add wave sim:/tb_aes_sram_dma_320x240_selftest/aes_block_out
run -all
