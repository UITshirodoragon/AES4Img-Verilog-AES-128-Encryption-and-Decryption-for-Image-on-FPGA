module Mix_Single_Column(
		input wire [31:0] column_in,
		output wire [31:0] column_out
);

	wire [7:0] byte0 = column_in[31:24];
	wire [7:0] byte1 = column_in[23:16];
	wire [7:0] byte2 = column_in[15:8];
	wire [7:0] byte3 = column_in[7:0];

	//Multiply by 2 function
	function [7:0] xTime;
		input [7:0]x;
		begin
			xTime = (x[7] == 1'b1) ? ((x << 1) ^ 8'h1b) : (x << 1);
		end	
	endfunction
	
	assign column_out[31:24] = xTime(byte0) ^ (xTime(byte1) ^ byte1) ^ byte2 ^ byte3;
	assign column_out[23:16] = byte0 ^ xTime(byte1) ^ (xTime(byte2) ^ byte2) ^ byte3;
	assign column_out[15:8] = byte0 ^ byte1 ^ xTime(byte2) ^ (xTime(byte3) ^ byte3);
	assign column_out[7:0] = (xTime(byte0) ^ byte0) ^ byte1 ^ byte2 ^ xTime(byte3);
	
endmodule