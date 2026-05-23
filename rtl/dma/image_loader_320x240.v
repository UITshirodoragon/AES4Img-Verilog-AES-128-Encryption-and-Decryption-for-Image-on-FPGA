//------------------------------------------------------------------------------
// image_loader_320x240.v
// Load ảnh ROM/HEX vào SRAM_ORIG lúc reset/boot.
//------------------------------------------------------------------------------
module image_loader_320x240 #(
    parameter IMG_W = 320,
    parameter IMG_H = 240,
    parameter ADDR_ORIG = 18'h00000
)(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    output reg         busy,
    output reg         done,

    output reg  [16:0] rom_addr,
    input  wire [15:0] rom_q,

    output reg         sram_req,
    output reg         sram_we,
    output reg         sram_rd,
    output reg  [17:0] sram_addr,
    output reg  [15:0] sram_wdata,
    input  wire        sram_grant,

    output reg [16:0]  pixel_counter,
    output reg [2:0]   state_dbg
);

localparam TOTAL_PIXELS = IMG_W * IMG_H;
localparam L_IDLE  = 3'd0;
localparam L_ADDR  = 3'd1;
localparam L_WAIT  = 3'd2;
localparam L_LATCH = 3'd3;
localparam L_WRITE = 3'd4;
localparam L_NEXT  = 3'd5;
localparam L_DONE  = 3'd6;

reg [2:0] state;
reg [16:0] idx;
reg [15:0] q_latched;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= L_IDLE;
        busy <= 1'b0;
        done <= 1'b0;
        rom_addr <= 17'd0;
        sram_req <= 1'b0;
        sram_we <= 1'b0;
        sram_rd <= 1'b0;
        sram_addr <= 18'd0;
        sram_wdata <= 16'd0;
        pixel_counter <= 17'd0;
        idx <= 17'd0;
        q_latched <= 16'd0;
        state_dbg <= L_IDLE;
    end else begin
        done <= 1'b0;
        state_dbg <= state;
        case (state)
            L_IDLE: begin
                busy <= 1'b0;
                sram_req <= 1'b0;
                sram_we <= 1'b0;
                sram_rd <= 1'b0;
                if (start) begin
                    busy <= 1'b1;
                    idx <= 17'd0;
                    rom_addr <= 17'd0;
                    pixel_counter <= 17'd0;
                    state <= L_ADDR;
                end
            end
            L_ADDR: begin
                rom_addr <= idx;
                state <= L_WAIT;
            end
            L_WAIT: begin
                // wait one clock for synchronous ROM output
                state <= L_LATCH;
            end
            L_LATCH: begin
                q_latched <= rom_q;
                state <= L_WRITE;
            end
            L_WRITE: begin
                sram_req <= 1'b1;
                sram_we <= 1'b1;
                sram_rd <= 1'b0;
                sram_addr <= ADDR_ORIG + idx;
                sram_wdata <= q_latched;
                if (sram_grant)
                    state <= L_NEXT;
            end
            L_NEXT: begin
                sram_req <= 1'b0;
                sram_we <= 1'b0;
                pixel_counter <= idx + 17'd1;
                if (idx == TOTAL_PIXELS - 1) begin
                    state <= L_DONE;
                end else begin
                    idx <= idx + 17'd1;
                    state <= L_ADDR;
                end
            end
            L_DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= L_IDLE;
            end
            default: state <= L_IDLE;
        endcase
    end
end

endmodule
