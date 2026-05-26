`timescale 1ns/1ps
module tb_aes_sram_dma_320x240_selftest;
reg clk, reset_n, start, decrypt, fast_mode, pause, step, frame_tick;
reg [1:0] slow_level;
wire busy, done, block_done_pulse, row_done_pulse;
wire sram_req, sram_we, sram_rd; wire [17:0] sram_addr; wire [15:0] sram_wdata; reg [15:0] sram_rdata; wire sram_grant;
wire aes_start, aes_decrypt; wire [127:0] aes_block_in; wire [127:0] aes_block_out; wire aes_done, aes_busy;
wire [3:0] state_dbg; wire [15:0] block_counter; wire [8:0] row_dbg; wire [5:0] col_block_dbg; wire [2:0] pixel_dbg; wire [31:0] cycle_counter, active_cycle_counter;
reg [15:0] mem [0:1023];
assign sram_grant = sram_req;

aes_sram_dma_320x240 #(.IMG_W(16), .IMG_H(2), .ADDR_ORIG(18'h000), .ADDR_ENC(18'h100), .ADDR_DEC(18'h200)) dut(
    .clk(clk), .reset_n(reset_n), .start(start), .decrypt(decrypt), .fast_mode(fast_mode), .slow_level(slow_level), .pause(pause), .step(step), .frame_tick(frame_tick),
    .busy(busy), .done(done), .block_done_pulse(block_done_pulse), .row_done_pulse(row_done_pulse),
    .sram_req(sram_req), .sram_we(sram_we), .sram_rd(sram_rd), .sram_addr(sram_addr), .sram_wdata(sram_wdata), .sram_rdata(sram_rdata), .sram_grant(sram_grant),
    .aes_start(aes_start), .aes_decrypt(aes_decrypt), .aes_block_in(aes_block_in), .aes_block_out(aes_block_out), .aes_done(aes_done), .aes_busy(aes_busy),
    .state_dbg(state_dbg), .block_counter(block_counter), .row_dbg(row_dbg), .col_block_dbg(col_block_dbg), .pixel_dbg(pixel_dbg),
    .cycle_counter(cycle_counter), .active_cycle_counter(active_cycle_counter)
);

tb_aes_mock_core u_mock(.clk(clk), .reset_n(reset_n), .start(aes_start), .decrypt(aes_decrypt), .block_in(aes_block_in), .block_out(aes_block_out), .busy(aes_busy), .done(aes_done));

initial clk=0; always #5 clk=~clk;
integer i;
reg [127:0] blk;
initial begin
    $dumpfile("tb_aes_sram_dma_320x240_selftest.vcd"); $dumpvars(0,tb_aes_sram_dma_320x240_selftest);
    for(i=0;i<1024;i=i+1) mem[i]=16'h0000;
    for(i=0;i<32;i=i+1) mem[i]=16'h2000+i;
    reset_n=0; start=0; decrypt=0; fast_mode=1; slow_level=0; pause=0; step=0; frame_tick=0; sram_rdata=0;
    repeat(3) @(posedge clk); reset_n=1;
    @(posedge clk); start=1; @(posedge clk); start=0;
    while(!done) begin
        if (sram_req && sram_rd) sram_rdata = mem[sram_addr];
        @(posedge clk);
        if (sram_req && sram_we) mem[sram_addr] = sram_wdata;
    end
    // 16x2 image = 32 pixels = 4 AES blocks
    if (block_counter !== 16'd4) begin $display("FAIL: block_counter=%0d", block_counter); $finish; end
    // Check first encrypted block equals original packed XOR mock key.
    blk = {mem[18'h100],mem[18'h101],mem[18'h102],mem[18'h103],mem[18'h104],mem[18'h105],mem[18'h106],mem[18'h107]};
    if (blk !== ({16'h2000,16'h2001,16'h2002,16'h2003,16'h2004,16'h2005,16'h2006,16'h2007} ^ 128'h00112233445566778899aabbccddeeff)) begin
        $display("FAIL: encrypted block mismatch got=%h", blk); $finish;
    end
    $display("PASS: tb_aes_sram_dma_320x240_selftest"); $finish;
end
endmodule

// Local mock keeps this unit test self-contained when ModelSim compiles the
// testbench directly from a Quartus-generated script.
module tb_aes_mock_core(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    input  wire        decrypt,
    input  wire [127:0] block_in,
    output reg  [127:0] block_out,
    output reg         busy,
    output reg         done
);
reg [1:0] cnt;
reg [127:0] block_latched;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        cnt <= 2'd0;
        busy <= 1'b0;
        done <= 1'b0;
        block_out <= 128'd0;
        block_latched <= 128'd0;
    end else begin
        done <= 1'b0;
        if (start && !busy) begin
            busy <= 1'b1;
            cnt <= 2'd3;
            block_latched <= block_in;
        end else if (busy) begin
            if (cnt == 2'd0) begin
                busy <= 1'b0;
                done <= 1'b1;
                block_out <= block_latched ^ 128'h00112233445566778899aabbccddeeff;
            end else begin
                cnt <= cnt - 2'd1;
            end
        end
    end
end

endmodule
