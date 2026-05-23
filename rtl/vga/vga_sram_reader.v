//------------------------------------------------------------------------------
// vga_sram_reader.v
// Tạo request đọc SRAM cho pixel vùng ảnh. Top-right dashboard không cần SRAM.
// Địa chỉ mapping: TL ORIG, BL ENC, BR DEC. Mỗi vùng 320x240 1:1.
//------------------------------------------------------------------------------
module vga_sram_reader #(
    parameter ADDR_ORIG = 18'h00000,
    parameter ADDR_ENC  = 18'h14000,
    parameter ADDR_DEC  = 18'h28000
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        bus_view_enable,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        video_on,
    output reg         vga_req,
    output reg  [17:0] vga_addr,
    input  wire        vga_grant,
    input  wire [15:0] vga_rdata,
    output reg  [15:0] pixel_data,
    output reg         pixel_valid
);

wire in_tl = (x < 10'd320) && (y < 10'd240);
wire in_tr = (x >= 10'd320) && (y < 10'd240);
wire in_bl = (x < 10'd320) && (y >= 10'd240);
wire in_br = (x >= 10'd320) && (y >= 10'd240);
wire [9:0] local_x = in_br ? (x - 10'd320) : x;
wire [9:0] local_y = (in_bl || in_br) ? (y - 10'd240) : y;
wire is_image_region = video_on && !in_tr && (in_tl || in_bl || in_br);
wire [17:0] offset = local_y * 320 + local_x;

always @(*) begin
    vga_req = bus_view_enable && is_image_region;
    if (in_tl)
        vga_addr = ADDR_ORIG + offset;
    else if (in_bl)
        vga_addr = ADDR_ENC + offset;
    else if (in_br)
        vga_addr = ADDR_DEC + offset;
    else
        vga_addr = ADDR_ORIG;
end

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        pixel_data <= 16'd0;
        pixel_valid <= 1'b0;
    end else begin
        if (vga_grant) begin
            pixel_data <= vga_rdata;
            pixel_valid <= 1'b1;
        end else begin
            pixel_valid <= 1'b0;
        end
    end
end

endmodule
