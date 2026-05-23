//------------------------------------------------------------------------------
// vga_quadrant_renderer_320x240.v
// Render 4 vùng 320x240: original, dashboard, encrypted, decrypted.
// VGA image pixels lấy từ SRAM data khi vga_pixel_valid=1.
//------------------------------------------------------------------------------
module vga_quadrant_renderer_320x240(
    input  wire        clk_25,
    input  wire        reset,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        video_on,
    input  wire        bus_view_enable,
    input  wire [15:0] sram_pixel,
    input  wire        sram_pixel_valid,

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
    input  wire [7:0]  uart_flags,

    output reg  [9:0]  VGA_R,
    output reg  [9:0]  VGA_G,
    output reg  [9:0]  VGA_B
);

wire in_tl = (x < 10'd320) && (y < 10'd240);
wire in_tr = (x >= 10'd320) && (y < 10'd240);
wire in_bl = (x < 10'd320) && (y >= 10'd240);
wire in_br = (x >= 10'd320) && (y >= 10'd240);
wire [9:0] local_x = in_tr || in_br ? (x - 10'd320) : x;
wire [9:0] local_y = in_bl || in_br ? (y - 10'd240) : y;

wire text_pixel;
text_dashboard u_text(
    .local_x(local_x), .local_y(local_y),
    .sys_state(sys_state), .dma_state(dma_state), .core_state(core_state), .bus_owner(bus_owner),
    .fast_mode(fast_mode), .slow_level(slow_level), .decrypt_mode(decrypt_mode), .auto_mode(auto_mode),
    .block_counter(block_counter), .row_counter(row_counter), .col_block(col_block),
    .cycle_counter(cycle_counter), .active_cycle_counter(active_cycle_counter),
    .enc_done(enc_done), .dec_done(dec_done), .verify_pass(verify_pass), .verify_fail(verify_fail),
    .image_loaded(image_loaded), .uart_busy(uart_busy), .uart_packet_count(uart_packet_count),
    .uart_packet_state(uart_packet_state), .uart_writer_state(uart_writer_state),
    .uart_crc_calc(uart_crc_calc), .uart_crc_recv(uart_crc_recv), .uart_flags(uart_flags),
    .pixel_on(text_pixel)
);

wire [15:0] rgb565 = sram_pixel_valid ? sram_pixel : 16'h0000;
wire [9:0] img_r = {rgb565[15:11], 5'b00000};
wire [9:0] img_g = {rgb565[10:5],  4'b0000};
wire [9:0] img_b = {rgb565[4:0],   5'b00000};

localparam SYS_ENC_RUN = 4'd2;
localparam SYS_DEC_RUN = 4'd4;

wire [15:0] pixel_block_index = (local_y[8:0] * 16'd40) + {10'd0, local_x[9:3]};
wire raw_region_has_data = image_loaded;
wire enc_region_has_data = enc_done ||
                           ((sys_state == SYS_ENC_RUN) && (pixel_block_index < block_counter));
wire dec_region_has_data = dec_done ||
                           ((sys_state == SYS_DEC_RUN) && (pixel_block_index < block_counter));
wire raw_image_visible = in_tl && raw_region_has_data && bus_view_enable && sram_pixel_valid;
wire enc_image_visible = in_bl && enc_region_has_data && bus_view_enable && sram_pixel_valid;
wire dec_image_visible = in_br && dec_region_has_data && bus_view_enable && sram_pixel_valid;

wire label_region = in_tl || in_bl || in_br;
wire [9:0] label_start_x = in_tl ? 10'd112 : 10'd16;
wire [9:0] label_width = in_tl ? 10'd96 : 10'd288;
wire label_box = label_region &&
                 (local_x >= label_start_x) && (local_x < (label_start_x + label_width)) &&
                 (local_y >= 10'd104) && (local_y < 10'd136);
wire [9:0] label_dx = local_x - label_start_x;
wire [9:0] label_dy = local_y - 10'd104;
wire [3:0] label_index = label_dx[8:5];
wire [2:0] label_font_col = label_dx[4:2];
wire [2:0] label_font_row = label_dy[4:2];
wire [1:0] label_kind = in_tl ? 2'd0 : (in_bl ? 2'd1 : 2'd2);
wire [7:0] label_char_code;
wire [7:0] label_font_bits;
wire label_pixel = label_box && label_font_bits[7-label_font_col];
wire label_visible = (in_tl && !raw_region_has_data) ||
                     (in_bl && !enc_region_has_data) ||
                     (in_br && !dec_region_has_data);

function [7:0] label_char;
    input [1:0] kind;
    input [3:0] idx;
    begin
        label_char = " ";
        case (kind)
            2'd0: begin
                case (idx)
                    4'd0: label_char = "R";
                    4'd1: label_char = "A";
                    4'd2: label_char = "W";
                    default: label_char = " ";
                endcase
            end
            2'd1: begin
                case (idx)
                    4'd0: label_char = "E";
                    4'd1: label_char = "N";
                    4'd2: label_char = "C";
                    4'd3: label_char = "R";
                    4'd4: label_char = "Y";
                    4'd5: label_char = "P";
                    4'd6: label_char = "T";
                    4'd7: label_char = "E";
                    4'd8: label_char = "D";
                    default: label_char = " ";
                endcase
            end
            default: begin
                case (idx)
                    4'd0: label_char = "D";
                    4'd1: label_char = "E";
                    4'd2: label_char = "C";
                    4'd3: label_char = "R";
                    4'd4: label_char = "Y";
                    4'd5: label_char = "P";
                    4'd6: label_char = "T";
                    4'd7: label_char = "E";
                    4'd8: label_char = "D";
                    default: label_char = " ";
                endcase
            end
        endcase
    end
endfunction

assign label_char_code = label_char(label_kind, label_index);
font_rom_8x8 u_label_font(.char_code(label_char_code), .row(label_font_row), .bits(label_font_bits));

always @(*) begin
    VGA_R = 10'd0;
    VGA_G = 10'd0;
    VGA_B = 10'd0;

    if (video_on) begin
        if (in_tr) begin
            if (text_pixel) begin
                VGA_R = 10'h3ff;
                VGA_G = 10'h3ff;
                VGA_B = 10'h3ff;
            end else begin
                VGA_R = 10'd0;
                VGA_G = 10'd40;
                VGA_B = 10'd80;
            end
        end else if (raw_image_visible) begin
            VGA_R = img_r;
            VGA_G = img_g;
            VGA_B = img_b;
        end else if (enc_image_visible) begin
            VGA_R = img_r;
            VGA_G = img_g;
            VGA_B = img_b;
        end else if (dec_image_visible) begin
            VGA_R = img_r;
            VGA_G = img_g;
            VGA_B = img_b;
        end else if (in_tl) begin
            VGA_R = 10'd40; VGA_G = 10'd40; VGA_B = 10'd40;
        end else if (in_bl) begin
            VGA_R = 10'd56; VGA_G = 10'd8;  VGA_B = 10'd8;
        end else if (in_br) begin
            VGA_R = 10'd8;  VGA_G = 10'd44; VGA_B = 10'd56;
        end

        if (label_visible && label_pixel) begin
            VGA_R = 10'h3ff;
            VGA_G = 10'h3ff;
            VGA_B = 10'h280;
        end
    end
end

endmodule
