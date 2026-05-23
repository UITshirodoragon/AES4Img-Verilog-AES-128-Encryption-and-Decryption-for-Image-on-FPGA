module aes_decryption_core(
	input wire clk, reset_n, start_n,
	input wire [127:0] ciphertext, key,
	output reg [127:0] plaintext,
	output reg done
);

reg [3:0] round;
reg [127:0] current_state, current_key;

wire [127:0] inv_sub_out, inv_shift_out, add_key_out, inv_mix_out, key_expansion_out, inv_key_expansion_out;
wire [7:0] rcon_out;

parameter IDLE = 3'd0, KEY_GEN = 3'd1, FIRST_ROUND = 3'd2, NINE_ROUNDS_LOOP = 3'd3, LAST_ROUND = 3'd4;
reg [2:0] state_fsm, next_state_fsm;
//Datapath
wire [3:0]round_for_rcon = (state_fsm == KEY_GEN) ? round + 1 : round;
rcon_gen RC(.round_num(round_for_rcon), .rcon(rcon_out));
KeyExpansion KE(.prev_key(current_key), .rcon(rcon_out), .next_key(key_expansion_out));
InvKeyExpansion IKE(.current_key(current_key), .rcon(rcon_out), .prev_key(inv_key_expansion_out));

InvSubBytes ISB(.state_in(current_state), .state_out(inv_sub_out));
InvShiftRows ISR(.state_in(inv_sub_out), .state_out(inv_shift_out));
AddRoundKey ARK(.state_in(inv_shift_out), .round_key(current_key), .state_out(add_key_out));
Inv_MixColumns IMC(.state_in(add_key_out), .state_out(inv_mix_out));

wire [127:0]round_result = (round == 4'd0) ? add_key_out : inv_mix_out;

//Change State
always @(*) begin
	next_state_fsm = state_fsm;
	case(state_fsm)
			IDLE: 
				next_state_fsm = (!start_n) ? KEY_GEN : IDLE;
			KEY_GEN: 
				next_state_fsm = (round == 4'd10) ? FIRST_ROUND : KEY_GEN;
			FIRST_ROUND: 
				next_state_fsm = NINE_ROUNDS_LOOP;
			NINE_ROUNDS_LOOP: 
				next_state_fsm = (round == 4'd1) ? LAST_ROUND : NINE_ROUNDS_LOOP;
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
				current_state <= ciphertext;
			end
		end
		KEY_GEN:
		begin
			if (round < 4'd10) begin
				current_key <= key_expansion_out;
				round <= round + 4'd1;
			end
		end
		FIRST_ROUND:
		begin
			current_state <= current_state ^ current_key;
			current_key <= inv_key_expansion_out;
			round <= round - 4'd1;
		end
		NINE_ROUNDS_LOOP:
		begin
			current_state <= round_result;
			current_key <= inv_key_expansion_out;
			round <= round - 4'd1;
		end
		LAST_ROUND:
		begin
			done <= 1'b1;
			plaintext <= round_result;
		end
	endcase
end

endmodule



