module InvKeyExpansion(
    input  wire [127:0] current_key, // Khóa của vòng i (K_i)
    input  wire [7:0]   rcon,        // Hằng số vòng Rcon của vòng i
    output wire [127:0] prev_key     // Khóa của vòng trước (K_{i-1})
);

    // 1. Tách khóa hiện tại thành 4 word (32-bit)
    wire [31:0] w4 = current_key[127:96];
    wire [31:0] w5 = current_key[95:64];
    wire [31:0] w6 = current_key[63:32];
    wire [31:0] w7 = current_key[31:0];

    // 2. Phục hồi w3, w2, w1 (Rất nhanh, chỉ cần XOR 1 tầng)
    wire [31:0] w3 = w7 ^ w6;
    wire [31:0] w2 = w6 ^ w5;
    wire [31:0] w1 = w5 ^ w4;

    // 3. Phục hồi w0 (Cần tính qua hàm g)
    // 3.1. Dịch vòng trái 1 byte trên w3
    wire [31:0] rot_w3 = {w3[23:0], w3[31:24]};
    
    // 3.2. Tra bảng S-Box TIẾN cho 4 byte
    wire [31:0] sub_w3;
    Sbox_8bits sb0(.in_byte(rot_w3[31:24]), .out_byte(sub_w3[31:24]));
    Sbox_8bits sb1(.in_byte(rot_w3[23:16]), .out_byte(sub_w3[23:16]));
    Sbox_8bits sb2(.in_byte(rot_w3[15:8]),  .out_byte(sub_w3[15:8]));
    Sbox_8bits sb3(.in_byte(rot_w3[7:0]),   .out_byte(sub_w3[7:0]));

    // 3.3. XOR với Rcon
    wire [31:0] g_w3 = sub_w3 ^ {rcon, 24'h000000};

    // 3.4. Phục hồi w0
    wire [31:0] w0 = w4 ^ g_w3;

    // 4. Ghép lại thành khóa vòng trước
    assign prev_key = {w0, w1, w2, w3};

endmodule