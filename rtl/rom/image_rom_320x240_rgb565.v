//------------------------------------------------------------------------------
// image_rom_320x240_rgb565.v
// ROM ảnh RGB565. Dùng image_320x240_rgb565.hex theo $readmemh.
// Với Quartus, đặt file HEX trong thư mục project hoặc cập nhật path.
//------------------------------------------------------------------------------
module image_rom_320x240_rgb565 #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter HEX_FILE = "image_320x240_rgb565.hex"
)(
    input  wire        clk,
    input  wire [16:0] addr,
    output reg  [15:0] q
);
localparam TOTAL_PIXELS = IMG_W * IMG_H;
reg [15:0] mem [0:TOTAL_PIXELS-1];

initial begin
    $readmemh(HEX_FILE, mem);
end

always @(posedge clk) begin
    q <= mem[addr];
end
endmodule
