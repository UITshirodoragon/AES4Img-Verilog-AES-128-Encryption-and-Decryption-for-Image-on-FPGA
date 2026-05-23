//------------------------------------------------------------------------------
// sram_arbiter.v
// 2-master SRAM arbiter: DMA/AES và VGA.
// Nguyên tắc:
// - Khi DMA request, DMA luôn ưu tiên.
// - VGA chỉ được grant khi DMA không request.
// - Fast mode: top/controller nên giữ VGA request thấp khi DMA busy để không ảnh hưởng throughput.
//------------------------------------------------------------------------------
module sram_arbiter (
    input  wire        clk,
    input  wire        reset_n,

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

    output reg  [1:0]  owner_dbg     // 0 none, 1 DMA, 2 VGA
);

assign dma_grant = dma_req;
assign vga_grant = (!dma_req) && vga_req;
assign dma_rdata = phy_rdata;
assign vga_rdata = phy_rdata;

always @(*) begin
    phy_addr   = 18'd0;
    phy_wdata  = 16'd0;
    phy_we     = 1'b0;
    phy_rd     = 1'b0;
    owner_dbg  = 2'd0;

    if (dma_req) begin
        phy_addr  = dma_addr;
        phy_wdata = dma_wdata;
        phy_we    = dma_we;
        phy_rd    = dma_rd;
        owner_dbg = 2'd1;
    end else if (vga_req) begin
        phy_addr  = vga_addr;
        phy_wdata = 16'd0;
        phy_we    = 1'b0;
        phy_rd    = 1'b1;
        owner_dbg = 2'd2;
    end
end

endmodule
