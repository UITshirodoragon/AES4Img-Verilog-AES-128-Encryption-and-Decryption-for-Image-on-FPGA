`timescale 1ns/1ps
module tb_sram_arbiter_selftest;
reg clk, reset_n;
reg dma_req, dma_we, dma_rd; reg [17:0] dma_addr; reg [15:0] dma_wdata;
wire dma_grant; wire [15:0] dma_rdata;
reg vga_req; reg [17:0] vga_addr; wire vga_grant; wire [15:0] vga_rdata;
wire [17:0] phy_addr; wire [15:0] phy_wdata; wire phy_we, phy_rd; reg [15:0] phy_rdata;
wire [1:0] owner_dbg;

sram_arbiter dut(
    .clk(clk), .reset_n(reset_n),
    .dma_req(dma_req), .dma_we(dma_we), .dma_rd(dma_rd), .dma_addr(dma_addr), .dma_wdata(dma_wdata), .dma_grant(dma_grant), .dma_rdata(dma_rdata),
    .vga_req(vga_req), .vga_addr(vga_addr), .vga_grant(vga_grant), .vga_rdata(vga_rdata),
    .phy_addr(phy_addr), .phy_wdata(phy_wdata), .phy_we(phy_we), .phy_rd(phy_rd), .phy_rdata(phy_rdata), .owner_dbg(owner_dbg)
);
initial clk=0; always #5 clk=~clk;
initial begin
    $dumpfile("tb_sram_arbiter_selftest.vcd"); $dumpvars(0,tb_sram_arbiter_selftest);
    reset_n=0; dma_req=0; dma_we=0; dma_rd=0; dma_addr=0; dma_wdata=0; vga_req=0; vga_addr=0; phy_rdata=16'hbeef;
    repeat(2) @(posedge clk); reset_n=1;
    // VGA only
    vga_req=1; vga_addr=18'h12345; #1;
    if (!vga_grant || dma_grant || phy_addr!==18'h12345 || !phy_rd || phy_we || owner_dbg!==2'd2) begin $display("FAIL: VGA grant"); $finish; end
    // DMA priority over VGA
    dma_req=1; dma_rd=1; dma_addr=18'h00055; #1;
    if (!dma_grant || vga_grant || phy_addr!==18'h00055 || owner_dbg!==2'd1) begin $display("FAIL: DMA priority"); $finish; end
    // DMA write
    dma_we=1; dma_rd=0; dma_wdata=16'hcafe; #1;
    if (!phy_we || phy_rd || phy_wdata!==16'hcafe) begin $display("FAIL: DMA write signals"); $finish; end
    dma_req=0; vga_req=0; #1;
    if (owner_dbg!==2'd0 || phy_we || phy_rd) begin $display("FAIL: idle"); $finish; end
    $display("PASS: tb_sram_arbiter_selftest"); $finish;
end
endmodule
