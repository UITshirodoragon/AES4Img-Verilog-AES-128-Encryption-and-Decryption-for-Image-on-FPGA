//------------------------------------------------------------------------------
// aes128_core_wrapper.v
// Wrapper chuẩn hóa AES core cũ thành IP start/busy/done active-high.
// Giữ nguyên aes_encryption_core và aes_decryption_core gốc.
//------------------------------------------------------------------------------
module aes128_core_wrapper (
    input  wire        clk,
    input  wire        reset_n,
    input  wire        start,
    input  wire        decrypt,       // 0: encrypt, 1: decrypt
    input  wire [127:0] block_in,
    input  wire [127:0] key,
    output wire [127:0] block_out,
    output reg         busy,
    output reg         done,
    output reg  [3:0]  core_state_dbg
);

localparam W_IDLE = 4'd0;
localparam W_WAIT = 4'd1;
localparam W_DONE = 4'd2;

reg [3:0] state;
reg decrypt_latched;
reg enc_start_n;
reg dec_start_n;

wire [127:0] enc_out;
wire [127:0] dec_out;
wire enc_done;
wire dec_done;

aes_encryption_core u_enc (
    .clk(clk),
    .reset_n(reset_n),
    .start_n(enc_start_n),
    .plaintext(block_in),
    .key(key),
    .ciphertext(enc_out),
    .done(enc_done)
);

aes_decryption_core u_dec (
    .clk(clk),
    .reset_n(reset_n),
    .start_n(dec_start_n),
    .ciphertext(block_in),
    .key(key),
    .plaintext(dec_out),
    .done(dec_done)
);

assign block_out = decrypt_latched ? dec_out : enc_out;

always @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        state <= W_IDLE;
        decrypt_latched <= 1'b0;
        enc_start_n <= 1'b1;
        dec_start_n <= 1'b1;
        busy <= 1'b0;
        done <= 1'b0;
        core_state_dbg <= W_IDLE;
    end else begin
        enc_start_n <= 1'b1;
        dec_start_n <= 1'b1;
        done <= 1'b0;
        core_state_dbg <= state;

        case (state)
            W_IDLE: begin
                busy <= 1'b0;
                if (start) begin
                    decrypt_latched <= decrypt;
                    busy <= 1'b1;
                    if (decrypt)
                        dec_start_n <= 1'b0;
                    else
                        enc_start_n <= 1'b0;
                    state <= W_WAIT;
                end
            end

            W_WAIT: begin
                busy <= 1'b1;
                if ((decrypt_latched && dec_done) || (!decrypt_latched && enc_done)) begin
                    state <= W_DONE;
                end
            end

            W_DONE: begin
                busy <= 1'b0;
                done <= 1'b1;
                state <= W_IDLE;
            end

            default: begin
                state <= W_IDLE;
            end
        endcase
    end
end

endmodule
