`timescale 1ns/1ps
module tb_vga_timing_waveform;
reg clk, reset;
wire hsync, vsync, video_on, frame_tick; wire [9:0] x,y;
vga_timing_640x480 dut(.clk_25mhz(clk), .reset(reset), .hsync(hsync), .vsync(vsync), .x_pos(x), .y_pos(y), .video_on(video_on), .frame_tick(frame_tick));
initial clk=0; always #20 clk=~clk; // 25MHz
integer frames;
initial begin
    $dumpfile("tb_vga_timing_waveform.vcd"); $dumpvars(0,tb_vga_timing_waveform);
    reset=1; frames=0; repeat(4) @(posedge clk); reset=0;
    while(frames < 2) begin
        @(posedge clk);
        if (frame_tick) frames = frames + 1;
    end
    if (x !== 10'd0 || y !== 10'd0) begin $display("FAIL: frame tick not at origin"); $finish; end
    $display("PASS: tb_vga_timing_waveform"); $finish;
end
endmodule
