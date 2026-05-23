//------------------------------------------------------------------------------
// sram_arbiter_3m.v
// Three-master SRAM arbiter for UART image loading, AES DMA, and VGA viewing.
// Priority:
//   1) UART loader while receiving/writing the original image
//   2) AES DMA while encrypting/decrypting
//   3) VGA reader only when system allows viewing
//------------------------------------------------------------------------------
module sram_arbiter_3m(
    input  wire        clk,
    input  wire        reset_n,

    input  wire        uart_req,
    input  wire        uart_we,
    input  wire [17:0] uart_addr,
    input  wire [15:0] uart_wdata,
    output wire        uart_grant,

    input  wire        dma_req,
    input  wire        dma_we,
    input  wire        dma_rd,
    input  wire [17:0] dma_addr,
    input  wire [15:0] dma_wdata,
    output wire        dma_grant,
    output wire [15:0] dma_rdata,

    input  wire        vga_req,
    input  wire [17:0] vga_addr,
    output wire        vga_grant,
    output wire [15:0] vga_rdata,

    output reg  [17:0] phy_addr,
    output reg  [15:0] phy_wdata,
    output reg         phy_we,
    output reg         phy_rd,
    input  wire [15:0] phy_rdata,

    output reg  [1:0]  owner_dbg     // 0 none, 1 UART, 2 AES/DMA, 3 VGA
);

    assign uart_grant = uart_req;
    assign dma_grant  = (!uart_req) && dma_req;
    assign vga_grant  = (!uart_req) && (!dma_req) && vga_req;

    assign dma_rdata = phy_rdata;
    assign vga_rdata = phy_rdata;

    always @(*) begin
        phy_addr  = 18'd0;
        phy_wdata = 16'd0;
        phy_we    = 1'b0;
        phy_rd    = 1'b0;
        owner_dbg = 2'd0;

        if (uart_req) begin
            phy_addr  = uart_addr;
            phy_wdata = uart_wdata;
            phy_we    = uart_we;
            phy_rd    = 1'b0;
            owner_dbg = 2'd1;
        end else if (dma_req) begin
            phy_addr  = dma_addr;
            phy_wdata = dma_wdata;
            phy_we    = dma_we;
            phy_rd    = dma_rd;
            owner_dbg = 2'd2;
        end else if (vga_req) begin
            phy_addr  = vga_addr;
            phy_wdata = 16'd0;
            phy_we    = 1'b0;
            phy_rd    = 1'b1;
            owner_dbg = 2'd3;
        end
    end

endmodule
