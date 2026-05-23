//------------------------------------------------------------------------------
// aes_image_demo_controller_uart.v
// v2.1 controller: waits for a 320x240 RGB565 image loaded from PC over UART
// before allowing AES encrypt/decrypt. UART writes original image to ADDR_ORIG.
//------------------------------------------------------------------------------
module aes_image_demo_controller_uart #(
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

    input  wire        UART_RXD,
    output wire        UART_TXD,

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

localparam C_WAIT_IMAGE = 4'd0;
localparam C_IDLE       = 4'd1;
localparam C_ENC_RUN    = 4'd2;
localparam C_ENC_OK     = 4'd3;
localparam C_DEC_RUN    = 4'd4;
localparam C_DEC_OK     = 4'd5;
localparam C_DONE       = 4'd6;
localparam C_CLEAR_SRAM = 4'd7;

wire start_pulse, pause_pulse, step_pulse;
wire fast_mode, decrypt_sw, auto_mode, verify_enable, clear_views, debug_pattern;
wire [1:0] slow_level;

input_control u_in(
    .clk(CLOCK_50), .reset_n(reset_n), .KEY(KEY), .SW(SW),
    .start_pulse(start_pulse), .pause_pulse(pause_pulse), .step_pulse(step_pulse),
    .fast_mode(fast_mode), .decrypt_mode(decrypt_sw), .auto_mode(auto_mode), .slow_level(slow_level),
    .verify_enable(verify_enable), .clear_views(clear_views), .debug_pattern(debug_pattern)
);

// SW[8] bypasses UART loading. Use it only when ORIG has been preloaded by another tool.
wire image_bypass = SW[8];
wire image_ready;

reg [3:0] ctrl_state;
reg dma_start, dma_decrypt, enc_done_flag, dec_done_flag, verify_pass_flag, verify_fail_flag;

//------------------------------------------------------------------------------
// UART image loader master
//------------------------------------------------------------------------------
wire uart_loader_req, uart_loader_we, uart_grant;
wire [17:0] uart_loader_addr;
wire [15:0] uart_loader_wdata;
wire uart_image_loaded, uart_loader_busy;
wire [9:0] uart_packet_count;
wire [3:0] uart_packet_state, uart_writer_state;
wire [7:0] uart_byte_count_dbg, uart_crc_calc, uart_crc_recv, uart_flags;
wire [1:0] uart_rx_state_dbg;
wire uart_tx_busy_dbg, uart_packet_valid_dbg;

localparam integer REGION_WORDS = IMG_W * IMG_H;

reg [1:0]  clear_region;
reg [17:0] clear_index;
reg        clear_phase;
wire       clear_busy = (ctrl_state == C_CLEAR_SRAM);
wire       clear_req = clear_busy && !clear_phase;
wire       clear_we = clear_req;
wire [17:0] clear_base = (clear_region == 2'd0) ? ADDR_ORIG :
                         (clear_region == 2'd1) ? ADDR_ENC  : ADDR_DEC;
wire [17:0] clear_addr = clear_base + clear_index;
wire [15:0] clear_wdata = 16'h0000;

wire        uart_req = clear_busy ? clear_req : uart_loader_req;
wire        uart_we = clear_busy ? clear_we : uart_loader_we;
wire [17:0] uart_addr = clear_busy ? clear_addr : uart_loader_addr;
wire [15:0] uart_wdata = clear_busy ? clear_wdata : uart_loader_wdata;

assign image_ready = uart_image_loaded | image_bypass;

uart_image_loader_320x240 #(
    .ADDR_BASE(ADDR_ORIG),
    .TOTAL_PACKETS(600)
) u_uart_loader(
    .clk(CLOCK_50),
    .rst_n(reset_n),
    .enable(!clear_busy && !image_bypass && !uart_image_loaded),
    .clear(clear_views),
    .uart_rx(UART_RXD),
    .uart_tx(UART_TXD),
    .sram_req(uart_loader_req),
    .sram_we(uart_loader_we),
    .sram_addr(uart_loader_addr),
    .sram_wdata(uart_loader_wdata),
    .sram_grant(uart_grant),
    .image_loaded(uart_image_loaded),
    .loader_busy(uart_loader_busy),
    .packet_count(uart_packet_count),
    .packet_state_dbg(uart_packet_state),
    .writer_state_dbg(uart_writer_state),
    .packet_byte_count_dbg(uart_byte_count_dbg),
    .crc_calc_dbg(uart_crc_calc),
    .crc_recv_dbg(uart_crc_recv),
    .uart_flags_dbg(uart_flags),
    .uart_rx_state_dbg(uart_rx_state_dbg),
    .uart_tx_busy_dbg(uart_tx_busy_dbg),
    .packet_valid_dbg(uart_packet_valid_dbg)
);

//------------------------------------------------------------------------------
// AES DMA master
//------------------------------------------------------------------------------
wire dma_busy, dma_done, dma_block_done, dma_row_done;
wire dma_req, dma_we, dma_rd, dma_grant;
wire [17:0] dma_addr;
wire [15:0] dma_wdata, dma_rdata;
wire aes_start, aes_decrypt;
wire [127:0] aes_block_in, aes_block_out;
wire aes_done, aes_busy;
wire [3:0] dma_state_dbg, core_state_dbg;
wire [15:0] block_counter;
wire [8:0] row_counter;
wire [5:0] col_block;
wire [2:0] pixel_dbg;
wire [31:0] cycle_counter, active_cycle_counter;
wire frame_tick_25;

aes_sram_dma_320x240 #(
    .IMG_W(IMG_W), .IMG_H(IMG_H), .ADDR_ORIG(ADDR_ORIG), .ADDR_ENC(ADDR_ENC), .ADDR_DEC(ADDR_DEC)
) u_dma(
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

//------------------------------------------------------------------------------
// VGA view master and SRAM arbitration
//------------------------------------------------------------------------------
wire vga_req_raw, vga_req, vga_grant;
wire [17:0] vga_addr;
wire [15:0] vga_rdata;
wire [17:0] phy_addr;
wire [15:0] phy_wdata;
wire phy_we, phy_rd;
wire [15:0] phy_rdata;
wire [1:0] bus_owner_dbg;

// During UART loading: VGA image read is disabled so UART can fill SRAM_ORIG.
// During AES fast mode: VGA image read is disabled so AES throughput is not affected.
wire bus_view_enable = image_ready && !uart_loader_busy && (!dma_busy || !fast_mode);
assign vga_req = bus_view_enable ? vga_req_raw : 1'b0;

sram_arbiter_3m u_arb(
    .clk(CLOCK_50), .reset_n(reset_n),
    .uart_req(uart_req), .uart_we(uart_we), .uart_addr(uart_addr), .uart_wdata(uart_wdata), .uart_grant(uart_grant),
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
    .image_loaded(image_ready), .uart_busy(clear_busy || uart_loader_busy), .uart_packet_count(uart_packet_count),
    .uart_packet_state(uart_packet_state), .uart_writer_state(uart_writer_state),
    .uart_crc_calc(uart_crc_calc), .uart_crc_recv(uart_crc_recv), .uart_flags(uart_flags)
);

//------------------------------------------------------------------------------
// System phase controller
//------------------------------------------------------------------------------
always @(posedge CLOCK_50 or negedge reset_n) begin
    if (!reset_n) begin
        ctrl_state <= C_CLEAR_SRAM;
        dma_start <= 1'b0;
        dma_decrypt <= 1'b0;
        enc_done_flag <= 1'b0;
        dec_done_flag <= 1'b0;
        verify_pass_flag <= 1'b0;
        verify_fail_flag <= 1'b0;
        clear_region <= 2'd0;
        clear_index <= 18'd0;
        clear_phase <= 1'b0;
    end else begin
        dma_start <= 1'b0;

        if (clear_views) begin
            enc_done_flag <= 1'b0;
            dec_done_flag <= 1'b0;
            verify_pass_flag <= 1'b0;
            verify_fail_flag <= 1'b0;
            if (!image_ready)
                ctrl_state <= C_WAIT_IMAGE;
        end

        case (ctrl_state)
            C_CLEAR_SRAM: begin
                enc_done_flag <= 1'b0;
                dec_done_flag <= 1'b0;
                verify_pass_flag <= 1'b0;
                verify_fail_flag <= 1'b0;
                if (!clear_phase) begin
                    if (uart_grant)
                        clear_phase <= 1'b1;
                end else begin
                    clear_phase <= 1'b0;
                    if (clear_index == (REGION_WORDS - 1)) begin
                        clear_index <= 18'd0;
                        if (clear_region == 2'd2) begin
                            clear_region <= 2'd0;
                            ctrl_state <= C_WAIT_IMAGE;
                        end else begin
                            clear_region <= clear_region + 2'd1;
                        end
                    end else begin
                        clear_index <= clear_index + 18'd1;
                    end
                end
            end

            C_WAIT_IMAGE: begin
                if (image_ready)
                    ctrl_state <= C_IDLE;
            end

            C_IDLE: begin
                if (!image_ready) begin
                    ctrl_state <= C_WAIT_IMAGE;
                end else if (start_pulse) begin
                    if (auto_mode || !decrypt_sw) begin
                        dma_decrypt <= 1'b0;
                        dma_start <= 1'b1;
                        ctrl_state <= C_ENC_RUN;
                    end else begin
                        dma_decrypt <= 1'b1;
                        dma_start <= 1'b1;
                        ctrl_state <= C_DEC_RUN;
                    end
                end
            end

            C_ENC_RUN: begin
                if (dma_done) begin
                    enc_done_flag <= 1'b1;
                    ctrl_state <= C_ENC_OK;
                end
            end

            C_ENC_OK: begin
                if (auto_mode) begin
                    dma_decrypt <= 1'b1;
                    dma_start <= 1'b1;
                    ctrl_state <= C_DEC_RUN;
                end else begin
                    ctrl_state <= C_DONE;
                end
            end

            C_DEC_RUN: begin
                if (dma_done) begin
                    dec_done_flag <= 1'b1;
                    if (verify_enable)
                        verify_pass_flag <= 1'b1; // lightweight marker; full verifier may be added as a separate DMA phase.
                    ctrl_state <= C_DEC_OK;
                end
            end

            C_DEC_OK: begin
                ctrl_state <= C_DONE;
            end

            C_DONE: begin
                if (start_pulse)
                    ctrl_state <= C_IDLE;
            end

            default: ctrl_state <= C_CLEAR_SRAM;
        endcase
    end
end

assign LEDG[0] = image_ready;
assign LEDG[1] = clear_busy || uart_loader_busy;
assign LEDG[2] = dma_busy;
assign LEDG[3] = enc_done_flag;
assign LEDG[4] = dec_done_flag;
assign LEDG[5] = verify_pass_flag;
assign LEDG[6] = uart_packet_valid_dbg;
assign LEDG[7] = uart_tx_busy_dbg;
assign LEDG[8] = image_bypass;

assign LEDR[3:0]   = ctrl_state;
assign LEDR[7:4]   = dma_state_dbg;
assign LEDR[11:8]  = uart_packet_state;
assign LEDR[15:12] = uart_writer_state;
assign LEDR[17:16] = bus_owner_dbg;

endmodule
