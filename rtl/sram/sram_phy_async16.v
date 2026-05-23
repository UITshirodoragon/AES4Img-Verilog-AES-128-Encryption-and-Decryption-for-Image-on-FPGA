//------------------------------------------------------------------------------
// sram_phy_async16.v
// SRAM PHY 16-bit, 18-bit address. Giao tiếp mức logic đơn giản:
// - rd/we active-high ở clk 50 MHz.
// - o_rdata được chốt ở cạnh lên khi rd=1 và we=0.
//------------------------------------------------------------------------------
module sram_phy_async16 (
    input  wire        clk,
    input  wire        reset,
    input  wire [17:0] addr,
    input  wire [15:0] wdata,
    input  wire        we,
    input  wire        rd,
    output reg  [15:0] rdata,

    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_CE_N
);

assign SRAM_CE_N = 1'b0;
assign SRAM_UB_N = 1'b0;
assign SRAM_LB_N = 1'b0;
assign SRAM_ADDR = addr;
assign SRAM_WE_N = ~we;
assign SRAM_OE_N = ~(rd && !we);
assign SRAM_DQ   = we ? wdata : 16'hzzzz;

always @(posedge clk or posedge reset) begin
    if (reset)
        rdata <= 16'h0000;
    else if (rd && !we)
        rdata <= SRAM_DQ;
end

endmodule
