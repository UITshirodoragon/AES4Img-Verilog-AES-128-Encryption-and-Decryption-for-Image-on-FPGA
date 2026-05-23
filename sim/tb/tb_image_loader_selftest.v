`timescale 1ns/1ps
module tb_image_loader_selftest;
reg clk, reset_n, start;
wire busy, done;
wire [16:0] rom_addr; reg [15:0] rom_q;
wire sram_req, sram_we, sram_rd; wire [17:0] sram_addr; wire [15:0] sram_wdata; wire sram_grant;
wire [16:0] pixel_counter; wire [2:0] state_dbg;
reg [15:0] mem [0:31];
assign sram_grant = sram_req;

image_loader_320x240 #(.IMG_W(16), .IMG_H(2), .ADDR_ORIG(18'h00000)) dut(
    .clk(clk), .reset_n(reset_n), .start(start), .busy(busy), .done(done),
    .rom_addr(rom_addr), .rom_q(rom_q),
    .sram_req(sram_req), .sram_we(sram_we), .sram_rd(sram_rd), .sram_addr(sram_addr), .sram_wdata(sram_wdata), .sram_grant(sram_grant),
    .pixel_counter(pixel_counter), .state_dbg(state_dbg)
);
initial clk=0; always #5 clk=~clk;
integer i;
initial begin
    $dumpfile("tb_image_loader_selftest.vcd"); $dumpvars(0,tb_image_loader_selftest);
    for(i=0;i<32;i=i+1) mem[i]=16'h1000+i;
    reset_n=0; start=0; rom_q=0;
    repeat(3) @(posedge clk); reset_n=1;
    @(posedge clk); start=1; @(posedge clk); start=0;
    while(!done) begin
        rom_q = mem[rom_addr];
        @(posedge clk);
        if (sram_req && sram_we) begin
            if (sram_wdata !== mem[sram_addr]) begin
                $display("FAIL: write data addr=%0d got=%h exp=%h", sram_addr, sram_wdata, mem[sram_addr]); $finish;
            end
        end
    end
    if (pixel_counter !== 17'd32) begin $display("FAIL: pixel_counter %0d", pixel_counter); $finish; end
    $display("PASS: tb_image_loader_selftest"); $finish;
end
endmodule
