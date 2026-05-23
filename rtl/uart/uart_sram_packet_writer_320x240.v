//------------------------------------------------------------------------------
// uart_sram_packet_writer_320x240.v
// Writes validated 256-byte UART packets into SRAM as 128 RGB565 words.
// The PC sender sends RGB565 as high byte first then low byte. This writer stores
// each SRAM word as {high_byte, low_byte}.
//------------------------------------------------------------------------------
module uart_sram_packet_writer_320x240 #(
    parameter ADDR_BASE     = 18'h00000,
    parameter TOTAL_PACKETS = 600
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,
    input  wire        clear,

    input  wire        packet_valid,
    input  wire [7:0]  packet_pd_data,
    output wire [7:0]  packet_pd_address,

    output reg         sram_req,
    output reg         sram_we,
    output reg [17:0]  sram_addr,
    output reg [15:0]  sram_wdata,
    input  wire        sram_grant,

    output reg         busy,
    output reg         image_loaded,
    output reg [9:0]   packet_count,
    output reg [7:0]   word_index_dbg,
    output reg [3:0]   state_dbg
);

    localparam S_IDLE      = 4'd0;
    localparam S_CAP_HIGH  = 4'd1;
    localparam S_CAP_LOW   = 4'd2;
    localparam S_WRITE     = 4'd3;
    localparam S_NEXT_WORD = 4'd4;
    localparam S_NEXT_PKT  = 4'd5;
    localparam S_DONE      = 4'd6;

    reg [3:0] state;
    reg [7:0] packet_addr_reg;
    reg [7:0] word_index;
    reg [7:0] high_byte;
    reg       packet_valid_d;

    wire packet_valid_posedge;
    assign packet_valid_posedge = packet_valid & ~packet_valid_d;
    assign packet_pd_address = packet_addr_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            packet_valid_d <= 1'b0;
        end else begin
            packet_valid_d <= packet_valid;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            packet_addr_reg <= 8'd0;
            word_index <= 8'd0;
            high_byte <= 8'd0;
            sram_req <= 1'b0;
            sram_we <= 1'b0;
            sram_addr <= ADDR_BASE;
            sram_wdata <= 16'd0;
            busy <= 1'b0;
            image_loaded <= 1'b0;
            packet_count <= 10'd0;
            word_index_dbg <= 8'd0;
            state_dbg <= S_IDLE;
        end else begin
            state_dbg <= state;
            sram_req <= 1'b0;
            sram_we <= 1'b0;

            if (clear) begin
                state <= S_IDLE;
                packet_addr_reg <= 8'd0;
                word_index <= 8'd0;
                high_byte <= 8'd0;
                busy <= 1'b0;
                image_loaded <= 1'b0;
                packet_count <= 10'd0;
                word_index_dbg <= 8'd0;
            end else begin
                case (state)
                    S_IDLE: begin
                        busy <= 1'b0;
                        packet_addr_reg <= 8'd0;
                        word_index <= 8'd0;
                        word_index_dbg <= 8'd0;
                        if (enable && !image_loaded && packet_valid_posedge) begin
                            busy <= 1'b1;
                            state <= S_CAP_HIGH;
                        end
                    end

                    S_CAP_HIGH: begin
                        high_byte <= packet_pd_data;
                        packet_addr_reg <= packet_addr_reg + 8'd1;
                        state <= S_CAP_LOW;
                    end

                    S_CAP_LOW: begin
                        sram_wdata <= {high_byte, packet_pd_data};
                        sram_addr <= ADDR_BASE + ({8'd0, packet_count} << 7) + {10'd0, word_index};
                        packet_addr_reg <= packet_addr_reg + 8'd1;
                        state <= S_WRITE;
                    end

                    S_WRITE: begin
                        sram_req <= 1'b1;
                        sram_we <= 1'b1;
                        if (sram_grant)
                            state <= S_NEXT_WORD;
                    end

                    S_NEXT_WORD: begin
                        if (word_index == 8'd127) begin
                            word_index <= 8'd0;
                            word_index_dbg <= 8'd127;
                            state <= S_NEXT_PKT;
                        end else begin
                            word_index <= word_index + 8'd1;
                            word_index_dbg <= word_index + 8'd1;
                            state <= S_CAP_HIGH;
                        end
                    end

                    S_NEXT_PKT: begin
                        packet_addr_reg <= 8'd0;
                        busy <= 1'b0;
                        if (packet_count == (TOTAL_PACKETS - 1)) begin
                            image_loaded <= 1'b1;
                            state <= S_DONE;
                        end else begin
                            packet_count <= packet_count + 10'd1;
                            state <= S_IDLE;
                        end
                    end

                    S_DONE: begin
                        busy <= 1'b0;
                        image_loaded <= 1'b1;
                        state <= S_DONE;
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule
