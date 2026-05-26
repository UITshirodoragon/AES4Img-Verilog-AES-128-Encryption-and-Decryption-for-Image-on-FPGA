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

top #(.IMG_W(16), .IMG_H(2), .ADDR_ORIG(18'h000), .ADDR_ENC(18'h100), .ADDR_DEC(18'h200)) dut(
    .CLOCK_50(CLOCK_50), .KEY(KEY), .SW(SW),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_WE_N(SRAM_WE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N),
    .LEDR(LEDR), .LEDG(LEDG)
);

sram_model_async16 #(.DEPTH(4096)) mem(
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
