module aes_encryption_core(
	input wire clk, reset_n, start_n,
	input wire [127:0] plaintext, key,
	output reg [127:0] ciphertext,
	output reg done
);

reg [3:0] round;
reg [127:0] current_state, current_key;

wire [127:0] sub_out, shift_out, add_key_out, mix_out, key_expansion_out;
wire [7:0] rcon_out;

//Datapath
rcon_gen RC(.round_num(round + 4'd1), .rcon(rcon_out));
KeyExpansion KE(.prev_key(current_key), .rcon(rcon_out), .next_key(key_expansion_out));


SubBytes SB(.state_in(current_state), .state_out(sub_out));
ShiftRows SR(.state_in(sub_out), .state_out(shift_out));
MixColumns MC(.state_in(shift_out), .state_out(mix_out));

wire [127:0] Before_Add_Key = (round == 4'd10) ? shift_out : mix_out;

AddRoundKey ARK(.state_in(Before_Add_Key), .round_key(current_key), .state_out(add_key_out));

//Controller
parameter IDLE = 2'd0, FIRST_ROUND = 2'd1, NINE_ROUNDS_LOOP = 2'd2, LAST_ROUND = 2'd3;
reg [1:0] state_fsm, next_state_fsm;

//Change State
always @(*) begin
	next_state_fsm = state_fsm;
	case(state_fsm)
			IDLE: 
				next_state_fsm = (!start_n) ? FIRST_ROUND : IDLE;
			FIRST_ROUND: 
				next_state_fsm = NINE_ROUNDS_LOOP;
			NINE_ROUNDS_LOOP: 
				next_state_fsm = (round == 4'd9) ? LAST_ROUND : NINE_ROUNDS_LOOP;
			LAST_ROUND:
				next_state_fsm = IDLE;
	endcase
end

//Update State
always @(posedge clk or negedge reset_n) begin
	if (!reset_n) begin
		state_fsm <= IDLE;
	end
	else begin 
		state_fsm <= next_state_fsm;
	end
end

//Output 
always @(posedge clk) begin
	case(state_fsm)
		IDLE: 
		begin
			done <= 1'b0;
			round <= 0;
			if (!start_n) begin
				current_key <= key;
				current_state <= plaintext;
			end
		end
		FIRST_ROUND:
		begin
			current_state <= current_state ^ current_key;
			current_key <= key_expansion_out;
			round <= round + 4'd1;
		end
		NINE_ROUNDS_LOOP:
		begin
			current_state <= add_key_out;
			current_key <= key_expansion_out;
			round <= round + 4'd1;
		end
		LAST_ROUND:
		begin
			done <= 1'b1;
			ciphertext <= add_key_out;
		end
	endcase
end

endmodule



