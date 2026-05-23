module MasterController (
    input  wire        CLOCK_50,
    input  wire        reset_n,
    input  wire        btn_enc,
    input  wire        btn_dec,

    // SRAM
    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_CE_N,

    // VGA
    output wire        VGA_HS,
    output wire        VGA_VS,
    output wire [9:0]  VGA_R,
    output wire [9:0]  VGA_G,
    output wire [9:0]  VGA_B,
    output wire        VGA_CLK,
    output wire        VGA_BLANK_N,
    output wire        VGA_SYNC_N
);

//=============================================================================
// CONSTANTS
//=============================================================================
localparam [2:0] ST_INIT     = 3'd0;
localparam [2:0] ST_IDLE     = 3'd1;
localparam [2:0] ST_ENCRYPT  = 3'd2;
localparam [2:0] ST_WAIT_DEC = 3'd3;
localparam [2:0] ST_DECRYPT  = 3'd4;
localparam [2:0] ST_DONE     = 3'd5;

localparam [3:0] P_IDLE         = 4'd0;
localparam [3:0] P_READ_SETUP   = 4'd1;
localparam [3:0] P_READ_ASSERT  = 4'd2;
localparam [3:0] P_READ_CAPTURE = 4'd3;
localparam [3:0] P_READ_TAKE    = 4'd4;
localparam [3:0] P_AES_START    = 4'd5;
localparam [3:0] P_AES_WAIT     = 4'd6;
localparam [3:0] P_WRITE_SETUP  = 4'd7;
localparam [3:0] P_WRITE_PULSE  = 4'd8;
localparam [3:0] P_NEXT         = 4'd9;

localparam [1:0] I_ROM_ADDR    = 2'd0;
localparam [1:0] I_ROM_WAIT    = 2'd1;
localparam [1:0] I_WRITE_SETUP = 2'd2;
localparam [1:0] I_WRITE_PULSE = 2'd3;

localparam [17:0] ADDR_ORIG = 18'h00000;
localparam [17:0] ADDR_ENC  = 18'h10000;
localparam [17:0] ADDR_DEC  = 18'h20000;

localparam [9:0] IMG_Y0 = 10'd176;
localparam [9:0] IMG_Y1 = 10'd304;
localparam [9:0] ORIG_X0 = 10'd40;
localparam [9:0] ORIG_X1 = 10'd168;
localparam [9:0] ENC_X0  = 10'd256;
localparam [9:0] ENC_X1  = 10'd384;
localparam [9:0] DEC_X0  = 10'd472;
localparam [9:0] DEC_X1  = 10'd600;

//=============================================================================
// REG/WIRE
//=============================================================================
reg [2:0] state_fsm;
reg [3:0] proc_fsm;
reg [1:0] init_phase;

reg [6:0] row_enc;
reg [6:0] row_dec;

reg [3:0] block_idx;
reg [2:0] pixel_idx;

reg is_encrypted;

reg [13:0] init_counter;
reg [13:0] rom_addr;

wire [15:0] rom_data_out;

wire [9:0] vga_x;
wire [9:0] vga_y;
wire       vga_on;
wire       v_blank;

reg clk_25;

reg [1:0] btn_enc_sync;
reg [1:0] btn_dec_sync;

// SRAM control
reg [17:0] aes_addr;
reg [15:0] aes_wdata;
reg        aes_we;
reg        aes_rd;

wire [15:0] sram_data_r;

// AES
reg  [127:0] aes_in;

wire [127:0] enc_out;
wire [127:0] dec_out;
wire [127:0] aes_result;
reg  [15:0]  aes_result_word;

reg  enc_start;
reg  dec_start;

wire enc_done;
wire dec_done;

wire btn_enc_pressed;
wire btn_dec_pressed;

//=============================================================================
// 25MHz CLOCK
//=============================================================================
always @(posedge CLOCK_50 or negedge reset_n) begin
    if(!reset_n)
        clk_25 <= 1'b0;
    else
        clk_25 <= ~clk_25;
end

//=============================================================================
// INPUT SYNCHRONIZERS
//=============================================================================
always @(posedge CLOCK_50 or negedge reset_n) begin
    if(!reset_n) begin
        btn_enc_sync <= 2'b11;
        btn_dec_sync <= 2'b11;
    end
    else begin
        btn_enc_sync <= {btn_enc_sync[0], btn_enc};
        btn_dec_sync <= {btn_dec_sync[0], btn_dec};
    end
end

assign btn_enc_pressed = ~btn_enc_sync[1];
assign btn_dec_pressed = ~btn_dec_sync[1];

//=============================================================================
// VGA CONTROLLER
//=============================================================================
vga_controller VGA_UNIT (
    .clk_25mhz(clk_25),
    .reset(!reset_n),
    .hsync(VGA_HS),
    .vsync(VGA_VS),
    .x_pos(vga_x),
    .y_pos(vga_y),
    .video_on(vga_on)
);

assign v_blank = (vga_y >= 10'd480);

//=============================================================================
// VGA ADDRESSING
//=============================================================================
wire in_img_y   = (vga_y >= IMG_Y0) && (vga_y < IMG_Y1);
wire in_orig_x  = (vga_x >= ORIG_X0) && (vga_x < ORIG_X1);
wire in_enc_x   = (vga_x >= ENC_X0)  && (vga_x < ENC_X1);
wire in_dec_x   = (vga_x >= DEC_X0)  && (vga_x < DEC_X1);

wire [9:0] vga_row_full = vga_y - IMG_Y0;
wire [9:0] orig_col_full = vga_x - ORIG_X0;
wire [9:0] enc_col_full  = vga_x - ENC_X0;
wire [9:0] dec_col_full  = vga_x - DEC_X0;

wire [6:0] vga_img_row = vga_row_full[6:0];
wire [6:0] orig_col = orig_col_full[6:0];
wire [6:0] enc_col  = enc_col_full[6:0];
wire [6:0] dec_col  = dec_col_full[6:0];

wire show_orig = vga_on && in_img_y && in_orig_x && (state_fsm != ST_INIT);
wire show_enc  = vga_on && in_img_y && in_enc_x &&
                 ((state_fsm == ST_WAIT_DEC) ||
                  (state_fsm == ST_DECRYPT) ||
                  (state_fsm == ST_DONE) ||
                  ((state_fsm == ST_ENCRYPT) && (vga_img_row < row_enc)));
wire show_dec  = vga_on && in_img_y && in_dec_x &&
                 ((state_fsm == ST_DONE) ||
                  ((state_fsm == ST_DECRYPT) && (vga_img_row < row_dec)));
wire show_pixel = show_orig || show_enc || show_dec;

wire [17:0] vga_row_offset  = {4'b0000, vga_img_row, 7'b0000000};
wire [17:0] orig_col_offset = {11'b00000000000, orig_col};
wire [17:0] enc_col_offset  = {11'b00000000000, enc_col};
wire [17:0] dec_col_offset  = {11'b00000000000, dec_col};

wire [17:0] vga_addr =
    show_orig ? (ADDR_ORIG + vga_row_offset + orig_col_offset) :
    show_enc  ? (ADDR_ENC  + vga_row_offset + enc_col_offset)  :
    show_dec  ? (ADDR_DEC  + vga_row_offset + dec_col_offset)  :
                ADDR_ORIG;

//=============================================================================
// SRAM CONTROLLER
//=============================================================================
sram_controller SRAM_UNIT (
    .clk(CLOCK_50),
    .reset(!reset_n),
    .i_addr(v_blank ? aes_addr : vga_addr),
    .i_data_write(aes_wdata),
    .i_we(v_blank && aes_we),
    .i_rd(v_blank ? aes_rd : 1'b1),
    .o_data_read(sram_data_r),
    .SRAM_ADDR(SRAM_ADDR),
    .SRAM_DQ(SRAM_DQ),
    .SRAM_WE_N(SRAM_WE_N),
    .SRAM_OE_N(SRAM_OE_N),
    .SRAM_UB_N(SRAM_UB_N),
    .SRAM_LB_N(SRAM_LB_N),
    .SRAM_CE_N(SRAM_CE_N)
);

//=============================================================================
// AES CORES
//=============================================================================
aes_encryption_core ENC_UNIT (
    .clk(CLOCK_50),
    .reset_n(reset_n),
    .start_n(enc_start),
    .plaintext(aes_in),
    .key(128'h2b7e151628aed2a6abf7158809cf4f3c),
    .ciphertext(enc_out),
    .done(enc_done)
);

aes_decryption_core DEC_UNIT (
    .clk(CLOCK_50),
    .reset_n(reset_n),
    .start_n(dec_start),
    .ciphertext(aes_in),
    .key(128'h2b7e151628aed2a6abf7158809cf4f3c),
    .plaintext(dec_out),
    .done(dec_done)
);

//=============================================================================
// IMAGE ROM
//=============================================================================
image_rom ROM_UNIT (
    .address(rom_addr),
    .clock(CLOCK_50),
    .data(16'd0),
    .wren(1'b0),
    .q(rom_data_out)
);

//=============================================================================
// VGA OUTPUT
//=============================================================================
assign VGA_CLK     = clk_25;
assign VGA_SYNC_N  = 1'b0;
assign VGA_BLANK_N = vga_on;

wire [4:0] pixel_r = sram_data_r[15:11];
wire [5:0] pixel_g = sram_data_r[10:5];
wire [4:0] pixel_b = sram_data_r[4:0];

assign VGA_R = show_pixel ? {pixel_r, pixel_r}       : 10'd0;
assign VGA_G = show_pixel ? {pixel_g, pixel_g[5:2]}  : 10'd0;
assign VGA_B = show_pixel ? {pixel_b, pixel_b}       : 10'd0;

//=============================================================================
// ADDRESS AND RESULT HELPERS
//=============================================================================
wire [6:0]  active_row       = (state_fsm == ST_ENCRYPT) ? row_enc : row_dec;
wire [17:0] proc_row_offset  = {4'b0000, active_row, 7'b0000000};
wire [17:0] proc_blk_offset  = {11'b00000000000, block_idx, 3'b000};
wire [17:0] proc_pix_offset  = {15'b000000000000000, pixel_idx};
wire [17:0] read_base        = (state_fsm == ST_ENCRYPT) ? ADDR_ORIG : ADDR_ENC;
wire [17:0] write_base       = (state_fsm == ST_ENCRYPT) ? ADDR_ENC  : ADDR_DEC;
wire [17:0] proc_read_addr   = read_base  + proc_row_offset + proc_blk_offset + proc_pix_offset;
wire [17:0] proc_write_addr  = write_base + proc_row_offset + proc_blk_offset + proc_pix_offset;

assign aes_result = (state_fsm == ST_ENCRYPT) ? enc_out : dec_out;

always @(*) begin
    case(pixel_idx)
        3'd0: aes_result_word = aes_result[127:112];
        3'd1: aes_result_word = aes_result[111:96];
        3'd2: aes_result_word = aes_result[95:80];
        3'd3: aes_result_word = aes_result[79:64];
        3'd4: aes_result_word = aes_result[63:48];
        3'd5: aes_result_word = aes_result[47:32];
        3'd6: aes_result_word = aes_result[31:16];
        default: aes_result_word = aes_result[15:0];
    endcase
end

//=============================================================================
// MAIN CONTROLLER
//=============================================================================
always @(posedge CLOCK_50 or negedge reset_n) begin
    if(!reset_n) begin
        state_fsm <= ST_INIT;
        proc_fsm <= P_IDLE;
        init_phase <= I_ROM_ADDR;

        row_enc <= 7'd0;
        row_dec <= 7'd0;
        block_idx <= 4'd0;
        pixel_idx <= 3'd0;
        is_encrypted <= 1'b0;

        init_counter <= 14'd0;
        rom_addr <= 14'd0;

        aes_addr <= 18'd0;
        aes_wdata <= 16'd0;
        aes_we <= 1'b0;
        aes_rd <= 1'b0;
        aes_in <= 128'd0;

        enc_start <= 1'b1;
        dec_start <= 1'b1;
    end
    else begin
        enc_start <= 1'b1;
        dec_start <= 1'b1;
        aes_we <= 1'b0;
        aes_rd <= 1'b0;

        case(state_fsm)
            ST_INIT: begin
                proc_fsm <= P_IDLE;

                if(v_blank) begin
                    case(init_phase)
                        I_ROM_ADDR: begin
                            rom_addr <= init_counter;
                            init_phase <= I_ROM_WAIT;
                        end

                        I_ROM_WAIT: begin
                            init_phase <= I_WRITE_SETUP;
                        end

                        I_WRITE_SETUP: begin
                            aes_addr <= {4'b0000, init_counter};
                            aes_wdata <= rom_data_out;
                            init_phase <= I_WRITE_PULSE;
                        end

                        I_WRITE_PULSE: begin
                            aes_we <= 1'b1;
                            init_phase <= I_ROM_ADDR;

                            if(init_counter == 14'd16383) begin
                                state_fsm <= ST_IDLE;
                            end
                            else begin
                                init_counter <= init_counter + 14'd1;
                            end
                        end
                    endcase
                end
            end

            ST_IDLE: begin
                proc_fsm <= P_IDLE;
                block_idx <= 4'd0;
                pixel_idx <= 3'd0;
                aes_in <= 128'd0;

                if(btn_enc_pressed) begin
                    row_enc <= 7'd0;
                    row_dec <= 7'd0;
                    is_encrypted <= 1'b0;
                    state_fsm <= ST_ENCRYPT;
                end
            end

            ST_WAIT_DEC: begin
                proc_fsm <= P_IDLE;
                block_idx <= 4'd0;
                pixel_idx <= 3'd0;
                aes_in <= 128'd0;

                if(is_encrypted && btn_dec_pressed) begin
                    row_dec <= 7'd0;
                    state_fsm <= ST_DECRYPT;
                end
            end

            ST_DONE: begin
                proc_fsm <= P_IDLE;
            end

            ST_ENCRYPT,
            ST_DECRYPT: begin
                if(v_blank) begin
                    case(proc_fsm)
                        P_IDLE: begin
                            pixel_idx <= 3'd0;
                            aes_in <= 128'd0;
                            proc_fsm <= P_READ_SETUP;
                        end

                        P_READ_SETUP: begin
                            aes_addr <= proc_read_addr;
                            proc_fsm <= P_READ_ASSERT;
                        end

                        P_READ_ASSERT: begin
                            aes_rd <= 1'b1;
                            proc_fsm <= P_READ_CAPTURE;
                        end

                        P_READ_CAPTURE: begin
                            aes_rd <= 1'b1;
                            proc_fsm <= P_READ_TAKE;
                        end

                        P_READ_TAKE: begin
                            aes_in <= {aes_in[111:0], sram_data_r};

                            if(pixel_idx == 3'd7) begin
                                pixel_idx <= 3'd0;
                                proc_fsm <= P_AES_START;
                            end
                            else begin
                                pixel_idx <= pixel_idx + 3'd1;
                                proc_fsm <= P_READ_SETUP;
                            end
                        end

                        P_AES_START: begin
                            if(state_fsm == ST_ENCRYPT)
                                enc_start <= 1'b0;
                            else
                                dec_start <= 1'b0;

                            proc_fsm <= P_AES_WAIT;
                        end

                        P_AES_WAIT: begin
                            if((state_fsm == ST_ENCRYPT && enc_done) ||
                               (state_fsm == ST_DECRYPT && dec_done)) begin
                                pixel_idx <= 3'd0;
                                proc_fsm <= P_WRITE_SETUP;
                            end
                        end

                        P_WRITE_SETUP: begin
                            aes_addr <= proc_write_addr;
                            aes_wdata <= aes_result_word;
                            proc_fsm <= P_WRITE_PULSE;
                        end

                        P_WRITE_PULSE: begin
                            aes_we <= 1'b1;

                            if(pixel_idx == 3'd7) begin
                                pixel_idx <= 3'd0;
                                proc_fsm <= P_NEXT;
                            end
                            else begin
                                pixel_idx <= pixel_idx + 3'd1;
                                proc_fsm <= P_WRITE_SETUP;
                            end
                        end

                        P_NEXT: begin
                            pixel_idx <= 3'd0;
                            aes_in <= 128'd0;

                            if(block_idx == 4'd15) begin
                                block_idx <= 4'd0;

                                if(state_fsm == ST_ENCRYPT) begin
                                    if(row_enc == 7'd127) begin
                                        is_encrypted <= 1'b1;
                                        state_fsm <= ST_WAIT_DEC;
                                        proc_fsm <= P_IDLE;
                                    end
                                    else begin
                                        row_enc <= row_enc + 7'd1;
                                        proc_fsm <= P_READ_SETUP;
                                    end
                                end
                                else begin
                                    if(row_dec == 7'd127) begin
                                        state_fsm <= ST_DONE;
                                        proc_fsm <= P_IDLE;
                                    end
                                    else begin
                                        row_dec <= row_dec + 7'd1;
                                        proc_fsm <= P_READ_SETUP;
                                    end
                                end
                            end
                            else begin
                                block_idx <= block_idx + 4'd1;
                                proc_fsm <= P_READ_SETUP;
                            end
                        end

                        default: begin
                            proc_fsm <= P_IDLE;
                        end
                    endcase
                end
            end

            default: begin
                state_fsm <= ST_INIT;
            end
        endcase
    end
end

endmodule
