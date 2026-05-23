`timescale 1ns/1ps

module tb_uart_rx_packet_256_selftest;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg rx_valid = 1'b0;
    reg [7:0] rx_data = 8'd0;
    reg tx_busy = 1'b0;
    reg [7:0] pd_addr = 8'd0;
    wire [7:0] pd_data;
    wire packet_valid;
    wire [7:0] tx_data;
    wire tx_start;
    wire rx_clear;
    wire [3:0] state_dbg;
    wire [7:0] byte_count_dbg, crc_calc_dbg, crc_recv_dbg, flags;
    integer i;
    integer errors;
    reg [7:0] crc;

    always #10 clk = ~clk;

    uart_rx_packet_256 #(.TIMEOUT_MAX(32'd100000), .DRAIN_IDLE_MAX(32'd1000)) dut(
        .clk(clk), .rst_n(rst_n), .rx_valid(rx_valid), .rx_data(rx_data), .tx_busy(tx_busy),
        .packet_valid(packet_valid), .tx_data(tx_data), .tx_start(tx_start), .rx_clear(rx_clear),
        .packet_pd_address(pd_addr), .packet_pd_data(pd_data), .state_dbg(state_dbg),
        .byte_count_dbg(byte_count_dbg), .crc_calc_dbg(crc_calc_dbg), .crc_recv_dbg(crc_recv_dbg), .debug_flags(flags)
    );

    function [7:0] crc8;
        input [7:0] crc_in;
        input [7:0] data_in;
        reg [7:0] crc_temp;
        integer j;
        begin
            crc_temp = crc_in ^ data_in;
            for (j = 0; j < 8; j = j + 1) begin
                if (crc_temp[7]) crc_temp = {crc_temp[6:0], 1'b0} ^ 8'h07;
                else crc_temp = {crc_temp[6:0], 1'b0};
            end
            crc8 = crc_temp;
        end
    endfunction

    task send_byte;
        input [7:0] b;
        begin
            @(posedge clk); rx_data <= b; rx_valid <= 1'b1;
            @(posedge clk); rx_valid <= 1'b0;
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        $dumpfile("tb_uart_rx_packet_256_selftest.vcd");
        $dumpvars(0, tb_uart_rx_packet_256_selftest);
        errors = 0;
        #100 rst_n = 1'b1;
        crc = 8'hFF;
        send_byte(8'hAA);
        for (i = 0; i < 256; i = i + 1) begin
            send_byte(i[7:0]);
            crc = crc8(crc, i[7:0]);
        end
        send_byte(crc);
        #2000;
        if (!flags[5]) begin
            $display("FAIL: ACK flag not seen");
            errors = errors + 1;
        end
        if (crc_recv_dbg != crc) begin
            $display("FAIL: crc_recv mismatch got=%h expected=%h", crc_recv_dbg, crc);
            errors = errors + 1;
        end
        pd_addr = 8'd0; #20; if (pd_data !== 8'h00) errors = errors + 1;
        pd_addr = 8'd255; #20; if (pd_data !== 8'hff) errors = errors + 1;
        if (errors == 0) $display("PASS: tb_uart_rx_packet_256_selftest");
        else $display("FAIL: tb_uart_rx_packet_256_selftest errors=%0d", errors);
        $finish;
    end
endmodule
