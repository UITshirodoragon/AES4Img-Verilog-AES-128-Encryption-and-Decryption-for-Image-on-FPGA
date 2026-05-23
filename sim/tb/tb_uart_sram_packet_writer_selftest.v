`timescale 1ns/1ps

module tb_uart_sram_packet_writer_selftest;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg enable = 1'b1;
    reg clear = 1'b0;
    reg packet_valid = 1'b0;
    wire [7:0] packet_addr;
    reg  [7:0] packet_mem [0:255];
    wire [7:0] packet_data = packet_mem[packet_addr];
    wire sram_req, sram_we;
    wire [17:0] sram_addr;
    wire [15:0] sram_wdata;
    reg sram_grant = 1'b1;
    wire busy, image_loaded;
    wire [9:0] packet_count;
    wire [7:0] word_index_dbg;
    wire [3:0] state_dbg;
    integer i;
    integer errors;

    always #10 clk = ~clk;

    uart_sram_packet_writer_320x240 #(
        .ADDR_BASE(18'h00000),
        .TOTAL_PACKETS(1)
    ) dut (
        .clk(clk), .rst_n(rst_n), .enable(enable), .clear(clear),
        .packet_valid(packet_valid), .packet_pd_data(packet_data), .packet_pd_address(packet_addr),
        .sram_req(sram_req), .sram_we(sram_we), .sram_addr(sram_addr), .sram_wdata(sram_wdata), .sram_grant(sram_grant),
        .busy(busy), .image_loaded(image_loaded), .packet_count(packet_count),
        .word_index_dbg(word_index_dbg), .state_dbg(state_dbg)
    );

    initial begin
        $dumpfile("tb_uart_sram_packet_writer_selftest.vcd");
        $dumpvars(0, tb_uart_sram_packet_writer_selftest);
        errors = 0;
        for (i = 0; i < 256; i = i + 1)
            packet_mem[i] = i[7:0];
        #100 rst_n = 1'b1;
        #40 packet_valid = 1'b1;
        #20 packet_valid = 1'b0;
        #20000;
        if (!image_loaded) begin
            $display("FAIL: image_loaded was not asserted");
            errors = errors + 1;
        end
        if (packet_count != 0) begin
            $display("FAIL: packet_count expected 0 after one packet, got %0d", packet_count);
            errors = errors + 1;
        end
        if (errors == 0) $display("PASS: tb_uart_sram_packet_writer_selftest");
        else $display("FAIL: tb_uart_sram_packet_writer_selftest errors=%0d", errors);
        $finish;
    end

    // Check byte order at write strobes: payload bytes 0,1 => 16'h0001,
    // payload bytes 2,3 => 16'h0203, etc. This matches send_image_packet_2.py.
    always @(posedge clk) begin
        if (sram_req && sram_we && sram_grant) begin
            if (sram_wdata !== {packet_mem[((sram_addr-18'h00000)<<1)], packet_mem[((sram_addr-18'h00000)<<1)+1]}) begin
                $display("FAIL byte order at addr=%h got=%h", sram_addr, sram_wdata);
                errors = errors + 1;
            end
        end
    end
endmodule
