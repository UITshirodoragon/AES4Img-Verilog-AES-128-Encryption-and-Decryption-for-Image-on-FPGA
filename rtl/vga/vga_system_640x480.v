//------------------------------------------------------------------------------
// vga_system_640x480.v
// VGA timing + SRAM pixel reader + quadrant renderer.
//------------------------------------------------------------------------------
module vga_system_640x480 #(
    parameter ADDR_ORIG = 18'h00000,
    parameter ADDR_ENC  = 18'h14000,
    parameter ADDR_DEC  = 18'h28000
)(
    input  wire        clk_50,
    input  wire        reset_n,
    input  wire        bus_view_enable,

    output reg         clk_25,
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [9:0]  VGA_R,
    output wire [9:0]  VGA_G,
    output wire [9:0]  VGA_B,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,
    output wire        frame_tick_25,

    output wire        vga_req,
    output wire [17:0] vga_addr,
    input  wire        vga_grant,
    input  wire [15:0] vga_rdata,

    input  wire [3:0]  sys_state,
    input  wire [3:0]  dma_state,
    input  wire [3:0]  core_state,
    input  wire [1:0]  bus_owner,
    input  wire        fast_mode,
    input  wire [1:0]  slow_level,
    input  wire        decrypt_mode,
    input  wire        auto_mode,
    input  wire [15:0] block_counter,
    input  wire [8:0]  row_counter,
    input  wire [5:0]  col_block,
    input  wire [31:0] cycle_counter,
    input  wire [31:0] active_cycle_counter,
    input  wire        enc_done,
    input  wire        dec_done,
    input  wire        verify_pass,
    input  wire        verify_fail,
    input  wire        image_loaded,
    input  wire        uart_busy,
    input  wire [9:0]  uart_packet_count,
    input  wire [3:0]  uart_packet_state,
    input  wire [3:0]  uart_writer_state,
    input  wire [7:0]  uart_crc_calc,
    input  wire [7:0]  uart_crc_recv,
    input  wire [7:0]  uart_flags
);

always @(posedge clk_50 or negedge reset_n) begin
    if (!reset_n) clk_25 <= 1'b0;
    else          clk_25 <= ~clk_25;
end

wire [9:0] x;
wire [9:0] y;
wire video_on;

vga_timing_640x480 u_timing(
    .clk_25mhz(clk_25), .reset(!reset_n),
    .hsync(VGA_HS), .vsync(VGA_VS), .x_pos(x), .y_pos(y),
    .video_on(video_on), .frame_tick(frame_tick_25)
);

wire [15:0] pixel_data;
wire pixel_valid;

vga_sram_reader #(.ADDR_ORIG(ADDR_ORIG), .ADDR_ENC(ADDR_ENC), .ADDR_DEC(ADDR_DEC)) u_reader(
    .clk(clk_50), .reset_n(reset_n), .bus_view_enable(bus_view_enable),
    .x(x), .y(y), .video_on(video_on),
    .vga_req(vga_req), .vga_addr(vga_addr), .vga_grant(vga_grant), .vga_rdata(vga_rdata),
    .pixel_data(pixel_data), .pixel_valid(pixel_valid)
);

vga_quadrant_renderer_320x240 u_renderer(
    .clk_25(clk_25), .reset(!reset_n), .x(x), .y(y), .video_on(video_on),
    .bus_view_enable(bus_view_enable), .sram_pixel(pixel_data), .sram_pixel_valid(pixel_valid),
    .sys_state(sys_state), .dma_state(dma_state), .core_state(core_state), .bus_owner(bus_owner),
    .fast_mode(fast_mode), .slow_level(slow_level), .decrypt_mode(decrypt_mode), .auto_mode(auto_mode),
    .block_counter(block_counter), .row_counter(row_counter), .col_block(col_block),
    .cycle_counter(cycle_counter), .active_cycle_counter(active_cycle_counter),
    .enc_done(enc_done), .dec_done(dec_done), .verify_pass(verify_pass), .verify_fail(verify_fail),
    .image_loaded(image_loaded), .uart_busy(uart_busy), .uart_packet_count(uart_packet_count),
    .uart_packet_state(uart_packet_state), .uart_writer_state(uart_writer_state),
    .uart_crc_calc(uart_crc_calc), .uart_crc_recv(uart_crc_recv), .uart_flags(uart_flags),
    .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B)
);

assign VGA_CLK = clk_25;
assign VGA_BLANK_N = video_on;
assign VGA_SYNC_N = 1'b0;

endmodule
