`timescale 1ns/1ps
//------------------------------------------------------------------------------
// tb_system_smoke_small.v
// Smoke test hệ thống rút nhỏ 16x2. Dùng SRAM model và AES thật.
// Chỉ kiểm tra load image rồi start encrypt, không render đủ VGA frame.
//------------------------------------------------------------------------------
module tb_system_smoke_small;
reg CLOCK_50;
reg [3:0] KEY;
reg [17:0] SW;
wire [17:0] SRAM_ADDR; wire [15:0] SRAM_DQ;
wire SRAM_WE_N, SRAM_OE_N, SRAM_UB_N, SRAM_LB_N, SRAM_CE_N;
wire VGA_HS,VGA_VS,VGA_CLK,VGA_BLANK_N,VGA_SYNC_N; wire [9:0] VGA_R,VGA_G,VGA_B; wire [17:0] LEDR; wire [8:0] LEDG;

top #(.IMG_W(16), .IMG_H(2), .ADDR_ORIG(18'h000), .ADDR_ENC(18'h100), .ADDR_DEC(18'h200), .ROM_INIT_FROM_FILE(0)) dut(
    .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_WE_N(SRAM_WE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N),
    .LEDR(LEDR), .LEDG(LEDG)
);

tb_sram_model_async16 #(.DEPTH(4096)) mem(
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_WE_N(SRAM_WE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N)
);

initial CLOCK_50=0; always #10 CLOCK_50=~CLOCK_50;
integer timeout;
initial begin
    $dumpfile("tb_system_smoke_small.vcd"); $dumpvars(0,tb_system_smoke_small);
    KEY=4'b1110; SW=18'd0; // reset_n=0
    repeat(5) @(posedge CLOCK_50);
    KEY[0]=1'b1;
    timeout=0;
    while(dut.u_demo.ctrl_state != 4'd1 && timeout < 1000) begin @(posedge CLOCK_50); timeout=timeout+1; end
    if (dut.u_demo.ctrl_state != 4'd1) begin $display("FAIL: did not reach IDLE after image load"); $finish; end
    // Start encrypt in fast mode.
    KEY[1]=1'b0; repeat(4) @(posedge CLOCK_50); KEY[1]=1'b1;
    timeout=0;
    while(!dut.u_demo.enc_done_flag && timeout < 2000) begin @(posedge CLOCK_50); timeout=timeout+1; end
    if (!dut.u_demo.enc_done_flag) begin $display("FAIL: encrypt did not complete"); $finish; end
    $display("PASS: tb_system_smoke_small"); $finish;
end
endmodule

// Local SRAM model keeps this smoke test self-contained when ModelSim compiles
// the testbench directly from a Quartus-generated script.
module tb_sram_model_async16 #(
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
