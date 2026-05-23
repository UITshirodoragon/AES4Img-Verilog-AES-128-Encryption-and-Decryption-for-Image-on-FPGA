//------------------------------------------------------------------------------
// sram_model_async16.v - simple async SRAM model for testbench.
//------------------------------------------------------------------------------
module sram_model_async16 #(
    parameter ADDR_WIDTH = 18,
    parameter DEPTH = 262144
)(
    input  wire [ADDR_WIDTH-1:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    input  wire SRAM_WE_N,
    input  wire SRAM_OE_N,
    input  wire SRAM_UB_N,
    input  wire SRAM_LB_N,
    input  wire SRAM_CE_N
);
reg [15:0] mem [0:DEPTH-1];
wire selected = !SRAM_CE_N;
wire write_en = selected && !SRAM_WE_N;
wire read_en  = selected && SRAM_WE_N && !SRAM_OE_N;
assign SRAM_DQ = read_en ? mem[SRAM_ADDR] : 16'hzzzz;

always @(*) begin
    if (write_en) begin
        if (!SRAM_UB_N) mem[SRAM_ADDR][15:8] = SRAM_DQ[15:8];
        if (!SRAM_LB_N) mem[SRAM_ADDR][7:0]  = SRAM_DQ[7:0];
    end
end
endmodule
