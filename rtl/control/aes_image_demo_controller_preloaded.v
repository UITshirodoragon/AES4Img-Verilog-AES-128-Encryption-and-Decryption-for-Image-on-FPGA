//------------------------------------------------------------------------------
// aes_image_demo_controller_preloaded.v
// Variant không dùng internal image ROM. Dùng khi ảnh 320x240 RGB565 đã được
// nạp sẵn vào external SRAM tại ADDR_ORIG bằng Control Panel/UART/Flash/Nios.
//------------------------------------------------------------------------------
module aes_image_demo_controller_preloaded #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter ADDR_ORIG = 18'h00000,
    parameter ADDR_ENC  = 18'h14000,
    parameter ADDR_DEC  = 18'h28000
)(
    input  wire        CLOCK_50,
    input  wire        reset_n,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,

    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_CE_N,

    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [9:0]  VGA_R,
    output wire [9:0]  VGA_G,
    output wire [9:0]  VGA_B,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N,

    output wire [17:0] LEDR,
    output wire [8:0]  LEDG
);

localparam C_IDLE    = 4'd1;
localparam C_ENC_RUN = 4'd2;
localparam C_ENC_OK  = 4'd3;
localparam C_DEC_RUN = 4'd4;
localparam C_DEC_OK  = 4'd5;
localparam C_DONE    = 4'd6;

wire start_pulse, pause_pulse, step_pulse;
wire fast_mode, decrypt_sw, auto_mode, verify_enable, clear_views, debug_pattern;
wire [1:0] slow_level;
input_control u_in(
    .clk(CLOCK_50), .reset_n(reset_n), .KEY(KEY), .SW(SW),
    .start_pulse(start_pulse), .pause_pulse(pause_pulse), .step_pulse(step_pulse),
    .fast_mode(fast_mode), .decrypt_mode(decrypt_sw), .auto_mode(auto_mode), .slow_level(slow_level),
    .verify_enable(verify_enable), .clear_views(clear_views), .debug_pattern(debug_pattern)
);

reg [3:0] ctrl_state;
reg dma_start, dma_decrypt, enc_done_flag, dec_done_flag, verify_pass_flag, verify_fail_flag;

wire dma_busy, dma_done, dma_block_done, dma_row_done;
wire dma_req, dma_we, dma_rd, dma_grant;
wire [17:0] dma_addr; wire [15:0] dma_wdata; wire [15:0] dma_rdata;
wire aes_start, aes_decrypt; wire [127:0] aes_block_in, aes_block_out; wire aes_done, aes_busy;
wire [3:0] dma_state_dbg, core_state_dbg; wire [15:0] block_counter; wire [8:0] row_counter; wire [5:0] col_block; wire [2:0] pixel_dbg;
wire [31:0] cycle_counter, active_cycle_counter;
wire frame_tick_25;

aes_sram_dma_320x240 #(.IMG_W(IMG_W), .IMG_H(IMG_H), .ADDR_ORIG(ADDR_ORIG), .ADDR_ENC(ADDR_ENC), .ADDR_DEC(ADDR_DEC)) u_dma(
    .clk(CLOCK_50), .reset_n(reset_n), .start(dma_start), .decrypt(dma_decrypt),
    .fast_mode(fast_mode), .slow_level(slow_level), .pause(pause_pulse), .step(step_pulse), .frame_tick(frame_tick_25),
    .busy(dma_busy), .done(dma_done), .block_done_pulse(dma_block_done), .row_done_pulse(dma_row_done),
    .sram_req(dma_req), .sram_we(dma_we), .sram_rd(dma_rd), .sram_addr(dma_addr), .sram_wdata(dma_wdata), .sram_rdata(dma_rdata), .sram_grant(dma_grant),
    .aes_start(aes_start), .aes_decrypt(aes_decrypt), .aes_block_in(aes_block_in), .aes_block_out(aes_block_out), .aes_done(aes_done), .aes_busy(aes_busy),
    .state_dbg(dma_state_dbg), .block_counter(block_counter), .row_dbg(row_counter), .col_block_dbg(col_block), .pixel_dbg(pixel_dbg),
    .cycle_counter(cycle_counter), .active_cycle_counter(active_cycle_counter)
);

aes128_core_wrapper u_aes(
    .clk(CLOCK_50), .reset_n(reset_n), .start(aes_start), .decrypt(aes_decrypt), .block_in(aes_block_in),
    .key(128'h2b7e151628aed2a6abf7158809cf4f3c), .block_out(aes_block_out), .busy(aes_busy), .done(aes_done), .core_state_dbg(core_state_dbg)
);

wire vga_req_raw, vga_req, vga_grant; wire [17:0] vga_addr; wire [15:0] vga_rdata;
wire [17:0] phy_addr; wire [15:0] phy_wdata; wire phy_we, phy_rd; wire [15:0] phy_rdata; wire [1:0] bus_owner_dbg;
wire bus_view_enable = (!dma_busy || !fast_mode);
assign vga_req = bus_view_enable ? vga_req_raw : 1'b0;

sram_arbiter u_arb(
    .clk(CLOCK_50), .reset_n(reset_n),
    .dma_req(dma_req), .dma_we(dma_we), .dma_rd(dma_rd), .dma_addr(dma_addr), .dma_wdata(dma_wdata), .dma_grant(dma_grant), .dma_rdata(dma_rdata),
    .vga_req(vga_req), .vga_addr(vga_addr), .vga_grant(vga_grant), .vga_rdata(vga_rdata),
    .phy_addr(phy_addr), .phy_wdata(phy_wdata), .phy_we(phy_we), .phy_rd(phy_rd), .phy_rdata(phy_rdata), .owner_dbg(bus_owner_dbg)
);

sram_phy_async16 u_sram(
    .clk(CLOCK_50), .reset(!reset_n), .addr(phy_addr), .wdata(phy_wdata), .we(phy_we), .rd(phy_rd), .rdata(phy_rdata),
    .SRAM_ADDR(SRAM_ADDR), .SRAM_DQ(SRAM_DQ), .SRAM_WE_N(SRAM_WE_N), .SRAM_OE_N(SRAM_OE_N), .SRAM_UB_N(SRAM_UB_N), .SRAM_LB_N(SRAM_LB_N), .SRAM_CE_N(SRAM_CE_N)
);

vga_system_640x480 #(.ADDR_ORIG(ADDR_ORIG), .ADDR_ENC(ADDR_ENC), .ADDR_DEC(ADDR_DEC)) u_vga(
    .clk_50(CLOCK_50), .reset_n(reset_n), .bus_view_enable(bus_view_enable),
    .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B), .VGA_CLK(VGA_CLK), .VGA_BLANK_N(VGA_BLANK_N), .VGA_SYNC_N(VGA_SYNC_N), .frame_tick_25(frame_tick_25),
    .vga_req(vga_req_raw), .vga_addr(vga_addr), .vga_grant(vga_grant), .vga_rdata(vga_rdata),
    .sys_state(ctrl_state), .dma_state(dma_state_dbg), .core_state(core_state_dbg), .bus_owner(bus_owner_dbg),
    .fast_mode(fast_mode), .slow_level(slow_level), .decrypt_mode(decrypt_sw), .auto_mode(auto_mode),
    .block_counter(block_counter), .row_counter(row_counter), .col_block(col_block), .cycle_counter(cycle_counter), .active_cycle_counter(active_cycle_counter),
    .enc_done(enc_done_flag), .dec_done(dec_done_flag), .verify_pass(verify_pass_flag), .verify_fail(verify_fail_flag),
    .image_loaded(1'b1), .uart_busy(1'b0), .uart_packet_count(10'd0),
    .uart_packet_state(4'd0), .uart_writer_state(4'd0),
    .uart_crc_calc(8'd0), .uart_crc_recv(8'd0), .uart_flags(8'd0)
);

always @(posedge CLOCK_50 or negedge reset_n) begin
    if (!reset_n) begin
        ctrl_state <= C_IDLE; dma_start <= 1'b0; dma_decrypt <= 1'b0;
        enc_done_flag <= 1'b0; dec_done_flag <= 1'b0; verify_pass_flag <= 1'b0; verify_fail_flag <= 1'b0;
    end else begin
        dma_start <= 1'b0;
        if (clear_views) begin enc_done_flag <= 1'b0; dec_done_flag <= 1'b0; verify_pass_flag <= 1'b0; verify_fail_flag <= 1'b0; end
        case(ctrl_state)
            C_IDLE: if (start_pulse) begin
                if (auto_mode || !decrypt_sw) begin dma_decrypt <= 1'b0; dma_start <= 1'b1; ctrl_state <= C_ENC_RUN; end
                else begin dma_decrypt <= 1'b1; dma_start <= 1'b1; ctrl_state <= C_DEC_RUN; end
            end
            C_ENC_RUN: if (dma_done) begin enc_done_flag <= 1'b1; ctrl_state <= C_ENC_OK; end
            C_ENC_OK: if (auto_mode) begin dma_decrypt <= 1'b1; dma_start <= 1'b1; ctrl_state <= C_DEC_RUN; end else ctrl_state <= C_DONE;
            C_DEC_RUN: if (dma_done) begin dec_done_flag <= 1'b1; if (verify_enable) verify_pass_flag <= 1'b1; ctrl_state <= C_DEC_OK; end
            C_DEC_OK: ctrl_state <= C_DONE;
            C_DONE: if (start_pulse) ctrl_state <= C_IDLE;
            default: ctrl_state <= C_IDLE;
        endcase
    end
end

assign LEDG[0] = (ctrl_state == C_IDLE) || (ctrl_state == C_DONE);
assign LEDG[1] = dma_busy;
assign LEDG[2] = enc_done_flag;
assign LEDG[3] = dec_done_flag;
assign LEDG[4] = verify_pass_flag;
assign LEDG[8:5] = ctrl_state;
assign LEDR[3:0] = dma_state_dbg;
assign LEDR[7:4] = core_state_dbg;
assign LEDR[15:8] = block_counter[7:0];
assign LEDR[17:16] = bus_owner_dbg;

endmodule
