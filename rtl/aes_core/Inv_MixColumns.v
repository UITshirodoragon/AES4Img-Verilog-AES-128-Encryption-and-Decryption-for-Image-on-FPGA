module Inv_MixColumns(
		input wire [127:0] state_in,
		output wire [127:0] state_out
);

	Inv_Mix_Single_Column imsc0(.column_in(state_in[127:96]), .column_out(state_out[127:96]));
	Inv_Mix_Single_Column imsc1(.column_in(state_in[95:64]), .column_out(state_out[95:64]));
	Inv_Mix_Single_Column imsc2(.column_in(state_in[63:32]), .column_out(state_out[63:32]));
	Inv_Mix_Single_Column imsc3(.column_in(state_in[31:0]), .column_out(state_out[31:0]));
	
endmodule