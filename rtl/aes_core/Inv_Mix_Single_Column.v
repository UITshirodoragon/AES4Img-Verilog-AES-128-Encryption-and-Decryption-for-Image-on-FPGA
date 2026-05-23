module Inv_Mix_Single_Column(
		input wire [31:0] column_in,
		output wire [31:0] column_out
);

	wire [7:0] b0 = column_in[31:24];
	wire [7:0] b1 = column_in[23:16];
	wire [7:0] b2 = column_in[15:8];
	wire [7:0] b3 = column_in[7:0];

	//Multiply by 2 function
	function [7:0] xTime;
		input [7:0]x;
		begin
			xTime = (x[7] == 1'b1) ? ((x << 1) ^ 8'h1b) : (x << 1);
		end	
	endfunction
	
    wire [7:0] b0_x2 = xTime(b0);
    wire [7:0] b0_x4 = xTime(b0_x2);
    wire [7:0] b0_x8 = xTime(b0_x4);
    wire [7:0] b0_x9 = b0_x8 ^ b0;
    wire [7:0] b0_xb = b0_x8 ^ b0_x2 ^ b0;
    wire [7:0] b0_xd = b0_x8 ^ b0_x4 ^ b0;
    wire [7:0] b0_xe = b0_x8 ^ b0_x4 ^ b0_x2;

    wire [7:0] b1_x2 = xTime(b1);
    wire [7:0] b1_x4 = xTime(b1_x2);
    wire [7:0] b1_x8 = xTime(b1_x4);
    wire [7:0] b1_x9 = b1_x8 ^ b1;
    wire [7:0] b1_xb = b1_x8 ^ b1_x2 ^ b1;
    wire [7:0] b1_xd = b1_x8 ^ b1_x4 ^ b1;
    wire [7:0] b1_xe = b1_x8 ^ b1_x4 ^ b1_x2;
	 
    wire [7:0] b2_x2 = xTime(b2);
    wire [7:0] b2_x4 = xTime(b2_x2);
    wire [7:0] b2_x8 = xTime(b2_x4);
    wire [7:0] b2_x9 = b2_x8 ^ b2;
    wire [7:0] b2_xb = b2_x8 ^ b2_x2 ^ b2;
    wire [7:0] b2_xd = b2_x8 ^ b2_x4 ^ b2;
    wire [7:0] b2_xe = b2_x8 ^ b2_x4 ^ b2_x2;

    wire [7:0] b3_x2 = xTime(b3);
    wire [7:0] b3_x4 = xTime(b3_x2);
    wire [7:0] b3_x8 = xTime(b3_x4);
    wire [7:0] b3_x9 = b3_x8 ^ b3;
    wire [7:0] b3_xb = b3_x8 ^ b3_x2 ^ b3;
    wire [7:0] b3_xd = b3_x8 ^ b3_x4 ^ b3;
    wire [7:0] b3_xe = b3_x8 ^ b3_x4 ^ b3_x2;

    assign column_out[31:24] = b0_xe ^ b1_xb ^ b2_xd ^ b3_x9;
    assign column_out[23:16] = b0_x9 ^ b1_xe ^ b2_xb ^ b3_xd;
    assign column_out[15:8]  = b0_xd ^ b1_x9 ^ b2_xe ^ b3_xb;
    assign column_out[7:0]   = b0_xb ^ b1_xd ^ b2_x9 ^ b3_xe;

endmodule
	