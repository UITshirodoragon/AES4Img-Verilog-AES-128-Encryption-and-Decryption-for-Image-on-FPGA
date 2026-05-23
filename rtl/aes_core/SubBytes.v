module SubBytes(
		input wire [127:0] state_in,
		output wire [127:0] state_out
);

	 Sbox_8bits sb0  (.in_byte(state_in[127:120]), .out_byte(state_out[127:120]));
    Sbox_8bits sb1  (.in_byte(state_in[119:112]), .out_byte(state_out[119:112]));
    Sbox_8bits sb2  (.in_byte(state_in[111:104]), .out_byte(state_out[111:104]));
    Sbox_8bits sb3  (.in_byte(state_in[103:96]),  .out_byte(state_out[103:96]));
    
    Sbox_8bits sb4  (.in_byte(state_in[95:88]),   .out_byte(state_out[95:88]));
    Sbox_8bits sb5  (.in_byte(state_in[87:80]),   .out_byte(state_out[87:80]));
    Sbox_8bits sb6  (.in_byte(state_in[79:72]),   .out_byte(state_out[79:72]));
    Sbox_8bits sb7  (.in_byte(state_in[71:64]),   .out_byte(state_out[71:64]));
    
    Sbox_8bits sb8  (.in_byte(state_in[63:56]),   .out_byte(state_out[63:56]));
    Sbox_8bits sb9  (.in_byte(state_in[55:48]),   .out_byte(state_out[55:48]));
    Sbox_8bits sb10 (.in_byte(state_in[47:40]),   .out_byte(state_out[47:40]));
    Sbox_8bits sb11 (.in_byte(state_in[39:32]),   .out_byte(state_out[39:32]));
    
    Sbox_8bits sb12 (.in_byte(state_in[31:24]),   .out_byte(state_out[31:24]));
    Sbox_8bits sb13 (.in_byte(state_in[23:16]),   .out_byte(state_out[23:16]));
    Sbox_8bits sb14 (.in_byte(state_in[15:8]),    .out_byte(state_out[15:8]));
    Sbox_8bits sb15 (.in_byte(state_in[7:0]),     .out_byte(state_out[7:0]));
	 
endmodule