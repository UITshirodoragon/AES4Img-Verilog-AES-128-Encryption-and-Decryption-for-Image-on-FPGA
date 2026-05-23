//------------------------------------------------------------------------------
// button_edge.v - đồng bộ nút active-low và tạo xung pressed 1 chu kỳ.
//------------------------------------------------------------------------------
module button_edge (
    input  wire clk,
    input  wire reset_n,
    input  wire key_n,
    output wire pressed
);
reg [2:0] sync;
always @(posedge clk or negedge reset_n) begin
    if (!reset_n)
        sync <= 3'b111;
    else
        sync <= {sync[1:0], key_n};
end
assign pressed = (sync[2:1] == 2'b10); // high->low transition
endmodule
