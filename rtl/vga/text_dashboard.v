//------------------------------------------------------------------------------
// text_dashboard.v
// Dashboard top-right 320x240, font 8x8, 40x30 chars.
// v2.1 adds UART image-load status.
//------------------------------------------------------------------------------
module text_dashboard(
    input  wire [9:0]  local_x,
    input  wire [9:0]  local_y,
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
    output wire        pixel_on
);

wire [9:0] padded_y = (local_y >= 10'd16) ? (local_y - 10'd16) : 10'd511;
wire [5:0] char_col = local_x[9:3];
wire [4:0] char_row = padded_y[8:3];
wire [2:0] font_row = padded_y[2:0];
wire [2:0] font_col = local_x[2:0];
reg  [7:0] ch;
wire [7:0] font_bits;

function [7:0] hexchar;
    input [3:0] v;
    begin
        case(v)
            4'h0: hexchar = "0"; 4'h1: hexchar = "1"; 4'h2: hexchar = "2"; 4'h3: hexchar = "3";
            4'h4: hexchar = "4"; 4'h5: hexchar = "5"; 4'h6: hexchar = "6"; 4'h7: hexchar = "7";
            4'h8: hexchar = "8"; 4'h9: hexchar = "9"; 4'ha: hexchar = "A"; 4'hb: hexchar = "B";
            4'hc: hexchar = "C"; 4'hd: hexchar = "D"; 4'he: hexchar = "E"; default: hexchar = "F";
        endcase
    end
endfunction

function [7:0] fixed_char;
    input [8*40-1:0] str;
    input [5:0] c;
    begin
        fixed_char = str[(39-c)*8 +: 8];
    end
endfunction

always @(*) begin
    ch = " ";
    case (char_row)
        5'd0:  ch = fixed_char("ImageAES128                             ", char_col);
        5'd1:  ch = fixed_char("UART 320X240 RGB565                     ", char_col);
        5'd3: begin
            if (char_col < 7) ch = fixed_char("STATE:                                  ", char_col);
            else if (char_col == 7) ch = hexchar(sys_state);
        end
        5'd4: begin
            if (char_col < 7) ch = fixed_char("DMA  :                                  ", char_col);
            else if (char_col == 7) ch = hexchar(dma_state);
        end
        5'd5: begin
            if (char_col < 7) ch = fixed_char("CORE :                                  ", char_col);
            else if (char_col == 7) ch = hexchar(core_state);
        end
        5'd6: begin
            if (char_col < 7) ch = fixed_char("MODE :                                  ", char_col);
            else begin
                if (fast_mode) begin
                    case(char_col) 7:ch="F";8:ch="A";9:ch="S";10:ch="T"; default:ch=" "; endcase
                end else begin
                    case(char_col) 7:ch="S";8:ch="L";9:ch="O";10:ch="W";12:ch="L";13:ch="3"; default:ch=" "; endcase
                end
            end
        end
        5'd7: begin
            if (char_col < 7) ch = fixed_char("OP   :                                  ", char_col);
            else if (auto_mode) begin case(char_col) 7:ch="A";8:ch="U";9:ch="T";10:ch="O"; default:ch=" "; endcase end
            else if (decrypt_mode) begin case(char_col) 7:ch="D";8:ch="E";9:ch="C"; default:ch=" "; endcase end
            else begin case(char_col) 7:ch="E";8:ch="N";9:ch="C"; default:ch=" "; endcase end
        end
        5'd8: begin
            if (char_col < 7) ch = fixed_char("BUS  :                                  ", char_col);
            else begin
                case (bus_owner)
                    2'd1: case(char_col) 7:ch="U";8:ch="A";9:ch="R";10:ch="T"; default:ch=" "; endcase
                    2'd2: case(char_col) 7:ch="A";8:ch="E";9:ch="S"; default:ch=" "; endcase
                    2'd3: case(char_col) 7:ch="V";8:ch="G";9:ch="A"; default:ch=" "; endcase
                    default: case(char_col) 7:ch="I";8:ch="D";9:ch="L";10:ch="E"; default:ch=" "; endcase
                endcase
            end
        end
        5'd10: begin
            if (char_col < 7) ch = fixed_char("UART :                                  ", char_col);
            else if (image_loaded) begin case(char_col) 7:ch="D";8:ch="O";9:ch="N";10:ch="E"; default:ch=" "; endcase end
            else if (uart_busy) begin case(char_col) 7:ch="L";8:ch="O";9:ch="A";10:ch="D"; default:ch=" "; endcase end
            else begin case(char_col) 7:ch="W";8:ch="A";9:ch="I";10:ch="T"; default:ch=" "; endcase end
        end
        5'd11: begin
            if (char_col < 7) ch = fixed_char("UPKT :                                  ", char_col);
            else if (char_col == 7) ch = hexchar({2'b00,uart_packet_count[9:8]});
            else if (char_col == 8) ch = hexchar(uart_packet_count[7:4]);
            else if (char_col == 9) ch = hexchar(uart_packet_count[3:0]);
            else if (char_col == 10) ch = "/";
            else if (char_col == 11) ch = "2";
            else if (char_col == 12) ch = "5";
            else if (char_col == 13) ch = "8";
        end
        5'd12: begin
            if (char_col < 7) ch = fixed_char("UCRC :                                  ", char_col);
            else if (char_col == 7) ch = hexchar(uart_crc_calc[7:4]);
            else if (char_col == 8) ch = hexchar(uart_crc_calc[3:0]);
            else if (char_col == 9) ch = "/";
            else if (char_col == 10) ch = hexchar(uart_crc_recv[7:4]);
            else if (char_col == 11) ch = hexchar(uart_crc_recv[3:0]);
            else if (char_col == 13) ch = hexchar(uart_packet_state);
            else if (char_col == 15) ch = hexchar(uart_writer_state);
            else if (char_col == 17) ch = hexchar(uart_flags[7:4]);
            else if (char_col == 18) ch = hexchar(uart_flags[3:0]);
        end
        5'd13: begin
            if (char_col < 7) ch = fixed_char("BLOCK:                                  ", char_col);
            else if (char_col == 7) ch = hexchar(block_counter[15:12]);
            else if (char_col == 8) ch = hexchar(block_counter[11:8]);
            else if (char_col == 9) ch = hexchar(block_counter[7:4]);
            else if (char_col == 10) ch = hexchar(block_counter[3:0]);
            else if (char_col == 11) ch = "/";
            else if (char_col == 12) ch = "2";
            else if (char_col == 13) ch = "5";
            else if (char_col == 14) ch = "8";
            else if (char_col == 15) ch = "0";
        end
        5'd14: begin
            if (char_col < 7) ch = fixed_char("ROW  :                                  ", char_col);
            else if (char_col == 7) ch = hexchar({3'b000,row_counter[8]});
            else if (char_col == 8) ch = hexchar(row_counter[7:4]);
            else if (char_col == 9) ch = hexchar(row_counter[3:0]);
            else if (char_col == 10) ch = "/";
            else if (char_col == 11) ch = "0";
            else if (char_col == 12) ch = "E";
            else if (char_col == 13) ch = "F";
        end
        5'd15: begin
            if (char_col < 7) ch = fixed_char("COL  :                                  ", char_col);
            else if (char_col == 7) ch = hexchar({2'b00,col_block[5:4]});
            else if (char_col == 8) ch = hexchar(col_block[3:0]);
            else if (char_col == 9) ch = "/";
            else if (char_col == 10) ch = "2";
            else if (char_col == 11) ch = "7";
        end
        5'd17: begin
            if (char_col < 7) ch = fixed_char("CYCLE:                                  ", char_col);
            else if (char_col >= 7 && char_col <= 14) ch = hexchar(cycle_counter[(14-char_col)*4 +: 4]);
        end
        5'd18: begin
            if (char_col < 7) ch = fixed_char("ACTIVE:                                 ", char_col);
            else if (char_col >= 7 && char_col <= 14) ch = hexchar(active_cycle_counter[(14-char_col)*4 +: 4]);
        end
        5'd20: begin
            if (char_col < 7) ch = fixed_char("ENC  :                                  ", char_col);
            else if (enc_done) begin case(char_col) 7:ch="D";8:ch="O";9:ch="N";10:ch="E"; default:ch=" "; endcase end
            else begin case(char_col) 7:ch="W";8:ch="A";9:ch="I";10:ch="T"; default:ch=" "; endcase end
        end
        5'd21: begin
            if (char_col < 7) ch = fixed_char("DEC  :                                  ", char_col);
            else if (dec_done) begin case(char_col) 7:ch="D";8:ch="O";9:ch="N";10:ch="E"; default:ch=" "; endcase end
            else begin case(char_col) 7:ch="W";8:ch="A";9:ch="I";10:ch="T"; default:ch=" "; endcase end
        end
        5'd22: begin
            if (char_col < 7) ch = fixed_char("VERIFY:                                 ", char_col);
            else if (verify_fail) begin case(char_col) 7:ch="F";8:ch="A";9:ch="I";10:ch="L"; default:ch=" "; endcase end
            else if (verify_pass) begin case(char_col) 7:ch="P";8:ch="A";9:ch="S";10:ch="S"; default:ch=" "; endcase end
            else begin case(char_col) 7:ch="O";8:ch="F";9:ch="F"; default:ch=" "; endcase end
        end
        5'd24: ch = fixed_char("KEY0 RESET  KEY1 START                  ", char_col);
        5'd25: ch = fixed_char("KEY2 PAUSE  KEY3 STEP                   ", char_col);
        5'd26: ch = fixed_char("SW0 FAST/SLOW SW1 ENC/DEC               ", char_col);
        5'd27: ch = fixed_char("SW2 AUTO SW0 FAST/SLOW-L3 SW8 BYPASS    ", char_col);
        default: ch = " ";
    endcase
end

font_rom_8x8 u_font(.char_code(ch), .row(font_row), .bits(font_bits));
assign pixel_on = font_bits[7-font_col];

endmodule
