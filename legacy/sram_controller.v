module sram_controller (
    input  wire        clk,
    input  wire        reset,

    input  wire [17:0] i_addr,
    input  wire [15:0] i_data_write,
    input  wire        i_we,
    input  wire        i_rd,
    output reg  [15:0] o_data_read,

    output wire [17:0] SRAM_ADDR,
    inout  wire [15:0] SRAM_DQ,
    output wire        SRAM_WE_N,
    output wire        SRAM_OE_N,
    output wire        SRAM_UB_N,
    output wire        SRAM_LB_N,
    output wire        SRAM_CE_N
);

    assign SRAM_CE_N = 1'b0;
    assign SRAM_UB_N = 1'b0;
    assign SRAM_LB_N = 1'b0;

    assign SRAM_ADDR = i_addr;
    assign SRAM_WE_N = ~i_we;
    assign SRAM_OE_N = ~(i_rd && !i_we);
    assign SRAM_DQ = i_we ? i_data_write : 16'hzzzz;

    always @(posedge clk or posedge reset) begin
        if (reset)
            o_data_read <= 16'd0;
        else if (i_rd && !i_we)
            o_data_read <= SRAM_DQ;
    end

endmodule
