module InvSubBytes(
		input wire [127:0] state_in,
		output wire [127:0] state_out
);

	 Inv_sbox_8bit isb0  (.in_byte(state_in[127:120]), .out_byte(state_out[127:120]));
    Inv_sbox_8bit isb1  (.in_byte(state_in[119:112]), .out_byte(state_out[119:112]));
    Inv_sbox_8bit isb2  (.in_byte(state_in[111:104]), .out_byte(state_out[111:104]));
    Inv_sbox_8bit isb3  (.in_byte(state_in[103:96]),  .out_byte(state_out[103:96]));
    
    Inv_sbox_8bit isb4  (.in_byte(state_in[95:88]),   .out_byte(state_out[95:88]));
    Inv_sbox_8bit isb5  (.in_byte(state_in[87:80]),   .out_byte(state_out[87:80]));
    Inv_sbox_8bit isb6  (.in_byte(state_in[79:72]),   .out_byte(state_out[79:72]));
    Inv_sbox_8bit isb7  (.in_byte(state_in[71:64]),   .out_byte(state_out[71:64]));
    
    Inv_sbox_8bit isb8  (.in_byte(state_in[63:56]),   .out_byte(state_out[63:56]));
    Inv_sbox_8bit isb9  (.in_byte(state_in[55:48]),   .out_byte(state_out[55:48]));
    Inv_sbox_8bit isb10 (.in_byte(state_in[47:40]),   .out_byte(state_out[47:40]));
    Inv_sbox_8bit isb11 (.in_byte(state_in[39:32]),   .out_byte(state_out[39:32]));
    
    Inv_sbox_8bit isb12 (.in_byte(state_in[31:24]),   .out_byte(state_out[31:24]));
    Inv_sbox_8bit isb13 (.in_byte(state_in[23:16]),   .out_byte(state_out[23:16]));
    Inv_sbox_8bit isb14 (.in_byte(state_in[15:8]),    .out_byte(state_out[15:8]));
    Inv_sbox_8bit isb15 (.in_byte(state_in[7:0]),     .out_byte(state_out[7:0]));
	 
endmodule