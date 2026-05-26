//------------------------------------------------------------------------------
// top.v - simulation/smoke-test top-level for AES4Img.
//
// This top uses the ROM image loader profile so testbenches can run without
// driving UART packets. Keep the board-facing DE2 top in top_de.v.
//------------------------------------------------------------------------------
module top #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter ADDR_ORIG = 18'h00000,
    parameter ADDR_ENC  = 18'h14000,
    parameter ADDR_DEC  = 18'h28000,
    parameter HEX_FILE  = "image_320x240_rgb565.hex"
)(
    input  wire        CLOCK_50,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,

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

aes_image_demo_controller #(
    .IMG_W(IMG_W),
    .IMG_H(IMG_H),
    .ADDR_ORIG(ADDR_ORIG),
    .ADDR_ENC(ADDR_ENC),
    .ADDR_DEC(ADDR_DEC),
    .HEX_FILE(HEX_FILE)
) u_demo(
    .CLOCK_50(CLOCK_50), .reset_n(KEY[0]), .KEY(KEY), .SW(SW),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_WE_N(SRAM_WE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N),
    .LEDR(LEDR), .LEDG(LEDG)
);

endmodule
