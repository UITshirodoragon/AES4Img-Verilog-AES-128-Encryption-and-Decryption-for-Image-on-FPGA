`timescale 1ns/1ps
//------------------------------------------------------------------------------
// tb_aes128_core_wrapper_selftest.v
// Self-check AES wrapper bằng NIST AES-128 known-answer vector.
//------------------------------------------------------------------------------
module tb_aes128_core_wrapper_selftest;
reg clk;
reg reset_n;
reg start;
reg decrypt;
reg [127:0] block_in;
reg [127:0] key;
wire [127:0] block_out;
wire busy;
wire done;
wire [3:0] core_state_dbg;

localparam [127:0] K   = 128'h2b7e151628aed2a6abf7158809cf4f3c;
localparam [127:0] PT  = 128'h3243f6a8885a308d313198a2e0370734;
localparam [127:0] CT  = 128'h3925841d02dc09fbdc118597196a0b32;

aes128_core_wrapper dut(
    .clk(clk), .reset_n(reset_n), .start(start), .decrypt(decrypt),
    .block_in(block_in), .key(key), .block_out(block_out), .busy(busy), .done(done), .core_state_dbg(core_state_dbg)
);

initial clk = 1'b0;
always #10 clk = ~clk;

integer timeout;
initial begin
    $dumpfile("tb_aes128_core_wrapper_selftest.vcd");
    $dumpvars(0, tb_aes128_core_wrapper_selftest);
    reset_n = 1'b0; start = 1'b0; decrypt = 1'b0; block_in = 128'd0; key = K;
    repeat(5) @(posedge clk);
    reset_n = 1'b1;

    @(posedge clk);
    block_in = PT; decrypt = 1'b0; start = 1'b1;
    @(posedge clk); start = 1'b0;
    timeout = 0;
    while(!done && timeout < 200) begin @(posedge clk); timeout = timeout + 1; end
    if (!done) begin $display("FAIL: encrypt timeout"); $finish; end
    if (block_out !== CT) begin $display("FAIL: encrypt got %h expected %h", block_out, CT); $finish; end
    $display("PASS: AES encrypt KAT");

    @(posedge clk);
    block_in = CT; decrypt = 1'b1; start = 1'b1;
    @(posedge clk); start = 1'b0;
    timeout = 0;
    while(!done && timeout < 300) begin @(posedge clk); timeout = timeout + 1; end
    if (!done) begin $display("FAIL: decrypt timeout"); $finish; end
    if (block_out !== PT) begin $display("FAIL: decrypt got %h expected %h", block_out, PT); $finish; end
    $display("PASS: AES decrypt KAT");
    $display("PASS: tb_aes128_core_wrapper_selftest");
    $finish;
end
endmodule
