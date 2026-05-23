//------------------------------------------------------------------------------
// input_control.v
// Decode KEY/SW cho demo AES ảnh.
//------------------------------------------------------------------------------
module input_control (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [3:0]  KEY,
    input  wire [17:0] SW,
    output wire        start_pulse,
    output wire        pause_pulse,
    output wire        step_pulse,
    output wire        fast_mode,
    output wire        decrypt_mode,
    output wire        auto_mode,
    output wire [1:0]  slow_level,
    output wire        verify_enable,
    output wire        clear_views,
    output wire        debug_pattern
);

button_edge u_start (.clk(clk), .reset_n(reset_n), .key_n(KEY[1]), .pressed(start_pulse));
button_edge u_pause (.clk(clk), .reset_n(reset_n), .key_n(KEY[2]), .pressed(pause_pulse));
button_edge u_step  (.clk(clk), .reset_n(reset_n), .key_n(KEY[3]), .pressed(step_pulse));

assign fast_mode     = ~SW[0];       // SW0=0 FAST, SW0=1 SLOW-L3
assign decrypt_mode  =  SW[1];       // 0 encrypt, 1 decrypt
assign auto_mode     =  SW[2];
assign slow_level    =  2'b10;       // only slow L3: 1 row/frame
assign verify_enable =  SW[5];
assign clear_views   =  SW[6];
assign debug_pattern =  SW[7];

endmodule
