//------------------------------------------------------------------------------
// aes_sram_dma_320x240.v
// DMA đọc/ghi ảnh RGB565 trong SRAM theo block AES 128-bit = 8 pixel.
// Default: 320x240, nhưng có parameter để rút nhỏ khi simulation.
//------------------------------------------------------------------------------
module aes_sram_dma_320x240 #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter ADDR_ORIG = 18'h00000,
    parameter ADDR_ENC  = 18'h14000,
    parameter ADDR_DEC  = 18'h28000
)(
    input  wire        clk,
    input  wire        reset_n,

    input  wire        start,
    input  wire        decrypt,       // 0 encrypt ORIG->ENC, 1 decrypt ENC->DEC
    input  wire        fast_mode,
    input  wire [1:0]  slow_level,
    input  wire        pause,
    input  wire        step,
    input  wire        frame_tick,

    output reg         busy,
    output reg         done,
    output reg         block_done_pulse,
    output reg         row_done_pulse,

    output reg         sram_req,
    output reg         sram_we,
    output reg         sram_rd,
    output reg [17:0]  sram_addr,
    output reg [15:0]  sram_wdata,
    input  wire [15:0] sram_rdata,
    input  wire        sram_grant,

    output reg         aes_start,
    output reg         aes_decrypt,
    output reg [127:0] aes_block_in,
    input  wire [127:0] aes_block_out,
    input  wire        aes_done,
    input  wire        aes_busy,

    output reg [3:0]   state_dbg,
    output reg [15:0]  block_counter,
    output reg [8:0]   row_dbg,
    output reg [5:0]   col_block_dbg,
    output reg [2:0]   pixel_dbg,
    output reg [31:0]  cycle_counter,
    output reg [31:0]  active_cycle_counter
);

localparam BLOCKS_PER_ROW = IMG_W / 8;
localparam TOTAL_BLOCKS   = (IMG_W / 8) * IMG_H;

localparam S_IDLE       = 4'd0;
localparam S_READ_REQ   = 4'd1;
localparam S_READ_WAIT  = 4'd2;
localparam S_READ_CAP   = 4'd3;
localparam S_AES_START  = 4'd4;
localparam S_AES_WAIT   = 4'd5;
localparam S_WRITE_REQ  = 4'd6;
localparam S_WRITE_WAIT = 4'd7;
localparam S_NEXT       = 4'd8;
localparam S_THROTTLE   = 4'd9;
localparam S_DONE       = 4'd10;

reg [3:0] state;
reg [2:0] pixel_idx;
reg [15:0] block_idx;
reg [15:0] row_idx;
reg [15:0] col_idx;
reg [15:0] throttle_count;
reg frame_seen;
reg step_seen;
reg paused;
reg [3:0] rows_this_frame;

wire [17:0] pixel_base = row_idx * IMG_W + col_idx * 8;
wire [17:0] src_base = decrypt ? ADDR_ENC : ADDR_ORIG;
wire [17:0] dst_base = decrypt ? ADDR_DEC : ADDR_ENC;
wire last_pixel = (pixel_idx == 3'd7);
wire last_block = (block_idx == (TOTAL_BLOCKS - 1));
wire end_of_row = (col_idx == (BLOCKS_PER_ROW - 1));

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        frame_seen <= 1'b0;
        step_seen <= 1'b0;
    end else begin
        if (frame_tick) begin
            frame_seen <= 1'b1;
        end
        if (state != S_THROTTLE) begin
            step_seen <= 1'b0;
            if (state == S_READ_REQ)
                frame_seen <= 1'b0;
        end else begin
            if (step) step_seen <= 1'b1;
        end
    end
end

wire [3:0] row_budget = (slow_level == 2'b00) ? 4'd8 :
                         (slow_level == 2'b01) ? 4'd2 :
                         (slow_level == 2'b10) ? 4'd1 : 4'd0;

wire row_gate_release = (!end_of_row) ? 1'b1 :
                        (rows_this_frame < row_budget) ? 1'b1 : frame_seen;

wire slow_release = fast_mode ? 1'b1 :
                    (slow_level == 2'b11) ? (frame_seen || step_seen) : row_gate_release;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= S_IDLE;
        busy <= 1'b0;
        done <= 1'b0;
        sram_req <= 1'b0;
        sram_we <= 1'b0;
        sram_rd <= 1'b0;
        sram_addr <= 18'd0;
        sram_wdata <= 16'd0;
        aes_start <= 1'b0;
        aes_decrypt <= 1'b0;
        aes_block_in <= 128'd0;
        block_idx <= 16'd0;
        row_idx <= 16'd0;
        col_idx <= 16'd0;
        pixel_idx <= 3'd0;
        block_counter <= 16'd0;
        row_dbg <= 9'd0;
        col_block_dbg <= 6'd0;
        pixel_dbg <= 3'd0;
        cycle_counter <= 32'd0;
        active_cycle_counter <= 32'd0;
        state_dbg <= S_IDLE;
        throttle_count <= 16'd0;
        paused <= 1'b0;
        rows_this_frame <= 4'd0;
        block_done_pulse <= 1'b0;
        row_done_pulse <= 1'b0;
    end else begin
        done <= 1'b0;
        aes_start <= 1'b0;
        block_done_pulse <= 1'b0;
        row_done_pulse <= 1'b0;
        state_dbg <= state;
        if (frame_tick)
            rows_this_frame <= 4'd0;

        if (busy)
            cycle_counter <= cycle_counter + 32'd1;
        if (busy && state != S_THROTTLE)
            active_cycle_counter <= active_cycle_counter + 32'd1;

        if (pause)
            paused <= ~paused;

        case (state)
            S_IDLE: begin
                busy <= 1'b0;
                sram_req <= 1'b0;
                sram_we <= 1'b0;
                sram_rd <= 1'b0;
                if (start) begin
                    busy <= 1'b1;
                    block_idx <= 16'd0;
                    row_idx <= 16'd0;
                    col_idx <= 16'd0;
                    pixel_idx <= 3'd0;
                    block_counter <= 16'd0;
                    cycle_counter <= 32'd0;
                    active_cycle_counter <= 32'd0;
                    aes_decrypt <= decrypt;
                    paused <= 1'b0;
                    state <= S_READ_REQ;
                end
            end

            S_READ_REQ: begin
                if (!paused) begin
                    sram_req <= 1'b1;
                    sram_we <= 1'b0;
                    sram_rd <= 1'b1;
                    sram_addr <= src_base + pixel_base + pixel_idx;
                    pixel_dbg <= pixel_idx;
                    row_dbg <= row_idx[8:0];
                    col_block_dbg <= col_idx[5:0];
                    if (sram_grant)
                        state <= S_READ_WAIT;
                end
            end

            S_READ_WAIT: begin
                sram_req <= 1'b0;
                sram_rd <= 1'b0;
                sram_we <= 1'b0;
                state <= S_READ_CAP;
            end

            S_READ_CAP: begin
                // byte ordering: pixel 0 đi vào MSW của AES block để dễ quan sát.
                case (pixel_idx)
                    3'd0: aes_block_in[127:112] <= sram_rdata;
                    3'd1: aes_block_in[111:96]  <= sram_rdata;
                    3'd2: aes_block_in[95:80]   <= sram_rdata;
                    3'd3: aes_block_in[79:64]   <= sram_rdata;
                    3'd4: aes_block_in[63:48]   <= sram_rdata;
                    3'd5: aes_block_in[47:32]   <= sram_rdata;
                    3'd6: aes_block_in[31:16]   <= sram_rdata;
                    3'd7: aes_block_in[15:0]    <= sram_rdata;
                endcase
                if (last_pixel) begin
                    pixel_idx <= 3'd0;
                    state <= S_AES_START;
                end else begin
                    pixel_idx <= pixel_idx + 3'd1;
                    state <= S_READ_REQ;
                end
            end

            S_AES_START: begin
                aes_decrypt <= decrypt;
                aes_start <= 1'b1;
                state <= S_AES_WAIT;
            end

            S_AES_WAIT: begin
                if (aes_done)
                    state <= S_WRITE_REQ;
            end

            S_WRITE_REQ: begin
                if (!paused) begin
                    sram_req <= 1'b1;
                    sram_we <= 1'b1;
                    sram_rd <= 1'b0;
                    sram_addr <= dst_base + pixel_base + pixel_idx;
                    case (pixel_idx)
                        3'd0: sram_wdata <= aes_block_out[127:112];
                        3'd1: sram_wdata <= aes_block_out[111:96];
                        3'd2: sram_wdata <= aes_block_out[95:80];
                        3'd3: sram_wdata <= aes_block_out[79:64];
                        3'd4: sram_wdata <= aes_block_out[63:48];
                        3'd5: sram_wdata <= aes_block_out[47:32];
                        3'd6: sram_wdata <= aes_block_out[31:16];
                        3'd7: sram_wdata <= aes_block_out[15:0];
                    endcase
                    pixel_dbg <= pixel_idx;
                    if (sram_grant)
                        state <= S_WRITE_WAIT;
                end
            end

            S_WRITE_WAIT: begin
                sram_req <= 1'b0;
                sram_we <= 1'b0;
                sram_rd <= 1'b0;
                if (last_pixel) begin
                    pixel_idx <= 3'd0;
                    state <= S_NEXT;
                end else begin
                    pixel_idx <= pixel_idx + 3'd1;
                    state <= S_WRITE_REQ;
                end
            end

            S_NEXT: begin
                block_done_pulse <= 1'b1;
                if (end_of_row) begin
                    row_done_pulse <= 1'b1;
                    if (rows_this_frame != 4'hf)
                        rows_this_frame <= rows_this_frame + 4'd1;
                end
                block_counter <= block_idx + 16'd1;
                if (last_block) begin
                    state <= S_DONE;
                end else begin
                    block_idx <= block_idx + 16'd1;
                    if (end_of_row) begin
                        col_idx <= 16'd0;
                        row_idx <= row_idx + 16'd1;
                    end else begin
                        col_idx <= col_idx + 16'd1;
                    end
                    throttle_count <= 16'd0;
                    state <= fast_mode ? S_READ_REQ : S_THROTTLE;
                end
            end

            S_THROTTLE: begin
                throttle_count <= throttle_count + 16'd1;
                if (slow_release)
                    state <= S_READ_REQ;
            end

            S_DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= S_IDLE;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule
