//------------------------------------------------------------------------------
// vga_timing_640x480.v - VGA 640x480@60Hz timing, pixel clock 25 MHz.
//------------------------------------------------------------------------------
module vga_timing_640x480(
    input  wire       clk_25mhz,
    input  wire       reset,
    output reg        hsync,
    output reg        vsync,
    output reg [9:0]  x_pos,
    output reg [9:0]  y_pos,
    output wire       video_on,
    output wire       frame_tick
);

localparam H_DISPLAY = 10'd640;
localparam H_FRONT   = 10'd16;
localparam H_SYNC    = 10'd96;
localparam H_BACK    = 10'd48;
localparam H_TOTAL   = 10'd800;

localparam V_DISPLAY = 10'd480;
localparam V_FRONT   = 10'd10;
localparam V_SYNC    = 10'd2;
localparam V_BACK    = 10'd33;
localparam V_TOTAL   = 10'd525;

reg [9:0] h_count;
reg [9:0] v_count;

always @(posedge clk_25mhz or posedge reset) begin
    if (reset) begin
        h_count <= 10'd0;
        v_count <= 10'd0;
    end else begin
        if (h_count == H_TOTAL - 1) begin
            h_count <= 10'd0;
            if (v_count == V_TOTAL - 1)
                v_count <= 10'd0;
            else
                v_count <= v_count + 10'd1;
        end else begin
            h_count <= h_count + 10'd1;
        end
    end
end

always @(*) begin
    x_pos = h_count;
    y_pos = v_count;
    hsync = ~((h_count >= (H_DISPLAY + H_FRONT)) && (h_count < (H_DISPLAY + H_FRONT + H_SYNC)));
    vsync = ~((v_count >= (V_DISPLAY + V_FRONT)) && (v_count < (V_DISPLAY + V_FRONT + V_SYNC)));
end

assign video_on = (h_count < H_DISPLAY) && (v_count < V_DISPLAY);
assign frame_tick = (h_count == 10'd0) && (v_count == 10'd0);

endmodule
