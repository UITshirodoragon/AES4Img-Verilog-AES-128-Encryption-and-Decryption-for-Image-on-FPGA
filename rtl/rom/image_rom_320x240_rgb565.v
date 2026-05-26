//------------------------------------------------------------------------------
// image_rom_320x240_rgb565.v
// ROM anh RGB565. Quartus chay tu thu muc quartus/, nen default path tro
// nguoc ve project root noi dat image_320x240_rgb565.hex.
//------------------------------------------------------------------------------
module image_rom_320x240_rgb565 #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter INIT_FROM_FILE = 1,
    parameter HEX_FILE = "../image_320x240_rgb565.hex"
)(
    input  wire        clk,
    input  wire [16:0] addr,
    output reg  [15:0] q
);
localparam TOTAL_PIXELS = IMG_W * IMG_H;
reg [15:0] mem [0:TOTAL_PIXELS-1];
integer init_i;

initial begin
    for (init_i = 0; init_i < TOTAL_PIXELS; init_i = init_i + 1)
        mem[init_i] = 16'h2000 + init_i;

    if (INIT_FROM_FILE)
        $readmemh(HEX_FILE, mem);
end

always @(posedge clk) begin
    q <= mem[addr];
end
endmodule
