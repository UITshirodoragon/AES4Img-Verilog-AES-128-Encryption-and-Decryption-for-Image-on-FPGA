//------------------------------------------------------------------------------
// uart_image_loader_320x240.v
// UART-RS232 image loader for 320x240 RGB565 images.
// PC sends 600 packets. Each packet: 0xAA + 256 payload bytes + CRC8.
// This module receives, ACK/NACKs, and writes payload to SRAM_ORIG.
//------------------------------------------------------------------------------
module uart_image_loader_320x240 #(
    parameter ADDR_BASE     = 18'h00000,
    parameter TOTAL_PACKETS = 600
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        clear,
    input  wire        uart_rx,
    output wire        uart_tx,

    output wire        sram_req,
    output wire        sram_we,
    output wire [17:0] sram_addr,
    output wire [15:0] sram_wdata,
    input  wire        sram_grant,

    output wire        image_loaded,
    output wire        loader_busy,
    output wire [9:0]  packet_count,
    output wire [3:0]  packet_state_dbg,
    output wire [3:0]  writer_state_dbg,
    output wire [7:0]  packet_byte_count_dbg,
    output wire [7:0]  crc_calc_dbg,
    output wire [7:0]  crc_recv_dbg,
    output wire [7:0]  uart_flags_dbg,
    output wire [1:0]  uart_rx_state_dbg,
    output wire        uart_tx_busy_dbg,
    output wire        packet_valid_dbg
);

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       rx_clear;
    wire [7:0] tx_data;
    wire       tx_start;
    wire       tx_busy;
    wire [1:0] rx_state;

    wire       packet_valid;
    wire [7:0] packet_pd_address;
    wire [7:0] packet_pd_data;
    wire       writer_busy;
    wire [7:0] writer_word_index_dbg;

    uart_controller u_uart_controller(
        .clk_50m(clk),
        .rst_n(rst_n),
        .rx_clear(rx_clear),
        .rx(uart_rx),
        .tx(uart_tx),
        .tx_data_in(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .rx_data_out(rx_data),
        .rx_valid(rx_valid),
        .rx_state(rx_state)
    );

    uart_rx_packet_256 u_packet(
        .clk(clk),
        .rst_n(rst_n),
        .rx_valid(rx_valid),
        .rx_data(rx_data),
        .tx_busy(tx_busy),
        .packet_valid(packet_valid),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .rx_clear(rx_clear),
        .packet_pd_address(packet_pd_address),
        .packet_pd_data(packet_pd_data),
        .state_dbg(packet_state_dbg),
        .byte_count_dbg(packet_byte_count_dbg),
        .crc_calc_dbg(crc_calc_dbg),
        .crc_recv_dbg(crc_recv_dbg),
        .debug_flags(uart_flags_dbg)
    );

    uart_sram_packet_writer_320x240 #(
        .ADDR_BASE(ADDR_BASE),
        .TOTAL_PACKETS(TOTAL_PACKETS)
    ) u_writer(
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .clear(clear),
        .packet_valid(packet_valid),
        .packet_pd_data(packet_pd_data),
        .packet_pd_address(packet_pd_address),
        .sram_req(sram_req),
        .sram_we(sram_we),
        .sram_addr(sram_addr),
        .sram_wdata(sram_wdata),
        .sram_grant(sram_grant),
        .busy(writer_busy),
        .image_loaded(image_loaded),
        .packet_count(packet_count),
        .word_index_dbg(writer_word_index_dbg),
        .state_dbg(writer_state_dbg)
    );

    assign loader_busy = enable && !image_loaded;
    assign uart_rx_state_dbg = rx_state;
    assign uart_tx_busy_dbg = tx_busy;
    assign packet_valid_dbg = packet_valid;

endmodule
