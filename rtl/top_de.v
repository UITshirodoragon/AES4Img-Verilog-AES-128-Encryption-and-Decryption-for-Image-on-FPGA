//------------------------------------------------------------------------------
// top_de.v - DE2 hardware top-level for AES4Img.
//
// This is the board-facing top used by Quartus. It loads a 320x240 RGB565 image
// from PC over UART/RS232, stores it in external SRAM, runs AES-128 through DMA,
// and renders ORIG/ENC/DEC plus debug dashboard over VGA.
//------------------------------------------------------------------------------
module top_de(
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,

    input  wire        UART_RXD,
    output wire        UART_TXD,

    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_CE_N,

    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [9:0]  VGA_R,
    output wire [9:0]  VGA_G,
    output wire [9:0]  VGA_B,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,

    output wire [17:0] LEDR,
    output wire [8:0]  LEDG
);

    aes_image_demo_controller_uart u_demo(
        .CLOCK_50(CLOCK_50),
        .reset_n(KEY[0]),
        .KEY(KEY),
        .SW(SW),
        .UART_RXD(UART_RXD),
        .UART_TXD(UART_TXD),
        .SRAM_ADDR(SRAM_ADDR),
        .SRAM_DQ(SRAM_DQ),
        .SRAM_WE_N(SRAM_WE_N),
        .SRAM_OE_N(SRAM_OE_N),
        .SRAM_UB_N(SRAM_UB_N),
        .SRAM_LB_N(SRAM_LB_N),
        .SRAM_CE_N(SRAM_CE_N),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_CLK(VGA_CLK),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .LEDR(LEDR),
        .LEDG(LEDG)
    );

endmodule
