module KeyExpansion(
    input  wire [127:0] prev_key,   
    input  wire [7:0]   rcon,       
    output wire [127:0] next_key    
);

	 //Split Key into 4 words
	 wire [31:0] w0 = prev_key[127:96];
    wire [31:0] w1 = prev_key[95:64];
    wire [31:0] w2 = prev_key[63:32];
    wire [31:0] w3 = prev_key[31:0];
	 
	 //Rotate left 1 byte
	 wire [31:0] rot_w3 = {w3[23:0], w3[31:24]};
	 
	 //Sub Words
	 wire [31:0] sub_w3;
	 Sbox_8bits sb0(.in_byte(rot_w3[31:24]), .out_byte(sub_w3[31:24]));
	 Sbox_8bits sb1(.in_byte(rot_w3[23:16]), .out_byte(sub_w3[23:16]));
	 Sbox_8bits sb2(.in_byte(rot_w3[15:8]), .out_byte(sub_w3[15:8]));
	 Sbox_8bits sb3(.in_byte(rot_w3[7:0]), .out_byte(sub_w3[7:0]));

	 //XOR first byte of sub_w3 with Rcon
	 wire [31:0] xor_w3 = sub_w3 ^ {rcon, 24'b0};
	 
	 //Calculate next 4 keys
	 wire [31:0] w4 = w0 ^ xor_w3;
	 wire [31:0] w5 = w1 ^ w4;
	 wire [31:0] w6 = w2 ^ w5;
	 wire [31:0] w7 = w3 ^ w6;
	 
	 assign next_key = {w4, w5, w6, w7};
endmodule