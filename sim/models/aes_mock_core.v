//------------------------------------------------------------------------------
// aes_mock_core.v - mock AES for DMA unit tests.
// Latency fixed 3 cycles. encrypt: XOR constant. decrypt: same XOR.
//------------------------------------------------------------------------------
module aes_mock_core(
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    input  wire        decrypt,
    input  wire [127:0] block_in,
    output reg  [127:0] block_out,
    output reg         busy,
    output reg         done
);
reg [1:0] cnt;
reg [127:0] block_latched;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        cnt <= 2'd0; busy <= 1'b0; done <= 1'b0; block_out <= 128'd0; block_latched <= 128'd0;
    end else begin
        done <= 1'b0;
        if (start && !busy) begin
            busy <= 1'b1; cnt <= 2'd3; block_latched <= block_in;
        end else if (busy) begin
            if (cnt == 2'd0) begin
                busy <= 1'b0; done <= 1'b1; block_out <= block_latched ^ 128'h00112233445566778899aabbccddeeff;
            end else begin
                cnt <= cnt - 2'd1;
            end
        end
    end
end
endmodule
