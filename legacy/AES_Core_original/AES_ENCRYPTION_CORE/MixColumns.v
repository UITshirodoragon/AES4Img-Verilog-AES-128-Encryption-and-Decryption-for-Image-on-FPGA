module MixColumns(
		input wire [127:0] state_in,
		output wire [127:0] state_out
);

	Mix_Single_Column msc0(.column_in(state_in[127:96]), .column_out(state_out[127:96]));
	Mix_Single_Column msc1(.column_in(state_in[95:64]), .column_out(state_out[95:64]));
	Mix_Single_Column msc2(.column_in(state_in[63:32]), .column_out(state_out[63:32]));
	Mix_Single_Column msc3(.column_in(state_in[31:0]), .column_out(state_out[31:0]));
	
endmodule