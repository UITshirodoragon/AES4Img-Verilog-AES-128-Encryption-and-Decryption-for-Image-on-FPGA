//------------------------------------------------------------------------------
// uart_rx_packet_256.v
// Receives packets from UART stream using the protocol used by send_image_packet_2.py:
//   HEADER  : 0xAA
//   PAYLOAD : 256 bytes
//   CRC8    : 1 byte, poly 0x07, init 0xFF, calculated over payload only
// Response:
//   ACK  = 0x06 when CRC is correct
//   NACK = 0x15 on timeout/CRC error
//------------------------------------------------------------------------------
module uart_rx_packet_256 #(
    parameter TIMEOUT_MAX    = 32'd50000000,
    parameter DRAIN_IDLE_MAX = 32'd1000000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        rx_valid,
    input  wire [7:0]  rx_data,
    input  wire        tx_busy,

    output reg         packet_valid,
    output reg [7:0]   tx_data,
    output reg         tx_start,
    output reg         rx_clear,

    input  wire [7:0]  packet_pd_address,
    output wire [7:0]  packet_pd_data,

    output wire [3:0]  state_dbg,
    output wire [7:0]  byte_count_dbg,
    output wire [7:0]  crc_calc_dbg,
    output wire [7:0]  crc_recv_dbg,
    output wire [7:0]  debug_flags
);

    localparam IDLE        = 4'd0;
    localparam CLEAR_DATA  = 4'd1;
    localparam DATA        = 4'd2;
    localparam CLEAR_CRC   = 4'd3;
    localparam REC_CRC8    = 4'd4;
    localparam RECOVERY    = 4'd5;
    localparam SEND_NACK   = 4'd6;
    localparam SEND_ACK    = 4'd7;
    localparam WAIT_SEND   = 4'd8;
    localparam CLEAR_IDLE  = 4'd9;
    localparam DRAIN_RX    = 4'd10;

    reg [3:0]  state;
    reg [3:0]  next_state;
    reg [7:0]  crc;
    reg [7:0]  crc_rec;
    reg [7:0]  byte_cnt;
    reg [31:0] timeout_cnt;
    reg [31:0] drain_cnt;
    reg        nack_response;
    reg        header_seen;
    reg        crc_byte_seen;
    reg        crc_error_seen;
    reg        timeout_seen;
    reg        ack_seen;
    reg        nack_seen;
    reg [7:0]  buffer [0:255];

    wire timeout;
    wire drain_done;

    assign timeout = (timeout_cnt >= TIMEOUT_MAX);
    assign drain_done = (drain_cnt >= DRAIN_IDLE_MAX);
    assign packet_pd_data = buffer[packet_pd_address];

    function [7:0] crc8;
        input [7:0] crc_in;
        input [7:0] data_in;
        reg [7:0] crc_temp;
        integer i;
        begin
            crc_temp = crc_in ^ data_in;
            for (i = 0; i < 8; i = i + 1) begin
                if (crc_temp[7])
                    crc_temp = {crc_temp[6:0], 1'b0} ^ 8'h07;
                else
                    crc_temp = {crc_temp[6:0], 1'b0};
            end
            crc8 = crc_temp;
        end
    endfunction

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (rx_valid && rx_data == 8'hAA)
                    next_state = CLEAR_DATA;
            end
            CLEAR_DATA: begin
                if (!rx_valid)
                    next_state = DATA;
            end
            DATA: begin
                if (timeout)
                    next_state = RECOVERY;
                else if (rx_valid && byte_cnt == 8'd255)
                    next_state = CLEAR_CRC;
                else if (rx_valid)
                    next_state = CLEAR_DATA;
            end
            CLEAR_CRC: begin
                if (!rx_valid)
                    next_state = REC_CRC8;
            end
            REC_CRC8: begin
                if (timeout)
                    next_state = RECOVERY;
                else if (rx_valid && rx_data != crc)
                    next_state = RECOVERY;
                else if (rx_valid && rx_data == crc)
                    next_state = SEND_ACK;
            end
            RECOVERY: begin
                next_state = SEND_NACK;
            end
            SEND_NACK: begin
                if (tx_busy)
                    next_state = WAIT_SEND;
                else if (timeout)
                    next_state = CLEAR_IDLE;
            end
            SEND_ACK: begin
                if (tx_busy)
                    next_state = WAIT_SEND;
                else if (timeout)
                    next_state = CLEAR_IDLE;
            end
            WAIT_SEND: begin
                if (!tx_busy && nack_response)
                    next_state = DRAIN_RX;
                else if (!tx_busy)
                    next_state = CLEAR_IDLE;
                else if (timeout)
                    next_state = CLEAR_IDLE;
            end
            DRAIN_RX: begin
                if (rx_valid)
                    next_state = DRAIN_RX;
                else if (drain_done)
                    next_state = IDLE;
            end
            CLEAR_IDLE: begin
                if (!rx_valid)
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            crc <= 8'hFF;
            crc_rec <= 8'd0;
            byte_cnt <= 8'd0;
            timeout_cnt <= 32'd0;
            drain_cnt <= 32'd0;
            nack_response <= 1'b0;
            header_seen <= 1'b0;
            crc_byte_seen <= 1'b0;
            crc_error_seen <= 1'b0;
            timeout_seen <= 1'b0;
            ack_seen <= 1'b0;
            nack_seen <= 1'b0;
            rx_clear <= 1'b0;
            tx_start <= 1'b0;
            tx_data <= 8'd0;
            packet_valid <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    timeout_cnt <= 32'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b0;
                    byte_cnt <= 8'd0;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                    if (rx_valid && rx_data == 8'hAA) begin
                        header_seen <= 1'b1;
                        crc_byte_seen <= 1'b0;
                        crc_error_seen <= 1'b0;
                        timeout_seen <= 1'b0;
                        ack_seen <= 1'b0;
                        nack_seen <= 1'b0;
                    end
                end
                CLEAR_DATA: begin
                    timeout_cnt <= 32'd0;
                    rx_clear <= 1'b1;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                    if (byte_cnt == 8'd0)
                        crc <= 8'hFF;
                end
                DATA: begin
                    if (timeout)
                        timeout_seen <= 1'b1;
                    if (rx_valid) begin
                        timeout_cnt <= 32'd0;
                        buffer[byte_cnt] <= rx_data;
                        crc <= crc8(crc, rx_data);
                        byte_cnt <= byte_cnt + 8'd1;
                    end else if (!timeout) begin
                        timeout_cnt <= timeout_cnt + 32'd1;
                    end
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                CLEAR_CRC: begin
                    timeout_cnt <= 32'd0;
                    rx_clear <= 1'b1;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                REC_CRC8: begin
                    if (timeout)
                        timeout_seen <= 1'b1;
                    if (rx_valid) begin
                        timeout_cnt <= 32'd0;
                        crc_rec <= rx_data;
                        crc_byte_seen <= 1'b1;
                        if (rx_data != crc)
                            crc_error_seen <= 1'b1;
                    end else if (!timeout) begin
                        timeout_cnt <= timeout_cnt + 32'd1;
                    end
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                RECOVERY: begin
                    timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b1;
                    nack_seen <= 1'b1;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                SEND_NACK: begin
                    if (!tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b1;
                    nack_seen <= 1'b1;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b1;
                    tx_data <= 8'h15;
                    packet_valid <= 1'b0;
                end
                SEND_ACK: begin
                    if (!tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b0;
                    ack_seen <= 1'b1;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b1;
                    tx_data <= 8'h06;
                    packet_valid <= 1'b1;
                end
                WAIT_SEND: begin
                    if (tx_busy && !timeout)
                        timeout_cnt <= timeout_cnt + 32'd1;
                    else
                        timeout_cnt <= 32'd0;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                DRAIN_RX: begin
                    timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                    nack_response <= 1'b0;
                    if (rx_valid) begin
                        drain_cnt <= 32'd0;
                        rx_clear <= 1'b1;
                    end else if (!drain_done) begin
                        drain_cnt <= drain_cnt + 32'd1;
                        rx_clear <= 1'b0;
                    end else begin
                        rx_clear <= 1'b0;
                    end
                end
                CLEAR_IDLE: begin
                    timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b0;
                    rx_clear <= 1'b1;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                    timeout_cnt <= 32'd0;
                    byte_cnt <= 8'd0;
                    drain_cnt <= 32'd0;
                    nack_response <= 1'b0;
                    rx_clear <= 1'b0;
                    tx_start <= 1'b0;
                    packet_valid <= 1'b0;
                end
            endcase
        end
    end

    assign state_dbg = state;
    assign byte_count_dbg = byte_cnt;
    assign crc_calc_dbg = crc;
    assign crc_recv_dbg = crc_rec;
    assign debug_flags[0] = header_seen;
    assign debug_flags[1] = rx_valid;
    assign debug_flags[2] = timeout_seen;
    assign debug_flags[3] = crc_error_seen;
    assign debug_flags[4] = crc_byte_seen;
    assign debug_flags[5] = ack_seen;
    assign debug_flags[6] = nack_seen;
    assign debug_flags[7] = (state == DRAIN_RX);

endmodule
